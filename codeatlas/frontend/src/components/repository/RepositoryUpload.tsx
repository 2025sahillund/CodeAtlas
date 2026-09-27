import React, { useState, useRef, useCallback } from 'react';
import { Repository } from '../../types';
import { repositoryApi } from '../../services/api';

interface Props {
  onReady: (repo: Repository) => void;
}

export default function RepositoryUpload({ onReady }: Props) {
  const [isDragging, setIsDragging] = useState(false);
  const [isUploading, setIsUploading] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [localPath, setLocalPath] = useState('');
  const [mode, setMode] = useState<'zip' | 'local'>('zip');
  const fileRef = useRef<HTMLInputElement>(null);

  const handleFile = useCallback(async (file: File) => {
    if (!file.name.endsWith('.zip')) {
      setError('Only ZIP files are accepted.');
      return;
    }
    setError(null);
    setIsUploading(true);
    try {
      const result = await repositoryApi.uploadZip(file);
      // Fetch the initial repo record
      const repo = await repositoryApi.get(result.id);
      onReady(repo);
    } catch (e: any) {
      setError(e?.response?.data?.detail ?? e?.message ?? 'Upload failed.');
    } finally {
      setIsUploading(false);
    }
  }, [onReady]);

  const handleLocalPath = async () => {
    if (!localPath.trim()) return;
    setError(null);
    setIsUploading(true);
    try {
      const result = await repositoryApi.addLocal(localPath.trim());
      const repo = await repositoryApi.get(result.id);
      onReady(repo);
    } catch (e: any) {
      setError(e?.response?.data?.detail ?? e?.message ?? 'Failed to add local repository.');
    } finally {
      setIsUploading(false);
    }
  };

  const onDrop = (e: React.DragEvent) => {
    e.preventDefault();
    setIsDragging(false);
    const file = e.dataTransfer.files?.[0];
    if (file) handleFile(file);
  };

  return (
    <div>
      <div className="page-header">
        <div className="page-title">Add Repository</div>
        <div className="page-subtitle">
          Upload a repository ZIP or point to a local path to begin analysis.
        </div>
      </div>

      {/* Mode tabs */}
      <div className="flex-row mb-16">
        <button
          className={`btn ${mode === 'zip' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setMode('zip')}
        >
          📦 Upload ZIP
        </button>
        <button
          className={`btn ${mode === 'local' ? 'btn-primary' : 'btn-secondary'}`}
          onClick={() => setMode('local')}
        >
          📂 Local Path
        </button>
      </div>

      {mode === 'zip' && (
        <div
          className={`upload-area ${isDragging ? 'dragover' : ''}`}
          onDragOver={e => { e.preventDefault(); setIsDragging(true); }}
          onDragLeave={() => setIsDragging(false)}
          onDrop={onDrop}
          onClick={() => fileRef.current?.click()}
        >
          <input
            ref={fileRef}
            type="file"
            accept=".zip"
            style={{ display: 'none' }}
            onChange={e => { const f = e.target.files?.[0]; if (f) handleFile(f); }}
          />
          <div className="upload-area__icon">
            {isUploading ? <span className="spinner" /> : '📦'}
          </div>
          <div className="upload-area__title">
            {isUploading ? 'Uploading…' : 'Drop repository ZIP here'}
          </div>
          <div className="upload-area__subtitle">
            or click to browse files
          </div>
          <div className="upload-area__hint">
            Accepts .zip files. The repository will be extracted and indexed automatically.
          </div>
        </div>
      )}

      {mode === 'local' && (
        <div className="card">
          <div className="card__body">
            <div className="input-group mb-12">
              <label className="input-label">Repository Path (server-side)</label>
              <input
                className="input"
                placeholder="e.g.  C:\Users\Sahil\care-sync-25A15"
                value={localPath}
                onChange={e => setLocalPath(e.target.value)}
                onKeyDown={e => e.key === 'Enter' && handleLocalPath()}
              />
            </div>
            <button
              className="btn btn-primary"
              onClick={handleLocalPath}
              disabled={isUploading || !localPath.trim()}
            >
              {isUploading ? <><span className="spinner" /> Scanning…</> : 'Analyze Repository'}
            </button>
          </div>
        </div>
      )}

      {error && (
        <div className="alert error mt-12">
          <span>⚠️</span>
          <span>{error}</span>
        </div>
      )}

      {/* Info section */}
      <div className="card mt-20">
        <div className="card__header">
          <span className="card__title">What CodeAtlas Does</span>
        </div>
        <div className="card__body">
          <div className="flex-col">
            {[
              ['🔍', 'Scans repository files, symbols, imports, and relationships'],
              ['🗺', 'Builds a searchable knowledge model of your codebase'],
              ['✨', 'Lets you trace features through the codebase with natural language'],
              ['📎', 'Shows real source evidence — no fabricated results'],
              ['🔒', 'Runs locally — your code stays private'],
            ].map(([icon, text]) => (
              <div key={text} className="flex-row" style={{ alignItems: 'flex-start' }}>
                <span style={{ fontSize: '16px', flexShrink: 0 }}>{icon}</span>
                <span className="text-sm" style={{ color: 'var(--color-text-muted)' }}>{text}</span>
              </div>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
