"""
CodeAtlas Repository Knowledge Model.

Defines the data structures for representing a scanned repository:
files, symbols, imports, relationships, and metadata.
"""

from __future__ import annotations

from enum import Enum
from typing import Any, Optional
from pydantic import BaseModel, Field


# ---------------------------------------------------------------------------
# Enumerations
# ---------------------------------------------------------------------------

class SymbolType(str, Enum):
    CLASS = "class"
    FUNCTION = "function"
    METHOD = "method"
    VARIABLE = "variable"
    CONSTANT = "constant"
    INTERFACE = "interface"
    ENUM = "enum"
    DECORATOR = "decorator"
    MODULE = "module"
    UNKNOWN = "unknown"


class RelationshipType(str, Enum):
    IMPORTS = "imports"
    CALLS = "calls"
    REFERENCES = "references"
    EXTENDS = "extends"
    IMPLEMENTS = "implements"
    CREATES = "creates"
    READS = "reads"
    WRITES = "writes"
    ROUTES_TO = "routes_to"
    TESTS = "tests"
    DEPENDS_ON = "depends_on"
    DEFINES = "defines"


class Confidence(str, Enum):
    CONFIRMED = "CONFIRMED"
    INFERRED = "INFERRED"
    UNKNOWN = "UNKNOWN"


class RepositoryStatus(str, Enum):
    UPLOADED = "uploaded"
    SCANNING = "scanning"
    INDEXED = "indexed"
    ERROR = "error"


# ---------------------------------------------------------------------------
# Evidence
# ---------------------------------------------------------------------------

class Evidence(BaseModel):
    """Source evidence for a relationship or finding."""
    file: str
    line_start: Optional[int] = None
    line_end: Optional[int] = None
    snippet: Optional[str] = None
    description: str = ""


# ---------------------------------------------------------------------------
# Symbol
# ---------------------------------------------------------------------------

class Symbol(BaseModel):
    """A named entity in source code (class, function, method, etc.)."""
    id: str                            # unique: "file_path::symbol_name"
    name: str
    qualified_name: str                # includes class context if method
    symbol_type: SymbolType
    file: str                          # relative path within repository
    line_start: int
    line_end: int
    docstring: Optional[str] = None
    visibility: str = "public"         # public / private / protected / unknown


# ---------------------------------------------------------------------------
# Import Record
# ---------------------------------------------------------------------------

class ImportRecord(BaseModel):
    """A single import statement extracted from a source file."""
    file: str                          # file containing this import
    imported_module: str               # what is being imported
    imported_names: list[str] = Field(default_factory=list)   # "from X import Y, Z"
    line: int
    raw: str                           # original import text


# ---------------------------------------------------------------------------
# Source File
# ---------------------------------------------------------------------------

class SourceFile(BaseModel):
    """Metadata and contents index for a single repository file."""
    id: str                            # relative path used as ID
    path: str                          # relative path
    language: str
    size_bytes: int
    line_count: int
    is_entry_point: bool = False
    is_test: bool = False
    is_config: bool = False
    symbols: list[Symbol] = Field(default_factory=list)
    imports: list[ImportRecord] = Field(default_factory=list)
    # Raw content stored separately (not in default serialisation for performance)
    _content: Optional[str] = None


# ---------------------------------------------------------------------------
# Relationship
# ---------------------------------------------------------------------------

class Relationship(BaseModel):
    """A directional relationship between two symbols or files."""
    source_id: str                     # symbol.id or file.id
    target_id: str
    relationship_type: RelationshipType
    evidence: list[Evidence] = Field(default_factory=list)
    confidence: Confidence = Confidence.INFERRED
    description: str = ""


# ---------------------------------------------------------------------------
# Repository
# ---------------------------------------------------------------------------

class Repository(BaseModel):
    """Complete knowledge model for a scanned repository."""
    id: str
    name: str
    status: RepositoryStatus = RepositoryStatus.UPLOADED
    root_path: str                     # absolute path on disk (server-side)
    total_files: int = 0
    source_files: int = 0
    languages: dict[str, int] = Field(default_factory=dict)   # lang → file count
    files: dict[str, SourceFile] = Field(default_factory=dict)
    symbols: dict[str, Symbol] = Field(default_factory=dict)
    relationships: list[Relationship] = Field(default_factory=list)
    entry_points: list[str] = Field(default_factory=list)     # symbol IDs
    test_files: list[str] = Field(default_factory=list)       # file paths
    dependency_files: list[str] = Field(default_factory=list) # e.g. pubspec.yaml
    error: Optional[str] = None
    metadata: dict[str, Any] = Field(default_factory=dict)


