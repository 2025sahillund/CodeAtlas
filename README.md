# CodeAtlas 🗺️

**CodeAtlas** is an agentic repository intelligence and deep codebase analysis platform. It provides deterministic, AST-derived mental models, end-to-end feature execution tracing, change blast radius calculation, regression risk detection, and visual repository hierarchy mapping.

---

## 🌟 Key Capabilities

### 1. 🏛️ Repository Intelligence & Project Overview
- **AST-Derived Architecture Metrics**: Deterministic extraction of files, source symbols, cross-layer relationships, languages, and entry points.
- **Dynamic Architecture Map**: Interactive canonical layer visualization (`UI / Screens` ➔ `Services` ➔ `Models` ➔ `Storage & Data Access` ➔ `API / Controllers`).
- **Module Explorer**: Automated package and module boundary discovery with internal vs. external dependency accounting.
- **API Intelligence**: Automatic route extraction for FastAPI, Flask Blueprints, and Express.js with HTTP methods, paths, handler functions, and line numbers.
- **Data & Storage Intelligence**: Auto-detection of database technologies (Firebase / Cloud Firestore, SQLite, PostgreSQL, MongoDB, Shared Preferences, Domain Models) and collection/table schemas.

### 2. 🌳 Visual Repository Tree Map
- **Hierarchical Codebase Map**: Interactive, collapsible directory and file hierarchy built from actual repository structure.
- **Symbol Drill-Down**: Expand files to inspect classes, methods, functions, line ranges, and docstrings.
- **Cross-Module Relationships**: Detailed inspection of upstream incoming callers (`↙️`) and downstream outgoing dependencies (`↗️`).
- **Visual Connection Flow**: Center-node dependency flow visualizer connecting inbound callers and outbound callees with clickable source evidence snippets.
- **Instant Search**: Real-time filter with automatic path expansion for files and symbols.

### 3. 🎯 Feature Tracer
- **Natural Language Feature Queries**: Ask questions like *"Where is user authentication implemented"* or *"How does prescription scanning work"*.
- **Multi-Path Execution Graph**: Graphs entry points, controllers, business services, and database persistence layers.
- **Evidence Verification**: Verifiable source code snippets with confidence classification (`CONFIRMED`, `INFERRED`).

### 4. 💥 Change Impact Radar
- **Refactoring Blast Radius**: Analyze the downstream impact of changing any symbol (e.g. `MedicineService.addMedicine`) or file across configurable depths (1 to 5).
- **Impact Categorization**: Breaks down impact into Direct Callers, Indirect Callers, Type Dependencies, and Storage Mutators.
- **Severity Scoring**: Computes risk levels and affected component counts.

### 5. 🐛 Regression Investigator
- **Git Diff & Scenario Analysis**: Paste git diffs or natural queries to detect unintended logic regressions.
- **Risk Severity Cards**: Categorizes risks into High, Medium, and Low severity with affected components, rule violations, and test coverage mapping.

---

## 🚀 Quick Start

### Prerequisites
- **Python**: 3.10+
- **Node.js**: 18+ (npm)

### 1. Backend Setup
```bash
cd codeatlas/backend
pip install -r requirements.txt
python -m uvicorn app.main:app --port 8000 --host 127.0.0.1
```
*Backend API will run on `http://127.0.0.1:8000`.*

### 2. Frontend Setup
```bash
cd codeatlas/frontend
npm install
npm run dev
```
*Frontend will run on `http://localhost:3000`.*

---

## 🧪 Testing

### Backend Test Suite (137 Tests)
```bash
cd codeatlas/backend
python -m pytest
```

### Frontend Production Build
```bash
cd codeatlas/frontend
npm run build
```

---

## 🏗️ Architecture

```
CodeAtlas/
├── codeatlas/
│   ├── backend/             # FastAPI, AST Analyzers, Knowledge Graph
│   │   ├── app/
│   │   │   ├── analyzers/   # Language detection, symbol extractor, diff parser, relationships
│   │   │   ├── models/      # Pydantic knowledge models (Tree, Intelligence, Trace, Impact, Regression)
│   │   │   ├── services/    # Feature Tracer, Impact Radar, Regression Investigator, Tree Builder
│   │   │   └── api/         # REST API endpoints
│   │   └── tests/           # 137 unit and integration tests
│   └── frontend/            # React, TypeScript, Vite
│       └── src/
│           ├── components/  # RepositoryOverview, RepositoryTreeViewer, FeatureTracer, ImpactRadar, Regression
│           ├── services/    # Axios API client
│           └── types/       # TypeScript interfaces
└── caresync_source/         # Real multi-language demonstration repository (Dart / Flutter / Flask / Firestore)
```

---

## 📄 License
MIT License
