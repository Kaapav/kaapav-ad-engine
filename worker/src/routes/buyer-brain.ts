import { Hono } from 'hono';
import type { AppEnv } from '../types';
import {
  getBuyerBrainSummary,
  runBuyerBrainEngine,
} from '../services/buyer-brain-engine';

const app = new Hono<AppEnv>();

function limitParam(value: unknown, fallback = 50, max = 200): number {
  const n = Number(value ?? fallback);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(1, Math.floor(n)));
}

function str(value: unknown, fallback = ''): string {
  const s = value?.toString().trim();
  return s && s.length > 0 ? s : fallback;
}

function nullableStr(value: unknown): string | null {
  const s = value?.toString().trim();
  return s && s.length > 0 ? s : null;
}

function num(value: unknown, fallback = 0): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function normalizeEventType(value: unknown): string {
  const raw = str(value, 'manual_signal').toLowerCase();

  const allowed = new Set([
    'page_view',
    'product_view',
    'add_to_cart',
    'checkout_started',
    'order_created',
    'order_paid',
    'order_cancelled',
    'refund_created',
    'whatsapp_clicked',
    'whatsapp_message',
    'price_asked',
    'catalog_clicked',
    'manual_signal',
  ]);

  return allowed.has(raw) ? raw : 'manual_signal';
}


function intentWeight(eventType: string, eventValue: number): number {
  switch (eventType) {
    case 'order_paid':
      return eventValue > 0 ? 100 : 85;
    case 'order_created':
      return 75;
    case 'checkout_started':
      return 60;
    case 'add_to_cart':
      return 50;
    case 'price_asked':
      return 45;
    case 'whatsapp_message':
      return 42;
    case 'whatsapp_clicked':
      return 35;
    case 'catalog_clicked':
      return 28;
    case 'product_view':
      return 18;
    case 'refund_created':
    case 'order_cancelled':
      return -70;
    default:
      return 10;
  }
}

const ALLOWED_EVENT_SOURCES = new Set([
  'kaapav_app',
  'sheet',
  'manual',
  'manual_test',
]);

const ALLOWED_EVENT_TYPES = new Set([
  'page_view',
  'product_view',
  'add_to_cart',
  'checkout_started',
  'order_created',
  'order_paid',
  'order_cancelled',
  'refund_created',
  'whatsapp_clicked',
  'whatsapp_message',
  'price_asked',
  'catalog_clicked',
  'manual_signal',
]);

function clampNum(value: number, min = 0, max = 100): number {
  return Math.min(max, Math.max(min, value));
}

function eventIdPart(value: string): string {
  return value
    .toLowerCase()
    .replace(/[^a-z0-9._:-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 90);
}

function stableBuyerEventId(
  source: string,
  sourceRef: string,
  eventType: string,
): string {
  return `buyer_event:${eventIdPart(source)}:${eventIdPart(sourceRef)}:${eventIdPart(eventType)}`;
}

function isValidCampaignId(value: string | null): boolean {
  if (!value) return true;
  return /^\d{8,30}$/.test(value);
}

function safeEventTime(value: unknown): string {
  const raw = nullableStr(value);
  if (!raw) return new Date().toISOString();

  const d = new Date(raw);
  if (!Number.isFinite(d.getTime())) return new Date().toISOString();

  return d.toISOString();
}

type SheetsEnv = {
  KV?: {
    get: (key: string) => Promise<string | null>;
    put: (key: string, value: string, options?: { expirationTtl?: number }) => Promise<void>;
  };
  GOOGLE_SERVICE_ACCOUNT_EMAIL?: string;
  GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY?: string;
  GOOGLE_SHEETS_SPREADSHEET_ID?: string;
};

function sheetsB64Url(bytes: ArrayBuffer | Uint8Array | string): string {
  let binary = '';

  if (typeof bytes === 'string') {
    binary = bytes;
  } else {
    const arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
    for (let i = 0; i < arr.length; i++) {
      binary += String.fromCharCode(arr[i]);
    }
  }

  return btoa(binary)
    .replace(/\+/g, '-')
    .replace(/\//g, '_')
    .replace(/=+$/g, '');
}

function sheetsUtf8B64Url(value: string): string {
  return sheetsB64Url(new TextEncoder().encode(value));
}

async function getSheetsAccessToken(env: SheetsEnv): Promise<string> {
  const cached = await env.KV?.get('ad_engine_google_sheets_access_token');
  if (cached) return cached;

  if (
    !env.GOOGLE_SERVICE_ACCOUNT_EMAIL ||
    !env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY ||
    !env.GOOGLE_SHEETS_SPREADSHEET_ID
  ) {
    throw new Error('Google Sheets secrets missing');
  }

  const now = Math.floor(Date.now() / 1000);

  const header = sheetsUtf8B64Url(
    JSON.stringify({ alg: 'RS256', typ: 'JWT' }),
  );

  const claim = sheetsUtf8B64Url(
    JSON.stringify({
      iss: env.GOOGLE_SERVICE_ACCOUNT_EMAIL,
      scope: 'https://www.googleapis.com/auth/spreadsheets.readonly',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    }),
  );

  const signingInput = `${header}.${claim}`;

  const pem = env.GOOGLE_SERVICE_ACCOUNT_PRIVATE_KEY
    .replace(/-----BEGIN PRIVATE KEY-----/g, '')
    .replace(/-----END PRIVATE KEY-----/g, '')
    .replace(/\\n/g, '\n')
    .replace(/\n/g, '');

  const binaryDer = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0));

  const privateKey = await crypto.subtle.importKey(
    'pkcs8',
    binaryDer.buffer,
    {
      name: 'RSASSA-PKCS1-v1_5',
      hash: 'SHA-256',
    },
    false,
    ['sign'],
  );

  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    privateKey,
    new TextEncoder().encode(signingInput),
  );

  const jwt = `${signingInput}.${sheetsB64Url(signature)}`;

  const tokenRes = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: jwt,
    }),
  });

  const tokenJson = (await tokenRes.json()) as {
    access_token?: string;
    error?: string;
    error_description?: string;
  };

  if (!tokenRes.ok || !tokenJson.access_token) {
    throw new Error(`Google token error: ${JSON.stringify(tokenJson)}`);
  }

  await env.KV?.put(
    'ad_engine_google_sheets_access_token',
    tokenJson.access_token,
    { expirationTtl: 3300 },
  );

  return tokenJson.access_token;
}

