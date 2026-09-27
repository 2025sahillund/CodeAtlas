import React, { useState } from 'react';
import { Repository, ImpactAnalysis, ImpactNode, Confidence } from '../../types';
import { repositoryApi } from '../../services/api';

interface Props {
  repository: Repository;
  onAnalyze: (result: ImpactAnalysis) => void;
  impactResult: ImpactAnalysis | null;
  selectedNode: ImpactNode | null;
  onNodeSelect: (node: ImpactNode) => void;
}

const EXAMPLE_TARGETS = [
  'MedicineService.addMedicine',
  'medicine_name',
  'ScanPrescriptionScreen',
  'medicine_service.dart',
  'ApiService.syncUser',
  'AuthService',
];

const CATEGORY_STYLES: Record<string, { bg: string; color: string; border: string; icon: string }> = {
  DIRECT: { bg: '#fee2e2', color: '#991b1b', border: '#fca5a5', icon: '⚡' },
  INDIRECT: { bg: '#dbeafe', color: '#1e40af', border: '#93c5fd', icon: '🔗' },
  DATA: { bg: '#fef3c7', color: '#92400e', border: '#fde68a', icon: '💾' },
  UI: { bg: '#ede9fe', color: '#5b21b6', border: '#c4b5fd', icon: '🖥' },
  TEST: { bg: '#dcfce7', color: '#166534', border: '#86efac', icon: '🧪' },
  CONFIGURATION: { bg: '#f1f5f9', color: '#475569', border: '#cbd5e1', icon: '⚙' },
  API: { bg: '#e0e7ff', color: '#3730a3', border: '#a5b4fc', icon: '🌐' },
  UNKNOWN: { bg: '#fef9c3', color: '#713f12', border: '#fef08a', icon: '❓' },
};

