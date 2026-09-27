"""
Relationship Extractor.

Discovers relationships between symbols and files:
1. Imports (file → file) with precise language-aware path resolution
2. Function & method calls (symbol → symbol) with class context & imports
3. Instantiations / object creations (symbol → class)
4. Class inheritance & interface implementations (class → class/interface)
5. Database / data store access (symbol → data collection) with READS / WRITES
6. Test coverage relationships (test file → source file)

All relationships include verifiable source evidence (file, line numbers, snippet).
"""

from __future__ import annotations

import posixpath
import re
from pathlib import Path
from typing import Optional

from app.models.repository import (
    Relationship, RelationshipType, Confidence, Evidence,
    Symbol, SymbolType, SourceFile, Repository
)
from app.analyzers.symbol_extractor import RESERVED_WORDS



# ---------------------------------------------------------------------------
# Common language & framework built-in types to avoid false CREATES
# ---------------------------------------------------------------------------

BUILTIN_TYPES = {
    # Dart / Flutter standard widgets and types
    "Text", "Icon", "SizedBox", "Divider", "Container", "Padding", "Center",
    "Column", "Row", "Card", "Scaffold", "AppBar", "Align", "Expanded",
    "Flexible", "SingleChildScrollView", "DropdownMenuItem", "ElevatedButton",
    "TextButton", "OutlinedButton", "IconButton", "CircleAvatar", "TextStyle",
    "EdgeInsets", "BorderRadius", "BoxDecoration", "LinearGradient", "Colors",
    "RegExp", "DateTime", "Duration", "Uri", "Future", "Stream", "List", "Map",
    "Set", "SnackBar", "AlertDialog", "TextEditingController", "GlobalKey",
    "MaterialPageRoute", "ScrollController", "FormState", "SnackBarBehavior",
    "Color", "FontWeight", "MainAxisAlignment", "CrossAxisAlignment",
    "VisualDensity", "RoundedRectangleBorder", "InputDecoration", "TextField",
    "DropdownButtonFormField", "ValueKey", "Key", "State", "StatefulWidget",
    "StatelessWidget", "BuildContext", "Widget", "VoidCallback",
    # Python built-ins
    "Exception", "ValueError", "TypeError", "KeyError", "IndexError",
    "RuntimeError", "AttributeError", "StopIteration", "dict", "list",
    "set", "tuple", "str", "int", "float", "bool", "bytes", "object",
    "Path", "BytesIO", "StringIO", "APIRouter", "BaseModel", "Field",
    # JS / TS built-ins
    "Promise", "Error", "Array", "Object", "String", "Number", "Boolean",
    "Date", "RegExp", "Map", "Set", "WeakMap", "WeakSet", "Symbol",
    "Response", "Request", "Headers", "URL", "URLSearchParams",
}

# Generic method names that should NEVER be resolved globally without import or receiver type
GENERIC_METHOD_NAMES = {
    "get", "set", "map", "contains", "add", "remove", "clear", "tolist",
    "tostring", "tojson", "fromjson", "trim", "split", "pop", "push",
    "print", "setstate", "dispose", "init", "show", "format", "close",
    "save", "update", "delete", "create", "read", "write", "build",
    "length", "indexof", "startswith", "endswith", "replace", "replacefirst",
    "allmatches", "firstmatch", "join", "where", "firstwhere", "lastwhere",
    "sort", "sublist", "take", "skip", "any", "every", "foreach",
    "now", "parse", "tryparse", "clamp", "round", "floor", "ceil",
    "then", "catcherror", "whencomplete", "timeout", "listen", "cancel",
    "validate", "reset", "log", "info", "warn", "error", "debug",
    "render", "mount", "unmount", "send", "json", "status", "end",
}

# DB access patterns
FIRESTORE_COLLECTION_RE = re.compile(
    r"\.collection\(\s*['\"]([^'\"]+)['\"]\s*\)"
)
FIRESTORE_WRITE_RE = re.compile(
    r"\.(?:add|set|update|delete)\s*\("
)
FIRESTORE_READ_RE = re.compile(
    r"\.(?:get|snapshots|where)\s*\("
)

SQL_TABLE_RE = re.compile(
    r"(?:FROM|JOIN|INTO|UPDATE|TABLE)\s+['\"`]?([a-zA-Z_]\w+)['\"`]?",
    re.IGNORECASE,
)


