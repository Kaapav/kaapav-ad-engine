import type { Bindings, MetaCampaign, MetaInsight, ParsedInsights } from '../types';

// ─── Constants ───
const INSIGHT_FIELDS = [
  'spend', 'impressions', 'reach', 'clicks',
  'cpc', 'cpm', 'ctr', 'actions', 'action_values', 'purchase_roas',
  'frequency', 'date_start', 'date_stop',
  'campaign_id', 'campaign_name',
  'adset_id', 'adset_name',
  'ad_id', 'ad_name',
].join(',');

const CAMPAIGN_FIELDS = [
  'name', 'objective', 'status', 'effective_status',
  'daily_budget', 'lifetime_budget', 'created_time', 'updated_time',
].join(',');

// Extended insight row type (Meta returns these fields because we request them)
type InsightRow = MetaInsight & {
  campaign_id?: string;
  campaign_name?: string;
  adset_id?: string;
  adset_name?: string;
  ad_id?: string;
  ad_name?: string;
};

// ─── Helpers ───
function baseUrl(env: Bindings): string {
  return `https://graph.facebook.com/${env.META_API_VERSION}`;
}

function accountId(env: Bindings): string {
  const id = env.META_AD_ACCOUNT_ID;
  return id.startsWith('act_') ? id : `act_${id}`;
}

function sleep(ms: number) {
  return new Promise((r) => setTimeout(r, ms));
}

function num(v: any): number {
  const n = Number(v);
  return Number.isFinite(n) ? n : 0;
}

async function metaFetch(url: string, token: string, init?: RequestInit): Promise<any> {
  const sep = url.includes('?') ? '&' : '?';
  const full = `${url}${sep}access_token=${token}`;

  const max = 4;
  let lastErr: any = null;

  for (let attempt = 0; attempt < max; attempt++) {
    const res = await fetch(full, {
      ...init,
      headers: { 'Content-Type': 'application/json', ...init?.headers },
    });

    const json = (await res.json()) as any;

    if (res.ok) return json;

    const msg = json?.error?.message || `Meta API ${res.status}`;
    const code = json?.error?.code;

    // Retry on rate limit/transient errors only
    const retryable =
      res.status === 429 ||
      code === 1 || code === 2 || code === 4 || code === 17 || code === 32;

    lastErr = new Error(`[Meta ${code || res.status}] ${msg}`);
    if (!retryable) throw lastErr;

    await sleep(350 * Math.pow(2, attempt));
  }

  throw lastErr ?? new Error('Meta API failed');
}

async function metaFetchPaged(url: string, token: string, maxPages = 12): Promise<any[]> {
  const out: any[] = [];
  let next: string | null = url;

  for (let i = 0; i < maxPages && next; i++) {
    const json = await metaFetch(next, token);
    out.push(...(json?.data ?? []));
    next = json?.paging?.next ?? null;
  }

  return out;
}

// ─────────────────────────────────────────────
// Campaign Operations (FAST)
// ─────────────────────────────────────────────
export async function getCampaigns(
  env: Bindings,
  datePreset = 'last_30d',
  limit = 50,
): Promise<MetaCampaign[]> {
  const token = env.META_ACCESS_TOKEN;

  const campaignsUrl =
    `${baseUrl(env)}/${accountId(env)}/campaigns` +
    `?fields=${CAMPAIGN_FIELDS}` +
    `&effective_status=["ACTIVE","PAUSED","CAMPAIGN_PAUSED","IN_PROCESS"]` +
    `&limit=${limit}`;

  const campaignsJson = await metaFetch(campaignsUrl, token);
  const campaigns = (campaignsJson?.data as MetaCampaign[]) ?? [];

  // Single insights call for all campaigns
  const insightsUrl =
    `${baseUrl(env)}/${accountId(env)}/insights` +
    `?fields=${INSIGHT_FIELDS}` +
    `&date_preset=${datePreset}` +
    `&level=campaign` +
    `&limit=500`;

  const insightRows = (await metaFetchPaged(insightsUrl, token, 10)) as InsightRow[];

  const byCampaign = new Map<string, MetaInsight[]>();
  for (const r of insightRows) {
    const cid = String(r.campaign_id ?? '');
    if (!cid) continue;
    const arr = byCampaign.get(cid) ?? [];
    arr.push(r);
    byCampaign.set(cid, arr);
  }

  return campaigns.map((c) => ({
    ...c,
    insights: { data: byCampaign.get(c.id) ?? [] },
  }));
}