# ---------------------------------------------------------------------------
# Feature Trace Models
# ---------------------------------------------------------------------------

class TraceNode(BaseModel):
    """A node in the feature trace graph."""
    id: str
    file: str
    symbol: Optional[str] = None       # symbol name (may be None for file-level nodes)
    symbol_id: Optional[str] = None    # full symbol ID
    symbol_type: Optional[SymbolType] = None
    role: str = ""                     # e.g. "Entry Point", "OCR Engine", "Data Layer"
    line_start: Optional[int] = None
    line_end: Optional[int] = None
    confidence: Confidence = Confidence.INFERRED
    evidence: list[Evidence] = Field(default_factory=list)


class TraceEdge(BaseModel):
    """A directed edge in the feature trace graph."""
    source_id: str
    target_id: str
    relationship_type: RelationshipType
    label: str = ""
    evidence: list[Evidence] = Field(default_factory=list)
    confidence: Confidence = Confidence.INFERRED


class FeatureTrace(BaseModel):
    """Result of a Feature Tracer query."""
    query: str
    summary: str
    entry_points: list[TraceNode] = Field(default_factory=list)
    nodes: list[TraceNode] = Field(default_factory=list)
    edges: list[TraceEdge] = Field(default_factory=list)
    confirmed: list[str] = Field(default_factory=list)    # finding descriptions
    inferred: list[str] = Field(default_factory=list)
    unknowns: list[str] = Field(default_factory=list)
    total_nodes: int = 0
    total_edges: int = 0


# ---------------------------------------------------------------------------
# Change Impact Radar Models
# ---------------------------------------------------------------------------

class ImpactType(str, Enum):
    DIRECT = "DIRECT"
    INDIRECT = "INDIRECT"
    DATA = "DATA"
    UI = "UI"
    TEST = "TEST"
    CONFIGURATION = "CONFIGURATION"
    API = "API"
    UNKNOWN = "UNKNOWN"


class ImpactNode(BaseModel):
    """A component impacted by changes to the target."""
    id: str
    file: str
    symbol: Optional[str] = None
    symbol_id: Optional[str] = None
    symbol_type: Optional[SymbolType] = None
    impact_type: ImpactType = ImpactType.DIRECT
    relationship: Optional[RelationshipType] = None
    distance: int = 1
    confidence: Confidence = Confidence.CONFIRMED
    reason: str = ""
    evidence: list[Evidence] = Field(default_factory=list)


class ImpactSummary(BaseModel):
    """Statistical summary of a change impact analysis."""
    target_id: str
    target_name: str
    total_impacted: int = 0
    direct_count: int = 0
    indirect_count: int = 0
    data_count: int = 0
    ui_count: int = 0
    test_count: int = 0
    unknown_count: int = 0
    max_distance: int = 0
    description: str = ""


class ImpactAnalysis(BaseModel):
    """Result of a Change Impact Radar analysis."""
    target: ImpactNode
    direct_impacts: list[ImpactNode] = Field(default_factory=list)
    indirect_impacts: list[ImpactNode] = Field(default_factory=list)
    data_impacts: list[ImpactNode] = Field(default_factory=list)
    ui_impacts: list[ImpactNode] = Field(default_factory=list)
    test_impacts: list[ImpactNode] = Field(default_factory=list)
    unknowns: list[str] = Field(default_factory=list)
    evidence: list[Evidence] = Field(default_factory=list)
    confidence: Confidence = Confidence.CONFIRMED
    summary: ImpactSummary
    nodes: list[ImpactNode] = Field(default_factory=list)
    edges: list[TraceEdge] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Regression Investigator Models
# ---------------------------------------------------------------------------

class RiskSeverity(str, Enum):
    HIGH = "HIGH"
    MEDIUM = "MEDIUM"
    LOW = "LOW"
    UNKNOWN = "UNKNOWN"


