import sys
sys.path.insert(0, r'C:\Users\Sahil\Downloads\CodeAtlas\codeatlas\backend')

from app.analyzers.repository_scanner import scan_repository
from app.services.feature_tracer import trace_feature

print('Scanning CareSync...')
import os
from pathlib import Path

caresync_path = Path(__file__).parent.parent.parent / "caresync_source"
if not caresync_path.exists():
    caresync_path = Path(r"C:\Users\Sahil\care-sync-25A15")

repo = scan_repository(
    repo_root=str(caresync_path),
    repo_name='CareSync'
)

print(f'Status: {repo.status}')
print(f'Total files: {repo.total_files}')
print(f'Source files: {repo.source_files}')
langs = dict(list(repo.languages.items())[:8])
print(f'Languages: {langs}')
print(f'Symbols: {len(repo.symbols)}')
print(f'Relationships: {len(repo.relationships)}')
print(f'Entry points: {repo.entry_points[:5]}')
print()

print('--- TRACE 1: prescription scanning ---')
result = trace_feature('Trace prescription scanning', repo)
print(f'Summary: {result.summary}')
print(f'Nodes: {result.total_nodes}, Edges: {result.total_edges}')
for n in result.nodes[:10]:
    sym = n.symbol if n.symbol else "(file)"
    print(f'  [{n.confidence}] {n.file} :: {sym} | {n.role}')

print()
print('--- TRACE 2: medicine management ---')
result2 = trace_feature('Trace medicine management', repo)
print(f'Summary: {result2.summary}')
for n in result2.nodes[:8]:
    sym = n.symbol if n.symbol else "(file)"
    print(f'  [{n.confidence}] {n.file} :: {sym} | {n.role}')

print()
print('--- TRACE 3: authentication ---')
result3 = trace_feature('Where is user authentication implemented', repo)
print(f'Summary: {result3.summary}')
for n in result3.nodes[:6]:
    sym = n.symbol if n.symbol else "(file)"
    print(f'  [{n.confidence}] {n.file} :: {sym} | {n.role}')

print()
print('--- TRACE 4: health connect steps ---')
result4 = trace_feature('How does step tracking work', repo)
print(f'Summary: {result4.summary}')
for n in result4.nodes[:6]:
    sym = n.symbol if n.symbol else "(file)"
    print(f'  [{n.confidence}] {n.file} :: {sym} | {n.role}')

print()
print('====================================================')
print('CHANGE IMPACT RADAR DEMONSTRATIONS')
print('====================================================')
from app.services.impact_radar import analyze_impact

print('--- IMPACT SCENARIO 1: MedicineService.addMedicine ---')
impact1 = analyze_impact('MedicineService.addMedicine', repo, max_depth=3)
print(f'Target: {impact1.target.id} ({impact1.target.symbol_type})')
print(f'Summary: {impact1.summary.description}')
print(f'Direct: {impact1.summary.direct_count}, Indirect: {impact1.summary.indirect_count}, Data: {impact1.summary.data_count}, UI: {impact1.summary.ui_count}, Test: {impact1.summary.test_count}')
print(f'Total Impacted: {impact1.summary.total_impacted}')
print('Sample Direct Impacts:')
for n in impact1.direct_impacts[:5]:
    print(f'  [{n.impact_type.value} | {n.confidence.value}] {n.file} :: {n.symbol} -> {n.reason}')
print('Sample UI Impacts:')
for n in impact1.ui_impacts[:5]:
    print(f'  [{n.impact_type.value} | {n.confidence.value}] {n.file} :: {n.symbol} -> {n.reason}')
print('Sample Test Impacts:')
for n in impact1.test_impacts[:3]:
    print(f'  [{n.impact_type.value} | {n.confidence.value}] {n.file} :: {n.symbol} -> {n.reason}')
print('Sample Evidence:')
for ev in impact1.evidence[:3]:
    print(f'  [EVIDENCE] {ev.file}:{ev.line_start}-{ev.line_end} | {ev.description}')
    if ev.snippet:
        first_line = ev.snippet.split("\n")[0]
        print(f'     "{first_line.strip()}"')

print()
print('--- IMPACT SCENARIO 2: medicine_name (Data Identifier) ---')
impact2 = analyze_impact('medicine_name', repo, max_depth=3)
print(f'Target: {impact2.target.id}')
print(f'Total Impacted: {impact2.summary.total_impacted}')
print(f'Direct: {impact2.summary.direct_count}, Indirect: {impact2.summary.indirect_count}, Data: {impact2.summary.data_count}, UI: {impact2.summary.ui_count}, Test: {impact2.summary.test_count}')

print()
print('--- IMPACT SCENARIO 3: medicine_service.dart (File Target) ---')
impact3 = analyze_impact('medicine_service.dart', repo, max_depth=3)
print(f'Target: {impact3.target.id}')
print(f'Total Impacted: {impact3.summary.total_impacted}')
print(f'Direct: {impact3.summary.direct_count}, Indirect: {impact3.summary.indirect_count}, Data: {impact3.summary.data_count}, UI: {impact3.summary.ui_count}, Test: {impact3.summary.test_count}')

print()
print('====================================================')
print('REGRESSION INVESTIGATOR DEMONSTRATIONS')
print('====================================================')
from app.services.regression_investigator import investigate_regression

adherence_diff = """\
diff --git a/lib/services/medicine_service.dart b/lib/services/medicine_service.dart
--- a/lib/services/medicine_service.dart
+++ b/lib/services/medicine_service.dart
@@ -580,6 +580,8 @@ class MedicineService {
       int adherence = 0;
       if (totalLogs > 0) {
         final takenCount = allLogs.where((l) => l['status'] == 'taken').length;
-        adherence = ((takenCount / totalLogs) * 100).round().clamp(0, 100);
+        adherence = ((takenCount / totalLogs) * 100).round();
       } else if (inventory.isNotEmpty) {
-        adherence = 100;
+        adherence = 0;
       }
"""

print('--- REGRESSION SCENARIO: CareSync Medicine Adherence Diff ---')
reg_analysis = investigate_regression(repo, diff_text=adherence_diff, max_depth=3)
print(f'Summary: {reg_analysis.summary.description}')
print(f'Changed Files: {reg_analysis.summary.changed_files_count}')
print(f'Changed Symbols: {reg_analysis.summary.changed_symbols_count}')
print(f'Affected Components: {reg_analysis.summary.affected_components_count}')
print(f'Related Tests: {reg_analysis.summary.tests_count}')
print(f'Risks: {reg_analysis.summary.risks_count} (High: {reg_analysis.summary.high_risk_count}, Med: {reg_analysis.summary.medium_risk_count})')
print()
print('Discovered Regression Risks:')
for risk in reg_analysis.risks:
    print(f'  [{risk.severity.value} | {risk.category.value}] {risk.title}')
    print(f'     Reason: {risk.description}')
    if risk.suggested_test:
        print(f'     Suggested Test: {risk.suggested_test}')
    if risk.evidence:
        print(f'     Evidence: {risk.evidence[0].file}:{risk.evidence[0].line_start} -> "{risk.evidence[0].snippet}"')
    print()

print('Done.')
