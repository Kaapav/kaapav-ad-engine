// ═══════════════════════════════════════════════════════════════
// BUYER QUALITY ENGINE
// Scores every lead as a buyer based on:
// AOV + Repeat + Payment Reliability + Response + LTV + Refunds
// Outputs: buyer_quality_score, buyer_tier, seed eligibility
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type BuyerTier = 'platinum' | 'gold' | 'silver' | 'risk';

export type BuyerScoreResult = {
  phone: string;
  leadId: string | null;
  customerName: string;
  totalOrders: number;
  totalRevenue: number;
  avgOrderValue: number;
  repeatOrders: number;
  prepaidRatio: number;
  refundCount: number;
  responseScore: number;
  buyerQualityScore: number;
  buyerTier: BuyerTier;
  lookalikeSeedEligible: boolean;
  productAffinity: string;
};

// ─────────────────────────────────────────────
// Normalize a value to 0–100 given a range
// ─────────────────────────────────────────────

function normalize(
  value: number,
  min: number,
  max: number,
): number {
  if (max <= min) return 0;
  return Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
}

// ─────────────────────────────────────────────
// Canonical Buyer Quality Score Formula
// ─────────────────────────────────────────────

function computeBuyerQualityScore(input: {
  aovScore: number;         // 0–100
  repeatScore: number;      // 0–100
  paymentScore: number;     // 0–100
  responseScore: number;    // 0–100
  ltvScore: number;         // 0–100
  productValueScore: number;// 0–100
  consistencyScore: number; // 0–100
  refundPenalty: number;    // 0–100
}): number {
  const raw =
    input.aovScore          * 0.20 +
    input.repeatScore       * 0.20 +
    input.paymentScore      * 0.15 +
    input.responseScore     * 0.10 +
    input.ltvScore          * 0.15 +
    input.productValueScore * 0.10 +
    input.consistencyScore  * 0.10 -
    input.refundPenalty     * 0.20;

  return Math.min(100, Math.max(0, raw));
}

