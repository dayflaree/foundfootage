export interface Env {
  DB: D1Database;
  ADMIN_TOKEN?: string;
  SERVER_INGEST_TOKEN?: string;
}

export interface Session {
  steamid64: string;
  tokenHash: string;
}

export interface Vector3 {
  x: number;
  y: number;
  z: number;
}

export interface PublicMessage {
  id: string;
  body: string;
  position: Vector3;
  normal: Vector3;
  created_at: number;
}
