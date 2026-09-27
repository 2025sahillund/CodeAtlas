"""
CodeAtlas Project Intelligence & Architecture Overview Service.

Provides repository-wide intelligence:
1. Architecture Summary (files, symbols, languages, frameworks, layers)
2. Module Explorer (derived modules, cohesion, dependencies, in/out relationships)
3. API Intelligence (detected HTTP routes, methods, handlers, evidence)
4. Data / Storage Intelligence (detected storage systems, collections/tables, evidence)
5. Dynamic Architecture Map (grouped graph with cross-layer dependencies & evidence)

Generic and evidence-based. No hardcoded repository rules.
"""

from __future__ import annotations

import posixpath
import re
from collections import defaultdict
from pathlib import Path
from typing import Optional, Any

from app.models.repository import (
    Repository, Symbol, SourceFile, Relationship,
    RelationshipType, Confidence, Evidence, SymbolType,
    ApiEndpoint, StorageTechnology, RepositoryModule,
    ArchitectureLayer, ArchitectureGraphNode, ArchitectureGraphEdge,
    ArchitectureGraph, ProjectIntelligence,
    TreeNodeType, RelationshipRef, RepositoryTreeNode, RepositoryTree,
)
from app.services.feature_tracer import _infer_role, _shorten_id


# ---------------------------------------------------------------------------
# API Route Regex Patterns
# ---------------------------------------------------------------------------

FASTAPI_METHOD_ROUTE_RE = re.compile(
    r"@(?:app|router|api|[a-zA-Z_]\w*)\.(get|post|put|delete|patch|options|head)\(\s*['\"]([^'\"]+)['\"]",
    re.IGNORECASE,
)

FLASK_ROUTE_RE = re.compile(
    r"@(?:app|router|api|[a-zA-Z_]\w*)\.route\(\s*['\"]([^'\"]+)['\"](?:\s*,\s*methods\s*=\s*\[(.*?)\])?",
    re.IGNORECASE,
)

EXPRESS_ROUTE_RE = re.compile(
    r"(?:app|router)\.(get|post|put|delete|patch)\(\s*['\"]([^'\"]+)['\"]",
    re.IGNORECASE,
)

PYTHON_DEF_RE = re.compile(
    r"def\s+([a-zA-Z_]\w*)\s*\("
)

PYTHON_DOCSTRING_RE = re.compile(
    r'"""(.*?)"""|\'\'\'(.*?)\'\'\'',
    re.DOTALL,
)


# ---------------------------------------------------------------------------
# Storage & Database Patterns
# ---------------------------------------------------------------------------

FIRESTORE_COLLECTION_RE = re.compile(
    r"\.collection\(\s*['\"]([^'\"]+)['\"]\s*\)"
)

SQL_TABLE_RE = re.compile(
    r"(?:FROM|JOIN|INTO|UPDATE|TABLE)\s+['\"`]?([a-zA-Z_]\w+)['\"`]?",
    re.IGNORECASE,
)

PREFERENCES_KEY_RE = re.compile(
    r"(?:getString|getInt|getBool|setString|setInt|setBool)\(\s*['\"]([^'\"]+)['\"]"
)


# ---------------------------------------------------------------------------
# Public Entry Point
# ---------------------------------------------------------------------------

def analyze_project_intelligence(repo: Repository) -> ProjectIntelligence:
    """
    Generate comprehensive repository intelligence for the given indexed repository.
    """
    # 1. Frameworks
    frameworks = _detect_frameworks(repo)

    # 2. Architecture Layers
    layers = _infer_architecture_layers(repo)

    # 3. Modules
    modules = _derive_modules(repo)

    # 4. API Endpoints
    api_endpoints = _detect_api_endpoints(repo)

    # 5. Data & Storage Technologies
    storage_technologies = _detect_storage_technologies(repo)

    # 6. Dynamic Architecture Graph
    architecture_graph = _build_architecture_graph(repo, layers)

    # 7. Overall Summary Description
    summary_description = _generate_summary_description(
        repo=repo,
        frameworks=frameworks,
        layers=layers,
        modules=modules,
        api_endpoints=api_endpoints,
        storage_technologies=storage_technologies,
    )

    return ProjectIntelligence(
        repository_id=repo.id,
        repository_name=repo.name,
        total_files=repo.total_files,
        source_files=repo.source_files,
        total_symbols=len(repo.symbols),
        total_relationships=len(repo.relationships),
        languages=dict(sorted(repo.languages.items(), key=lambda x: x[1], reverse=True)),
        entry_points=repo.entry_points[:10],
        detected_frameworks=frameworks,
        layers=layers,
        modules=modules,
        api_endpoints=api_endpoints,
        storage_technologies=storage_technologies,
        architecture_graph=architecture_graph,
        summary_description=summary_description,
    )


