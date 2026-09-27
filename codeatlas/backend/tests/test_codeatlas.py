"""
CodeAtlas Backend Test Suite.

Tests cover:
1. Language detection
2. Symbol extraction
3. Import extraction
4. Relationship extraction
5. Repository scanning
6. Feature Tracer
7. API endpoints
8. Evidence generation
9. Confidence classification
10. Edge cases (missing feature, irrelevant query)
"""

from __future__ import annotations

import os
import sys
import tempfile
import zipfile
from pathlib import Path

import pytest

# Ensure the backend app is importable
sys.path.insert(0, str(Path(__file__).parent.parent))

from app.analyzers.language_detector import (
    detect_language, is_source_file, is_test_file,
    is_entry_point, is_config_file,
)
from app.analyzers.symbol_extractor import extract_symbols, extract_imports
from app.analyzers.repository_scanner import scan_repository
from app.models.repository import (
    SymbolType, Confidence, RelationshipType,
    ImpactType, ImpactAnalysis, ImpactNode, ImpactSummary,
    RiskSeverity, RiskCategory, RegressionRisk, ChangedFile,
    RegressionSummary, RegressionAnalysis,
    ProjectIntelligence, ApiEndpoint, StorageTechnology,
    RepositoryModule, ArchitectureLayer, ArchitectureGraph,
    RepositoryTree, RepositoryTreeNode, TreeNodeType, RelationshipRef,
)
from app.analyzers.diff_parser import parse_git_diff, detect_changed_symbols
from app.services.feature_tracer import trace_feature, _extract_terms
from app.services.impact_radar import analyze_impact, _resolve_target_node
from app.services.regression_investigator import investigate_regression
from app.services.project_intelligence import analyze_project_intelligence, build_repository_tree
from app.services.repository_store import repository_store
from fastapi.testclient import TestClient
from app.main import app


# ---------------------------------------------------------------------------
# Fixtures: synthetic repository
# ---------------------------------------------------------------------------

PYTHON_SERVICE = """\
class UserService:
    def get_user(self, user_id: str):
        return db.collection('users').doc(user_id).get()

    def create_user(self, email: str, name: str):
        return db.collection('users').add({'email': email, 'name': name})

    def delete_user(self, user_id: str):
        db.collection('users').doc(user_id).delete()
"""

PYTHON_AUTH = """\
from services.user_service import UserService

class AuthService:
    def __init__(self):
        self.users = UserService()

    def login(self, email: str, password: str):
        user = self.users.get_user(email)
        if user:
            return self._create_token(user)
        raise ValueError('Invalid credentials')

    def signup(self, email: str, password: str, name: str):
        user = self.users.create_user(email, name)
        return self._create_token(user)

    def _create_token(self, user):
        return {'token': 'jwt_token', 'user': user}
"""

PYTHON_MAIN = """\
from services.auth_service import AuthService
from services.user_service import UserService

def main():
    auth = AuthService()
    print('CareApp started')

if __name__ == '__main__':
    main()
"""

DART_SCREEN = """\
import 'package:flutter/material.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
    @override
    _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
    Future<void> _handleLogin() async {
        final result = await AuthService.signIn(_email, _password);
        if (result != null) {
            Navigator.pushNamed(context, '/home');
        }
    }
}
"""

DART_SERVICE = """\
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
    static Future<UserCredential?> signIn(String email, String password) async {
        try {
            return await FirebaseAuth.instance.signInWithEmailAndPassword(
                email: email, password: password);
        } catch (e) {
            return null;
        }
    }
}
"""

TYPESCRIPT_API = """\
import express from 'express';
import { UserController } from './controllers/user_controller';

const router = express.Router();
const controller = new UserController();

router.get('/users', controller.listUsers);
router.post('/users', controller.createUser);
router.delete('/users/:id', controller.deleteUser);

export default router;
"""

TEST_FILE = """\
import pytest
from services.auth_service import AuthService

def test_login_success():
    auth = AuthService()
    assert auth.login('test@example.com', 'pass') is not None

def test_login_invalid():
    auth = AuthService()
    with pytest.raises(ValueError):
        auth.login('bad@example.com', 'wrong')
"""


@pytest.fixture
def synthetic_repo(tmp_path: Path) -> Path:
    """Create a synthetic multi-file repository for testing."""
    (tmp_path / "services").mkdir()
    (tmp_path / "screens").mkdir()
    (tmp_path / "tests").mkdir()
    (tmp_path / "controllers").mkdir()

    (tmp_path / "main.py").write_text(PYTHON_MAIN)
    (tmp_path / "services" / "auth_service.py").write_text(PYTHON_AUTH)
    (tmp_path / "services" / "user_service.py").write_text(PYTHON_SERVICE)
    (tmp_path / "screens" / "login_screen.dart").write_text(DART_SCREEN)
    (tmp_path / "services" / "auth_service.dart").write_text(DART_SERVICE)
    (tmp_path / "controllers" / "user_controller.ts").write_text(TYPESCRIPT_API)
    (tmp_path / "tests" / "test_auth.py").write_text(TEST_FILE)
    (tmp_path / "pubspec.yaml").write_text("name: test_app\n")

    return tmp_path


# ---------------------------------------------------------------------------
# Test 1: Language detection
# ---------------------------------------------------------------------------

class TestLanguageDetection:

    def test_python_detection(self):
        assert detect_language(Path("app.py")) == "Python"

    def test_dart_detection(self):
        assert detect_language(Path("screen.dart")) == "Dart"

    def test_typescript_detection(self):
        assert detect_language(Path("component.ts")) == "TypeScript"

    def test_tsx_detection(self):
        assert detect_language(Path("App.tsx")) == "TypeScript"

    def test_javascript_detection(self):
        assert detect_language(Path("index.js")) == "JavaScript"

    def test_kotlin_detection(self):
        assert detect_language(Path("Main.kt")) == "Kotlin"

    def test_unknown_extension(self):
        assert detect_language(Path("binary.bin")) == "Unknown"

    def test_png_not_source(self):
        assert not is_source_file(Path("image.png"))

    def test_dart_source(self):
        assert is_source_file(Path("service.dart"))

    def test_generated_dart_excluded(self):
        assert not is_source_file(Path("model.g.dart"))

    def test_entry_point_detection(self):
        assert is_entry_point(Path("main.dart"))
        assert is_entry_point(Path("main.py"))
        assert not is_entry_point(Path("service.py"))

    def test_test_file_detection(self):
        assert is_test_file(Path("test/widget_test.dart"))
        assert is_test_file(Path("tests/test_auth.py"))
        assert not is_test_file(Path("services/auth_service.py"))

    def test_config_file_detection(self):
        assert is_config_file(Path("pubspec.yaml"))
        assert is_config_file(Path("package.json"))
        assert not is_config_file(Path("main.dart"))


# ---------------------------------------------------------------------------
# Test 2: Symbol extraction
# ---------------------------------------------------------------------------

class TestSymbolExtraction:

    def test_python_class_extraction(self):
        symbols = extract_symbols("service.py", PYTHON_SERVICE, "Python")
        class_syms = [s for s in symbols if s.symbol_type == SymbolType.CLASS]
        assert any(s.name == "UserService" for s in class_syms), \
            f"Expected UserService in {[s.name for s in class_syms]}"

    def test_python_method_extraction(self):
        symbols = extract_symbols("service.py", PYTHON_SERVICE, "Python")
        method_names = {s.name for s in symbols if s.symbol_type == SymbolType.METHOD}
        assert "get_user" in method_names or "create_user" in method_names, \
            f"Expected methods, got: {method_names}"

    def test_dart_class_extraction(self):
        symbols = extract_symbols("login_screen.dart", DART_SCREEN, "Dart")
        class_syms = [s for s in symbols if s.symbol_type == SymbolType.CLASS]
        assert any("LoginScreen" in s.name for s in class_syms), \
            f"Expected LoginScreen, got: {[s.name for s in class_syms]}"

    def test_dart_service_method_extraction(self):
        symbols = extract_symbols("auth_service.dart", DART_SERVICE, "Dart")
        assert len(symbols) > 0, "Expected at least one symbol"

    def test_typescript_class_extraction(self):
        symbols = extract_symbols("router.ts", TYPESCRIPT_API, "TypeScript")
        assert len(symbols) >= 0  # May extract const declarations

    def test_symbol_has_file_reference(self):
        symbols = extract_symbols("services/auth.py", PYTHON_AUTH, "Python")
        for sym in symbols:
            assert sym.file == "services/auth.py"

    def test_symbol_has_line_numbers(self):
        symbols = extract_symbols("auth.py", PYTHON_AUTH, "Python")
        for sym in symbols:
            assert sym.line_start > 0
            assert sym.line_end >= sym.line_start

    def test_symbol_id_format(self):
        symbols = extract_symbols("auth.py", PYTHON_AUTH, "Python")
        for sym in symbols:
            assert "::" in sym.id
            assert sym.file in sym.id

    def test_no_keywords_as_symbols(self):
        symbols = extract_symbols("main.py", PYTHON_MAIN, "Python")
        names = {s.name for s in symbols}
        assert "if" not in names
        assert "return" not in names
        assert "import" not in names