def extract_relationships(repo: Repository) -> list[Relationship]:
    """
    Extract all relationships across the scanned repository.
    Returns a comprehensive list of typed, evidenced Relationship objects.
    """
    relationships: list[Relationship] = []

    # Detect package name if Dart/Flutter project
    package_name = _detect_package_name(repo)

    # 1. Build lookups
    file_by_stem: dict[str, str] = {}
    for fp in repo.files:
        stem = Path(fp).stem.lower()
        file_by_stem[stem] = fp
        stem_clean = stem.replace("_", "").replace("-", "")
        file_by_stem[stem_clean] = fp

    # Symbols indexed by qualified_name, class_name, and by file
    symbols_by_file: dict[str, list[Symbol]] = {}
    classes_by_name: dict[str, list[Symbol]] = {}  # class_name -> [Symbol]
    symbols_by_class_method: dict[tuple[str, str], list[Symbol]] = {}  # (class_name, method_name) -> [Symbol]
    all_symbols_by_name: dict[str, list[Symbol]] = {}  # name -> [Symbol]

    for sym_id, sym in repo.symbols.items():
        symbols_by_file.setdefault(sym.file, []).append(sym)
        all_symbols_by_name.setdefault(sym.name.lower(), []).append(sym)

        if sym.symbol_type in (SymbolType.CLASS, SymbolType.INTERFACE, SymbolType.ENUM):
            classes_by_name.setdefault(sym.name, []).append(sym)

        if "." in sym.qualified_name:
            cls, meth = sym.qualified_name.split(".", 1)
            symbols_by_class_method.setdefault((cls, meth), []).append(sym)

    # 2. Extract relationships per file
    file_import_targets: dict[str, set[str]] = {}

    # Phase 2a: Imports
    for file_path, source_file in repo.files.items():
        import_rels = _extract_import_relationships(
            file_path, source_file, repo.files, file_by_stem, package_name
        )
        relationships.extend(import_rels)
        file_import_targets[file_path] = {r.target_id for r in import_rels}

    # Phase 2b: Calls, Instantiations, Inheritances, DB Access, Tests
    for file_path, source_file in repo.files.items():
        content = source_file._content
        if not content:
            continue

        lines = content.split("\n")
        imported_files = file_import_targets.get(file_path, set())

        # Extract variable types declared in this file for receiver inference
        var_types = _extract_file_variable_types(source_file, lines)

        # Call & Creation relationships
        relationships.extend(_extract_code_relationships(
            file_path=file_path,
            source_file=source_file,
            lines=lines,
            repo=repo,
            imported_files=imported_files,
            classes_by_name=classes_by_name,
            symbols_by_class_method=symbols_by_class_method,
            all_symbols_by_name=all_symbols_by_name,
            var_types=var_types,
        ))

        # DB / Firestore relationships
        relationships.extend(_extract_db_relationships(
            file_path=file_path,
            source_file=source_file,
            lines=lines,
        ))

        # Test relationships
        if source_file.is_test:
            for imp_file in imported_files:
                if not repo.files.get(imp_file, SourceFile(id=imp_file, path=imp_file, language="", size_bytes=0, line_count=0)).is_test:
                    matching_imp = next((i for i in source_file.imports if _resolve_import_to_file(i.imported_module, file_path, repo.files, file_by_stem, package_name) == imp_file), None)
                    imp_line = matching_imp.line if matching_imp else 1
                    imp_snippet = matching_imp.raw if matching_imp else (lines[0].strip() if lines else f"Test file {file_path}")
                    relationships.append(Relationship(
                        source_id=file_path,
                        target_id=imp_file,
                        relationship_type=RelationshipType.TESTS,
                        confidence=Confidence.CONFIRMED,
                        description=f"{Path(file_path).name} tests {Path(imp_file).name}",
                        evidence=[Evidence(
                            file=file_path,
                            line_start=imp_line,
                            line_end=imp_line,
                            snippet=imp_snippet,
                            description=f"Test file imports and tests {imp_file}",
                        )],
                    ))

    return _deduplicate_relationships(relationships)


# ---------------------------------------------------------------------------
# Import Extraction & Resolution
# ---------------------------------------------------------------------------

