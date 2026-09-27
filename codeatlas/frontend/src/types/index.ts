// CodeAtlas — TypeScript type definitions

export type RepositoryStatus = 'uploaded' | 'scanning' | 'indexed' | 'error';
export type Confidence = 'CONFIRMED' | 'INFERRED' | 'UNKNOWN';
export type SymbolType = 'class' | 'function' | 'method' | 'variable' | 'constant' |
  'interface' | 'enum' | 'decorator' | 'module' | 'unknown';
export type RelationshipType = 'imports' | 'calls' | 'references' | 'extends' |
  'implements' | 'creates' | 'reads' | 'writes' | 'routes_to' | 'tests' | 'depends_on' | 'defines';

export interface Repository {
  id: string;
  name: string;
  status: RepositoryStatus;
  total_files: number;
  source_files: number;
  languages: Record<string, number>;
  entry_points: string[];
  test_files_count: number;
  dependency_files: string[];
  symbol_count: number;
  relationship_count: number;
  error?: string;
  files?: FileSummary[];
}

export interface FileSummary {
  path: string;
  language: string;
  size_bytes: number;
  line_count: number;
  is_entry_point: boolean;
  is_test: boolean;
  is_config: boolean;
  symbol_count: number;
  import_count: number;
}

export interface FileDetail {
  path: string;
  language: string;
  size_bytes: number;
  line_count: number;
  is_entry_point: boolean;
  is_test: boolean;
  symbols: SymbolRecord[];
  imports: ImportRecord[];
  content: string | null;
}

export interface SymbolRecord {
  id: string;
  name: string;
  qualified_name: string;
  symbol_type: SymbolType;
  file: string;
  line_start: number;
  line_end: number;
  docstring?: string;
}

export interface ImportRecord {
  file: string;
  imported_module: string;
  imported_names: string[];
  line: number;
  raw: string;
}

export interface Evidence {
  file: string;
  line_start?: number;
  line_end?: number;
  snippet?: string;
  description: string;
}

export interface TraceNode {
  id: string;
  file: string;
  symbol?: string;
  symbol_id?: string;
  symbol_type?: SymbolType;
  role: string;
  line_start?: number;
  line_end?: number;
  confidence: Confidence;
  evidence: Evidence[];
}

export interface TraceEdge {
  source_id: string;
  target_id: string;
  relationship_type: RelationshipType;
  label: string;
  evidence: Evidence[];
  confidence: Confidence;
}

export interface FeatureTrace {
  query: string;
  summary: string;
  entry_points: TraceNode[];
  nodes: TraceNode[];
  edges: TraceEdge[];
  confirmed: string[];
  inferred: string[];
  unknowns: string[];
  total_nodes: number;
  total_edges: number;
}

export interface UploadResponse {
  id: string;
  name: string;
  status: string;
  message: string;
}

export type ImpactType = 'DIRECT' | 'INDIRECT' | 'DATA' | 'UI' | 'TEST' | 'CONFIGURATION' | 'API' | 'UNKNOWN';

export interface ImpactNode {
  id: string;
  file: string;
  symbol?: string;
  symbol_id?: string;
  symbol_type?: SymbolType;
  impact_type: ImpactType;
  relationship?: RelationshipType;
  distance: number;
  confidence: Confidence;
  reason: string;
  evidence: Evidence[];
}

export interface ImpactSummary {
  target_id: string;
  target_name: string;
  total_impacted: number;
  direct_count: number;
  indirect_count: number;
  data_count: number;
  ui_count: number;
  test_count: number;
  unknown_count: number;
  max_distance: number;
  description: string;
}

export interface ImpactAnalysis {
  target: ImpactNode;
  direct_impacts: ImpactNode[];
  indirect_impacts: ImpactNode[];
  data_impacts: ImpactNode[];
  ui_impacts: ImpactNode[];
  test_impacts: ImpactNode[];
  unknowns: string[];
  evidence: Evidence[];
  confidence: Confidence;
  summary: ImpactSummary;
  nodes: ImpactNode[];
  edges: TraceEdge[];
}

export type RiskSeverity = 'HIGH' | 'MEDIUM' | 'LOW' | 'UNKNOWN';

export type RiskCategory =
  | 'BUSINESS_LOGIC'
  | 'DATA'
  | 'API'
  | 'UI'
  | 'STATE'
  | 'EDGE_CASE'
  | 'TEST_COVERAGE'
  | 'DEPENDENCY'
  | 'CONFIGURATION'
  | 'UNKNOWN';

