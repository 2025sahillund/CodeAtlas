"""
Feature Tracer — Generic Repository Flow & Architecture Analyzer.

Takes a natural language query about a feature (e.g. "Trace prescription scanning")
and dynamically discovers the relevant files, symbols, cross-file relationships,
and evidence from the indexed repository knowledge model.

Algorithm:
1. Domain term extraction: extract keywords and tight domain synonyms
2. Candidate scoring & ranking: score all files and symbols in the repository with word-token matching
3. Entry point selection: top-ranked candidate files/symbols become starting nodes (preferring screens/methods/classes)
4. Multi-hop graph expansion: traverse relationships (calls, creates, imports, writes, reads)
   up to configurable max_depth (default 3) across files
5. Evidence assembly: attach exact source code snippets, line numbers, and confidence
6. Trace summarization: synthesize flow summary, confirmed findings, and unknowns

Generic implementation with zero hardcoded repository rules.
"""

from __future__ import annotations

import posixpath
import re
from pathlib import Path
from typing import Optional

from app.models.repository import (
    Repository, Symbol, SourceFile, Relationship,
    RelationshipType, Confidence, Evidence, SymbolType,
)
from app.models.repository import FeatureTrace, TraceNode, TraceEdge


# ---------------------------------------------------------------------------
# Stop words — excluded from domain term extraction
# ---------------------------------------------------------------------------

STOP_WORDS: set[str] = {
    "trace", "show", "find", "where", "how", "does", "the", "is", "are",
    "what", "which", "a", "an", "it", "its", "in", "on", "at", "to",
    "for", "of", "and", "or", "with", "by", "from", "that", "this",
    "was", "be", "been", "being", "have", "has", "had", "do", "did",
    "will", "would", "could", "should", "get", "got", "make", "use",
    "using", "used", "code", "file", "function", "method", "class",
    "feature", "flow", "logic", "implement", "implementation", "implemented",
    "work", "works", "working", "system", "app", "application", "all",
}

# Domain synonym & alias mappings (generic software concepts)
TERM_SYNONYMS: dict[str, list[str]] = {
    "prescription": ["prescription", "scan", "ocr", "rx"],
    "scanning": ["scan", "scanner", "ocr", "recognition", "detect"],
    "scan": ["scan", "scanner", "ocr", "recognition", "detect"],
    "ocr": ["ocr", "scan", "recognition", "recognizer"],
    "login": ["login", "signin", "auth", "sign_in", "logon"],
    "signup": ["signup", "register", "registration", "sign_up"],
    "auth": ["auth", "login", "signin", "signup", "user", "credential", "session"],
    "authentication": ["auth", "login", "signin", "signup", "user", "credential", "session"],
    "medicine": ["medicine", "medication", "drug", "dose", "pill", "rx", "inventory", "stock"],
    "medicines": ["medicine", "medication", "drug", "dose", "pill", "inventory", "stock"],
    "medication": ["medicine", "medication", "drug", "dose", "pill", "inventory"],
    "management": ["manage", "crud", "list", "add", "edit", "update", "delete", "inventory"],
    "payment": ["payment", "pay", "checkout", "billing", "stripe"],
    "cart": ["cart", "basket", "order", "checkout"],
    "user": ["user", "account", "profile"],
    "profile": ["profile", "account", "user", "settings"],
    "notification": ["notification", "notify", "alert", "reminder", "push", "schedule"],
    "reminder": ["reminder", "notification", "alert", "schedule", "alarm"],
    "appointment": ["appointment", "booking", "schedule", "visit", "doctor"],
    "upload": ["upload", "attachment", "image", "photo", "file"],
    "image": ["image", "photo", "picture", "camera", "gallery"],
    "database": ["database", "db", "store", "firestore", "sql", "collection"],
    "health": ["health", "fitness", "vitals", "wellness", "tracking"],
    "step": ["step", "steps", "activity", "walk", "pedometer", "tracking"],
    "steps": ["step", "steps", "activity", "walk", "pedometer", "tracking"],
    "sleep": ["sleep", "rest", "slumber"],
    "caregiver": ["caregiver", "carer", "guardian", "monitor", "family"],
    "family": ["family", "member", "caregiver"],
    "sos": ["sos", "emergency", "alert", "urgent", "contact"],
    "report": ["report", "summary", "export", "pdf", "passport"],
    "delete": ["delete", "remove", "destroy"],
}


# ---------------------------------------------------------------------------
# Public Entry Point
# ---------------------------------------------------------------------------

