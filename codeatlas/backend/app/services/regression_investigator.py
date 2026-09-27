"""
Regression Investigator — Generic Regression Analysis Engine.

Answers:
"Why did this change cause a regression?"
"What existing behavior is at risk because of this change?"

Combines:
- Git diffs / changed symbols
- Static repository knowledge graph
- Cross-file call/data/UI relationships
- Test metadata and coverage associations
- Static regression signals (edge cases, calculations, state, contracts)
- Verifiable source evidence
"""

from __future__ import annotations

import posixpath
import re
from pathlib import Path
from typing import Optional

from app.models.repository import (
    Repository, Symbol, SourceFile, Relationship,
    RelationshipType, Confidence, Evidence, SymbolType,
    ImpactType, ImpactNode, TraceEdge,
    RiskSeverity, RiskCategory, RegressionRisk,
    ChangedFile, RegressionSummary, RegressionAnalysis,
)
from app.analyzers.diff_parser import parse_git_diff, detect_changed_symbols
from app.services.impact_radar import (
    _resolve_target_node, _get_lookup_keys, _make_impact_node,
    _add_impact_edge, _deduplicate_evidence, RELATIONSHIP_PRIORITY,
)
from app.services.feature_tracer import _tokenize, _infer_role, _shorten_id


# ---------------------------------------------------------------------------
# Signal Regex Patterns
# ---------------------------------------------------------------------------

EDGE_CASE_PATTERNS = [
    re.compile(r"(\w+)\s*(?:==|<=|>=|<|>)\s*0\b"),
    re.compile(r"(\w+)\.isEmpty\b"),
    re.compile(r"(\w+)\.length\s*(?:==|<=|<)\s*0\b"),
    re.compile(r"(\w+)\s*==\s*null\b"),
    re.compile(r"(\w+)\s*!=\s*null\b"),
    re.compile(r"\belse\s+if\s*\((.*?)\)"),
    re.compile(r"\bclamp\s*\(\s*\d+\s*,\s*\d+\s*\)"),
]

CALCULATION_PATTERNS = [
    re.compile(r"\((.*?)\s*[/]\s*(.*?)\)\s*[*]\s*100"),  # percentage
    re.compile(r"\.round\s*\(\s*\)"),
    re.compile(r"\b(adherence|score|rate|percentage|ratio|average|mean|total)\b", re.IGNORECASE),
]

STATE_PATTERNS = [
    re.compile(r"\b(status|state|mode|phase)\s*==\s*['\"](\w+)['\"]"),
    re.compile(r"\b(taken|undone|completed|pending|active|canceled|failed)\b", re.IGNORECASE),
    re.compile(r"setState\s*\("),
]


# ---------------------------------------------------------------------------
# Public Entry Point
# ---------------------------------------------------------------------------

