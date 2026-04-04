import type { Bindings, MetaCampaign, MetaInsight, ParsedInsights } from '../types';

// ─── Constants ───
const INSIGHT_FIELDS = [
  'campaign_name', 'spend', 'impressions', 'reach', 'clicks',
  'cpc', 'cpm', 'ctr', 'actions', 'action_values', 'purchase_roas',
  'frequency', 'date_start', 'date_stop',
].join(',');

const CAMPAIGN_FIELDS = [
  'name', 'objective', 'status', 'effective_status',
  'daily_budget', 'lifetime_budget', 'created_time', 'updated_time',
].join(',');

// ─── Helpers ───
function baseUrl(env: Bindings): string {
  return `https://graph.facebook.com/${env.META_API_VERSION}`;
}

function accountId(env: Bindings): string {
  const id = env.META_AD_ACCOUNT_ID;
  return id.startsWith('act_') ? id : `act_${id}`;
}

async function metaFetch(url: string, token: string, init?: RequestInit): Promise<any> {
  const sep = url.includes('?') ? '&' : '?';
  const res = await fetch(`${url}${sep}access_token=${token}`, {
    ...init,
    headers: { 'Content-Type': 'application/json', ...init?.headers },
  });

  const json = await res.json() as any;

  if (!res.ok) {
    const msg = json?.error?.message || `Meta API ${res.status}`;
    const code = json?.error?.code;
    throw new Error(`[Meta ${code || res.status}] ${msg}`);
  }

  return json;
}

// ─── Campaign Operations ───
export async function getCampaigns(
  env: Bindings,
  datePreset = 'last_30d',
  limit = 50
): Promise<MetaCampaign[]> {
  const url =
    `${baseUrl(env)}/${accountId(env)}/campaigns` +
    `?fields=${CAMPAIGN_FIELDS}` +
    `&effective_status=["ACTIVE","PAUSED","CAMPAIGN_PAUSED","IN_PROCESS"]` +
    `&limit=${limit}`;

  const data = await metaFetch(url, env.META_ACCESS_TOKEN);

  // Batch-fetch insights for each campaign
  const withInsights = await Promise.all(
    (data.data as MetaCampaign[]).map(async (c) => {
      try {
        const iUrl = `${baseUrl(env)}/${c.id}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}`;
        const insights = await metaFetch(iUrl, env.META_ACCESS_TOKEN);
        return { ...c, insights };
      } catch {
        return { ...c, insights: { data: [] } };
      }
    })
  );

  return withInsights;
}

export async function getCampaignDetail(
  env: Bindings,
  campaignId: string,
  datePreset = 'last_30d'
): Promise<MetaCampaign> {
  // Campaign base data
  const campaign = await metaFetch(
    `${baseUrl(env)}/${campaignId}?fields=${CAMPAIGN_FIELDS}`,
    env.META_ACCESS_TOKEN
  );

  // Insights
  const insights = await metaFetch(
    `${baseUrl(env)}/${campaignId}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}`,
    env.META_ACCESS_TOKEN
  );

  // Ad Sets
  const adsets = await metaFetch(
    `${baseUrl(env)}/${campaignId}/adsets?fields=name,status,daily_budget,targeting&limit=20`,
    env.META_ACCESS_TOKEN
  );

  return { ...campaign, insights, adsets };
}

export async function getCampaignInsights(
  env: Bindings,
  campaignId: string,
  datePreset = 'last_30d',
  timeIncrement = '1'
): Promise<MetaInsight[]> {
  const data = await metaFetch(
    `${baseUrl(env)}/${campaignId}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}&time_increment=${timeIncrement}`,
    env.META_ACCESS_TOKEN
  );
  return data.data;
}

export async function getAccountInsights(
  env: Bindings,
  datePreset = 'last_30d',
  timeIncrement?: string
): Promise<MetaInsight[]> {
  let url = `${baseUrl(env)}/${accountId(env)}/insights?fields=${INSIGHT_FIELDS}&date_preset=${datePreset}`;
  if (timeIncrement) url += `&time_increment=${timeIncrement}`;

  const data = await metaFetch(url, env.META_ACCESS_TOKEN);
  return data.data;
}

