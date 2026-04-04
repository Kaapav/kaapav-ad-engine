import type { Bindings } from '../types';

const SHEETS_BASE = 'https://sheets.googleapis.com/v4/spreadsheets';

async function sheetsFetch(url: string, token: string, init?: RequestInit): Promise<any> {
  const res = await fetch(url, {
    ...init,
    headers: {
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
      ...init?.headers,
    },
  });
  if (!res.ok) throw new Error(`Sheets API ${res.status}: ${await res.text()}`);
  return res.json();
}

export async function writeRange(
  env: Bindings,
  sheetId: string,
  range: string,
  values: string[][]
): Promise<void> {
  const url = `${SHEETS_BASE}/${sheetId}/values/${encodeURIComponent(range)}?valueInputOption=USER_ENTERED`;
  await sheetsFetch(url, env.GOOGLE_SHEETS_TOKEN, {
    method: 'PUT',
    body: JSON.stringify({ range, majorDimension: 'ROWS', values }),
  });
}

export async function appendRows(
  env: Bindings,
  sheetId: string,
  sheet: string,
  values: string[][]
): Promise<void> {
  const range = `${sheet}!A:Z`;
  const url = `${SHEETS_BASE}/${sheetId}/values/${encodeURIComponent(range)}:append?valueInputOption=USER_ENTERED`;
  await sheetsFetch(url, env.GOOGLE_SHEETS_TOKEN, {
    method: 'POST',
    body: JSON.stringify({ range, majorDimension: 'ROWS', values }),
  });
}

export async function syncCampaigns(
  env: Bindings,
  sheetId: string,
  campaigns: Array<{ name: string; status: string; spend: number; revenue: number; roas: number; cpa: number }>
): Promise<void> {
  const header = ['Campaign', 'Status', 'Spend (₹)', 'Revenue (₹)', 'ROAS', 'CPA (₹)', 'Synced At'];
  const rows = campaigns.map((c) => [
    c.name, c.status,
    c.spend.toFixed(0), c.revenue.toFixed(0),
    `${c.roas.toFixed(2)}x`, c.cpa.toFixed(0),
    new Date().toISOString(),
  ]);
  await writeRange(env, sheetId, 'Campaigns!A1', [header, ...rows]);
}

export async function syncLeads(
  env: Bindings,
  sheetId: string,
  leads: Array<{ name: string; phone: string; stage: string; campaign: string | null; value: number; created_at: string }>
): Promise<void> {
  const header = ['Name', 'Phone', 'Stage', 'Campaign', 'Value (₹)', 'Created'];
  const rows = leads.map((l) => [
    l.name, l.phone, l.stage, l.campaign || '',
    l.value ? l.value.toString() : '0', l.created_at,
  ]);
  await writeRange(env, sheetId, 'Leads!A1', [header, ...rows]);
}