def investigate_regression(
    repo: Repository,
    diff_text: Optional[str] = None,
    query: Optional[str] = None,
    changed_file_paths: Optional[list[str]] = None,
    max_depth: int = 3,
    max_nodes: int = 60,
) -> RegressionAnalysis:
    """
    Run the Regression Investigator on a repository given a Git diff,
    a list of changed files, or a natural-language description of a change.
    """
    # 1. Parse and Resolve Changed Files and Symbols
    changed_files: list[ChangedFile] = []
    changed_symbols: list[Symbol] = []
    unknowns: list[str] = []

    if diff_text and diff_text.strip():
        parsed_files = parse_git_diff(diff_text.strip())
        changed_files, changed_symbols = detect_changed_symbols(parsed_files, repo)
    elif changed_file_paths:
        for fp in changed_file_paths:
            cf = ChangedFile(file=fp.strip(), status="modified")
            changed_files.append(cf)
        changed_files, changed_symbols = detect_changed_symbols(changed_files, repo)
    elif query and query.strip():
        # Natural language or symbol query
        target_node = _resolve_target_node(query.strip(), repo)
        if target_node and target_node.file:
            cf = ChangedFile(file=target_node.file, status="modified")
            if target_node.symbol:
                cf.changed_symbols.append(target_node.symbol)
            changed_files = [cf]
            if target_node.symbol_id and target_node.symbol_id in repo.symbols:
                changed_symbols = [repo.symbols[target_node.symbol_id]]
            else:
                changed_files, changed_symbols = detect_changed_symbols([cf], repo)
        else:
            unknowns.append(f"Target query '{query}' could not be resolved to a specific repository component.")

    if not changed_files and not changed_symbols:
        summary = RegressionSummary(
            description="No changed files or symbols could be identified for regression analysis.",
        )
        return RegressionAnalysis(
            query=query,
            unknowns=unknowns or ["No diff, changed files, or valid symbol query was provided."],
            confidence=Confidence.UNKNOWN,
            summary=summary,
        )

    # 2. Build Changed Symbols ImpactNodes
    changed_symbol_nodes: list[ImpactNode] = []
    seen_changed_ids: set[str] = set()

    for sym in changed_symbols:
        if sym.id not in seen_changed_ids:
            seen_changed_ids.add(sym.id)
            ev = _get_symbol_evidence_direct(sym, repo)
            changed_symbol_nodes.append(
                ImpactNode(
                    id=sym.id,
                    file=sym.file,
                    symbol=sym.qualified_name,
                    symbol_id=sym.id,
                    symbol_type=sym.symbol_type,
                    impact_type=ImpactType.DIRECT,
                    distance=0,
                    confidence=Confidence.CONFIRMED,
                    reason=f"Changed component in {Path(sym.file).name}",
                    evidence=ev,
                )
            )

    # If no specific symbols were matched but files were changed, create nodes for changed files
    if not changed_symbol_nodes:
        for cf in changed_files:
            if cf.file in repo.files and cf.file not in seen_changed_ids:
                seen_changed_ids.add(cf.file)
                sf = repo.files[cf.file]
                changed_symbol_nodes.append(
                    ImpactNode(
                        id=cf.file,
                        file=cf.file,
                        symbol=Path(cf.file).name,
                        impact_type=ImpactType.DIRECT,
                        distance=0,
                        confidence=Confidence.CONFIRMED,
                        reason=f"Changed file: {cf.file}",
                        evidence=[
                            Evidence(
                                file=cf.file,
                                line_start=1,
                                line_end=min(10, sf.line_count),
                                snippet=(sf._content.splitlines()[0] if sf._content else "") if sf._content else "",
                                description=f"Modified file {cf.file}",
                            )
                        ],
                    )
                )

    # 3. Traverse Repository Graph for Affected Callers, Screens, Stores, and Tests
    incoming_by_target: dict[str, list[Relationship]] = {}
    outgoing_by_source: dict[str, list[Relationship]] = {}
    for rel in repo.relationships:
        incoming_by_target.setdefault(rel.target_id, []).append(rel)
        outgoing_by_source.setdefault(rel.source_id, []).append(rel)

    affected_nodes: dict[str, ImpactNode] = {}
    impact_edges: list[TraceEdge] = []
    seen_edge_keys: set[tuple[str, str, str]] = set()
    visited_ids: set[str] = set(n.id for n in changed_symbol_nodes)
    frontier: list[str] = list(visited_ids)

    for dist in range(1, max_depth + 1):
        next_frontier: list[str] = []
        for curr_id in frontier:
            if len(affected_nodes) >= max_nodes:
                break

            lookup_keys = _get_lookup_keys(curr_id)

            # A. Incoming Callers / Importers / Testers
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
                if len(affected_nodes) >= max_nodes:
                    break
                caller_id = rel.source_id
                if caller_id in visited_ids and caller_id in affected_nodes:
                    _add_impact_edge(caller_id, curr_id, rel, impact_edges, seen_edge_keys)
                    continue
                if caller_id in seen_changed_ids:
                    continue

                node = _make_impact_node(
                    node_id=caller_id,
                    repo=repo,
                    distance=dist,
                    relationship=rel.relationship_type,
                    confidence=rel.confidence,
                    evidence=rel.evidence,
                    trigger_id=curr_id,
                    is_incoming=True,
                )
                if node:
                    visited_ids.add(node.id)
                    affected_nodes[node.id] = node
                    next_frontier.append(node.id)
                    _add_impact_edge(node.id, curr_id, rel, impact_edges, seen_edge_keys)

            # B. Outgoing Callees / Data writes / Reads / Creates
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
                if len(affected_nodes) >= max_nodes:
                    break
                downstream_id = rel.target_id
                if downstream_id in visited_ids and downstream_id in affected_nodes:
                    _add_impact_edge(curr_id, downstream_id, rel, impact_edges, seen_edge_keys)
                    continue
                if downstream_id in seen_changed_ids:
                    continue

                node = _make_impact_node(
                    node_id=downstream_id,
                    repo=repo,
                    distance=dist,
                    relationship=rel.relationship_type,
                    confidence=rel.confidence,
                    evidence=rel.evidence,
                    trigger_id=curr_id,
                    is_incoming=False,
                )
                if node:
                    visited_ids.add(node.id)
                    affected_nodes[node.id] = node
                    next_frontier.append(node.id)
                    _add_impact_edge(curr_id, node.id, rel, impact_edges, seen_edge_keys)

        frontier = next_frontier

    all_affected_list = list(affected_nodes.values())
    all_affected_list.sort(key=lambda n: (n.distance, n.impact_type.value, n.file))

    # Separate related tests from general affected components
    related_tests = [n for n in all_affected_list if n.impact_type == ImpactType.TEST]
    non_test_affected = [n for n in all_affected_list if n.impact_type != ImpactType.TEST]

    # 4. Discover and Synthesize Evidence-Based Regression Risks
    risks: list[RegressionRisk] = []
    risk_id_counter = 1

    # Inspect changed files, hunks, and symbols for regression signals
    for cf in changed_files:
        src_file = repo.files.get(cf.file)
        file_content = src_file._content if src_file else ""
        content_lines = file_content.splitlines() if file_content else []

        # Collect changed code text (from hunks if available, or from symbol spans)
        changed_lines_text: list[tuple[int, str]] = []
        if cf.hunks:
            for hunk in cf.hunks:
                for line_idx, line in enumerate(hunk.added_lines, start=hunk.new_start):
                    changed_lines_text.append((line_idx, line))
                for line_idx, line in enumerate(hunk.removed_lines, start=hunk.old_start):
                    changed_lines_text.append((line_idx, line))

        # Fallback to lines in changed symbols if hunks were not parsed
        if not changed_lines_text and changed_symbols:
            for sym in changed_symbols:
                if sym.file == cf.file and sym.line_start and sym.line_end:
                    start_idx = max(0, sym.line_start - 1)
                    end_idx = min(len(content_lines), sym.line_end)
                    for l_no, text in enumerate(content_lines[start_idx:end_idx], start=start_idx + 1):
                        changed_lines_text.append((l_no, text))

        # Check Signal 1: Edge Cases & Conditional Branches
        for l_no, text in changed_lines_text:
            for pattern in EDGE_CASE_PATTERNS:
                match = pattern.search(text)
                if match:
                    matched_cond = match.group(0).strip()
                    matched_var = match.group(1) if match.groups() else ""
                    # Find surrounding symbol
                    sym_name = _find_enclosing_symbol_name(cf.file, l_no, repo)
                    
                    evidence_item = Evidence(
                        file=cf.file,
                        line_start=l_no,
                        line_end=l_no,
                        snippet=text.strip(),
                        description=f"Conditional edge-case branch in {sym_name}: '{matched_cond}'",
                    )

                    has_callers = len(non_test_affected) > 0
                    severity = RiskSeverity.HIGH if has_callers else RiskSeverity.MEDIUM
                    
                    suggested = f"Assert behavior of {sym_name} when {matched_var or 'input'} satisfies '{matched_cond}' and boundary states."
                    if "0" in matched_cond:
                        suggested = f"Assert {sym_name} when total count is 0 (e.g., {matched_var or 'count'} == 0) to verify default fallback."

                    risks.append(
                        RegressionRisk(
                            id=f"RISK-{risk_id_counter:03d}",
                            severity=severity,
                            category=RiskCategory.EDGE_CASE,
                            title=f"Potential edge-case / boundary condition regression in {sym_name}",
                            description=f"Conditional logic '{matched_cond}' was altered in {cf.file}. Dependent callers and screens may exhibit unexpected behavior on boundary inputs.",
                            source=f"{cf.file}::{sym_name}" if sym_name else cf.file,
                            related_component=non_test_affected[0].id if non_test_affected else None,
                            confidence=Confidence.CONFIRMED,
                            evidence=[evidence_item],
                            suggested_test=suggested,
                        )
                    )
                    risk_id_counter += 1
                    break

        # Check Signal 2: Business Logic / Calculation Modification
        for l_no, text in changed_lines_text:
            for pattern in CALCULATION_PATTERNS:
                match = pattern.search(text)
                if match:
                    matched_calc = match.group(0).strip()
                    sym_name = _find_enclosing_symbol_name(cf.file, l_no, repo)
                    evidence_item = Evidence(
                        file=cf.file,
                        line_start=l_no,
                        line_end=l_no,
                        snippet=text.strip(),
                        description=f"Metric calculation / arithmetic logic in {sym_name}: '{matched_calc}'",
                    )
                    # Check if UI screens or reports depend on this calculation
                    dependent_ui = [n for n in non_test_affected if n.impact_type == ImpactType.UI]
                    severity = RiskSeverity.HIGH if dependent_ui else RiskSeverity.MEDIUM

                    risks.append(
                        RegressionRisk(
                            id=f"RISK-{risk_id_counter:03d}",
                            severity=severity,
                            category=RiskCategory.BUSINESS_LOGIC,
                            title=f"Metric calculation / formula modified in {sym_name}",
                            description=f"Calculation logic '{matched_calc}' in {cf.file} was modified. Downstream consumers and UI reports relying on this metric may receive shifted values.",
                            source=f"{cf.file}::{sym_name}" if sym_name else cf.file,
                            related_component=dependent_ui[0].id if dependent_ui else (non_test_affected[0].id if non_test_affected else None),
                            confidence=Confidence.CONFIRMED,
                            evidence=[evidence_item],
                            suggested_test=f"Verify calculation output of {sym_name} across varying input values, empty sets, and upper/lower bounds.",
                        )
                    )
                    risk_id_counter += 1
                    break

        # Check Signal 3: Downstream UI & Threshold Alerts
        dependent_ui = [n for n in non_test_affected if n.impact_type == ImpactType.UI]
        if dependent_ui and changed_symbols:
            primary_sym = changed_symbols[0]
            screen_names = ", ".join(sorted(list(set(Path(n.file).name for n in dependent_ui[:4]))))
            risks.append(
                RegressionRisk(
                    id=f"RISK-{risk_id_counter:03d}",
                    severity=RiskSeverity.HIGH,
                    category=RiskCategory.UI,
                    title=f"Downstream UI screens and alert thresholds affected by {primary_sym.name}",
                    description=f"UI components ({screen_names}) depend on {primary_sym.qualified_name} for presentation and threshold checks.",
                    source=f"{primary_sym.file}::{primary_sym.qualified_name}",
                    related_component=dependent_ui[0].id,
                    confidence=Confidence.CONFIRMED,
                    evidence=list(dependent_ui[0].evidence[:2]),
                    suggested_test=f"Validate UI rendering and threshold color/status alerts on {screen_names}.",
                )
            )
            risk_id_counter += 1

        # Check Signal 4: Test Coverage Assessment
        # If changed business logic symbols have no related tests in repository
        for sym in changed_symbols:
            matching_tests = [
                t for t in related_tests
                if sym.file in t.id or sym.name in t.id or sym.name.lower() in t.file.lower()
            ]
            if not matching_tests and not related_tests:
                risks.append(
                    RegressionRisk(
                        id=f"RISK-{risk_id_counter:03d}",
                        severity=RiskSeverity.HIGH,
                        category=RiskCategory.TEST_COVERAGE,
                        title=f"Missing automated test coverage for {sym.qualified_name}",
                        description=f"No automated test suites were detected in the repository covering {sym.qualified_name}. Regressions in this component cannot be caught automatically.",
                        source=f"{sym.file}::{sym.qualified_name}",
                        confidence=Confidence.CONFIRMED,
                        evidence=_get_symbol_evidence_direct(sym, repo),
                        suggested_test=f"Implement unit tests for {sym.qualified_name} verifying nominal and edge-case execution paths.",
                    )
                )
                risk_id_counter += 1
            else:
                # Tests exist, but check if boundary / zero cases are asserted
                test_file_names = ", ".join(list(set(Path(t.file).name for t in (matching_tests or related_tests)[:2])))
                risks.append(
                    RegressionRisk(
                        id=f"RISK-{risk_id_counter:03d}",
                        severity=RiskSeverity.MEDIUM,
                        category=RiskCategory.TEST_COVERAGE,
                        title=f"Incomplete edge-case test validation in {test_file_names}",
                        description=f"Existing test suite ({test_file_names}) tests {sym.name} but may lack coverage for boundary/zero-state conditions.",
                        source=f"{sym.file}::{sym.qualified_name}",
                        related_component=(matching_tests or related_tests)[0].id,
                        confidence=Confidence.INFERRED,
                        evidence=list((matching_tests or related_tests)[0].evidence[:1]),
                        suggested_test=f"Add dedicated test case in {test_file_names} asserting {sym.name} behavior on empty and boundary inputs.",
                    )
                )
                risk_id_counter += 1

    # Deduplicate risks by title
    unique_risks: list[RegressionRisk] = []
    seen_risk_titles: set[str] = set()
    for r in risks:
        if r.title not in seen_risk_titles:
            seen_risk_titles.add(r.title)
            unique_risks.append(r)

    # 5. Collect All Evidence
    all_evidence: list[Evidence] = []
    for node in changed_symbol_nodes:
        all_evidence.extend(node.evidence)
    for node in all_affected_list:
        all_evidence.extend(node.evidence)
    for risk in unique_risks:
        all_evidence.extend(risk.evidence)
    for edge in impact_edges:
        all_evidence.extend(edge.evidence)

    deduped_evidence = _deduplicate_evidence(all_evidence)

    # 6. Build Summary Metrics
    high_count = sum(1 for r in unique_risks if r.severity == RiskSeverity.HIGH)
    med_count = sum(1 for r in unique_risks if r.severity == RiskSeverity.MEDIUM)
    low_count = sum(1 for r in unique_risks if r.severity == RiskSeverity.LOW)

    summary_desc = (
        f"Analyzed {len(changed_files)} changed file(s) and {len(changed_symbols)} symbol(s). "
        f"Identified {len(non_test_affected)} affected component(s), {len(related_tests)} related test(s), "
        f"and {len(unique_risks)} potential regression risk(s) ({high_count} HIGH, {med_count} MEDIUM)."
    )

    summary = RegressionSummary(
        changed_files_count=len(changed_files),
        changed_symbols_count=len(changed_symbols),
        affected_components_count=len(non_test_affected),
        risks_count=len(unique_risks),
        high_risk_count=high_count,
        medium_risk_count=med_count,
        low_risk_count=low_count,
        tests_count=len(related_tests),
        description=summary_desc,
    )

    # All nodes for graph visualization (changed + affected + tests)
    graph_nodes = changed_symbol_nodes + all_affected_list

    return RegressionAnalysis(
        query=query,
        changed_files=changed_files,
        changed_symbols=changed_symbol_nodes,
        affected_components=non_test_affected,
        risks=unique_risks,
        related_tests=related_tests,
        evidence=deduped_evidence,
        unknowns=unknowns,
        confidence=Confidence.CONFIRMED if all(r.confidence == Confidence.CONFIRMED for r in unique_risks[:3]) else Confidence.INFERRED,
        summary=summary,
        nodes=graph_nodes,
        edges=impact_edges,
    )


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _find_enclosing_symbol_name(file_path: str, line_no: int, repo: Repository) -> str:
    """Find the name of the symbol enclosing line_no in file_path."""
    src = repo.files.get(file_path)
    if not src:
        return ""
    for sym in src.symbols:
        if sym.line_start <= line_no <= sym.line_end:
            return sym.qualified_name
    return ""


def _get_symbol_evidence_direct(sym: Symbol, repo: Repository) -> list[Evidence]:
    """Get verifiable Evidence snippet for a Symbol directly."""
    src = repo.files.get(sym.file)
    if not src or not src._content:
        return [
            Evidence(
                file=sym.file,
                line_start=sym.line_start,
                line_end=sym.line_end,
                description=f"Definition of {sym.qualified_name}",
            )
        ]
    lines = src._content.splitlines()
    start_idx = max(0, sym.line_start - 1)
    end_idx = min(len(lines), sym.line_end)
    snippet_lines = lines[start_idx:min(start_idx + 4, end_idx)]
    snippet = "\n".join(snippet_lines)
    return [
        Evidence(
            file=sym.file,
            line_start=sym.line_start,
            line_end=sym.line_start + len(snippet_lines) - 1,
            snippet=snippet,
            description=f"Definition of {sym.qualified_name}",
        )
    ]
