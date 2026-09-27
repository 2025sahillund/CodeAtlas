import React, { useState, useEffect, useCallback } from 'react';
import {
  Repository,
  FeatureTrace,
  TraceNode,
  ImpactAnalysis,
  ImpactNode,
  RegressionAnalysis,
  RegressionRisk,
  RecentAnalysisItem,
} from './types';
import { repositoryApi } from './services/api';
import RepositoryUpload from './components/repository/RepositoryUpload';
import RepositoryOverview from './components/repository/RepositoryOverview';
import FeatureTracerPage from './components/tracer/FeatureTracerPage';
import EvidencePanel from './components/tracer/EvidencePanel';
import ChangeImpactRadarPage from './components/impact/ChangeImpactRadarPage';
import ImpactEvidencePanel from './components/impact/ImpactEvidencePanel';
import RegressionInvestigatorPage from './components/regression/RegressionInvestigatorPage';
import RegressionEvidencePanel from './components/regression/RegressionEvidencePanel';

type Page = 'upload' | 'overview' | 'tracer' | 'impact' | 'regression';

function App() {
  const [page, setPage] = useState<Page>('upload');
  const [repository, setRepository] = useState<Repository | null>(null);
  const [traceResult, setTraceResult] = useState<FeatureTrace | null>(null);
  const [selectedNode, setSelectedNode] = useState<TraceNode | null>(null);
  const [impactResult, setImpactResult] = useState<ImpactAnalysis | null>(null);
  const [selectedImpactNode, setSelectedImpactNode] = useState<ImpactNode | null>(null);
  const [regressionResult, setRegressionResult] = useState<RegressionAnalysis | null>(null);
  const [selectedRegressionItem, setSelectedRegressionItem] = useState<
    { type: 'risk'; risk: RegressionRisk } | { type: 'node'; node: ImpactNode } | null
  >(null);
  const [recentAnalyses, setRecentAnalyses] = useState<RecentAnalysisItem[]>([]);
  const [pollingId, setPollingId] = useState<string | null>(null);

  // Poll repository status while scanning
  useEffect(() => {
    if (!pollingId) return;
    if (repository?.status === 'indexed' || repository?.status === 'error') {
      setPollingId(null);
      return;
    }
    const interval = setInterval(async () => {
      try {
        const updated = await repositoryApi.get(pollingId);
        setRepository(updated);
        if (updated.status === 'indexed' || updated.status === 'error') {
          setPollingId(null);
          clearInterval(interval);
        }
      } catch {
        clearInterval(interval);
        setPollingId(null);
      }
    }, 1200);
    return () => clearInterval(interval);
  }, [pollingId, repository?.status]);

  const handleRepositoryReady = useCallback((repo: Repository) => {
    setRepository(repo);
    setPollingId(repo.id);
    setPage('overview');
    setTraceResult(null);
    setSelectedNode(null);
    setImpactResult(null);
    setSelectedImpactNode(null);
    setRegressionResult(null);
    setSelectedRegressionItem(null);
  }, []);

  const handleTrace = useCallback((result: FeatureTrace) => {
    setTraceResult(result);
    setSelectedNode(null);

    const item: RecentAnalysisItem = {
      id: `trace-${Date.now()}`,
      type: 'trace',
      targetOrQuery: result.query,
      timestamp: Date.now(),
      countSummary: `${result.total_nodes} nodes • ${result.total_edges} edges (${result.confirmed.length} confirmed)`,
      detail: result.summary,
    };
    setRecentAnalyses(prev => [item, ...prev.filter(x => !(x.type === 'trace' && x.targetOrQuery === result.query))].slice(0, 15));
  }, []);

  const handleNodeSelect = useCallback((node: TraceNode) => {
    setSelectedNode(prev => prev?.id === node.id ? null : node);
  }, []);

  const handleImpactAnalyze = useCallback((result: ImpactAnalysis) => {
    setImpactResult(result);
    setSelectedImpactNode(null);

    const targetLabel = result.target.symbol || result.target.file || result.target.id;
    const item: RecentAnalysisItem = {
      id: `impact-${Date.now()}`,
      type: 'impact',
      targetOrQuery: targetLabel,
      timestamp: Date.now(),
      countSummary: `${result.summary.total_impacted} impacted components (${result.summary.direct_count} direct, ${result.summary.ui_count} UI)`,
      detail: result.summary.description,
    };
    setRecentAnalyses(prev => [item, ...prev.filter(x => !(x.type === 'impact' && x.targetOrQuery === targetLabel))].slice(0, 15));
  }, []);

  const handleImpactNodeSelect = useCallback((node: ImpactNode) => {
    setSelectedImpactNode(prev => prev?.id === node.id ? null : node);
  }, []);

  const handleRegressionInvestigate = useCallback((result: RegressionAnalysis) => {
    setRegressionResult(result);
    setSelectedRegressionItem(null);

    const queryLabel = result.query || (result.changed_files[0]?.file ? `Diff: ${result.changed_files[0].file}` : 'Change Investigation');
    const item: RecentAnalysisItem = {
      id: `reg-${Date.now()}`,
      type: 'regression',
      targetOrQuery: queryLabel,
      timestamp: Date.now(),
      countSummary: `${result.summary.risks_count} risk(s) detected (${result.summary.high_risk_count} HIGH, ${result.summary.affected_components_count} affected)`,
      detail: result.summary.description,
    };
    setRecentAnalyses(prev => [item, ...prev.slice(0, 14)]);
  }, []);

  const handleSelectRisk = useCallback((risk: RegressionRisk) => {
    setSelectedRegressionItem(prev =>
      prev?.type === 'risk' && prev.risk.id === risk.id ? null : { type: 'risk', risk }
    );
  }, []);

  const handleSelectRegressionNode = useCallback((node: ImpactNode) => {
    setSelectedRegressionItem(prev =>
      prev?.type === 'node' && prev.node.id === node.id ? null : { type: 'node', node }
    );
  }, []);

  const navDisabled = !repository || repository.status !== 'indexed';

  return (
    <div className="app-shell">
      {/* Header */}
      <header className="app-header">
        <a className="app-header__logo" href="#" onClick={e => { e.preventDefault(); setPage('upload'); }}>
          <div className="app-header__logo-icon">CA</div>
          <span className="app-header__title">CodeAtlas</span>
        </a>
        <span className="app-header__tagline">Understand before you change.</span>
        <div className="app-header__spacer" />
        {repository && (
          <div className="flex-row">
            <span className="text-sm text-muted font-mono">{repository.name}</span>
            <StatusBadge status={repository.status} />
          </div>
        )}
      </header>

      <div className="app-body">
        {/* Sidebar */}
        <nav className="app-sidebar">
          {repository && (
            <div style={{ padding: '0 12px', marginBottom: '16px' }}>
              <RepositoryMiniCard repo={repository} />
            </div>
          )}

          <div className="nav-section">
            <div className="nav-section__label">Repository</div>
            <button
              className={`nav-item ${page === 'upload' ? 'active' : ''}`}
              onClick={() => setPage('upload')}
            >
              <span className="nav-item__icon">📁</span>
              {repository ? 'Change Repository' : 'Add Repository'}
            </button>
            <button
              className={`nav-item ${page === 'overview' ? 'active' : ''} ${navDisabled ? 'disabled' : ''}`}
              onClick={() => !navDisabled && setPage('overview')}
              disabled={navDisabled}
            >
              <span className="nav-item__icon">🗺</span>
              Overview
            </button>
          </div>

          <div className="nav-section">
            <div className="nav-section__label">Analysis</div>
            <button
              className={`nav-item ${page === 'tracer' ? 'active' : ''} ${navDisabled ? 'disabled' : ''}`}
              onClick={() => !navDisabled && setPage('tracer')}
              disabled={navDisabled}
            >
              <span className="nav-item__icon">🔍</span>
              Feature Tracer
            </button>
            <button
              className={`nav-item ${page === 'impact' ? 'active' : ''} ${navDisabled ? 'disabled' : ''}`}
              onClick={() => !navDisabled && setPage('impact')}
              disabled={navDisabled}
            >
              <span className="nav-item__icon">💥</span>
              Change Impact Radar
            </button>
            <button
              className={`nav-item ${page === 'regression' ? 'active' : ''} ${navDisabled ? 'disabled' : ''}`}
              onClick={() => !navDisabled && setPage('regression')}
              disabled={navDisabled}
            >
              <span className="nav-item__icon">🐛</span>
              Regression Investigator
            </button>
          </div>
        </nav>

        {/* Main content */}
        <main className="app-main">
          {page === 'upload' && (
            <RepositoryUpload onReady={handleRepositoryReady} />
          )}
          {page === 'overview' && repository && (
            <RepositoryOverview
              repository={repository}
              recentAnalyses={recentAnalyses}
              onNavigate={(p) => setPage(p)}
            />
          )}
          {page === 'tracer' && repository && (
            <div className="trace-layout">
              <FeatureTracerPage
                repository={repository}
                onTrace={handleTrace}
                traceResult={traceResult}
                selectedNode={selectedNode}
                onNodeSelect={handleNodeSelect}
              />
              <EvidencePanel
                selectedNode={selectedNode}
                traceResult={traceResult}
              />
            </div>
          )}
          {page === 'impact' && repository && (
            <div className="trace-layout">
              <ChangeImpactRadarPage
                repository={repository}
                onAnalyze={handleImpactAnalyze}
                impactResult={impactResult}
                selectedNode={selectedImpactNode}
                onNodeSelect={handleImpactNodeSelect}
              />
              <ImpactEvidencePanel
                selectedNode={selectedImpactNode}
                impactResult={impactResult}
              />
            </div>
          )}
          {page === 'regression' && repository && (
            <div className="trace-layout">
              <RegressionInvestigatorPage
                repository={repository}
                onInvestigate={handleRegressionInvestigate}
                regressionResult={regressionResult}
                selectedItem={selectedRegressionItem}
                onSelectRisk={handleSelectRisk}
                onSelectNode={handleSelectRegressionNode}
              />
              <RegressionEvidencePanel
                selectedItem={selectedRegressionItem}
                regressionResult={regressionResult}
              />
            </div>
          )}
          {!repository && page !== 'upload' && (
            <div className="empty-state">
              <div className="empty-state__icon">📂</div>
              <div className="empty-state__title">No repository loaded</div>
              <div className="empty-state__subtitle">
                Upload a repository ZIP or add a local path to get started.
              </div>
            </div>
          )}
        </main>
      </div>
    </div>
  );
}

