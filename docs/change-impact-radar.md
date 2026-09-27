# Change Impact Radar

> **"Understand before you change."**
> CodeAtlas Change Impact Radar answers: *"If I change this code, what else could be affected?"*

---

## 1. Problem Statement

When maintaining or modifying existing codebases, software developers frequently encounter unintended side effects, regressions, and broken contracts because dependencies are spread across services, state controllers, user interfaces, database access layers, and tests.

Traditional tools either:
- Rely on simple keyword text search (grep/ripgrep) which produces false positives (matching unrelated comments or variables) and misses structural relationships, OR
- Rely on generative LLMs that hallucinate dependencies, invent invalid line numbers, or construct non-existent runtime paths.

**Change Impact Radar** provides **deterministic, evidence-based change impact analysis** powered directly by the repository's static semantic knowledge graph.

---

## 2. Developer Workflow

```
┌────────────────────────────────────────────────────────┐
│ 1. Developer opens Change Impact Radar                 │
│    Enters target: class, method, symbol, file, or data │
│    e.g., "MedicineService.addMedicine"                 │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 2. Semantic Target Resolution                          │
│    Resolves qualified symbols, methods, or files       │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 3. Bidirectional Knowledge Graph Traversal             │
│    - Incoming callers, creators, testers, importers    │
│    - Outgoing data writes, reads, models, callees      │
│    - Depth-limited BFS (Default: 3 hops)               │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 4. Impact Classification & Metric Calculation          │
│    - DIRECT Impact (callers at distance 1)             │
│    - INDIRECT Impact (multi-hop callers at distance >=2)│
│    - DATA Impact (data models, Firestore collections)  │
│    - UI Impact (screens, widgets)                      │
│    - TEST Impact (test suites)                         │
└─────────────────────────┬──────────────────────────────┘
                          │
                          ▼
┌────────────────────────────────────────────────────────┐
│ 5. Visual Impact Graph & Evidence Inspection           │
│    Developer clicks any node to see exact code         │
│    snippets, line numbers, and ground-truth reasons.   │
└────────────────────────────────────────────────────────┘
```

---

## 3. Impact Domain Model

The impact engine is modeled with clean Pydantic & TypeScript abstractions:

### Impact Types

| Impact Type | Description |
| :--- | :--- |
| `DIRECT` | Immediate callers, direct instantiations, and service dependencies at distance 1. |
| `INDIRECT` | Multi-hop transitive callers and upstream callers-of-callers (distance $\ge 2$). |
| `DATA` | Data models, persistence schemas, and database collections written or read. |
| `UI` | Presentation components, user interface screens, forms, and widgets. |
| `TEST` | Automated unit tests, widget tests, and integration test suites. |
| `CONFIGURATION` | Config files, manifests, environment specifications. |
| `API` | Network endpoints and REST/gRPC client calls. |
| `UNKNOWN` | Targets or paths requiring manual developer verification. |

### Core Entities

- **`ImpactNode`**:
  - `id`: Qualified entity identifier
  - `file`: Path to source file
  - `symbol`: Name of symbol/method/class
  - `symbol_type`: Symbol category (`method`, `class`, `function`, etc.)
  - `impact_type`: Classified impact category
  - `relationship`: Triggering relationship (`CALLS`, `WRITES`, `READS`, `CREATES`, etc.)
  - `distance`: Graph hop distance from target ($0$ = target, $1$ = direct, $\ge 2$ = indirect)
  - `confidence`: `CONFIRMED` \| `INFERRED` \| `UNKNOWN`
  - `reason`: Human-readable deterministic explanation of why this component is affected
  - `evidence`: List of verified source code snippets and line numbers

- **`ImpactSummary`**:
  - `total_impacted`: Count of all affected components
  - `direct_count`: Count of direct callers
  - `indirect_count`: Count of transitive callers
  - `data_count`: Count of affected data entities
  - `ui_count`: Count of affected UI screens
  - `test_count`: Count of affected test suites
  - `max_distance`: Maximum graph traversal distance reached
  - `description`: Plain-English narrative summary

- **`ImpactAnalysis`**: Complete response containing target, categorized impact lists, ground-truth evidence list, visual graph nodes, and edges.

---

## 4. Graph Traversal & Prioritization