def _extract_import_relationships(
    file_path: str,
    source_file: SourceFile,
    known_files: dict[str, SourceFile],
    file_by_stem: dict[str, str],
    package_name: Optional[str],
) -> list[Relationship]:
    """Resolve import records to actual repository files."""
    rels: list[Relationship] = []

    for imp in source_file.imports:
        target_file = _resolve_import_to_file(
            imp.imported_module, file_path, known_files, file_by_stem, package_name
        )
        if not target_file or target_file == file_path:
            continue

        rels.append(Relationship(
            source_id=file_path,
            target_id=target_file,
            relationship_type=RelationshipType.IMPORTS,
            confidence=Confidence.CONFIRMED,
            description=f"{file_path} imports {target_file}",
            evidence=[Evidence(
                file=file_path,
                line_start=imp.line,
                line_end=imp.line,
                snippet=imp.raw,
                description="Import statement",
            )],
        ))

    return rels


def _resolve_import_to_file(
    module_path: str,
    importing_file: str,
    known_files: dict[str, SourceFile],
    file_by_stem: dict[str, str],
    package_name: Optional[str] = None,
) -> str | None:
    """
    Resolve an import path string to a known file in the repository.
    Handles relative paths, Dart package imports, Python dotted imports, TS/JS modules.
    """
    raw = module_path.strip().strip("'\"")

    # 1. Builtin Dart SDK imports (dart:io, dart:convert, etc.) -> external
    if raw.startswith("dart:"):
        return None

    # 2. Dart package: imports
    if raw.startswith("package:"):
        # e.g. "package:care_sync/services/medicine_service.dart"
        parts = raw[len("package:"):].split("/", 1)
        pkg = parts[0]
        subpath = parts[1] if len(parts) > 1 else ""

        # If subpath exists under lib/
        lib_candidate = f"lib/{subpath}"
        if lib_candidate in known_files:
            return lib_candidate
        if subpath in known_files:
            return subpath

        # If package name matches this project or known files match subpath
        for ext in ("", ".dart"):
            cand = f"lib/{subpath}{ext}" if not subpath.endswith(".dart") else f"lib/{subpath}"
            if cand in known_files:
                return cand

        # If external package (e.g. package:flutter/material.dart, package:firebase_auth/...)
        return None

    # 3. Relative imports (e.g. "../services/medicine_service.dart", "./login_screen.dart", "login_screen.dart")
    importing_dir = posixpath.dirname(importing_file)

    # Normalize relative path against importing directory
    candidate = posixpath.normpath(posixpath.join(importing_dir, raw))
    if candidate in known_files:
        return candidate

    # Try common extensions for the candidate
    for ext in (".dart", ".ts", ".tsx", ".js", ".jsx", ".py", ".kt", ".java", ".go"):
        if f"{candidate}{ext}" in known_files:
            return f"{candidate}{ext}"
        if f"{candidate}/index{ext}" in known_files:
            return f"{candidate}/index{ext}"

    # Also try resolving relative to 'lib/' or repo root
    if f"lib/{raw}" in known_files:
        return f"lib/{raw}"
    for ext in (".dart", ".ts", ".tsx", ".js", ".jsx", ".py"):
        if f"lib/{raw}{ext}" in known_files:
            return f"lib/{raw}{ext}"

    # 4. Python dotted import (e.g. "services.auth_service", "backend_models")
    if "." in raw and "/" not in raw:
        dotted_path = raw.replace(".", "/")
        for ext in (".py", ""):
            cand = f"{dotted_path}{ext}"
            if cand in known_files:
                return cand
            cand_from_dir = posixpath.normpath(posixpath.join(importing_dir, f"{dotted_path}{ext}"))
            if cand_from_dir in known_files:
                return cand_from_dir

    # 5. Direct exact or suffix match (only if not a generic library keyword)
    raw_no_ext = posixpath.splitext(raw)[0]
    for fp in known_files:
        fp_no_ext = posixpath.splitext(fp)[0]
        if fp == raw or fp_no_ext.endswith(f"/{raw_no_ext}") or fp_no_ext == raw_no_ext:
            return fp

    return None


def _detect_package_name(repo: Repository) -> Optional[str]:
    """Detect package name from pubspec.yaml or package.json."""
    pubspec = repo.files.get("pubspec.yaml") or repo.files.get("pubspec.yml")
    if pubspec and pubspec._content:
        m = re.search(r"^name:\s*([a-zA-Z_]\w*)", pubspec._content, re.MULTILINE)
        if m:
            return m.group(1)
    return None


# ---------------------------------------------------------------------------
# Code-Level Relationships (Calls, Instantiations, Inheritances)
# ---------------------------------------------------------------------------