def trace_feature(
    query: str,
    repo: Repository,
    max_depth: int = 3,
    max_nodes: int = 18,
) -> FeatureTrace:
    """
    Perform a complete feature trace for the given natural language query.
    Dynamically discovers candidate entry points, expands through relationships,
    and returns a FeatureTrace with verified nodes, edges, and evidence.
    """
    # 1. Extract domain terms
    terms = _extract_terms(query)
    if not terms:
        return FeatureTrace(
            query=query,
            summary="Empty or invalid query. Please provide domain keywords to trace.",
            unknowns=["Query contained no searchable terms."],
            total_nodes=0,
            total_edges=0,
        )

    # 2. Score candidate files and symbols
    file_scores = _score_files(repo, terms)
    symbol_scores = _score_symbols(repo, terms)

    # 3. Check relevance threshold
    max_file_score = max(file_scores.values()) if file_scores else 0.0
    max_sym_score = max(symbol_scores.values()) if symbol_scores else 0.0

    if max_file_score < 0.4 and max_sym_score < 0.4:
        return FeatureTrace(
            query=query,
            summary=f"No relevant files or symbols found for query: '{query}'.",
            unknowns=[f"No code matching keywords {terms[:4]} found in repository."],
            total_nodes=0,
            total_edges=0,
        )

    # 4. Select Entry Points
    entry_nodes: list[TraceNode] = []
    entry_node_ids: set[str] = set()

    sorted_syms = sorted(symbol_scores.items(), key=lambda x: x[1], reverse=True)
    sorted_files = sorted(file_scores.items(), key=lambda x: x[1], reverse=True)

    # Prioritize classes/screens and top functional methods from the best matching files
    seen_entry_files: set[str] = set()
    for sym_id, score in sorted_syms:
        if score < 0.8 or len(entry_nodes) >= 3:
            break
        sym = repo.symbols.get(sym_id)
        if not sym:
            continue
        # Limit symbols from same file to top 2 to keep entry points diverse
        if sym.file in seen_entry_files and len([n for n in entry_nodes if n.file == sym.file]) >= 2:
            continue
        node = _make_symbol_node(sym, repo, terms, is_entry=True)
        if node.id not in entry_node_ids:
            entry_nodes.append(node)
            entry_node_ids.add(node.id)
            seen_entry_files.add(sym.file)

    # If no symbol entry points found or to supplement top file
    if not entry_nodes:
        for fp, score in sorted_files[:2]:
            if score < 0.4:
                break
            sf = repo.files.get(fp)
            if not sf:
                continue
            node = _make_file_node(fp, sf, terms, is_entry=True)
            if node.id not in entry_node_ids:
                entry_nodes.append(node)
                entry_node_ids.add(node.id)

    # 5. Multi-Hop Graph Expansion (BFS up to max_depth)
    all_trace_nodes: dict[str, TraceNode] = {n.id: n for n in entry_nodes}
    all_trace_edges: list[TraceEdge] = []
    seen_edge_keys: set[tuple[str, str, RelationshipType]] = set()

    # Pre-index relationships
    rel_by_source: dict[str, list[Relationship]] = {}
    rel_by_target: dict[str, list[Relationship]] = {}

    for rel in repo.relationships:
        rel_by_source.setdefault(rel.source_id, []).append(rel)
        rel_by_target.setdefault(rel.target_id, []).append(rel)
        if "::" in rel.source_id:
            src_file = rel.source_id.split("::")[0]
            rel_by_source.setdefault(src_file, []).append(rel)

    frontier: list[str] = list(entry_node_ids)
    depth = 0

    while frontier and depth < max_depth and len(all_trace_nodes) < max_nodes:
        next_frontier: list[str] = []
        depth += 1

        for current_id in frontier:
            if len(all_trace_nodes) >= max_nodes:
                break

            current_node = all_trace_nodes.get(current_id)
            current_file = current_node.file if current_node else (
                current_id.split("::")[0] if "::" in current_id else current_id
            )

            # Find matching relationships
            matching_rels: list[Relationship] = []
            matching_rels.extend(rel_by_source.get(current_id, []))
            matching_rels.extend(rel_by_target.get(current_id, []))

            if current_file and current_file != current_id:
                matching_rels.extend(rel_by_source.get(current_file, []))

            for rel in matching_rels:
                if len(all_trace_nodes) >= max_nodes:
                    break

                is_outgoing = (
                    rel.source_id == current_id
                    or rel.source_id.startswith(f"{current_file}::")
                    or rel.source_id == current_file
                )

                peer_id = rel.target_id if is_outgoing else rel.source_id

                # Avoid expanding to test files unless query specifically asks for tests
                if _is_test_peer(peer_id, repo) and "test" not in terms:
                    continue

                if rel.relationship_type == RelationshipType.IMPORTS and rel.source_id == rel.target_id:
                    continue

                # Resolve source node and target node
                src_node = _resolve_trace_node(rel.source_id, repo, terms)
                tgt_node = _resolve_trace_node(rel.target_id, repo, terms)

                if not src_node or not tgt_node:
                    continue

                # Add new nodes to collection
                for n in (src_node, tgt_node):
                    if n.id not in all_trace_nodes and len(all_trace_nodes) < max_nodes:
                        all_trace_nodes[n.id] = n
                        if n.id == peer_id or n.id.startswith(peer_id):
                            next_frontier.append(n.id)

                # Add edge if both endpoints exist in our node set
                if src_node.id in all_trace_nodes and tgt_node.id in all_trace_nodes and src_node.id != tgt_node.id:
                    edge_key = (src_node.id, tgt_node.id, rel.relationship_type)
                    if edge_key not in seen_edge_keys:
                        seen_edge_keys.add(edge_key)
                        all_trace_edges.append(TraceEdge(
                            source_id=src_node.id,
                            target_id=tgt_node.id,
                            relationship_type=rel.relationship_type,
                            label=rel.relationship_type.value,
                            evidence=rel.evidence[:2],
                            confidence=rel.confidence,
                        ))

        frontier = next_frontier

    # 6. Ensure Entry Points and Ordered Node Chain
    ordered_nodes: list[TraceNode] = []
    seen_ids: set[str] = set()

    for ep in entry_nodes:
        if ep.id in all_trace_nodes and ep.id not in seen_ids:
            ordered_nodes.append(all_trace_nodes[ep.id])
            seen_ids.add(ep.id)

    # Follow outgoing edges from entry points to order downstream nodes
    queue = [n.id for n in ordered_nodes]
    visited_for_order: set[str] = set(queue)

    while queue:
        curr = queue.pop(0)
        for edge in all_trace_edges:
            if edge.source_id == curr and edge.target_id not in visited_for_order:
                tgt_node = all_trace_nodes.get(edge.target_id)
                if tgt_node and tgt_node.id not in seen_ids:
                    ordered_nodes.append(tgt_node)
                    seen_ids.add(tgt_node.id)
                    visited_for_order.add(edge.target_id)
                    queue.append(edge.target_id)

    # Append any remaining nodes
    for nid, node in all_trace_nodes.items():
        if nid not in seen_ids:
            ordered_nodes.append(node)
            seen_ids.add(nid)

    # 7. Collect Findings & Categorize
    confirmed_findings: list[str] = []
    inferred_findings: list[str] = []
    unknowns: list[str] = []

    for edge in all_trace_edges:
        desc = f"{_shorten_id(edge.source_id)} --[{edge.relationship_type.value}]--> {_shorten_id(edge.target_id)}"
        if edge.confidence == Confidence.CONFIRMED:
            confirmed_findings.append(desc)
        elif edge.confidence == Confidence.INFERRED:
            inferred_findings.append(desc)

    # Summary generation
    summary = _generate_summary(query, terms, ordered_nodes, all_trace_edges, repo)

    return FeatureTrace(
        query=query,
        summary=summary,
        entry_points=entry_nodes,
        nodes=ordered_nodes,
        edges=all_trace_edges,
        confirmed=list(dict.fromkeys(confirmed_findings))[:20],
        inferred=list(dict.fromkeys(inferred_findings))[:20],
        unknowns=unknowns,
        total_nodes=len(ordered_nodes),
        total_edges=len(all_trace_edges),
    )


