import React, { useState } from 'react';
import { Repository, FeatureTrace, TraceNode, TraceEdge, Confidence } from '../../types';
import { repositoryApi } from '../../services/api';

interface Props {
  repository: Repository;
  onTrace: (result: FeatureTrace) => void;
  traceResult: FeatureTrace | null;
  selectedNode: TraceNode | null;
  onNodeSelect: (node: TraceNode) => void;
}

const EXAMPLE_QUERIES = [
  'Trace prescription scanning',
  'Where is authentication implemented?',
  'How does medicine management work?',
  'Trace the notification flow',
  'How is user profile saved?',
];

const ROLE_ICONS: Record<string, string> = {
  'UI / Screen': '🖥',
  'Service Layer': '⚙️',
  'Repository / DAO': '🗄',
  'Data Model': '📦',
  'Controller / Route': '🔀',
  'Test': '🧪',
  'Entry Point': '🚪',
  'API Client': '🌐',
  'Notification': '🔔',
  'Data Store': '🔥',
  'Authentication': '🔐',
  'OCR / Scanner': '📷',
  'Export / Report': '📄',
  'File / Storage': '💾',
  'Configuration': '⚙',
  'Utility': '🔧',
  'Navigation': '🧭',
  'Component': '🧩',
};

export default function FeatureTracerPage({
  repository,
  onTrace,
  traceResult,
  selectedNode,
  onNodeSelect,
}: Props) {
  const [query, setQuery] = useState('');
  const [isTracing, setIsTracing] = useState(false);
  const [error, setError] = useState<string | null>(null);

  const runTrace = async (q: string) => {
    if (!q.trim()) return;
    setIsTracing(true);
    setError(null);
    try {
      const result = await repositoryApi.trace(repository.id, q.trim());
      onTrace(result);
    } catch (e: any) {
      if (e?.response?.status === 404) {
        const detail = e?.response?.data?.detail;
        if (!detail || detail === 'Not Found' || detail.toLowerCase().includes('not found')) {
          setError('Repository not found. Please select or scan a repository again.');
        } else {
          setError(detail);
        }
      } else {
        setError(e?.response?.data?.detail ?? e?.message ?? 'Trace failed.');
      }
    } finally {
      setIsTracing(false);
    }
  };

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    runTrace(query);
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-title">Feature Tracer</div>
        <div className="page-subtitle">
          Ask a natural-language question. CodeAtlas discovers the answer from the actual code.
        </div>
      </div>

      {/* Query form */}
      <div className="card mb-20">
        <div className="card__body">
          <form onSubmit={handleSubmit}>
            <div className="flex-row" style={{ gap: '10px', alignItems: 'stretch' }}>
              <input
                className="input input-query"
                placeholder="What do you want to understand? e.g. Trace prescription scanning"
                value={query}
                onChange={e => setQuery(e.target.value)}
                disabled={isTracing}
                autoFocus
              />
              <button
                className="btn btn-primary btn-lg"
                type="submit"
                disabled={isTracing || !query.trim()}
                style={{ flexShrink: 0 }}
              >
                {isTracing ? <><span className="spinner" /> Tracing…</> : '→ Analyze'}
              </button>
            </div>
          </form>
          <div className="query-examples mt-12">
            {EXAMPLE_QUERIES.map(q => (
              <button
                key={q}
                className="query-chip"
                onClick={() => { setQuery(q); runTrace(q); }}
                disabled={isTracing}
              >
                {q}
              </button>
            ))}
          </div>
        </div>
      </div>

      {error && (
        <div className="alert error mb-16">
          <span>⚠️ {error}</span>
        </div>
      )}

      {/* Results */}
      {traceResult && (
        <div>
          {/* Summary */}
          <div className="summary-banner">
            <strong>Query:</strong> "{traceResult.query}"<br />
            {traceResult.summary}
          </div>

          {/* Stats row */}
          <div className="flex-row mb-16" style={{ flexWrap: 'wrap', gap: '8px' }}>
            <StatPill label="Nodes" value={traceResult.total_nodes} />
            <StatPill label="Edges" value={traceResult.total_edges} />
            <StatPill label="Confirmed" value={traceResult.confirmed.length} color="confirmed" />
            <StatPill label="Inferred" value={traceResult.inferred.length} color="inferred" />
            {traceResult.unknowns.length > 0 && (
              <StatPill label="Unknown" value={traceResult.unknowns.length} color="unknown" />
            )}
          </div>

          {traceResult.total_nodes === 0 ? (
            <div className="empty-state">
              <div className="empty-state__icon">🔍</div>
              <div className="empty-state__title">No results found</div>
              <div className="empty-state__subtitle">
                {traceResult.unknowns[0] ??
                  'Try a different query. CodeAtlas searches filenames, symbols, and relationships.'}
              </div>
            </div>
          ) : (
            <TraceFlow
              trace={traceResult}
              selectedNode={selectedNode}
              onNodeSelect={onNodeSelect}
            />
          )}

          {/* Findings panels */}
          {(traceResult.confirmed.length > 0 || traceResult.inferred.length > 0 || traceResult.unknowns.length > 0) && (
            <div className="grid-2 mt-20" style={{ gridTemplateColumns: 'repeat(auto-fill, minmax(280px, 1fr))' }}>
              {traceResult.confirmed.length > 0 && (
                <FindingsCard
                  title="✅ Confirmed"
                  items={traceResult.confirmed}
                  colorClass="CONFIRMED"
                />
              )}
              {traceResult.inferred.length > 0 && (
                <FindingsCard
                  title="🔵 Inferred"
                  items={traceResult.inferred}
                  colorClass="INFERRED"
                />
              )}
              {traceResult.unknowns.length > 0 && (
                <FindingsCard
                  title="❓ Unknown"
                  items={traceResult.unknowns}
                  colorClass="UNKNOWN"
                />
              )}
            </div>
          )}
        </div>
      )}
    </div>
  );
}

