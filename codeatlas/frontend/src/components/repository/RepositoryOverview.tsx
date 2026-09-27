import React, { useState, useEffect, useMemo } from 'react';
import {
  Repository,
  ProjectIntelligence,
  RepositoryModule,
  ArchitectureLayer,
  ApiEndpoint,
  StorageTechnology,
  ArchitectureGraphNode,
  RecentAnalysisItem,
  FileSummary,
} from '../../types';
import { repositoryApi } from '../../services/api';
import RepositoryTreeViewer from './RepositoryTreeViewer';

interface Props {
  repository: Repository;
  recentAnalyses: RecentAnalysisItem[];
  onNavigate: (page: 'tracer' | 'impact' | 'regression') => void;
}

type TabKey = 'overview' | 'map' | 'modules' | 'apis' | 'storage' | 'tree' | 'recent' | 'files';

const HTTP_METHOD_COLORS: Record<string, { bg: string; color: string; border: string }> = {
  GET: { bg: '#dbeafe', color: '#1e40af', border: '#93c5fd' },
  POST: { bg: '#dcfce7', color: '#166534', border: '#86efac' },
  PUT: { bg: '#fef3c7', color: '#92400e', border: '#fde68a' },
  PATCH: { bg: '#fef9c3', color: '#713f12', border: '#fef08a' },
  DELETE: { bg: '#fee2e2', color: '#991b1b', border: '#fca5a5' },
};

