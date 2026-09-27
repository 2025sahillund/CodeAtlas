"""
Repository API Routes.

Endpoints:
  POST  /api/repositories/upload          — upload ZIP or specify local path
  POST  /api/repositories/{id}/analyze    — scan & index the repository
  GET   /api/repositories/{id}            — get repository metadata
  GET   /api/repositories                 — list all repositories
  POST  /api/repositories/{id}/trace      — run Feature Tracer
  GET   /api/repositories/{id}/files/{file_id} — get file content + symbols
  DELETE /api/repositories/{id}           — remove repository
"""

from __future__ import annotations

import os
import shutil
import tempfile
import zipfile
from pathlib import Path
from typing import Any, Optional

from fastapi import APIRouter, HTTPException, UploadFile, File, Form, BackgroundTasks
from fastapi.responses import JSONResponse
from pydantic import BaseModel

from app.models.repository import Repository, RepositoryStatus
from app.services.repository_store import repository_store
from app.analyzers.repository_scanner import scan_repository
from app.services.feature_tracer import trace_feature
from app.services.impact_radar import analyze_impact
from app.services.regression_investigator import investigate_regression
from app.services.project_intelligence import analyze_project_intelligence, build_repository_tree

router = APIRouter()

# Persistent upload directory (survives restarts within session)
UPLOAD_DIR = Path(__file__).parent.parent.parent / "uploads"
UPLOAD_DIR.mkdir(parents=True, exist_ok=True)


# ---------------------------------------------------------------------------
# Request / Response schemas
# ---------------------------------------------------------------------------

class LocalPathRequest(BaseModel):
    path: str
    name: Optional[str] = None


class TraceRequest(BaseModel):
    query: str


class ImpactRequest(BaseModel):
    target: Optional[str] = None
    query: Optional[str] = None
    max_depth: Optional[int] = None
    depth: Optional[int] = None


class RegressionRequest(BaseModel):
    diff: Optional[str] = None
    query: Optional[str] = None
    changed_files: Optional[list[str]] = None
    max_depth: Optional[int] = None
    depth: Optional[int] = None


class RepositorySummary(BaseModel):
    id: str
    name: str
    status: str
    total_files: int
    source_files: int
    languages: dict[str, int]
    entry_points: list[str]
    error: Optional[str] = None


# ---------------------------------------------------------------------------
# Helper: build summary response
# ---------------------------------------------------------------------------

def _repo_summary(repo: Repository) -> dict[str, Any]:
    return {
        "id": repo.id,
        "name": repo.name,
        "status": repo.status.value,
        "total_files": repo.total_files,
        "source_files": repo.source_files,
        "languages": repo.languages,
        "entry_points": repo.entry_points[:10],
        "test_files_count": len(repo.test_files),
        "dependency_files": repo.dependency_files,
        "symbol_count": len(repo.symbols),
        "relationship_count": len(repo.relationships),
        "error": repo.error,
    }


def _repo_files_summary(repo: Repository) -> list[dict[str, Any]]:
    result = []
    for fp, sf in repo.files.items():
        result.append({
            "path": sf.path,
            "language": sf.language,
            "size_bytes": sf.size_bytes,
            "line_count": sf.line_count,
            "is_entry_point": sf.is_entry_point,
            "is_test": sf.is_test,
            "is_config": sf.is_config,
            "symbol_count": len(sf.symbols),
            "import_count": len(sf.imports),
        })
    return sorted(result, key=lambda x: x["path"])


# ---------------------------------------------------------------------------
# Background task: scan repository
# ---------------------------------------------------------------------------

def _scan_in_background(repo_id: str, root_path: str, repo_name: str) -> None:
    """Performs repository scanning and updates the store when done."""
    try:
        repo = scan_repository(
            repo_root=root_path,
            repo_id=repo_id,
            repo_name=repo_name,
        )
        repository_store.put(repo)
    except Exception as e:
        existing = repository_store.get(repo_id)
        if existing:
            existing.status = RepositoryStatus.ERROR
            existing.error = str(e)
            repository_store.put(existing)


# ---------------------------------------------------------------------------
# Endpoints
# ---------------------------------------------------------------------------

@router.get("/repositories")
async def list_repositories():
    """List all uploaded/indexed repositories."""
    repos = repository_store.list_all()
    return [_repo_summary(r) for r in repos]