# ---------------------------------------------------------------------------
# 1. Framework Detection
# ---------------------------------------------------------------------------

def _detect_frameworks(repo: Repository) -> list[str]:
    """Detect active frameworks from dependencies and source imports."""
    frameworks: set[str] = set()

    # Check dependency file contents
    for dep_file_path in repo.dependency_files:
        sf = repo.files.get(dep_file_path)
        content = (sf._content or "").lower() if sf else ""
        dep_lower = dep_file_path.lower()

        if "pubspec" in dep_lower:
            if "flutter:" in content or "sdk: flutter" in content:
                frameworks.add("Flutter")
                frameworks.add("Dart")
            if "cloud_firestore" in content or "firebase_core" in content:
                frameworks.add("Firebase")
            if "google_mlkit" in content or "google_ml_kit" in content:
                frameworks.add("Google ML Kit")
            if "provider" in content:
                frameworks.add("Provider State")

        elif "package.json" in dep_lower:
            if "next" in content:
                frameworks.add("Next.js")
            if "react" in content:
                frameworks.add("React")
            if "express" in content:
                frameworks.add("Express")
            if "vue" in content:
                frameworks.add("Vue")
            if "axios" in content:
                frameworks.add("Axios")

        elif "requirements" in dep_lower or "pipfile" in dep_lower or "pyproject" in dep_lower:
            if "fastapi" in content:
                frameworks.add("FastAPI")
            if "flask" in content:
                frameworks.add("Flask")
            if "django" in content:
                frameworks.add("Django")
            if "torch" in content or "pytorch" in content:
                frameworks.add("PyTorch")
            if "tensorflow" in content:
                frameworks.add("TensorFlow")
            if "sqlalchemy" in content:
                frameworks.add("SQLAlchemy")
            if "pydantic" in content:
                frameworks.add("Pydantic")

    # Check file contents and imports
    for fp, sf in repo.files.items():
        lang = sf.language
        if lang == "Dart":
            frameworks.add("Dart")
            if any("package:flutter" in imp.imported_module for imp in sf.imports):
                frameworks.add("Flutter")
            if any("cloud_firestore" in imp.imported_module for imp in sf.imports):
                frameworks.add("Firebase")
        elif lang == "Python":
            if any("fastapi" in imp.imported_module for imp in sf.imports):
                frameworks.add("FastAPI")
            if any("flask" in imp.imported_module for imp in sf.imports):
                frameworks.add("Flask")
            if any("django" in imp.imported_module for imp in sf.imports):
                frameworks.add("Django")
        elif lang in ("TypeScript", "JavaScript", "TSX", "JSX"):
            if any("react" in imp.imported_module for imp in sf.imports):
                frameworks.add("React")

    return sorted(frameworks)


# ---------------------------------------------------------------------------
# 2. Architecture Layers
# ---------------------------------------------------------------------------

