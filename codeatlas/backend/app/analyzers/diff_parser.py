"""
Diff Parser — Generic Unified Diff and Change Extraction.

Parses unified Git diffs and patch formats to extract:
1. Modified, added, and deleted files
2. Changed line intervals and hunks
3. Added and removed lines
4. Intersected symbols (classes, methods, functions) within the repository knowledge graph
"""

from __future__ import annotations

import posixpath
import re
from pathlib import Path
from typing import Optional

from app.models.repository import Repository, Symbol, ChangedFile, ChangedLineHunk


HUNK_HEADER_RE = re.compile(
    r"^@@\s+-(?P<old_start>\d+)(?:,(?P<old_lines>\d+))?\s+\+(?P<new_start>\d+)(?:,(?P<new_lines>\d+))?\s+@@"
)


def parse_git_diff(diff_text: str) -> list[ChangedFile]:
    """
    Parse a unified Git diff text into structured ChangedFile objects.
    Handles standard `git diff`, `git patch`, and manual unified diff strings.
    """
    if not diff_text or not diff_text.strip():
        return []

    lines = diff_text.splitlines()
    files: list[ChangedFile] = []
    curr_file: Optional[ChangedFile] = None
    curr_hunk: Optional[ChangedLineHunk] = None

    def _normalize_path(p: str) -> str:
        clean = p.strip()
        if clean.startswith("a/") or clean.startswith("b/"):
            clean = clean[2:]
        clean = clean.replace("\\", "/").lstrip("/")
        return clean

    i = 0
    while i < len(lines):
        line = lines[i]

        # 1. Detect diff --git header
        if line.startswith("diff --git "):
            parts = line.split(" ")
            if len(parts) >= 4:
                file_b = _normalize_path(parts[3])
                curr_file = ChangedFile(file=file_b, status="modified")
                files.append(curr_file)
                curr_hunk = None
            i += 1
            continue

        # 2. Detect --- and +++ headers
        if line.startswith("--- "):
            old_path = line[4:].strip()
            if old_path == "/dev/null" and curr_file:
                curr_file.status = "added"
            i += 1
            continue

        if line.startswith("+++ "):
            new_path = _normalize_path(line[4:].strip())
            if new_path == "/dev/null" and curr_file:
                curr_file.status = "deleted"
            elif not curr_file or curr_file.file != new_path:
                if curr_file and curr_file.file == "":
                    curr_file.file = new_path
                elif not curr_file or curr_file.file != new_path:
                    # New file entry if not already created by diff --git
                    curr_file = ChangedFile(file=new_path, status="modified")
                    files.append(curr_file)
            i += 1
            continue

        # 3. Detect Hunk header @@ -x,y +x,y @@
        hunk_match = HUNK_HEADER_RE.match(line)
        if hunk_match:
            if not curr_file:
                # Diff snippet without file header
                curr_file = ChangedFile(file="[unknown_file]", status="modified")
                files.append(curr_file)

            old_start = int(hunk_match.group("old_start"))
            old_lines = int(hunk_match.group("old_lines")) if hunk_match.group("old_lines") else 1
            new_start = int(hunk_match.group("new_start"))
            new_lines = int(hunk_match.group("new_lines")) if hunk_match.group("new_lines") else 1

            curr_hunk = ChangedLineHunk(
                old_start=old_start,
                old_lines=old_lines,
                new_start=new_start,
                new_lines=new_lines,
            )
            curr_file.hunks.append(curr_hunk)

            # Record changed line range for new version
            range_end = max(new_start, new_start + new_lines - 1)
            curr_file.changed_line_ranges.append((new_start, range_end))
            i += 1
            continue

        # 4. Added / Removed lines inside a hunk
        if curr_hunk:
            if line.startswith("+") and not line.startswith("+++"):
                curr_hunk.added_lines.append(line[1:])
                if curr_file:
                    curr_file.added_count += 1
            elif line.startswith("-") and not line.startswith("---"):
                curr_hunk.removed_lines.append(line[1:])
                if curr_file:
                    curr_file.removed_count += 1

        i += 1

    return files


def detect_changed_symbols(
    changed_files: list[ChangedFile],
    repo: Repository,
) -> tuple[list[ChangedFile], list[Symbol]]:
    """
    Intersect changed line ranges in changed_files with indexed symbols in repo.
    Returns the enriched changed_files list and the set of unique changed Symbols.
    """
    changed_symbols: list[Symbol] = []
    seen_sym_ids: set[str] = set()

    for cf in changed_files:
        # Match file in repository
        matched_repo_file: Optional[str] = None
        if cf.file in repo.files:
            matched_repo_file = cf.file
        else:
            # Suffix match (e.g. "medicine_service.dart" vs "lib/services/medicine_service.dart")
            for rf in repo.files:
                if rf.endswith(cf.file) or cf.file.endswith(rf):
                    matched_repo_file = rf
                    break

        if not matched_repo_file:
            continue

        cf.file = matched_repo_file
        src_file = repo.files[matched_repo_file]

        # If no specific hunks/ranges were provided, treat all top-level symbols as changed
        if not cf.changed_line_ranges:
            for sym in src_file.symbols:
                if sym.id not in seen_sym_ids:
                    seen_sym_ids.add(sym.id)
                    changed_symbols.append(sym)
                    cf.changed_symbols.append(sym.qualified_name)
            continue

        # Check overlap between changed line ranges and symbol line spans
        for sym in src_file.symbols:
            sym_start = sym.line_start
            sym_end = sym.line_end
            has_overlap = False

            for c_start, c_end in cf.changed_line_ranges:
                if max(sym_start, c_start) <= min(sym_end, c_end):
                    has_overlap = True
                    break

            if has_overlap and sym.id not in seen_sym_ids:
                seen_sym_ids.add(sym.id)
                changed_symbols.append(sym)
                cf.changed_symbols.append(sym.qualified_name)

    return changed_files, changed_symbols
