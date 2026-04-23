import { getSheetsAccessToken } from './google-auth';
import type { AppEnv } from '../types';

type TabDef = { title: string; headers: string[] };

type UpsertInput = {
  tabTitle: string;
  managedHeaders: string[];
  keyHeaders: string[]; // columns that form a unique key
  rows: Array<Record<string, any>>;
};

function assertToken(env: AppEnv['Bindings']) {
  if (!env.GOOGLE_SHEETS_TOKEN) {
    throw new Error('GOOGLE_SHEETS_TOKEN missing (set via wrangler secret)');
  }
}

function colToA1(n: number): string {
  // 1 -> A, 26 -> Z, 27 -> AA
  let x = n;
  let s = '';
  while (x > 0) {
    const r = (x - 1) % 26;
    s = String.fromCharCode(65 + r) + s;
    x = Math.floor((x - 1) / 26);
  }
  return s;
}

function normalizeCell(v: any): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'number') return String(v);
  if (typeof v === 'boolean') return v ? 'TRUE' : 'FALSE';
  return String(v);
}

function assertSheetsAuth(env: AppEnv['Bindings']) {
  const hasManual =
    (env as any).GOOGLE_SHEETS_TOKEN && String((env as any).GOOGLE_SHEETS_TOKEN).trim();

  const hasService =
    (env as any).GOOGLE_CLIENT_EMAIL &&
    String((env as any).GOOGLE_CLIENT_EMAIL).trim() &&
    (env as any).GOOGLE_PRIVATE_KEY &&
    String((env as any).GOOGLE_PRIVATE_KEY).trim();

  if (!hasManual && !hasService) {
    throw new Error(
      'Missing Sheets auth: set GOOGLE_SHEETS_TOKEN OR GOOGLE_CLIENT_EMAIL + GOOGLE_PRIVATE_KEY',
    );
  }
}

async function gsFetch(env: AppEnv['Bindings'], path: string, init?: RequestInit): Promise<any> {
  assertSheetsAuth(env);

  const url = `https://sheets.googleapis.com/v4/spreadsheets${path}`;

  // Manual token if present, else service account token
  const manualToken = (env as any).GOOGLE_SHEETS_TOKEN
    ? String((env as any).GOOGLE_SHEETS_TOKEN).trim()
    : '';

  const token = manualToken || (await getSheetsAccessToken(env as any));

  const res = await fetch(url, {
    ...init,
    headers: {
      Authorization: `Bearer ${token}`,
      'Content-Type': 'application/json',
      ...(init?.headers ?? {}),
    },
  });

  const json: any = await res.json().catch(() => ({}));

  if (!res.ok) {
    const msg = json?.error?.message || `Sheets API error ${res.status}`;
    throw new Error(msg);
  }
  return json;
}

async function getSpreadsheetTabs(env: AppEnv['Bindings'], sheetId: string) {
  const meta: any = await gsFetch(
    env,
    `/${sheetId}?fields=sheets.properties(sheetId,title)`,
    { method: 'GET' },
  );
  const sheets: Array<{ sheetId: number; title: string }> =
    (meta?.sheets ?? []).map((s: any) => ({
      sheetId: Number(s.properties.sheetId),
      title: String(s.properties.title),
    }));
  return sheets;
}

async function addSheetTab(env: AppEnv['Bindings'], sheetId: string, title: string) {
  await gsFetch(env, `/${sheetId}:batchUpdate`, {
    method: 'POST',
    body: JSON.stringify({
      requests: [{ addSheet: { properties: { title } } }],
    }),
  });
}

async function getValues(env: AppEnv['Bindings'], sheetId: string, range: string) {
  const enc = encodeURIComponent(range);
  const json = await gsFetch(env, `/${sheetId}/values/${enc}?majorDimension=ROWS`, {
    method: 'GET',
  });
  return (json?.values ?? []) as string[][];
}

async function updateValues(env: AppEnv['Bindings'], sheetId: string, range: string, values: any[][]) {
  const enc = encodeURIComponent(range);
  await gsFetch(env, `/${sheetId}/values/${enc}?valueInputOption=RAW`, {
    method: 'PUT',
    body: JSON.stringify({ range, majorDimension: 'ROWS', values }),
  });
}

