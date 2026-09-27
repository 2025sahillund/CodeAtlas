import React, { useState, useEffect, useMemo, useCallback } from 'react';
import {
  Repository,
  RepositoryTree,
  RepositoryTreeNode,
  RelationshipRef,
  TreeNodeType,
} from '../../types';
import { repositoryApi } from '../../services/api';

interface Props {
  repository: Repository;
  onNavigateToFeature?: (page: 'tracer' | 'impact' | 'regression') => void;
}

const LAYER_COLORS: Record<string, { bg: string; color: string; border: string }> = {
  'UI / Screens': { bg: '#eff6ff', color: '#1d4ed8', border: '#bfdbfe' },
  'API / Controllers': { bg: '#ecfdf5', color: '#047857', border: '#a7f3d0' },
  'Services': { bg: '#f5f3ff', color: '#6d28d9', border: '#ddd6fe' },
  'Models': { bg: '#fffbeb', color: '#b45309', border: '#fde68a' },
  'Storage & Data Access': { bg: '#fef2f2', color: '#b91c1c', border: '#fecaca' },
  'External Integrations': { bg: '#fdf2f8', color: '#be185d', border: '#fbcfe8' },
  'Tests': { bg: '#f0fdf4', color: '#15803d', border: '#bbf7d0' },
  'Configuration': { bg: '#f8fafc', color: '#475569', border: '#cbd5e1' },
};

const REL_TYPE_COLORS: Record<string, { bg: string; color: string }> = {
  CALLS: { bg: '#dbeafe', color: '#1e40af' },
  IMPORTS: { bg: '#f1f5f9', color: '#334155' },
  READS: { bg: '#fef3c7', color: '#92400e' },
  WRITES: { bg: '#fee2e2', color: '#991b1b' },
  CREATES: { bg: '#dcfce7', color: '#166534' },
  EXTENDS: { bg: '#f3e8ff', color: '#6b21a8' },
  TESTS: { bg: '#e0e7ff', color: '#3730a3' },
  ROUTES_TO: { bg: '#ffedd5', color: '#9a3412' },
};