def _infer_architecture_layers(repo: Repository) -> list[ArchitectureLayer]:
    """Classify repository files and symbols into canonical architectural layers."""
    layer_map: dict[str, dict[str, Any]] = {
        "UI / Screens": {"role": "UI / Presentation", "files": set(), "symbols": set()},
        "API / Controllers": {"role": "API & Route Handling", "files": set(), "symbols": set()},
        "Services": {"role": "Business Logic & Orchestration", "files": set(), "symbols": set()},
        "Models": {"role": "Data Structures & Entities", "files": set(), "symbols": set()},
        "Storage & Data Access": {"role": "Persistence & Database Access", "files": set(), "symbols": set()},
        "External Integrations": {"role": "Third-Party Clients & Adapters", "files": set(), "symbols": set()},
        "Tests": {"role": "Verification & Test Suites", "files": set(), "symbols": set()},
        "Configuration": {"role": "Application Configuration & Setup", "files": set(), "symbols": set()},
    }

    for fp, sf in repo.files.items():
        if sf.is_test:
            layer_map["Tests"]["files"].add(fp)
            for s in sf.symbols:
                layer_map["Tests"]["symbols"].add(s.name)
            continue

        if sf.is_config:
            layer_map["Configuration"]["files"].add(fp)
            for s in sf.symbols:
                layer_map["Configuration"]["symbols"].add(s.name)
            continue

        fp_lower = fp.lower()

        # Classify by file path & role
        if any(k in fp_lower for k in ("screen", "page", "view", "widget", "component", "ui")):
            layer = "UI / Screens"
        elif any(k in fp_lower for k in ("route", "controller", "endpoint", "handler", "api")):
            layer = "API / Controllers"
        elif any(k in fp_lower for k in ("service", "manager", "provider", "bloc", "store", "auth")):
            layer = "Services"
        elif any(k in fp_lower for k in ("model", "entity", "schema", "dto", "types")):
            layer = "Models"
        elif any(k in fp_lower for k in ("repo", "dao", "db", "database", "storage", "firestore", "sql")):
            layer = "Storage & Data Access"
        elif any(k in fp_lower for k in ("ocr", "scanner", "client", "sdk", "http", "export", "pdf")):
            layer = "External Integrations"
        else:
            # Fallback by symbol roles
            role = _infer_role(fp, Path(fp).stem, [])
            if "UI" in role or "Screen" in role:
                layer = "UI / Screens"
            elif "Service" in role or "Auth" in role:
                layer = "Services"
            elif "Model" in role:
                layer = "Models"
            elif "API" in role or "Route" in role:
                layer = "API / Controllers"
            elif "Store" in role or "DAO" in role:
                layer = "Storage & Data Access"
            elif "OCR" in role or "Scanner" in role or "Export" in role:
                layer = "External Integrations"
            elif "Config" in role:
                layer = "Configuration"
            else:
                layer = "Services"

        layer_map[layer]["files"].add(fp)
        for s in sf.symbols:
            layer_map[layer]["symbols"].add(s.name)

    layers: list[ArchitectureLayer] = []
    for layer_name, data in layer_map.items():
        if data["files"] or data["symbols"]:
            layers.append(ArchitectureLayer(
                name=layer_name,
                role=data["role"],
                file_count=len(data["files"]),
                symbol_count=len(data["symbols"]),
                files=sorted(data["files"]),
                symbols=sorted(data["symbols"])[:50],
            ))

    return layers


# ---------------------------------------------------------------------------
# 3. Module Explorer
# ---------------------------------------------------------------------------

def _derive_modules(repo: Repository) -> list[RepositoryModule]:
    """Group source files into logical modules based on repository directory hierarchy."""
    module_files: dict[str, list[str]] = {}

    for fp in repo.files.keys():
        parts = fp.replace("\\", "/").split("/")
        if len(parts) == 1:
            # Top-level file
            mod_path = "root"
        elif parts[0] in ("lib", "app", "src") and len(parts) >= 3:
            # e.g. lib/screens, app/api, src/components
            mod_path = f"{parts[0]}/{parts[1]}"
        elif len(parts) >= 2:
            mod_path = parts[0]
        else:
            mod_path = "root"

        if mod_path not in module_files:
            module_files[mod_path] = []
        module_files[mod_path].append(fp)

    # Build file -> module lookup
    file_to_module: dict[str, str] = {}
    for mod_path, files in module_files.items():
        for f in files:
            file_to_module[f] = mod_path

    # Count cross-module relationships
    incoming_counts: dict[str, int] = {m: 0 for m in module_files}
    outgoing_counts: dict[str, int] = {m: 0 for m in module_files}
    module_deps: dict[str, set[str]] = {m: set() for m in module_files}

    for rel in repo.relationships:
        src_file = rel.source_id.split("::")[0]
        tgt_file = rel.target_id.split("::")[0]

        src_mod = file_to_module.get(src_file)
        tgt_mod = file_to_module.get(tgt_file)

        if src_mod and tgt_mod and src_mod != tgt_mod:
            outgoing_counts[src_mod] += 1
            incoming_counts[tgt_mod] += 1
            module_deps[src_mod].add(tgt_mod)

    modules: list[RepositoryModule] = []
    for mod_path, files in module_files.items():
        name = mod_path.split("/")[-1] if "/" in mod_path else mod_path
        if name == "root":
            name = "Root / Top-Level"

        # Collect symbols in this module
        mod_symbols: list[str] = []
        for fp in files:
            sf = repo.files.get(fp)
            if sf:
                mod_symbols.extend([s.name for s in sf.symbols])

        role = _infer_role(mod_path, name, [])

        modules.append(RepositoryModule(
            name=name,
            path=mod_path,
            role=role,
            file_count=len(files),
            symbol_count=len(mod_symbols),
            files=sorted(files),
            symbols=sorted(set(mod_symbols))[:40],
            dependencies=sorted(module_deps[mod_path]),
            incoming_count=incoming_counts[mod_path],
            outgoing_count=outgoing_counts[mod_path],
        ))

    # Sort modules by file count descending
    return sorted(modules, key=lambda m: (m.file_count, m.symbol_count), reverse=True)


