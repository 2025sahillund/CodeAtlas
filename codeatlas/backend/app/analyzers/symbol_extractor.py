"""
Symbol Extractor.

Extracts symbols (classes, functions, methods, fields, interfaces) and imports
from source files using language-aware line and block scanning.

Supports Dart, Python, TypeScript, JavaScript, Java, Kotlin, Go, Swift, Rust.
No external parsing libraries required.
"""

from __future__ import annotations

import re
from pathlib import Path
from typing import Optional

from app.models.repository import Symbol, SymbolType, ImportRecord


# ---------------------------------------------------------------------------
# Keywords and non-symbol filters
# ---------------------------------------------------------------------------

RESERVED_WORDS = {
    "if", "else", "for", "while", "do", "switch", "case", "default",
    "return", "break", "continue", "throw", "rethrow", "try", "catch",
    "finally", "yield", "await", "async", "sync", "new", "this", "super",
    "true", "false", "null", "nil", "None", "True", "False",
    "var", "let", "const", "final", "late", "static", "abstract",
    "def", "class", "interface", "enum", "struct", "trait", "type",
    "import", "export", "from", "as", "show", "hide", "with", "extends",
    "implements", "part", "of", "library", "typedef", "mixin", "extension",
    "is", "in", "not", "and", "or", "pass", "raise", "except", "assert",
    "public", "private", "protected", "override", "void", "dynamic",
    "int", "double", "num", "bool", "String", "List", "Map", "Set",
    "Future", "Stream", "Widget", "BuildContext", "State", "StatefulWidget",
    "StatelessWidget", "Container", "Padding", "Center", "Column", "Row",
    "SizedBox", "Divider", "Card", "Text", "Icon", "Scaffold", "AppBar",
}

# ---------------------------------------------------------------------------
# Import patterns per language
# ---------------------------------------------------------------------------

IMPORT_PATTERNS: dict[str, re.Pattern] = {
    "Python": re.compile(r"^(?:from\s+([\w.]+)\s+import\s+([\w, *]+)|import\s+([\w., ]+))"),
    "Dart": re.compile(r"^(?:import|export)\s+['\"]([^'\"]+)['\"](?:\s+as\s+\w+)?(?:\s+show\s+([\w, ]+))?(?:\s+hide\s+([\w, ]+))?;"),
    "TypeScript": re.compile(r"^(?:import|export)\s+(?:type\s+)?(?:\{[^}]*\}|[\w*]+|\*\s+as\s+\w+)?\s*(?:from\s+)?['\"]([^'\"]+)['\"]"),
    "JavaScript": re.compile(r"^(?:import|export)\s+(?:\{[^}]*\}|[\w*]+|\*\s+as\s+\w+)?\s*(?:from\s+)?['\"]([^'\"]+)['\"]"),
    "Java": re.compile(r"^import\s+(?:static\s+)?([\w.]+(?:\.\*)?)\s*;"),
    "Kotlin": re.compile(r"^import\s+([\w.]+(?:\.\*)?)\s*"),
    "Go": re.compile(r'^\s*"([\w./]+)"'),
    "Swift": re.compile(r"^import\s+(\w+)"),
    "Rust": re.compile(r"^use\s+([\w:{}*, ]+)\s*;"),
    "C#": re.compile(r"^using\s+([\w.]+)\s*;"),
    "PHP": re.compile(r"^(?:use|require|include|require_once|include_once)\s+['\"]?([\w.\\/]+)['\"]?\s*;"),
}


def extract_symbols(file_path: str, content: str, language: str) -> list[Symbol]:
    """
    Extract symbols from source file content using language-specific parsing.
    Returns a list of Symbol objects with line references and block ranges.
    """
    if not content:
        return []

    if language == "Dart":
        return _extract_dart_symbols(file_path, content)
    elif language == "Python":
        return _extract_python_symbols(file_path, content)
    elif language in ("TypeScript", "JavaScript"):
        return _extract_ts_js_symbols(file_path, content, language)
    elif language in ("Java", "Kotlin", "C#"):
        return _extract_jvm_symbols(file_path, content, language)
    elif language == "Go":
        return _extract_go_symbols(file_path, content)
    elif language == "Swift":
        return _extract_swift_symbols(file_path, content)
    elif language == "Rust":
        return _extract_rust_symbols(file_path, content)
    else:
        return _extract_generic_symbols(file_path, content, language)