@router.post("/repositories/upload")
async def upload_repository(
    background_tasks: BackgroundTasks,
    file: Optional[UploadFile] = File(None),
    name: Optional[str] = Form(None),
):
    """
    Upload a repository as a ZIP file.
    The ZIP is extracted and the repository is scanned asynchronously.
    """
    if file is None:
        raise HTTPException(status_code=400, detail="No file uploaded.")

    if not file.filename:
        raise HTTPException(status_code=400, detail="File has no name.")

    # Security: only accept ZIP files
    if not file.filename.lower().endswith(".zip"):
        raise HTTPException(status_code=400, detail="Only .zip files are accepted.")

    # Save uploaded file to disk
    tmp_zip = UPLOAD_DIR / f"{file.filename}"
    try:
        contents = await file.read()
        tmp_zip.write_bytes(contents)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to save upload: {e}")

    # Extract ZIP to a dedicated directory
    repo_name = name or Path(file.filename).stem
    extract_dir = UPLOAD_DIR / repo_name
    if extract_dir.exists():
        shutil.rmtree(extract_dir)
    extract_dir.mkdir(parents=True, exist_ok=True)

    try:
        with zipfile.ZipFile(tmp_zip, "r") as zf:
            # Security: prevent zip-slip attacks
            for member in zf.namelist():
                member_path = Path(extract_dir / member).resolve()
                if not str(member_path).startswith(str(extract_dir.resolve())):
                    raise HTTPException(
                        status_code=400,
                        detail=f"Unsafe path in ZIP: {member}",
                    )
            zf.extractall(extract_dir)
    except zipfile.BadZipFile:
        raise HTTPException(status_code=400, detail="Invalid ZIP file.")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Extraction failed: {e}")
    finally:
        tmp_zip.unlink(missing_ok=True)

    # Find the actual repository root (handle top-level folder in ZIP)
    root_path = _find_repo_root(extract_dir)

    # Create repository record
    repo = repository_store.create(name=repo_name, root_path=str(root_path))

    # Schedule async scan
    background_tasks.add_task(
        _scan_in_background, repo.id, str(root_path), repo_name
    )

    return {
        "id": repo.id,
        "name": repo_name,
        "status": "scanning",
        "message": "Repository uploaded. Scanning in progress.",
    }


@router.post("/repositories/local")
async def add_local_repository(
    background_tasks: BackgroundTasks,
    request: LocalPathRequest,
):
    """
    Add a local repository by path (for local development use).
    The path must exist on the server.
    """
    root = Path(request.path)
    if not root.exists() or not root.is_dir():
        raise HTTPException(
            status_code=400,
            detail=f"Path does not exist or is not a directory: {request.path}",
        )

    repo_name = request.name or root.name
    repo = repository_store.create(name=repo_name, root_path=str(root.resolve()))

    background_tasks.add_task(
        _scan_in_background, repo.id, str(root.resolve()), repo_name
    )

    return {
        "id": repo.id,
        "name": repo_name,
        "status": "scanning",
        "message": "Local repository added. Scanning in progress.",
    }


@router.post("/repositories/{repo_id}/analyze")
async def analyze_repository(
    repo_id: str,
    background_tasks: BackgroundTasks,
):
    """
    Re-trigger analysis for an already-uploaded repository.
    """
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    repo.status = RepositoryStatus.SCANNING
    repository_store.put(repo)

    background_tasks.add_task(
        _scan_in_background, repo.id, repo.root_path, repo.name
    )

    return {"id": repo_id, "status": "scanning", "message": "Re-analysis started."}


@router.get("/repositories/{repo_id}")
async def get_repository(repo_id: str):
    """Get repository metadata and file list."""
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")
    return {
        **_repo_summary(repo),
        "files": _repo_files_summary(repo),
    }


@router.get("/repositories/{repo_id}/intelligence")
async def get_repository_intelligence(repo_id: str):
    """
    Get comprehensive Repository Intelligence: architecture summary,
    module explorer, API endpoints, storage technologies, and dynamic architecture map.
    """
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    if repo.status != RepositoryStatus.INDEXED:
        raise HTTPException(
            status_code=400,
            detail=f"Repository is not ready for analysis (status: {repo.status.value}). "
                   "Wait for indexing to complete.",
        )

    try:
        intel = analyze_project_intelligence(repo)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate repository intelligence: {e}")

    return intel.model_dump()


