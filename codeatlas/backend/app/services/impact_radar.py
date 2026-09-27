"""
Change Impact Radar — Generic Repository Change Impact Analysis Engine.

Answers: "If I change this code, what else could be affected?"

Analyzes the existing repository knowledge graph to calculate:
1. Direct impacts (callers, creators, importers at distance 1)
2. Indirect impacts (multi-hop transitive callers at distance >= 2)
3. Data impacts (data stores and models mutated or read)
4. UI impacts (screens and widgets depending on the target)
5. Test impacts (test suites testing the target or its callers)

All impacts include verifiable source evidence, distance, confidence, and reasons.
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
    ImpactType, ImpactNode, ImpactSummary, ImpactAnalysis, TraceEdge
)
from app.services.feature_tracer import (
    _tokenize, _infer_role, _get_symbol_evidence, _is_test_peer, _shorten_id
)


RELATIONSHIP_PRIORITY = {
    RelationshipType.CALLS: 1,
    RelationshipType.WRITES: 2,
    RelationshipType.READS: 3,
    RelationshipType.CREATES: 4,
    RelationshipType.IMPLEMENTS: 5,
    RelationshipType.EXTENDS: 6,
    RelationshipType.TESTS: 7,
    RelationshipType.IMPORTS: 8,
}


# ---------------------------------------------------------------------------
# Public Entry Point
# ---------------------------------------------------------------------------

def analyze_impact(
    target_query: str,
    repo: Repository,
    max_depth: int = 3,
    max_nodes: int = 100,
) -> ImpactAnalysis:
    """
    Perform change impact analysis for a specified target symbol, class, or file.
    Traverses incoming and outgoing dependencies up to max_depth.
    """
    target_q = target_query.strip()
    if not target_q:
        dummy_target = ImpactNode(
            id="[unknown]",
            file="",
            symbol="",
            impact_type=ImpactType.UNKNOWN,
            confidence=Confidence.UNKNOWN,
            reason="No target specified.",
        )
        return ImpactAnalysis(
            target=dummy_target,
            unknowns=["Target query was empty."],
            confidence=Confidence.UNKNOWN,
            summary=ImpactSummary(
                target_id="",
                target_name="",
                description="No target specified.",
            ),
        )

    # 1. Resolve Target
    target_node = _resolve_target_node(target_q, repo)
    if not target_node:
        dummy_target = ImpactNode(
            id=f"[unknown::{target_q}]",
            file="",
            symbol=target_q,
            impact_type=ImpactType.UNKNOWN,
            confidence=Confidence.UNKNOWN,
            reason=f"Target '{target_q}' could not be resolved in repository.",
        )
        return ImpactAnalysis(
            target=dummy_target,
            unknowns=[f"Target '{target_q}' was not found in the indexed repository."],
            confidence=Confidence.UNKNOWN,
            summary=ImpactSummary(
                target_id=target_q,
                target_name=target_q,
                description=f"Target '{target_q}' was not found in the indexed repository.",
            ),
        )

    # 2. Pre-index relationships for fast multi-granular traversal
    # Incoming: who points to key? (Callers, importers, creators, testers)
    incoming_by_target: dict[str, list[Relationship]] = {}
    # Outgoing: who does key point to? (Callees, writes, reads, creates)
    outgoing_by_source: dict[str, list[Relationship]] = {}

    for rel in repo.relationships:
        incoming_by_target.setdefault(rel.target_id, []).append(rel)
        outgoing_by_source.setdefault(rel.source_id, []).append(rel)

        # Also index by file path if source/target is a symbol
        if "::" in rel.target_id:
            tgt_file = rel.target_id.split("::")[0]
            incoming_by_target.setdefault(tgt_file, []).append(rel)
        if "::" in rel.source_id:
            src_file = rel.source_id.split("::")[0]
            outgoing_by_source.setdefault(src_file, []).append(rel)

    # 3. BFS Graph Traversal for Impacted Components
    impacted_nodes: dict[str, ImpactNode] = {}
    impact_edges: list[TraceEdge] = []
    seen_edge_keys: set[tuple[str, str, RelationshipType]] = set()

    frontier: list[str] = [target_node.id]
    # If target is a symbol, also include its file in frontier matching
    if target_node.symbol and target_node.file:
        frontier.append(target_node.file)

    visited_ids: set[str] = {target_node.id}
    if target_node.file:
        visited_ids.add(target_node.file)

    distance = 0

    while frontier and distance < max_depth and len(impacted_nodes) < max_nodes:
        next_frontier: list[str] = []
        distance += 1

        for curr_id in frontier:
            if len(impacted_nodes) >= max_nodes:
                break

            lookup_keys = _get_lookup_keys(curr_id)

            # ---------------------------------------------------------------
            # A. Incoming Dependencies: components that CALL, IMPORT, CREATE, EXTEND, TEST curr_id
            # ---------------------------------------------------------------
            incoming_rels: list[Relationship] = []
            seen_in_rel_keys = set()
            for k in lookup_keys:
                for r in incoming_by_target.get(k, []):
                    rk = (r.source_id, r.relationship_type.value, r.target_id)
                    if rk not in seen_in_rel_keys:
                        seen_in_rel_keys.add(rk)
                        incoming_rels.append(r)

            incoming_rels.sort(key=lambda r: RELATIONSHIP_PRIORITY.get(r.relationship_type, 9))

            for rel in incoming_rels:
                if len(impacted_nodes) >= max_nodes:
                    break

                caller_id = rel.source_id
                if caller_id in visited_ids and caller_id in impacted_nodes:
                    # Already visited node, but we might still add the edge
                    _add_impact_edge(caller_id, curr_id, rel, impact_edges, seen_edge_keys)
                    continue

                if caller_id == target_node.id or caller_id == target_node.file:
                    continue

                # Categorize impact
                node = _make_impact_node(
                    node_id=caller_id,
                    repo=repo,
                    distance=distance,
                    relationship=rel.relationship_type,
                    confidence=rel.confidence,
                    evidence=rel.evidence,
                    trigger_id=curr_id,
                    is_incoming=True,
                )
                if node:
                    visited_ids.add(node.id)
                    impacted_nodes[node.id] = node
                    next_frontier.append(node.id)
                    _add_impact_edge(node.id, curr_id, rel, impact_edges, seen_edge_keys)

            # ---------------------------------------------------------------
            # B. Outgoing Dependencies: data stores WRITTEN/READ, callees, created models
            # ---------------------------------------------------------------
            outgoing_rels: list[Relationship] = []
            seen_out_rel_keys = set()
            for k in lookup_keys:
                for r in outgoing_by_source.get(k, []):
                    rk = (r.source_id, r.relationship_type.value, r.target_id)
                    if rk not in seen_out_rel_keys:
                        seen_out_rel_keys.add(rk)
                        outgoing_rels.append(r)

            outgoing_rels.sort(key=lambda r: RELATIONSHIP_PRIORITY.get(r.relationship_type, 9))

            for rel in outgoing_rels:
                if len(impacted_nodes) >= max_nodes:
                    break

                downstream_id = rel.target_id
                # Follow data writes, reads, calls, creations
                if downstream_id in visited_ids and downstream_id in impacted_nodes:
                    _add_impact_edge(curr_id, downstream_id, rel, impact_edges, seen_edge_keys)
                    continue

                if downstream_id == target_node.id or downstream_id == target_node.file:
                    continue

                node = _make_impact_node(
                    node_id=downstream_id,
                    repo=repo,
                    distance=distance,
                    relationship=rel.relationship_type,
                    confidence=rel.confidence,
                    evidence=rel.evidence,
                    trigger_id=curr_id,
                    is_incoming=False,
                )
                if node:
                    visited_ids.add(node.id)
                    impacted_nodes[node.id] = node
                    next_frontier.append(node.id)
                    _add_impact_edge(curr_id, node.id, rel, impact_edges, seen_edge_keys)

                    # If this is a DATA write (e.g. data::medicines), also find components that READ this data!
                    if node.impact_type == ImpactType.DATA and downstream_id.startswith("data::") and (distance + 1 <= max_depth):
                        readers = incoming_by_target.get(downstream_id, [])
                        for read_rel in readers:
                            if len(impacted_nodes) >= max_nodes:
                                break
                            reader_id = read_rel.source_id
                            if reader_id not in visited_ids and reader_id != target_node.id:
                                reader_node = _make_impact_node(
                                    node_id=reader_id,
                                    repo=repo,
                                    distance=distance + 1,
                                    relationship=RelationshipType.READS,
                                    confidence=read_rel.confidence,
                                    evidence=read_rel.evidence,
                                    trigger_id=downstream_id,
                                    is_incoming=False,
                                )
                                if reader_node:
                                    visited_ids.add(reader_node.id)
                                    impacted_nodes[reader_node.id] = reader_node
                                    next_frontier.append(reader_node.id)
                                    _add_impact_edge(downstream_id, reader_node.id, read_rel, impact_edges, seen_edge_keys)

        frontier = next_frontier

    # 4. Partition Impacted Nodes into Categories
    all_nodes_list = list(impacted_nodes.values())
    # Sort by distance, then by impact category
    all_nodes_list.sort(key=lambda n: (n.distance, n.impact_type.value, n.file))

    data_impacts = [n for n in all_nodes_list if n.impact_type == ImpactType.DATA]
    ui_impacts = [n for n in all_nodes_list if n.impact_type == ImpactType.UI]
    test_impacts = [n for n in all_nodes_list if n.impact_type == ImpactType.TEST]
    direct_impacts = [
        n for n in all_nodes_list
        if n.distance == 1 and n.impact_type not in (ImpactType.DATA, ImpactType.UI, ImpactType.TEST)
    ]
    indirect_impacts = [
        n for n in all_nodes_list
        if n.distance > 1 and n.impact_type not in (ImpactType.DATA, ImpactType.UI, ImpactType.TEST)
    ]

    # Collect all unique evidence
    all_evidence: list[Evidence] = list(target_node.evidence)
    for n in all_nodes_list:
        all_evidence.extend(n.evidence)
    for e in impact_edges:
        all_evidence.extend(e.evidence)

    # Deduplicate evidence
    unique_evidence = _deduplicate_evidence(all_evidence)

    # 5. Build Summary
    summary = ImpactSummary(
        target_id=target_node.id,
        target_name=target_node.symbol or Path(target_node.file).name,
        total_impacted=len(all_nodes_list),
        direct_count=len(direct_impacts),
        indirect_count=len(indirect_impacts),
        data_count=len(data_impacts),
        ui_count=len(ui_impacts),
        test_count=len(test_impacts),
        unknown_count=0,
        max_distance=max((n.distance for n in all_nodes_list), default=0),
        description=_generate_impact_description(target_node, all_nodes_list, summary_counts={
            "direct": len(direct_impacts),
            "indirect": len(indirect_impacts),
            "data": len(data_impacts),
            "ui": len(ui_impacts),
            "test": len(test_impacts),
        }),
    )

    # List of all nodes for visual graph (including target)
    graph_nodes = [target_node] + all_nodes_list

    return ImpactAnalysis(
        target=target_node,
        direct_impacts=direct_impacts,
        indirect_impacts=indirect_impacts,
        data_impacts=data_impacts,
        ui_impacts=ui_impacts,
        test_impacts=test_impacts,
        unknowns=[],
        evidence=unique_evidence,
        confidence=Confidence.CONFIRMED if all(n.confidence == Confidence.CONFIRMED for n in direct_impacts) else Confidence.INFERRED,
        summary=summary,
        nodes=graph_nodes,
        edges=impact_edges,
    )


# ---------------------------------------------------------------------------
# Key Hierarchy Helper
# ---------------------------------------------------------------------------

def _get_lookup_keys(node_id: str) -> list[str]:
    """
    Given a node ID (method, class, file, or data identifier), return all
    hierarchical ancestor keys to enable multi-granular relationship lookup.
    """
    keys = [node_id]
    if "::" in node_id:
        fpath, sym = node_id.split("::", 1)
        if "." in sym:
            parent_cls = f"{fpath}::{sym.rsplit('.', 1)[0]}"
            keys.append(parent_cls)
        keys.append(fpath)
    return keys


# ---------------------------------------------------------------------------
# Target Resolution
# ---------------------------------------------------------------------------

def _resolve_target_node(query: str, repo: Repository) -> Optional[ImpactNode]:
    """
    Resolve a user query (symbol, method, class, file, or keyword) to a target ImpactNode.
    """
    q = query.strip()
    q_lower = q.lower()

    # 1. Exact symbol ID match
    if q in repo.symbols:
        sym = repo.symbols[q]
        return _make_target_from_symbol(sym, repo)

    # 2. Exact file path match
    if q in repo.files:
        sf = repo.files[q]
        return _make_target_from_file(q, sf, repo)

    # 3. Qualified name match in symbols (e.g. "MedicineService.addMedicine" or "AuthService.login")
    for sym_id, sym in repo.symbols.items():
        if sym.qualified_name.lower() == q_lower or sym.name.lower() == q_lower:
            return _make_target_from_symbol(sym, repo)

    # 4. Method name inside qualified name (e.g. "addMedicine" matches "MedicineService.addMedicine")
    for sym_id, sym in repo.symbols.items():
        if sym.name.lower() == q_lower:
            return _make_target_from_symbol(sym, repo)

    # 5. File name or stem match (e.g. "medicine_service.dart" or "medicine_service")
    for fp, sf in repo.files.items():
        stem = Path(fp).stem.lower()
        fname = Path(fp).name.lower()
        if fname == q_lower or stem == q_lower or fp.lower().endswith(f"/{q_lower}") or fp.lower().endswith(f"/{q_lower}.dart"):
            return _make_target_from_file(fp, sf, repo)

    # 6. Field / keyword search in symbols
    q_tokens = _tokenize(q)
    scored_syms: list[tuple[float, Symbol]] = []
    for sym_id, sym in repo.symbols.items():
        name_tokens = _tokenize(sym.qualified_name)
        score = 0.0
        for tok in q_tokens:
            if tok in name_tokens:
                score += 2.0
            elif any(t.startswith(tok) for t in name_tokens):
                score += 1.0
        if score > 0:
            if sym.symbol_type == SymbolType.CLASS:
                score *= 1.4
            elif sym.symbol_type == SymbolType.METHOD:
                score *= 1.2
            scored_syms.append((score, sym))

    if scored_syms:
        scored_syms.sort(key=lambda x: x[0], reverse=True)
        return _make_target_from_symbol(scored_syms[0][1], repo)

    # 7. Scored files
    scored_files: list[tuple[float, str, SourceFile]] = []
    for fp, sf in repo.files.items():
        file_tokens = _tokenize(fp)
        score = 0.0
        for tok in q_tokens:
            if tok in file_tokens:
                score += 2.0
        if score > 0:
            scored_files.append((score, fp, sf))

    if scored_files:
        scored_files.sort(key=lambda x: x[0], reverse=True)
        return _make_target_from_file(scored_files[0][1], scored_files[0][2], repo)

    return None


def _make_target_from_symbol(sym: Symbol, repo: Repository) -> ImpactNode:
    """Create a Target ImpactNode from a Symbol."""
    evidence = _get_symbol_evidence(sym, repo)
    return ImpactNode(
        id=sym.id,
        file=sym.file,
        symbol=sym.qualified_name,
        symbol_id=sym.id,
        symbol_type=sym.symbol_type,
        impact_type=ImpactType.DIRECT,
        distance=0,
        confidence=Confidence.CONFIRMED,
        reason=f"Target component selected for change analysis: {sym.qualified_name}",
        evidence=evidence,
    )


def _make_target_from_file(fp: str, sf: SourceFile, repo: Repository) -> ImpactNode:
    """Create a Target ImpactNode from a SourceFile."""
    return ImpactNode(
        id=fp,
        file=fp,
        symbol=Path(fp).name,
        impact_type=ImpactType.DIRECT,
        distance=0,
        confidence=Confidence.CONFIRMED,
        reason=f"Target file selected for change analysis: {Path(fp).name}",
        evidence=[Evidence(
            file=fp,
            line_start=1,
            line_end=min(sf.line_count, 10),
            snippet=f"File: {fp} ({sf.language})",
            description=f"Source file {Path(fp).name}",
        )],
    )


# ---------------------------------------------------------------------------
# Node Construction & Impact Categorization
# ---------------------------------------------------------------------------

def _make_impact_node(
    node_id: str,
    repo: Repository,
    distance: int,
    relationship: RelationshipType,
    confidence: Confidence,
    evidence: list[Evidence],
    trigger_id: str,
    is_incoming: bool,
) -> Optional[ImpactNode]:
    """Construct an ImpactNode with inferred impact type and explanatory reason."""
    # Data store
    if node_id.startswith("data::"):
        coll_name = node_id.replace("data::", "")
        return ImpactNode(
            id=node_id,
            file="[data store]",
            symbol=coll_name,
            symbol_id=node_id,
            impact_type=ImpactType.DATA,
            relationship=relationship,
            distance=distance,
            confidence=confidence,
            reason=f"Data storage / collection '{coll_name}' is mutated or accessed by {_shorten_id(trigger_id)}",
            evidence=evidence,
        )

    # Symbol
    if node_id in repo.symbols:
        sym = repo.symbols[node_id]
        role = _infer_role(sym.file, sym.name, [])
        impact_type = _classify_impact_type(sym.file, role, relationship, distance, is_incoming, repo)
        reason = _build_impact_reason(sym.qualified_name, trigger_id, relationship, distance, impact_type, is_incoming)
        return ImpactNode(
            id=sym.id,
            file=sym.file,
            symbol=sym.qualified_name,
            symbol_id=sym.id,
            symbol_type=sym.symbol_type,
            impact_type=impact_type,
            relationship=relationship,
            distance=distance,
            confidence=confidence,
            reason=reason,
            evidence=evidence if evidence else _get_symbol_evidence(sym, repo),
        )

    # Method where symbol ID has format file::Class.method
    if "::" in node_id:
        file_part, sym_part = node_id.split("::", 1)
        role = _infer_role(file_part, sym_part, [])
        impact_type = _classify_impact_type(file_part, role, relationship, distance, is_incoming, repo)
        reason = _build_impact_reason(sym_part, trigger_id, relationship, distance, impact_type, is_incoming)
        return ImpactNode(
            id=node_id,
            file=file_part,
            symbol=sym_part,
            symbol_id=node_id,
            symbol_type=SymbolType.METHOD,
            impact_type=impact_type,
            relationship=relationship,
            distance=distance,
            confidence=confidence,
            reason=reason,
            evidence=evidence,
        )

    # File
    if node_id in repo.files:
        sf = repo.files[node_id]
        role = _infer_role(node_id, Path(node_id).stem, [])
        impact_type = _classify_impact_type(node_id, role, relationship, distance, is_incoming, repo)
        reason = _build_impact_reason(Path(node_id).name, trigger_id, relationship, distance, impact_type, is_incoming)
        return ImpactNode(
            id=node_id,
            file=node_id,
            symbol=Path(node_id).name,
            impact_type=impact_type,
            relationship=relationship,
            distance=distance,
            confidence=confidence,
            reason=reason,
            evidence=evidence,
        )

    return None


def _classify_impact_type(
    file_path: str,
    role: str,
    relationship: RelationshipType,
    distance: int,
    is_incoming: bool,
    repo: Repository,
) -> ImpactType:
    """Categorize an impacted component into TEST, DATA, UI, API, DIRECT, or INDIRECT."""
    fp_lower = file_path.lower()

    # Test impact
    if "test" in fp_lower or relationship == RelationshipType.TESTS or role == "Test":
        return ImpactType.TEST

    # Data impact
    if file_path.startswith("data::") or "model" in fp_lower or role in ("Data Model", "Data Store"):
        return ImpactType.DATA

    # UI impact
    if "screen" in fp_lower or "page" in fp_lower or "widget" in fp_lower or role == "UI / Screen":
        return ImpactType.UI

    # API / Route impact
    if "route" in fp_lower or "controller" in fp_lower or "api" in fp_lower or role in ("Controller / Route", "API Client"):
        return ImpactType.API

    # Direct vs Indirect
    if distance == 1:
        return ImpactType.DIRECT
    else:
        return ImpactType.INDIRECT


def _build_impact_reason(
    name: str,
    trigger_id: str,
    relationship: RelationshipType,
    distance: int,
    impact_type: ImpactType,
    is_incoming: bool,
) -> str:
    """Generate human-readable rationale for the change impact."""
    trigger_name = _shorten_id(trigger_id)

    if impact_type == ImpactType.TEST:
        return f"Test suite '{name}' tests or depends on '{trigger_name}' and may fail if behavior changes."

    if impact_type == ImpactType.DATA:
        return f"Data entity/model '{name}' is directly referenced or mutated by '{trigger_name}'."

    if impact_type == ImpactType.UI:
        return f"UI Screen '{name}' interacts with or triggers '{trigger_name}' (distance: {distance} hop{'s' if distance > 1 else ''})."

    if distance == 1:
        if relationship == RelationshipType.CALLS:
            return f"Direct caller: '{name}' invokes '{trigger_name}'."
        elif relationship == RelationshipType.CREATES:
            return f"Direct dependency: '{name}' instantiates '{trigger_name}'."
        elif relationship == RelationshipType.IMPORTS:
            return f"Module dependency: '{name}' imports '{trigger_name}'."
        elif relationship == RelationshipType.EXTENDS:
            return f"Structural dependency: '{name}' extends/implements '{trigger_name}'."
        else:
            return f"Direct {relationship.value} dependency with '{trigger_name}'."
    else:
        return f"Transitive dependency ({distance} hops): reached via '{trigger_name}' through {relationship.value} relationship."


def _add_impact_edge(
    src_id: str,
    tgt_id: str,
    rel: Relationship,
    edges: list[TraceEdge],
    seen_edge_keys: set[tuple[str, str, RelationshipType]],
) -> None:
    """Add a verified directed trace edge between two components."""
    if src_id == tgt_id:
        return
    key = (src_id, tgt_id, rel.relationship_type)
    if key not in seen_edge_keys:
        seen_edge_keys.add(key)
        edges.append(TraceEdge(
            source_id=src_id,
            target_id=tgt_id,
            relationship_type=rel.relationship_type,
            label=rel.relationship_type.value,
            evidence=rel.evidence[:2],
            confidence=rel.confidence,
        ))


def _deduplicate_evidence(ev_list: list[Evidence]) -> list[Evidence]:
    """Deduplicate evidence objects by (file, line_start, snippet)."""
    seen: set[tuple[str, Optional[int], Optional[str]]] = set()
    result: list[Evidence] = []
    for ev in ev_list:
        key = (ev.file, ev.line_start, ev.snippet)
        if key not in seen:
            seen.add(key)
            result.append(ev)
    return result


def _generate_impact_description(
    target: ImpactNode,
    impacted: list[ImpactNode],
    summary_counts: dict[str, int],
) -> str:
    """Generate overall summary description of the change impact."""
    if not impacted:
        return f"No dependencies found for '{target.symbol or target.file}'. Changes will have isolated local scope."

    files_impacted = list(dict.fromkeys(n.file for n in impacted if n.file != "[data store]"))
    parts = []
    if summary_counts["direct"] > 0:
        parts.append(f"{summary_counts['direct']} direct caller{'s' if summary_counts['direct'] != 1 else ''}")
    if summary_counts["indirect"] > 0:
        parts.append(f"{summary_counts['indirect']} indirect caller{'s' if summary_counts['indirect'] != 1 else ''}")
    if summary_counts["ui"] > 0:
        parts.append(f"{summary_counts['ui']} UI screen{'s' if summary_counts['ui'] != 1 else ''}")
    if summary_counts["data"] > 0:
        parts.append(f"{summary_counts['data']} data store/model{'s' if summary_counts['data'] != 1 else ''}")
    if summary_counts["test"] > 0:
        parts.append(f"{summary_counts['test']} test file{'s' if summary_counts['test'] != 1 else ''}")

    breakdown = ", ".join(parts)
    return (
        f"Modifying '{target.symbol or Path(target.file).name}' potentially impacts {len(impacted)} components "
        f"across {len(files_impacted)} file{'s' if len(files_impacted) != 1 else ''} ({breakdown})."
    )
