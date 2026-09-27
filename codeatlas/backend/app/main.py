"""
CodeAtlas FastAPI Application — Main Entry Point.
"""

from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api import repositories

app = FastAPI(
    title="CodeAtlas API",
    description="AI Engineering Intelligence — Understand before you change.",
    version="1.0.0",
)

# CORS — allow the React frontend in development
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # tighten in production
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Mount routers
app.include_router(repositories.router, prefix="/api")


@app.get("/")
async def root():
    return {
        "product": "CodeAtlas",
        "tagline": "Understand before you change.",
        "version": "1.0.0",
        "docs": "/docs",
    }


@app.get("/health")
async def health():
    return {"status": "ok"}
