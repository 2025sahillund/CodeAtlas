"""
Language Detection and File Classification.

Determines the programming language and role of a source file
based on extension, filename patterns, and content signals.
"""

from __future__ import annotations

import re
from pathlib import Path


# ---------------------------------------------------------------------------
# Language map: extension → language name
# ---------------------------------------------------------------------------

EXTENSION_LANGUAGE: dict[str, str] = {
    ".py": "Python",
    ".js": "JavaScript",
    ".ts": "TypeScript",
    ".jsx": "JavaScript",
    ".tsx": "TypeScript",
    ".dart": "Dart",
    ".java": "Java",
    ".kt": "Kotlin",
    ".swift": "Swift",
    ".go": "Go",
    ".rs": "Rust",
    ".cpp": "C++",
    ".cc": "C++",
    ".cxx": "C++",
    ".c": "C",
    ".h": "C/C++ Header",
    ".hpp": "C++ Header",
    ".cs": "C#",
    ".rb": "Ruby",
    ".php": "PHP",
    ".scala": "Scala",
    ".r": "R",
    ".m": "Objective-C",
    ".vue": "Vue",
    ".svelte": "Svelte",
    ".html": "HTML",
    ".css": "CSS",
    ".scss": "SCSS",
    ".sass": "SASS",
    ".less": "LESS",
    ".json": "JSON",
    ".yaml": "YAML",
    ".yml": "YAML",
    ".toml": "TOML",
    ".xml": "XML",
    ".md": "Markdown",
    ".sh": "Shell",
    ".bash": "Shell",
    ".zsh": "Shell",
    ".ps1": "PowerShell",
    ".sql": "SQL",
    ".graphql": "GraphQL",
    ".proto": "Protobuf",
    ".tf": "Terraform",
    ".gradle": "Gradle",
}

# ---------------------------------------------------------------------------
# Directories to ignore (configurable via settings)
# ---------------------------------------------------------------------------

DEFAULT_IGNORE_DIRS: set[str] = {
    ".git",
    ".github",
    ".dart_tool",
    ".idea",
    ".vscode",
    ".kilo",
    "node_modules",
    "build",
    "dist",
    "out",
    "__pycache__",
    ".venv",
    "venv",
    "env",
    ".env",
    "target",
    ".gradle",
    "gradle",
    "ios",          # Flutter platform-specific – skip for app logic analysis
    "macos",
    "linux",
    "windows",
    "web",
    ".dart_tool",
    "coverage",
    ".nyc_output",
    "vendor",
    "third_party",
}

# ---------------------------------------------------------------------------
# File patterns to ignore
# ---------------------------------------------------------------------------

IGNORE_FILE_PATTERNS: list[re.Pattern] = [
    re.compile(r"\.g\.dart$"),         # Generated Dart files
    re.compile(r"\.freezed\.dart$"),
    re.compile(r"\.pb\.dart$"),
    re.compile(r"_generated\.dart$"),
    re.compile(r"\.pb\.go$"),
    re.compile(r"\.generated\.(ts|js)$"),
    re.compile(r"^GeneratedPluginRegistrant"),
]

# Files that are never interesting for code analysis
IGNORE_EXTENSIONS: set[str] = {
    ".png", ".jpg", ".jpeg", ".gif", ".webp", ".svg", ".ico",
    ".mp4", ".mp3", ".wav", ".avi", ".mov",
    ".pdf", ".docx", ".xlsx", ".pptx",
    ".zip", ".tar", ".gz", ".rar", ".7z",
    ".exe", ".dll", ".so", ".dylib", ".a",
    ".class", ".pyc", ".pyo",
    ".lock",  # skip lock files (pubspec.lock, package-lock.json)
    ".map",   # source maps
    ".snap",  # jest snapshots
}

# Files with recognised special roles
CONFIG_FILENAMES: set[str] = {
    "pubspec.yaml", "pubspec.yml",
    "package.json", "package-lock.json",
    "requirements.txt", "setup.py", "setup.cfg", "pyproject.toml",
    "Cargo.toml", "Cargo.lock",
    "go.mod", "go.sum",
    "pom.xml", "build.gradle", "build.gradle.kts",
    "CMakeLists.txt",
    "Makefile", "makefile",
    "Dockerfile", "docker-compose.yml", "docker-compose.yaml",
    ".env.example", ".env.sample",
    "firebase.json", "firestore.rules", "firestore.indexes.json",
    "tsconfig.json", "jsconfig.json",
    "webpack.config.js", "vite.config.ts", "vite.config.js",
    "next.config.js", "nuxt.config.js",
    "analysis_options.yaml",
    ".gitignore", ".gitattributes",
    "README.md", "CHANGELOG.md",
}

DEPENDENCY_FILENAMES: set[str] = {
    "pubspec.yaml", "package.json", "requirements.txt",
    "Cargo.toml", "go.mod", "pom.xml",
    "build.gradle", "build.gradle.kts",
    "pyproject.toml", "setup.py",
    "Gemfile",
}

# Test directory / file patterns
TEST_PATTERNS: list[re.Pattern] = [
    re.compile(r"(^|[/_-])test([s]?)[/_-]"),          # test/, tests/, test_
    re.compile(r"[/_-]test([s]?)($|[/_-])"),
    re.compile(r"_test\.(dart|go|py|kt|java|ts|js)$"),
    re.compile(r"\.test\.(ts|js|tsx|jsx)$"),
    re.compile(r"\.spec\.(ts|js|tsx|jsx)$"),
    re.compile(r"(^|/)__tests__/"),
    re.compile(r"(^|/)test_"),
]

# Entry point filename patterns
ENTRY_POINT_PATTERNS: list[re.Pattern] = [
    re.compile(r"^main\.(dart|py|go|js|ts|java|kt|swift|rs)$"),
    re.compile(r"^app\.(py|js|ts|go)$"),
    re.compile(r"^index\.(js|ts|tsx|jsx)$"),
    re.compile(r"^server\.(py|js|ts)$"),
    re.compile(r"^__main__\.py$"),
    re.compile(r"^MainActivity\.(java|kt)$"),
    re.compile(r"^AppDelegate\.(swift|m)$"),
]


def detect_language(path: Path) -> str:
    """Return the language name for a given file path."""
    return EXTENSION_LANGUAGE.get(path.suffix.lower(), "Unknown")


def is_source_file(path: Path) -> bool:
    """True if this file should be indexed as a source file."""
    if path.suffix.lower() in IGNORE_EXTENSIONS:
        return False
    if detect_language(path) == "Unknown":
        return False
    if any(p.search(path.name) for p in IGNORE_FILE_PATTERNS):
        return False
    return True


def is_ignored_dir(name: str, extra_ignore: set[str] | None = None) -> bool:
    """True if this directory name should be skipped."""
    ignore_set = DEFAULT_IGNORE_DIRS | (extra_ignore or set())
    return name in ignore_set or name.startswith(".")


def is_test_file(path: Path) -> bool:
    """True if file path looks like a test file."""
    path_str = path.as_posix().lower()
    return any(p.search(path_str) for p in TEST_PATTERNS)


def is_entry_point(path: Path) -> bool:
    """True if filename looks like an application entry point."""
    return any(p.match(path.name) for p in ENTRY_POINT_PATTERNS)


def is_config_file(path: Path) -> bool:
    return path.name in CONFIG_FILENAMES


def is_dependency_file(path: Path) -> bool:
    return path.name in DEPENDENCY_FILENAMES