export async function getCampaignDetail(
  env: Bindings,
  campaignId: string,
  datePreset = 'last_30d',
): Promise<MetaCampaign> {
  const token = env.META_ACCESS_TOKEN;

  const campaign = await metaFetch(
    `${baseUrl(env)}/${campaignId}?fields=${CAMPAIGN_FIELDS}`,
    token,
  );

  const insights = await metaFetch(
    `${baseUrl(env)}/${campaignId}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}`,
    token,
  );

  const adsets = await metaFetch(
    `${baseUrl(env)}/${campaignId}/adsets?fields=name,status,daily_budget,targeting&limit=40`,
    token,
  );

  return { ...campaign, insights, adsets };
}

export async function getCampaignInsights(
  env: Bindings,
  campaignId: string,
  datePreset = 'last_30d',
  timeIncrement = '1',
): Promise<MetaInsight[]> {
  const token = env.META_ACCESS_TOKEN;
  const data = await metaFetch(
    `${baseUrl(env)}/${campaignId}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}&time_increment=${timeIncrement}`,
    token,
  );
  return data.data ?? [];
}

export async function getAccountInsights(
  env: Bindings,
  datePreset = 'last_30d',
  timeIncrement?: string,
): Promise<MetaInsight[]> {
  const token = env.META_ACCESS_TOKEN;

  let url =
    `${baseUrl(env)}/${accountId(env)}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}`;
  if (timeIncrement) url += `&time_increment=${timeIncrement}`;

  const data = await metaFetch(url, token);
  return data.data ?? [];
}

// NEW: Campaign DAILY insights (time_increment=1, level=campaign)
export async function getCampaignDailyInsights(
  env: Bindings,
  datePreset = 'last_7d',
): Promise<MetaInsight[]> {
  const token = env.META_ACCESS_TOKEN;

  const url =
    `${baseUrl(env)}/${accountId(env)}/insights` +
    `?fields=${INSIGHT_FIELDS}` +
    `&date_preset=${datePreset}` +
    `&time_increment=1` +
    `&level=campaign` +
    `&limit=500`;

  return (await metaFetchPaged(url, token, 12)) as InsightRow[] as any;
}

// ─── Campaign Mutations ───
export async function updateCampaignStatus(
  env: Bindings,
  campaignId: string,
  status: string,
): Promise<void> {
  const token = env.META_ACCESS_TOKEN;
  await metaFetch(`${baseUrl(env)}/${campaignId}`, token, {
    method: 'POST',
    body: JSON.stringify({ status }),
  });
}

export async function updateCampaignBudget(
  env: Bindings,
  campaignId: string,
  dailyBudget?: number,
  lifetimeBudget?: number,
): Promise<void> {
  const token = env.META_ACCESS_TOKEN;

  const body: Record<string, string> = {};
  if (dailyBudget != null) body.daily_budget = String(Math.round(dailyBudget * 100));
  if (lifetimeBudget != null) body.lifetime_budget = String(Math.round(lifetimeBudget * 100));

  await metaFetch(`${baseUrl(env)}/${campaignId}`, token, {
    method: 'POST',
    body: JSON.stringify(body),
  });
}

export async function createCampaign(
  env: Bindings,
  params: {
    name: string;
    objective: string;
    status?: string;
    special_ad_categories?: string[];
    daily_budget?: number;
    lifetime_budget?: number;
    bid_strategy?: string;
  },
): Promise<{ id: string }> {
  const token = env.META_ACCESS_TOKEN;

  const body: Record<string, unknown> = {
    name: params.name,
    objective: params.objective,
    status: params.status || 'PAUSED',
    special_ad_categories: params.special_ad_categories || [],
  };

  // Meta expects minor units (paise)
  if (params.daily_budget != null) {
    body.daily_budget = String(Math.round(params.daily_budget * 100));
  }
  if (params.lifetime_budget != null) {
    body.lifetime_budget = String(Math.round(params.lifetime_budget * 100));
  }
  if (params.bid_strategy) {
    body.bid_strategy = params.bid_strategy;
  }

  // POST /act_<ad_account_id>/campaigns
  const url = `${baseUrl(env)}/${accountId(env)}/campaigns`;

  const json = await metaFetch(url, token, {
    method: 'POST',
    body: JSON.stringify(body),
  });

  const id = String(json?.id ?? '');
  if (!id) throw new Error('Meta createCampaign: missing id in response');

  return { id };
}

