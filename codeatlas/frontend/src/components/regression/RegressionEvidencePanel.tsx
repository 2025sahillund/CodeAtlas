import React from 'react';
import { RegressionAnalysis, RegressionRisk, ImpactNode, Evidence } from '../../types';

interface Props {
  selectedItem: { type: 'risk'; risk: RegressionRisk } | { type: 'node'; node: ImpactNode } | null;
  regressionResult: RegressionAnalysis | null;
}

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

export default function RegressionEvidencePanel({ selectedItem, regressionResult }: Props) {
  if (!regressionResult) return null;

  return (
    <div>
      <div style={{ marginBottom: '16px' }}>
        <div className="page-title" style={{ fontSize: '16px' }}>Evidence & Risk Inspector</div>
        <div className="page-subtitle" style={{ fontSize: '12px' }}>
          {selectedItem ? 'Ground-truth evidence for selected item' : 'Select a risk or component to inspect evidence'}
        </div>
      </div>

      <div className="evidence-panel">
        {!selectedItem ? (
          <div className="evidence-panel__empty">
            <div style={{ fontSize: '32px', marginBottom: '8px' }}>🔬</div>
            <div>Select a regression risk or affected component to inspect verifiable code evidence.</div>
          </div>
        ) : selectedItem.type === 'risk' ? (
          <RiskEvidenceView risk={selectedItem.risk} regressionResult={regressionResult} />
        ) : (
          <NodeEvidenceView node={selectedItem.node} regressionResult={regressionResult} />
        )}
      </div>
    </div>
  );
}

function RiskEvidenceView({ risk, regressionResult }: { risk: RegressionRisk; regressionResult: RegressionAnalysis }) {
  const sevStyle = SEVERITY_STYLES[risk.severity] || SEVERITY_STYLES.MEDIUM;
  const catIcon = CATEGORY_ICONS[risk.category] || '⚠️';

  return (
    <div className="evidence-panel" style={{ gap: '12px' }}>
      {/* Risk Summary Card */}
      <div className="evidence-section">
        <div className="evidence-section__header">
          <div className="flex-row" style={{ gap: '6px' }}>
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
              {sevStyle.icon} {risk.severity} RISK
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
          </div>
          <span className={`confidence-badge ${risk.confidence}`}>{risk.confidence}</span>
        </div>

        <div className="font-bold text-sm" style={{ marginTop: '8px', color: 'var(--color-text)' }}>
          {risk.title}
        </div>

        <div className="text-xs" style={{ color: 'var(--color-text-muted)', lineHeight: 1.5, marginTop: '4px' }}>
          {risk.description}
        </div>

        <div style={{ marginTop: '10px' }}>
          <EvidenceField label="Source" value={risk.source} mono />
          {risk.related_component && (
            <EvidenceField label="Impacted Target" value={risk.related_component} mono />
          )}
        </div>
      </div>

      {/* Suggested Validation Test */}
      {risk.suggested_test && (
        <div
          className="evidence-section"
          style={{
            background: '#ecfdf5',
            border: '1px solid #a7f3d0',
            borderRadius: 'var(--radius)',
            padding: '12px',
          }}
        >
          <div className="flex-row" style={{ gap: '6px', color: '#065f46', fontWeight: 700, fontSize: '12px' }}>
            <span>🧪</span>
            <span>Suggested Validation Test</span>
          </div>
          <div style={{ fontSize: '12px', color: '#064e3b', marginTop: '6px', lineHeight: 1.4 }}>
            {risk.suggested_test}
          </div>
        </div>
      )}

      {/* Code Evidence Snippets */}
      {risk.evidence.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Verifiable Code Evidence</span>
            <span className="text-xs text-muted">({risk.evidence.length})</span>
          </div>
          {risk.evidence.map((ev, i) => (
            <RegressionEvidenceBlock key={i} evidence={ev} />
          ))}
        </div>
      )}
    </div>
  );
}

function NodeEvidenceView({ node, regressionResult }: { node: ImpactNode; regressionResult: RegressionAnalysis }) {
  const isMatch = (edgeId: string) =>
    edgeId === node.id ||
    (node.symbol_id && edgeId === node.symbol_id) ||
    (node.file && node.file !== '[data store]' && (edgeId === node.file || edgeId.startsWith(`${node.file}::`)));

  const outEdges = regressionResult.edges.filter(e => isMatch(e.source_id));
  const inEdges = regressionResult.edges.filter(e => isMatch(e.target_id));

  return (
    <div className="evidence-panel" style={{ gap: '12px' }}>
      <div className="evidence-section">
        <div className="evidence-section__header">
          <span className="evidence-section__title">Affected Component</span>
          <span className={`confidence-badge ${node.confidence}`}>{node.confidence}</span>
        </div>

        <EvidenceField label="File" value={node.file} mono />
        {node.symbol && <EvidenceField label="Symbol" value={node.symbol} mono />}
        {node.symbol_type && <EvidenceField label="Type" value={node.symbol_type} />}
        <EvidenceField label="Category" value={node.impact_type} />
        {node.relationship && <EvidenceField label="Relationship" value={node.relationship} />}

        {node.reason && (
          <div style={{ marginTop: '8px', padding: '8px 10px', background: 'var(--color-surface-2)', borderRadius: '6px', fontSize: '12px' }}>
            <strong>Reason:</strong> {node.reason}
          </div>
        )}
      </div>

      {node.evidence.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Source Evidence</span>
          </div>
          {node.evidence.map((ev, i) => (
            <RegressionEvidenceBlock key={i} evidence={ev} />
          ))}
        </div>
      )}

      {inEdges.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Incoming Callers</span>
          </div>
          {inEdges.slice(0, 4).map((edge, i) => (
            <div key={i} className="progress-row">
              <span className="progress-row__icon">←</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="font-mono text-xs" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {shortenId(edge.source_id)}
                </div>
                <div className="text-xs text-muted">{edge.label || edge.relationship_type}</div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function RegressionEvidenceBlock({ evidence }: { evidence: Evidence }) {
  return (
    <div className="evidence-block" style={{ marginBottom: '8px' }}>
      <div className="evidence-block__file">
        <span>📄 {evidence.file}</span>
        {evidence.line_start != null && (
          <span className="font-mono text-xs text-muted">
            :L{evidence.line_start}{evidence.line_end && evidence.line_end !== evidence.line_start ? `–L${evidence.line_end}` : ''}
          </span>
        )}
      </div>

      {evidence.snippet && (
        <pre className="evidence-block__snippet font-mono">{evidence.snippet}</pre>
      )}

      {evidence.description && (
        <div className="evidence-block__desc">{evidence.description}</div>
      )}
    </div>
  );
}

function EvidenceField({ label, value, mono = false }: { label: string; value: string; mono?: boolean }) {
  return (
    <div className="evidence-field">
      <span className="evidence-field__label">{label}</span>
      <span className={`evidence-field__value ${mono ? 'font-mono' : ''}`} style={{ wordBreak: 'break-all' }}>
        {value}
      </span>
    </div>
  );
}

function shortenId(id: string): string {
  if (id.includes('::')) {
    const [file, sym] = id.split('::');
    const fileName = file.split('/').pop() ?? file;
    return `${fileName}::${sym}`;
  }
  return id.split('/').pop() ?? id;
}