# ---------------------------------------------------------------------------
# Dart Symbol Extraction
# ---------------------------------------------------------------------------

# Matches Dart class/enum/mixin/extension declarations
DART_CLASS_RE = re.compile(
    r"^(?:abstract\s+)?(?:class|mixin|enum|extension)\s+(\w+)"
)

# Matches Dart constructor declarations: ClassName(...) or ClassName.named(...) or factory ClassName...
DART_CONSTRUCTOR_RE = re.compile(
    r"^\s*(?:const\s+|factory\s+)?([A-Z]\w+)(?:\.([a-zA-Z_]\w*))?\s*\("
)

# Matches Dart method/function signatures
DART_METHOD_RE = re.compile(
    r"^\s*(?:@\w+\s+)*(?:static\s+)?(?:override\s+)?(?:Future<[^>]+>|Stream<[^>]+>|void|int|double|num|bool|String|List(?:<[^>]+>)?|Map(?:<[^>]+>)?|Set(?:<[^>]+>)?|dynamic|Widget|State<[^>]+>|[A-Z]\w*(?:<[^>]+>)?)\s+([a-zA-Z_]\w*)\s*(?:<[^>]+>)?\s*\("
)

# Matches Dart getter/setter
DART_GETTER_RE = re.compile(
    r"^\s*(?:static\s+)?(?:[\w<>,\s]+)?\s*(?:get|set)\s+([a-zA-Z_]\w*)\s*(?:\(|=>|\{)"
)

# Matches Dart member field declarations (at class scope only)
DART_FIELD_RE = re.compile(
    r"^\s*(?:static\s+)?(?:final|const|late|var)\s+(?:(?:Future|Stream|void|int|double|num|bool|String|List|Map|Set|dynamic|Widget|[A-Z]\w*)(?:<[^>]+>)?\s+)?([a-zA-Z_]\w*)\s*(?:=|[;])"
)

# Matches top-level Dart function without return type or simple signature
DART_TOP_FUNC_RE = re.compile(
    r"^(?:Future<[^>]+>|void|int|bool|String|Widget|[A-Z]\w+)\s+([a-zA-Z_]\w*)\s*\("
)


