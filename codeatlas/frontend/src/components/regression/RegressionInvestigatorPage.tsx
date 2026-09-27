import React, { useState } from 'react';
import {
  Repository,
  RegressionAnalysis,
  RegressionRisk,
  ImpactNode,
  RiskSeverity,
} from '../../types';
import { repositoryApi } from '../../services/api';

interface Props {
  repository: Repository;
  onInvestigate: (result: RegressionAnalysis) => void;
  regressionResult: RegressionAnalysis | null;
  selectedItem: { type: 'risk'; risk: RegressionRisk } | { type: 'node'; node: ImpactNode } | null;
  onSelectRisk: (risk: RegressionRisk) => void;
  onSelectNode: (node: ImpactNode) => void;
}

const PRESET_DIFFS: { title: string; desc: string; diff: string; query?: string }[] = [
  {
    title: 'CareSync: Medicine Adherence & Zero-Log Edge Case',
    desc: 'Alters adherence calculation formula and totalLogs == 0 zero-state fallback in MedicineService.getRealStats.',
    diff: `diff --git a/lib/services/medicine_service.dart b/lib/services/medicine_service.dart
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
`,
  },
  {
    title: 'CareSync: Prescription OCR Confirmation Logic',
    desc: 'Modifies prescription save validation in ScanPrescriptionScreen.',
    diff: `diff --git a/lib/screens/scan_prescription_screen.dart b/lib/screens/scan_prescription_screen.dart
--- a/lib/screens/scan_prescription_screen.dart
+++ b/lib/screens/scan_prescription_screen.dart
@@ -340,3 +340,4 @@ class _ScanPrescriptionScreenState {
-    if (detectedMedicines.isEmpty) return;
+    if (detectedMedicines.length <= 0 || !isVerified) return;
`,
  },
  {
    title: 'Natural Query: Adherence Calculation Changed',
    desc: 'Investigates regression risks for adherence calculation via natural query.',
    diff: '',
    query: 'Medicine adherence calculation was changed',
  },
];

const SEVERITY_STYLES: Record<string, { bg: string; color: string; border: string; icon: string }> = {
  HIGH: { bg: '#fee2e2', color: '#991b1b', border: '#fca5a5', icon: '🚨' },
  MEDIUM: { bg: '#fef3c7', color: '#92400e', border: '#fde68a', icon: '⚠️' },
  LOW: { bg: '#e0e7ff', color: '#3730a3', border: '#a5b4fc', icon: 'ℹ️' },
  UNKNOWN: { bg: '#f1f5f9', color: '#475569', border: '#cbd5e1', icon: '❓' },
};

const CATEGORY_ICONS: Record<string, string> = {
  EDGE_CASE: '⚡',
  BUSINESS_LOGIC: '🧠',
  DATA: '💾',
  UI: '🖥',
  STATE: '🔄',
  TEST_COVERAGE: '🧪',
  API: '🌐',
  DEPENDENCY: '📦',
  CONFIGURATION: '⚙',
  UNKNOWN: '❓',
};