export default function ChangeImpactRadarPage({
  repository,
  onAnalyze,
  impactResult,
  selectedNode,
  onNodeSelect,
}: Props) {
  const [targetQuery, setTargetQuery] = useState('');
  const [maxDepth, setMaxDepth] = useState<number>(3);
  const [isAnalyzing, setIsAnalyzing] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [activeTab, setActiveTab] = useState<'ALL' | 'DIRECT' | 'INDIRECT' | 'DATA' | 'UI' | 'TEST'>('ALL');

  const runAnalysis = async (q: string, depth = maxDepth) => {
    if (!q.trim()) return;
    setIsAnalyzing(true);
    setError(null);
    try {
      const result = await repositoryApi.impact(repository.id, q.trim(), depth);
      onAnalyze(result);
    } catch (e: any) {
      if (e?.response?.status === 404) {
        const detail = e?.response?.data?.detail;
        if (!detail || detail === 'Not Found' || detail.toLowerCase().includes('not found')) {
          setError('Repository not found. Please select or scan a repository again.');
        } else {
          setError(detail);
        }
      } else {
        setError(e?.response?.data?.detail ?? e?.message ?? 'Impact analysis failed.');
      }
    } finally {
      setIsAnalyzing(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    runAnalysis(targetQuery);
  };

  const getFilteredNodes = (): ImpactNode[] => {
    if (!impactResult) return [];
    switch (activeTab) {
      case 'DIRECT': return impactResult.direct_impacts;
      case 'INDIRECT': return impactResult.indirect_impacts;
      case 'DATA': return impactResult.data_impacts;
      case 'UI': return impactResult.ui_impacts;
      case 'TEST': return impactResult.test_impacts;
      default:
        return [
          ...impactResult.direct_impacts,
          ...impactResult.indirect_impacts,
          ...impactResult.data_impacts,
          ...impactResult.ui_impacts,
          ...impactResult.test_impacts,
        ];
    }
  };

  const filteredNodes = getFilteredNodes();

  return (
    <div>
      <div className="page-header">
        <div className="page-title">Change Impact Radar</div>
        <div className="page-subtitle">
          "If I change this code, what else could be affected?" Search any symbol, method, class, file, or data identifier.
        </div>
      </div>

      {/* Query Form */}
      <div className="card mb-20">
        <div className="card__body">
          <form onSubmit={handleSubmit}>
            <div className="flex-row" style={{ gap: '10px', alignItems: 'stretch' }}>
              <input
                className="input input-query"
                placeholder="What are you planning to change? e.g. MedicineService.addMedicine, medicine_name, scan_prescription"
                value={targetQuery}
                onChange={e => setTargetQuery(e.target.value)}
                disabled={isAnalyzing}
                autoFocus
              />
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
              <button
                className="btn btn-primary btn-lg"
                type="submit"
                disabled={isAnalyzing || !targetQuery.trim()}
                style={{ flexShrink: 0 }}
              >
                {isAnalyzing ? <><span className="spinner" /> Analyzing…</> : '💥 Analyze Impact'}
              </button>
            </div>
          </form>

          {/* Example Queries */}
          <div className="flex-row mt-12" style={{ flexWrap: 'wrap', gap: '6px' }}>
            <span className="text-xs text-muted">Try scenario:</span>
            {EXAMPLE_TARGETS.map((t, idx) => (
              <button
                key={idx}
                className="btn btn-secondary btn-sm"
                style={{ fontSize: '11px', padding: '2px 8px' }}
                onClick={() => {
                  setTargetQuery(t);
                  runAnalysis(t);
                }}
                disabled={isAnalyzing}
              >
                {t}
              </button>
            ))}
          </div>

          {error && (
            <div className="alert error mt-16">{error}</div>
          )}
        </div>
      </div>

      {/* Impact Result Section */}
      {impactResult && (
        <div className="flex-col" style={{ gap: '20px' }}>
          
          {/* Summary Metric Pills */}
          <div className="card">
            <div className="card__body">
              <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '16px' }}>
                <div>
                  <div className="text-xs text-muted font-mono mb-4">TARGET COMPONENT</div>
                  <div className="font-bold" style={{ fontSize: '16px', color: 'var(--color-text)' }}>
                    {impactResult.target.symbol || impactResult.target.file || impactResult.target.id}
                  </div>
                  <div className="text-xs text-muted font-mono mt-4">
                    {impactResult.target.file}
                  </div>
                </div>

                <div className="flex-row" style={{ gap: '8px', flexWrap: 'wrap' }}>
                  <MetricPill label="Direct Impact" count={impactResult.summary.direct_count} type="DIRECT" />
                  <MetricPill label="Indirect Impact" count={impactResult.summary.indirect_count} type="INDIRECT" />
                  <MetricPill label="Data Impact" count={impactResult.summary.data_count} type="DATA" />
                  <MetricPill label="UI Impact" count={impactResult.summary.ui_count} type="UI" />
                  <MetricPill label="Test Impact" count={impactResult.summary.test_count} type="TEST" />
                  {impactResult.summary.unknown_count > 0 && (
                    <MetricPill label="Unknown" count={impactResult.summary.unknown_count} type="UNKNOWN" />
                  )}
                </div>
              </div>

              {impactResult.summary.description && (
                <div style={{ marginTop: '16px', padding: '12px 14px', background: 'var(--color-surface-2)', borderRadius: 'var(--radius)', fontSize: '13px', lineHeight: 1.5 }}>
                  {impactResult.summary.description}
                </div>
              )}
            </div>
          </div>

          {/* Visual Impact Flow Graph */}
          <div className="card">
            <div className="card__header">
              <span className="card__title">Impact Graph</span>
              <span className="text-xs text-muted">
                {impactResult.nodes.length} nodes · {impactResult.edges.length} relationships
              </span>
            </div>
            <div className="card__body" style={{ background: '#f8fafc', overflowX: 'auto' }}>
              <ImpactGraphVisual
                analysis={impactResult}
                selectedNode={selectedNode}
                onNodeSelect={onNodeSelect}
              />
            </div>
          </div>

          {/* Affected Components List with Tabs */}
          <div className="card">
            <div className="card__header" style={{ borderBottom: '1px solid var(--color-border)', paddingBottom: '0' }}>
              <div className="flex-row" style={{ gap: '4px' }}>
                <TabButton
                  active={activeTab === 'ALL'}
                  label={`All Affected (${impactResult.summary.total_impacted})`}
                  onClick={() => setActiveTab('ALL')}
                />
                <TabButton
                  active={activeTab === 'DIRECT'}
                  label={`Direct (${impactResult.summary.direct_count})`}
                  onClick={() => setActiveTab('DIRECT')}
                />
                <TabButton
                  active={activeTab === 'INDIRECT'}
                  label={`Indirect (${impactResult.summary.indirect_count})`}
                  onClick={() => setActiveTab('INDIRECT')}
                />
                <TabButton
                  active={activeTab === 'DATA'}
                  label={`Data (${impactResult.summary.data_count})`}
                  onClick={() => setActiveTab('DATA')}
                />
                <TabButton
                  active={activeTab === 'UI'}
                  label={`UI (${impactResult.summary.ui_count})`}
                  onClick={() => setActiveTab('UI')}
                />
                <TabButton
                  active={activeTab === 'TEST'}
                  label={`Tests (${impactResult.summary.test_count})`}
                  onClick={() => setActiveTab('TEST')}
                />
              </div>
            </div>

            <div className="card__body scroll-area" style={{ maxHeight: '480px', padding: '12px' }}>
              {filteredNodes.length === 0 ? (
                <div className="empty-state" style={{ padding: '30px 0' }}>
                  <div className="empty-state__subtitle">No affected components in this category.</div>
                </div>
              ) : (
                <div className="flex-col" style={{ gap: '8px' }}>
                  {filteredNodes.map((node) => {
                    const isSelected = selectedNode?.id === node.id;
                    const style = CATEGORY_STYLES[node.impact_type] || CATEGORY_STYLES.DIRECT;
                    return (
                      <div
                        key={node.id}
                        onClick={() => onNodeSelect(node)}
                        style={{
                          padding: '12px 14px',
                          borderRadius: 'var(--radius)',
                          border: `1px solid ${isSelected ? 'var(--color-accent)' : 'var(--color-border)'}`,
                          background: isSelected ? 'var(--color-accent-light)' : 'var(--color-surface)',
                          cursor: 'pointer',
                          transition: 'all 0.15s ease',
                          display: 'flex',
                          flexDirection: 'column',
                          gap: '6px',
                        }}
                      >
                        <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
                          <div className="flex-row" style={{ gap: '8px' }}>
                            <span
                              style={{
                                fontSize: '11px',
                                fontWeight: 700,
                                padding: '2px 6px',
                                borderRadius: '4px',
                                backgroundColor: style.bg,
                                color: style.color,
                                border: `1px solid ${style.border}`,
                                display: 'inline-flex',
                                alignItems: 'center',
                                gap: '4px',
                              }}
                            >
                              <span>{style.icon}</span>
                              <span>{node.impact_type}</span>
                            </span>
                            <span className="font-mono font-bold text-sm" style={{ color: 'var(--color-text)' }}>
                              {node.symbol || node.file}
                            </span>
                          </div>

                          <div className="flex-row" style={{ gap: '6px' }}>
                            <span className="mono-pill">
                              {node.distance === 0 ? 'Target' : `${node.distance} hop${node.distance > 1 ? 's' : ''}`}
                            </span>
                            <span className={`confidence-badge ${node.confidence}`}>
                              {node.confidence}
                            </span>
                          </div>
                        </div>

                        <div className="text-xs text-muted font-mono">
                          📄 {node.file}
                        </div>

                        {node.reason && (
                          <div className="text-xs" style={{ color: 'var(--color-text-muted)', lineHeight: 1.4 }}>
                            {node.reason}
                          </div>
                        )}

                        {node.evidence.length > 0 && node.evidence[0].snippet && (
                          <pre
                            className="font-mono text-xs"
                            style={{
                              background: 'var(--color-surface-2)',
                              padding: '4px 8px',
                              borderRadius: '4px',
                              margin: '2px 0 0 0',
                              whiteSpace: 'pre-wrap',
                              overflow: 'hidden',
                              maxHeight: '48px',
                              color: '#334155',
                            }}
                          >
                            {node.evidence[0].snippet}
                          </pre>
                        )}
                      </div>
                    );
                  })}
                </div>
              )}
            </div>
          </div>

        </div>
      )}
    </div>
  );
}