# ---------------------------------------------------------------------------
# 4. API Route Detection
# ---------------------------------------------------------------------------

def _detect_api_endpoints(repo: Repository) -> list[ApiEndpoint]:
    """Extract actual declared API endpoints from source code."""
    endpoints: list[ApiEndpoint] = []
    seen_routes: set[str] = set()

    for fp, sf in repo.files.items():
        content = sf._content
        if not content:
            continue

        lines = content.split("\n")

        # 1. FastAPI / Flask / Python API Routes
        if sf.language == "Python":
            for i, line in enumerate(lines):
                methods = []
                path = ""

                match = FASTAPI_METHOD_ROUTE_RE.search(line)
                if match and match.group(1).lower() != "route":
                    methods = [match.group(1).upper()]
                    path = match.group(2)
                else:
                    flask_match = FLASK_ROUTE_RE.search(line)
                    if flask_match:
                        path = flask_match.group(1)
                        raw_methods = flask_match.group(2)
                        if raw_methods:
                            methods = [m.strip(" '\"").upper() for m in raw_methods.split(",") if m.strip(" '\"")]
                        else:
                            methods = ["GET"]

                if methods and path:
                    for method in methods:
                        key = f"{method}:{path}:{fp}"
                        if key in seen_routes:
                            continue
                        seen_routes.add(key)

                        # Look for handler function on next lines
                        handler = "handler"
                        docstring: Optional[str] = None
                        line_start = i + 1
                        line_end = min(len(lines), i + 8)

                        for j in range(i + 1, min(len(lines), i + 6)):
                            def_match = PYTHON_DEF_RE.search(lines[j])
                            if def_match:
                                handler = def_match.group(1)
                                # Extract docstring if present
                                body_text = "\n".join(lines[j + 1:min(len(lines), j + 6)])
                                doc_match = PYTHON_DOCSTRING_RE.search(body_text)
                                if doc_match:
                                    docstring = (doc_match.group(1) or doc_match.group(2) or "").strip()
                                break

                        snippet = "\n".join(lines[i:min(len(lines), i + 4)])
                        endpoints.append(ApiEndpoint(
                            method=method,
                            path=path,
                            handler=handler,
                            file=fp,
                            line_start=line_start,
                            line_end=line_end,
                            docstring=docstring,
                            evidence=[Evidence(
                                file=fp,
                                line_start=line_start,
                                line_end=line_end,
                                snippet=snippet,
                                description=f"{method} {path} endpoint handled by {handler}",
                            )],
                        ))


        # 2. Node / Express Routes
        elif sf.language in ("JavaScript", "TypeScript", "TSX", "JSX"):
            for i, line in enumerate(lines):
                match = EXPRESS_ROUTE_RE.search(line)
                if match:
                    method = match.group(1).upper()
                    path = match.group(2)
                    key = f"{method}:{path}:{fp}"
                    if key in seen_routes:
                        continue
                    seen_routes.add(key)

                    line_start = i + 1
                    line_end = min(len(lines), i + 4)
                    snippet = "\n".join(lines[i:line_end])
                    endpoints.append(ApiEndpoint(
                        method=method,
                        path=path,
                        handler=f"route_{path.replace('/', '_').strip('_')}",
                        file=fp,
                        line_start=line_start,
                        line_end=line_end,
                        evidence=[Evidence(
                            file=fp,
                            line_start=line_start,
                            line_end=line_end,
                            snippet=snippet,
                            description=f"{method} {path} route in {fp}",
                        )],
                    ))

    return sorted(endpoints, key=lambda ep: (ep.path, ep.method))


# ---------------------------------------------------------------------------
# 5. Data & Storage Technology Detection
# ---------------------------------------------------------------------------