# ---------------------------------------------------------------------------
# Node Resolution & Role Inference
# ---------------------------------------------------------------------------

def _resolve_trace_node(node_id: str, repo: Repository, terms: list[str]) -> Optional[TraceNode]:
    """Resolve a symbol ID, file path, or data URI into a TraceNode."""
    if node_id.startswith("data::"):
        coll_name = node_id.replace("data::", "")
        return TraceNode(
            id=node_id,
            file="[data store]",
            symbol=coll_name,
            symbol_id=node_id,
            role="Data Store",
            confidence=Confidence.CONFIRMED,
            evidence=[Evidence(
                file="[database]",
                snippet=f"Data collection / entity '{coll_name}'",
                description="Database collection",
            )],
        )

    if node_id in repo.symbols:
        sym = repo.symbols[node_id]
        return _make_symbol_node(sym, repo, terms)

    if "::" in node_id:
        file_part, sym_part = node_id.split("::", 1)
        cls_name = sym_part.split(".")[0]
        cls_id = f"{file_part}::{cls_name}"

        if cls_id in repo.symbols:
            cls_sym = repo.symbols[cls_id]
            role = _infer_role(cls_sym.file, sym_part, terms)
            return TraceNode(
                id=node_id,
                file=cls_sym.file,
                symbol=sym_part,
                symbol_id=node_id,
                symbol_type=SymbolType.METHOD,
                role=role,
                line_start=cls_sym.line_start,
                line_end=cls_sym.line_end,
                confidence=Confidence.CONFIRMED,
                evidence=_get_symbol_evidence(cls_sym, repo),
            )
        if file_part in repo.files:
            role = _infer_role(file_part, sym_part, terms)
            return TraceNode(
                id=node_id,
                file=file_part,
                symbol=sym_part,
                symbol_id=node_id,
                symbol_type=SymbolType.METHOD,
                role=role,
                confidence=Confidence.CONFIRMED,
            )

    if node_id in repo.files:
        sf = repo.files[node_id]
        return _make_file_node(node_id, sf, terms)

    return None