// ── Small helpers ──────────────────────────────────────────────────────────

function StatusBadge({ status }: { status: string }) {
  const labels: Record<string, string> = {
    scanning: 'Scanning…',
    indexed: 'Ready',
    error: 'Error',
    uploaded: 'Uploaded',
  };
  return (
    <span className={`status-badge ${status}`}>
      <span className={`status-dot ${status === 'scanning' ? 'pulse' : ''}`} />
      {labels[status] ?? status}
    </span>
  );
}

function RepositoryMiniCard({ repo }: { repo: Repository }) {
  const topLang = Object.entries(repo.languages)
    .sort((a, b) => b[1] - a[1])
    .slice(0, 2)
    .map(([l]) => l)
    .join(', ');

  return (
    <div className="repo-card">
      <div className="repo-card__name">{repo.name}</div>
      <div className="repo-card__meta">
        <div className="repo-card__meta-row">
          <span>Files</span>
          <strong>{repo.source_files}</strong>
        </div>
        <div className="repo-card__meta-row">
          <span>Symbols</span>
          <strong>{repo.symbol_count}</strong>
        </div>
        {topLang && (
          <div className="repo-card__meta-row">
            <span>Languages</span>
            <strong style={{ fontSize: '10px' }}>{topLang}</strong>
          </div>
        )}
      </div>
    </div>
  );
}

export default App;