export default function RegressionInvestigatorPage({
  repository,
  onInvestigate,
  regressionResult,
  selectedItem,
  onSelectRisk,
  onSelectNode,
}: Props) {
  const [inputMode, setInputMode] = useState<'diff' | 'query'>('diff');
  const [diffText, setDiffText] = useState(PRESET_DIFFS[0].diff);
  const [queryText, setQueryText] = useState('');
  const [maxDepth, setMaxDepth] = useState<number>(3);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const runInvestigation = async (diffParam?: string, queryParam?: string) => {
    const d = diffParam !== undefined ? diffParam : diffText;
    const q = queryParam !== undefined ? queryParam : queryText;

    if (!d.trim() && !q.trim()) return;

    setIsAnalyzing(true);
    setError(null);
    try {
      const result = await repositoryApi.regression(repository.id, {
        diff: d.trim() || undefined,
        query: q.trim() || undefined,
        max_depth: maxDepth,
      });
      onInvestigate(result);
    } catch (e: any) {
      if (e?.response?.status === 404) {
        const detail = e?.response?.data?.detail;
        if (!detail || detail === 'Not Found' || detail.toLowerCase().includes('not found')) {
          setError('Repository not found. Please select or scan a repository again.');
        } else {
          setError(detail);
        }
      } else {
        setError(e?.response?.data?.detail ?? e?.message ?? 'Regression analysis failed.');
      }
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    runInvestigation();
  };

  const handleLoadPreset = (preset: typeof PRESET_DIFFS[0]) => {
    if (preset.diff) {
      setInputMode('diff');
      setDiffText(preset.diff);
      setQueryText('');
      runInvestigation(preset.diff, '');
    } else if (preset.query) {
      setInputMode('query');
      setQueryText(preset.query);
      setDiffText('');
      runInvestigation('', preset.query);
    }
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-title">Regression Investigator</div>
        <div className="page-subtitle">
          "Why did this change cause a regression? What existing behavior is at risk?" Discover edge cases, affected business logic, and test coverage gaps from code changes.
        </div>
      </div>

      {/* Input Card */}
      <div className="card mb-20">
        <div className="card__body">
          {/* Mode Selector Tabs */}
          <div className="flex-row mb-12" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
            <div className="flex-row" style={{ gap: '6px' }}>
              <button
                type="button"
                className={`btn btn-sm ${inputMode === 'diff' ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setInputMode('diff')}
              >
                📄 Paste Git Diff
              </button>
              <button
                type="button"
                className={`btn btn-sm ${inputMode === 'query' ? 'btn-primary' : 'btn-secondary'}`}
                onClick={() => setInputMode('query')}
              >
                🔍 Natural Query / Symbol
              </button>
            </div>

            <div className="flex-row" style={{ gap: '6px', alignItems: 'center', padding: '0 8px', background: 'var(--color-surface-2)', borderRadius: 'var(--radius)', border: '1px solid var(--color-border)' }}>
              <span className="text-xs text-muted font-mono">Depth:</span>
              {[1, 2, 3, 4].map(d => (
                <button
                  key={d}
                  type="button"
                  onClick={() => setMaxDepth(d)}
                  style={{
                    padding: '2px 8px',
                    fontSize: '12px',
                    fontWeight: maxDepth === d ? 700 : 400,
                    borderRadius: '4px',
                    border: 'none',
                    background: maxDepth === d ? 'var(--color-accent)' : 'transparent',
                    color: maxDepth === d ? '#ffffff' : 'var(--color-text)',
                    cursor: 'pointer',
                  }}
                >
                  {d}
                </button>
              ))}
            </div>
          </div>

          <form onSubmit={handleSubmit}>
            {inputMode === 'diff' ? (
              <div style={{ marginBottom: '12px' }}>
                <textarea
                  className="input font-mono text-xs"
                  rows={7}
                  placeholder="Paste git diff here... e.g. diff --git a/file.dart b/file.dart"
                  value={diffText}
                  onChange={e => setDiffText(e.target.value)}
                  disabled={isAnalyzing}
                  style={{ width: '100%', resize: 'vertical', lineHeight: 1.4 }}
                />
              </div>
            ) : (
              <div style={{ marginBottom: '12px' }}>
                <input
                  className="input input-query"
                  placeholder="What changed? e.g. Medicine adherence calculation was modified"
                  value={queryText}
                  onChange={e => setQueryText(e.target.value)}
                  disabled={isAnalyzing}
                />
              </div>
            )}

            <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '8px' }}>
              <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap' }}>
                <span className="text-xs text-muted">Load scenario:</span>
                {PRESET_DIFFS.map((preset, idx) => (
                  <button
                    key={idx}
                    type="button"
                    className="btn btn-secondary btn-sm"
                    style={{ fontSize: '11px', padding: '2px 8px' }}
                    onClick={() => handleLoadPreset(preset)}
                    disabled={isAnalyzing}
                  >
                    {preset.title.split(':')[1] || preset.title}
                  </button>
                ))}
              </div>

              <button
                className="btn btn-primary btn-lg"
                type="submit"
                disabled={isAnalyzing || (inputMode === 'diff' ? !diffText.trim() : !queryText.trim())}
              >
                {isAnalyzing ? <><span className="spinner" /> Investigating…</> : '🔬 Investigate Regression'}
              </button>
            </div>
          </form>

          {error && <div className="alert error mt-16">{error}</div>}
        </div>
      </div>

      {/* Results Section */}
      {regressionResult && (
        <div className="flex-col" style={{ gap: '20px' }}>
          
          {/* Summary Banner & Metric Pills */}
          <div className="card">
            <div className="card__body">
              <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '16px' }}>
                <div>
                  <div className="text-xs text-muted font-mono mb-4">CHANGE INVESTIGATION SUMMARY</div>
                  <div className="font-bold" style={{ fontSize: '16px', color: 'var(--color-text)' }}>
                    {regressionResult.summary.risks_count} Potential Regression Risk{regressionResult.summary.risks_count === 1 ? '' : 's'} Detected
                  </div>
                  <div className="text-xs text-muted font-mono mt-4">
                    {regressionResult.changed_files.map(cf => cf.file).join(', ') || 'Query Target'}
                  </div>
                </div>

                <div className="flex-row" style={{ gap: '8px', flexWrap: 'wrap' }}>
                  <MetricCard label="Changed Files" count={regressionResult.summary.changed_files_count} />
                  <MetricCard label="Changed Symbols" count={regressionResult.summary.changed_symbols_count} />
                  <MetricCard label="Affected Callers" count={regressionResult.summary.affected_components_count} />
                  <MetricCard
                    label="High Risks"
                    count={regressionResult.summary.high_risk_count}
                    highlight={regressionResult.summary.high_risk_count > 0}
                  />
                  <MetricCard label="Related Tests" count={regressionResult.summary.tests_count} />
                </div>
              </div>

              {regressionResult.summary.description && (
                <div style={{ marginTop: '16px', padding: '12px 14px', background: 'var(--color-surface-2)', borderRadius: 'var(--radius)', fontSize: '13px', lineHeight: 1.5 }}>
                  {regressionResult.summary.description}
                </div>
              )}
            </div>
          </div>

          {/* Regression Risks Section */}
          <div className="card">
            <div className="card__header">
              <span className="card__title">Identified Regression Risks</span>
              <span className="text-xs text-muted">
                {regressionResult.risks.length} risk{regressionResult.risks.length === 1 ? '' : 's'} discovered from code & graph evidence
              </span>
            </div>

            <div className="card__body" style={{ padding: '16px' }}>
              {regressionResult.risks.length === 0 ? (
                <div className="empty-state" style={{ padding: '24px 0' }}>
                  <div className="empty-state__subtitle">No direct regression risk signals detected for this change.</div>
                </div>
              ) : (
                <div className="flex-col" style={{ gap: '12px' }}>
                  {regressionResult.risks.map(risk => {
                    const isSelected = selectedItem?.type === 'risk' && selectedItem.risk.id === risk.id;
                    const sevStyle = SEVERITY_STYLES[risk.severity] || SEVERITY_STYLES.MEDIUM;
                    const catIcon = CATEGORY_ICONS[risk.category] || '⚠️';

                    return (
                      <div
                        key={risk.id}
                        onClick={() => onSelectRisk(risk)}
                        style={{
                          padding: '14px 16px',
                          borderRadius: 'var(--radius)',
                          border: `1px solid ${isSelected ? 'var(--color-accent)' : sevStyle.border}`,
                          background: isSelected ? 'var(--color-accent-light)' : 'var(--color-surface)',
                          cursor: 'pointer',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: '8px',
                          transition: 'all 0.15s ease',
                          boxShadow: 'var(--shadow-sm)',
                        }}
                      >
                        <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
                          <div className="flex-row" style={{ gap: '8px' }}>
                            <span
                              style={{
                                fontSize: '11px',
                                fontWeight: 800,
                                padding: '2px 8px',
                                borderRadius: '4px',
                                backgroundColor: sevStyle.bg,
                                color: sevStyle.color,
                                border: `1px solid ${sevStyle.border}`,
                              }}
                            >
                              {sevStyle.icon} {risk.severity}
                            </span>
                            <span
                              style={{
                                fontSize: '11px',
                                fontWeight: 600,
                                padding: '2px 8px',
                                borderRadius: '4px',
                                backgroundColor: 'var(--color-surface-2)',
                                border: '1px solid var(--color-border)',
                              }}
                            >
                              {catIcon} {risk.category}
                            </span>
                            <span className="font-bold text-sm" style={{ color: 'var(--color-text)' }}>
                              {risk.title}
                            </span>
                          </div>

                          <span className={`confidence-badge ${risk.confidence}`}>
                            {risk.confidence}
                          </span>
                        </div>

                        <div className="text-xs" style={{ color: 'var(--color-text-muted)', lineHeight: 1.4 }}>
                          {risk.description}
                        </div>

                        {risk.evidence.length > 0 && risk.evidence[0].snippet && (
                          <pre
                            className="font-mono text-xs"
                            style={{
                              background: '#1e293b',
                              color: '#f8fafc',
                              padding: '6px 10px',
                              borderRadius: '4px',
                              margin: '2px 0 0 0',
                              whiteSpace: 'pre-wrap',
                              overflow: 'hidden',
                              maxHeight: '48px',
                            }}
                          >
                            {risk.evidence[0].snippet}
                          </pre>
                        )}

                        {risk.suggested_test && (
                          <div
                            style={{
                              marginTop: '4px',
                              padding: '8px 10px',
                              borderRadius: '4px',
                              background: '#ecfdf5',
                              border: '1px solid #a7f3d0',
                              color: '#065f46',
                              fontSize: '12px',
                            }}
                          >
                            <strong>🧪 Suggested Validation:</strong> {risk.suggested_test}
                          </div>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

          {/* Affected Components & Tests Grid */}
          <div className="grid-2">
            
            {/* Affected Callers & Screens */}
            <div className="card">
              <div className="card__header">
                <span className="card__title">Affected Callers & Screens</span>
                <span className="text-xs text-muted">{regressionResult.affected_components.length} components</span>
              </div>
              <div className="card__body scroll-area" style={{ maxHeight: '360px', padding: '10px' }}>
                {regressionResult.affected_components.length === 0 ? (
                  <div className="empty-state" style={{ padding: '20px 0' }}>
                    <div className="empty-state__subtitle">No downstream callers affected.</div>
                  </div>
                ) : (
                  <div className="flex-col" style={{ gap: '6px' }}>
                    {regressionResult.affected_components.map(node => {
                      const isSelected = selectedItem?.type === 'node' && selectedItem.node.id === node.id;
                      return (
                        <div
                          key={node.id}
                          onClick={() => onSelectNode(node)}
                          style={{
                            padding: '8px 10px',
                            borderRadius: '6px',
                            background: isSelected ? 'var(--color-accent-light)' : 'var(--color-surface-2)',
                            border: `1px solid ${isSelected ? 'var(--color-accent)' : 'var(--color-border)'}`,
                            cursor: 'pointer',
                            fontSize: '12px',
                          }}
                        >
                          <div className="font-mono font-bold text-xs" style={{ color: 'var(--color-text)' }}>
                            {node.symbol || node.file.split('/').pop()}
                          </div>
                          <div className="text-xs text-muted font-mono" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            {node.file}
                          </div>
                        </div>
                      );
                    })}
                  </div>
                )}
              </div>
            </div>

            {/* Existing Tests & Coverage Gap */}
            <div className="card">
              <div className="card__header">
                <span className="card__title">Test Suites & Coverage</span>
                <span className="text-xs text-muted">{regressionResult.related_tests.length} tests</span>
              </div>
              <div className="card__body scroll-area" style={{ maxHeight: '360px', padding: '10px' }}>
                {regressionResult.related_tests.length === 0 ? (
                  <div className="empty-state" style={{ padding: '20px 0' }}>
                    <div className="empty-state__subtitle" style={{ color: '#991b1b' }}>
                      ⚠️ No existing test suites found for these components in repository.
                    </div>
                  </div>
                ) : (
                  <div className="flex-col" style={{ gap: '6px' }}>
                    {regressionResult.related_tests.map(testNode => (
                      <div
                        key={testNode.id}
                        onClick={() => onSelectNode(testNode)}
                        style={{
                          padding: '8px 10px',
                          borderRadius: '6px',
                          background: '#f0fdf4',
                          border: '1px solid #bbf7d0',
                          cursor: 'pointer',
                          fontSize: '12px',
                        }}
                      >
                        <div className="flex-row" style={{ justifyContent: 'space-between' }}>
                          <span className="font-mono font-bold text-xs" style={{ color: '#166534' }}>
                            🧪 {testNode.symbol || testNode.file.split('/').pop()}
                          </span>
                          <span className="confidence-badge CONFIRMED">TEST</span>
                        </div>
                        <div className="text-xs text-muted font-mono mt-4">
                          {testNode.file}
                        </div>
                      </div>
                    ))}
                  </div>
                )}
              </div>
            </div>

          </div>

        </div>
      )}
    </div>
  );
}

function MetricCard({ label, count, highlight = false }: { label: string; count: number; highlight?: boolean }) {
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        padding: '6px 12px',
        borderRadius: 'var(--radius)',
        backgroundColor: highlight ? '#fee2e2' : 'var(--color-surface-2)',
        border: `1px solid ${highlight ? '#fca5a5' : 'var(--color-border)'}`,
        minWidth: '85px',
      }}
    >
      <span style={{ fontSize: '18px', fontWeight: 800, color: highlight ? '#991b1b' : 'var(--color-text)' }}>
        {count}
      </span>
      <span style={{ fontSize: '10px', fontWeight: 600, color: 'var(--color-text-muted)', textTransform: 'uppercase' }}>
        {label}
      </span>
    </div>
  );
}