class RiskCategory(str, Enum):
    BUSINESS_LOGIC = "BUSINESS_LOGIC"
    DATA = "DATA"
    API = "API"
    UI = "UI"
    STATE = "STATE"
    EDGE_CASE = "EDGE_CASE"
    TEST_COVERAGE = "TEST_COVERAGE"
    DEPENDENCY = "DEPENDENCY"
    CONFIGURATION = "CONFIGURATION"
    UNKNOWN = "UNKNOWN"


class RegressionRisk(BaseModel):
    """A specific potential regression risk discovered from changes and graph evidence."""
    id: str
    severity: RiskSeverity = RiskSeverity.MEDIUM
    category: RiskCategory = RiskCategory.BUSINESS_LOGIC
    title: str
    description: str
    source: str
    related_component: Optional[str] = None
    confidence: Confidence = Confidence.CONFIRMED
    evidence: list[Evidence] = Field(default_factory=list)
    suggested_test: str = ""


class ChangedLineHunk(BaseModel):
    """A hunk in a unified diff."""
    old_start: int = 1
    old_lines: int = 0
    new_start: int = 1
    new_lines: int = 0
    added_lines: list[str] = Field(default_factory=list)
    removed_lines: list[str] = Field(default_factory=list)


class ChangedFile(BaseModel):
    """A file identified as changed in a diff or change set."""
    file: str
    status: str = "modified"  # modified, added, deleted
    added_count: int = 0
    removed_count: int = 0
    changed_line_ranges: list[tuple[int, int]] = Field(default_factory=list)
    hunks: list[ChangedLineHunk] = Field(default_factory=list)
    changed_symbols: list[str] = Field(default_factory=list)


class RegressionSummary(BaseModel):
    """Summary metrics of a regression investigation."""
    changed_files_count: int = 0
    changed_symbols_count: int = 0
    affected_components_count: int = 0
    risks_count: int = 0
    high_risk_count: int = 0
    medium_risk_count: int = 0
    low_risk_count: int = 0
    tests_count: int = 0
    description: str = ""


class RegressionAnalysis(BaseModel):
    """Complete result of a Regression Investigator run."""
    query: Optional[str] = None
    changed_files: list[ChangedFile] = Field(default_factory=list)
    changed_symbols: list[ImpactNode] = Field(default_factory=list)
    affected_components: list[ImpactNode] = Field(default_factory=list)
    risks: list[RegressionRisk] = Field(default_factory=list)
    related_tests: list[ImpactNode] = Field(default_factory=list)
    evidence: list[Evidence] = Field(default_factory=list)
    unknowns: list[str] = Field(default_factory=list)
    confidence: Confidence = Confidence.CONFIRMED
    summary: RegressionSummary
    nodes: list[ImpactNode] = Field(default_factory=list)
    edges: list[TraceEdge] = Field(default_factory=list)


# ---------------------------------------------------------------------------
# Repository Intelligence / Project Overview Models
# ---------------------------------------------------------------------------

class ApiEndpoint(BaseModel):
    """An API route or endpoint detected from repository code."""
    method: str                        # GET, POST, PUT, DELETE, etc.
    path: str                          # URL pattern e.g. "/api/repositories/{id}/impact"
    handler: str                       # Function/method name handling this route
    file: str                          # File containing route declaration
    line_start: int
    line_end: int
    docstring: Optional[str] = None
    evidence: list[Evidence] = Field(default_factory=list)


class StorageTechnology(BaseModel):
    """A data store, database, or storage mechanism detected from evidence."""
    technology: str                    # e.g. "Firebase / Firestore", "SQLite", "PostgreSQL", "MongoDB"
    category: str                      # "Cloud NoSQL", "Relational SQL", "Client Key-Value", "Document DB"
    confidence: Confidence = Confidence.CONFIRMED
    files: list[str] = Field(default_factory=list)
    entities: list[str] = Field(default_factory=list)  # collections / tables / models
    evidence: list[Evidence] = Field(default_factory=list)
    description: str = ""


class RepositoryModule(BaseModel):
    """A logical module or package derived from repository structure."""
    name: str                          # e.g. "services", "screens", "models", "api"
    path: str                          # directory path e.g. "lib/services"
    role: str                          # e.g. "Service Layer", "UI / Screen", etc.
    file_count: int
    symbol_count: int
    files: list[str] = Field(default_factory=list)
    symbols: list[str] = Field(default_factory=list)
    dependencies: list[str] = Field(default_factory=list)
    incoming_count: int = 0
    outgoing_count: int = 0