function MetricPill({ label, count, type }: { label: string; count: number; type: string }) {
  const style = CATEGORY_STYLES[type] || CATEGORY_STYLES.DIRECT;
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        padding: '6px 12px',
        borderRadius: 'var(--radius)',
        backgroundColor: style.bg,
        border: `1px solid ${style.border}`,
        minWidth: '85px',
      }}
    >
      <span style={{ fontSize: '18px', fontWeight: 800, color: style.color }}>
        {count}
      </span>
      <span style={{ fontSize: '10px', fontWeight: 600, color: style.color, textTransform: 'uppercase' }}>
        {label}
      </span>
    </div>
  );
}

function TabButton({ active, label, onClick }: { active: boolean; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        padding: '8px 14px',
        fontSize: '13px',
        fontWeight: active ? 700 : 500,
        color: active ? 'var(--color-accent)' : 'var(--color-text-muted)',
        borderBottom: active ? '2px solid var(--color-accent)' : '2px solid transparent',
        background: 'none',
        borderTop: 'none',
        borderLeft: 'none',
        borderRight: 'none',
        cursor: 'pointer',
        transition: 'all 0.15s ease',
      }}
    >
      {label}
    </button>
  );
}

function ImpactGraphVisual({
  analysis,
  selectedNode,
  onNodeSelect,
}: {
  analysis: ImpactAnalysis;
  selectedNode: ImpactNode | null;
  onNodeSelect: (node: ImpactNode) => void;
}) {
  const target = analysis.target;
  const direct = analysis.direct_impacts.slice(0, 8);
  const data = analysis.data_impacts.slice(0, 6);
  const ui = analysis.ui_impacts.slice(0, 6);
  const test = analysis.test_impacts.slice(0, 4);
  const indirect = analysis.indirect_impacts.slice(0, 6);

  return (
    <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: '24px', padding: '16px 0' }}>
      
      {/* Target Node at the Top */}
      <div
        onClick={() => onNodeSelect(target)}
        style={{
          padding: '12px 20px',
          borderRadius: '10px',
          background: '#1e293b',
          color: '#ffffff',
          boxShadow: '0 4px 10px rgba(0,0,0,0.15)',
          cursor: 'pointer',
          textAlign: 'center',
          maxWidth: '400px',
          border: selectedNode?.id === target.id ? '3px solid #38bdf8' : '1px solid #334155',
        }}
      >
        <div style={{ fontSize: '10px', textTransform: 'uppercase', letterSpacing: '1px', color: '#94a3b8' }}>
          🎯 SELECTED TARGET
        </div>
        <div className="font-mono font-bold" style={{ fontSize: '14px', marginTop: '4px' }}>
          {target.symbol || target.file}
        </div>
        <div className="text-xs" style={{ color: '#cbd5e1', marginTop: '2px' }}>
          {target.file}
        </div>
      </div>

      {/* Connection Tree Grid */}
      <div style={{ display: 'grid', gridTemplateColumns: 'repeat(auto-fit, minmax(200px, 1fr))', gap: '16px', width: '100%' }}>
        
        {/* Column 1: Direct Impacts */}
        {direct.length > 0 && (
          <GraphColumn
            title="Direct Impact"
            icon="⚡"
            type="DIRECT"
            nodes={direct}
            selectedNode={selectedNode}
            onNodeSelect={onNodeSelect}
          />
        )}

        {/* Column 2: Data Impacts */}
        {data.length > 0 && (
          <GraphColumn
            title="Data Dependencies"
            icon="💾"
            type="DATA"
            nodes={data}
            selectedNode={selectedNode}
            onNodeSelect={onNodeSelect}
          />
        )}

        {/* Column 3: UI Impacts */}
        {ui.length > 0 && (
          <GraphColumn
            title="UI Screens"
            icon="🖥"
            type="UI"
            nodes={ui}
            selectedNode={selectedNode}
            onNodeSelect={onNodeSelect}
          />
        )}

        {/* Column 4: Test Impacts */}
        {test.length > 0 && (
          <GraphColumn
            title="Test Suites"
            icon="🧪"
            type="TEST"
            nodes={test}
            selectedNode={selectedNode}
            onNodeSelect={onNodeSelect}
          />
        )}

        {/* Column 5: Indirect Impacts */}
        {indirect.length > 0 && (
          <GraphColumn
            title="Indirect Impact"
            icon="🔗"
            type="INDIRECT"
            nodes={indirect}
            selectedNode={selectedNode}
            onNodeSelect={onNodeSelect}
          />
        )}

      </div>
    </div>
  );
}

