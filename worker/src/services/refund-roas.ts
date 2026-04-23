// ═══════════════════════════════════════════════════════════════
// REFUND-ADJUSTED ROAS ENGINE
// Meta ROAS is FAKE — it counts cancelled/returned orders too.
// This engine pulls real refund/cancel signals from:
//   → lead_activities (type: refund / cancel / return)
//   → whatsapp_bridge (message containing refund keywords)
// Then recalculates TRUE ROAS per campaign.
// Outputs: refund_adjusted_roas table
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type RefundAdjustedResult = {
  campaignId: string;
  campaignName: string;
  metaRoas: number;
  trueRoas: number;
  grossRevenue: number;
  refundedRevenue: number;
  adjustedRevenue: number;
  totalSpend: number;
  refundCount: number;
  refundRate: number;      // 0–1
  roasDelta: number;       // trueRoas - metaRoas
  trustLevel: 'high' | 'medium' | 'low';
};

// ─────────────────────────────────────────────
// Refund keyword detection
// ─────────────────────────────────────────────

const REFUND_KEYWORDS = [
  'refund',
  'return',
  'cancel',
  'cancelled',
  'returned',
  'rejected',
  'not delivered',
  'rto',           // Return To Origin (Indian logistics term)
  'ndr',           // Non-Delivery Report
  'failed delivery',
  'wapas',         // Hindi: "return"
  'bhejo wapas',
  'order cancel',
];

function isRefundSignal(text: string): boolean {
  const lower = text.toLowerCase();
  return REFUND_KEYWORDS.some((kw) => lower.includes(kw));
}

// ─────────────────────────────────────────────
// Trust level based on refund rate
// ─────────────────────────────────────────────