class ArchitectureLayer(BaseModel):
    """An architectural layer inferred from the codebase."""
    name: str                          # "UI / Screens", "Services", "Models", etc.
    role: str
    file_count: int
    symbol_count: int
    files: list[str] = Field(default_factory=list)
    symbols: list[str] = Field(default_factory=list)


class ArchitectureGraphNode(BaseModel):
    """A node in the high-level architecture map."""
    id: str                            # e.g. "layer::ui", "layer::services"
    label: str                         # "UI / Screens"
    layer: str                         # "UI", "Services", "Models", "Storage", "API", "Integrations", "Tests"
    file_count: int
    symbol_count: int
    files: list[str] = Field(default_factory=list)
    symbols: list[str] = Field(default_factory=list)


class ArchitectureGraphEdge(BaseModel):
    """A directed edge in the high-level architecture map."""
    source_id: str
    target_id: str
    label: str
    count: int
    relationship_types: list[str] = Field(default_factory=list)
    evidence: list[Evidence] = Field(default_factory=list)


class ArchitectureGraph(BaseModel):
    """Dynamic architecture map built from real repository relationships."""
    nodes: list[ArchitectureGraphNode] = Field(default_factory=list)
    edges: list[ArchitectureGraphEdge] = Field(default_factory=list)


class ProjectIntelligence(BaseModel):
    """Complete intelligence and architecture overview for a repository."""
    repository_id: str
    repository_name: str
    total_files: int
    source_files: int
    total_symbols: int
    total_relationships: int
    languages: dict[str, int]
    entry_points: list[str]
    detected_frameworks: list[str] = Field(default_factory=list)
    layers: list[ArchitectureLayer] = Field(default_factory=list)
    modules: list[RepositoryModule] = Field(default_factory=list)
    api_endpoints: list[ApiEndpoint] = Field(default_factory=list)
    storage_technologies: list[StorageTechnology] = Field(default_factory=list)
    architecture_graph: ArchitectureGraph = Field(default_factory=ArchitectureGraph)
    summary_description: str = ""


# ---------------------------------------------------------------------------
# Visual Repository Tree Models
# ---------------------------------------------------------------------------

class TreeNodeType(str, Enum):
    REPOSITORY = "repository"
    DIRECTORY = "directory"
    FILE = "file"
    SYMBOL = "symbol"


class RelationshipRef(BaseModel):
    """A cross-reference relationship connected to a tree node."""
    id: str
    source_id: str
    target_id: str
    relationship_type: str             # "calls", "imports", "reads", "writes", "creates", "extends", etc.
    direction: str                     # "incoming" or "outgoing"
    target_label: str                  # clean display name (e.g. "MedicineService.addMedicine")
    target_file: Optional[str] = None
    target_layer: Optional[str] = None
    confidence: Confidence = Confidence.INFERRED
    evidence: list[Evidence] = Field(default_factory=list)
    description: str = ""


class RepositoryTreeNode(BaseModel):
    """A node in the hierarchical repository tree (directory, file, or symbol)."""
    id: str                            # e.g. "dir::lib/screens", "file::lib/screens/home_screen.dart", "sym::lib/screens/home_screen.dart::HomeScreen"
    name: str                          # e.g. "screens", "home_screen.dart", "HomeScreen"
    path: str                          # relative path e.g. "lib/screens/home_screen.dart"
    node_type: TreeNodeType            # repository, directory, file, symbol
    language: Optional[str] = None
    size_bytes: Optional[int] = None
    line_count: Optional[int] = None
    layer: Optional[str] = None        # "UI / Screens", "Services", "Models", etc.
    symbol_type: Optional[str] = None  # for symbols: "class", "function", "method", "variable"
    line_start: Optional[int] = None
    line_end: Optional[int] = None
    docstring: Optional[str] = None
    file_count: int = 0
    symbol_count: int = 0
    relationship_count: int = 0
    children: list[RepositoryTreeNode] = Field(default_factory=list)
    imports: list[str] = Field(default_factory=list)
    incoming_relationships: list[RelationshipRef] = Field(default_factory=list)
    outgoing_relationships: list[RelationshipRef] = Field(default_factory=list)


class RepositoryTree(BaseModel):
    """Full hierarchical tree representation of an indexed repository."""
    repository_id: str
    repository_name: str
    total_files: int
    total_symbols: int
    total_relationships: int
    root: RepositoryTreeNode