export async function ensureTabsAndHeaders(env: AppEnv['Bindings'], sheetId: string, defs: TabDef[]) {
  const existing = await getSpreadsheetTabs(env, sheetId);
  const titles = new Set(existing.map((s) => s.title));

  for (const d of defs) {
    if (!titles.has(d.title)) {
      await addSheetTab(env, sheetId, d.title);
    }
  }

  // ensure headers exist (if empty, write them)
  for (const d of defs) {
    const values = await getValues(env, sheetId, `${d.title}!A1:ZZ1`);
    const header = values?.[0] ?? [];
    const headerEmpty = header.length === 0 || header.every((x) => !String(x ?? '').trim());

    if (headerEmpty) {
      await updateValues(env, sheetId, `${d.title}!A1:${colToA1(d.headers.length)}1`, [
        d.headers,
      ]);
    }
  }
}

/**
 * 10/10 upsert that preserves manual columns:
 * - Reads full sheet
 * - Creates "final headers" = existing headers + missing managed headers appended
 * - Builds key->row mapping
 * - Updates only managed columns, preserves all other columns
 * - Writes back full matrix
 */
export async function upsertTablePreserveManual(
  env: AppEnv['Bindings'],
  sheetId: string,
  input: UpsertInput,
): Promise<{ tab: string; updated: number; inserted: number; total_rows: number; total_cols: number }> {
  const tab = input.tabTitle;

  // read existing
  const existing = await getValues(env, sheetId, `${tab}!A1:ZZ10000`);
  const existingHeader = (existing?.[0] ?? []).map((h) => String(h ?? '').trim()).filter((h) => h.length > 0);

  // final headers: existing + any missing managed headers appended
  const finalHeaders = [...existingHeader];
  for (const h of input.managedHeaders) {
    if (!finalHeaders.includes(h)) finalHeaders.push(h);
  }
  for (const k of input.keyHeaders) {
    if (!finalHeaders.includes(k)) finalHeaders.unshift(k); // ensure keys exist
  }

  // header -> idx
  const idx = new Map<string, number>();
  finalHeaders.forEach((h, i) => idx.set(h, i));

  // build key index from existing rows
  const rowsExisting = existing.slice(1);
  const keyIndex = new Map<string, number>(); // key -> row number in rowsExisting (0-based)
  for (let r = 0; r < rowsExisting.length; r++) {
    const row = rowsExisting[r];
    const k = makeKeyFromRow(finalHeaders, idx, input.keyHeaders, row);
    if (k) keyIndex.set(k, r);
  }

  // build mutable matrix (existing expanded to finalHeaders)
  const matrix: string[][] = [];
  matrix.push(finalHeaders);

  // expand all existing rows to finalHeaders length
  for (const row of rowsExisting) {
    const expanded = new Array(finalHeaders.length).fill('');
    for (let i = 0; i < row.length && i < expanded.length; i++) expanded[i] = normalizeCell(row[i]);
    matrix.push(expanded);
  }

  let updated = 0;
  let inserted = 0;

  // upsert incoming rows
  for (const obj of input.rows) {
    const key = makeKeyFromObject(input.keyHeaders, obj);
    if (!key) continue;

    const existingRowIdx = keyIndex.get(key);
    if (existingRowIdx !== undefined) {
      // update in place (row in matrix is +1 because header at 0)
      const target = matrix[existingRowIdx + 1];
      for (const h of input.managedHeaders) {
        const i = idx.get(h);
        if (i === undefined) continue;
        target[i] = normalizeCell(obj[h]);
      }
      updated++;
    } else {
      // insert new row
      const newRow = new Array(finalHeaders.length).fill('');
      // fill keys
      for (const k of input.keyHeaders) {
        const i = idx.get(k);
        if (i !== undefined) newRow[i] = normalizeCell(obj[k]);
      }
      // fill managed fields
      for (const h of input.managedHeaders) {
        const i = idx.get(h);
        if (i !== undefined) newRow[i] = normalizeCell(obj[h]);
      }
      matrix.push(newRow);
      inserted++;
    }
  }

  // write back full matrix
  const lastCol = colToA1(finalHeaders.length);
  const lastRow = matrix.length;

  await updateValues(env, sheetId, `${tab}!A1:${lastCol}${lastRow}`, matrix);

  return {
    tab,
    updated,
    inserted,
    total_rows: lastRow - 1,
    total_cols: finalHeaders.length,
  };
}

function makeKeyFromObject(keys: string[], obj: Record<string, any>): string | null {
  const parts = keys.map((k) => String(obj[k] ?? '').trim());
  if (parts.some((p) => !p)) return null;
  return parts.join('|');
}

function makeKeyFromRow(
  headers: string[],
  idx: Map<string, number>,
  keys: string[],
  row: any[],
): string | null {
  const parts: string[] = [];
  for (const k of keys) {
    const i = idx.get(k);
    if (i === undefined) return null;
    const v = String(row[i] ?? '').trim();
    if (!v) return null;
    parts.push(v);
  }
  return parts.join('|');
}