async function readSheetRows(
  env: SheetsEnv,
  tabName: string,
  range = 'A:ZZ',
): Promise<string[][]> {
  if (!env.GOOGLE_SHEETS_SPREADSHEET_ID) {
    throw new Error('GOOGLE_SHEETS_SPREADSHEET_ID missing');
  }

  const token = await getSheetsAccessToken(env);
  const encodedRange = encodeURIComponent(`${tabName}!${range}`);

  const res = await fetch(
    `https://sheets.googleapis.com/v4/spreadsheets/${env.GOOGLE_SHEETS_SPREADSHEET_ID}/values/${encodedRange}`,
    {
      method: 'GET',
      headers: {
        Authorization: `Bearer ${token}`,
      },
    },
  );

  const text = await res.text();

  let json: { values?: string[][]; error?: unknown } = {};
  try {
    json = text ? JSON.parse(text) : {};
  } catch (_) {
    json = {};
  }

  if (!res.ok) {
    throw new Error(`Sheets read failed: ${text}`);
  }

  return json.values || [];
}

function sheetObj(headers: string[], row: string[]): Record<string, string> {
  const obj: Record<string, string> = {};

  headers.forEach((h, i) => {
    obj[h] = row[i] ?? '';
  });

  return obj;
}

function countBy<T extends string>(values: T[]): Record<string, number> {
  const out: Record<string, number> = {};

  for (const value of values) {
    const key = value || 'blank';
    out[key] = (out[key] || 0) + 1;
  }

  return out;
}

function sampleRows(
  headers: string[],
  rows: string[][],
  limit = 5,
): Record<string, string>[] {
  return rows.slice(1, limit + 1).map((row) => sheetObj(headers, row));
}

function mapSheetCatalogueEventType(eventType: string): string {
  const e = String(eventType || '').toLowerCase().replace(/\s+/g, '');

  if (e === 'websiteclick') return 'page_view';
  if (e === 'catalogueclick') return 'catalog_clicked';
  if (e === 'viewcontent') return 'product_view';
  if (e === 'addtowishlist') return 'product_view';
  if (e === 'addtocart') return 'add_to_cart';
  if (e === 'initiatecheckout') return 'checkout_started';
  if (e === 'whatsappintent') return 'whatsapp_clicked';

  if (e === 'catalogueproductclick') return 'product_view';
  if (e === 'cataloguecategoryview') return 'catalog_clicked';

  return 'manual_signal';
}

function mapSheetOrderEventType(status: string, paymentStatus: string): string {
  const s = status.toLowerCase();
  const p = paymentStatus.toLowerCase();

  if (p === 'paid') return 'order_paid';
  if (s === 'cancelled' || s === 'canceled') return 'order_cancelled';
  if (s === 'refunded' || p === 'refunded') return 'refund_created';

  return 'order_created';
}

function maybeExtractMetaId(value: string): string {
  const match = String(value || '').match(/\b\d{12,30}\b/);
  return match ? match[0] : '';
}

function sheetBool(value: string | null | undefined, fallback = false): boolean {
  if (value == null || value === '') return fallback;
  return ['1', 'true', 'yes', 'y'].includes(value.toLowerCase());
}

function sheetLimit(
  value: string | null | undefined,
  fallback = 500000,
  max = 500000,
): number {
  const n = Number(value || fallback);
  return Math.max(1, Math.min(max, Number.isFinite(n) ? n : fallback));
}

function sheetTimeToIso(value: string): string {
  const raw = String(value || '').trim();

  if (!raw) return new Date().toISOString();

  if (/^\d{4}-\d{2}-\d{2} \d{2}:\d{2}/.test(raw)) {
    const iso = raw.replace(' ', 'T') + '+05:30';
    const d = new Date(iso);
    if (Number.isFinite(d.getTime())) return d.toISOString();
  }

  const d = new Date(raw);
  if (Number.isFinite(d.getTime())) return d.toISOString();

  return new Date().toISOString();
}