# Patterns for method / function calls: Receiver.method(...) or await Receiver.method(...)
CALL_PATTERN = re.compile(
    r"\b([a-zA-Z_]\w*)\.([a-zA-Z_]\w*)\s*\("
)

# Pattern for constructor / instantiation: ClassName(...) or new ClassName(...)
INSTANTIATION_PATTERN = re.compile(
    r"\b(?:new\s+)?([A-Z]\w*)\s*\("
)

# Pattern for class inheritance: class A extends B
EXTENDS_PATTERN = re.compile(
    r"class\s+([a-zA-Z_]\w*)\s+(?:extends|implements|with)\s+([a-zA-Z_]\w*)"
)


def _extract_file_variable_types(source_file: SourceFile, lines: list[str]) -> dict[str, str]:
    """
    Extract variable -> type mappings from variable declarations within a file.
    e.g. 'final textRecognizer = TextRecognizer();' -> 'textRecognizer' -> 'TextRecognizer'
         'final picker = ImagePicker();' -> 'picker' -> 'ImagePicker'
         'self.users = UserService()' -> 'users' -> 'UserService'
         'const controller = new UserController()' -> 'controller' -> 'UserController'
    """
    var_types: dict[str, str] = {}

    patterns = [
        # final picker = ImagePicker();
        re.compile(r"(?:final|const|late|var)\s+([a-zA-Z_]\w*)\s*=\s*(?:new\s+)?([A-Z]\w*)\s*\("),
        # ImagePicker picker = ImagePicker();
        re.compile(r"([A-Z]\w*)\s+([a-zA-Z_]\w*)\s*=\s*(?:new\s+)?\1\s*\("),
        # self.users = UserService()
        re.compile(r"self\.([a-zA-Z_]\w*)\s*=\s*([A-Z]\w*)\s*\("),
        # const controller = new UserController()
        re.compile(r"(?:const|let|var)\s+([a-zA-Z_]\w*)\s*=\s*(?:new\s+)?([A-Z]\w*)\s*\("),
    ]

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            continue
        for pat in patterns:
            m = pat.search(stripped)
            if m:
                var_name = m.group(1)
                type_name = m.group(2)
                var_types[var_name] = type_name
                break

    return var_types