function computeTrustLevel(
  refundRate: number,
): RefundAdjustedResult['trustLevel'] {
  if (refundRate <= 0.05) return 'high';    // ≤5% refund rate
  if (refundRate <= 0.15) return 'medium';  // ≤15%
  return 'low';                             // >15% — serious issue
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runRefundAdjustedRoas(
  env: AppEnv['Bindings'],
): Promise<{
  processed: number;
  upserted: number;
  totalRefundedRevenue: number;
  avgRoasDelta: number;
}> {
  // ── Load all converted leads with campaign data ───────────────
  const leads = await env.DB.prepare(
    `SELECT
       l.id          as lead_id,
       l.phone,
       l.campaign_id,
       l.campaign,
       l.value,
       l.stage,
       l.created_at
     FROM leads l
     WHERE l.campaign_id IS NOT NULL
       AND l.campaign_id != ''
     ORDER BY l.campaign_id ASC`,
  ).all<{
    lead_id: string;
    phone: string;
    campaign_id: string;
    campaign: string;
    value: number;
    stage: string;
    created_at: string;
  }>();

  if (!leads.results?.length) {
    return {
      processed: 0,
      upserted: 0,
      totalRefundedRevenue: 0,
      avgRoasDelta: 0,
    };
  }

  // ── Load all lead activities ──────────────────────────────────
  const activities = await env.DB.prepare(
    `SELECT lead_id, type, description, created_at
     FROM lead_activities
     ORDER BY created_at DESC`,
  ).all<{
    lead_id: string;
    type: string;
    description: string;
    created_at: string;
  }>();

  // ── Load WhatsApp inbound messages for refund signals ─────────
  const waMessages = await env.DB.prepare(
    `SELECT phone, direction, message_type, created_at
     FROM whatsapp_bridge
     WHERE direction = 'inbound'
     ORDER BY created_at DESC`,
  ).all<{
    phone: string;
    direction: string;
    message_type: string | null;
    created_at: string;
  }>();

  // ── Load performance snapshots (7d) for spend + meta roas ──────
  const snapshots = await env.DB.prepare(
    `SELECT
       entity_id    as campaign_id,
       AVG(spend)   as spend,
       AVG(revenue) as revenue,
       AVG(roas)    as roas,
       extra
     FROM performance_snapshots
     WHERE entity_type = 'campaign'
       AND snapshot_date >= datetime('now', '-7 days')
     GROUP BY entity_id`,
  ).all<{
    campaign_id: string;
    spend: number;
    revenue: number;
    roas: number;
    extra: string;
  }>();

  if (!snapshots.results?.length) {
    return {
      processed: 0,
      upserted: 0,
      totalRefundedRevenue: 0,
      avgRoasDelta: 0,
    };
  }

  // ── Build lookup maps ─────────────────────────────────────────

  // Activities by lead_id
  const actsByLead = new Map<string, typeof activities.results>();
  for (const a of activities.results ?? []) {
    const arr = actsByLead.get(a.lead_id) ?? [];
    arr.push(a);
    actsByLead.set(a.lead_id, arr);
  }

  // WhatsApp messages by phone
  const waByPhone = new Map<string, typeof waMessages.results>();
  for (const m of waMessages.results ?? []) {
    const arr = waByPhone.get(m.phone) ?? [];
    arr.push(m);
    waByPhone.set(m.phone, arr);
  }

  // ── Group leads by campaign ───────────────────────────────────
  const leadsByCampaign = new Map<string, typeof leads.results>();
  for (const l of leads.results ?? []) {
    const arr = leadsByCampaign.get(l.campaign_id) ?? [];
    arr.push(l);
    leadsByCampaign.set(l.campaign_id, arr);
  }

  // ── Snapshot map ──────────────────────────────────────────────
  const snapshotMap = new Map<
    string,
    { spend: number; revenue: number; roas: number; name: string }
  >();
  for (const s of snapshots.results ?? []) {
    const extra = (() => {
      try { return JSON.parse(s.extra ?? '{}'); }
      catch { return {}; }
    })();

    snapshotMap.set(s.campaign_id, {
      spend:   Number(s.spend ?? 0),
      revenue: Number(s.revenue ?? 0),
      roas:    Number(s.roas ?? 0),
      name:    extra.name ?? s.campaign_id,
    });
  }

  let upserted              = 0;
  let totalRefundedRevenue  = 0;
  const roasDeltas: number[] = [];

  for (const [campaignId, campaignLeads] of leadsByCampaign.entries()) {
    const snap = snapshotMap.get(campaignId);
    if (!snap) continue;

    const { spend, revenue: metaRevenue, roas: metaRoas, name: campaignName } = snap;

    if (spend < 100) continue; // skip very small spends

    // ── Identify refunded orders for this campaign ────────────────

    let refundedRevenue = 0;
    let refundCount     = 0;

    for (const lead of campaignLeads) {
      const leadActs = actsByLead.get(lead.lead_id) ?? [];

      // Check activities for refund signals
      const hasRefundActivity = leadActs.some(
        (a) =>
          a.type === 'refund' ||
          a.type === 'return' ||
          a.type === 'cancel' ||
          isRefundSignal(a.description ?? ''),
      );

      // Check WhatsApp messages for refund signals
      const waHistory  = waByPhone.get(lead.phone) ?? [];
      const hasWaRefund = waHistory.some(
        (m) => isRefundSignal(m.message_type ?? ''),
      );

      if (hasRefundActivity || hasWaRefund) {
        refundedRevenue += Number(lead.value ?? 0);
        refundCount++;
      }
    }

    // ── Calculate TRUE ROAS ───────────────────────────────────────
    const grossRevenue    = metaRevenue;
    const adjustedRevenue = Math.max(0, grossRevenue - refundedRevenue);
    const trueRoas        = spend > 0 ? adjustedRevenue / spend : 0;
    const roasDelta       = trueRoas - metaRoas;
    const totalOrders     = campaignLeads.filter(
      (l) => l.stage === 'Converted',
    ).length;
    const refundRate      = totalOrders > 0 ? refundCount / totalOrders : 0;
    const trustLevel      = computeTrustLevel(refundRate);

    totalRefundedRevenue += refundedRevenue;
    roasDeltas.push(roasDelta);

    // ── Upsert to D1 ───────────────────────────────────────────
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO refund_adjusted_roas (
        id, campaign_id, campaign_name,
        meta_roas, true_roas,
        gross_revenue, refunded_revenue, adjusted_revenue,
        total_spend, refund_count, refund_rate,
        roas_delta, trust_level, computed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        campaignId,
        campaignName,
        Math.round(metaRoas   * 100) / 100,
        Math.round(trueRoas   * 100) / 100,
        Math.round(grossRevenue),
        Math.round(refundedRevenue),
        Math.round(adjustedRevenue),
        Math.round(spend),
        refundCount,
        Math.round(refundRate * 1000) / 1000,
        Math.round(roasDelta  * 100) / 100,
        trustLevel,
        now,
      )
      .run();

    // ── Generate recommendation if ROAS delta is significant ──────
    if (roasDelta < -0.5 && spend >= 1000) {
      const recId = `refund:roas_drop:${campaignId}`;
      const priority: 'high' | 'critical' =
        roasDelta < -1.5 ? 'critical' : 'high';

      await env.DB.prepare(
        `INSERT INTO optimization_recommendations (
          id, entity_type, entity_id, priority, action_type,
          title, description, score, status, payload, created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ON CONFLICT(id) DO UPDATE SET
          priority    = excluded.priority,
          title       = excluded.title,
          description = excluded.description,
          score       = excluded.score,
          status      = 'open',
          payload     = excluded.payload`,
      )
        .bind(
          recId,
          'campaign',
          campaignId,
          priority,
          'reduce_budget',
          `True ROAS for ${campaignName} is ${trueRoas.toFixed(2)}x (Meta shows ${metaRoas.toFixed(2)}x)`,
          `After adjusting for ${refundCount} refund(s), true ROAS dropped from ` +
            `${metaRoas.toFixed(2)}x to ${trueRoas.toFixed(2)}x. ` +
            `₹${Math.round(refundedRevenue)} revenue was refunded. ` +
            `Review product-market fit and reduce spend until refund rate improves.`,
          Math.min(100, Math.round(Math.abs(roasDelta) * 20)),
          'open',
          JSON.stringify({
            source: 'refund_engine',
            metaRoas,
            trueRoas,
            roasDelta,
            refundCount,
            refundRate,
            refundedRevenue,
            trustLevel,
          }),
          now,
        )
        .run();
    }

    upserted++;
  }

  const avgRoasDelta =
    roasDeltas.length
      ? roasDeltas.reduce((s, v) => s + v, 0) / roasDeltas.length
      : 0;

  return {
    processed: leadsByCampaign.size,
    upserted,
    totalRefundedRevenue: Math.round(totalRefundedRevenue),
    avgRoasDelta: Math.round(avgRoasDelta * 100) / 100,
  };
}