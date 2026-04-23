import type { Bindings } from '../types';

const TOKEN_URL = 'https://oauth2.googleapis.com/token';
const CACHE_KEY = 'google:sheets_access_token:v1';

function base64UrlEncode(input: ArrayBuffer | Uint8Array | string): string {
  let bytes: Uint8Array;

  if (typeof input === 'string') {
    bytes = new TextEncoder().encode(input);
  } else if (input instanceof Uint8Array) {
    bytes = input;
  } else {
    bytes = new Uint8Array(input);
  }

  let bin = '';
  for (let i = 0; i < bytes.length; i++) bin += String.fromCharCode(bytes[i]);

  const b64 = btoa(bin);
  return b64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function pemToArrayBuffer(pem: string): ArrayBuffer {
  const clean = pem
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\s+/g, '');

  const bin = atob(clean);
  const bytes = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
  return bytes.buffer;
}

async function importPrivateKey(pem: string): Promise<CryptoKey> {
  const keyData = pemToArrayBuffer(pem);
  return crypto.subtle.importKey(
    'pkcs8',
    keyData,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
}

async function signJwtRS256(privateKeyPem: string, header: any, payload: any): Promise<string> {
  // Cloudflare secrets sometimes store newlines as "\n"
  const fixedPem = privateKeyPem.includes('\\n')
    ? privateKeyPem.replace(/\\n/g, '\n')
    : privateKeyPem;

  const key = await importPrivateKey(fixedPem);

  const encodedHeader = base64UrlEncode(JSON.stringify(header));
  const encodedPayload = base64UrlEncode(JSON.stringify(payload));
  const data = new TextEncoder().encode(`${encodedHeader}.${encodedPayload}`);

  const sig = await crypto.subtle.sign({ name: 'RSASSA-PKCS1-v1_5' }, key, data);
  const encodedSig = base64UrlEncode(sig);

  return `${encodedHeader}.${encodedPayload}.${encodedSig}`;
}

export async function getSheetsAccessToken(env: Bindings): Promise<string> {
  // KV cache (recommended) to avoid calling Google token endpoint frequently
  const cached = await env.CACHE.get(CACHE_KEY);
  if (cached) return cached;

  if (!env.GOOGLE_CLIENT_EMAIL) throw new Error('GOOGLE_CLIENT_EMAIL missing');
  if (!env.GOOGLE_PRIVATE_KEY) throw new Error('GOOGLE_PRIVATE_KEY missing');

  const now = Math.floor(Date.now() / 1000);
  const header = { alg: 'RS256', typ: 'JWT' };

  const payload = {
    iss: env.GOOGLE_CLIENT_EMAIL,
    scope: [
      'https://www.googleapis.com/auth/spreadsheets',
      // keep this only if you need Drive operations:
      // 'https://www.googleapis.com/auth/drive.file',
    ].join(' '),
    aud: TOKEN_URL,
    iat: now,
    exp: now + 3600, // 1 hour
  };

  const assertion = await signJwtRS256(env.GOOGLE_PRIVATE_KEY, header, payload);

  const body = new URLSearchParams({
    grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
    assertion,
  });

  const res = await fetch(TOKEN_URL, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body,
  });

  const json = (await res.json()) as any;

  if (!res.ok) {
    const msg = json?.error_description || json?.error || 'Google token error';
    throw new Error(`Google OAuth token failed: ${msg}`);
  }

  const token = String(json.access_token ?? '');
  if (!token) throw new Error('Google OAuth token missing access_token');

  // Cache token slightly less than 1 hour
  await env.CACHE.put(CACHE_KEY, token, { expirationTtl: 3300 });

  return token;
}