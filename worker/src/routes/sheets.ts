import { Hono } from 'hono';
import type { AppEnv } from '../types';
import * as Sheets from '../services/sheets';

const app = new Hono<AppEnv>();

type SyncBody = {
  sheetId: string;
  days?: number; // default 14
  limit?: number; // default 500
};

/**
 * Tabs written by Ad Engine worker ONLY (no clash with kaapav-app tabs)
 * These names are safe to use in the same spreadsheet.
 */
const TAB_META_DAILY = 'Meta Daily Campaigns';
const TAB_RECOMMENDATIONS = 'AI Recommendations';
const TAB_ACTIONS = 'Meta Actions Log';
const TAB_ATTRIBUTION = 'Attribution Map';
const TAB_LEADS = 'Ad Engine Leads';

// Headers (snake_case, aligned)
const HEADERS_META_DAILY = [
  'date',
  'campaign_id',
  'campaign_name',
  'spend',
  'impressions',
  'reach',
  'clicks',
  'ctr',
  'cpc',
  'cpm',
  'frequency',
  'conversions',
  'revenue',
  'roas',

  // attributed business truth (computed using attribution_map + order_signals)
  'paid_orders_attributed',
  'revenue_attributed',
  'paid_roas_attributed',
] as const;

const HEADERS_RECOMMENDATIONS = [
  'id',
  'created_at',
  'priority',
  'status',
  'action_type',
  'entity_type',
  'entity_id',
  'title',
  'description',
  'score',
  'payload',
] as const;

const HEADERS_ACTIONS = [
  'id',
  'created_at',
  'type',
  'title',
  'description',
  'campaign_id',
  'rule_id',
] as const;

const HEADERS_ATTRIBUTION = [
  'phone',
  'source',
  'source_platform',
  'campaign_id',
  'adset_id',
  'ad_id',
  'confidence',
  'first_seen',
  'last_seen',
  'data_json',
] as const;

const HEADERS_LEADS = [
  'id',
  'created_at',
  'updated_at',
  'phone',
  'name',
  'email',
  'source',
  'campaign',
  'campaign_id',
  'stage',
  'value',
  'product',
  'notes',
] as const;

function clampInt(v: any, d: number, min: number, max: number) {
  const n = Number(v ?? d);
  if (!Number.isFinite(n)) return d;
  return Math.max(min, Math.min(max, Math.floor(n)));
}