def _extract_dart_symbols(file_path: str, content: str) -> list[Symbol]:
    """Extract classes, constructors, methods, getters, and fields from Dart code."""
    symbols: list[Symbol] = []
    lines = content.split("\n")

    current_class: Optional[str] = None
    class_brace_depth: int = 0
    brace_depth: int = 0

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()

        # Count brace changes on this line
        # Simple string/comment strip for brace counting
        clean_line = _strip_comments_and_strings(line)
        open_braces = clean_line.count("{")
        close_braces = clean_line.count("}")

        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            brace_depth += open_braces - close_braces
            if current_class and brace_depth < class_brace_depth:
                current_class = None
            continue

        # Check for class/enum/mixin/extension definition at top-level
        class_match = DART_CLASS_RE.match(stripped)
        if class_match and brace_depth == 0:
            class_name = class_match.group(1)
            sym_type = SymbolType.ENUM if "enum" in stripped else SymbolType.CLASS
            current_class = class_name
            class_brace_depth = brace_depth + 1

            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{class_name}",
                name=class_name,
                qualified_name=class_name,
                symbol_type=sym_type,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
                visibility="private" if class_name.startswith("_") else "public",
            ))

            brace_depth += open_braces - close_braces
            continue

        # Inside class scope (brace_depth == class_brace_depth == 1)
        if current_class and brace_depth == class_brace_depth:
            # 1. Constructor check
            ctor_match = DART_CONSTRUCTOR_RE.match(stripped)
            if ctor_match:
                cls_prefix = ctor_match.group(1)
                named_part = ctor_match.group(2)
                if cls_prefix == current_class or cls_prefix == current_class.lstrip("_"):
                    ctor_name = f"{cls_prefix}.{named_part}" if named_part else cls_prefix
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{current_class}.{ctor_name}",
                        name=named_part or cls_prefix,
                        qualified_name=f"{current_class}.{ctor_name}",
                        symbol_type=SymbolType.METHOD,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                    ))
                    brace_depth += open_braces - close_braces
                    continue

            # 2. Getter/Setter check
            get_match = DART_GETTER_RE.match(stripped)
            if get_match:
                prop_name = get_match.group(1)
                if prop_name not in RESERVED_WORDS:
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{current_class}.{prop_name}",
                        name=prop_name,
                        qualified_name=f"{current_class}.{prop_name}",
                        symbol_type=SymbolType.METHOD,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                        visibility="private" if prop_name.startswith("_") else "public",
                    ))
                    brace_depth += open_braces - close_braces
                    continue

            # 3. Method check
            method_match = DART_METHOD_RE.match(stripped)
            if method_match:
                method_name = method_match.group(1)
                if method_name not in RESERVED_WORDS:
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{current_class}.{method_name}",
                        name=method_name,
                        qualified_name=f"{current_class}.{method_name}",
                        symbol_type=SymbolType.METHOD,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                        visibility="private" if method_name.startswith("_") else "public",
                    ))
                    brace_depth += open_braces - clean_line.count("}")
                    if current_class and brace_depth < class_brace_depth:
                        current_class = None
                    continue

            # 4. Class-level Field / Variable check (only at class scope)
            field_match = DART_FIELD_RE.match(stripped)
            if field_match:
                field_name = field_match.group(1)
                if field_name not in RESERVED_WORDS:
                    symbols.append(Symbol(
                        id=f"{file_path}::{current_class}.{field_name}",
                        name=field_name,
                        qualified_name=f"{current_class}.{field_name}",
                        symbol_type=SymbolType.VARIABLE,
                        file=file_path,
                        line_start=line_num,
                        line_end=line_num,
                        visibility="private" if field_name.startswith("_") else "public",
                    ))

        # Top-level function check (brace_depth == 0)
        elif brace_depth == 0:
            top_func_match = DART_METHOD_RE.match(stripped) or DART_TOP_FUNC_RE.match(stripped)
            if top_func_match:
                func_name = top_func_match.group(1)
                if func_name not in RESERVED_WORDS:
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{func_name}",
                        name=func_name,
                        qualified_name=func_name,
                        symbol_type=SymbolType.FUNCTION,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                        visibility="private" if func_name.startswith("_") else "public",
                    ))

        # Update brace depth
        brace_depth += open_braces - close_braces
        if current_class and brace_depth < class_brace_depth:
            current_class = None

    return _deduplicate_symbols(symbols)


# ---------------------------------------------------------------------------
# Python Symbol Extraction
# ---------------------------------------------------------------------------

PY_CLASS_RE = re.compile(r"^class\s+([a-zA-Z_]\w*)(?:\s*\(([^)]*)\))?:")
PY_FUNC_RE = re.compile(r"^( *)(?:async\s+)?def\s+([a-zA-Z_]\w*)\s*\(")