export default function RepositoryOverview({ repository, recentAnalyses, onNavigate }: Props) {
  const [activeTab, setActiveTab] = useState<TabKey>('overview');
  const [intelligence, setIntelligence] = useState<ProjectIntelligence | null>(null);
  const [isLoadingIntel, setIsLoadingIntel] = useState(false);
  const [intelError, setIntelError] = useState<string | null>(null);

  // Selected items in sub-views
  const [selectedModule, setSelectedModule] = useState<RepositoryModule | null>(null);
  const [selectedLayerId, setSelectedLayerId] = useState<string | null>(null);
  const [selectedApiMethod, setSelectedApiMethod] = useState<string>('ALL');
  const [fileSearchQuery, setFileSearchQuery] = useState('');
  const [apiSearchQuery, setApiSearchQuery] = useState('');

  // Fetch intelligence on mount / repo change
  useEffect(() => {
    if (!repository.id || repository.status !== 'indexed') return;
    let isCurrent = true;
    setIsLoadingIntel(true);
    setIntelError(null);

    repositoryApi.getIntelligence(repository.id)
      .then((data) => {
        if (isCurrent) {
          setIntelligence(data);
          if (data.modules.length > 0) {
            setSelectedModule(data.modules[0]);
          }
          if (data.architecture_graph.nodes.length > 0) {
            setSelectedLayerId(data.architecture_graph.nodes[0].id);
          }
        }
      })
      .catch((err) => {
        if (isCurrent) {
          setIntelError(err?.response?.data?.detail ?? err?.message ?? 'Failed to load intelligence');
        }
      })
      .finally(() => {
        if (isCurrent) setIsLoadingIntel(false);
      });

    return () => { isCurrent = false; };
  }, [repository.id, repository.status]);

  const files = repository.files ?? [];
  const filteredFiles = useMemo(() => {
    if (!fileSearchQuery.trim()) return files;
    const q = fileSearchQuery.toLowerCase();
    return files.filter(f => f.path.toLowerCase().includes(q) || f.language.toLowerCase().includes(q));
  }, [files, fileSearchQuery]);

  const filteredApis = useMemo(() => {
    if (!intelligence) return [];
    let list = intelligence.api_endpoints;
    if (selectedApiMethod !== 'ALL') {
      list = list.filter(ep => ep.method.toUpperCase() === selectedApiMethod);
    }
    if (apiSearchQuery.trim()) {
      const q = apiSearchQuery.toLowerCase();
      list = list.filter(ep => ep.path.toLowerCase().includes(q) || ep.handler.toLowerCase().includes(q) || ep.file.toLowerCase().includes(q));
    }
    return list;
  }, [intelligence, selectedApiMethod, apiSearchQuery]);

  const apiMethodCounts = useMemo(() => {
    if (!intelligence) return {};
    const counts: Record<string, number> = {};
    for (const ep of intelligence.api_endpoints) {
      counts[ep.method] = (counts[ep.method] || 0) + 1;
    }
    return counts;
  }, [intelligence]);

  const languages = Object.entries(repository.languages).sort((a, b) => b[1] - a[1]);
  const maxLangCount = languages[0]?.[1] ?? 1;

  return (
    <div>
      {/* Page Header */}
      <div className="page-header" style={{ marginBottom: '16px' }}>
        <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'flex-start', flexWrap: 'wrap', gap: '12px' }}>
          <div>
            <div className="page-title">{repository.name}</div>
            <div className="page-subtitle">
              Understand the architecture, structure and key components of your codebase.
            </div>
          </div>
          {intelligence?.detected_frameworks && intelligence.detected_frameworks.length > 0 && (
            <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap' }}>
              {intelligence.detected_frameworks.map(fw => (
                <span key={fw} className="role-tag" style={{ background: 'var(--color-surface-2)', borderColor: 'var(--color-border)', fontSize: '11px' }}>
                  {fw}
                </span>
              ))}
            </div>
          )}
        </div>
      </div>

      {/* Status Banners */}
      {repository.status === 'scanning' && (
        <div className="alert info mb-16">
          <span className="spinner" />
          <span>Scanning & indexing repository knowledge graph…</span>
        </div>
      )}
      {repository.error && (
        <div className="alert error mb-16">
          <span>⚠️ {repository.error}</span>
        </div>
      )}
      {intelError && (
        <div className="alert warning mb-16">
          <span>⚠️ {intelError}</span>
        </div>
      )}

      {/* Top 4 Summary Cards */}
      <div className="stats-grid mb-20" style={{ gridTemplateColumns: 'repeat(auto-fit, minmax(220px, 1fr))' }}>
        {/* Card 1: Architecture */}
        <div className="stat-card" style={{ cursor: 'pointer', transition: 'all 0.15s ease' }} onClick={() => setActiveTab('overview')}>
          <div className="flex-row" style={{ justifyContent: 'space-between', width: '100%', marginBottom: '4px' }}>
            <span className="stat-card__label" style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Architecture</span>
            <span style={{ fontSize: '14px' }}>🏛</span>
          </div>
          <div className="stat-card__value" style={{ fontSize: '20px' }}>
            {intelligence?.detected_frameworks.slice(0, 2).join(' • ') || `${Object.keys(repository.languages).length} Languages`}
          </div>
          <div className="text-xs text-muted mt-4">
            {intelligence ? `${intelligence.layers.length} Layers • ${intelligence.entry_points.length} Entry Points` : `${repository.source_files} source files`}
          </div>
        </div>

        {/* Card 2: Modules */}
        <div className="stat-card" style={{ cursor: 'pointer', transition: 'all 0.15s ease' }} onClick={() => setActiveTab('modules')}>
          <div className="flex-row" style={{ justifyContent: 'space-between', width: '100%', marginBottom: '4px' }}>
            <span className="stat-card__label" style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Modules</span>
            <span style={{ fontSize: '14px' }}>📦</span>
          </div>
          <div className="stat-card__value" style={{ fontSize: '20px' }}>
            {intelligence ? `${intelligence.modules.length} Modules` : `${repository.source_files} Files`}
          </div>
          <div className="text-xs text-muted mt-4">
            {repository.symbol_count.toLocaleString()} Symbols • {repository.relationship_count.toLocaleString()} Graph Edges
          </div>
        </div>

        {/* Card 3: APIs */}
        <div className="stat-card" style={{ cursor: 'pointer', transition: 'all 0.15s ease' }} onClick={() => setActiveTab('apis')}>
          <div className="flex-row" style={{ justifyContent: 'space-between', width: '100%', marginBottom: '4px' }}>
            <span className="stat-card__label" style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>APIs</span>
            <span style={{ fontSize: '14px' }}>🌐</span>
          </div>
          <div className="stat-card__value" style={{ fontSize: '20px' }}>
            {intelligence?.api_endpoints.length ? `${intelligence.api_endpoints.length} Endpoints` : '0 Endpoints'}
          </div>
          <div className="text-xs text-muted mt-4">
            {intelligence?.api_endpoints.length
              ? Object.entries(apiMethodCounts).map(([m, c]) => `${m}: ${c}`).join(' • ')
              : 'No external API routes'}
          </div>
        </div>

        {/* Card 4: Data / Storage */}
        <div className="stat-card" style={{ cursor: 'pointer', transition: 'all 0.15s ease' }} onClick={() => setActiveTab('storage')}>
          <div className="flex-row" style={{ justifyContent: 'space-between', width: '100%', marginBottom: '4px' }}>
            <span className="stat-card__label" style={{ fontSize: '11px', textTransform: 'uppercase', letterSpacing: '0.5px' }}>Data & Storage</span>
            <span style={{ fontSize: '14px' }}>💾</span>
          </div>
          <div className="stat-card__value" style={{ fontSize: '20px' }}>
            {intelligence?.storage_technologies.length
              ? intelligence.storage_technologies[0].technology.split('/')[0].trim()
              : 'No DB Detected'}
          </div>
          <div className="text-xs text-muted mt-4">
            {intelligence?.storage_technologies.length
              ? `${intelligence.storage_technologies.length} Storage Engine(s) detected`
              : 'In-memory / stateless'}
          </div>
        </div>
      </div>

      {/* Intelligence Summary Description if available */}
      {intelligence?.summary_description && (
        <div className="card mb-20" style={{ background: '#f8fafc', borderLeft: '4px solid var(--color-accent)' }}>
          <div className="card__body" style={{ padding: '12px 16px', fontSize: '13px', lineHeight: 1.5, color: '#334155' }}>
            <strong>Codebase Overview:</strong> {intelligence.summary_description}
          </div>
        </div>
      )}

      {/* Sub-Navigation Tabs */}
      <div className="card mb-20">
        <div className="card__header" style={{ borderBottom: '1px solid var(--color-border)', paddingBottom: 0 }}>
          <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap' }}>
            <NavTabButton
              active={activeTab === 'overview'}
              label="🗺 Architecture & Map"
              onClick={() => setActiveTab('overview')}
            />
            <NavTabButton
              active={activeTab === 'modules'}
              label={`📦 Module Explorer (${intelligence?.modules.length ?? 0})`}
              onClick={() => setActiveTab('modules')}
            />
            <NavTabButton
              active={activeTab === 'apis'}
              label={`🌐 API Intelligence (${intelligence?.api_endpoints.length ?? 0})`}
              onClick={() => setActiveTab('apis')}
            />
            <NavTabButton
              active={activeTab === 'storage'}
              label={`💾 Data & Storage (${intelligence?.storage_technologies.length ?? 0})`}
              onClick={() => setActiveTab('storage')}
            />
            <NavTabButton
              active={activeTab === 'tree'}
              label="🌳 Repository Tree"
              onClick={() => setActiveTab('tree')}
            />
            <NavTabButton
              active={activeTab === 'recent'}
              label={`⏱ Recent Analysis (${recentAnalyses.length})`}
              onClick={() => setActiveTab('recent')}
            />
            <NavTabButton
              active={activeTab === 'files'}
              label={`📁 Source Files (${files.length})`}
              onClick={() => setActiveTab('files')}
            />
          </div>
        </div>

        <div className="card__body" style={{ padding: '20px' }}>
          {/* TAB 1: Architecture & Dynamic Map */}
          {activeTab === 'overview' && (
            <ArchitectureOverviewTab
              intelligence={intelligence}
              repository={repository}
              selectedLayerId={selectedLayerId}
              onSelectLayerId={setSelectedLayerId}
              onNavigate={onNavigate}
              languages={languages}
              maxLangCount={maxLangCount}
            />
          )}

          {/* TAB 2: Dynamic Map dedicated view */}
          {activeTab === 'map' && intelligence && (
            <ArchitectureMapTab
              graph={intelligence.architecture_graph}
              selectedLayerId={selectedLayerId}
              onSelectLayerId={setSelectedLayerId}
            />
          )}

          {/* TAB 3: Module Explorer */}
          {activeTab === 'modules' && (
            <ModuleExplorerTab
              modules={intelligence?.modules ?? []}
              selectedModule={selectedModule}
              onSelectModule={setSelectedModule}
            />
          )}

          {/* TAB 4: API Intelligence */}
          {activeTab === 'apis' && (
            <ApiIntelligenceTab
              apiEndpoints={filteredApis}
              allEndpoints={intelligence?.api_endpoints ?? []}
              selectedMethod={selectedApiMethod}
              onSelectMethod={setSelectedApiMethod}
              searchQuery={apiSearchQuery}
              onSearchChange={setApiSearchQuery}
              methodCounts={apiMethodCounts}
            />
          )}

          {/* TAB 5: Data & Storage */}
          {activeTab === 'storage' && (
            <DataStorageTab
              storageTechnologies={intelligence?.storage_technologies ?? []}
            />
          )}

          {/* TAB: Repository Tree */}
          {activeTab === 'tree' && (
            <RepositoryTreeViewer
              repository={repository}
              onNavigateToFeature={onNavigate}
            />
          )}

          {/* TAB 6: Recent Analysis */}
          {activeTab === 'recent' && (
            <RecentAnalysisTab
              recentAnalyses={recentAnalyses}
              onNavigate={onNavigate}
            />
          )}

          {/* TAB 7: Source Files Table */}
          {activeTab === 'files' && (
            <SourceFilesTab
              files={filteredFiles}
              searchQuery={fileSearchQuery}
              onSearchChange={setFileSearchQuery}
            />
          )}
        </div>
      </div>
    </div>
  );
}

