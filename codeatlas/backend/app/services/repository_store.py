"""
Repository Store Service.

In-memory store for indexed repositories during the server session.
In production, this would be backed by a database.
"""

from __future__ import annotations

import uuid
from pathlib import Path
from typing import Optional

from app.models.repository import Repository, RepositoryStatus


class RepositoryStore:
    """
    In-memory registry of all currently indexed repositories.
    Thread-safety note: for production use, add asyncio.Lock.
    """

    def __init__(self) -> None:
        self._repos: dict[str, Repository] = {}

    def create(self, name: str, root_path: str) -> Repository:
        rid = str(uuid.uuid4())
        repo = Repository(
            id=rid,
            name=name,
            status=RepositoryStatus.UPLOADED,
            root_path=root_path,
        )
        self._repos[rid] = repo
        return repo

    def get(self, repo_id: str) -> Optional[Repository]:
        return self._repos.get(repo_id)

    def put(self, repo: Repository) -> None:
        self._repos[repo.id] = repo

    def list_all(self) -> list[Repository]:
        return list(self._repos.values())

    def delete(self, repo_id: str) -> bool:
        if repo_id in self._repos:
            del self._repos[repo_id]
            return True
        return False


# Module-level singleton
repository_store = RepositoryStore()