@router.get("/repositories/{repo_id}/tree")
async def get_repository_tree(repo_id: str):
    """
    Get the hierarchical visual Repository Tree with nested directories, files,
    symbols, layers, and cross-referenced incoming/outgoing relationships.
    """
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    if repo.status != RepositoryStatus.INDEXED:
        raise HTTPException(
            status_code=400,
            detail=f"Repository is not ready for analysis (status: {repo.status.value}). "
                   "Wait for indexing to complete.",
        )

    try:
        tree = build_repository_tree(repo)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate repository tree: {e}")

    return tree.model_dump()


@router.post("/repositories/{repo_id}/trace")
async def trace_repository_feature(repo_id: str, request: TraceRequest):
    """
    Run the Feature Tracer for the given query against a repository.
    """
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    if repo.status != RepositoryStatus.INDEXED:
        raise HTTPException(
            status_code=400,
            detail=f"Repository is not ready for analysis (status: {repo.status.value}). "
                   "Wait for indexing to complete.",
        )

    if not request.query or not request.query.strip():
        raise HTTPException(status_code=400, detail="Query cannot be empty.")

    try:
        result = trace_feature(request.query.strip(), repo)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Feature trace failed: {e}")

    return result.model_dump()


@router.post("/repositories/{repo_id}/impact")
async def analyze_repository_impact(repo_id: str, request: ImpactRequest):
    """
    Run Change Impact Radar for the given target against a repository.
    """
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    if repo.status != RepositoryStatus.INDEXED:
        raise HTTPException(
            status_code=400,
            detail=f"Repository is not ready for analysis (status: {repo.status.value}). "
                   "Wait for indexing to complete.",
        )

    target_val = (request.target or request.query or "").strip()
    depth_val = request.max_depth if request.max_depth is not None else (request.depth if request.depth is not None else 3)

    if not target_val:
        raise HTTPException(status_code=400, detail="Target or query cannot be empty.")

    try:
        result = analyze_impact(
            target_val,
            repo,
            max_depth=depth_val,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Impact analysis failed: {e}")

    return result.model_dump()


@router.post("/repositories/{repo_id}/regression")
async def investigate_repository_regression(repo_id: str, request: RegressionRequest):
    """
    Run Regression Investigator for a diff, changed files, or query against a repository.
    """
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    if repo.status != RepositoryStatus.INDEXED:
        raise HTTPException(
            status_code=400,
            detail=f"Repository is not ready for analysis (status: {repo.status.value}). "
                   "Wait for indexing to complete.",
        )

    has_diff = bool(request.diff and request.diff.strip())
    has_query = bool(request.query and request.query.strip())
    has_files = bool(request.changed_files and len(request.changed_files) > 0)

    if not has_diff and not has_query and not has_files:
        raise HTTPException(status_code=400, detail="Must provide diff, query, or changed_files.")

    depth_val = request.max_depth if request.max_depth is not None else (request.depth if request.depth is not None else 3)

    try:
        result = investigate_regression(
            repo=repo,
            diff_text=request.diff.strip() if request.diff else None,
            query=request.query.strip() if request.query else None,
            changed_file_paths=request.changed_files,
            max_depth=depth_val,
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Regression investigation failed: {e}")

    return result.model_dump()


@router.get("/repositories/{repo_id}/files/{file_path:path}")
async def get_file(repo_id: str, file_path: str):
    """Get content, symbols, and imports for a specific file."""
    repo = repository_store.get(repo_id)
    if not repo:
        raise HTTPException(status_code=404, detail="Repository not found.")

    src = repo.files.get(file_path)
    if not src:
        raise HTTPException(status_code=404, detail=f"File not found: {file_path}")

    return {
        "path": src.path,
        "language": src.language,
        "size_bytes": src.size_bytes,
        "line_count": src.line_count,
        "is_entry_point": src.is_entry_point,
        "is_test": src.is_test,
        "symbols": [s.model_dump() for s in src.symbols],
        "imports": [i.model_dump() for i in src.imports],
        "content": src._content,  # null if file was too large or binary
    }


@router.delete("/repositories/{repo_id}")
async def delete_repository(repo_id: str):
    """Remove a repository from the store."""
    if not repository_store.delete(repo_id):
        raise HTTPException(status_code=404, detail="Repository not found.")
    return {"deleted": True, "id": repo_id}


# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------

def _find_repo_root(extract_dir: Path) -> Path:
    """
    If the ZIP contained a single top-level directory, return that directory
    as the repository root. Otherwise return the extraction directory itself.
    """
    entries = [e for e in extract_dir.iterdir() if not e.name.startswith(".")]
    if len(entries) == 1 and entries[0].is_dir():
        return entries[0]
    return extract_dir