export interface RegressionRisk {
  id: string;
  severity: RiskSeverity;
  category: RiskCategory;
  title: string;
  description: string;
  source: string;
  related_component?: string;
  confidence: Confidence;
  evidence: Evidence[];
  suggested_test: string;
}

export interface ChangedLineHunk {
  old_start: number;
  old_lines: number;
  new_start: number;
  new_lines: number;
  added_lines: string[];
  removed_lines: string[];
}

export interface ChangedFile {
  file: string;
  status: string;
  added_count: number;
  removed_count: number;
  changed_line_ranges: [number, number][];
  hunks: ChangedLineHunk[];
  changed_symbols: string[];
}

export interface RegressionSummary {
  changed_files_count: number;
  changed_symbols_count: number;
  affected_components_count: number;
  risks_count: number;
  high_risk_count: number;
  medium_risk_count: number;
  low_risk_count: number;
  tests_count: number;
  description: string;
}

export interface RegressionAnalysis {
  query?: string;
  changed_files: ChangedFile[];
  changed_symbols: ImpactNode[];
  affected_components: ImpactNode[];
  risks: RegressionRisk[];
  related_tests: ImpactNode[];
  evidence: Evidence[];
  unknowns: string[];
  confidence: Confidence;
  summary: RegressionSummary;
  nodes: ImpactNode[];
  edges: TraceEdge[];
}

// ---------------------------------------------------------------------------
// Repository Intelligence / Project Overview Types
// ---------------------------------------------------------------------------

export interface ApiEndpoint {
  method: string;
  path: string;
  handler: string;
  file: string;
  line_start: number;
  line_end: number;
  docstring?: string;
  evidence: Evidence[];
}

export interface StorageTechnology {
  technology: string;
  category: string;
  confidence: Confidence;
  files: string[];
  entities: string[];
  evidence: Evidence[];
  description: string;
}

export interface RepositoryModule {
  name: string;
  path: string;
  role: string;
  file_count: number;
  symbol_count: number;
  files: string[];
  symbols: string[];
  dependencies: string[];
  incoming_count: number;
  outgoing_count: number;
}

export interface ArchitectureLayer {
  name: string;
  role: string;
  file_count: number;
  symbol_count: number;
  files: string[];
  symbols: string[];
}

export interface ArchitectureGraphNode {
  id: string;
  label: string;
  layer: string;
  file_count: number;
  symbol_count: number;
  files: string[];
  symbols: string[];
}

export interface ArchitectureGraphEdge {
  source_id: string;
  target_id: string;
  label: string;
  count: number;
  relationship_types: string[];
  evidence: Evidence[];
}

export interface ArchitectureGraph {
  nodes: ArchitectureGraphNode[];
  edges: ArchitectureGraphEdge[];
}

export interface ProjectIntelligence {
  repository_id: string;
  repository_name: string;
  total_files: number;
  source_files: number;
  total_symbols: number;
  total_relationships: number;
  languages: Record<string, number>;
  entry_points: string[];
  detected_frameworks: string[];
  layers: ArchitectureLayer[];
  modules: RepositoryModule[];
  api_endpoints: ApiEndpoint[];
  storage_technologies: StorageTechnology[];
  architecture_graph: ArchitectureGraph;
  summary_description: string;
}

export interface RecentAnalysisItem {
  id: string;
  type: 'trace' | 'impact' | 'regression';
  targetOrQuery: string;
  timestamp: number;
  countSummary: string;
  detail?: string;
}

// ---------------------------------------------------------------------------
// Visual Repository Tree Types
// ---------------------------------------------------------------------------

export type TreeNodeType = 'repository' | 'directory' | 'file' | 'symbol';

export interface RelationshipRef {
  id: string;
  source_id: string;
  target_id: string;
  relationship_type: string;
  direction: 'incoming' | 'outgoing';
  target_label: string;
  target_file?: string;
  target_layer?: string;
  confidence: Confidence;
  evidence: Evidence[];
  description?: string;
}

export interface RepositoryTreeNode {
  id: string;
  name: string;
  path: string;
  node_type: TreeNodeType;
  language?: string;
  size_bytes?: number;
  line_count?: number;
  layer?: string;
  symbol_type?: string;
  line_start?: number;
  line_end?: number;
  docstring?: string;
  file_count: number;
  symbol_count: number;
  relationship_count: number;
  children: RepositoryTreeNode[];
  imports: string[];
  incoming_relationships: RelationshipRef[];
  outgoing_relationships: RelationshipRef[];
}

export interface RepositoryTree {
  repository_id: string;
  repository_name: string;
  total_files: number;
  total_symbols: number;
  total_relationships: number;
  root: RepositoryTreeNode;
}