function buyerTierFromScore(score: number): BuyerTier {
  if (score >= 85) return 'platinum';
  if (score >= 70) return 'gold';
  if (score >= 50) return 'silver';
  return 'risk';
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runBuyerEngine(
  env: AppEnv['Bindings'],
): Promise<{ processed: number; upserted: number }> {
  // Step 1: Load all leads with value > 0 (converted or qualified)
  const leads = await env.DB.prepare(
    `SELECT
       id, phone, name,
       COALESCE(value, 0) as value,
       stage, product,
       created_at, updated_at
     FROM leads
     WHERE phone IS NOT NULL AND phone != ''
     ORDER BY phone ASC`,
  ).all<{
    id: string;
    phone: string;
    name: string;
    value: number;
    stage: string;
    product: string | null;
    created_at: string;
    updated_at: string;
  }>();

  if (!leads.results?.length) {
    return { processed: 0, upserted: 0 };
  }

  // Step 2: Load activity data (order placements, calls, whatsapp replies)
  const activities = await env.DB.prepare(
    `SELECT lead_id, type, description, created_at
     FROM lead_activities
     ORDER BY created_at ASC`,
  ).all<{
    lead_id: string;
    type: string;
    description: string;
    created_at: string;
  }>();

  // Step 3: Load WhatsApp bridge data (response detection)
  const waMessages = await env.DB.prepare(
    `SELECT phone, direction, created_at, message_type
     FROM whatsapp_bridge
     ORDER BY created_at ASC`,
  ).all<{
    phone: string;
    direction: string;
    created_at: string;
    message_type: string | null;
  }>();

  // ─── Build lookup maps ───────────────────────────────────────
  // Group activities by lead_id
  const activitiesByLead = new Map<string, typeof activities.results>();
  for (const a of activities.results ?? []) {
    const arr = activitiesByLead.get(a.lead_id) ?? [];
    arr.push(a);
    activitiesByLead.set(a.lead_id, arr);
  }

  // Group WhatsApp messages by phone
  const waByPhone = new Map<string, typeof waMessages.results>();
  for (const m of waMessages.results ?? []) {
    const arr = waByPhone.get(m.phone) ?? [];
    arr.push(m);
    waByPhone.set(m.phone, arr);
  }

  // Group leads by phone (one phone may have multiple leads = repeat buyer)
  const leadsByPhone = new Map<string, typeof leads.results>();
  for (const l of leads.results ?? []) {
    const arr = leadsByPhone.get(l.phone) ?? [];
    arr.push(l);
    leadsByPhone.set(l.phone, arr);
  }

  // ─── Compute benchmarks for normalization ───────────────────
  // We need population-level max AOV and LTV to normalize
  const allValues = (leads.results ?? [])
    .map((l) => l.value)
    .filter((v) => v > 0);

  const maxAov = allValues.length
    ? Math.max(...allValues)
    : 50000;

  const maxLtv = maxAov * 3; // assume max 3x repeat as ceiling

  // ─── Score each unique phone ─────────────────────────────────
  let upserted = 0;

  for (const [phone, phoneLeads] of leadsByPhone.entries()) {
    // ── Basic aggregates ──────────────────────────────────────

    const convertedLeads = phoneLeads.filter(
      (l) => l.stage === 'Converted',
    );

    const totalOrders = convertedLeads.length;
    const totalRevenue = phoneLeads.reduce((s, l) => s + l.value, 0);
    const avgOrderValue = totalOrders > 0
      ? totalRevenue / totalOrders
      : 0;
    const repeatOrders = Math.max(0, totalOrders - 1);

    // Primary lead (most recent)
    const primaryLead = phoneLeads.sort(
      (a, b) =>
        new Date(b.created_at).getTime() -
        new Date(a.created_at).getTime(),
    )[0];

    // ── Activity signals ──────────────────────────────────────
    const allActivities = phoneLeads.flatMap(
      (l) => activitiesByLead.get(l.id) ?? [],
    );

    const orderActivities = allActivities.filter(
      (a) =>
        a.type === 'order' ||
        a.description?.toLowerCase().includes('order'),
    );

    const prepaidActivities = allActivities.filter(
      (a) =>
        a.description?.toLowerCase().includes('prepaid') ||
        a.description?.toLowerCase().includes('paid online'),
    );

    const refundActivities = allActivities.filter(
      (a) =>
        a.description?.toLowerCase().includes('refund') ||
        a.description?.toLowerCase().includes('return') ||
        a.description?.toLowerCase().includes('cancel'),
    );

    const refundCount = refundActivities.length;

    const prepaidRatio =
      orderActivities.length > 0
        ? prepaidActivities.length / orderActivities.length
        : 0;

    // ── WhatsApp response speed ───────────────────────────────
    const waHistory = waByPhone.get(phone) ?? [];

    const outbound = waHistory
      .filter((m) => m.direction === 'outbound')
      .sort(
        (a, b) =>
          new Date(a.created_at).getTime() -
          new Date(b.created_at).getTime(),
      );

    const inbound = waHistory
      .filter((m) => m.direction === 'inbound')
      .sort(
        (a, b) =>
          new Date(a.created_at).getTime() -
          new Date(b.created_at).getTime(),
      );

    // Response speed: time from first outbound to first inbound reply
    let responseSpeedMinutes = 999;
    if (outbound.length > 0 && inbound.length > 0) {
      const firstOut = new Date(outbound[0].created_at).getTime();
      const firstIn = new Date(inbound[0].created_at).getTime();
      if (firstIn > firstOut) {
        responseSpeedMinutes = (firstIn - firstOut) / (1000 * 60);
      }
    }

    // Response score: faster = better
    // <5min = 100, <30min = 75, <2hr = 50, <24hr = 25, >24hr = 0
    let responseScore = 0;
    if (responseSpeedMinutes < 5) responseScore = 100;
    else if (responseSpeedMinutes < 30) responseScore = 75;
    else if (responseSpeedMinutes < 120) responseScore = 50;
    else if (responseSpeedMinutes < 1440) responseScore = 25;
    else responseScore = 0;

    // ── Product affinity ─────────────────────────────────────
    // Most purchased product category
    const productCounts = new Map<string, number>();
    for (const l of phoneLeads) {
      if (l.product) {
        const p = l.product.trim().toLowerCase();
        productCounts.set(p, (productCounts.get(p) ?? 0) + 1);
      }
    }

    let productAffinity = 'general';
    let maxCount = 0;
    for (const [product, count] of productCounts.entries()) {
      if (count > maxCount) {
        maxCount = count;
        productAffinity = product;
      }
    }

    // ── Scoring ───────────────────────────────────────────────

    // AOV score: normalize against population max
    const aovScore = normalize(avgOrderValue, 0, maxAov);

    // Repeat score: 1 order = 0, 2 orders = 50, 3+ = 100
    const repeatScore = normalize(repeatOrders, 0, 3);

    // Payment reliability: prepaid ratio * 100
    const paymentScore = prepaidRatio * 100;

    // LTV score: total revenue vs max LTV
    const ltvScore = normalize(totalRevenue, 0, maxLtv);

    // Product value score: high AOV product = higher score
    // Bridal/Kundan sets typically > ₹5000
    const productValueScore = avgOrderValue >= 5000
      ? 100
      : avgOrderValue >= 2000
        ? 70
        : avgOrderValue >= 800
          ? 45
          : 20;

    // Conversion consistency score
    // Did they convert more than once? Were all leads converted?
    const conversionRate =
      phoneLeads.length > 0
        ? convertedLeads.length / phoneLeads.length
        : 0;
    const consistencyScore = normalize(conversionRate, 0, 1) * 100;

    // Refund penalty: 1 refund = -30pts, 2+ = -60pts (capped)
    const refundPenalty = Math.min(100, refundCount * 30);

    const buyerQualityScore = computeBuyerQualityScore({
      aovScore,
      repeatScore,
      paymentScore,
      responseScore,
      ltvScore,
      productValueScore,
      consistencyScore,
      refundPenalty,
    });

    const buyerTier = buyerTierFromScore(buyerQualityScore);

    // Seed eligibility:
    // Must be gold/platinum, no refunds, at least 1 converted order
    const lookalikeSeedEligible =
      (buyerTier === 'platinum' || buyerTier === 'gold') &&
      refundCount === 0 &&
      totalOrders >= 1;

    // ── Upsert to D1 ─────────────────────────────────────────
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO buyer_scores (
        id, lead_id, phone, customer_name,
        total_orders, total_revenue, avg_order_value,
        repeat_orders, prepaid_ratio, refund_count,
        response_score, buyer_quality_score, buyer_tier,
        lookalike_seed_eligible, product_affinity, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(phone) DO UPDATE SET
        lead_id = excluded.lead_id,
        customer_name = excluded.customer_name,
        total_orders = excluded.total_orders,
        total_revenue = excluded.total_revenue,
        avg_order_value = excluded.avg_order_value,
        repeat_orders = excluded.repeat_orders,
        prepaid_ratio = excluded.prepaid_ratio,
        refund_count = excluded.refund_count,
        response_score = excluded.response_score,
        buyer_quality_score = excluded.buyer_quality_score,
        buyer_tier = excluded.buyer_tier,
        lookalike_seed_eligible = excluded.lookalike_seed_eligible,
        product_affinity = excluded.product_affinity,
        updated_at = excluded.updated_at`,
    )
      .bind(
        crypto.randomUUID(),
        primaryLead.id,
        phone,
        primaryLead.name ?? phone,
        totalOrders,
        totalRevenue,
        avgOrderValue,
        repeatOrders,
        prepaidRatio,
        refundCount,
        responseScore,
        Math.round(buyerQualityScore * 100) / 100,
        buyerTier,
        lookalikeSeedEligible ? 1 : 0,
        productAffinity,
        now,
      )
      .run();

    upserted++;
  }

  return {
    processed: leadsByPhone.size,
    upserted,
  };
}