def _detect_storage_technologies(repo: Repository) -> list[StorageTechnology]:
    """Detect storage technologies, schemas, databases, and collections from evidence."""
    technologies: list[StorageTechnology] = []

    # 1. Firebase / Firestore
    firestore_files: set[str] = set()
    firestore_collections: set[str] = set()
    firestore_evidence: list[Evidence] = []

    # Check relationships for data:: targets
    for rel in repo.relationships:
        if rel.target_id.startswith("data::"):
            coll_name = rel.target_id.replace("data::", "")
            firestore_collections.add(coll_name)
            src_file = rel.source_id.split("::")[0]
            if src_file:
                firestore_files.add(src_file)
            if rel.evidence:
                firestore_evidence.extend(rel.evidence[:1])

    # Check file contents for .collection('...')
    for fp, sf in repo.files.items():
        content = sf._content
        if not content:
            continue
        lines = content.split("\n")
        for i, line in enumerate(lines):
            match = FIRESTORE_COLLECTION_RE.search(line)
            if match:
                coll = match.group(1)
                firestore_collections.add(coll)
                firestore_files.add(fp)
                if len(firestore_evidence) < 5:
                    firestore_evidence.append(Evidence(
                        file=fp,
                        line_start=i + 1,
                        line_end=min(len(lines), i + 2),
                        snippet=line.strip(),
                        description=f"Firestore collection '{coll}' accessed in {fp}",
                    ))

    if firestore_collections or any("firebase" in f.lower() or "firestore" in f.lower() for f in repo.files):
        technologies.append(StorageTechnology(
            technology="Firebase / Firestore",
            category="Cloud NoSQL Database",
            confidence=Confidence.CONFIRMED,
            files=sorted(firestore_files),
            entities=sorted(firestore_collections),
            evidence=firestore_evidence[:6],
            description=f"Cloud Firestore NoSQL store with {len(firestore_collections)} detected collection(s): {', '.join(sorted(firestore_collections)) if firestore_collections else 'Dynamic collections'}.",
        ))

    # 2. SQLite / Local Relational
    sqlite_files: set[str] = set()
    sqlite_tables: set[str] = set()
    sqlite_evidence: list[Evidence] = []

    for fp, sf in repo.files.items():
        content = sf._content
        if not content:
            continue
        fp_lower = fp.lower()
        if "sqlite" in fp_lower or "sqflite" in fp_lower:
            sqlite_files.add(fp)

        lines = content.split("\n")
        for i, line in enumerate(lines):
            if any(k in line.lower() for k in ("sqlite", "sqflite", "opendatabase", "createdatabase")):
                sqlite_files.add(fp)
                if len(sqlite_evidence) < 4:
                    sqlite_evidence.append(Evidence(
                        file=fp,
                        line_start=i + 1,
                        line_end=min(len(lines), i + 2),
                        snippet=line.strip(),
                        description=f"SQLite database interaction in {fp}",
                    ))
            sql_match = SQL_TABLE_RE.search(line)
            if sql_match and len(sql_match.group(1)) > 2:
                sqlite_tables.add(sql_match.group(1))

    if sqlite_files:
        technologies.append(StorageTechnology(
            technology="SQLite / Local Relational",
            category="Relational SQL Database",
            confidence=Confidence.CONFIRMED,
            files=sorted(sqlite_files),
            entities=sorted(sqlite_tables),
            evidence=sqlite_evidence[:6],
            description=f"Local SQLite database engine used for persistence across {len(sqlite_files)} file(s).",
        ))

    # 3. Client Local Storage / Key-Value
    kv_files: set[str] = set()
    kv_keys: set[str] = set()
    kv_evidence: list[Evidence] = []

    for fp, sf in repo.files.items():
        content = sf._content
        if not content:
            continue
        lines = content.split("\n")
        for i, line in enumerate(lines):
            if any(k in line for k in ("SharedPreferences", "shared_preferences", "localStorage", "AsyncStorage", "Hive")):
                kv_files.add(fp)
                pref_match = PREFERENCES_KEY_RE.search(line)
                if pref_match:
                    kv_keys.add(pref_match.group(1))
                if len(kv_evidence) < 4:
                    kv_evidence.append(Evidence(
                        file=fp,
                        line_start=i + 1,
                        line_end=min(len(lines), i + 2),
                        snippet=line.strip(),
                        description=f"Key-value storage access in {fp}",
                    ))

    if kv_files:
        technologies.append(StorageTechnology(
            technology="Key-Value / Shared Preferences",
            category="Client Key-Value Storage",
            confidence=Confidence.CONFIRMED,
            files=sorted(kv_files),
            entities=sorted(kv_keys),
            evidence=kv_evidence[:6],
            description=f"Local key-value storage engine for persistent user preferences and cached state.",
        ))

    # 4. Domain Data Models & Schemas
    model_classes: list[str] = []
    model_files: set[str] = set()
    model_evidence: list[Evidence] = []

    for sym in repo.symbols.values():
        if sym.symbol_type == SymbolType.CLASS:
            if "model" in sym.file.lower() or "schema" in sym.file.lower() or "entity" in sym.file.lower():
                model_classes.append(sym.name)
                model_files.add(sym.file)
                if len(model_evidence) < 4:
                    model_evidence.append(Evidence(
                        file=sym.file,
                        line_start=sym.line_start,
                        line_end=min(sym.line_end, sym.line_start + 3),
                        snippet=f"class {sym.name}",
                        description=f"Data entity / model class {sym.name}",
                    ))

    if model_classes:
        technologies.append(StorageTechnology(
            technology="Domain Data Models",
            category="ORM / Serialization Entities",
            confidence=Confidence.CONFIRMED,
            files=sorted(model_files),
            entities=sorted(set(model_classes)),
            evidence=model_evidence[:6],
            description=f"Structured domain entities ({len(set(model_classes))} models) defining data models and serialization contracts.",
        ))

    return technologies


