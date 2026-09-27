"""
Repository Scanner.

Recursively walks a repository directory, classifies files,
extracts symbols and imports, and assembles the Repository
knowledge model. No external tools required.
"""

from __future__ import annotations

import os
import re
import uuid
from pathlib import Path

from app.models.repository import (
    Repository, RepositoryStatus, SourceFile, Symbol,
    ImportRecord, Relationship,
)
from app.analyzers.language_detector import (
    detect_language, is_source_file, is_ignored_dir,
    is_test_file, is_entry_point, is_config_file, is_dependency_file,
    IGNORE_EXTENSIONS,
)
from app.analyzers.symbol_extractor import extract_symbols, extract_imports
from app.analyzers.relationship_extractor import extract_relationships

# Maximum file size to analyse (bytes) - skip very large files
MAX_FILE_SIZE = 500_000  # 500 KB

# Maximum content to keep in memory per file for analysis
MAX_CONTENT_CHARS = 200_000


def scan_repository(
    repo_root: str,
    repo_id: str | None = None,
    repo_name: str | None = None,
    extra_ignore_dirs: set[str] | None = None,
) -> Repository:
    """
    Scan the repository at `repo_root` and return a populated Repository.

    Steps:
    1. Walk directory tree, classify files
    2. Extract symbols and imports from each source file
    3. Extract relationships across the codebase
    """
    root = Path(repo_root)
    rid = repo_id or str(uuid.uuid4())
    name = repo_name or root.name

    repo = Repository(
        id=rid,
        name=name,
        status=RepositoryStatus.SCANNING,
        root_path=str(root.resolve()),
    )

    # ---------- Phase 1: File discovery ----------
    all_files: list[Path] = []
    _walk_directory(root, all_files, extra_ignore_dirs or set())

    repo.total_files = len(all_files)

    # ---------- Phase 2: File analysis ----------
    for abs_path in all_files:
        rel_path = abs_path.relative_to(root).as_posix()
        size = abs_path.stat().st_size

        language = detect_language(abs_path)

        # Read content for source files within size limit
        content: str | None = None
        if is_source_file(abs_path) and size <= MAX_FILE_SIZE:
            try:
                raw = abs_path.read_bytes()
                content = raw.decode("utf-8", errors="replace")[:MAX_CONTENT_CHARS]
            except Exception:
                content = None

        # Count lines
        line_count = content.count("\n") + 1 if content else 0

        src_file = SourceFile(
            id=rel_path,
            path=rel_path,
            language=language,
            size_bytes=size,
            line_count=line_count,
            is_entry_point=is_entry_point(Path(rel_path)),
            is_test=is_test_file(Path(rel_path)),
            is_config=is_config_file(Path(rel_path)),
        )
        # Store content privately for analysis (not serialised by default)
        src_file._content = content

        # Extract symbols and imports if we have content
        if content and language != "Unknown":
            try:
                symbols = extract_symbols(rel_path, content, language)
                src_file.symbols = symbols
                for sym in symbols:
                    repo.symbols[sym.id] = sym
            except Exception:
                pass

            try:
                imports = extract_imports(rel_path, content, language)
                src_file.imports = imports
            except Exception:
                pass

        repo.files[rel_path] = src_file

        # Language stats
        if language != "Unknown":
            repo.languages[language] = repo.languages.get(language, 0) + 1
            repo.source_files += 1

        # Accumulate entry points and test files
        if src_file.is_entry_point:
            # Find the main-like symbol in this file, or use file path
            entry_sym = next(
                (s.id for s in src_file.symbols if s.name in ("main", "app", "App", "MyApp")),
                rel_path,
            )
            repo.entry_points.append(entry_sym)

        if src_file.is_test:
            repo.test_files.append(rel_path)

        if is_dependency_file(abs_path):
            repo.dependency_files.append(rel_path)

    # ---------- Phase 3: Relationship extraction ----------
    try:
        rels = extract_relationships(repo)
        repo.relationships = rels
    except Exception as e:
        repo.metadata["relationship_error"] = str(e)

    repo.status = RepositoryStatus.INDEXED
    return repo


# ---------------------------------------------------------------------------
# Private helpers
# ---------------------------------------------------------------------------

def _walk_directory(
    root: Path,
    result: list[Path],
    extra_ignore_dirs: set[str],
) -> None:
    """Recursively collect file paths, skipping ignored directories."""
    try:
        entries = sorted(root.iterdir())
    except PermissionError:
        return

    for entry in entries:
        if entry.is_symlink():
            continue
        if entry.is_dir():
            if is_ignored_dir(entry.name, extra_ignore_dirs):
                continue
            _walk_directory(entry, result, extra_ignore_dirs)
        elif entry.is_file():
            # Skip binaries and non-text files
            if entry.suffix.lower() in IGNORE_EXTENSIONS:
                continue
            if entry.stat().st_size == 0:
                continue
            result.append(entry)