def _extract_python_symbols(file_path: str, content: str) -> list[Symbol]:
    """Extract Python classes, methods, and functions with indentation tracking."""
    symbols: list[Symbol] = []
    lines = content.split("\n")

    current_class: Optional[str] = None
    class_indent: int = 0

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())

        # Reset class context if indent drops to or below class level
        if current_class and indent <= class_indent and not line.startswith(" " * (class_indent + 1)):
            current_class = None

        # Class match
        class_match = PY_CLASS_RE.match(stripped)
        if class_match and indent == 0:
            class_name = class_match.group(1)
            current_class = class_name
            class_indent = indent
            end_line = _find_indent_block_end(lines, line_idx, indent)
            symbols.append(Symbol(
                id=f"{file_path}::{class_name}",
                name=class_name,
                qualified_name=class_name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            continue

        # Function / Method match
        func_match = PY_FUNC_RE.match(line)
        if func_match:
            leading_spaces = len(func_match.group(1))
            func_name = func_match.group(2)
            if func_name in RESERVED_WORDS:
                continue

            end_line = _find_indent_block_end(lines, line_idx, leading_spaces)

            if current_class and leading_spaces > class_indent:
                # Class method
                qual_name = f"{current_class}.{func_name}"
                symbols.append(Symbol(
                    id=f"{file_path}::{qual_name}",
                    name=func_name,
                    qualified_name=qual_name,
                    symbol_type=SymbolType.METHOD,
                    file=file_path,
                    line_start=line_num,
                    line_end=end_line,
                ))
            elif leading_spaces == 0:
                # Top-level function
                symbols.append(Symbol(
                    id=f"{file_path}::{func_name}",
                    name=func_name,
                    qualified_name=func_name,
                    symbol_type=SymbolType.FUNCTION,
                    file=file_path,
                    line_start=line_num,
                    line_end=end_line,
                ))

    return _deduplicate_symbols(symbols)


# ---------------------------------------------------------------------------
# TypeScript / JavaScript Symbol Extraction
# ---------------------------------------------------------------------------

TS_CLASS_RE = re.compile(r"^(?:export\s+)?(?:default\s+)?(?:abstract\s+)?class\s+([a-zA-Z_]\w*)")
TS_INTERFACE_RE = re.compile(r"^(?:export\s+)?(?:interface|type)\s+([a-zA-Z_]\w*)")
TS_ENUM_RE = re.compile(r"^(?:export\s+)?enum\s+([a-zA-Z_]\w*)")
TS_FUNC_RE = re.compile(r"^(?:export\s+)?(?:default\s+)?(?:async\s+)?function\s+([a-zA-Z_]\w*)\s*[(<]")
TS_CONST_FUNC_RE = re.compile(r"^(?:export\s+)?(?:const|let|var)\s+([a-zA-Z_]\w*)\s*=\s*(?:async\s*)?(?:\([^)]*\)|[a-zA-Z_]\w*)\s*=>")
TS_METHOD_RE = re.compile(r"^\s*(?:public\s+|private\s+|protected\s+)?(?:static\s+)?(?:async\s+)?([a-zA-Z_]\w*)\s*\([^)]*\)\s*(?::\s*[^\{]+)?\s*\{")


def _extract_ts_js_symbols(file_path: str, content: str, language: str) -> list[Symbol]:
    """Extract TS/JS classes, interfaces, functions, methods."""
    symbols: list[Symbol] = []
    lines = content.split("\n")

    current_class: Optional[str] = None
    class_brace_depth: int = 0
    brace_depth: int = 0

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()

        clean_line = _strip_comments_and_strings(line)
        open_braces = clean_line.count("{")
        close_braces = clean_line.count("}")

        if not stripped or stripped.startswith("//") or stripped.startswith("/*") or stripped.startswith("*"):
            brace_depth += open_braces - close_braces
            if current_class and brace_depth < class_brace_depth:
                current_class = None
            continue

        # Class
        m = TS_CLASS_RE.match(stripped)
        if m and brace_depth == 0:
            name = m.group(1)
            current_class = name
            class_brace_depth = brace_depth + 1
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            brace_depth += open_braces - close_braces
            continue

        # Interface / Type
        m = TS_INTERFACE_RE.match(stripped)
        if m and brace_depth == 0:
            name = m.group(1)
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.INTERFACE,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            brace_depth += open_braces - close_braces
            continue

        # Enum
        m = TS_ENUM_RE.match(stripped)
        if m and brace_depth == 0:
            name = m.group(1)
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.ENUM,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            brace_depth += open_braces - close_braces
            continue

        # Function (top-level)
        if brace_depth == 0:
            m = TS_FUNC_RE.match(stripped) or TS_CONST_FUNC_RE.match(stripped)
            if m:
                name = m.group(1)
                if name not in RESERVED_WORDS:
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{name}",
                        name=name,
                        qualified_name=name,
                        symbol_type=SymbolType.FUNCTION,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                    ))
                    brace_depth += open_braces - close_braces
                    continue

        # Method inside class
        if current_class and brace_depth == class_brace_depth:
            m = TS_METHOD_RE.match(stripped)
            if m:
                name = m.group(1)
                if name not in RESERVED_WORDS and name not in ("constructor", "if", "for", "while", "switch"):
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{current_class}.{name}",
                        name=name,
                        qualified_name=f"{current_class}.{name}",
                        symbol_type=SymbolType.METHOD,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                    ))

        brace_depth += open_braces - close_braces
        if current_class and brace_depth < class_brace_depth:
            current_class = None

    return _deduplicate_symbols(symbols)