// ---------------------------------------------------------------------------
// Sub-Components
// ---------------------------------------------------------------------------

function NavTabButton({ active, label, onClick }: { active: boolean; label: string; onClick: () => void }) {
  return (
    <button
      type="button"
      onClick={onClick}
      style={{
        padding: '10px 16px',
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

// ── Tab 1: Architecture Overview & Dynamic Map ────────────────────────────

function ArchitectureOverviewTab({
  intelligence,
  repository,
  selectedLayerId,
  onSelectLayerId,
  onNavigate,
  languages,
  maxLangCount,
}: {
  intelligence: ProjectIntelligence | null;
  repository: Repository;
  selectedLayerId: string | null;
  onSelectLayerId: (id: string) => void;
  onNavigate: (page: 'tracer' | 'impact' | 'regression') => void;
  languages: [string, number][];
  maxLangCount: number;
}) {
  const graph = intelligence?.architecture_graph;
  const selectedNode = graph?.nodes.find(n => n.id === selectedLayerId) || graph?.nodes[0];

  // Inbound & Outbound edges for selected layer
  const inEdges = useMemo(() => {
    if (!graph || !selectedNode) return [];
    return graph.edges.filter(e => e.target_id === selectedNode.id);
  }, [graph, selectedNode]);

  const outEdges = useMemo(() => {
    if (!graph || !selectedNode) return [];
    return graph.edges.filter(e => e.source_id === selectedNode.id);
  }, [graph, selectedNode]);

  return (
    <div className="flex-col" style={{ gap: '24px' }}>
      {/* Visual Dynamic Architecture Graph Map */}
      <div>
        <div className="flex-row mb-12" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
          <div>
            <h3 style={{ fontSize: '15px', fontWeight: 700, color: 'var(--color-text)' }}>Dynamic Architecture Map</h3>
            <p className="text-xs text-muted">
              Evidence-based architectural layers and cross-layer relationships derived from repository code.
            </p>
          </div>
          <span className="mono-pill">
            {graph?.nodes.length ?? 0} Layers • {graph?.edges.length ?? 0} Connectors
          </span>
        </div>

        {graph && graph.nodes.length > 0 ? (
          <div
            style={{
              padding: '20px',
              background: '#f8fafc',
              borderRadius: 'var(--radius)',
              border: '1px solid var(--color-border)',
            }}
          >
            {/* Grid of Layer Nodes */}
            <div
              style={{
                display: 'grid',
                gridTemplateColumns: 'repeat(auto-fit, minmax(180px, 1fr))',
                gap: '12px',
                marginBottom: '16px',
              }}
            >
              {graph.nodes.map(node => {
                const isSelected = selectedNode?.id === node.id;
                return (
                  <div
                    key={node.id}
                    onClick={() => onSelectLayerId(node.id)}
                    style={{
                      padding: '12px 14px',
                      borderRadius: 'var(--radius)',
                      background: isSelected ? '#1e293b' : 'var(--color-surface)',
                      color: isSelected ? '#ffffff' : 'var(--color-text)',
                      border: `1px solid ${isSelected ? '#0f172a' : 'var(--color-border)'}`,
                      cursor: 'pointer',
                      transition: 'all 0.15s ease',
                      boxShadow: isSelected ? 'var(--shadow)' : 'none',
                    }}
                  >
                    <div className="flex-row" style={{ justifyContent: 'space-between', marginBottom: '4px' }}>
                      <span style={{ fontSize: '12px', fontWeight: 700 }}>{node.label}</span>
                      <span className="mono-pill" style={{ background: isSelected ? '#334155' : 'var(--color-surface-2)', color: isSelected ? '#f8fafc' : 'var(--color-text-muted)', fontSize: '10px' }}>
                        {node.file_count} files
                      </span>
                    </div>
                    <div className="text-xs" style={{ color: isSelected ? '#94a3b8' : 'var(--color-text-muted)' }}>
                      {node.symbol_count} symbols
                    </div>
                  </div>
                );
              })}
            </div>

            {/* Selected Layer Inspector Details */}
            {selectedNode && (
              <div
                style={{
                  marginTop: '16px',
                  padding: '16px',
                  background: 'var(--color-surface)',
                  borderRadius: 'var(--radius)',
                  border: '1px solid var(--color-border)',
                }}
              >
                <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center', marginBottom: '12px' }}>
                  <div className="flex-row" style={{ gap: '8px' }}>
                    <span className="font-bold text-sm" style={{ color: 'var(--color-accent)' }}>
                      Layer Inspection: {selectedNode.label}
                    </span>
                    <span className="mono-pill">{selectedNode.files.length} Files</span>
                    <span className="mono-pill">{selectedNode.symbols.length} Symbols</span>
                  </div>
                </div>

                <div className="grid-2">
                  {/* Inbound & Outbound Connections */}
                  <div>
                    <div className="text-xs text-muted font-bold mb-8">CROSS-LAYER RELATIONSHIPS</div>
                    <div className="flex-col" style={{ gap: '6px' }}>
                      {inEdges.length === 0 && outEdges.length === 0 && (
                        <span className="text-xs text-muted">No cross-layer connections recorded for this layer.</span>
                      )}
                      {outEdges.map(e => {
                        const tgtNode = graph.nodes.find(n => n.id === e.target_id);
                        return (
                          <div key={`${e.source_id}->${e.target_id}`} className="flex-row" style={{ fontSize: '11px', padding: '4px 8px', background: 'var(--color-surface-2)', borderRadius: '4px' }}>
                            <span className="font-bold">➔ Calls / Uses</span>
                            <span className="mono-pill">{tgtNode?.label || e.target_id}</span>
                            <span className="text-muted" style={{ marginLeft: 'auto' }}>{e.label}</span>
                          </div>
                        );
                      })}
                      {inEdges.map(e => {
                        const srcNode = graph.nodes.find(n => n.id === e.source_id);
                        return (
                          <div key={`${e.source_id}->${e.target_id}`} className="flex-row" style={{ fontSize: '11px', padding: '4px 8px', background: '#eff6ff', borderRadius: '4px', color: '#1e40af' }}>
                            <span className="font-bold">⬅ Used by</span>
                            <span className="mono-pill">{srcNode?.label || e.source_id}</span>
                            <span className="text-muted" style={{ marginLeft: 'auto' }}>{e.label}</span>
                          </div>
                        );
                      })}
                    </div>
                  </div>

                  {/* Sample Files in this Layer */}
                  <div>
                    <div className="text-xs text-muted font-bold mb-8">CONTAINED SOURCE FILES</div>
                    <div className="scroll-area" style={{ maxHeight: '140px' }}>
                      <div className="flex-col" style={{ gap: '4px' }}>
                        {selectedNode.files.map(f => (
                          <span key={f} className="font-mono text-xs text-muted" style={{ overflow: 'hidden', textOverflow: 'ellipsis', whiteSpace: 'nowrap' }}>
                            📄 {f}
                          </span>
                        ))}
                      </div>
                    </div>
                  </div>
                </div>
              </div>
            )}
          </div>
        ) : (
          <div className="empty-state">
            <div className="empty-state__subtitle">No architecture layers could be inferred.</div>
          </div>
        )}
      </div>

      {/* Languages and Key Actions */}
      <div className="grid-2">
        {/* Languages Bar */}
        <div className="card">
          <div className="card__header">
            <span className="card__title">Languages & Distribution</span>
          </div>
          <div className="card__body">
            <div className="lang-bar">
              {languages.slice(0, 8).map(([lang, count]) => (
                <div key={lang} className="lang-bar__item">
                  <span className="lang-bar__name">{lang}</span>
                  <div className="lang-bar__track">
                    <div
                      className="lang-bar__fill"
                      style={{ width: `${Math.round((count / maxLangCount) * 100)}%` }}
                    />
                  </div>
                  <span className="lang-bar__count">{count}</span>
                </div>
              ))}
            </div>
          </div>
        </div>

        {/* Quick Launch Actions */}
        <div className="card">
          <div className="card__header">
            <span className="card__title">Deep Code Analysis Capabilities</span>
          </div>
          <div className="card__body">
            <div className="flex-col" style={{ gap: '10px' }}>
              <button
                className="btn btn-secondary"
                style={{ justifyContent: 'flex-start', textAlign: 'left', padding: '10px 14px' }}
                onClick={() => onNavigate('tracer')}
              >
                <span style={{ fontSize: '16px', marginRight: '8px' }}>🔍</span>
                <div>
                  <div className="font-bold text-xs">Feature Tracer</div>
                  <div className="text-xs text-muted">Ask natural questions to discover functional code flows</div>
                </div>
              </button>

              <button
                className="btn btn-secondary"
                style={{ justifyContent: 'flex-start', textAlign: 'left', padding: '10px 14px' }}
                onClick={() => onNavigate('impact')}
              >
                <span style={{ fontSize: '16px', marginRight: '8px' }}>💥</span>
                <div>
                  <div className="font-bold text-xs">Change Impact Radar</div>
                  <div className="text-xs text-muted">Identify downstream UI, services, data, and test impacts</div>
                </div>
              </button>

              <button
                className="btn btn-secondary"
                style={{ justifyContent: 'flex-start', textAlign: 'left', padding: '10px 14px' }}
                onClick={() => onNavigate('regression')}
              >
                <span style={{ fontSize: '16px', marginRight: '8px' }}>🐛</span>
                <div>
                  <div className="font-bold text-xs">Regression Investigator</div>
                  <div className="text-xs text-muted">Discover edge cases, metric shifts, and coverage risks from diffs</div>
                </div>
              </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

// ── Tab 2: Dedicated Architecture Map ────────────────────────────────────

function ArchitectureMapTab({
  graph,
  selectedLayerId,
  onSelectLayerId,
}: {
  graph: ProjectIntelligence['architecture_graph'];
  selectedLayerId: string | null;
  onSelectLayerId: (id: string) => void;
}) {
  return (
    <div>
      <div className="mb-16">
        <h3 className="font-bold text-sm">Interactive Architecture Map</h3>
        <p className="text-xs text-muted">
          Click any layer node to inspect cross-layer dependencies and verifiable source evidence.
        </p>
      </div>

      <div className="flex-col" style={{ gap: '16px' }}>
        {graph.edges.map((e, idx) => (
          <div key={idx} className="card" style={{ background: '#f8fafc' }}>
            <div className="card__body" style={{ padding: '12px 16px' }}>
              <div className="flex-row" style={{ justifyContent: 'space-between', marginBottom: '6px' }}>
                <div className="flex-row" style={{ gap: '8px' }}>
                  <span className="mono-pill font-bold" style={{ color: 'var(--color-accent)' }}>{e.source_id.replace('layer::', '').toUpperCase()}</span>
                  <span>➔</span>
                  <span className="mono-pill font-bold" style={{ color: '#065f46' }}>{e.target_id.replace('layer::', '').toUpperCase()}</span>
                </div>
                <span className="badge" style={{ fontSize: '11px', background: 'var(--color-surface)', border: '1px solid var(--color-border)' }}>
                  {e.count} relationship(s)
                </span>
              </div>
              <div className="text-xs text-muted">
                Types: {e.relationship_types.join(', ')}
              </div>
              {e.evidence.length > 0 && e.evidence[0].snippet && (
                <pre className="font-mono text-xs mt-8" style={{ background: '#1e293b', color: '#f8fafc', padding: '6px 10px', borderRadius: '4px', margin: '6px 0 0 0', maxHeight: '40px', overflow: 'hidden' }}>
                  {e.evidence[0].snippet}
                </pre>
              )}
            </div>
          </div>
        ))}
      </div>
    </div>
  );
}

// ── Tab 3: Module Explorer ────────────────────────────────────────────────

function ModuleExplorerTab({
  modules,
  selectedModule,
  onSelectModule,
}: {
  modules: RepositoryModule[];
  selectedModule: RepositoryModule | null;
  onSelectModule: (m: RepositoryModule) => void;
}) {
  if (modules.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-state__subtitle">No modules derived from repository structure.</div>
      </div>
    );
  }

  return (
    <div className="grid-2">
      {/* Left Column: Modules List */}
      <div>
        <div className="text-xs text-muted font-bold mb-12">DERIVED MODULES ({modules.length})</div>
        <div className="flex-col" style={{ gap: '8px' }}>
          {modules.map(mod => {
            const isSelected = selectedModule?.path === mod.path;
            return (
              <div
                key={mod.path}
                onClick={() => onSelectModule(mod)}
                style={{
                  padding: '12px 14px',
                  borderRadius: 'var(--radius)',
                  border: `1px solid ${isSelected ? 'var(--color-accent)' : 'var(--color-border)'}`,
                  background: isSelected ? 'var(--color-accent-light)' : 'var(--color-surface)',
                  cursor: 'pointer',
                  transition: 'all 0.15s ease',
                }}
              >
                <div className="flex-row" style={{ justifyContent: 'space-between', marginBottom: '4px' }}>
                  <div className="flex-row" style={{ gap: '6px' }}>
                    <span className="font-bold text-sm" style={{ color: 'var(--color-text)' }}>
                      📁 {mod.name}
                    </span>
                    <span className="role-tag" style={{ fontSize: '10px' }}>{mod.role}</span>
                  </div>
                  <span className="mono-pill">{mod.file_count} files</span>
                </div>
                <div className="text-xs text-muted font-mono">{mod.path}</div>
                <div className="flex-row mt-8" style={{ gap: '8px', fontSize: '11px', color: 'var(--color-text-muted)' }}>
                  <span>{mod.symbol_count} symbols</span>
                  <span>•</span>
                  <span>Inbound: {mod.incoming_count}</span>
                  <span>•</span>
                  <span>Outbound: {mod.outgoing_count}</span>
                </div>
              </div>
            );
          })}
        </div>
      </div>

      {/* Right Column: Module Details */}
      <div>
        {selectedModule ? (
          <div className="card">
            <div className="card__header">
              <span className="card__title">Module: {selectedModule.name}</span>
              <span className="mono-pill">{selectedModule.path}</span>
            </div>
            <div className="card__body">
              <div className="flex-col" style={{ gap: '16px' }}>
                <div>
                  <div className="text-xs text-muted font-bold mb-6">DEPENDENT MODULES</div>
                  <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap' }}>
                    {selectedModule.dependencies.length === 0 ? (
                      <span className="text-xs text-muted">No external module dependencies</span>
                    ) : (
                      selectedModule.dependencies.map(d => (
                        <span key={d} className="mono-pill" style={{ background: '#dbeafe', color: '#1e40af' }}>
                          ➔ {d}
                        </span>
                      ))
                    )}
                  </div>
                </div>

                <div>
                  <div className="text-xs text-muted font-bold mb-6">SOURCE FILES ({selectedModule.files.length})</div>
                  <div className="scroll-area" style={{ maxHeight: '180px' }}>
                    <div className="flex-col" style={{ gap: '4px' }}>
                      {selectedModule.files.map(f => (
                        <div key={f} className="text-xs font-mono" style={{ padding: '4px 8px', background: 'var(--color-surface-2)', borderRadius: '4px' }}>
                          📄 {f}
                        </div>
                      ))}
                    </div>
                  </div>
                </div>

                <div>
                  <div className="text-xs text-muted font-bold mb-6">CONTAINED SYMBOLS ({selectedModule.symbols.length})</div>
                  <div className="flex-row" style={{ gap: '4px', flexWrap: 'wrap', maxHeight: '120px', overflowY: 'auto' }}>
                    {selectedModule.symbols.map(s => (
                      <span key={s} className="mono-pill" style={{ fontSize: '10px' }}>
                        {s}
                      </span>
                    ))}
                  </div>
                </div>
              </div>
            </div>
          </div>
        ) : (
          <div className="empty-state">
            <div className="empty-state__subtitle">Select a module to inspect its files and dependencies.</div>
          </div>
        )}
      </div>
    </div>
  );
}

// ── Tab 4: API Intelligence ───────────────────────────────────────────────

function ApiIntelligenceTab({
  apiEndpoints,
  allEndpoints,
  selectedMethod,
  onSelectMethod,
  searchQuery,
  onSearchChange,
  methodCounts,
}: {
  apiEndpoints: ApiEndpoint[];
  allEndpoints: ApiEndpoint[];
  selectedMethod: string;
  onSelectMethod: (m: string) => void;
  searchQuery: string;
  onSearchChange: (q: string) => void;
  methodCounts: Record<string, number>;
}) {
  if (allEndpoints.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-state__icon">🌐</div>
        <div className="empty-state__title">No API endpoints detected</div>
        <div className="empty-state__subtitle">
          CodeAtlas scans for FastAPI, Flask, Express, Django, and REST routes. No matching endpoint declarations were found in this repository.
        </div>
      </div>
    );
  }

  const uniqueMethods = Object.keys(methodCounts);

  return (
    <div className="flex-col" style={{ gap: '16px' }}>
      {/* Filter Bar */}
      <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '12px' }}>
        <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap' }}>
          <button
            className={`btn btn-sm ${selectedMethod === 'ALL' ? 'btn-primary' : 'btn-secondary'}`}
            onClick={() => onSelectMethod('ALL')}
          >
            All ({allEndpoints.length})
          </button>
          {uniqueMethods.map(m => (
            <button
              key={m}
              className={`btn btn-sm ${selectedMethod === m ? 'btn-primary' : 'btn-secondary'}`}
              onClick={() => onSelectMethod(m)}
            >
              {m} ({methodCounts[m]})
            </button>
          ))}
        </div>

        <input
          className="input input-sm"
          style={{ width: '240px' }}
          placeholder="Filter endpoints or handlers..."
          value={searchQuery}
          onChange={e => onSearchChange(e.target.value)}
        />
      </div>

      {/* Endpoints List */}
      <div className="flex-col" style={{ gap: '10px' }}>
        {apiEndpoints.length === 0 ? (
          <div className="empty-state" style={{ padding: '24px 0' }}>
            <div className="empty-state__subtitle">No endpoints match the selected filter.</div>
          </div>
        ) : (
          apiEndpoints.map((ep, idx) => {
            const style = HTTP_METHOD_COLORS[ep.method] || HTTP_METHOD_COLORS.GET;
            return (
              <div
                key={`${ep.method}:${ep.path}:${idx}`}
                style={{
                  padding: '12px 16px',
                  borderRadius: 'var(--radius)',
                  background: 'var(--color-surface)',
                  border: '1px solid var(--color-border)',
                  boxShadow: 'var(--shadow-sm)',
                }}
              >
                <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center', flexWrap: 'wrap', gap: '8px' }}>
                  <div className="flex-row" style={{ gap: '8px' }}>
                    <span
                      style={{
                        padding: '2px 8px',
                        borderRadius: '4px',
                        fontWeight: 800,
                        fontSize: '11px',
                        background: style.bg,
                        color: style.color,
                        border: `1px solid ${style.border}`,
                      }}
                    >
                      {ep.method}
                    </span>
                    <span className="font-mono font-bold text-sm" style={{ color: 'var(--color-text)' }}>
                      {ep.path}
                    </span>
                  </div>

                  <div className="flex-row" style={{ gap: '6px' }}>
                    <span className="mono-pill">fn: {ep.handler}</span>
                    <span className="text-xs text-muted font-mono">{ep.file}:{ep.line_start}</span>
                  </div>
                </div>

                {ep.docstring && (
                  <div className="text-xs mt-8" style={{ color: 'var(--color-text-muted)', lineHeight: 1.4 }}>
                    {ep.docstring}
                  </div>
                )}

                {ep.evidence.length > 0 && ep.evidence[0].snippet && (
                  <pre className="font-mono text-xs mt-8" style={{ background: '#1e293b', color: '#f8fafc', padding: '6px 10px', borderRadius: '4px', margin: '6px 0 0 0', maxHeight: '44px', overflow: 'hidden' }}>
                    {ep.evidence[0].snippet}
                  </pre>
                )}
              </div>
            );
          })
        )}
      </div>
    </div>
  );
}

// ── Tab 5: Data & Storage ─────────────────────────────────────────────────

function DataStorageTab({
  storageTechnologies,
}: {
  storageTechnologies: StorageTechnology[];
}) {
  if (storageTechnologies.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-state__icon">💾</div>
        <div className="empty-state__title">No storage system detected</div>
        <div className="empty-state__subtitle">
          CodeAtlas checks for Firestore, SQLite, PostgreSQL, MongoDB, Local Key-Value stores, and domain schemas. None were explicitly declared in this repository.
        </div>
      </div>
    );
  }

  return (
    <div className="flex-col" style={{ gap: '16px' }}>
      {storageTechnologies.map((st, idx) => (
        <div key={idx} className="card" style={{ boxShadow: 'var(--shadow-sm)' }}>
          <div className="card__body" style={{ padding: '16px' }}>
            <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center', marginBottom: '8px' }}>
              <div className="flex-row" style={{ gap: '8px' }}>
                <span className="font-bold text-sm" style={{ color: 'var(--color-text)' }}>
                  💾 {st.technology}
                </span>
                <span className="role-tag" style={{ background: '#fef3c7', color: '#92400e', borderColor: '#fde68a' }}>
                  {st.category}
                </span>
              </div>
              <span className={`confidence-badge ${st.confidence}`}>{st.confidence}</span>
            </div>

            <div className="text-xs" style={{ color: 'var(--color-text-muted)', lineHeight: 1.5, marginBottom: '12px' }}>
              {st.description}
            </div>

            {/* Discovered Collections / Entities */}
            {st.entities.length > 0 && (
              <div className="mb-12">
                <div className="text-xs text-muted font-bold mb-4">DISCOVERED ENTITIES / COLLECTIONS ({st.entities.length})</div>
                <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap' }}>
                  {st.entities.map(e => (
                    <span key={e} className="mono-pill" style={{ background: '#ecfdf5', color: '#065f46', borderColor: '#a7f3d0' }}>
                      📦 {e}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Associated Files */}
            {st.files.length > 0 && (
              <div className="mb-12">
                <div className="text-xs text-muted font-bold mb-4">ASSOCIATED FILES ({st.files.length})</div>
                <div className="flex-row" style={{ gap: '6px', flexWrap: 'wrap', maxHeight: '80px', overflowY: 'auto' }}>
                  {st.files.slice(0, 10).map(f => (
                    <span key={f} className="text-xs font-mono text-muted">
                      📄 {f}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {/* Source Evidence */}
            {st.evidence.length > 0 && st.evidence[0].snippet && (
              <div>
                <div className="text-xs text-muted font-bold mb-4">SOURCE EVIDENCE</div>
                <pre className="font-mono text-xs" style={{ background: '#1e293b', color: '#f8fafc', padding: '6px 10px', borderRadius: '4px', margin: 0, maxHeight: '44px', overflow: 'hidden' }}>
                  {st.evidence[0].file}:{st.evidence[0].line_start} &rarr; {st.evidence[0].snippet}
                </pre>
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}

// ── Tab 6: Recent Analysis ────────────────────────────────────────────────

function RecentAnalysisTab({
  recentAnalyses,
  onNavigate,
}: {
  recentAnalyses: RecentAnalysisItem[];
  onNavigate: (page: 'tracer' | 'impact' | 'regression') => void;
}) {
  if (recentAnalyses.length === 0) {
    return (
      <div className="empty-state">
        <div className="empty-state__icon">⏱</div>
        <div className="empty-state__title">No analyses yet</div>
        <div className="empty-state__subtitle">
          Run Feature Tracer, Change Impact Radar, or Regression Investigator to automatically build a live timeline of your codebase explorations.
        </div>
        <div className="flex-row mt-16" style={{ justifyContent: 'center', gap: '8px' }}>
          <button className="btn btn-secondary btn-sm" onClick={() => onNavigate('tracer')}>
            🔍 Try Feature Tracer
          </button>
          <button className="btn btn-secondary btn-sm" onClick={() => onNavigate('impact')}>
            💥 Try Impact Radar
          </button>
          <button className="btn btn-secondary btn-sm" onClick={() => onNavigate('regression')}>
            🐛 Try Regression Investigator
          </button>
        </div>
      </div>
    );
  }

  const TYPE_LABELS: Record<string, { label: string; icon: string; bg: string; color: string; border: string }> = {
    trace: { label: 'Feature Trace', icon: '🔍', bg: '#dbeafe', color: '#1e40af', border: '#93c5fd' },
    impact: { label: 'Impact Analysis', icon: '💥', bg: '#fee2e2', color: '#991b1b', border: '#fca5a5' },
    regression: { label: 'Regression Investigation', icon: '🐛', bg: '#fef3c7', color: '#92400e', border: '#fde68a' },
  };

  return (
    <div className="flex-col" style={{ gap: '10px' }}>
      <div className="text-xs text-muted font-bold mb-4">RECENT ANALYSES IN THIS SESSION ({recentAnalyses.length})</div>
      {recentAnalyses.map(item => {
        const style = TYPE_LABELS[item.type] || TYPE_LABELS.trace;
        const timeStr = new Date(item.timestamp).toLocaleTimeString();
        return (
          <div
            key={item.id}
            style={{
              padding: '12px 16px',
              borderRadius: 'var(--radius)',
              background: 'var(--color-surface)',
              border: '1px solid var(--color-border)',
              boxShadow: 'var(--shadow-sm)',
            }}
          >
            <div className="flex-row" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
              <div className="flex-row" style={{ gap: '8px' }}>
                <span
                  style={{
                    fontSize: '11px',
                    fontWeight: 700,
                    padding: '2px 8px',
                    borderRadius: '4px',
                    background: style.bg,
                    color: style.color,
                    border: `1px solid ${style.border}`,
                  }}
                >
                  {style.icon} {style.label}
                </span>
                <span className="font-bold text-sm" style={{ color: 'var(--color-text)' }}>
                  "{item.targetOrQuery}"
                </span>
              </div>

              <div className="flex-row" style={{ gap: '8px' }}>
                <span className="text-xs text-muted font-mono">{timeStr}</span>
                <button
                  className="btn btn-secondary btn-sm"
                  style={{ fontSize: '11px', padding: '2px 8px' }}
                  onClick={() => onNavigate(item.type === 'trace' ? 'tracer' : item.type)}
                >
                  View in {style.label} &rarr;
                </button>
              </div>
            </div>

            <div className="text-xs text-muted mt-8">
              <strong>Result:</strong> {item.countSummary}
            </div>

            {item.detail && (
              <div className="text-xs text-muted mt-4" style={{ lineHeight: 1.4 }}>
                {item.detail}
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}

// ── Tab 7: Source Files Table ─────────────────────────────────────────────

function SourceFilesTab({
  files,
  searchQuery,
  onSearchChange,
}: {
  files: FileSummary[];
  searchQuery: string;
  onSearchChange: (q: string) => void;
}) {
  return (
    <div>
      <div className="flex-row mb-12" style={{ justifyContent: 'space-between', alignItems: 'center' }}>
        <span className="font-bold text-xs text-muted">INDEXED FILES ({files.length})</span>
        <input
          className="input input-sm"
          style={{ width: '220px' }}
          placeholder="Filter files by path or language..."
          value={searchQuery}
          onChange={e => onSearchChange(e.target.value)}
        />
      </div>

      <div className="scroll-area" style={{ maxHeight: '480px' }}>
        <table className="files-table">
          <thead>
            <tr>
              <th>Path</th>
              <th>Language</th>
              <th>Lines</th>
              <th>Symbols</th>
              <th>Flags</th>
            </tr>
          </thead>
          <tbody>
            {files.map((f: FileSummary) => (
              <tr key={f.path}>
                <td className="path-cell" title={f.path}>{f.path}</td>
                <td>{f.language}</td>
                <td>{f.line_count.toLocaleString()}</td>
                <td>{f.symbol_count}</td>
                <td>
                  <div className="flex-row" style={{ gap: '4px', flexWrap: 'wrap' }}>
                    {f.is_entry_point && <span className="mono-pill">entry</span>}
                    {f.is_test && <span className="mono-pill">test</span>}
                    {f.is_config && <span className="mono-pill">config</span>}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
