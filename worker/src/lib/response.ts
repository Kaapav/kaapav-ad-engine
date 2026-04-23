import type { Context } from 'hono';

export function ok<T>(c: Context, data: T, meta?: any, status = 200) {
  return c.json({ success: true, data, ...(meta ? { meta } : {}) }, status as any);
}

export function fail(c: Context, status: number, error: string, details?: any) {
  return c.json(
    { success: false, error, ...(details ? { details } : {}) },
    status as any,
  );
}