# ---------------------------------------------------------------------------
# JVM (Java, Kotlin) Symbol Extraction
# ---------------------------------------------------------------------------

JVM_CLASS_RE = re.compile(
    r"^(?:public\s+|private\s+|protected\s+|open\s+|data\s+|sealed\s+|abstract\s+)*(?:class|interface|enum class|enum)\s+([a-zA-Z_]\w*)"
)
JVM_METHOD_RE = re.compile(
    r"^\s*(?:public\s+|private\s+|protected\s+|override\s+|suspend\s+|static\s+|final\s+)*(?:fun\s+|[\w<>[\],\s]+\s+)([a-zA-Z_]\w*)\s*[(<]"
)


def _extract_jvm_symbols(file_path: str, content: str, language: str) -> list[Symbol]:
    symbols: list[Symbol] = []
    lines = content.split("\n")
    current_class: Optional[str] = None
    class_brace_depth: int = 0
    brace_depth: int = 0

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()
        clean = _strip_comments_and_strings(line)
        open_b = clean.count("{")
        close_b = clean.count("}")

        if not stripped or stripped.startswith("//") or stripped.startswith("/*"):
            brace_depth += open_b - close_b
            if current_class and brace_depth < class_brace_depth:
                current_class = None
            continue

        m = JVM_CLASS_RE.match(stripped)
        if m and brace_depth == 0:
            name = m.group(1)
            current_class = name
            class_brace_depth = brace_depth + 1
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            brace_depth += open_b - close_b
            continue

        if current_class and brace_depth == class_brace_depth:
            m = JVM_METHOD_RE.match(stripped)
            if m:
                name = m.group(1)
                if name not in RESERVED_WORDS:
                    end_line = _find_brace_block_end(lines, line_idx)
                    symbols.append(Symbol(
                        id=f"{file_path}::{current_class}.{name}",
                        name=name,
                        qualified_name=f"{current_class}.{name}",
                        symbol_type=SymbolType.METHOD,
                        file=file_path,
                        line_start=line_num,
                        line_end=end_line,
                    ))

        brace_depth += open_b - close_b
        if current_class and brace_depth < class_brace_depth:
            current_class = None

    return _deduplicate_symbols(symbols)


# ---------------------------------------------------------------------------
# Go, Swift, Rust, Generic Symbol Extraction
# ---------------------------------------------------------------------------

def _extract_go_symbols(file_path: str, content: str) -> list[Symbol]:
    symbols: list[Symbol] = []
    lines = content.split("\n")
    struct_re = re.compile(r"^type\s+([a-zA-Z_]\w*)\s+(?:struct|interface)")
    method_re = re.compile(r"^func\s+\(\s*\w+\s+\*?([a-zA-Z_]\w*)\s*\)\s*([a-zA-Z_]\w*)\s*\(")
    func_re = re.compile(r"^func\s+([a-zA-Z_]\w*)\s*\(")

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()

        m = struct_re.match(stripped)
        if m:
            name = m.group(1)
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            continue

        m = method_re.match(stripped)
        if m:
            recv = m.group(1)
            name = m.group(2)
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{recv}.{name}",
                name=name,
                qualified_name=f"{recv}.{name}",
                symbol_type=SymbolType.METHOD,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            continue

        m = func_re.match(stripped)
        if m:
            name = m.group(1)
            if name not in RESERVED_WORDS:
                end_line = _find_brace_block_end(lines, line_idx)
                symbols.append(Symbol(
                    id=f"{file_path}::{name}",
                    name=name,
                    qualified_name=name,
                    symbol_type=SymbolType.FUNCTION,
                    file=file_path,
                    line_start=line_num,
                    line_end=end_line,
                ))

    return _deduplicate_symbols(symbols)