// ─── Campaign Mutations ───
export async function updateCampaignStatus(
  env: Bindings,
  campaignId: string,
  status: string
): Promise<void> {
  await metaFetch(`${baseUrl(env)}/${campaignId}`, env.META_ACCESS_TOKEN, {
    method: 'POST',
    body: JSON.stringify({ status }),
  });
}

export async function updateCampaignBudget(
  env: Bindings,
  campaignId: string,
  dailyBudget?: number,
  lifetimeBudget?: number
): Promise<void> {
  const body: Record<string, string> = {};
  // Meta API uses cents (paisa for INR)
  if (dailyBudget) body.daily_budget = String(Math.round(dailyBudget * 100));
  if (lifetimeBudget) body.lifetime_budget = String(Math.round(lifetimeBudget * 100));

  await metaFetch(`${baseUrl(env)}/${campaignId}`, env.META_ACCESS_TOKEN, {
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
  }
): Promise<{ id: string }> {
  const body: Record<string, unknown> = {
    name: params.name,
    objective: params.objective,
    status: params.status || 'PAUSED',
    special_ad_categories: params.special_ad_categories || [],
  };

  if (params.daily_budget) body.daily_budget = String(Math.round(params.daily_budget * 100));
  if (params.lifetime_budget) body.lifetime_budget = String(Math.round(params.lifetime_budget * 100));
  if (params.bid_strategy) body.bid_strategy = params.bid_strategy;

  return await metaFetch(
    `${baseUrl(env)}/${accountId(env)}/campaigns`,
    env.META_ACCESS_TOKEN,
    { method: 'POST', body: JSON.stringify(body) }
  );
}

// ─── Lead Data (for webhook) ───
export async function getLeadData(
  env: Bindings,
  leadgenId: string
): Promise<Record<string, string>> {
  const data = await metaFetch(
    `${baseUrl(env)}/${leadgenId}?fields=field_data,campaign_name,ad_name,created_time`,
    env.META_ACCESS_TOKEN
  );

  const fields: Record<string, string> = {};
  if (data.field_data) {
    for (const f of data.field_data) {
      fields[f.name] = f.values?.[0] || '';
    }
  }
  fields._campaign_name = data.campaign_name || '';
  fields._created_time = data.created_time || '';
  return fields;
}

// ─── Parse Meta Insights → Clean Numbers ───
export function parseInsights(insights: MetaInsight[]): ParsedInsights {
  const zero: ParsedInsights = {
    spend: 0, revenue: 0, roas: 0, cpa: 0, ctr: 0, cpc: 0, cpm: 0,
    impressions: 0, reach: 0, clicks: 0, conversions: 0, leads: 0, frequency: 0,
  };

  if (!insights.length) return zero;

  const i = insights[0];
  const spend = parseFloat(i.spend || '0');
  const impressions = parseInt(i.impressions || '0');
  const reach = parseInt(i.reach || '0');
  const clicks = parseInt(i.clicks || '0');
  const cpc = parseFloat(i.cpc || '0');
  const cpm = parseFloat(i.cpm || '0');
  const ctr = parseFloat(i.ctr || '0');
  const frequency = parseFloat(i.frequency || '0');

  let conversions = 0;
  let leads = 0;
  let revenue = 0;

  for (const a of i.actions || []) {
    if (a.action_type === 'purchase' || a.action_type === 'offsite_conversion.fb_pixel_purchase')
      conversions += parseInt(a.value);
    if (a.action_type === 'lead' || a.action_type === 'offsite_conversion.fb_pixel_lead')
      leads += parseInt(a.value);
  }

  for (const av of i.action_values || []) {
    if (av.action_type === 'purchase' || av.action_type === 'offsite_conversion.fb_pixel_purchase')
      revenue += parseFloat(av.value);
  }

  let roas = 0;
  if (i.purchase_roas?.length) {
    roas = parseFloat(i.purchase_roas[0].value || '0');
  } else if (spend > 0 && revenue > 0) {
    roas = revenue / spend;
  }

  const cpa = conversions > 0 ? spend / conversions : 0;

  return { spend, revenue, roas, cpa, ctr, cpc, cpm, impressions, reach, clicks, conversions, leads, frequency };
}