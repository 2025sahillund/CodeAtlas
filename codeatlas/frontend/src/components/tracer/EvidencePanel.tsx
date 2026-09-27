import React from 'react';
import { FeatureTrace, TraceNode, Evidence } from '../../types';

interface Props {
  selectedNode: TraceNode | null;
  traceResult: FeatureTrace | null;
}

export default function EvidencePanel({ selectedNode, traceResult }: Props) {
  if (!traceResult) return null;

  return (
    <div>
      <div style={{ marginBottom: '16px' }}>
        <div className="page-title" style={{ fontSize: '16px' }}>Evidence Panel</div>
        <div className="page-subtitle" style={{ fontSize: '12px' }}>
          {selectedNode ? 'Showing evidence for selected component' : 'Click a node to inspect its evidence'}
        </div>
      </div>

      <div className="evidence-panel">
        {!selectedNode ? (
          <div className="evidence-panel__empty">
            <div style={{ fontSize: '32px', marginBottom: '8px' }}>🔎</div>
            <div>Select a node in the trace graph to view source evidence.</div>
          </div>
        ) : (
          <NodeEvidence node={selectedNode} traceResult={traceResult} />
        )}
      </div>
    </div>
  );
}

function NodeEvidence({ node, traceResult }: { node: TraceNode; traceResult: FeatureTrace }) {
  // Find edges involving this node (by exact ID, file path, or symbol ID)
  const isMatch = (edgeId: string) =>
    edgeId === node.id ||
    (node.symbol_id && edgeId === node.symbol_id) ||
    (node.file && node.file !== '[data store]' && (edgeId === node.file || edgeId.startsWith(`${node.file}::`)));

  const outEdges = traceResult.edges.filter(e => isMatch(e.source_id));
  const inEdges = traceResult.edges.filter(e => isMatch(e.target_id));


  return (
    <div className="evidence-panel" style={{ gap: '12px' }}>
      {/* Node identity */}
      <div className="evidence-section">
        <div className="evidence-section__header">
          <span className="evidence-section__title">Component</span>
          <span className={`confidence-badge ${node.confidence}`}>{node.confidence}</span>
        </div>

        <EvidenceField label="File" value={node.file} mono />
        {node.symbol && <EvidenceField label="Symbol" value={node.symbol} mono />}
        {node.symbol_type && <EvidenceField label="Type" value={node.symbol_type} />}
        {node.role && <EvidenceField label="Role" value={node.role} />}
        {node.line_start != null && (
          <EvidenceField
            label="Lines"
            value={`${node.line_start}${node.line_end != null && node.line_end !== node.line_start ? `–${node.line_end}` : ''}`}
          />
        )}
      </div>

      {/* Source evidence */}
      {node.evidence.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Source Evidence</span>
          </div>
          {node.evidence.map((ev, i) => (
            <EvidenceBlock key={i} evidence={ev} />
          ))}
        </div>
      )}

      {/* Relationships */}
      {outEdges.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Outgoing Relationships</span>
          </div>
          {outEdges.slice(0, 5).map((edge, i) => (
            <div key={i} className="progress-row">
              <span className="progress-row__icon">→</span>
              <div style={{ flex: 1 }}>
                <div className="font-mono text-xs">{shortenId(edge.target_id)}</div>
                <div className="text-xs text-muted">{edge.label || edge.relationship_type}</div>
              </div>
              <span className={`confidence-badge ${edge.confidence}`}>{edge.confidence}</span>
            </div>
          ))}
        </div>
      )}

      {inEdges.length > 0 && (
        <div className="evidence-section">
          <div className="evidence-section__header">
            <span className="evidence-section__title">Incoming Relationships</span>
          </div>
          {inEdges.slice(0, 5).map((edge, i) => (
            <div key={i} className="progress-row">
              <span className="progress-row__icon">←</span>
              <div style={{ flex: 1 }}>
                <div className="font-mono text-xs">{shortenId(edge.source_id)}</div>
                <div className="text-xs text-muted">{edge.label || edge.relationship_type}</div>
              </div>
              <span className={`confidence-badge ${edge.confidence}`}>{edge.confidence}</span>
            </div>
          ))}
        </div>
      )}

      {/* Relationship evidence */}
      {[...outEdges, ...inEdges].slice(0, 3).map((edge, i) => (
        edge.evidence.length > 0 ? (
          <div key={i} className="evidence-section">
            <div className="evidence-section__header">
              <span className="evidence-section__title">
                Relationship Evidence — {edge.relationship_type}
              </span>
              <span className={`confidence-badge ${edge.confidence}`}>{edge.confidence}</span>
            </div>
            {edge.evidence.slice(0, 2).map((ev, j) => (
              <EvidenceBlock key={j} evidence={ev} />
            ))}
          </div>
        ) : null
      ))}
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
      <div className="evidence-field__label">{label}</div>
      <div
        className={`evidence-field__value ${mono ? 'font-mono' : ''}`}
        style={{ fontSize: mono ? '12px' : '13px' }}
      >
        {value}
      </div>
    </div>
  );
}

function EvidenceBlock({ evidence }: { evidence: Evidence }) {
  return (
    <div style={{ marginBottom: '10px' }}>
      <div className="evidence-field__label">{evidence.description || 'Source'}</div>
      <div className="flex-row mt-4" style={{ gap: '6px', flexWrap: 'wrap' }}>
        <span className="mono-pill">{evidence.file}</span>
        {evidence.line_start != null && (
          <span className="mono-pill">
            L{evidence.line_start}{evidence.line_end != null && evidence.line_end !== evidence.line_start ? `–${evidence.line_end}` : ''}
          </span>
        )}
      </div>
      {evidence.snippet ? (
        <pre className="evidence-snippet">{evidence.snippet}</pre>
      ) : (
        <div className="text-xs text-faint mt-4" style={{ fontStyle: 'italic' }}>
          Unknown — requires runtime or semantic verification.
        </div>
      )}
    </div>
  );
}

function shortenId(id: string): string {
  // "lib/services/medicine_service.dart::MedicineService.addMedicine"
  // → "medicine_service.dart::addMedicine"
  const parts = id.split('::');
  if (parts.length === 2) {
    const file = parts[0].split('/').pop() ?? parts[0];
    const sym = parts[1].split('.').pop() ?? parts[1];
    return `${file}::${sym}`;
  }
  return id.split('/').pop() ?? id;
}