def _extract_swift_symbols(file_path: str, content: str) -> list[Symbol]:
    symbols: list[Symbol] = []
    lines = content.split("\n")
    class_re = re.compile(r"^(?:public\s+|private\s+|open\s+|final\s+)*(?:class|struct|protocol|enum)\s+([a-zA-Z_]\w*)")
    func_re = re.compile(r"^\s*(?:public\s+|private\s+|override\s+|static\s+)*func\s+([a-zA-Z_]\w*)\s*\(")

    current_class: Optional[str] = None
    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()

        m = class_re.match(stripped)
        if m:
            name = m.group(1)
            current_class = name
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            continue

        m = func_re.match(stripped)
        if m:
            name = m.group(1)
            if name not in RESERVED_WORDS:
                qual = f"{current_class}.{name}" if current_class else name
                st = SymbolType.METHOD if current_class else SymbolType.FUNCTION
                end_line = _find_brace_block_end(lines, line_idx)
                symbols.append(Symbol(
                    id=f"{file_path}::{qual}",
                    name=name,
                    qualified_name=qual,
                    symbol_type=st,
                    file=file_path,
                    line_start=line_num,
                    line_end=end_line,
                ))

    return _deduplicate_symbols(symbols)


def _extract_rust_symbols(file_path: str, content: str) -> list[Symbol]:
    symbols: list[Symbol] = []
    lines = content.split("\n")
    struct_re = re.compile(r"^(?:pub\s+)?(?:struct|enum|trait)\s+([a-zA-Z_]\w*)")
    fn_re = re.compile(r"^\s*(?:pub\s+)?(?:async\s+)?fn\s+([a-zA-Z_]\w*)\s*[\(<]")

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()

        m = struct_re.match(stripped)
        if m:
            name = m.group(1)
            end_line = _find_brace_block_end(lines, line_idx)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=end_line,
            ))
            continue

        m = fn_re.match(stripped)
        if m:
            name = m.group(1)
            if name not in RESERVED_WORDS:
                end_line = _find_brace_block_end(lines, line_idx)
                symbols.append(Symbol(
                    id=f"{file_path}::{name}",
                    name=name,
                    qualified_name=name,
                    symbol_type=SymbolType.FUNCTION,
                    file=file_path,
                    line_start=line_num,
                    line_end=end_line,
                ))

    return _deduplicate_symbols(symbols)


def _extract_generic_symbols(file_path: str, content: str, language: str) -> list[Symbol]:
    symbols: list[Symbol] = []
    lines = content.split("\n")
    gen_class = re.compile(r"^(?:class|struct|interface)\s+([a-zA-Z_]\w*)")
    gen_func = re.compile(r"^(?:function|def|func)\s+([a-zA-Z_]\w*)\s*\(")

    for line_idx, line in enumerate(lines):
        line_num = line_idx + 1
        stripped = line.strip()

        m = gen_class.match(stripped)
        if m:
            name = m.group(1)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.CLASS,
                file=file_path,
                line_start=line_num,
                line_end=_find_brace_block_end(lines, line_idx),
            ))
            continue

        m = gen_func.match(stripped)
        if m:
            name = m.group(1)
            symbols.append(Symbol(
                id=f"{file_path}::{name}",
                name=name,
                qualified_name=name,
                symbol_type=SymbolType.FUNCTION,
                file=file_path,
                line_start=line_num,
                line_end=_find_brace_block_end(lines, line_idx),
            ))

    return _deduplicate_symbols(symbols)


# ---------------------------------------------------------------------------
# Import Extraction
# ---------------------------------------------------------------------------