// ─────────────────────────────────────────────
// POST /sync-all  (10/10: creates tabs + full export)
// ─────────────────────────────────────────────
app.post('/sync-all', async (c) => {
  try {
    const body = (await c.req.json()) as SyncBody;
    const sheetId = body.sheetId?.trim();
    if (!sheetId) return c.json({ success: false, error: 'sheetId is required' }, 400);

    const days = clampInt(body.days, 14, 3, 120);
    const limit = clampInt(body.limit, 500, 50, 5000);

    // Ensure tabs + headers (safe, idempotent)
    await Sheets.ensureTabsAndHeaders(c.env, sheetId, [
      { title: TAB_META_DAILY, headers: [...HEADERS_META_DAILY] },
      { title: TAB_RECOMMENDATIONS, headers: [...HEADERS_RECOMMENDATIONS] },
      { title: TAB_ACTIONS, headers: [...HEADERS_ACTIONS] },
      { title: TAB_ATTRIBUTION, headers: [...HEADERS_ATTRIBUTION] },
      { title: TAB_LEADS, headers: [...HEADERS_LEADS] },
    ]);

    // 1) Meta Daily Campaigns (from D1 meta_daily + attributed join)
    const metaDaily = await buildMetaDailyCampaignRows(c.env, days);
    const metaRes = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_META_DAILY,
      managedHeaders: [...HEADERS_META_DAILY],
      keyHeaders: ['date', 'campaign_id'],
      rows: metaDaily,
    });

    // 2) Recommendations
    const recos = await c.env.DB.prepare(
      `SELECT *
       FROM optimization_recommendations
       ORDER BY created_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all<any>();

    const recoRows = (recos.results ?? []).map((r: any) => ({
      id: String(r.id ?? ''),
      created_at: String(r.created_at ?? ''),
      priority: String(r.priority ?? ''),
      status: String(r.status ?? ''),
      action_type: String(r.action_type ?? ''),
      entity_type: String(r.entity_type ?? ''),
      entity_id: String(r.entity_id ?? ''),
      title: String(r.title ?? ''),
      description: String(r.description ?? ''),
      score: r.score == null ? '' : Number(r.score),
      payload: String(r.payload ?? ''),
    }));

    const recoRes = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_RECOMMENDATIONS,
      managedHeaders: [...HEADERS_RECOMMENDATIONS],
      keyHeaders: ['id'],
      rows: recoRows,
    });

    // 3) Actions log (activity_log)
    const actions = await c.env.DB.prepare(
      `SELECT *
       FROM activity_log
       ORDER BY created_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all<any>();

    const actionRows = (actions.results ?? []).map((r: any) => ({
      id: String(r.id ?? ''),
      created_at: String(r.created_at ?? ''),
      type: String(r.type ?? ''),
      title: String(r.title ?? ''),
      description: String(r.description ?? ''),
      campaign_id: String(r.campaign_id ?? ''),
      rule_id: String(r.rule_id ?? ''),
    }));

    const actionRes = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_ACTIONS,
      managedHeaders: [...HEADERS_ACTIONS],
      keyHeaders: ['id'],
      rows: actionRows,
    });

    // 4) Attribution map
    const attrs = await c.env.DB.prepare(
      `SELECT *
       FROM attribution_map
       ORDER BY last_seen DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all<any>();

    const attrRows = (attrs.results ?? []).map((r: any) => ({
      phone: String(r.phone ?? ''),
      source: String(r.source ?? ''),
      source_platform: String(r.source_platform ?? ''),
      campaign_id: String(r.campaign_id ?? ''),
      adset_id: String(r.adset_id ?? ''),
      ad_id: String(r.ad_id ?? ''),
      confidence: r.confidence == null ? '' : Number(r.confidence),
      first_seen: String(r.first_seen ?? ''),
      last_seen: String(r.last_seen ?? ''),
      data_json: String(r.data_json ?? ''),
    }));

    const attrRes = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_ATTRIBUTION,
      managedHeaders: [...HEADERS_ATTRIBUTION],
      keyHeaders: ['phone'],
      rows: attrRows,
    });

    // 5) Leads (Ad Engine Leads tab — NOT the kaapav-app Leads tab)
    const leads = await c.env.DB.prepare(
      `SELECT *
       FROM leads
       ORDER BY created_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all<any>();

    const leadRows = (leads.results ?? []).map((r: any) => ({
      id: String(r.id ?? ''),
      created_at: String(r.created_at ?? ''),
      updated_at: String(r.updated_at ?? ''),
      phone: String(r.phone ?? ''),
      name: String(r.name ?? ''),
      email: String(r.email ?? ''),
      source: String(r.source ?? ''),
      campaign: String(r.campaign ?? ''),
      campaign_id: String(r.campaign_id ?? ''),
      stage: String(r.stage ?? ''),
      value: r.value == null ? '' : Number(r.value),
      product: String(r.product ?? ''),
      notes: String(r.notes ?? ''),
    }));

    const leadRes = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_LEADS,
      managedHeaders: [...HEADERS_LEADS],
      keyHeaders: ['id'],
      rows: leadRows,
    });

    return c.json({
      success: true,
      data: {
        days,
        limit,
        tabs: {
          meta_daily: metaRes,
          recommendations: recoRes,
          actions_log: actionRes,
          attribution_map: attrRes,
          leads: leadRes,
        },
      },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

// ─────────────────────────────────────────────
// Keep your existing endpoints but upgrade behavior safely
// ─────────────────────────────────────────────

// POST /sync-campaigns => sync Meta Daily Campaigns tab (D1-driven)
app.post('/sync-campaigns', async (c) => {
  try {
    const body = (await c.req.json()) as SyncBody;
    const sheetId = body.sheetId?.trim();
    if (!sheetId) return c.json({ success: false, error: 'sheetId is required' }, 400);

    const days = clampInt(body.days, 14, 3, 120);

    await Sheets.ensureTabsAndHeaders(c.env, sheetId, [
      { title: TAB_META_DAILY, headers: [...HEADERS_META_DAILY] },
    ]);

    const rows = await buildMetaDailyCampaignRows(c.env, days);

    const res = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_META_DAILY,
      managedHeaders: [...HEADERS_META_DAILY],
      keyHeaders: ['date', 'campaign_id'],
      rows,
    });

    return c.json({ success: true, data: res });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

// POST /sync-leads => sync Ad Engine Leads tab (no clash)
app.post('/sync-leads', async (c) => {
  try {
    const body = (await c.req.json()) as SyncBody;
    const sheetId = body.sheetId?.trim();
    if (!sheetId) return c.json({ success: false, error: 'sheetId is required' }, 400);

    const limit = clampInt(body.limit, 500, 50, 5000);

    await Sheets.ensureTabsAndHeaders(c.env, sheetId, [
      { title: TAB_LEADS, headers: [...HEADERS_LEADS] },
    ]);

    const leads = await c.env.DB.prepare(
      `SELECT *
       FROM leads
       ORDER BY created_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all<any>();

    const leadRows = (leads.results ?? []).map((r: any) => ({
      id: String(r.id ?? ''),
      created_at: String(r.created_at ?? ''),
      updated_at: String(r.updated_at ?? ''),
      phone: String(r.phone ?? ''),
      name: String(r.name ?? ''),
      email: String(r.email ?? ''),
      source: String(r.source ?? ''),
      campaign: String(r.campaign ?? ''),
      campaign_id: String(r.campaign_id ?? ''),
      stage: String(r.stage ?? ''),
      value: r.value == null ? '' : Number(r.value),
      product: String(r.product ?? ''),
      notes: String(r.notes ?? ''),
    }));

    const res = await Sheets.upsertTablePreserveManual(c.env, sheetId, {
      tabTitle: TAB_LEADS,
      managedHeaders: [...HEADERS_LEADS],
      keyHeaders: ['id'],
      rows: leadRows,
    });

    return c.json({ success: true, data: res });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

export default app;

// ─────────────────────────────────────────────
// D1 query: build meta_daily rows + attributed business truth
// ─────────────────────────────────────────────
async function buildMetaDailyCampaignRows(env: AppEnv['Bindings'], days: number) {
  // meta_daily rows
  const md = await env.DB.prepare(
    `SELECT entity_date, entity_id, entity_name,
            spend, impressions, reach, clicks, ctr, cpc, cpm, frequency,
            conversions, revenue, roas
     FROM meta_daily
     WHERE entity_type='campaign'
       AND date(entity_date) >= date('now', ?)
     ORDER BY entity_date DESC`,
  )
    .bind(`-${days} day`)
    .all<any>();

  const metaRows = md.results ?? [];

  // attributed paid orders grouped by (date, campaign_id)
  // (If attribution_map is empty today, this will simply return no rows.)
  const att = await env.DB.prepare(
    `SELECT
        am.campaign_id as campaign_id,
        substr(os.paid_at,1,10) as paid_date,
        COUNT(*) as paid_orders,
        COALESCE(SUM(os.total),0) as revenue_attributed
     FROM attribution_map am
     JOIN order_signals os ON os.phone = am.phone
     WHERE am.campaign_id IS NOT NULL
       AND am.campaign_id <> ''
       AND os.payment_status = 'paid'
       AND os.paid_at IS NOT NULL
       AND date(substr(os.paid_at,1,10)) >= date('now', ?)
     GROUP BY am.campaign_id, substr(os.paid_at,1,10)`,
  )
    .bind(`-${days} day`)
    .all<any>();

  const attrMap = new Map<string, { paid_orders: number; revenue_attributed: number }>();
  for (const r of att.results ?? []) {
    const key = `${String(r.paid_date)}|${String(r.campaign_id)}`;
    attrMap.set(key, {
      paid_orders: Number(r.paid_orders ?? 0),
      revenue_attributed: Number(r.revenue_attributed ?? 0),
    });
  }

  // final rows for sheet
  return metaRows.map((r: any) => {
    const date = String(r.entity_date ?? '').slice(0, 10);
    const campaignId = String(r.entity_id ?? '');
    const k = `${date}|${campaignId}`;
    const a = attrMap.get(k);

    const spend = Number(r.spend ?? 0);
    const revAttr = Number(a?.revenue_attributed ?? 0);
    const paidRoasAttr = spend > 0 ? revAttr / spend : 0;

    return {
      date,
      campaign_id: campaignId,
      campaign_name: String(r.entity_name ?? ''),
      spend,
      impressions: Number(r.impressions ?? 0),
      reach: Number(r.reach ?? 0),
      clicks: Number(r.clicks ?? 0),
      ctr: Number(r.ctr ?? 0),
      cpc: Number(r.cpc ?? 0),
      cpm: Number(r.cpm ?? 0),
      frequency: Number(r.frequency ?? 0),
      conversions: Number(r.conversions ?? 0),
      revenue: Number(r.revenue ?? 0),
      roas: Number(r.roas ?? 0),

      paid_orders_attributed: Number(a?.paid_orders ?? 0),
      revenue_attributed: revAttr,
      paid_roas_attributed: Number(paidRoasAttr.toFixed(4)),
    };
  });
}