function GraphColumn({
  title,
  icon,
  type,
  nodes,
  selectedNode,
  onNodeSelect,
}: {
  title: string;
  icon: string;
  type: string;
  nodes: ImpactNode[];
  selectedNode: ImpactNode | null;
  onNodeSelect: (node: ImpactNode) => void;
}) {
  const style = CATEGORY_STYLES[type] || CATEGORY_STYLES.DIRECT;
  return (
    <div
      style={{
        display: 'flex',
        flexDirection: 'column',
        gap: '8px',
        padding: '12px',
        background: 'var(--color-surface)',
        borderRadius: 'var(--radius)',
        border: '1px solid var(--color-border)',
      }}
    >
      <div className="flex-row" style={{ gap: '6px', fontSize: '12px', fontWeight: 700, color: style.color }}>
        <span>{icon}</span>
        <span>{title}</span>
        <span className="mono-pill" style={{ marginLeft: 'auto', fontSize: '10px' }}>{nodes.length}</span>
      </div>

      <div className="flex-col" style={{ gap: '6px' }}>
        {nodes.map(node => {
          const isSelected = selectedNode?.id === node.id;
          return (
            <div
              key={node.id}
              onClick={() => onNodeSelect(node)}
              style={{
                padding: '8px 10px',
                borderRadius: '6px',
                background: isSelected ? 'var(--color-accent-light)' : style.bg,
                border: `1px solid ${isSelected ? 'var(--color-accent)' : style.border}`,
                cursor: 'pointer',
                fontSize: '11px',
                transition: 'all 0.15s ease',
              }}
            >
              <div className="font-mono font-bold" style={{ color: isSelected ? 'var(--color-accent)' : style.color, wordBreak: 'break-all' }}>
                {node.symbol || node.file.split('/').pop()}
              </div>
              <div className="text-xs text-muted font-mono" style={{ marginTop: '2px', overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                {node.file}
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