async function sha256Hex(value: string): Promise<string> {
  const clean = String(value || '').trim();
  if (!clean) return '';

  const hash = await crypto.subtle.digest(
    'SHA-256',
    new TextEncoder().encode(clean),
  );

  return Array.from(new Uint8Array(hash))
    .map((b) => b.toString(16).padStart(2, '0'))
    .join('');
}

function parseSheetItems(raw: string): Array<Record<string, unknown>> {
  try {
    const parsed = JSON.parse(raw || '[]');
    return Array.isArray(parsed) ? parsed : [];
  } catch (_) {
    return [];
  }
}

function checkoutItemsTotal(raw: string): number {
  const items = parseSheetItems(raw);

  return items.reduce((sum, item) => {
    const qty = Number(item.qty || item.quantity || 1) || 1;
    const price = Number(item.price || 0) || 0;
    return sum + qty * price;
  }, 0);
}

function checkoutItemsSku(raw: string): string {
  return parseSheetItems(raw)
    .map((item) => String(item.sku || item.id || '').trim())
    .filter(Boolean)
    .join(',');
}

function checkoutItemsName(raw: string): string {
  return parseSheetItems(raw)
    .map((item) => String(item.name || '').trim())
    .filter(Boolean)
    .join(', ');
}

function checkoutItemsCategory(raw: string): string {
  return parseSheetItems(raw)
    .map((item) => String(item.category || '').trim())
    .filter(Boolean)
    .filter((v, i, arr) => arr.indexOf(v) === i)
    .join(', ');
}

function sheetRefSafe(value: string): string {
  return String(value || '')
    .replace(/[^a-zA-Z0-9._:-]+/g, '_')
    .replace(/^_+|_+$/g, '')
    .slice(0, 160);
}

function normalizeProductCategory(value: string): string {
  const clean = String(value || '').trim();

  if (!clean) return '';

  const lower = clean.toLowerCase();

if (
  lower === 'jewellery' ||
  lower === 'jewelry' ||
  lower === 'all jewellery' ||
  lower === 'all jewelry' ||
  lower === 'unknown' ||
  clean.includes(',')
) {
  return '';
}
  return clean;
}

function positiveCatalogueValue(
  rawEventType: string,
  row: Record<string, string>,
): number {
  const mappedType = mapSheetCatalogueEventType(rawEventType);

  const price = Number(row.price || 0) || 0;
  const quantity = Number(row.quantity || 1) || 1;
  const cartTotal = Number(row.cart_total || 0) || 0;
  const checkoutTotal = checkoutItemsTotal(row.checkout_items || '');

  if (mappedType === 'checkout_started') {
    return Math.max(cartTotal, checkoutTotal, price * quantity, 1);
  }

  if (mappedType === 'add_to_cart') {
    return Math.max(price * quantity, cartTotal, 1);
  }

  if (mappedType === 'product_view') {
    return Math.max(price, 1);
  }

  if (mappedType === 'whatsapp_clicked') {
    return Math.max(price, cartTotal, checkoutTotal, 1);
  }

  if (mappedType === 'catalog_clicked' || mappedType === 'page_view') {
    return 1;
  }

  return Math.max(price * quantity, cartTotal, checkoutTotal, price, 1);
}

function catalogueConfidence(mappedType: string): number {
  if (mappedType === 'checkout_started') return 85;
  if (mappedType === 'add_to_cart') return 78;
  if (mappedType === 'product_view') return 62;
  if (mappedType === 'whatsapp_clicked') return 70;
  if (mappedType === 'catalog_clicked') return 55;
  if (mappedType === 'page_view') return 45;
  return 40;
}