def extract_imports(file_path: str, content: str, language: str) -> list[ImportRecord]:
    """Extract import statements from a source file."""
    pattern = IMPORT_PATTERNS.get(language)
    if not pattern:
        return []

    records: list[ImportRecord] = []
    lines = content.split("\n")
    in_go_block = False

    for line_num, line in enumerate(lines, start=1):
        stripped = line.strip()
        if not stripped:
            continue

        # Go import block
        if language == "Go":
            if stripped == "import (":
                in_go_block = True
                continue
            if in_go_block:
                if stripped == ")":
                    in_go_block = False
                    continue
                match = pattern.match(stripped)
                if match:
                    records.append(ImportRecord(
                        file=file_path,
                        imported_module=match.group(1),
                        line=line_num,
                        raw=stripped,
                    ))
            elif stripped.startswith("import ") and '"' in stripped:
                match = pattern.match(stripped.replace("import ", ""))
                if match:
                    records.append(ImportRecord(
                        file=file_path,
                        imported_module=match.group(1),
                        line=line_num,
                        raw=stripped,
                    ))
            continue

        # Python imports
        if language == "Python":
            if not (stripped.startswith("import ") or stripped.startswith("from ")):
                continue
            match = pattern.match(stripped)
            if not match:
                continue
            if match.group(1):  # from X import Y
                module = match.group(1)
                names = [n.strip() for n in match.group(2).split(",") if n.strip()]
            elif match.group(3):  # import X
                module = match.group(3).split(",")[0].strip()
                names = []
            else:
                continue
            records.append(ImportRecord(
                file=file_path,
                imported_module=module,
                imported_names=names,
                line=line_num,
                raw=stripped,
            ))
            continue

        # Dart, TS, JS, Java, etc.
        if not (stripped.startswith("import ") or stripped.startswith("export ") or
                stripped.startswith("from ") or stripped.startswith("use ") or
                stripped.startswith("using ") or stripped.startswith("require(") or
                stripped.startswith("include ")):
            continue

        match = pattern.match(stripped)
        if match:
            module = match.group(1) if match.lastindex and match.lastindex >= 1 else stripped
            records.append(ImportRecord(
                file=file_path,
                imported_module=module.strip("'\""),
                line=line_num,
                raw=stripped,
            ))

    return records


# ---------------------------------------------------------------------------
# Block end helpers
# ---------------------------------------------------------------------------

def _find_brace_block_end(lines: list[str], start_idx: int) -> int:
    """Find the line index (1-indexed) where the enclosing { } block ends."""
    depth = 0
    found_open = False

    for i in range(start_idx, min(start_idx + 1000, len(lines))):
        clean = _strip_comments_and_strings(lines[i])
        for ch in clean:
            if ch == "{":
                depth += 1
                found_open = True
            elif ch == "}":
                depth -= 1
                if found_open and depth <= 0:
                    return i + 1  # 1-indexed

        # Arrow function or semicolon on single line definition (no braces)
        if not found_open and (";" in clean or "=>" in clean) and i == start_idx:
            return i + 1

    return min(start_idx + 50, len(lines))


def _find_indent_block_end(lines: list[str], start_idx: int, base_indent: int) -> int:
    """Find the line where a Python indentation block ends."""
    for i in range(start_idx + 1, min(start_idx + 500, len(lines))):
        line = lines[i]
        if not line.strip() or line.strip().startswith("#"):
            continue
        indent = len(line) - len(line.lstrip())
        if indent <= base_indent:
            return i  # previous line was end of block (1-indexed = i)
    return min(start_idx + 50, len(lines))


def _strip_comments_and_strings(line: str) -> str:
    """Remove string literals and line comments for accurate brace/syntax counting."""
    # Remove single line comments
    if "//" in line:
        line = line[:line.index("//")]
    if "#" in line:
        line = line[:line.index("#")]
    # Simple regex to replace quoted strings with spaces
    line = re.sub(r"(['\"]).*?\1", " ", line)
    return line


def _deduplicate_symbols(symbols: list[Symbol]) -> list[Symbol]:
    """Deduplicate symbols by ID preserving first appearance."""
    seen: set[str] = set()
    result: list[Symbol] = []
    for s in symbols:
        if s.id not in seen:
            seen.add(s.id)
            result.append(s)
    return result