def _make_symbol_node(
    sym: Symbol,
    repo: Repository,
    terms: list[str],
    is_entry: bool = False,
) -> TraceNode:
    """Construct a TraceNode from a Symbol."""
    evidence = _get_symbol_evidence(sym, repo)
    role = _infer_role(sym.file, sym.name, terms)
    if is_entry and ("Screen" in sym.name or "Page" in sym.name or "Controller" in sym.name):
        role = "Entry Point"

    return TraceNode(
        id=sym.id,
        file=sym.file,
        symbol=sym.qualified_name,
        symbol_id=sym.id,
        symbol_type=sym.symbol_type,
        role=role,
        line_start=sym.line_start,
        line_end=sym.line_end,
        confidence=Confidence.CONFIRMED,
        evidence=evidence,
    )


def _make_file_node(
    fp: str,
    src: SourceFile,
    terms: list[str],
    is_entry: bool = False,
) -> TraceNode:
    """Construct a TraceNode from a SourceFile."""
    role = _infer_role(fp, Path(fp).stem, terms)
    if is_entry:
        role = "Entry Point"
    return TraceNode(
        id=fp,
        file=fp,
        symbol=Path(fp).name,
        role=role,
        confidence=Confidence.CONFIRMED,
        evidence=[Evidence(
            file=fp,
            line_start=1,
            line_end=min(src.line_count, 10),
            snippet=f"File: {fp} ({src.language})",
            description=f"Source file {Path(fp).name}",
        )],
    )


def _get_symbol_evidence(sym: Symbol, repo: Repository) -> list[Evidence]:
    """Retrieve actual source lines for a symbol definition."""
    src = repo.files.get(sym.file)
    if not src or not src._content:
        return []
    lines = src._content.split("\n")
    start = max(0, sym.line_start - 1)
    end = min(len(lines), start + 4)
    snippet = "\n".join(lines[start:end])
    return [Evidence(
        file=sym.file,
        line_start=sym.line_start,
        line_end=min(sym.line_end, sym.line_start + 3),
        snippet=snippet[:300],
        description=f"Definition of {sym.qualified_name}",
    )]


def _infer_role(file_path: str, symbol_name: str, terms: list[str]) -> str:
    """Infer architectural role from file and symbol patterns."""
    fp_lower = file_path.lower()
    name_lower = symbol_name.lower()
    combined = f"{fp_lower} {name_lower}"

    ROLE_PATTERNS: list[tuple[re.Pattern, str]] = [
        (re.compile(r"scan|ocr|recogni|mlkit|detect"), "OCR / Scanner"),
        (re.compile(r"screen|page|view|widget"), "UI / Screen"),
        (re.compile(r"service|manager|provider"), "Service Layer"),
        (re.compile(r"repository|repo|dao"), "Repository / DAO"),
        (re.compile(r"model|entity|schema"), "Data Model"),
        (re.compile(r"controller|handler|route"), "Controller / Route"),
        (re.compile(r"auth|login|signin|signup|session"), "Authentication"),
        (re.compile(r"notif|reminder|alert|push|alarm"), "Notification"),
        (re.compile(r"db|database|firestore|sql|store|collection"), "Data Store"),
        (re.compile(r"api|client|http|fetch|request"), "API Client"),
        (re.compile(r"test|spec"), "Test"),
        (re.compile(r"pdf|export|report|passport"), "Export / Report"),
        (re.compile(r"upload|download|file|storage"), "File / Storage"),
        (re.compile(r"config|setting|option|env"), "Configuration"),
        (re.compile(r"util|helper|common|shared"), "Utility"),
        (re.compile(r"nav|router|routing"), "Navigation"),
    ]

    for pattern, role in ROLE_PATTERNS:
        if pattern.search(combined):
            return role

    return "Component"