# ---------------------------------------------------------------------------
# 6. Dynamic Architecture Graph Map
# ---------------------------------------------------------------------------

def _build_architecture_graph(
    repo: Repository,
    layers: list[ArchitectureLayer],
) -> ArchitectureGraph:
    """Build dynamic architecture map with cross-layer edges directly from repository relationships."""
    # 1. Create nodes for each active layer
    nodes: list[ArchitectureGraphNode] = []
    file_to_layer_id: dict[str, str] = {}

    layer_id_map = {
        "UI / Screens": "layer::ui",
        "API / Controllers": "layer::api",
        "Services": "layer::services",
        "Models": "layer::models",
        "Storage & Data Access": "layer::storage",
        "External Integrations": "layer::integrations",
        "Tests": "layer::tests",
        "Configuration": "layer::config",
    }

    for lyr in layers:
        node_id = layer_id_map.get(lyr.name, f"layer::{lyr.name.lower().replace(' ', '_')}")
        nodes.append(ArchitectureGraphNode(
            id=node_id,
            label=lyr.name,
            layer=lyr.name.split("/")[0].strip(),
            file_count=lyr.file_count,
            symbol_count=lyr.symbol_count,
            files=lyr.files,
            symbols=lyr.symbols,
        ))
        for f in lyr.files:
            file_to_layer_id[f] = node_id

    # 2. Build aggregated cross-layer edges
    edge_map: dict[tuple[str, str], dict[str, Any]] = {}

    for rel in repo.relationships:
        src_file = rel.source_id.split("::")[0]
        tgt_file = rel.target_id.split("::")[0]

        src_layer = file_to_layer_id.get(src_file)
        # Handle data:: targets
        if rel.target_id.startswith("data::"):
            tgt_layer = "layer::storage"
        else:
            tgt_layer = file_to_layer_id.get(tgt_file)

        if src_layer and tgt_layer and src_layer != tgt_layer:
            pair = (src_layer, tgt_layer)
            if pair not in edge_map:
                edge_map[pair] = {
                    "count": 0,
                    "types": set(),
                    "evidence": [],
                }
            edge_map[pair]["count"] += 1
            edge_map[pair]["types"].add(rel.relationship_type.value)
            if len(edge_map[pair]["evidence"]) < 3 and rel.evidence:
                edge_map[pair]["evidence"].extend(rel.evidence)

    edges: list[ArchitectureGraphEdge] = []
    for (src, tgt), data in edge_map.items():
        type_str = ", ".join(sorted(data["types"]))
        edges.append(ArchitectureGraphEdge(
            source_id=src,
            target_id=tgt,
            label=f"{data['count']} {type_str}",
            count=data["count"],
            relationship_types=sorted(data["types"]),
            evidence=data["evidence"][:4],
        ))

    # Sort edges by count descending
    edges.sort(key=lambda e: e.count, reverse=True)

    return ArchitectureGraph(nodes=nodes, edges=edges)


# ---------------------------------------------------------------------------
# 7. Summary Description Helper
# ---------------------------------------------------------------------------

def _generate_summary_description(
    repo: Repository,
    frameworks: list[str],
    layers: list[ArchitectureLayer],
    modules: list[RepositoryModule],
    api_endpoints: list[ApiEndpoint],
    storage_technologies: list[StorageTechnology],
) -> str:
    """Generate high-level architectural summary sentence."""
    parts = []
    if frameworks:
        parts.append(f"{', '.join(frameworks)} project")
    else:
        parts.append("Multi-language repository")

    parts.append(f"comprising {repo.source_files} source files across {len(modules)} modules and {len(layers)} architectural layers.")

    if api_endpoints:
        parts.append(f"Detected {len(api_endpoints)} API endpoints.")
    if storage_technologies:
        storage_names = [st.technology for st in storage_technologies]
        parts.append(f"Integrates {', '.join(storage_names)}.")

    return " ".join(parts)


