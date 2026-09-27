import axios from 'axios';
import {
  Repository, FeatureTrace, UploadResponse, FileDetail, ImpactAnalysis, RegressionAnalysis,
  ProjectIntelligence, RepositoryTree
} from '../types';

// In development, Vite proxies /api/* → http://localhost:8000
// In production builds, set VITE_API_URL to override.
const BASE = (import.meta as unknown as { env: Record<string, string> }).env?.VITE_API_URL ?? '';

const api = axios.create({ baseURL: BASE });

export const repositoryApi = {
  /** Upload a ZIP file */
  uploadZip: async (file: File, name?: string): Promise<UploadResponse> => {
    const form = new FormData();
    form.append('file', file);
    if (name) form.append('name', name);
    const resp = await api.post('/api/repositories/upload', form, {
      headers: { 'Content-Type': 'multipart/form-data' },
    });
    return resp.data;
  },

  /** Add a local path (dev mode) */
  addLocal: async (path: string, name?: string): Promise<UploadResponse> => {
    const resp = await api.post('/api/repositories/local', { path, name });
    return resp.data;
  },

  /** List all repositories */
  list: async (): Promise<Repository[]> => {
    const resp = await api.get('/api/repositories');
    return resp.data;
  },

  /** Get repository metadata + files */
  get: async (id: string): Promise<Repository> => {
    const resp = await api.get(`/api/repositories/${id}`);
    return resp.data;
  },

  /** Get repository intelligence overview */
  getIntelligence: async (id: string): Promise<ProjectIntelligence> => {
    const resp = await api.get(`/api/repositories/${id}/intelligence`);
    return resp.data;
  },

  /** Get hierarchical visual repository tree */
  getTree: async (id: string): Promise<RepositoryTree> => {
    const resp = await api.get(`/api/repositories/${id}/tree`);
    return resp.data;
  },

  /** Re-trigger analysis */
  analyze: async (id: string): Promise<void> => {
    await api.post(`/api/repositories/${id}/analyze`);
  },

  /** Run Feature Tracer */
  trace: async (id: string, query: string): Promise<FeatureTrace> => {
    const resp = await api.post(`/api/repositories/${id}/trace`, { query });
    return resp.data;
  },

  /** Run Change Impact Radar */
  impact: async (id: string, target: string, maxDepth = 3): Promise<ImpactAnalysis> => {
    const resp = await api.post(`/api/repositories/${id}/impact`, {
      target,
      query: target,
      max_depth: maxDepth,
      depth: maxDepth,
    });
    return resp.data;
  },

  /** Run Regression Investigator */
  regression: async (
    id: string,
    params: { diff?: string; query?: string; changed_files?: string[]; max_depth?: number; depth?: number }
  ): Promise<RegressionAnalysis> => {
    const depthVal = params.max_depth ?? params.depth ?? 3;
    const resp = await api.post(`/api/repositories/${id}/regression`, {
      ...params,
      max_depth: depthVal,
      depth: depthVal,
    });
    return resp.data;
  },

  /** Get file content + symbols */
  getFile: async (repoId: string, filePath: string): Promise<FileDetail> => {
    const encoded = encodeURIComponent(filePath).replace(/%2F/g, '/');
    const resp = await api.get(`/api/repositories/${repoId}/files/${encoded}`);
    return resp.data;
  },

  /** Delete repository */
  delete: async (id: string): Promise<void> => {
    await api.delete(`/api/repositories/${id}`);
  },
};
