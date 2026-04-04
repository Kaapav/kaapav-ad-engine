import { createMiddleware } from 'hono/factory';
import type { AppEnv } from '../types';

// ─── API Auth (API key or session token) ───
export const apiAuth = createMiddleware<AppEnv>(async (c, next) => {
  // Option 1: X-API-Key header
  const apiKey = c.req.header('X-API-Key');
  if (apiKey && apiKey === c.env.API_SECRET_KEY) {
    c.set('authenticated', true);
    await next();
    return;
  }

  // Option 2: Bearer session token
  const authHeader = c.req.header('Authorization');
  if (authHeader?.startsWith('Bearer ')) {
    const token = authHeader.slice(7);
    const session = await c.env.SESSIONS.get(token);
    if (session) {
      c.set('authenticated', true);
      await next();
      return;
    }
  }

  return c.json({ success: false, error: 'Unauthorized' }, 401);
});

// ─── Meta Webhook Signature Verification ───
export async function verifyMetaSignature(
  body: string,
  signature: string | undefined,
  appSecret: string
): Promise<boolean> {
  if (!signature) return false;

  const expectedSig = signature.startsWith('sha256=')
    ? signature.slice(7)
    : signature;

  const encoder = new TextEncoder();
  const key = await crypto.subtle.importKey(
    'raw',
    encoder.encode(appSecret),
    { name: 'HMAC', hash: 'SHA-256' },
    false,
    ['sign']
  );

  const sigBuffer = await crypto.subtle.sign('HMAC', key, encoder.encode(body));
  const hexSig = Array.from(new Uint8Array(sigBuffer))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');

  return hexSig === expectedSig;
}