export default function RepositoryTreeViewer({ repository, onNavigateToFeature }: Props) {
  const [treeData, setTreeData] = useState<RepositoryTree | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  // Tree UI state
  const [expandedIds, setExpandedIds] = useState<Set<string>>(new Set());
  const [selectedNode, setSelectedNode] = useState<RepositoryTreeNode | null>(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [showSymbolsInTree, setShowSymbolsInTree] = useState(true);
  const [detailTab, setDetailTab] = useState<'relationships' | 'graph' | 'symbols' | 'imports'>('relationships');

  // Fetch Tree
  useEffect(() => {
    if (!repository.id || repository.status !== 'indexed') return;
    let isCurrent = true;
    setLoading(true);
    setError(null);

    repositoryApi.getTree(repository.id)
      .then((data) => {
        if (isCurrent) {
          setTreeData(data);
          setSelectedNode(data.root);

          // Auto-expand root and top-level subdirectories
          const initialExpanded = new Set<string>();
          initialExpanded.add(data.root.id);
          for (const child of data.root.children) {
            if (child.node_type === 'directory') {
              initialExpanded.add(child.id);
            }
          }
          setExpandedIds(initialExpanded);
        }
      })
      .catch((err) => {
        if (isCurrent) {
          setError(err?.response?.data?.detail || err?.message || 'Failed to load repository tree.');
        }
      })
      .finally(() => {
        if (isCurrent) setLoading(false);
      });

    return () => {
      isCurrent = false;
    };
  }, [repository.id, repository.status]);

  // Toggle node expansion
  const toggleExpand = (nodeId: string, e?: React.MouseEvent) => {
    if (e) e.stopPropagation();
    setExpandedIds((prev) => {
      const next = new Set(prev);
      if (next.has(nodeId)) {
        next.delete(nodeId);
      } else {
        next.add(nodeId);
      }
      return next;
    });
  };

  // Expand all directories
  const expandAll = () => {
    if (!treeData) return;
    const allIds = new Set<string>();
    const traverse = (node: RepositoryTreeNode) => {
      allIds.add(node.id);
      for (const child of node.children) {
        traverse(child);
      }
    };
    traverse(treeData.root);
    setExpandedIds(allIds);
  };

  // Collapse all except root
  const collapseAll = () => {
    if (!treeData) return;
    setExpandedIds(new Set([treeData.root.id]));
  };

  // Find node by path or id in tree
  const findNodeInTree = useCallback((root: RepositoryTreeNode, targetId: string): RepositoryTreeNode | null => {
    if (root.id === targetId || root.path === targetId) return root;
    for (const child of root.children) {
      const found = findNodeInTree(child, targetId);
      if (found) return found;
    }
    return null;
  }, []);

  // Search filter and auto-expansion
  const searchMatches = useMemo(() => {
    if (!treeData || !searchQuery.trim()) return [];
    const query = searchQuery.trim().toLowerCase();
    const matches: RepositoryTreeNode[] = [];

    const traverse = (node: RepositoryTreeNode) => {
      const nameMatch = node.name.toLowerCase().includes(query);
      const pathMatch = node.path.toLowerCase().includes(query);
      const symbolMatch = node.node_type === 'file' && node.children.some(
        (c) => c.name.toLowerCase().includes(query)
      );

      if (nameMatch || pathMatch || symbolMatch) {
        matches.push(node);
      }
      for (const child of node.children) {
        traverse(child);
      }
    };

    traverse(treeData.root);
    return matches;
  }, [treeData, searchQuery]);

  // Expand ancestors of search matches
  useEffect(() => {
    if (!searchQuery.trim() || !treeData) return;
    const query = searchQuery.trim().toLowerCase();
    const toExpand = new Set<string>(expandedIds);

    const checkAndExpand = (node: RepositoryTreeNode): boolean => {
      let containsMatch = node.name.toLowerCase().includes(query) || node.path.toLowerCase().includes(query);

      for (const child of node.children) {
        const childMatched = checkAndExpand(child);
        if (childMatched) {
          containsMatch = true;
        }
      }

      if (containsMatch) {
        toExpand.add(node.id);
      }
      return containsMatch;
    };

    checkAndExpand(treeData.root);
    setExpandedIds(toExpand);
  }, [searchQuery, treeData]);

  // Select node and expand path to it
  const handleSelectNode = (node: RepositoryTreeNode) => {
    setSelectedNode(node);
  };

  // Jump to relationship target
  const handleJumpToTarget = (rel: RelationshipRef) => {
    if (!treeData) return;
    const targetFile = rel.target_file || rel.target_id;
    const found = findNodeInTree(treeData.root, `file::${targetFile}`) ||
                  findNodeInTree(treeData.root, `sym::${rel.target_id}`) ||
                  findNodeInTree(treeData.root, targetFile);

    if (found) {
      setSelectedNode(found);
      // Ensure ancestors are expanded
      const parts = found.path.split('/');
      const toAdd = new Set(expandedIds);
      let curr = '';
      for (let i = 0; i < parts.length - 1; i++) {
        curr = curr ? `${curr}/${parts[i]}` : parts[i];
        toAdd.add(`dir::${curr}`);
      }
      toAdd.add(found.id);
      setExpandedIds(toAdd);
    }
  };

  if (loading) {
    return (
      <div className="card text-center p-32">
        <div className="loading-spinner" style={{ margin: '0 auto 16px' }} />
        <h4 className="font-bold mb-4">Building Visual Repository Tree...</h4>
        <p className="text-sm text-muted">
          Parsing hierarchy, indexing declared symbols, and constructing cross-layer relationship maps.
        </p>
      </div>
    );
  }

  if (error || !treeData) {
    return (
      <div className="card p-24" style={{ borderLeft: '4px solid var(--color-danger)' }}>
        <h4 className="font-bold text-danger mb-4">Failed to Load Repository Tree</h4>
        <p className="text-sm text-muted">{error || 'Unknown error occurred while generating tree.'}</p>
      </div>
    );
  }

  // Recursive Tree Node Renderer
  const renderTreeNode = (node: RepositoryTreeNode, depth: number = 0) => {
    const isExpanded = expandedIds.has(node.id);
    const isSelected = selectedNode?.id === node.id;
    const hasChildren = node.children.length > 0;
    const isSymbol = node.node_type === 'symbol';
    const isFile = node.node_type === 'file';
    const isDir = node.node_type === 'directory';
    const isRepo = node.node_type === 'repository';

    if (isSymbol && !showSymbolsInTree) return null;

    // Search query match check
    const isMatch = searchQuery.trim() && (
      node.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
      node.path.toLowerCase().includes(searchQuery.toLowerCase())
    );

    const layerStyle = node.layer ? LAYER_COLORS[node.layer] : undefined;

    return (
      <div key={node.id} className="tree-node-wrapper">
        <div
          className={`tree-node-item ${isSelected ? 'tree-node-item--selected' : ''} ${isMatch ? 'tree-node-item--matched' : ''}`}
          style={{
            paddingLeft: `${depth * 18 + 8}px`,
            display: 'flex',
            alignItems: 'center',
            gap: '6px',
            paddingTop: '4px',
            paddingBottom: '4px',
            paddingRight: '8px',
            cursor: 'pointer',
            borderRadius: '4px',
            fontSize: isSymbol ? '12px' : '13px',
            transition: 'background-color 0.15s ease',
            backgroundColor: isSelected
              ? 'rgba(37, 99, 235, 0.08)'
              : isMatch
              ? 'rgba(254, 240, 138, 0.3)'
              : 'transparent',
            borderLeft: isSelected ? '3px solid var(--color-primary)' : '3px solid transparent',
          }}
          onClick={() => handleSelectNode(node)}
        >
          {/* Expand/Collapse Chevron */}
          {hasChildren ? (
            <button
              type="button"
              className="tree-chevron-btn"
              style={{
                background: 'none',
                border: 'none',
                cursor: 'pointer',
                padding: '0 2px',
                color: 'var(--color-text-muted)',
                fontSize: '10px',
                display: 'inline-flex',
                alignItems: 'center',
                justifyContent: 'center',
                width: '14px',
                height: '14px',
              }}
              onClick={(e) => toggleExpand(node.id, e)}
            >
              {isExpanded ? '▼' : '▶'}
            </button>
          ) : (
            <span style={{ width: '14px', display: 'inline-block' }} />
          )}

          {/* Node Icon */}
          <span style={{ fontSize: '14px', display: 'inline-flex', alignItems: 'center' }}>
            {isRepo && '📦'}
            {isDir && (isExpanded ? '📂' : '📁')}
            {isFile && '📄'}
            {isSymbol && (node.symbol_type === 'class' ? '🔷' : '🔹')}
          </span>

          {/* Node Name */}
          <span
            className={`tree-node-name ${isSymbol ? 'font-mono' : ''}`}
            style={{
              fontWeight: isDir || isRepo ? 600 : isFile ? 500 : 400,
              color: isSelected
                ? 'var(--color-primary)'
                : isSymbol
                ? 'var(--color-text-muted)'
                : 'var(--color-text)',
              whiteSpace: 'nowrap',
              overflow: 'hidden',
              textOverflow: 'ellipsis',
              flex: 1,
            }}
          >
            {node.name}
            {isSymbol && node.line_start ? (
              <span style={{ fontSize: '10px', color: '#94a3b8', marginLeft: '6px' }}>
                L{node.line_start}
              </span>
            ) : null}
          </span>

          {/* Right Badges */}
          {isDir && (
            <span
              className="badge"
              style={{
                fontSize: '10px',
                padding: '1px 5px',
                backgroundColor: 'var(--color-bg-secondary)',
                color: 'var(--color-text-muted)',
              }}
            >
              {node.file_count} files
            </span>
          )}

          {isFile && node.language && (
            <span
              className="badge font-mono"
              style={{
                fontSize: '10px',
                padding: '1px 5px',
                backgroundColor: 'var(--color-bg-secondary)',
                color: 'var(--color-text-muted)',
              }}
            >
              {node.language}
            </span>
          )}

          {isFile && layerStyle && (
            <span
              className="badge"
              style={{
                fontSize: '9px',
                padding: '1px 5px',
                backgroundColor: layerStyle.bg,
                color: layerStyle.color,
                border: `1px solid ${layerStyle.border}`,
              }}
            >
              {node.layer}
            </span>
          )}

          {isFile && node.relationship_count > 0 && (
            <span
              className="badge"
              title={`${node.relationship_count} relationships`}
              style={{
                fontSize: '10px',
                padding: '1px 4px',
                backgroundColor: '#eff6ff',
                color: '#1d4ed8',
              }}
            >
              🔗 {node.relationship_count}
            </span>
          )}

          {isSymbol && node.relationship_count > 0 && (
            <span
              className="badge"
              title={`${node.relationship_count} relationships`}
              style={{
                fontSize: '9px',
                padding: '0 4px',
                backgroundColor: '#f1f5f9',
                color: '#475569',
              }}
            >
              {node.relationship_count}
            </span>
          )}
        </div>

        {/* Child Nodes */}
        {hasChildren && isExpanded && (
          <div className="tree-node-children">
            {node.children.map((child) => renderTreeNode(child, depth + 1))}
          </div>
        )}
      </div>
    );
  };

  return (
    <div className="repository-tree-viewer">
      {/* 1. Header Toolbar */}
      <div
        className="card mb-16 p-16"
        style={{
          display: 'flex',
          justifyContent: 'space-between',
          alignItems: 'center',
          flexWrap: 'wrap',
          gap: '12px',
        }}
      >
        <div className="flex-row items-center" style={{ gap: '12px' }}>
          <div>
            <h3 className="font-bold text-base m-0 flex-row items-center" style={{ gap: '8px' }}>
              <span>📦</span> {treeData.repository_name}
              <span className="text-xs text-muted font-normal">Hierarchy & Symbol Tree</span>
            </h3>
            <div className="flex-row items-center mt-4" style={{ gap: '8px' }}>
              <span className="badge" style={{ backgroundColor: '#eff6ff', color: '#1d4ed8', fontSize: '11px' }}>
                📄 {treeData.total_files} Files
              </span>
              <span className="badge" style={{ backgroundColor: '#ecfdf5', color: '#047857', fontSize: '11px' }}>
                🔷 {treeData.total_symbols} Symbols
              </span>
              <span className="badge" style={{ backgroundColor: '#f5f3ff', color: '#6d28d9', fontSize: '11px' }}>
                🔗 {treeData.total_relationships} Relationships
              </span>
            </div>
          </div>
        </div>

        <div className="flex-row items-center" style={{ gap: '8px' }}>
          {/* Quick Search */}
          <div style={{ position: 'relative', width: '280px' }}>
            <input
              type="text"
              className="input input-sm"
              placeholder="Search files, folders, or symbols..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
              style={{ width: '100%', paddingRight: searchQuery ? '24px' : '8px' }}
            />
            {searchQuery && (
              <button
                type="button"
                style={{
                  position: 'absolute',
                  right: '6px',
                  top: '50%',
                  transform: 'translateY(-50%)',
                  background: 'none',
                  border: 'none',
                  cursor: 'pointer',
                  color: 'var(--color-text-muted)',
                }}
                onClick={() => setSearchQuery('')}
              >
                ✕
              </button>
            )}
          </div>

          <button className="btn btn-secondary btn-sm" onClick={expandAll} title="Expand all folders">
            Expand All
          </button>
          <button className="btn btn-secondary btn-sm" onClick={collapseAll} title="Collapse all folders">
            Collapse All
          </button>

          <label
            className="flex-row items-center text-xs text-muted"
            style={{ cursor: 'pointer', userSelect: 'none', gap: '4px', marginLeft: '4px' }}
          >
            <input
              type="checkbox"
              checked={showSymbolsInTree}
              onChange={(e) => setShowSymbolsInTree(e.target.checked)}
            />
            Symbols
          </label>
        </div>
      </div>

      {/* Search results banner if searching */}
      {searchQuery.trim() && (
        <div
          className="mb-12 p-8 text-xs flex-row justify-between items-center"
          style={{
            backgroundColor: '#fefce8',
            border: '1px solid #fef08a',
            borderRadius: '6px',
            color: '#854d0e',
          }}
        >
          <span>
            Found <strong>{searchMatches.length}</strong> matching item(s) for "<strong>{searchQuery}</strong>"
          </span>
          <button
            className="btn btn-secondary btn-sm"
            style={{ fontSize: '11px', padding: '2px 8px' }}
            onClick={() => setSearchQuery('')}
          >
            Clear Search
          </button>
        </div>
      )}

      {/* 2. Main Two-Panel Layout */}
      <div
        className="tree-layout-grid"
        style={{
          display: 'grid',
          gridTemplateColumns: 'minmax(320px, 420px) 1fr',
          gap: '16px',
          alignItems: 'start',
        }}
      >
        {/* Left Tree Explorer Panel */}
        <div
          className="card p-12 tree-navigation-card"
          style={{
            maxHeight: 'calc(100vh - 240px)',
            minHeight: '520px',
            overflowY: 'auto',
            border: '1px solid var(--color-border)',
          }}
        >
          <div className="flex-row justify-between items-center mb-8 pb-8 border-b">
            <span className="text-xs font-bold text-muted uppercase">Repository Structure</span>
            <span className="text-xs text-muted">{expandedIds.size} open</span>
          </div>

          <div className="tree-root-container">
            {renderTreeNode(treeData.root, 0)}
          </div>
        </div>

        {/* Right Detail & Relationship Inspector Panel */}
        <div
          className="card p-20 tree-detail-card"
          style={{
            minHeight: '520px',
            maxHeight: 'calc(100vh - 240px)',
            overflowY: 'auto',
            border: '1px solid var(--color-border)',
          }}
        >
          {selectedNode ? (
            <div>
              {/* Detail Header */}
              <div
                className="pb-16 mb-16 border-b"
                style={{
                  display: 'flex',
                  justifyContent: 'space-between',
                  alignItems: 'flex-start',
                  gap: '16px',
                }}
              >
                <div>
                  {/* Breadcrumb Path */}
                  <div className="text-xs text-muted font-mono mb-6" style={{ wordBreak: 'break-all' }}>
                    {selectedNode.path || selectedNode.name}
                  </div>

                  <h3 className="font-bold text-lg m-0 flex-row items-center" style={{ gap: '8px' }}>
                    <span>
                      {selectedNode.node_type === 'repository' && '📦'}
                      {selectedNode.node_type === 'directory' && '📁'}
                      {selectedNode.node_type === 'file' && '📄'}
                      {selectedNode.node_type === 'symbol' && (selectedNode.symbol_type === 'class' ? '🔷' : '🔹')}
                    </span>
                    <span>{selectedNode.name}</span>
                  </h3>

                  <div className="flex-row items-center mt-8" style={{ gap: '8px', flexWrap: 'wrap' }}>
                    <span
                      className="badge font-bold uppercase"
                      style={{
                        fontSize: '11px',
                        backgroundColor: 'var(--color-bg-secondary)',
                        color: 'var(--color-text)',
                      }}
                    >
                      {selectedNode.node_type}
                    </span>

                    {selectedNode.symbol_type && (
                      <span className="badge" style={{ backgroundColor: '#eff6ff', color: '#1e40af', fontSize: '11px' }}>
                        {selectedNode.symbol_type}
                      </span>
                    )}

                    {selectedNode.language && (
                      <span className="badge font-mono" style={{ fontSize: '11px', backgroundColor: '#f1f5f9', color: '#334155' }}>
                        {selectedNode.language}
                      </span>
                    )}

                    {selectedNode.layer && LAYER_COLORS[selectedNode.layer] && (
                      <span
                        className="badge"
                        style={{
                          fontSize: '11px',
                          backgroundColor: LAYER_COLORS[selectedNode.layer].bg,
                          color: LAYER_COLORS[selectedNode.layer].color,
                          border: `1px solid ${LAYER_COLORS[selectedNode.layer].border}`,
                        }}
                      >
                        {selectedNode.layer}
                      </span>
                    )}

                    {selectedNode.line_count !== undefined && selectedNode.line_count > 0 && (
                      <span className="text-xs text-muted">{selectedNode.line_count} lines</span>
                    )}
                    {selectedNode.size_bytes !== undefined && selectedNode.size_bytes > 0 && (
                      <span className="text-xs text-muted">
                        {(selectedNode.size_bytes / 1024).toFixed(1)} KB
                      </span>
                    )}
                  </div>
                </div>

                {/* Quick Feature Launcher */}
                {onNavigateToFeature && selectedNode.node_type !== 'repository' && (
                  <div className="flex-row" style={{ gap: '6px' }}>
                    <button
                      className="btn btn-secondary btn-sm"
                      style={{ fontSize: '11px', padding: '4px 8px' }}
                      title="Analyze Impact for this component"
                      onClick={() => onNavigateToFeature('impact')}
                    >
                      💥 Impact Radar
                    </button>
                    <button
                      className="btn btn-secondary btn-sm"
                      style={{ fontSize: '11px', padding: '4px 8px' }}
                      title="Trace feature with this component"
                      onClick={() => onNavigateToFeature('tracer')}
                    >
                      🎯 Feature Tracer
                    </button>
                  </div>
                )}
              </div>

              {/* Detail Metrics Strip */}
              <div
                className="grid-4 mb-16"
                style={{
                  display: 'grid',
                  gridTemplateColumns: 'repeat(auto-fit, minmax(110px, 1fr))',
                  gap: '8px',
                }}
              >
                {selectedNode.node_type === 'directory' || selectedNode.node_type === 'repository' ? (
                  <div className="metric-chip p-8" style={{ backgroundColor: 'var(--color-bg-secondary)', borderRadius: '6px' }}>
                    <div className="text-xs text-muted">Files</div>
                    <div className="font-bold text-base">{selectedNode.file_count}</div>
                  </div>
                ) : null}

                <div className="metric-chip p-8" style={{ backgroundColor: 'var(--color-bg-secondary)', borderRadius: '6px' }}>
                  <div className="text-xs text-muted">Symbols</div>
                  <div className="font-bold text-base">{selectedNode.symbol_count}</div>
                </div>

                <div className="metric-chip p-8" style={{ backgroundColor: 'var(--color-bg-secondary)', borderRadius: '6px' }}>
                  <div className="text-xs text-muted">Incoming Conns</div>
                  <div className="font-bold text-base text-success">
                    {selectedNode.incoming_relationships.length}
                  </div>
                </div>

                <div className="metric-chip p-8" style={{ backgroundColor: 'var(--color-bg-secondary)', borderRadius: '6px' }}>
                  <div className="text-xs text-muted">Outgoing Conns</div>
                  <div className="font-bold text-base text-primary">
                    {selectedNode.outgoing_relationships.length}
                  </div>
                </div>
              </div>

              {/* Detail Tabs */}
              <div className="tabs-nav mb-16 border-b flex-row" style={{ gap: '8px' }}>
                <button
                  className={`tab-btn ${detailTab === 'relationships' ? 'active' : ''}`}
                  onClick={() => setDetailTab('relationships')}
                  style={{
                    padding: '6px 12px',
                    fontSize: '12px',
                    fontWeight: 600,
                    borderBottom: detailTab === 'relationships' ? '2px solid var(--color-primary)' : '2px solid transparent',
                    color: detailTab === 'relationships' ? 'var(--color-primary)' : 'var(--color-text-muted)',
                    background: 'none',
                    borderTop: 'none',
                    borderLeft: 'none',
                    borderRight: 'none',
                    cursor: 'pointer',
                  }}
                >
                  🔗 Relationships ({selectedNode.relationship_count})
                </button>

                <button
                  className={`tab-btn ${detailTab === 'graph' ? 'active' : ''}`}
                  onClick={() => setDetailTab('graph')}
                  style={{
                    padding: '6px 12px',
                    fontSize: '12px',
                    fontWeight: 600,
                    borderBottom: detailTab === 'graph' ? '2px solid var(--color-primary)' : '2px solid transparent',
                    color: detailTab === 'graph' ? 'var(--color-primary)' : 'var(--color-text-muted)',
                    background: 'none',
                    borderTop: 'none',
                    borderLeft: 'none',
                    borderRight: 'none',
                    cursor: 'pointer',
                  }}
                >
                  🕸️ Visual Connection Flow
                </button>

                {selectedNode.children.length > 0 && (
                  <button
                    className={`tab-btn ${detailTab === 'symbols' ? 'active' : ''}`}
                    onClick={() => setDetailTab('symbols')}
                    style={{
                      padding: '6px 12px',
                      fontSize: '12px',
                      fontWeight: 600,
                      borderBottom: detailTab === 'symbols' ? '2px solid var(--color-primary)' : '2px solid transparent',
                      color: detailTab === 'symbols' ? 'var(--color-primary)' : 'var(--color-text-muted)',
                      background: 'none',
                      borderTop: 'none',
                      borderLeft: 'none',
                      borderRight: 'none',
                      cursor: 'pointer',
                    }}
                  >
                    🔷 Declared Symbols ({selectedNode.children.length})
                  </button>
                )}

                {selectedNode.imports && selectedNode.imports.length > 0 && (
                  <button
                    className={`tab-btn ${detailTab === 'imports' ? 'active' : ''}`}
                    onClick={() => setDetailTab('imports')}
                    style={{
                      padding: '6px 12px',
                      fontSize: '12px',
                      fontWeight: 600,
                      borderBottom: detailTab === 'imports' ? '2px solid var(--color-primary)' : '2px solid transparent',
                      color: detailTab === 'imports' ? 'var(--color-primary)' : 'var(--color-text-muted)',
                      background: 'none',
                      borderTop: 'none',
                      borderLeft: 'none',
                      borderRight: 'none',
                      cursor: 'pointer',
                    }}
                  >
                    📦 Imports ({selectedNode.imports.length})
                  </button>
                )}
              </div>

              {/* TAB 1: RELATIONSHIPS LIST */}
              {detailTab === 'relationships' && (
                <div>
                  {selectedNode.relationship_count === 0 ? (
                    <div className="p-16 text-center text-muted text-sm" style={{ backgroundColor: 'var(--color-bg-secondary)', borderRadius: '6px' }}>
                      No direct relationships indexed for this item.
                    </div>
                  ) : (
                    <div className="relationships-split" style={{ display: 'grid', gridTemplateColumns: '1fr 1fr', gap: '16px' }}>
                      {/* Incoming Callers */}
                      <div>
                        <h4 className="font-bold text-xs text-muted uppercase mb-8 flex-row items-center" style={{ gap: '6px' }}>
                          <span>↙️ Incoming Consumers</span>
                          <span className="badge" style={{ backgroundColor: '#eff6ff', color: '#1d4ed8', fontSize: '10px' }}>
                            {selectedNode.incoming_relationships.length}
                          </span>
                        </h4>

                        {selectedNode.incoming_relationships.length === 0 ? (
                          <div className="text-xs text-muted p-12 border rounded">No incoming consumers.</div>
                        ) : (
                          <div className="flex-col" style={{ gap: '8px', maxHeight: '360px', overflowY: 'auto' }}>
                            {selectedNode.incoming_relationships.map((rel, idx) => {
                              const relBadge = REL_TYPE_COLORS[rel.relationship_type] || { bg: '#f1f5f9', color: '#334155' };
                              return (
                                <div
                                  key={idx}
                                  className="p-10 border rounded hover-card"
                                  style={{ backgroundColor: '#ffffff', cursor: 'pointer', fontSize: '12px' }}
                                  onClick={() => handleJumpToTarget(rel)}
                                >
                                  <div className="flex-row justify-between items-center mb-4">
                                    <span
                                      className="badge font-mono font-bold"
                                      style={{ backgroundColor: relBadge.bg, color: relBadge.color, fontSize: '9px' }}
                                    >
                                      {rel.relationship_type}
                                    </span>
                                    {rel.target_layer && (
                                      <span className="text-xs text-muted" style={{ fontSize: '10px' }}>
                                        {rel.target_layer}
                                      </span>
                                    )}
                                  </div>

                                  <div className="font-bold text-xs" style={{ color: 'var(--color-primary)' }}>
                                    {rel.target_label}
                                  </div>

                                  {rel.target_file && (
                                    <div className="text-xs text-muted font-mono mt-2" style={{ fontSize: '11px' }}>
                                      {rel.target_file}
                                    </div>
                                  )}

                                  {rel.evidence && rel.evidence.length > 0 && rel.evidence[0].snippet && (
                                    <div
                                      className="font-mono text-xs mt-4 p-4 rounded"
                                      style={{
                                        backgroundColor: 'var(--color-bg-secondary)',
                                        fontSize: '10px',
                                        color: '#334155',
                                        whiteSpace: 'nowrap',
                                        overflow: 'hidden',
                                        textOverflow: 'ellipsis',
                                      }}
                                    >
                                      {rel.evidence[0].snippet}
                                    </div>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>

                      {/* Outgoing Dependencies */}
                      <div>
                        <h4 className="font-bold text-xs text-muted uppercase mb-8 flex-row items-center" style={{ gap: '6px' }}>
                          <span>↗️ Outgoing Dependencies</span>
                          <span className="badge" style={{ backgroundColor: '#ecfdf5', color: '#047857', fontSize: '10px' }}>
                            {selectedNode.outgoing_relationships.length}
                          </span>
                        </h4>

                        {selectedNode.outgoing_relationships.length === 0 ? (
                          <div className="text-xs text-muted p-12 border rounded">No outgoing dependencies.</div>
                        ) : (
                          <div className="flex-col" style={{ gap: '8px', maxHeight: '360px', overflowY: 'auto' }}>
                            {selectedNode.outgoing_relationships.map((rel, idx) => {
                              const relBadge = REL_TYPE_COLORS[rel.relationship_type] || { bg: '#f1f5f9', color: '#334155' };
                              return (
                                <div
                                  key={idx}
                                  className="p-10 border rounded hover-card"
                                  style={{ backgroundColor: '#ffffff', cursor: 'pointer', fontSize: '12px' }}
                                  onClick={() => handleJumpToTarget(rel)}
                                >
                                  <div className="flex-row justify-between items-center mb-4">
                                    <span
                                      className="badge font-mono font-bold"
                                      style={{ backgroundColor: relBadge.bg, color: relBadge.color, fontSize: '9px' }}
                                    >
                                      {rel.relationship_type}
                                    </span>
                                    {rel.target_layer && (
                                      <span className="text-xs text-muted" style={{ fontSize: '10px' }}>
                                        {rel.target_layer}
                                      </span>
                                    )}
                                  </div>

                                  <div className="font-bold text-xs" style={{ color: 'var(--color-primary)' }}>
                                    {rel.target_label}
                                  </div>

                                  {rel.target_file && (
                                    <div className="text-xs text-muted font-mono mt-2" style={{ fontSize: '11px' }}>
                                      {rel.target_file}
                                    </div>
                                  )}

                                  {rel.evidence && rel.evidence.length > 0 && rel.evidence[0].snippet && (
                                    <div
                                      className="font-mono text-xs mt-4 p-4 rounded"
                                      style={{
                                        backgroundColor: 'var(--color-bg-secondary)',
                                        fontSize: '10px',
                                        color: '#334155',
                                        whiteSpace: 'nowrap',
                                        overflow: 'hidden',
                                        textOverflow: 'ellipsis',
                                      }}
                                    >
                                      {rel.evidence[0].snippet}
                                    </div>
                                  )}
                                </div>
                              );
                            })}
                          </div>
                        )}
                      </div>
                    </div>
                  )}
                </div>
              )}

              {/* TAB 2: VISUAL CONNECTION FLOW */}
              {detailTab === 'graph' && (
                <div className="p-16 border rounded" style={{ backgroundColor: 'var(--color-bg-secondary)' }}>
                  <div className="text-xs text-muted mb-12">
                    Interactive connection flow centered on <strong>{selectedNode.name}</strong>. Click any node to navigate.
                  </div>

                  <div
                    style={{
                      display: 'flex',
                      alignItems: 'center',
                      justifyContent: 'space-between',
                      gap: '16px',
                    }}
                  >
                    {/* Inbound column */}
                    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <div className="text-xs font-bold text-muted uppercase text-center mb-4">
                        Inbound Callers ({selectedNode.incoming_relationships.length})
                      </div>
                      {selectedNode.incoming_relationships.length === 0 ? (
                        <div className="text-xs text-muted text-center p-8 border rounded" style={{ backgroundColor: '#ffffff' }}>
                          None
                        </div>
                      ) : (
                        selectedNode.incoming_relationships.slice(0, 6).map((r, i) => (
                          <div
                            key={i}
                            className="p-8 border rounded hover-card text-center"
                            style={{ backgroundColor: '#ffffff', cursor: 'pointer' }}
                            onClick={() => handleJumpToTarget(r)}
                          >
                            <span className="font-bold text-xs font-mono" style={{ color: 'var(--color-primary)' }}>
                              {r.target_label}
                            </span>
                            <div className="text-xs text-muted" style={{ fontSize: '10px' }}>
                              {r.relationship_type} ➔
                            </div>
                          </div>
                        ))
                      )}
                      {selectedNode.incoming_relationships.length > 6 && (
                        <div className="text-xs text-muted text-center">
                          +{selectedNode.incoming_relationships.length - 6} more
                        </div>
                      )}
                    </div>

                    {/* Center Node */}
                    <div
                      style={{
                        padding: '16px',
                        backgroundColor: '#ffffff',
                        border: '2px solid var(--color-primary)',
                        borderRadius: '8px',
                        textAlign: 'center',
                        minWidth: '160px',
                        boxShadow: '0 4px 12px rgba(37, 99, 235, 0.1)',
                      }}
                    >
                      <div className="text-xs uppercase font-bold text-primary mb-2">Selected Item</div>
                      <div className="font-bold text-sm">{selectedNode.name}</div>
                      {selectedNode.layer && (
                        <div className="badge mt-4" style={{ fontSize: '10px', backgroundColor: '#eff6ff', color: '#1d4ed8' }}>
                          {selectedNode.layer}
                        </div>
                      )}
                    </div>

                    {/* Outbound column */}
                    <div style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: '8px' }}>
                      <div className="text-xs font-bold text-muted uppercase text-center mb-4">
                        Outbound Dependencies ({selectedNode.outgoing_relationships.length})
                      </div>
                      {selectedNode.outgoing_relationships.length === 0 ? (
                        <div className="text-xs text-muted text-center p-8 border rounded" style={{ backgroundColor: '#ffffff' }}>
                          None
                        </div>
                      ) : (
                        selectedNode.outgoing_relationships.slice(0, 6).map((r, i) => (
                          <div
                            key={i}
                            className="p-8 border rounded hover-card text-center"
                            style={{ backgroundColor: '#ffffff', cursor: 'pointer' }}
                            onClick={() => handleJumpToTarget(r)}
                          >
                            <div className="text-xs text-muted" style={{ fontSize: '10px' }}>
                              ➔ {r.relationship_type}
                            </div>
                            <span className="font-bold text-xs font-mono" style={{ color: 'var(--color-primary)' }}>
                              {r.target_label}
                            </span>
                          </div>
                        ))
                      )}
                      {selectedNode.outgoing_relationships.length > 6 && (
                        <div className="text-xs text-muted text-center">
                          +{selectedNode.outgoing_relationships.length - 6} more
                        </div>
                      )}
                    </div>
                  </div>
                </div>
              )}

              {/* TAB 3: DECLARED SYMBOLS LIST */}
              {detailTab === 'symbols' && selectedNode.children.length > 0 && (
                <div className="flex-col" style={{ gap: '8px' }}>
                  {selectedNode.children.map((child, idx) => (
                    <div
                      key={idx}
                      className="p-10 border rounded hover-card flex-row justify-between items-center"
                      style={{ backgroundColor: '#ffffff', cursor: 'pointer' }}
                      onClick={() => handleSelectNode(child)}
                    >
                      <div className="flex-row items-center" style={{ gap: '8px' }}>
                        <span>{child.symbol_type === 'class' ? '🔷' : '🔹'}</span>
                        <div>
                          <span className="font-bold font-mono text-sm" style={{ color: 'var(--color-text)' }}>
                            {child.name}
                          </span>
                          {child.docstring && (
                            <div className="text-xs text-muted mt-2" style={{ fontStyle: 'italic' }}>
                              {child.docstring}
                            </div>
                          )}
                        </div>
                      </div>

                      <div className="flex-row items-center" style={{ gap: '8px' }}>
                        {child.line_start && (
                          <span className="text-xs text-muted font-mono">
                            L{child.line_start}–{child.line_end}
                          </span>
                        )}
                        <span className="badge" style={{ fontSize: '10px', backgroundColor: '#f1f5f9', color: '#475569' }}>
                          🔗 {child.relationship_count}
                        </span>
                      </div>
                    </div>
                  ))}
                </div>
              )}

              {/* TAB 4: IMPORTS */}
              {detailTab === 'imports' && selectedNode.imports && (
                <div className="p-12 border rounded" style={{ backgroundColor: '#ffffff' }}>
                  <div className="text-xs font-bold text-muted uppercase mb-8">Imported Modules</div>
                  <div className="flex-col" style={{ gap: '4px' }}>
                    {selectedNode.imports.map((imp, idx) => (
                      <div key={idx} className="font-mono text-xs p-4 rounded" style={{ backgroundColor: 'var(--color-bg-secondary)' }}>
                        import {imp}
                      </div>
                    ))}
                  </div>
                </div>
              )}
            </div>
          ) : (
            <div className="text-center text-muted p-40">
              <div style={{ fontSize: '32px', marginBottom: '8px' }}>📂</div>
              <h4 className="font-bold mb-4">No Item Selected</h4>
              <p className="text-xs">Click any folder, file, or symbol in the left tree to inspect its metadata and relationships.</p>
            </div>
          )}
        </div>
      </div>
    </div>
  );
}