// NEW: Required for intelligence apply (budget scaling)
export async function getCampaignBudgetInfo(
  env: Bindings,
  campaignId: string,
): Promise<{ daily_budget_inr: number; status: string }> {
  const token = env.META_ACCESS_TOKEN;
  const data = await metaFetch(
    `${baseUrl(env)}/${campaignId}?fields=status,daily_budget`,
    token,
  );

  return {
    daily_budget_inr: num(data?.daily_budget) / 100,
    status: String(data?.status ?? 'UNKNOWN'),
  };
}

// ─── Lead Data (for webhook) ───
export async function getLeadData(
  env: Bindings,
  leadgenId: string,
): Promise<Record<string, string>> {
  const token = env.META_ACCESS_TOKEN;

  const data = await metaFetch(
    `${baseUrl(env)}/${leadgenId}?fields=field_data,campaign_name,campaign_id,ad_name,ad_id,adset_id,created_time`,
    token,
  );

  const fields: Record<string, string> = {};
  if (data.field_data) {
    for (const f of data.field_data) {
      fields[f.name] = f.values?.[0] || '';
    }
  }

  fields._campaign_name = data.campaign_name || '';
  fields._campaign_id = data.campaign_id || '';
  fields._ad_name = data.ad_name || '';
  fields._ad_id = data.ad_id || '';
  fields._adset_id = data.adset_id || '';
  fields._created_time = data.created_time || '';

  return fields;
}

export async function getAdSetInsights(env: Bindings, adsetId: string, datePreset: string): Promise<any[]> {
  const token = env.META_ACCESS_TOKEN;
  const fields = INSIGHT_FIELDS; // Use your existing constant
  
  const url = `${baseUrl(env)}/${adsetId}/insights?fields=${fields}&date_preset=${datePreset}&limit=500`;
  const data = await metaFetch(url, token);
  return data.data ?? [];
}

export async function getAds(env: Bindings, campaignId: string, datePreset: string): Promise<any[]> {
  const token = env.META_ACCESS_TOKEN;
  const fields = 'id,name,creative,adset_id,insights.fields(' + INSIGHT_FIELDS + ').date_preset(' + datePreset + ')';
  
  const url = `${baseUrl(env)}/${campaignId}/ads?fields=${fields}&limit=100`;
  const data = await metaFetch(url, token);
  return data.data ?? [];
}

// ─── Parse Meta Insights → Clean Numbers (aggregated) ───
export function parseInsights(insights: MetaInsight[]): ParsedInsights {
  const zero: ParsedInsights = {
    spend: 0, revenue: 0, roas: 0, cpa: 0, ctr: 0, cpc: 0, cpm: 0,
    impressions: 0, reach: 0, clicks: 0, conversions: 0, leads: 0, frequency: 0,
  };

  if (!insights?.length) return zero;

  let spend = 0;
  let impressions = 0;
  let reach = 0;
  let clicks = 0;

  let ctrSum = 0;
  let cpcSum = 0;
  let cpmSum = 0;
  let freqSum = 0;

  let conversions = 0;
  let leads = 0;
  let revenue = 0;

  for (const i of insights as any[]) {
    spend += num(i.spend);
    impressions += Math.floor(num(i.impressions));
    reach += Math.floor(num(i.reach));
    clicks += Math.floor(num(i.clicks));

    ctrSum += num(i.ctr);
    cpcSum += num(i.cpc);
    cpmSum += num(i.cpm);
    freqSum += num(i.frequency);

    for (const a of i.actions || []) {
      if (a.action_type === 'purchase' || a.action_type === 'offsite_conversion.fb_pixel_purchase') {
        conversions += Math.floor(num(a.value));
      }
      if (a.action_type === 'lead' || a.action_type === 'offsite_conversion.fb_pixel_lead') {
        leads += Math.floor(num(a.value));
      }
    }

    for (const av of i.action_values || []) {
      if (av.action_type === 'purchase' || av.action_type === 'offsite_conversion.fb_pixel_purchase') {
        revenue += num(av.value);
      }
    }
  }

  let roas = 0;
  const pr = (insights[0] as any)?.purchase_roas;
  if (Array.isArray(pr) && pr.length) {
    roas = num(pr[0]?.value);
  } else if (spend > 0) {
    roas = revenue / spend;
  }

  const cpa = conversions > 0 ? spend / conversions : 0;

  const nRows = Math.max(1, insights.length);
  const ctr = ctrSum / nRows;
  const cpc = cpcSum / nRows;
  const cpm = cpmSum / nRows;
  const frequency = freqSum / nRows;

  return {
    spend,
    revenue,
    roas,
    cpa,
    ctr,
    cpc,
    cpm,
    impressions,
    reach,
    clicks,
    conversions,
    leads,
    frequency,
  };
}