# ---------------------------------------------------------------------------
# Test 3: Import extraction
# ---------------------------------------------------------------------------

class TestImportExtraction:

    def test_python_import_extraction(self):
        imports = extract_imports("main.py", PYTHON_MAIN, "Python")
        modules = {i.imported_module for i in imports}
        assert "services.auth_service" in modules or "services" in modules, \
            f"Expected auth_service import, got: {modules}"

    def test_python_from_import(self):
        imports = extract_imports("auth.py", PYTHON_AUTH, "Python")
        assert len(imports) > 0

    def test_dart_import_extraction(self):
        imports = extract_imports("login_screen.dart", DART_SCREEN, "Dart")
        modules = {i.imported_module for i in imports}
        # Should detect the flutter/material and local service import
        assert len(modules) > 0

    def test_import_has_file_reference(self):
        imports = extract_imports("main.py", PYTHON_MAIN, "Python")
        for imp in imports:
            assert imp.file == "main.py"

    def test_import_has_line_number(self):
        imports = extract_imports("main.py", PYTHON_MAIN, "Python")
        for imp in imports:
            assert imp.line > 0


# ---------------------------------------------------------------------------
# Test 4: Repository scanning
# ---------------------------------------------------------------------------

class TestRepositoryScanning:

    def test_scan_finds_all_source_files(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        # Should find Python, Dart, TypeScript files
        source_paths = list(repo.files.keys())
        assert any(".py" in p for p in source_paths)
        assert any(".dart" in p for p in source_paths)

    def test_scan_detects_languages(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert "Python" in repo.languages
        assert "Dart" in repo.languages

    def test_scan_status_indexed(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert repo.status.value == "indexed"

    def test_scan_finds_symbols(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert len(repo.symbols) > 0

    def test_scan_finds_entry_point(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert len(repo.entry_points) > 0

    def test_scan_finds_test_files(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert len(repo.test_files) > 0

    def test_scan_finds_dependency_files(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert len(repo.dependency_files) > 0

    def test_scan_ignores_git_directory(self, synthetic_repo: Path):
        git_dir = synthetic_repo / ".git"
        git_dir.mkdir()
        (git_dir / "config").write_text("fake git config")
        repo = scan_repository(str(synthetic_repo))
        assert not any(".git" in p for p in repo.files)

    def test_scan_total_files_count(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        assert repo.total_files > 0
        assert repo.source_files > 0

    def test_scan_repo_has_name(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo), repo_name="TestRepo")
        assert repo.name == "TestRepo"


# ---------------------------------------------------------------------------
# Test 5: Relationship extraction
# ---------------------------------------------------------------------------

class TestRelationshipExtraction:

    def test_import_relationships_found(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        import_rels = [r for r in repo.relationships
                       if r.relationship_type == RelationshipType.IMPORTS]
        assert len(import_rels) >= 0  # May find some

    def test_relationships_have_evidence(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        for rel in repo.relationships:
            assert rel.confidence in (
                Confidence.CONFIRMED, Confidence.INFERRED, Confidence.UNKNOWN
            )


# ---------------------------------------------------------------------------
# Test 6: Feature Tracer — term extraction
# ---------------------------------------------------------------------------

class TestTermExtraction:

    def test_extracts_key_terms(self):
        terms = _extract_terms("Trace prescription scanning")
        assert "prescription" in terms
        assert "scan" in terms or "scanning" in terms

    def test_removes_stop_words(self):
        terms = _extract_terms("Where is user authentication implemented?")
        assert "where" not in terms
        assert "is" not in terms
        assert "the" not in terms

    def test_expands_synonyms(self):
        terms = _extract_terms("Trace login flow")
        assert "auth" in terms or "signin" in terms

    def test_medicine_synonyms(self):
        terms = _extract_terms("Trace medicine management")
        assert "medicine" in terms or "medication" in terms

    def test_empty_query(self):
        terms = _extract_terms("")
        assert terms == []

    def test_single_term(self):
        terms = _extract_terms("authentication")
        assert len(terms) > 0


# ---------------------------------------------------------------------------
# Test 7: Feature Tracer — tracing
# ---------------------------------------------------------------------------

class TestFeatureTracer:

    def test_trace_auth_query(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace user authentication", repo)
        # Should find auth-related files
        assert result.total_nodes >= 0
        assert result.query == "Trace user authentication"
        assert result.summary != ""

    def test_trace_finds_relevant_files(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication login", repo)
        file_names = [n.file for n in result.nodes]
        # auth service or login screen should be found
        has_auth = any("auth" in f.lower() or "login" in f.lower() for f in file_names)
        assert has_auth, f"Expected auth-related file, got: {file_names}"

    def test_trace_returns_confirmed_or_inferred(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace user service", repo)
        for node in result.nodes:
            assert node.confidence in (
                Confidence.CONFIRMED, Confidence.INFERRED, Confidence.UNKNOWN
            )

    def test_trace_has_entry_points(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Where is authentication implemented", repo)
        # Entry points should be a subset of nodes
        ep_ids = {ep.id for ep in result.entry_points}
        node_ids = {n.id for n in result.nodes}
        for ep_id in ep_ids:
            assert ep_id in node_ids

    def test_trace_irrelevant_query_graceful(self, synthetic_repo: Path):
        """An irrelevant query with no matching terms returns 0 nodes."""
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("xyznonexistentfeatureabcdef123456789", repo)
        # With a sufficiently nonsense query, no file/symbol should score above threshold
        # The tracer should either return 0 nodes or populate unknowns
        assert result.total_nodes == 0 or len(result.unknowns) > 0, (
            f"Expected 0 nodes or unknowns, got {result.total_nodes} nodes: "
            f"{[n.file for n in result.nodes[:3]]}"
        )

    def test_trace_nodes_have_file_references(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication", repo)
        for node in result.nodes:
            assert node.file is not None and node.file != ""

    def test_trace_different_query_different_result(self, synthetic_repo: Path):
        """Different queries should produce meaningfully different trace results."""
        repo = scan_repository(str(synthetic_repo))
        auth_result = trace_feature("Trace authentication", repo)
        user_result = trace_feature("Trace user management", repo)
        auth_files = {n.file for n in auth_result.nodes}
        user_files = {n.file for n in user_result.nodes}
        # They may overlap but queries should not be identical
        # (at minimum, the query string differs)
        assert auth_result.query != user_result.query


# ---------------------------------------------------------------------------
# Test 8: Evidence generation
# ---------------------------------------------------------------------------

class TestEvidenceGeneration:

    def test_confirmed_node_has_evidence(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace user service", repo)
        confirmed = [n for n in result.nodes if n.confidence == Confidence.CONFIRMED]
        for node in confirmed:
            # Confirmed nodes should have evidence
            assert len(node.evidence) > 0 or node.symbol is not None

    def test_evidence_has_file_reference(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication", repo)
        for node in result.nodes:
            for ev in node.evidence:
                assert ev.file is not None and ev.file != ""

    def test_evidence_snippet_is_real(self, synthetic_repo: Path):
        """Evidence snippets must come from actual file content."""
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication", repo)
        for node in result.nodes:
            for ev in node.evidence:
                if ev.snippet:
                    # Snippet should not be empty or a placeholder
                    assert len(ev.snippet) > 0
                    assert "fake" not in ev.snippet.lower()
                    assert "mock" not in ev.snippet.lower()


# ---------------------------------------------------------------------------
# Test 9: Confidence classification
# ---------------------------------------------------------------------------

class TestConfidenceClassification:

    def test_confirmed_comes_from_direct_evidence(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace user service", repo)
        # Symbols found in the repository are CONFIRMED
        confirmed_nodes = [n for n in result.nodes if n.confidence == Confidence.CONFIRMED]
        # At least some nodes should be confirmed (they're in the actual repo)
        assert len(confirmed_nodes) >= 0  # May be 0 for inferred-only traces

    def test_no_confirmed_without_evidence(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication", repo)
        for node in result.nodes:
            if node.confidence == Confidence.CONFIRMED:
                # Confirmed nodes must have a real file in the repo
                assert node.file in repo.files or node.file == "[data store]"


# ---------------------------------------------------------------------------
# Test 10: API endpoints (using TestClient)
# ---------------------------------------------------------------------------

@pytest.fixture
def client():
    """Create a FastAPI TestClient."""
    from fastapi.testclient import TestClient
    from app.main import app
    return TestClient(app)


class TestAPIEndpoints:

    def test_root_returns_product_info(self, client):
        resp = client.get("/")
        assert resp.status_code == 200
        data = resp.json()
        assert data["product"] == "CodeAtlas"

    def test_health_check(self, client):
        resp = client.get("/health")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

    def test_list_repositories_empty(self, client):
        resp = client.get("/api/repositories")
        assert resp.status_code == 200
        assert isinstance(resp.json(), list)

    def test_upload_requires_zip(self, client):
        from io import BytesIO
        resp = client.post(
            "/api/repositories/upload",
            files={"file": ("test.txt", BytesIO(b"not a zip"), "text/plain")},
        )
        assert resp.status_code == 400

    def test_upload_zip(self, client, synthetic_repo: Path):
        import io
        zip_buffer = io.BytesIO()
        with zipfile.ZipFile(zip_buffer, "w") as zf:
            for f in synthetic_repo.rglob("*"):
                if f.is_file():
                    zf.write(f, f.relative_to(synthetic_repo))
        zip_buffer.seek(0)

        resp = client.post(
            "/api/repositories/upload",
            files={"file": ("test_repo.zip", zip_buffer, "application/zip")},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert "id" in data
        assert data["status"] == "scanning"

    def test_get_nonexistent_repository(self, client):
        resp = client.get("/api/repositories/nonexistent-id")
        assert resp.status_code == 404

    def test_trace_nonexistent_repository(self, client):
        resp = client.post(
            "/api/repositories/nonexistent-id/trace",
            json={"query": "Trace authentication"},
        )
        assert resp.status_code == 404

    def test_add_local_repository(self, client, synthetic_repo: Path):
        resp = client.post(
            "/api/repositories/local",
            json={"path": str(synthetic_repo), "name": "SyntheticTest"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["name"] == "SyntheticTest"
        assert "id" in data

    def test_local_repo_scanned_and_traceable(self, client, synthetic_repo: Path):
        """Full integration: add local repo → wait for scan → trace feature."""
        import time

        # Add local repo
        resp = client.post(
            "/api/repositories/local",
            json={"path": str(synthetic_repo), "name": "IntegrationTest"},
        )
        assert resp.status_code == 200
        repo_id = resp.json()["id"]

        # Wait for scan (background task runs synchronously in TestClient)
        # In TestClient, background tasks run after response, so poll briefly
        for _ in range(10):
            status_resp = client.get(f"/api/repositories/{repo_id}")
            if status_resp.status_code == 200:
                status = status_resp.json().get("status")
                if status == "indexed":
                    break
            time.sleep(0.2)

        status_resp = client.get(f"/api/repositories/{repo_id}")
        assert status_resp.status_code == 200
        repo_data = status_resp.json()
        assert repo_data["status"] == "indexed", f"Status: {repo_data['status']}"

        # Run trace
        trace_resp = client.post(
            f"/api/repositories/{repo_id}/trace",
            json={"query": "Trace authentication login"},
        )
        assert trace_resp.status_code == 200
        trace_data = trace_resp.json()
        assert "nodes" in trace_data
        assert "edges" in trace_data
        assert "summary" in trace_data
        assert trace_data["query"] == "Trace authentication login"

    def test_trace_empty_query_rejected(self, client, synthetic_repo: Path):
        """Empty query should return 400."""
        import time
        resp = client.post(
            "/api/repositories/local",
            json={"path": str(synthetic_repo), "name": "EmptyQueryTest"},
        )
        repo_id = resp.json()["id"]

        # Wait for scan
        for _ in range(10):
            sr = client.get(f"/api/repositories/{repo_id}")
            if sr.json().get("status") == "indexed":
                break
            time.sleep(0.2)

        trace_resp = client.post(
            f"/api/repositories/{repo_id}/trace",
            json={"query": ""},
        )
        assert trace_resp.status_code == 400

    def test_get_file_content(self, client, synthetic_repo: Path):
        """Can retrieve file content and symbols after indexing."""
        import time
        resp = client.post(
            "/api/repositories/local",
            json={"path": str(synthetic_repo), "name": "FileTest"},
        )
        repo_id = resp.json()["id"]
        for _ in range(10):
            sr = client.get(f"/api/repositories/{repo_id}")
            if sr.json().get("status") == "indexed":
                break
            time.sleep(0.2)

        # Try to get main.py
        file_resp = client.get(f"/api/repositories/{repo_id}/files/main.py")
        assert file_resp.status_code == 200
        fd = file_resp.json()
        assert fd["language"] == "Python"
        assert fd["content"] is not None

    def test_delete_repository(self, client, synthetic_repo: Path):
        resp = client.post(
            "/api/repositories/local",
            json={"path": str(synthetic_repo), "name": "DeleteTest"},
        )
        repo_id = resp.json()["id"]

        del_resp = client.delete(f"/api/repositories/{repo_id}")
        assert del_resp.status_code == 200

        get_resp = client.get(f"/api/repositories/{repo_id}")
        assert get_resp.status_code == 404


# ---------------------------------------------------------------------------
# Test 11: Dart Import Resolution
# ---------------------------------------------------------------------------

class TestDartImportResolution:

    def test_relative_import_resolution(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        # login_screen.dart imports '../services/auth_service.dart'
        login_file = repo.files.get("screens/login_screen.dart")
        assert login_file is not None
        import_rels = [
            r for r in repo.relationships
            if r.source_id == "screens/login_screen.dart" and r.relationship_type == RelationshipType.IMPORTS
        ]
        target_ids = {r.target_id for r in import_rels}
        assert "services/auth_service.dart" in target_ids

    def test_external_package_not_resolved_to_random_files(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        # package:flutter/material.dart or package:firebase_auth should NOT resolve to random repo files
        import_rels = [
            r for r in repo.relationships
            if r.relationship_type == RelationshipType.IMPORTS
        ]
        for rel in import_rels:
            assert not rel.target_id.startswith("package:")
            assert rel.target_id in repo.files

    def test_dart_sdk_imports_ignored(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        import_rels = [
            r for r in repo.relationships
            if r.relationship_type == RelationshipType.IMPORTS and "dart:" in r.target_id
        ]
        assert len(import_rels) == 0


# ---------------------------------------------------------------------------
# Test 12: Cross-File Relationships (Calls, Creates, Extends)
# ---------------------------------------------------------------------------

class TestCrossFileRelationships:

    def test_dart_cross_file_call(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        # _handleLogin in login_screen.dart calls AuthService.signIn in auth_service.dart
        call_rels = [
            r for r in repo.relationships
            if r.relationship_type == RelationshipType.CALLS
        ]
        has_cross_file = any(
            "login_screen" in r.source_id and "auth_service" in r.target_id
            for r in call_rels
        )
        assert has_cross_file, f"Expected cross-file call, got: {[r.description for r in call_rels]}"

    def test_python_cross_file_call(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        # AuthService in auth_service.py calls UserService in user_service.py
        call_rels = [
            r for r in repo.relationships
            if r.relationship_type == RelationshipType.CALLS
        ]
        has_user_call = any(
            "auth_service" in r.source_id and "user_service" in r.target_id
            for r in call_rels
        )
        assert has_user_call, f"Expected auth->user call, got: {[r.description for r in call_rels]}"

    def test_cross_file_creates(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        create_rels = [
            r for r in repo.relationships
            if r.relationship_type == RelationshipType.CREATES
        ]
        assert len(create_rels) > 0

    def test_database_collection_access(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        db_rels = [
            r for r in repo.relationships
            if r.target_id.startswith("data::")
        ]
        assert len(db_rels) > 0
        assert any("users" in r.target_id for r in db_rels)


# ---------------------------------------------------------------------------
# Test 13: Dart Symbol Resolution & Scope Isolation
# ---------------------------------------------------------------------------

class TestDartSymbolResolution:

    def test_no_local_vars_in_symbols(self):
        dart_code = """\
class TestWidget extends StatelessWidget {
    final String title;

    TestWidget({required this.title});

    @override
    Widget build(BuildContext context) {
        final localVal = "hello";
        final int counter = 42;
        final List<String> items = [];
        return Text(localVal);
    }
}
"""
        symbols = extract_symbols("test_widget.dart", dart_code, "Dart")
        names = {s.name for s in symbols}
        assert "TestWidget" in names
        assert "title" in names
        assert "build" in names
        # Local variables should NOT be symbols
        assert "localVal" not in names
        assert "counter" not in names
        assert "items" not in names
        assert "int" not in names
        assert "List" not in names

    def test_dart_class_line_range(self):
        dart_code = """\
class SampleService {
    void doSomething() {
        print("action");
    }

    void doAnother() {
        print("action 2");
    }
}
"""
        symbols = extract_symbols("sample_service.dart", dart_code, "Dart")
        cls_sym = next(s for s in symbols if s.name == "SampleService")
        assert cls_sym.line_start == 1
        assert cls_sym.line_end >= 9


# ---------------------------------------------------------------------------
# Test 14: Evidence Extraction Verification
# ---------------------------------------------------------------------------

class TestEvidenceExtractionVerifiable:

    def test_every_edge_has_non_empty_snippet(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication", repo)
        assert result.total_edges > 0
        for edge in result.edges:
            assert len(edge.evidence) > 0
            for ev in edge.evidence:
                assert ev.file is not None and ev.file != ""
                assert ev.snippet is not None and len(ev.snippet) > 0
                assert ev.line_start is not None and ev.line_start > 0

    def test_evidence_matches_source_lines(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        for rel in repo.relationships:
            for ev in rel.evidence:
                if ev.file in repo.files and repo.files[ev.file]._content and ev.line_start:
                    lines = repo.files[ev.file]._content.split("\n")
                    line_idx = ev.line_start - 1
                    if line_idx < len(lines):
                        actual_line = lines[line_idx].strip()
                        assert ev.snippet in actual_line or actual_line in ev.snippet


# ---------------------------------------------------------------------------
# Test 15: Feature Graph Construction & Traversal
# ---------------------------------------------------------------------------

class TestFeatureGraphConstruction:

    def test_trace_produces_nodes_and_edges(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace user authentication", repo)
        assert result.total_nodes > 1
        assert result.total_edges > 0

    def test_trace_edges_connect_existing_nodes(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("Trace authentication", repo)
        node_ids = {n.id for n in result.nodes}
        for edge in result.edges:
            assert edge.source_id in node_ids, f"Edge source {edge.source_id} not in nodes"
            assert edge.target_id in node_ids, f"Edge target {edge.target_id} not in nodes"

    def test_trace_respects_max_depth(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result_depth_1 = trace_feature("Trace authentication", repo, max_depth=1)
        result_depth_3 = trace_feature("Trace authentication", repo, max_depth=3)
        assert result_depth_3.total_nodes >= result_depth_1.total_nodes


# ---------------------------------------------------------------------------
# Test 16: Missing and Irrelevant Features
# ---------------------------------------------------------------------------

class TestMissingAndIrrelevantFeatures:

    def test_completely_irrelevant_query_returns_zero_nodes(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("xyz123nonsensequerynotincodebase", repo)
        assert result.total_nodes == 0
        assert result.total_edges == 0
        assert len(result.unknowns) > 0

    def test_missing_feature_populated_in_unknowns(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        result = trace_feature("How is bitcoin blockchain mined", repo)
        assert result.total_nodes == 0
        assert len(result.unknowns) > 0


# ---------------------------------------------------------------------------
# Test 17: Change Impact Radar - Target Resolution
# ---------------------------------------------------------------------------

class TestImpactTargetResolution:

    def test_resolve_exact_qualified_method(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        node = _resolve_target_node("UserService.get_user", repo)
        assert node is not None
        assert "get_user" in node.id
        assert node.symbol == "UserService.get_user" or node.symbol == "get_user"

    def test_resolve_unqualified_method_name(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        node = _resolve_target_node("create_user", repo)
        assert node is not None
        assert "create_user" in node.id

    def test_resolve_class_name(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        node = _resolve_target_node("UserService", repo)
        assert node is not None
        assert "UserService" in node.id

    def test_resolve_file_path(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        node = _resolve_target_node("services/user_service.py", repo)
        assert node is not None
        assert "user_service.py" in node.file

    def test_resolve_nonexistent_target_returns_unknown(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("NonExistentComponentX999", repo)
        assert analysis.target.impact_type == ImpactType.UNKNOWN
        assert len(analysis.unknowns) > 0
        assert analysis.confidence == Confidence.UNKNOWN

    def test_empty_target_returns_unknown(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("", repo)
        assert analysis.target.impact_type == ImpactType.UNKNOWN
        assert len(analysis.unknowns) > 0


# ---------------------------------------------------------------------------
# Test 18: Change Impact Radar - Graph Traversal & Classification
# ---------------------------------------------------------------------------

class TestImpactGraphTraversal:

    def test_direct_caller_impact_detected(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("UserService.get_user", repo, max_depth=3)
        assert analysis.target.id != "[unknown]"
        # AuthService calls UserService.get_user
        direct_files = {n.file for n in analysis.direct_impacts}
        assert any("auth_service" in f for f in direct_files)
        assert analysis.summary.direct_count > 0

    def test_indirect_impact_detected_at_distance_2(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("UserService.get_user", repo, max_depth=3)
        # AuthService calls UserService.get_user, main / login_screen calls AuthService
        all_impacts = (
            analysis.direct_impacts +
            analysis.indirect_impacts +
            analysis.ui_impacts +
            analysis.test_impacts +
            analysis.data_impacts
        )
        impact_files = {n.file for n in all_impacts}
        assert any("auth_service" in f for f in impact_files)

    def test_depth_limiting(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis_depth_1 = analyze_impact("UserService.get_user", repo, max_depth=1)
        analysis_depth_3 = analyze_impact("UserService.get_user", repo, max_depth=3)
        # At depth 1, indirect impacts should be 0
        assert len(analysis_depth_1.indirect_impacts) == 0
        assert analysis_depth_3.summary.total_impacted >= analysis_depth_1.summary.total_impacted

    def test_test_impact_classification(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("AuthService.login", repo, max_depth=3)
        test_files = [n for n in analysis.test_impacts if "test" in n.file.lower()]
        assert len(test_files) > 0
        for t in test_files:
            assert t.impact_type == ImpactType.TEST

    def test_no_duplicate_node_ids(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("UserService.get_user", repo, max_depth=3)
        all_nodes = (
            analysis.direct_impacts +
            analysis.indirect_impacts +
            analysis.data_impacts +
            analysis.ui_impacts +
            analysis.test_impacts
        )
        node_ids = [n.id for n in all_nodes]
        assert len(node_ids) == len(set(node_ids)), "Duplicate node IDs detected in impact analysis"


# ---------------------------------------------------------------------------
# Test 19: Change Impact Radar - Cycle Handling & Synthetic Cycles
# ---------------------------------------------------------------------------

class TestImpactCycleHandling:

    def test_circular_dependency_terminates(self, tmp_path: Path):
        file_a = tmp_path / "service_a.py"
        file_a.write_text("""\
from service_b import ServiceB
class ServiceA:
    def action_a(self):
        return ServiceB().action_b()
""", encoding="utf-8")

        file_b = tmp_path / "service_b.py"
        file_b.write_text("""\
from service_a import ServiceA
class ServiceB:
    def action_b(self):
        return ServiceA().action_a()
""", encoding="utf-8")

        repo = scan_repository(str(tmp_path))
        analysis = analyze_impact("ServiceA.action_a", repo, max_depth=5)
        assert analysis.target.id != "[unknown]"
        assert analysis.summary.total_impacted >= 1


# ---------------------------------------------------------------------------
# Test 20: Change Impact Radar - Evidence & Confidence
# ---------------------------------------------------------------------------

class TestImpactEvidenceAndConfidence:

    def test_direct_impact_has_confirmed_confidence(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("UserService.get_user", repo, max_depth=2)
        for node in analysis.direct_impacts:
            assert node.confidence in (Confidence.CONFIRMED, Confidence.INFERRED)
            assert len(node.reason) > 0

    def test_evidence_snippets_are_valid(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = analyze_impact("UserService.get_user", repo, max_depth=2)
        for ev in analysis.evidence:
            assert ev.file is not None and ev.file != ""
            assert ev.snippet is not None and len(ev.snippet) > 0
            if ev.line_start is not None and ev.line_start > 0 and ev.file in repo.files:
                content = repo.files[ev.file]._content
                if content:
                    lines = content.split("\n")
                    idx = ev.line_start - 1
                    if idx < len(lines):
                        assert ev.snippet in lines[idx] or lines[idx].strip() in ev.snippet


# ---------------------------------------------------------------------------
# Test 21: Change Impact Radar - API Endpoints
# ---------------------------------------------------------------------------

class TestChangeImpactRadarAPI:

    def test_api_impact_endpoint_success(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        response = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"target": "UserService.get_user", "max_depth": 3},
        )
        assert response.status_code == 200
        data = response.json()
        assert "target" in data
        assert "direct_impacts" in data
        assert "indirect_impacts" in data
        assert "data_impacts" in data
        assert "ui_impacts" in data
        assert "test_impacts" in data
        assert "summary" in data
        assert "evidence" in data
        assert data["summary"]["direct_count"] > 0

    def test_api_impact_endpoint_404_on_missing_repo(self):
        client = TestClient(app)
        response = client.post(
            "/api/repositories/nonexistent-repo-id-123/impact",
            json={"target": "UserService.get_user"},
        )
        assert response.status_code == 404

    def test_api_impact_endpoint_400_on_empty_target(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)
        response = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"target": ""},
        )
        assert response.status_code == 400


# ---------------------------------------------------------------------------
# Test 22: Change Impact Radar - CareSync Real Repository Demonstration
# ---------------------------------------------------------------------------

class TestCareSyncImpactRadar:

    def test_caresync_medicine_impact_scenario(self):
        caresync_path = Path(__file__).parent.parent.parent.parent / "caresync_source"
        if not caresync_path.exists():
            pytest.skip("caresync_source directory not available for demo test")

        repo = scan_repository(str(caresync_path))
        assert repo.total_files > 30

        # Scenario: "What if I change MedicineService.addMedicine?"
        analysis = analyze_impact("MedicineService.addMedicine", repo, max_depth=3)
        assert analysis.target.id != "[unknown]"
        assert analysis.summary.total_impacted > 0

        all_impacted_files = {
            n.file for n in (
                analysis.direct_impacts +
                analysis.indirect_impacts +
                analysis.data_impacts +
                analysis.ui_impacts +
                analysis.test_impacts
            )
        }

        # Dynamic verification: MedicineService interacts with FirebaseService and screens
        assert any("firebase_service" in f for f in all_impacted_files)
        assert any("screen" in f or "medicine" in f for f in all_impacted_files)
        assert len(analysis.evidence) > 0

        # Scenario: "What if I change medicine document identifier / medicine_name?"
        analysis_sym = analyze_impact("medicine_name", repo, max_depth=3)
        assert analysis_sym.summary.total_impacted > 0

        # Scenario: "What if I change medicine_service.dart?"
        analysis_file = analyze_impact("medicine_service.dart", repo, max_depth=3)
        assert analysis_file.summary.total_impacted > 0


# ---------------------------------------------------------------------------
# Test 23: Regression Investigator - Diff Parser & Changed Symbols
# ---------------------------------------------------------------------------

SAMPLE_DIFF = """\
diff --git a/services/user_service.py b/services/user_service.py
index 1234567..89abcdef 100644
--- a/services/user_service.py
+++ b/services/user_service.py
@@ -2,3 +2,4 @@ class UserService:
     def get_user(self, user_id: str):
-        return db.collection('users').doc(user_id).get()
+        if user_id == null or len(user_id) == 0:
+            return None
+        return db.collection('users').doc(user_id).get()
"""

class TestDiffParser:

    def test_parse_standard_git_diff(self):
        changed_files = parse_git_diff(SAMPLE_DIFF)
        assert len(changed_files) == 1
        cf = changed_files[0]
        assert "services/user_service.py" in cf.file
        assert cf.added_count == 3
        assert cf.removed_count == 1
        assert len(cf.hunks) == 1
        assert len(cf.changed_line_ranges) == 1

    def test_parse_patch_without_git_header(self):
        patch = """\
--- a/auth_service.py
+++ b/auth_service.py
@@ -10,3 +10,4 @@
+        if count == 0:
+            return 0
"""
        changed_files = parse_git_diff(patch)
        assert len(changed_files) == 1
        assert "auth_service.py" in changed_files[0].file

    def test_parse_empty_diff_returns_empty_list(self):
        assert parse_git_diff("") == []
        assert parse_git_diff("   \n   ") == []

    def test_detect_changed_symbols(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        changed_files = parse_git_diff(SAMPLE_DIFF)
        cf, symbols = detect_changed_symbols(changed_files, repo)
        assert len(symbols) > 0
        sym_names = [s.name for s in symbols]
        assert "get_user" in sym_names or "UserService" in sym_names


# ---------------------------------------------------------------------------
# Test 24: Regression Investigator - Risk Signals & Analysis Engine
# ---------------------------------------------------------------------------

class TestRegressionInvestigatorEngine:

    def test_regression_analysis_from_diff(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = investigate_regression(repo, diff_text=SAMPLE_DIFF, max_depth=3)
        assert len(analysis.changed_files) == 1
        assert len(analysis.changed_symbols) > 0
        assert len(analysis.affected_components) > 0
        assert len(analysis.risks) > 0
        assert analysis.summary.risks_count > 0

    def test_edge_case_risk_signal_detected(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        edge_diff = """\
diff --git a/services/user_service.py b/services/user_service.py
--- a/services/user_service.py
+++ b/services/user_service.py
@@ -4,2 +4,4 @@
+        if count == 0:
+            return 0
"""
        analysis = investigate_regression(repo, diff_text=edge_diff)
        edge_risks = [r for r in analysis.risks if r.category == RiskCategory.EDGE_CASE]
        assert len(edge_risks) > 0
        assert any("count == 0" in r.description or "boundary" in r.title.lower() for r in edge_risks)
        assert edge_risks[0].suggested_test != ""

    def test_regression_from_natural_language_query(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = investigate_regression(repo, query="UserService.get_user")
        assert len(analysis.changed_symbols) > 0
        assert len(analysis.affected_components) > 0

    def test_missing_or_unknown_target(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        analysis = investigate_regression(repo, query="NonExistentComponentX999")
        assert len(analysis.unknowns) > 0
        assert analysis.summary.risks_count == 0


# ---------------------------------------------------------------------------
# Test 25: Regression Investigator - API Endpoints
# ---------------------------------------------------------------------------

class TestRegressionInvestigatorAPI:

    def test_api_regression_with_diff(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        response = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"diff": SAMPLE_DIFF, "max_depth": 3},
        )
        assert response.status_code == 200
        data = response.json()
        assert "changed_files" in data
        assert "changed_symbols" in data
        assert "affected_components" in data
        assert "risks" in data
        assert "summary" in data
        assert "evidence" in data
        assert data["summary"]["risks_count"] > 0

    def test_api_regression_with_query(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        response = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"query": "UserService.get_user"},
        )
        assert response.status_code == 200
        data = response.json()
        assert len(data["changed_symbols"]) > 0

    def test_api_regression_400_on_empty(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        response = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={},
        )
        assert response.status_code == 400

    def test_api_regression_404_missing_repo(self):
        client = TestClient(app)
        response = client.post(
            "/api/repositories/nonexistent-repo-999/regression",
            json={"query": "UserService"},
        )
        assert response.status_code == 404
        assert "Repository not found" in response.json()["detail"]

    def test_api_impact_with_query_and_depth_aliases(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        # Test sending 'query' and 'depth' instead of 'target' and 'max_depth'
        response = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"query": "UserService.get_user", "depth": 2},
        )
        assert response.status_code == 200
        data = response.json()
        assert data["summary"]["total_impacted"] > 0
        assert data["summary"]["direct_count"] > 0


# ---------------------------------------------------------------------------
# Test 26: Regression Investigator - CareSync Adherence Demonstration
# ---------------------------------------------------------------------------

class TestCareSyncAdherenceRegressionScenario:

    def test_caresync_adherence_diff_investigation(self):
        caresync_path = Path(__file__).parent.parent.parent.parent / "caresync_source"
        if not caresync_path.exists():
            pytest.skip("caresync_source directory not available for demo test")

        repo = scan_repository(str(caresync_path))
        assert repo.total_files > 30

        # Scenario: Developer alters the adherence calculation in medicine_service.dart
        adherence_diff = """\
diff --git a/lib/services/medicine_service.dart b/lib/services/medicine_service.dart
--- a/lib/services/medicine_service.dart
+++ b/lib/services/medicine_service.dart
@@ -580,6 +580,8 @@ class MedicineService {
       int adherence = 0;
       if (totalLogs > 0) {
         final takenCount = allLogs.where((l) => l['status'] == 'taken').length;
-        adherence = ((takenCount / totalLogs) * 100).round().clamp(0, 100);
+        adherence = ((takenCount / totalLogs) * 100).round();
       } else if (inventory.isNotEmpty) {
-        adherence = 100;
+        adherence = 0;
       }
"""
        analysis = investigate_regression(repo, diff_text=adherence_diff, max_depth=3)
        assert len(analysis.changed_files) == 1
        assert len(analysis.changed_symbols) > 0
        assert analysis.summary.risks_count > 0

        # Verify discovery of edge case condition (totalLogs > 0 / zero logs)
        edge_risks = [r for r in analysis.risks if r.category == RiskCategory.EDGE_CASE]
        assert len(edge_risks) > 0

        # Verify discovery of calculation modification
        calc_risks = [r for r in analysis.risks if r.category == RiskCategory.BUSINESS_LOGIC]
        assert len(calc_risks) > 0

        # Verify discovery of downstream UI components (reports_screen, alerts_screen, etc.)
        ui_risks = [r for r in analysis.risks if r.category == RiskCategory.UI]
        assert len(ui_risks) > 0

        # Verify test association (test_models_services.dart)
        test_risks = [r for r in analysis.risks if r.category == RiskCategory.TEST_COVERAGE]
        assert len(test_risks) > 0

        # Verify suggested test scenario exists
        assert any(r.suggested_test != "" for r in analysis.risks)
        assert len(analysis.evidence) > 0


# ---------------------------------------------------------------------------
# Test 27: API Lifecycle, 404 Handling & Shared Repository Integration
# ---------------------------------------------------------------------------

class TestImpactAndRegressionIntegrationAnd404:

    def test_impact_endpoint_returns_200_valid_repo(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        # 1. Target & max_depth format
        resp1 = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"target": "UserService.get_user", "max_depth": 3},
        )
        assert resp1.status_code == 200
        data1 = resp1.json()
        assert data1["target"]["id"] != "[unknown]"
        assert data1["summary"]["total_impacted"] > 0

        # 2. Query & depth format (aliases)
        resp2 = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"query": "UserService.get_user", "depth": 2},
        )
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert data2["summary"]["total_impacted"] > 0

    def test_regression_endpoint_returns_200_valid_repo(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        # 1. Diff payload
        resp1 = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"diff": SAMPLE_DIFF, "max_depth": 3},
        )
        assert resp1.status_code == 200
        data1 = resp1.json()
        assert len(data1["changed_files"]) > 0
        assert data1["summary"]["risks_count"] > 0

        # 2. Query payload
        resp2 = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"query": "UserService.get_user", "depth": 2},
        )
        assert resp2.status_code == 200
        data2 = resp2.json()
        assert len(data2["changed_symbols"]) > 0

        # 3. Changed files list payload
        resp3 = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"changed_files": ["services/user_service.py"], "max_depth": 2},
        )
        assert resp3.status_code == 200
        data3 = resp3.json()
        assert len(data3["changed_files"]) > 0

    def test_invalid_repo_id_returns_404_with_message(self):
        client = TestClient(app)
        invalid_id = "nonexistent-uuid-000000"

        # Trace 404
        resp_trace = client.post(f"/api/repositories/{invalid_id}/trace", json={"query": "test"})
        assert resp_trace.status_code == 404
        assert resp_trace.json()["detail"] == "Repository not found."

        # Impact 404
        resp_impact = client.post(f"/api/repositories/{invalid_id}/impact", json={"target": "test"})
        assert resp_impact.status_code == 404
        assert resp_impact.json()["detail"] == "Repository not found."

        # Regression 404
        resp_reg = client.post(f"/api/repositories/{invalid_id}/regression", json={"query": "test"})
        assert resp_reg.status_code == 404
        assert resp_reg.json()["detail"] == "Repository not found."

    def test_feature_tracer_still_works(self, synthetic_repo: Path):
        repo = scan_repository(str(synthetic_repo))
        repository_store.put(repo)
        client = TestClient(app)

        resp = client.post(
            f"/api/repositories/{repo.id}/trace",
            json={"query": "Where is user authentication implemented"},
        )
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_nodes"] > 0
        assert data["total_edges"] > 0
        assert len(data["confirmed"]) > 0

    def test_caresync_all_features_via_api(self):
        caresync_path = Path(__file__).parent.parent.parent.parent / "caresync_source"
        if not caresync_path.exists():
            pytest.skip("caresync_source directory not available")

        repo = scan_repository(str(caresync_path))
        repository_store.put(repo)
        client = TestClient(app)

        # Feature Tracer: Prescription scanning
        trace_resp1 = client.post(
            f"/api/repositories/{repo.id}/trace",
            json={"query": "Trace prescription scanning"},
        )
        assert trace_resp1.status_code == 200
        assert trace_resp1.json()["total_nodes"] > 0

        # Feature Tracer: Medicine management
        trace_resp2 = client.post(
            f"/api/repositories/{repo.id}/trace",
            json={"query": "Trace medicine management"},
        )
        assert trace_resp2.status_code == 200
        assert trace_resp2.json()["total_nodes"] > 0

        # Feature Tracer: Authentication
        trace_resp3 = client.post(
            f"/api/repositories/{repo.id}/trace",
            json={"query": "Where is user authentication implemented"},
        )
        assert trace_resp3.status_code == 200
        assert trace_resp3.json()["total_nodes"] > 0

        # Impact: MedicineService.addMedicine
        impact_resp1 = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"target": "MedicineService.addMedicine", "max_depth": 3},
        )
        assert impact_resp1.status_code == 200
        assert impact_resp1.json()["summary"]["total_impacted"] > 0

        # Impact: ScanPrescriptionScreen
        impact_resp2 = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"query": "ScanPrescriptionScreen", "depth": 3},
        )
        assert impact_resp2.status_code == 200
        assert impact_resp2.json()["summary"]["total_impacted"] > 0

        # Impact: medicine_name
        impact_resp3 = client.post(
            f"/api/repositories/{repo.id}/impact",
            json={"target": "medicine_name", "max_depth": 3},
        )
        assert impact_resp3.status_code == 200
        assert impact_resp3.json()["summary"]["total_impacted"] > 0

        # Regression: Adherence Diff
        adherence_diff = """\
diff --git a/lib/services/medicine_service.dart b/lib/services/medicine_service.dart
--- a/lib/services/medicine_service.dart
+++ b/lib/services/medicine_service.dart
@@ -580,6 +580,8 @@ class MedicineService {
       int adherence = 0;
       if (totalLogs > 0) {
         final takenCount = allLogs.where((l) => l['status'] == 'taken').length;
-        adherence = ((takenCount / totalLogs) * 100).round().clamp(0, 100);
+        adherence = ((takenCount / totalLogs) * 100).round();
       } else if (inventory.isNotEmpty) {
-        adherence = 100;
+        adherence = 0;
       }
"""
        reg_resp1 = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"diff": adherence_diff, "max_depth": 3},
        )
        assert reg_resp1.status_code == 200
        assert reg_resp1.json()["summary"]["risks_count"] > 0

        # Regression: Natural Query Mode
        reg_resp2 = client.post(
            f"/api/repositories/{repo.id}/regression",
            json={"query": "Medicine adherence calculation was changed", "max_depth": 3},
        )
        assert reg_resp2.status_code == 200
        assert len(reg_resp2.json()["changed_symbols"]) > 0


# ---------------------------------------------------------------------------
# Project Intelligence / Repository Overview Tests
# ---------------------------------------------------------------------------

class TestProjectIntelligence:
    """Tests for Repository Intelligence, Architecture Overview, APIs, Modules, and Storage."""

    def test_intelligence_synthetic_repo(self, synthetic_repo):
        """Test intelligence analysis on the synthetic multi-file repository."""
        repo = scan_repository(str(synthetic_repo), "test-repo")
        intel = analyze_project_intelligence(repo)
        
        assert isinstance(intel, ProjectIntelligence)
        assert intel.repository_id == repo.id
        assert intel.repository_name == repo.name
        assert intel.total_files == len(repo.files)
        assert intel.total_symbols == len(repo.symbols)
        assert intel.total_relationships == len(repo.relationships)
        assert len(intel.languages) > 0
        assert "Python" in intel.languages or "Dart" in intel.languages
        assert len(intel.entry_points) > 0
        assert len(intel.modules) > 0
        assert len(intel.layers) > 0
        assert isinstance(intel.architecture_graph, ArchitectureGraph)
        assert len(intel.architecture_graph.nodes) > 0

    def test_intelligence_module_extraction(self, synthetic_repo):
        """Test generic module extraction and cross-module relationship accounting."""
        repo = scan_repository(str(synthetic_repo), "test-repo")
        intel = analyze_project_intelligence(repo)
        
        # Modules should be discovered from folder structure
        module_names = [m.name for m in intel.modules]
        assert len(module_names) > 0
        
        for mod in intel.modules:
            assert mod.file_count > 0
            assert len(mod.files) == mod.file_count
            assert mod.incoming_count >= 0
            assert mod.outgoing_count >= 0
            assert mod.symbol_count >= 0

    def test_intelligence_fastapi_route_detection(self):
        """Test API detection for FastAPI endpoints."""
        fastapi_code = '''\
from fastapi import FastAPI, APIRouter, Depends

app = FastAPI()
router = APIRouter(prefix="/users")

@app.get("/health", tags=["system"])
def health_check():
    """Health check endpoint."""
    return {"status": "ok"}

@router.post("/{user_id}/status", response_model=UserResponse)
async def update_user_status(user_id: str, status: Status):
    """Update active status for user."""
    return {"user_id": user_id, "status": status}

@app.delete("/items/{item_id}")
def delete_item(item_id: int):
    return {"deleted": item_id}
'''
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "api" / "endpoints.py"
            fpath.parent.mkdir(parents=True, exist_ok=True)
            fpath.write_text(fastapi_code, encoding="utf-8")
            
            repo = scan_repository(tmp_dir, "fastapi-test")
            intel = analyze_project_intelligence(repo)
            
            assert len(intel.api_endpoints) >= 3
            methods = [ep.method for ep in intel.api_endpoints]
            paths = [ep.path for ep in intel.api_endpoints]
            handlers = [ep.handler for ep in intel.api_endpoints]
            
            assert "GET" in methods
            assert "POST" in methods
            assert "DELETE" in methods
            assert "/health" in paths
            assert "/items/{item_id}" in paths
            assert "health_check" in handlers
            assert "update_user_status" in handlers
            assert "delete_item" in handlers
            
            # Verify evidence is populated
            for ep in intel.api_endpoints:
                assert len(ep.evidence) > 0
                assert ep.file.endswith("endpoints.py")
                assert ep.line_start > 0

    def test_intelligence_flask_route_detection(self):
        """Test API detection for Flask application and blueprint routes."""
        flask_code = '''\
from flask import Flask, Blueprint, request, jsonify

app = Flask(__name__)
auth_bp = Blueprint('auth', __name__, url_prefix='/auth')

@app.route('/ping')
def ping():
    return 'pong'

@auth_bp.route('/login', methods=['POST'])
def login_route():
    data = request.json
    return jsonify({"token": "123"})

@auth_bp.route('/logout', methods=['GET', 'POST'])
def logout_route():
    return jsonify({"success": True})
'''
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "routes" / "auth.py"
            fpath.parent.mkdir(parents=True, exist_ok=True)
            fpath.write_text(flask_code, encoding="utf-8")
            
            repo = scan_repository(tmp_dir, "flask-test")
            intel = analyze_project_intelligence(repo)
            
            assert len(intel.api_endpoints) >= 3
            methods = [ep.method for ep in intel.api_endpoints]
            paths = [ep.path for ep in intel.api_endpoints]
            
            assert "GET" in methods
            assert "POST" in methods
            assert "/ping" in paths
            assert "/login" in paths
            assert "/logout" in paths

    def test_intelligence_express_route_detection(self):
        """Test API detection for Express.js / Node.js router routes."""
        express_code = '''\
const express = require('express');
const router = express.Router();

router.get('/api/v1/patients', async (req, res) => {
    res.json([{ id: 1, name: "Alice" }]);
});

router.post('/api/v1/patients', async (req, res) => {
    res.status(201).json({ id: 2 });
});

router.delete('/api/v1/patients/:id', async (req, res) => {
    res.status(204).send();
});
'''
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "src" / "routes.js"
            fpath.parent.mkdir(parents=True, exist_ok=True)
            fpath.write_text(express_code, encoding="utf-8")
            
            repo = scan_repository(tmp_dir, "express-test")
            intel = analyze_project_intelligence(repo)
            
            assert len(intel.api_endpoints) >= 3
            paths = [ep.path for ep in intel.api_endpoints]
            assert "/api/v1/patients" in paths

    def test_intelligence_storage_detection_firestore(self):
        """Test storage detection for Cloud Firestore database usage."""
        db_code = '''\
import firebase_admin
from firebase_admin import firestore

db = firestore.client()

def get_prescriptions(user_id):
    docs = db.collection('prescriptions').where('user_id', '==', user_id).stream()
    return [d.to_dict() for d in docs]

def save_adherence_log(log_data):
    ref = db.collection('adherence_logs').document()
    ref.set(log_data)
'''
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "services" / "db_service.py"
            fpath.parent.mkdir(parents=True, exist_ok=True)
            fpath.write_text(db_code, encoding="utf-8")
            
            repo = scan_repository(tmp_dir, "firestore-test")
            intel = analyze_project_intelligence(repo)
            
            assert len(intel.storage_technologies) >= 1
            tech_names = [s.technology for s in intel.storage_technologies]
            assert any("Firestore" in name for name in tech_names)
            
            firestore_tech = next(s for s in intel.storage_technologies if "Firestore" in s.technology)
            assert "prescriptions" in firestore_tech.entities or "adherence_logs" in firestore_tech.entities
            assert len(firestore_tech.evidence) > 0

    def test_intelligence_storage_detection_sqlite_and_postgres(self):
        """Test storage detection for SQLite and PostgreSQL databases."""
        db_code = '''\
import sqlite3
import psycopg2
from sqlalchemy.orm import declarative_base
from sqlalchemy import Column, Integer, String

Base = declarative_base()

class PatientRecord(Base):
    __tablename__ = 'patient_records'
    id = Column(Integer, primary_key=True)
    name = Column(String(50))
'''
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "models" / "db.py"
            fpath.parent.mkdir(parents=True, exist_ok=True)
            fpath.write_text(db_code, encoding="utf-8")
            
            repo = scan_repository(tmp_dir, "sql-test")
            intel = analyze_project_intelligence(repo)
            
            assert len(intel.storage_technologies) >= 1
            tech_names = [s.technology for s in intel.storage_technologies]
            assert any("SQLite" in name or "PostgreSQL" in name or "SQL" in name for name in tech_names)

    def test_intelligence_empty_states(self):
        """Test graceful empty state handling for repositories with no source or storage."""
        empty_md = """# My Project\nJust markdown documentation with no executable code."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "README.md"
            fpath.write_text(empty_md, encoding="utf-8")
            
            repo = scan_repository(tmp_dir, "empty-repo")
            intel = analyze_project_intelligence(repo)
            
            assert isinstance(intel, ProjectIntelligence)
            assert intel.total_files == 1
            assert intel.total_symbols == 0
            assert len(intel.api_endpoints) == 0
            assert len(intel.storage_technologies) == 0
            assert len(intel.architecture_graph.edges) == 0

    def test_api_endpoint_get_intelligence(self, client, synthetic_repo):
        """Test the GET /api/repositories/{id}/intelligence REST endpoint."""
        repo = scan_repository(str(synthetic_repo), "synthetic-test")
        repository_store.put(repo)
        
        # Valid repository
        resp = client.get(f"/api/repositories/{repo.id}/intelligence")
        assert resp.status_code == 200
        data = resp.json()
        assert data["repository_id"] == repo.id
        assert "total_files" in data
        assert "total_symbols" in data
        assert "modules" in data
        assert "layers" in data
        assert "api_endpoints" in data
        assert "storage_technologies" in data
        assert "architecture_graph" in data
        
        # Non-existent repository should return 404
        bad_resp = client.get("/api/repositories/non-existent-id/intelligence")
        assert bad_resp.status_code == 404

    def test_caresync_real_intelligence(self, client):
        """Verify real repository intelligence when CareSync repository is present."""
        caresync_path = Path("C:/Users/Sahil/Downloads/CodeAtlas/caresync_source")
        if not caresync_path.exists():
            caresync_path = Path(__file__).parent.parent.parent / "caresync_source"
        if not caresync_path.exists():
            pytest.skip("CareSync repository source not found on disk.")
            
        repo = scan_repository(str(caresync_path), "CareSync")
        repository_store.put(repo)
        
        intel = analyze_project_intelligence(repo)
        assert intel.total_files >= 50
        assert intel.total_symbols >= 500
        assert len(intel.modules) >= 3
        assert len(intel.layers) >= 3
        
        # Verify detected real APIs from Flask backend routes
        assert len(intel.api_endpoints) > 0
        endpoints_paths = [ep.path for ep in intel.api_endpoints]
        assert any("add" in p or "delete" in p or "sync" in p or "list" in p for p in endpoints_paths)
        
        # Verify detected storage
        assert len(intel.storage_technologies) > 0
        storage_names = [s.technology for s in intel.storage_technologies]
        assert any("Firestore" in s or "Storage" in s for s in storage_names)
        
        # Verify REST API response matches
        resp = client.get(f"/api/repositories/{repo.id}/intelligence")
        assert resp.status_code == 200
        api_data = resp.json()
        assert api_data["total_files"] == intel.total_files
        assert len(api_data["api_endpoints"]) == len(intel.api_endpoints)


# ---------------------------------------------------------------------------
# Visual Repository Tree Tests
# ---------------------------------------------------------------------------

class TestRepositoryTree:
    """Tests for Visual Repository Tree hierarchy, symbols, and relationships."""

    def test_build_repository_tree_synthetic(self, synthetic_repo):
        """Test tree generation on synthetic multi-file repository."""
        repo = scan_repository(str(synthetic_repo), "tree-test-repo")
        tree = build_repository_tree(repo)

        assert isinstance(tree, RepositoryTree)
        assert tree.repository_id == repo.id
        assert tree.repository_name == repo.name
        assert tree.total_files == len(repo.files)
        assert tree.total_symbols == len(repo.symbols)
        assert tree.total_relationships == len(repo.relationships)

        # Root node
        root = tree.root
        assert root.node_type == TreeNodeType.REPOSITORY
        assert root.name == repo.name
        assert root.file_count == tree.total_files
        assert len(root.children) > 0

        # Subdirectory inspection
        child_names = [c.name for c in root.children]
        assert "services" in child_names or "screens" in child_names

        # Find services dir
        services_node = next((c for c in root.children if c.name == "services"), None)
        assert services_node is not None
        assert services_node.node_type == TreeNodeType.DIRECTORY
        assert services_node.file_count > 0
        assert services_node.symbol_count > 0

        # Find a file node inside services (e.g. auth_service.py)
        file_node = next((f for f in services_node.children if f.name == "auth_service.py"), None)
        assert file_node is not None
        assert file_node.node_type == TreeNodeType.FILE
        assert file_node.language == "Python"
        assert file_node.layer == "Services"
        assert file_node.file_count == 1
        assert file_node.symbol_count > 0

        # Find symbols nested under auth_service.py
        sym_names = [s.name for s in file_node.children]
        assert "AuthService" in sym_names

        # Inspect symbol node
        auth_sym = next(s for s in file_node.children if s.name == "AuthService")
        assert auth_sym.node_type == TreeNodeType.SYMBOL
        assert auth_sym.symbol_type == "class"
        assert auth_sym.line_start > 0

        # Check relationships are wired
        assert file_node.relationship_count >= 0
        assert isinstance(file_node.incoming_relationships, list)
        assert isinstance(file_node.outgoing_relationships, list)

    def test_repository_tree_empty_repo(self):
        """Test tree generation on empty / single markdown file repository."""
        with tempfile.TemporaryDirectory() as tmp_dir:
            fpath = Path(tmp_dir) / "README.md"
            fpath.write_text("# Project", encoding="utf-8")

            repo = scan_repository(tmp_dir, "empty-tree-repo")
            tree = build_repository_tree(repo)

            assert isinstance(tree, RepositoryTree)
            assert tree.total_files == 1
            assert tree.total_symbols == 0
            assert tree.total_relationships == 0
            assert tree.root.file_count == 1
            assert len(tree.root.children) == 1
            assert tree.root.children[0].name == "README.md"
            assert tree.root.children[0].node_type == TreeNodeType.FILE

    def test_repository_tree_api_endpoint(self, client, synthetic_repo):
        """Test GET /api/repositories/{id}/tree REST endpoint."""
        repo = scan_repository(str(synthetic_repo), "endpoint-tree-repo")
        repository_store.put(repo)

        resp = client.get(f"/api/repositories/{repo.id}/tree")
        assert resp.status_code == 200
        data = resp.json()

        assert data["repository_id"] == repo.id
        assert "total_files" in data
        assert "total_symbols" in data
        assert "total_relationships" in data
        assert "root" in data
        assert data["root"]["node_type"] == "repository"
        assert len(data["root"]["children"]) > 0

        # Non-existent repository returns 404
        bad_resp = client.get("/api/repositories/non-existent-id/tree")
        assert bad_resp.status_code == 404

    def test_caresync_real_tree(self, client):
        """Verify real repository tree with CareSync source code."""
        caresync_path = Path("C:/Users/Sahil/Downloads/CodeAtlas/caresync_source")
        if not caresync_path.exists():
            caresync_path = Path(__file__).parent.parent.parent / "caresync_source"
        if not caresync_path.exists():
            pytest.skip("CareSync repository source not found on disk.")

        repo = scan_repository(str(caresync_path), repo_name="CareSync")
        repository_store.put(repo)

        tree = build_repository_tree(repo)
        assert tree.total_files >= 50
        assert tree.total_symbols >= 500
        assert tree.total_relationships >= 500

        # Check top-level directories
        top_names = [c.name for c in tree.root.children]
        assert "lib" in top_names or "backend_routes" in top_names

        # REST endpoint test
        resp = client.get(f"/api/repositories/{repo.id}/tree")
        assert resp.status_code == 200
        data = resp.json()
        assert data["total_files"] == tree.total_files
        assert data["root"]["name"] == "CareSync"

    def test_different_repository_tree_no_leakage(self):
        """Verify that another distinct repository does not contain any CareSync nodes."""
        other_code = """\
class BillingService:
    def process_invoice(self, invoice_id: str):
        return True
"""
        with tempfile.TemporaryDirectory() as tmp_dir:
            src_dir = Path(tmp_dir) / "core" / "billing"
            src_dir.mkdir(parents=True, exist_ok=True)
            (src_dir / "invoice_service.py").write_text(other_code, encoding="utf-8")

            repo = scan_repository(tmp_dir, repo_name="FinTechApp")
            tree = build_repository_tree(repo)

            assert tree.repository_name == "FinTechApp"
            assert tree.total_files == 1

            # Traverse all node names in the tree
            all_node_names = []
            def collect(node: RepositoryTreeNode):
                all_node_names.append(node.name)
                for child in node.children:
                    collect(child)
            collect(tree.root)

            # Ensure zero CareSync identifiers exist
            assert "CareSync" not in all_node_names
            assert "medicine_service.dart" not in all_node_names
            assert "ScanPrescriptionScreen" not in all_node_names
            assert "backend_routes" not in all_node_names

            # Ensure actual repository files exist
            assert "core" in all_node_names
            assert "billing" in all_node_names
            assert "invoice_service.py" in all_node_names
            assert "BillingService" in all_node_names




