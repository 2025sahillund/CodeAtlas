import React from 'react';
import { ImpactAnalysis, ImpactNode, Evidence } from '../../types';

interface Props {
  selectedNode: ImpactNode | null;
  impactResult: ImpactAnalysis | null;
}

const IMPACT_COLORS: Record<string, { bg: string; color: string; border: string }> = {
  DIRECT: { bg: '#fee2e2', color: '#991b1b', border: '#fca5a5' },
  INDIRECT: { bg: '#dbeafe', color: '#1e40af', border: '#93c5fd' },
  DATA: { bg: '#fef3c7', color: '#92400e', border: '#fde68a' },
  UI: { bg: '#ede9fe', color: '#5b21b6', border: '#c4b5fd' },
  TEST: { bg: '#dcfce7', color: '#166534', border: '#86efac' },
  CONFIGURATION: { bg: '#f1f5f9', color: '#475569', border: '#cbd5e1' },
  API: { bg: '#e0e7ff', color: '#3730a3', border: '#a5b4fc' },
  UNKNOWN: { bg: '#fef9c3', color: '#713f12', border: '#fef08a' },
};

export default function ImpactEvidencePanel({ selectedNode, impactResult }: Props) {
  if (!impactResult) return null;

  return (
    <div>
      <div style={{ marginBottom: '16px' }}>
        <div className="page-title" style={{ fontSize: '16px' }}>Evidence Panel</div>
        <div className="page-subtitle" style={{ fontSize: '12px' }}>
          {selectedNode ? 'Source evidence for affected component' : 'Select an impact node to inspect evidence'}
        </div>
      </div>

      <div className="evidence-panel">
        {!selectedNode ? (
          <div className="evidence-panel__empty">
            <div style={{ fontSize: '32px', marginBottom: '8px' }}>🎯</div>
            <div>Select an affected component or graph node to inspect ground-truth source evidence.</div>
          </div>
        ) : (
          <NodeImpactEvidence node={selectedNode} impactResult={impactResult} />
        )}
      </div>
    </div>
  );
}

function NodeImpactEvidence({ node, impactResult }: { node: ImpactNode; impactResult: ImpactAnalysis }) {
  const style = IMPACT_COLORS[node.impact_type] || IMPACT_COLORS.DIRECT;

  // Find incoming and outgoing edges for this node in the impact graph
  const isMatch = (edgeId: string) =>
    edgeId === node.id ||
    (node.symbol_id && edgeId === node.symbol_id) ||
    (node.file && node.file !== '[data store]' && (edgeId === node.file || edgeId.startsWith(`${node.file}::`)));

  const outEdges = impactResult.edges.filter(e => isMatch(e.source_id));
  const inEdges = impactResult.edges.filter(e => isMatch(e.target_id));

  return (
    <div className="evidence-panel" style={{ gap: '12px' }}>
      {/* Component Identity Card */}
      <div className="evidence-section">
        <div className="evidence-section__header">
          <span className="evidence-section__title">Impacted Target</span>
          <div className="flex-row" style={{ gap: '6px' }}>
            <span
              style={{
                fontSize: '10px',
                fontWeight: 700,
                padding: '2px 8px',
                borderRadius: '4px',
                backgroundColor: style.bg,
                color: style.color,
                border: `1px solid ${style.border}`,
              }}
            >
              {node.impact_type}
            </span>
            <span className={`confidence-badge ${node.confidence}`}>{node.confidence}</span>
          </div>
        </div>

        <EvidenceField label="File" value={node.file} mono />
        {node.symbol && <EvidenceField label="Symbol" value={node.symbol} mono />}
        {node.symbol_type && <EvidenceField label="Type" value={node.symbol_type} />}
        <EvidenceField label="Distance" value={node.distance === 0 ? 'Target (0)' : `${node.distance} hop${node.distance > 1 ? 's' : ''}`} />
        {node.relationship && <EvidenceField label="Relationship" value={node.relationship} />}
        
        {node.reason && (
          <div style={{ marginTop: '8px', padding: '8px 10px', background: 'var(--color-surface-2)', borderRadius: '6px', fontSize: '12px', color: 'var(--color-text)' }}>
            <strong>Analysis Reason:</strong> {node.reason}
          </div>
        )}
      </div>

      {/* Code Evidence Snippets */}
      {node.evidence.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Verifiable Code Evidence</span>
            <span className="text-xs text-muted">({node.evidence.length})</span>
          </div>
          {node.evidence.map((ev, i) => (
            <ImpactEvidenceBlock key={i} evidence={ev} />
          ))}
        </div>
      )}

      {/* Graph Relationships */}
      {inEdges.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Incoming Impact Paths</span>
          </div>
          {inEdges.slice(0, 5).map((edge, i) => (
            <div key={i} className="progress-row">
              <span className="progress-row__icon">←</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="font-mono text-xs" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {shortenId(edge.source_id)}
                </div>
                <div className="text-xs text-muted">{edge.label || edge.relationship_type}</div>
              </div>
              <span className={`confidence-badge ${edge.confidence}`}>{edge.confidence}</span>
            </div>
          ))}
        </div>
      )}

      {outEdges.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Downstream Dependencies</span>
          </div>
          {outEdges.slice(0, 5).map((edge, i) => (
            <div key={i} className="progress-row">
              <span className="progress-row__icon">→</span>
              <div style={{ flex: 1, minWidth: 0 }}>
                <div className="font-mono text-xs" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                  {shortenId(edge.target_id)}
                </div>
                <div className="text-xs text-muted">{edge.label || edge.relationship_type}</div>
              </div>
              <span className={`confidence-badge ${edge.confidence}`}>{edge.confidence}</span>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}

function ImpactEvidenceBlock({ evidence }: { evidence: Evidence }) {
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

function EvidenceField({
  label,
  value,
  mono = false,
}: {
  label: string;
  value: string;
  mono?: boolean;
}) {
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