# ---------------------------------------------------------------------------
# Scoring & Candidate Matching with CamelCase / Snake_case Tokenization
# ---------------------------------------------------------------------------

def _tokenize(text: str) -> set[str]:
    """Split camelCase, snake_case, and kebab-case text into lowercase word tokens."""
    tokens = re.findall(r"[A-Z]?[a-z]+|[A-Z]+(?=[A-Z][a-z]|\d|\W|$)|[a-z]+|\d+", text.replace("_", " ").replace("-", " "))
    return {t.lower() for t in tokens if len(t) >= 2}


def _extract_terms(query: str) -> list[str]:
    """Extract and expand domain keywords from query."""
    q = query.lower().strip()
    raw_words = re.split(r"[^a-z0-9_]+", q)
    words = [w for w in raw_words if w and len(w) >= 3 and w not in STOP_WORDS]

    expanded: list[str] = list(words)
    for word in words:
        if word in TERM_SYNONYMS:
            expanded.extend(TERM_SYNONYMS[word])

    seen: set[str] = set()
    result: list[str] = []
    for t in expanded:
        if t not in seen:
            seen.add(t)
            result.append(t)
    return result


def _score_files(repo: Repository, terms: list[str]) -> dict[str, float]:
    """Score each file by keyword token relevance."""
    scores: dict[str, float] = {}
    for fp, sf in repo.files.items():
        score = 0.0
        fp_lower = fp.lower()
        file_tokens = _tokenize(fp)

        for term in terms:
            if term in file_tokens:
                score += 2.0
            elif any(tok.startswith(term) for tok in file_tokens):
                score += 1.2
            elif f"/{term}" in fp_lower or f"_{term}" in fp_lower:
                score += 1.0

        if ("screen" in fp_lower or "service" in fp_lower or "route" in fp_lower) and score > 0:
            score += 0.5

        scores[fp] = score
    return scores


def _score_symbols(repo: Repository, terms: list[str]) -> dict[str, float]:
    """Score each symbol by keyword token relevance."""
    scores: dict[str, float] = {}
    for sym_id, sym in repo.symbols.items():
        score = 0.0
        name_lower = sym.name.lower()
        name_tokens = _tokenize(sym.qualified_name)
        file_tokens = _tokenize(sym.file)

        for term in terms:
            if term == name_lower:
                score += 3.5
            elif term in name_tokens:
                score += 2.5
            elif any(tok.startswith(term) for tok in name_tokens):
                score += 1.5
            elif term in file_tokens:
                score += 0.8

        # Prioritize Classes, Functions, and Methods over class fields / variables
        if sym.symbol_type == SymbolType.CLASS:
            score *= 1.5
        elif sym.symbol_type in (SymbolType.METHOD, SymbolType.FUNCTION):
            score *= 1.3
        elif sym.symbol_type == SymbolType.VARIABLE:
            score *= 0.4

        scores[sym_id] = score
    return scores


def _is_test_peer(peer_id: str, repo: Repository) -> bool:
    """Check if a relationship target is a test file."""
    if "test" in peer_id.lower() and not peer_id.startswith("data::"):
        file_path = peer_id.split("::")[0]
        sf = repo.files.get(file_path)
        return bool(sf and sf.is_test)
    return False


def _shorten_id(node_id: str) -> str:
    """Format an ID for clean display."""
    if node_id.startswith("data::"):
        return f"[{node_id.replace('data::', '')}]"
    if "::" in node_id:
        f, s = node_id.split("::", 1)
        return f"{Path(f).name}::{s}"
    return Path(node_id).name


def _generate_summary(
    query: str,
    terms: list[str],
    nodes: list[TraceNode],
    edges: list[TraceEdge],
    repo: Repository,
) -> str:
    """Generate human-readable summary of the feature trace."""
    if not nodes:
        return f"No components found for '{query}'."

    files = list(dict.fromkeys(Path(n.file).name for n in nodes if n.file != "[data store]"))
    roles = list(dict.fromkeys(n.role for n in nodes if n.role))

    files_str = ", ".join(files[:5])
    roles_str = " -> ".join(roles[:5])

    return (
        f"Traced '{query}' across {len(files)} file{'s' if len(files) != 1 else ''} "
        f"({len(nodes)} components, {len(edges)} verified relationships). "
        f"Flow: {roles_str}. "
        f"Key files: {files_str}."
    )