def _extract_code_relationships(
    file_path: str,
    source_file: SourceFile,
    lines: list[str],
    repo: Repository,
    imported_files: set[str],
    classes_by_name: dict[str, list[Symbol]],
    symbols_by_class_method: dict[tuple[str, str], list[Symbol]],
    all_symbols_by_name: dict[str, list[Symbol]],
    var_types: dict[str, str],
) -> list[Relationship]:
    """Extract CALLS, CREATES, EXTENDS, and REFERENCES from code blocks."""
    rels: list[Relationship] = []
    seen_edges: set[tuple[str, str, RelationshipType]] = set()

    # Pre-map symbols in imported files for fast, accurate resolution
    imported_classes: dict[str, Symbol] = {}
    imported_methods: dict[tuple[str, str], Symbol] = {}

    for imp_fp in imported_files:
        imp_file = repo.files.get(imp_fp)
        if not imp_file:
            continue
        for sym in imp_file.symbols:
            if sym.symbol_type in (SymbolType.CLASS, SymbolType.INTERFACE, SymbolType.ENUM):
                imported_classes[sym.name] = sym
            if "." in sym.qualified_name:
                cls, meth = sym.qualified_name.split(".", 1)
                imported_methods[(cls, meth)] = sym

    # Also include symbols defined in the current file
    for sym in source_file.symbols:
        if sym.symbol_type in (SymbolType.CLASS, SymbolType.INTERFACE, SymbolType.ENUM):
            imported_classes[sym.name] = sym
        if "." in sym.qualified_name:
            cls, meth = sym.qualified_name.split(".", 1)
            imported_methods[(cls, meth)] = sym

    # Process symbol bodies or file-level lines
    symbols_to_scan = source_file.symbols if source_file.symbols else [
        Symbol(
            id=file_path,
            name=Path(file_path).stem,
            qualified_name=Path(file_path).stem,
            symbol_type=SymbolType.UNKNOWN,
            file=file_path,
            line_start=1,
            line_end=len(lines),
        )
    ]

    for sym in symbols_to_scan:
        body_start = max(1, sym.line_start)
        body_end = min(sym.line_end, len(lines))
        body_lines = lines[body_start - 1: body_end]

        for rel_offset, line in enumerate(body_lines):
            abs_line = body_start + rel_offset
            stripped = line.strip()
            if not stripped or stripped.startswith("//") or stripped.startswith("#"):
                continue

            # ---------------------------------------------------------------
            # 1. Method Calls: Receiver.method(...)
            # ---------------------------------------------------------------
            for m in CALL_PATTERN.finditer(stripped):
                receiver = m.group(1)
                method_name = m.group(2)

                # Skip non-calls (e.g. 'if (', 'for (')
                if receiver in RESERVED_WORDS or method_name in RESERVED_WORDS:
                    continue

                # Determine effective class name
                target_cls = receiver
                if receiver in var_types:
                    target_cls = var_types[receiver]
                elif receiver == "this" or receiver == "super":
                    target_cls = sym.qualified_name.split(".")[0] if "." in sym.qualified_name else sym.name

                target_sym: Optional[Symbol] = None
                conf = Confidence.INFERRED

                # Priority 1: Check in imported files / current file with (Class, Method)
                if (target_cls, method_name) in imported_methods:
                    target_sym = imported_methods[(target_cls, method_name)]
                    conf = Confidence.CONFIRMED
                # Priority 2: Check in imported classes (matching class name)
                elif target_cls in imported_classes:
                    target_class_sym = imported_classes[target_cls]
                    target_sym = Symbol(
                        id=f"{target_class_sym.file}::{target_cls}.{method_name}",
                        name=method_name,
                        qualified_name=f"{target_cls}.{method_name}",
                        symbol_type=SymbolType.METHOD,
                        file=target_class_sym.file,
                        line_start=target_class_sym.line_start,
                        line_end=target_class_sym.line_end,
                    )
                    conf = Confidence.CONFIRMED
                # Priority 3: Global lookup if method name is distinct (not generic)
                elif (target_cls, method_name) in symbols_by_class_method:
                    matches = symbols_by_class_method[(target_cls, method_name)]
                    if matches:
                        target_sym = matches[0]
                        conf = Confidence.INFERRED if target_sym.file not in imported_files else Confidence.CONFIRMED
                elif method_name.lower() not in GENERIC_METHOD_NAMES and target_cls[0].isupper():
                    # Static call on known class in repo
                    if target_cls in classes_by_name:
                        cls_sym = classes_by_name[target_cls][0]
                        target_sym = Symbol(
                            id=f"{cls_sym.file}::{target_cls}.{method_name}",
                            name=method_name,
                            qualified_name=f"{target_cls}.{method_name}",
                            symbol_type=SymbolType.METHOD,
                            file=cls_sym.file,
                            line_start=cls_sym.line_start,
                            line_end=cls_sym.line_end,
                        )
                        conf = Confidence.INFERRED

                if target_sym and target_sym.id != sym.id:
                    edge_key = (sym.id, target_sym.id, RelationshipType.CALLS)
                    if edge_key not in seen_edges:
                        seen_edges.add(edge_key)
                        rels.append(Relationship(
                            source_id=sym.id,
                            target_id=target_sym.id,
                            relationship_type=RelationshipType.CALLS,
                            confidence=conf,
                            description=f"{sym.qualified_name} calls {target_sym.qualified_name}",
                            evidence=[Evidence(
                                file=file_path,
                                line_start=abs_line,
                                line_end=abs_line,
                                snippet=stripped[:200],
                                description=f"Invocation of {target_sym.qualified_name}",
                            )],
                        ))

            # ---------------------------------------------------------------
            # 2. Instantiations / Object Creations: ClassName(...)
            # ---------------------------------------------------------------
            for m in INSTANTIATION_PATTERN.finditer(stripped):
                cls_name = m.group(1)
                if cls_name in BUILTIN_TYPES or cls_name in RESERVED_WORDS:
                    continue

                target_class_sym: Optional[Symbol] = None
                conf = Confidence.INFERRED

                # Priority 1: Check in imported classes
                if cls_name in imported_classes:
                    target_class_sym = imported_classes[cls_name]
                    conf = Confidence.CONFIRMED
                # Priority 2: Check globally in repo classes
                elif cls_name in classes_by_name:
                    target_class_sym = classes_by_name[cls_name][0]
                    conf = Confidence.INFERRED if target_class_sym.file not in imported_files else Confidence.CONFIRMED

                if target_class_sym and target_class_sym.id != sym.id and target_class_sym.name != sym.name:
                    edge_key = (sym.id, target_class_sym.id, RelationshipType.CREATES)
                    if edge_key not in seen_edges:
                        seen_edges.add(edge_key)
                        rels.append(Relationship(
                            source_id=sym.id,
                            target_id=target_class_sym.id,
                            relationship_type=RelationshipType.CREATES,
                            confidence=conf,
                            description=f"{sym.qualified_name} creates {target_class_sym.name}",
                            evidence=[Evidence(
                                file=file_path,
                                line_start=abs_line,
                                line_end=abs_line,
                                snippet=stripped[:200],
                                description=f"Instantiation of {target_class_sym.name}",
                            )],
                        ))

            # ---------------------------------------------------------------
            # 3. Inheritance / Implementation: class A extends B
            # ---------------------------------------------------------------
            extends_match = EXTENDS_PATTERN.search(stripped)
            if extends_match:
                child_cls = extends_match.group(1)
                parent_cls = extends_match.group(2)
                if parent_cls not in BUILTIN_TYPES and parent_cls in classes_by_name:
                    parent_sym = classes_by_name[parent_cls][0]
                    child_id = f"{file_path}::{child_cls}"
                    edge_key = (child_id, parent_sym.id, RelationshipType.EXTENDS)
                    if edge_key not in seen_edges:
                        seen_edges.add(edge_key)
                        rels.append(Relationship(
                            source_id=child_id,
                            target_id=parent_sym.id,
                            relationship_type=RelationshipType.EXTENDS,
                            confidence=Confidence.CONFIRMED,
                            description=f"{child_cls} extends {parent_cls}",
                            evidence=[Evidence(
                                file=file_path,
                                line_start=abs_line,
                                line_end=abs_line,
                                snippet=stripped[:200],
                                description=f"Inheritance definition",
                            )],
                        ))

    return rels