// ── Trace flow (linear layout) ──────────────────────────────────────────

function TraceFlow({
  trace,
  selectedNode,
  onNodeSelect,
}: {
  trace: FeatureTrace;
  selectedNode: TraceNode | null;
  onNodeSelect: (n: TraceNode) => void;
}) {
  // Build ordered chain: entry points → related nodes sorted by file
  const entryIds = new Set(trace.entry_points.map(n => n.id));
  const orderedNodes = [
    ...trace.entry_points,
    ...trace.nodes.filter(n => !entryIds.has(n.id)),
  ];

  // Build adjacency for edge labels
  const edgeMap: Map<string, TraceEdge[]> = new Map();
  for (const edge of trace.edges) {
    const key = `${edge.source_id}→${edge.target_id}`;
    if (!edgeMap.has(key)) edgeMap.set(key, []);
    edgeMap.get(key)!.push(edge);
  }

  return (
    <div className="trace-graph">
      <div className="card__header">
        <span className="card__title">Feature Trace — "{trace.query}"</span>
        <span className="text-xs text-muted">{trace.total_nodes} components • click a node to inspect</span>
      </div>
      <div className="trace-flow">
        {orderedNodes.map((node, idx) => {
          const prevNode = orderedNodes[idx - 1];
          const edge = prevNode
            ? trace.edges.find(e =>
                (e.source_id === prevNode.id && e.target_id === node.id) ||
                (e.source_id === node.id && e.target_id === prevNode.id) ||
                (prevNode.file && node.file && prevNode.file !== node.file && (
                  (e.source_id.startsWith(prevNode.file) && e.target_id.startsWith(node.file)) ||
                  (e.source_id.startsWith(node.file) && e.target_id.startsWith(prevNode.file))
                ))
              )
            : null;


          return (
            <React.Fragment key={node.id}>
              {idx > 0 && (
                <EdgeConnector edge={edge} />
              )}
              <NodeCard
                node={node}
                isEntry={entryIds.has(node.id)}
                isSelected={selectedNode?.id === node.id}
                onSelect={() => onNodeSelect(node)}
              />
            </React.Fragment>
          );
        })}
      </div>
    </div>
  );
}

function NodeCard({
  node,
  isEntry,
  isSelected,
  onSelect,
}: {
  node: TraceNode;
  isEntry: boolean;
  isSelected: boolean;
  onSelect: () => void;
}) {
  const icon = ROLE_ICONS[node.role] ?? '🧩';
  const fileName = node.file.split('/').pop() ?? node.file;

  return (
    <div
      className={`trace-node ${isEntry ? 'entry-point' : ''} ${isSelected ? 'selected' : ''}`}
      onClick={onSelect}
    >
      <div className="trace-node__icon">{icon}</div>
      <div className="trace-node__body">
        <div className="trace-node__file" title={node.file}>{node.file}</div>
        <div className="trace-node__symbol">
          {node.symbol ?? fileName}
        </div>
        <div className="trace-node__meta">
          <span className={`confidence-badge ${node.confidence}`}>{node.confidence}</span>
          {node.role && <span className="role-tag">{node.role}</span>}
          {node.symbol_type && (
            <span className="role-tag" style={{ fontFamily: 'var(--font-mono)' }}>
              {node.symbol_type}
            </span>
          )}
          {node.line_start != null && (
            <span className="text-xs text-faint">:{node.line_start}</span>
          )}
          {isEntry && (
            <span className="role-tag" style={{ background: '#ede9fe', color: '#5b21b6', borderColor: '#c4b5fd' }}>
              entry point
            </span>
          )}
        </div>
      </div>
    </div>
  );
}

function EdgeConnector({ edge }: { edge: TraceEdge | null | undefined }) {
  return (
    <div className="trace-edge-connector">
      <div className="trace-edge-connector__line" />
      {edge && (
        <span className={`trace-edge-connector__label confidence-badge ${edge.confidence}`}>
          {edge.label || edge.relationship_type}
        </span>
      )}
    </div>
  );
}

function StatPill({ label, value, color }: {
  label: string; value: number; color?: 'confirmed' | 'inferred' | 'unknown';
}) {
  const cls = color ? `confidence-badge ${color.toUpperCase()}` : 'mono-pill';
  return (
    <span className={cls} style={{ fontSize: '11px', padding: '3px 10px' }}>
      {value} {label}
    </span>
  );
}

function FindingsCard({ title, items, colorClass }: {
  title: string; items: string[]; colorClass: Confidence;
}) {
  return (
    <div className="card">
      <div className="card__header">
        <span className="card__title">{title}</span>
      </div>
      <div className="card__body">
        <ul className="findings-list">
          {items.slice(0, 8).map((item, i) => (
            <li key={i}>{item}</li>
          ))}
        </ul>
      </div>
    </div>
  );
}