# ---------------------------------------------------------------------------
# 8. Visual Repository Tree Generator
# ---------------------------------------------------------------------------

def _infer_file_layer(fp: str, sf: Optional[SourceFile]) -> str:
    """Infer the architectural layer for a given source file."""
    if not sf:
        return "Services"
    if sf.is_test:
        return "Tests"
    if sf.is_config:
        return "Configuration"
    fp_lower = fp.lower()
    if any(k in fp_lower for k in ("screen", "page", "view", "widget", "component", "ui")):
        return "UI / Screens"
    if any(k in fp_lower for k in ("route", "controller", "endpoint", "handler", "api", "backend_routes")):
        return "API / Controllers"
    if any(k in fp_lower for k in ("service", "manager", "provider", "bloc", "store", "auth")):
        return "Services"
    if any(k in fp_lower for k in ("model", "entity", "schema", "dto", "types")):
        return "Models"
    if any(k in fp_lower for k in ("repo", "dao", "db", "database", "storage", "firestore", "sql")):
        return "Storage & Data Access"
    if any(k in fp_lower for k in ("ocr", "scanner", "client", "sdk", "http", "export", "pdf")):
        return "External Integrations"
    role = _infer_role(fp, Path(fp).stem, [])
    if "UI" in role or "Screen" in role:
        return "UI / Screens"
    if "Service" in role or "Auth" in role:
        return "Services"
    if "Model" in role:
        return "Models"
    if "API" in role or "Route" in role:
        return "API / Controllers"
    if "Store" in role or "DAO" in role:
        return "Storage & Data Access"
    if "OCR" in role or "Scanner" in role or "Export" in role:
        return "External Integrations"
    if "Config" in role:
        return "Configuration"
    return "Services"