# ---------------------------------------------------------------------------
# Database / Data Store Relationships
# ---------------------------------------------------------------------------

def _extract_db_relationships(
    file_path: str,
    source_file: SourceFile,
    lines: list[str],
) -> list[Relationship]:
    """Detect database, Firestore collection, and SQL access patterns."""
    rels: list[Relationship] = []
    seen: set[tuple[str, str, RelationshipType]] = set()

    for line_num, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("//") or stripped.startswith("#"):
            continue

        # Find Firestore .collection('name')
        for m in FIRESTORE_COLLECTION_RE.finditer(stripped):
            coll_name = m.group(1)
            # Determine if read or write
            is_write = bool(FIRESTORE_WRITE_RE.search(stripped))
            rel_type = RelationshipType.WRITES if is_write else RelationshipType.READS

            # Find enclosing symbol if possible
            enclosing_sym = _find_enclosing_symbol(source_file.symbols, line_num)
            source_id = enclosing_sym.id if enclosing_sym else file_path

            edge_key = (source_id, f"data::{coll_name}", rel_type)
            if edge_key not in seen:
                seen.add(edge_key)
                rels.append(Relationship(
                    source_id=source_id,
                    target_id=f"data::{coll_name}",
                    relationship_type=rel_type,
                    confidence=Confidence.CONFIRMED,
                    description=f"{'Writes to' if is_write else 'Reads from'} Firestore collection '{coll_name}'",
                    evidence=[Evidence(
                        file=file_path,
                        line_start=line_num,
                        line_end=line_num,
                        snippet=stripped[:200],
                        description=f"Firestore '{coll_name}' access",
                    )],
                ))

    return rels


def _find_enclosing_symbol(symbols: list[Symbol], line_num: int) -> Optional[Symbol]:
    """Find the most specific symbol enclosing a given line number."""
    candidates = [
        s for s in symbols
        if s.line_start <= line_num <= s.line_end
    ]
    if not candidates:
        return None
    # Return smallest enclosing range (most specific method)
    return min(candidates, key=lambda s: s.line_end - s.line_start)


def _deduplicate_relationships(rels: list[Relationship]) -> list[Relationship]:
    """Deduplicate relationships by (source, target, type)."""
    seen: set[tuple[str, str, RelationshipType]] = set()
    unique: list[Relationship] = []
    for r in rels:
        key = (r.source_id, r.target_id, r.relationship_type)
        if key not in seen:
            seen.add(key)
            unique.append(r)
    return unique