The impact traversal engine performs **bidirectional, depth-bounded breadth-first search**:

1. **Incoming Expansion (Callers & Dependents)**:
   - Identifies components that break if the target interface or behavior changes.
   - Looks up references across qualified method ID, parent class ID, and file path.
   - Discovers direct callers ($d=1$), callers of callers ($d=2$), etc.

2. **Outgoing Expansion (Callees & Data Mutations)**:
   - Identifies data stores mutated by the target (e.g., Firestore collections, database tables).
   - Identifies data models instantiated or modified.
   - For mutated data entities (e.g. `data::medicines`), dynamically discovers other components in the repository that **READ** from that collection.

3. **Relationship Prioritization**:
   Relationships are prioritized to evaluate structural and call dependencies before passive file imports:
   $$\text{CALLS} > \text{WRITES} > \text{READS} > \text{CREATES} > \text{IMPLEMENTS} > \text{EXTENDS} > \text{TESTS} > \text{IMPORTS}$$

4. **Cycle & Duplication Safeguards**:
   - Visited sets prevent infinite loops in cyclic dependencies (e.g. mutual class calls).
   - Node IDs are partitioned disjointly across categories with zero duplicate occurrences.
   - Maximum traversal depth is configurable (default: 3 hops).

---

## 5. Confidence Model

CodeAtlas applies a strict, verifiable confidence hierarchy:

- **`CONFIRMED`**: Direct repository evidence (explicit function call, class instantiation, model usage, or test target) is verified by static analysis with exact file and line references.
- **`INFERRED`**: The relationship is established through multi-hop propagation, file-level dependency linkage, or shared collection access without single-line AST proof.
- **`UNKNOWN`**: Target could not be unambiguously resolved in the indexed repository.

> **Rule:** Inferred relationships are never presented as confirmed.

---

## 6. Verifiable Source Evidence

Every impact result includes source evidence extracted directly from the scanned repository:

```json
{
  "file": "lib/services/medicine_service.dart",
  "line_start": 122,
  "line_end": 128,
  "snippet": "  static Future<bool> addMedicine({\n    required String name,\n    required String dosage,\n    required List<String> times,\n    required int stock,",
  "description": "Definition of MedicineService.addMedicine"
}
```

When an engineer selects any node in the UI, the **Evidence Panel** displays the source file, line span, exact snippet, relationship trigger, and reason.

---

## 7. CareSync Real-Repository Demonstration

### Scenario: Changing `MedicineService.addMedicine`

When analyzing the query `"MedicineService.addMedicine"` against the CareSync repository:

- **Target Resolved**: `lib/services/medicine_service.dart::MedicineService.addMedicine`
- **Total Impacted**: **30 components across 10 files**
- **Impact Breakdown**:
  - **Direct Impact (1)**: `ApiService` calling medicine synchronization
  - **UI Impact (28)**:
    - `AddMedicineScreen` (`_saveMedicine`)
    - `ScanPrescriptionScreen` (`_confirmAndSave`)
    - `MedicineListScreen` (`_refreshMedicines`, `_showRefillDialog`, `_showDeductStockDialog`)
    - `HomeScreen` (`_checkRefills`)
    - `AlertsScreen` (`_loadScheduleData`)
    - `MedicalPassportScreen` (`_loadAllPassportData`)
    - `PatientDashboardScreen` (`_initRealTimeStreams`, `_loadPatientData`)
    - `ReportsScreen`
  - **Test Impact (1)**: `test_models_services.dart` testing medicine service operations
- **Verifiable Evidence**: Direct source snippets with line spans from `lib/services/medicine_service.dart`, `lib/screens/add_medicine_screen.dart`, etc.

### Scenario: Changing `medicine_name` / Data Identifier

When querying `"medicine_name"`, Change Impact Radar dynamically discovers all models (`Medicine`), services (`MedicineService`, `FirebaseService`), screens, and database write paths referencing the medicine name and document identifiers.

---

## 8. Limitations & Future Extensions

- **Dynamic Reflection**: Dynamically computed runtime string dispatch (e.g. `reflectee.invoke(symbol)`) cannot be statically resolved without runtime instrumentation.
- **Transitive External Packages**: Impact analysis traverses the local repository knowledge graph; third-party package internals outside the repository are mapped at their entry boundary.