def build_repository_tree(repo: Repository) -> RepositoryTree:
    """
    Build a complete, generic hierarchical Repository Tree from indexed repository files,
    symbols, and relationship graphs.
    """
    # 1. Index cross-references and relationships
    file_incoming_rels: dict[str, list[RelationshipRef]] = defaultdict(list)
    file_outgoing_rels: dict[str, list[RelationshipRef]] = defaultdict(list)
    symbol_incoming_rels: dict[str, list[RelationshipRef]] = defaultdict(list)
    symbol_outgoing_rels: dict[str, list[RelationshipRef]] = defaultdict(list)

    for rel in repo.relationships:
        # Resolve source file and target file
        src_sym = repo.symbols.get(rel.source_id)
        src_file = src_sym.file if src_sym else rel.source_id

        tgt_sym = repo.symbols.get(rel.target_id)
        tgt_file = tgt_sym.file if tgt_sym else rel.target_id

        src_label = _shorten_id(rel.source_id)
        tgt_label = _shorten_id(rel.target_id)

        src_layer = _infer_file_layer(src_file, repo.files.get(src_file))
        tgt_layer = _infer_file_layer(tgt_file, repo.files.get(tgt_file))

        rel_type_str = rel.relationship_type.value.upper()

        out_ref = RelationshipRef(
            id=f"{rel.source_id}->{rel.target_id}::{rel.relationship_type.value}",
            source_id=rel.source_id,
            target_id=rel.target_id,
            relationship_type=rel_type_str,
            direction="outgoing",
            target_label=tgt_label,
            target_file=tgt_file,
            target_layer=tgt_layer,
            confidence=rel.confidence,
            evidence=rel.evidence,
            description=rel.description or f"{src_label} {rel.relationship_type.value} {tgt_label}",
        )

        in_ref = RelationshipRef(
            id=f"{rel.source_id}->{rel.target_id}::{rel.relationship_type.value}::in",
            source_id=rel.source_id,
            target_id=rel.target_id,
            relationship_type=rel_type_str,
            direction="incoming",
            target_label=src_label,
            target_file=src_file,
            target_layer=src_layer,
            confidence=rel.confidence,
            evidence=rel.evidence,
            description=rel.description or f"{src_label} {rel.relationship_type.value} {tgt_label}",
        )

        # File-level mapping
        file_outgoing_rels[src_file].append(out_ref)
        file_incoming_rels[tgt_file].append(in_ref)

        # Symbol-level mapping
        if rel.source_id in repo.symbols:
            symbol_outgoing_rels[rel.source_id].append(out_ref)
        if rel.target_id in repo.symbols:
            symbol_incoming_rels[rel.target_id].append(in_ref)

    # 2. Build folder/file hierarchy
    class DirNode:
        def __init__(self, name: str, path: str):
            self.name = name
            self.path = path
            self.subdirs: dict[str, DirNode] = {}
            self.files: list[RepositoryTreeNode] = []

    root_dir = DirNode(name=repo.name, path="")

    # Populate files and their nested symbols
    for fp, sf in sorted(repo.files.items()):
        parts = fp.replace("\\", "/").strip("/").split("/")
        filename = parts[-1]
        dir_parts = parts[:-1]

        current = root_dir
        curr_path_parts = []
        for d in dir_parts:
            curr_path_parts.append(d)
            subpath = "/".join(curr_path_parts)
            if d not in current.subdirs:
                current.subdirs[d] = DirNode(name=d, path=subpath)
            current = current.subdirs[d]

        # Build symbol nodes for this file
        file_layer = _infer_file_layer(fp, sf)
        symbol_nodes: list[RepositoryTreeNode] = []

        # Sort symbols by line_start
        sorted_symbols = sorted(sf.symbols, key=lambda s: s.line_start)
        for sym in sorted_symbols:
            sym_in = symbol_incoming_rels.get(sym.id, [])
            sym_out = symbol_outgoing_rels.get(sym.id, [])
            sym_type_val = sym.symbol_type.value if hasattr(sym.symbol_type, "value") else str(sym.symbol_type)

            sym_node = RepositoryTreeNode(
                id=f"sym::{sym.id}",
                name=sym.name,
                path=f"{fp}::{sym.name}",
                node_type=TreeNodeType.SYMBOL,
                language=sf.language,
                layer=file_layer,
                symbol_type=sym_type_val,
                line_start=sym.line_start,
                line_end=sym.line_end,
                docstring=sym.docstring,
                file_count=0,
                symbol_count=1,
                relationship_count=len(sym_in) + len(sym_out),
                children=[],
                imports=[],
                incoming_relationships=sym_in,
                outgoing_relationships=sym_out,
            )
            symbol_nodes.append(sym_node)

        file_in = file_incoming_rels.get(fp, [])
        file_out = file_outgoing_rels.get(fp, [])

        file_node = RepositoryTreeNode(
            id=f"file::{fp}",
            name=filename,
            path=fp,
            node_type=TreeNodeType.FILE,
            language=sf.language,
            size_bytes=sf.size_bytes,
            line_count=sf.line_count,
            layer=file_layer,
            file_count=1,
            symbol_count=len(symbol_nodes),
            relationship_count=len(file_in) + len(file_out),
            children=symbol_nodes,
            imports=[imp.imported_module for imp in sf.imports],
            incoming_relationships=file_in,
            outgoing_relationships=file_out,
        )
        current.files.append(file_node)

    # 3. Recursively convert DirNode to RepositoryTreeNode
    def _convert_dir(node: DirNode) -> RepositoryTreeNode:
        children: list[RepositoryTreeNode] = []

        # Subdirectories first (sorted)
        for dirname in sorted(node.subdirs.keys()):
            child_dir = _convert_dir(node.subdirs[dirname])
            children.append(child_dir)

        # Files next (sorted)
        for f in sorted(node.files, key=lambda x: x.name.lower()):
            children.append(f)

        total_files = sum(c.file_count for c in children)
        total_symbols = sum(c.symbol_count for c in children)
        total_rels = sum(c.relationship_count for c in children)

        return RepositoryTreeNode(
            id=f"dir::{node.path}" if node.path else "repo::root",
            name=node.name,
            path=node.path,
            node_type=TreeNodeType.DIRECTORY if node.path else TreeNodeType.REPOSITORY,
            file_count=total_files,
            symbol_count=total_symbols,
            relationship_count=total_rels,
            children=children,
        )

    root_tree_node = _convert_dir(root_dir)
    root_tree_node.name = repo.name
    root_tree_node.id = "repo::root"
    root_tree_node.node_type = TreeNodeType.REPOSITORY
    root_tree_node.file_count = repo.total_files
    root_tree_node.symbol_count = len(repo.symbols)
    root_tree_node.relationship_count = len(repo.relationships)

    return RepositoryTree(
        repository_id=repo.id,
        repository_name=repo.name,
        total_files=repo.total_files,
        total_symbols=len(repo.symbols),
        total_relationships=len(repo.relationships),
        root=root_tree_node,
    )