async function insertBuyerCatalogueEvent(
  env: any,
  event: Record<string, unknown>,
): Promise<'inserted' | 'updated'> {
  const source = 'sheet';
  const sourceRef = str(event.source_ref, '');
  const eventType = normalizeEventType(event.event_type);
  const eventValue = Math.max(1, num(event.event_value, 1));
  const id = stableBuyerEventId(source, sourceRef, eventType);

  const existing = await env.DB.prepare(
    `SELECT id FROM buyer_events WHERE id = ? LIMIT 1`,
  )
    .bind(id)
    .first();

  await env.DB.prepare(
    `INSERT OR REPLACE INTO buyer_events (
      id,
      source,
      source_ref,
      event_type,
      event_time,
      customer_key,
      phone_hash,
      email_hash,
      campaign_id,
      campaign_name,
      adset_id,
      adset_name,
      ad_id,
      ad_name,
      creative_id,
      product_sku,
      product_category,
      product_name,
      event_value,
      currency,
      intent_weight,
      confidence,
      raw_json,
      created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
  )
    .bind(
      id,
      source,
      sourceRef,
      eventType,
      safeEventTime(event.event_time),

      nullableStr(event.customer_key),
      nullableStr(event.phone_hash),
      nullableStr(event.email_hash),

      nullableStr(event.campaign_id),
      nullableStr(event.campaign_name),
      nullableStr(event.adset_id),
      nullableStr(event.adset_name),
      nullableStr(event.ad_id),
      nullableStr(event.ad_name),
      nullableStr(event.creative_id),

      nullableStr(event.product_sku),
      nullableStr(event.product_category),
      nullableStr(event.product_name),

      eventValue,
      str(event.currency, 'INR'),
      num(event.intent_weight, intentWeight(eventType, eventValue)),
      clampNum(num(event.confidence, 60), 0, 100),

      JSON.stringify(event),
    )
    .run();

  return existing ? 'updated' : 'inserted';
}

async function upsertBuyerCatalogueEventsBatch(
  env: any,
  events: Record<string, unknown>[],
  batchSize = 100,
): Promise<{ upserted: number; batches: number }> {
  let upserted = 0;
  let batches = 0;

  for (let i = 0; i < events.length; i += batchSize) {
    const chunk = events.slice(i, i + batchSize);

    const statements = chunk.map((event) => {
      const source = 'sheet';
      const sourceRef = str(event.source_ref, '');
      const eventType = normalizeEventType(event.event_type);
      const eventValue = Math.max(1, num(event.event_value, 1));
      const id = stableBuyerEventId(source, sourceRef, eventType);

      return env.DB.prepare(
        `INSERT OR REPLACE INTO buyer_events (
          id,
          source,
          source_ref,
          event_type,
          event_time,
          customer_key,
          phone_hash,
          email_hash,
          campaign_id,
          campaign_name,
          adset_id,
          adset_name,
          ad_id,
          ad_name,
          creative_id,
          product_sku,
          product_category,
          product_name,
          event_value,
          currency,
          intent_weight,
          confidence,
          raw_json,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      ).bind(
        id,
        source,
        sourceRef,
        eventType,
        safeEventTime(event.event_time),

        nullableStr(event.customer_key),
        nullableStr(event.phone_hash),
        nullableStr(event.email_hash),

        nullableStr(event.campaign_id),
        nullableStr(event.campaign_name),
        nullableStr(event.adset_id),
        nullableStr(event.adset_name),
        nullableStr(event.ad_id),
        nullableStr(event.ad_name),
        nullableStr(event.creative_id),

        nullableStr(event.product_sku),
        nullableStr(event.product_category),
        nullableStr(event.product_name),

        eventValue,
        str(event.currency, 'INR'),
        num(event.intent_weight, intentWeight(eventType, eventValue)),
        clampNum(num(event.confidence, 60), 0, 100),

        JSON.stringify(event),
      );
    });

    if (statements.length) {
      await env.DB.batch(statements);
      upserted += statements.length;
      batches += 1;
    }
  }

  return { upserted, batches };
}

app.get('/summary', async (c) => {
  try {
    const data = await getBuyerBrainSummary(c.env);
    return c.json({ success: true, data });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/recompute', async (c) => {
  try {
    const q = c.req.query();

    const data = await runBuyerBrainEngine(c.env, {
      source: 'manual',
      datePreset: q.date_preset || 'last_30d',
      limit: limitParam(q.limit, 50, 100),
    });

    return c.json({ success: true, data });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/events', async (c) => {
  try {
    const body = await c.req.json().catch(() => null);
    const input = Array.isArray(body) ? body : [body];

    const events = input.filter((x) => x && typeof x === 'object');

    if (!events.length) {
      return c.json(
        { success: false, error: 'Expected event object or event array' },
        400,
      );
    }

    const prepared: Array<{
      id: string;
      source: string;
      sourceRef: string;
      eventType: string;
      eventTime: string;
      eventValue: number;
      confidence: number;
      raw: Record<string, unknown>;
    }> = [];

    const errors: string[] = [];

    for (let i = 0; i < events.length; i++) {
      const e = events[i] as Record<string, unknown>;

      const source = str(e.source, 'manual').toLowerCase();
      const sourceRef = nullableStr(e.source_ref);
      const eventType = str(e.event_type, '').toLowerCase();
      const campaignId = nullableStr(e.campaign_id);
      const eventValue = num(e.event_value, 0);
      const confidence = clampNum(num(e.confidence, 70), 0, 100);
      const rawJson = JSON.stringify(e);

      if (!ALLOWED_EVENT_SOURCES.has(source)) {
        errors.push(
          `event[${i}].source must be one of: ${Array.from(ALLOWED_EVENT_SOURCES).join(', ')}`,
        );
      }

      if (!ALLOWED_EVENT_TYPES.has(eventType)) {
        errors.push(
          `event[${i}].event_type must be one of: ${Array.from(ALLOWED_EVENT_TYPES).join(', ')}`,
        );
      }

      if (!sourceRef) {
        errors.push(`event[${i}].source_ref is required for duplicate protection`);
      }

      if (!isValidCampaignId(campaignId)) {
        errors.push(`event[${i}].campaign_id is invalid`);
      }

      if (!Number.isFinite(eventValue) || eventValue < 0) {
        errors.push(`event[${i}].event_value must be a positive number or zero`);
      }

      if (eventType === 'order_paid' && eventValue <= 0) {
        errors.push(`event[${i}].event_value must be greater than 0 for order_paid`);
      }

      if (eventType === 'refund_created' && eventValue <= 0) {
        errors.push(`event[${i}].event_value must be greater than 0 for refund_created`);
      }

      if (source === 'manual_test' && sourceRef && !sourceRef.startsWith('test_')) {
        errors.push(`event[${i}].manual_test source_ref must start with test_`);
      }

      if ('phone' in e || 'email' in e) {
        errors.push(
          `event[${i}] must not include raw phone/email. Use phone_hash/email_hash only.`,
        );
      }

      if (rawJson.length > 20000) {
        errors.push(`event[${i}].raw_json is too large`);
      }

      if (sourceRef) {
        prepared.push({
          id: stableBuyerEventId(source, sourceRef, eventType || 'manual_signal'),
          source,
          sourceRef,
          eventType,
          eventTime: safeEventTime(e.event_time),
          eventValue,
          confidence,
          raw: e,
        });
      }
    }

    if (errors.length) {
      return c.json(
        {
          success: false,
          error: 'Buyer event validation failed',
          details: errors,
        },
        400,
      );
    }

let inserted = 0;
let updated = 0;

for (const item of prepared) {
  const existing = await c.env.DB.prepare(
    `SELECT id FROM buyer_events WHERE id = ? LIMIT 1`,
  )
    .bind(item.id)
    .first();

  const isUpdate = !!existing;
      const e = item.raw;

      await c.env.DB.prepare(
        `INSERT OR REPLACE INTO buyer_events (
          id,
          source,
          source_ref,
          event_type,
          event_time,

          customer_key,
          phone_hash,
          email_hash,

          campaign_id,
          campaign_name,
          adset_id,
          adset_name,
          ad_id,
          ad_name,
          creative_id,

          product_sku,
          product_category,
          product_name,

          event_value,
          currency,
          intent_weight,
          confidence,

          raw_json,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      )
        .bind(
          item.id,
          item.source,
          item.sourceRef,
          item.eventType,
          item.eventTime,

          nullableStr(e.customer_key),
          nullableStr(e.phone_hash),
          nullableStr(e.email_hash),

          nullableStr(e.campaign_id),
          nullableStr(e.campaign_name),
          nullableStr(e.adset_id),
          nullableStr(e.adset_name),
          nullableStr(e.ad_id),
          nullableStr(e.ad_name),
          nullableStr(e.creative_id),

          nullableStr(e.product_sku),
          nullableStr(e.product_category),
          nullableStr(e.product_name),

          item.eventValue,
          str(e.currency, 'INR'),
          num(e.intent_weight, intentWeight(item.eventType, item.eventValue)),
          item.confidence,

          JSON.stringify(e),
        )
        .run();

      if (isUpdate) {
        updated += 1;
      } else {
        inserted += 1;
      }
    }

return c.json({
  success: true,
  data: {
    processed: prepared.length,
    inserted,
    updated,
    rejected: 0,
    duplicate_mode: 'upsert_by_source_source_ref_event_type',
  },
});
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/sheets/import', async (c) => {
  try {
    if (String(c.env.SHEETS_IMPORT_ENABLED || '') !== 'true') {
      return c.json(
        { success: false, error: 'Sheets import disabled' },
        403,
      );
    }

    const dryRun = sheetBool(c.req.query('dry_run'), true);
    const limit = sheetLimit(c.req.query('limit'), 500000, 500000);

    const catalogueRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Catalogue Events',
      'A:P',
    );

    const headers = catalogueRows[0] || [];

    const rowCount = Math.max(0, catalogueRows.length - 1);
    const startRowIndex = Math.max(1, catalogueRows.length - Math.min(limit, rowCount));

    const rows = catalogueRows
      .slice(1)
      .slice(-limit)
      .map((row, index) => ({
        row_number: startRowIndex + index + 1,
        ...sheetObj(headers, row),
      }));

const skuCategoryMap = new Map<string, string>();
const skuNameMap = new Map<string, string>();

for (const r of rows) {
  const sku = String(r.sku || checkoutItemsSku(r.checkout_items || '') || '').trim();
  const category = normalizeProductCategory(
    r.category || checkoutItemsCategory(r.checkout_items || ''),
  );
  const name = String(
    r.product_name || checkoutItemsName(r.checkout_items || '') || '',
  ).trim();

  if (sku && category) skuCategoryMap.set(sku, category);
  if (sku && name) skuNameMap.set(sku, name);
}

const events: Record<string, unknown>[] = [];

for (const r of rows) {
      const mappedType = mapSheetCatalogueEventType(r.event_type || '');

const productSku =
  r.sku || checkoutItemsSku(r.checkout_items || '');

const productName =
  r.product_name ||
  checkoutItemsName(r.checkout_items || '') ||
  skuNameMap.get(productSku) ||
  '';

const productCategory =
  normalizeProductCategory(
    r.category ||
      checkoutItemsCategory(r.checkout_items || '') ||
      skuCategoryMap.get(productSku) ||
      '',
  );

      const phoneHash = await sha256Hex(r.phone || '');

      const eventValue = positiveCatalogueValue(r.event_type || '', r);

      events.push({
        source_ref: sheetRefSafe(
          `catalogue_${r.row_number}_${r.created_at}_${r.customer_id}_${r.event_type}_${productSku || productCategory || r.source}`,
        ),

        event_type: mappedType,
        event_time: sheetTimeToIso(r.created_at || ''),

        customer_key: r.customer_id || phoneHash || '',
        phone_hash: phoneHash,

        campaign_id: maybeExtractMetaId(r.utm_campaign || ''),
        campaign_name: r.utm_campaign || '',
        adset_id: '',
        adset_name: '',
        ad_id: '',
        ad_name: '',
        creative_id: '',

        product_sku: productSku,
        product_category: productCategory,
        product_name: productName,

        event_value: eventValue,
        currency: 'INR',
        confidence: catalogueConfidence(mappedType),

        sheet_tab: 'Catalogue Events',
        sheet_row_number: r.row_number,
        sheet_source: r.source || '',
        event_type_raw: r.event_type || '',
        customer_name_present: !!r.customer_name,

        utm_source: r.utm_source || '',
        utm_medium: r.utm_medium || '',
        utm_campaign: r.utm_campaign || '',

        privacy_note:
          'Raw phone/name are intentionally not stored in buyer_events. phone_hash/customer_key only.',
      });
    }

let inserted = 0;
let updated = 0;
let upserted = 0;
let batches = 0;

if (!dryRun) {
  const result = await upsertBuyerCatalogueEventsBatch(c.env, events, 100);
  upserted = result.upserted;
  batches = result.batches;
}

    return c.json({
      success: true,
      data: {
        mode: dryRun ? 'dry_run_no_db_writes' : 'imported_to_buyer_events',
        importer: 'catalogue_events_only_phase_1',
        limit,
        prepared: events.length,
inserted,
updated,
upserted,
batches,
write_mode: dryRun ? 'none' : 'batch_insert_or_replace',
skipped: 0,
        imported_tabs: ['Catalogue Events'],
        ignored_tabs: ['Orders', 'Sales', 'Customers', 'Leads'],
        min_event_value: events.reduce(
          (min, e) => Math.min(min, Number(e.event_value || 1)),
          events.length ? Number(events[0].event_value || 1) : 1,
        ),
        event_type_counts: events.reduce((acc: Record<string, number>, e) => {
          const key = String(e.event_type || 'unknown');
          acc[key] = (acc[key] || 0) + 1;
          return acc;
        }, {}),
        sample_events: events.slice(0, 10),
        warning:
          'Phase 1 imports Catalogue Events only. Sales/order proof will be added later after intent loop is validated.',
      },
    });
  } catch (err: any) {
    return c.json(
      {
        success: false,
        error: err?.message ?? 'Catalogue import failed',
      },
      500,
    );
  }
});

app.get('/sheets/preview', async (c) => {
  try {
    const catalogueRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Catalogue Events',
      'A:P',
    );

    const orderRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Orders',
      'A:AI',
    );

    const salesRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Sales',
      'A:S',
    );

    const catalogueHeaders = catalogueRows[0] || [];
    const orderHeaders = orderRows[0] || [];
    const salesHeaders = salesRows[0] || [];

    const catalogueObjects = catalogueRows
      .slice(1)
      .map((row) => sheetObj(catalogueHeaders, row));

    const orderObjects = orderRows
      .slice(1)
      .map((row) => sheetObj(orderHeaders, row));

    const salesObjects = salesRows
      .slice(1)
      .map((row) => sheetObj(salesHeaders, row));

    const catalogueEventTypes = catalogueObjects.map((r) => r.event_type || '');
    const catalogueSources = catalogueObjects.map((r) => r.source || '');
    const catalogueUtmCampaigns = catalogueObjects.map((r) => r.utm_campaign || '');

    const orderStatuses = orderObjects.map((r) => r.status || '');
    const orderPaymentStatuses = orderObjects.map((r) => r.payment_status || '');
    const orderSources = orderObjects.map((r) => r.source || '');

    const mappedCatalogueEvents = catalogueObjects.slice(0, 10).map((r) => ({
      source_ref: `sheet_catalogue_${r.created_at}_${r.customer_id || r.phone}_${r.event_type}_${r.sku}`,
      event_type: mapSheetCatalogueEventType(r.event_type || ''),
      event_time: r.created_at,
      customer_key: r.customer_id || '',
      phone_present: !!r.phone,
      phone_hash_needed: !!r.phone,
      product_sku: r.sku || '',
      product_category: r.category || '',
      product_name: r.product_name || '',
      event_value: Number(r.cart_total || r.price || 0) || 0,
      source: r.source || 'sheet',
      campaign_name: r.utm_campaign || '',
      campaign_id_guess: maybeExtractMetaId(r.utm_campaign || ''),
    }));

    const mappedOrderEvents = orderObjects.slice(0, 10).map((r) => ({
      source_ref: `sheet_order_${r.order_id}`,
      event_type: mapSheetOrderEventType(r.status || '', r.payment_status || ''),
      event_time: r.paid_at || r.created_at,
      customer_key: r.customer_id || '',
      phone_present: !!r.phone,
      phone_hash_needed: !!r.phone,
      order_id: r.order_id || '',
      product_category: r.category || '',
      product_name: r.item_names || r.items_summary || '',
      event_value: Number(r.total || 0) || 0,
      source: r.source || 'sheet',
      campaign_name: r.source || '',
      campaign_id_guess: maybeExtractMetaId(r.source || ''),
    }));

    return c.json({
      success: true,
      data: {
        mode: 'preview_only_no_db_writes',
        row_counts: {
          catalogue_events: catalogueObjects.length,
          orders: orderObjects.length,
          sales: salesObjects.length,
        },
        distributions: {
          catalogue_event_types: countBy(catalogueEventTypes),
          catalogue_sources: countBy(catalogueSources),
          catalogue_utm_campaigns_top: countBy(
            catalogueUtmCampaigns.filter(Boolean).slice(0, 200),
          ),
          order_statuses: countBy(orderStatuses),
          order_payment_statuses: countBy(orderPaymentStatuses),
          order_sources: countBy(orderSources),
        },
        mapping_preview: {
          catalogue_events: mappedCatalogueEvents,
          orders: mappedOrderEvents,
        },
        raw_samples: {
          catalogue_events: sampleRows(catalogueHeaders, catalogueRows, 3),
          orders: sampleRows(orderHeaders, orderRows, 3),
          sales: sampleRows(salesHeaders, salesRows, 3),
        },
        warning:
          'This endpoint does not write to buyer_events. It only previews sheet mapping.',
      },
    });
  } catch (err: any) {
    return c.json(
      {
        success: false,
        error: err?.message ?? 'Sheets preview failed',
      },
      500,
    );
  }
});

app.get('/sheets/health', async (c) => {
  try {
    const catalogueRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Catalogue Events',
      'A:P',
    );

    const orderRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Orders',
      'A:AI',
    );

    const salesRows = await readSheetRows(
      c.env as unknown as SheetsEnv,
      'Sales',
      'A:S',
    );

    return c.json({
      success: true,
      data: {
        spreadsheet_id_present: true,
        catalogue_events_rows: Math.max(0, catalogueRows.length - 1),
        orders_rows: Math.max(0, orderRows.length - 1),
        sales_rows: Math.max(0, salesRows.length - 1),
        headers: {
          catalogue_events: catalogueRows[0] || [],
          orders: orderRows[0] || [],
          sales: salesRows[0] || [],
        },
      },
    });
  } catch (err: any) {
    return c.json(
      {
        success: false,
        error: err?.message ?? 'Sheets health failed',
      },
      500,
    );
  }
});

app.get('/events/order/contract', async (c) => {
  return c.json({
    success: true,
    data: {
      endpoint: '/api/buyer-brain/events/order',
      method: 'POST',
      purpose:
        'Send Kaapav order lifecycle events to Buyer Brain for buyer-intent scoring.',
      auth: {
        required: true,
        header: 'X-API-Key',
      },
      required_fields: [
        'source',
        'order_id',
        'order_status',
        'amount',
      ],
      recommended_fields: [
        'order_time',
        'customer_key',
        'phone_hash',
        'email_hash',
        'campaign_id',
        'campaign_name',
        'adset_id',
        'adset_name',
        'ad_id',
        'ad_name',
        'creative_id',
        'product_sku',
        'product_category',
        'product_name',
        'currency',
        'confidence',
      ],
      allowed_sources: Array.from(ALLOWED_EVENT_SOURCES),
      status_mapping: {
        order_paid: ['paid', 'completed', 'delivered'],
        order_cancelled: ['cancelled', 'canceled'],
        refund_created: ['refunded', 'refund'],
        order_created: ['created', 'pending', 'processing'],
      },
      privacy_rules: [
        'Do not send raw phone.',
        'Do not send raw email.',
        'Use phone_hash/email_hash only.',
      ],
      duplicate_rule:
        'Same source + order_id + mapped event_type updates the existing buyer_event instead of creating duplicates.',
      example: {
        source: 'kaapav_app',
        order_id: 'KP12345',
        order_status: 'paid',
        order_time: new Date().toISOString(),
        customer_key: 'customer_12345',
        phone_hash: 'sha256_phone_hash_optional',
        email_hash: 'sha256_email_hash_optional',
        campaign_id: '120249786696250007',
        campaign_name: 'Kaapav_1 Sales campaign',
        adset_id: null,
        adset_name: null,
        ad_id: null,
        ad_name: null,
        creative_id: null,
        product_sku: 'KP-BRACELET-001',
        product_category: 'bracelets',
        product_name: 'Luxury Bracelet',
        amount: 1299,
        currency: 'INR',
        confidence: 95,
      },
    },
  });
});

app.post('/events/order', async (c) => {
  try {
    const body = await c.req.json().catch(() => null);

    if (!body || typeof body !== 'object' || Array.isArray(body)) {
      return c.json(
        { success: false, error: 'Expected order object' },
        400,
      );
    }

    const e = body as Record<string, unknown>;

    const source = str(e.source, 'kaapav_app').toLowerCase();
    const orderId = nullableStr(e.order_id) || nullableStr(e.source_ref);
    const orderStatus = str(e.order_status, 'paid').toLowerCase();
    const amount = num(e.amount ?? e.total ?? e.event_value, 0);

    if (!ALLOWED_EVENT_SOURCES.has(source)) {
      return c.json(
        { success: false, error: 'Invalid source' },
        400,
      );
    }

    if (!orderId) {
      return c.json(
        { success: false, error: 'order_id is required' },
        400,
      );
    }

    let eventType = 'order_created';

    if (['paid', 'completed', 'delivered'].includes(orderStatus)) {
      eventType = 'order_paid';
    } else if (['cancelled', 'canceled'].includes(orderStatus)) {
      eventType = 'order_cancelled';
    } else if (['refunded', 'refund'].includes(orderStatus)) {
      eventType = 'refund_created';
    }

    if (
      ['order_paid', 'refund_created'].includes(eventType) &&
      amount <= 0
    ) {
      return c.json(
        {
          success: false,
          error: `${eventType} requires amount greater than 0`,
        },
        400,
      );
    }

    const campaignId = nullableStr(e.campaign_id);

    if (!isValidCampaignId(campaignId)) {
      return c.json(
        { success: false, error: 'campaign_id is invalid' },
        400,
      );
    }

    if ('phone' in e || 'email' in e) {
      return c.json(
        {
          success: false,
          error: 'Do not send raw phone/email. Use phone_hash/email_hash only.',
        },
        400,
      );
    }

    const sourceRef = `order_${orderId}`;
    const id = stableBuyerEventId(source, sourceRef, eventType);

    const existing = await c.env.DB.prepare(
      `SELECT id FROM buyer_events WHERE id = ? LIMIT 1`,
    )
      .bind(id)
      .first();

    await c.env.DB.prepare(
      `INSERT OR REPLACE INTO buyer_events (
        id,
        source,
        source_ref,
        event_type,
        event_time,

        customer_key,
        phone_hash,
        email_hash,

        campaign_id,
        campaign_name,
        adset_id,
        adset_name,
        ad_id,
        ad_name,
        creative_id,

        product_sku,
        product_category,
        product_name,

        event_value,
        currency,
        intent_weight,
        confidence,

        raw_json,
        created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
    )
      .bind(
        id,
        source,
        sourceRef,
        eventType,
        safeEventTime(e.event_time ?? e.order_time ?? e.created_at),

        nullableStr(e.customer_key),
        nullableStr(e.phone_hash),
        nullableStr(e.email_hash),

        campaignId,
        nullableStr(e.campaign_name),
        nullableStr(e.adset_id),
        nullableStr(e.adset_name),
        nullableStr(e.ad_id),
        nullableStr(e.ad_name),
        nullableStr(e.creative_id),

        nullableStr(e.product_sku),
        nullableStr(e.product_category),
        nullableStr(e.product_name),

        amount,
        str(e.currency, 'INR'),
        num(e.intent_weight, intentWeight(eventType, amount)),
        clampNum(num(e.confidence, 90), 0, 100),

        JSON.stringify(e),
      )
      .run();

    return c.json({
      success: true,
      data: {
        processed: 1,
        inserted: existing ? 0 : 1,
        updated: existing ? 1 : 0,
        rejected: 0,
        event_type: eventType,
        source,
        source_ref: sourceRef,
      },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/events', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (q.source) {
      where.push('source = ?');
      bind.push(q.source);
    }

    if (q.event_type) {
      where.push('event_type = ?');
      bind.push(q.event_type);
    }

    if (q.campaign_id) {
      where.push('campaign_id = ?');
      bind.push(q.campaign_id);
    }

    if (q.product_category) {
      where.push('product_category = ?');
      bind.push(q.product_category);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM buyer_events
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY event_time DESC, created_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/scores', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (q.entity_type) {
      where.push('entity_type = ?');
      bind.push(q.entity_type);
    }

    if (q.product_category) {
      where.push('product_category = ?');
      bind.push(q.product_category);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM buyer_signal_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY buyer_intent_score DESC, calculated_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/waste', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM buyer_signal_scores
       ORDER BY waste_score DESC, spend DESC, calculated_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/product-affinity', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (q.source) {
      where.push('source = ?');
      bind.push(q.source);
    }

    if (q.product_category) {
      where.push('product_category = ?');
      bind.push(q.product_category);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM product_affinity_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY buyer_intent_score DESC, calculated_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/recommendations', async (c) => {
  try {
    const q = c.req.query();
    const status = q.status?.trim();
    const priority = q.priority?.trim();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (status) {
      where.push('status = ?');
      bind.push(status);
    } else {
      where.push(`status IN ('open', 'pending_approval')`);
    }

    if (priority) {
      where.push('priority = ?');
      bind.push(priority);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM targeting_recommendations
       WHERE ${where.join(' AND ')}
       ORDER BY
         CASE priority
           WHEN 'critical' THEN 4
           WHEN 'high' THEN 3
           WHEN 'medium' THEN 2
           WHEN 'low' THEN 1
           ELSE 0
         END DESC,
         buyer_intent_score DESC,
         created_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/recommendations/:id/dismiss', async (c) => {
  try {
    const id = c.req.param('id');

    const result = await c.env.DB.prepare(
      `UPDATE targeting_recommendations
       SET status = 'dismissed',
           dismissed_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
    )
      .bind(id)
      .run();

    if ((result.meta?.changes ?? 0) === 0) {
      return c.json({ success: false, error: 'Recommendation not found' }, 404);
    }

    await c.env.DB.prepare(
      `INSERT INTO action_ledger (
        id, source, action_type, entity_type, entity_id,
        recommendation_id, status, actor, reason, created_at
      ) VALUES (?, 'buyer_brain', 'dismiss_recommendation', 'targeting_recommendation', ?, ?, 'recorded', 'user', 'Dismissed buyer brain recommendation', CURRENT_TIMESTAMP)`,
    )
      .bind(crypto.randomUUID(), id, id)
      .run();

    return c.json({ success: true, data: { id, status: 'dismissed' } });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

export default app;