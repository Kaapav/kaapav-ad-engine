import type { AppEnv, MetaCampaign, ParsedInsights } from '../types';
import * as MetaApi from './meta-api';

type Env = AppEnv['Bindings'];

type BuyerBrainRunResult = {
  ok: boolean;
  runId: string;
  campaignsProcessed: number;
  scoresCreated: number;
  recommendationsCreated: number;
  durationMs: number;
};

type CampaignBrainRow = {
  campaign: MetaCampaign;
  metrics: ParsedInsights;
  productCategory: string;
  audienceCluster: string;
  buyerIntentScore: number;
  wasteScore: number;
  productAffinityScore: number;
  creativeSignalScore: number;
  retargetingPriority: number;
  recommendationHint: string;
  reasons: string[];
  buyerEventSignal: BuyerEventSignal;
};

type BuyerEventSignal = {
  campaign_id: string;
  product_category: string;
  paid_orders: number;
  paid_revenue: number;
  order_created: number;
  cart_events: number;
  checkout_events: number;
  whatsapp_events: number;
  price_asked_events: number;
  refunds: number;
  cancelled: number;
  negative_value: number;
  total_events: number;
  avg_confidence: number;
};

type SheetCategorySignal = {
  product_category: string;
  events: number;
  customers: number;
  product_views: number;
  carts: number;
  checkouts: number;
  order_created: number;
  paid_orders: number;
  paid_revenue: number;
  refunds: number;
  cancelled: number;
  total_value: number;
  intent_score: number;
  avg_confidence: number;
  buyer_intent_score: number;
  confidence: number;
  top_products: Array<Record<string, unknown>>;
};

function clamp(value: number, min = 0, max = 100): number {
  if (!Number.isFinite(value)) return min;
  return Math.max(min, Math.min(max, value));
}

function n(value: unknown): number {
  const parsed = Number(value);
  return Number.isFinite(parsed) ? parsed : 0;
}

function round(value: number, decimals = 2): number {
  const p = Math.pow(10, decimals);
  return Math.round(value * p) / p;
}

function id(prefix: string, ...parts: Array<string | number | undefined | null>) {
  return [prefix, ...parts.map((p) => String(p ?? 'unknown'))]
    .join(':')
    .replace(/\s+/g, '_')
    .toLowerCase();
}

function nowIso() {
  return new Date().toISOString();
}

function inferProductCategory(name: string): string {
  const s = name.toLowerCase();

  if (s.includes('bracelet') || s.includes('bangle') || s.includes('kada')) return 'bracelet';
  if (s.includes('earring') || s.includes('earrings') || s.includes('jhumka') || s.includes('stud')) return 'earrings';
  if (s.includes('necklace') || s.includes('choker')) return 'necklace';
  if (s.includes('ring')) return 'ring';
  if (s.includes('pendant set') || s.includes('pendant_set')) return 'pendant_set';
  if (s.includes('pendant')) return 'pendant';
  if (s.includes('chain')) return 'chain';
  if (s.includes('gift')) return 'gift';
  if (s.includes('festive') || s.includes('wedding') || s.includes('bridal')) return 'festive';
  if (s.includes('luxury') || s.includes('premium')) return 'luxury';

  return 'all_jewellery';
}

function inferAudienceCluster(name: string, category: string): string {
  const s = name.toLowerCase();

  if (s.includes('office') || s.includes('workwear')) return 'office_wear_buyers';
  if (s.includes('college') || s.includes('trend') || s.includes('genz')) return 'college_trend_buyers';
  if (s.includes('wedding') || s.includes('bridal') || s.includes('festive')) return 'festive_wedding_buyers';
  if (s.includes('gift')) return 'gift_buyers';
  if (s.includes('minimal') || s.includes('daily')) return 'minimal_daily_wear_buyers';
  if (s.includes('traditional') || s.includes('ethnic')) return 'traditional_ethnic_buyers';
  if (s.includes('luxury') || s.includes('premium')) return 'premium_artificial_jewellery_buyers';

  return `${category}_interest_buyers`;
}

function emptyBuyerEventSignal(
  campaignId: string,
  productCategory = 'all_jewellery',
): BuyerEventSignal {
  return {
    campaign_id: campaignId,
    product_category: productCategory,
    paid_orders: 0,
    paid_revenue: 0,
    order_created: 0,
    cart_events: 0,
    checkout_events: 0,
    whatsapp_events: 0,
    price_asked_events: 0,
    refunds: 0,
    cancelled: 0,
    negative_value: 0,
    total_events: 0,
    avg_confidence: 0,
  };
}

async function getBuyerEventSignals(env: Env): Promise<Map<string, BuyerEventSignal>> {
  const rows = await env.DB.prepare(
    `SELECT
      campaign_id,
      COALESCE(product_category, 'all_jewellery') AS product_category,

      SUM(CASE WHEN event_type = 'order_paid' THEN 1 ELSE 0 END) AS paid_orders,
      SUM(CASE WHEN event_type = 'order_paid' THEN COALESCE(event_value, 0) ELSE 0 END) AS paid_revenue,

      SUM(CASE WHEN event_type = 'order_created' THEN 1 ELSE 0 END) AS order_created,
      SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS cart_events,
      SUM(CASE WHEN event_type = 'checkout_started' THEN 1 ELSE 0 END) AS checkout_events,

      SUM(CASE WHEN event_type IN ('whatsapp_clicked', 'whatsapp_message', 'catalog_clicked') THEN 1 ELSE 0 END) AS whatsapp_events,
      SUM(CASE WHEN event_type = 'price_asked' THEN 1 ELSE 0 END) AS price_asked_events,

      SUM(CASE WHEN event_type = 'refund_created' THEN 1 ELSE 0 END) AS refunds,
      SUM(CASE WHEN event_type = 'order_cancelled' THEN 1 ELSE 0 END) AS cancelled,
      SUM(CASE WHEN event_type IN ('refund_created', 'order_cancelled') THEN ABS(COALESCE(event_value, 0)) ELSE 0 END) AS negative_value,

      COUNT(*) AS total_events,
      AVG(COALESCE(confidence, 70)) AS avg_confidence
    FROM buyer_events
    WHERE campaign_id IS NOT NULL
      AND campaign_id != ''
    GROUP BY campaign_id, COALESCE(product_category, 'all_jewellery')`,
  ).all();

  const map = new Map<string, BuyerEventSignal>();

  for (const row of rows.results ?? []) {
    const r = row as any;
    const campaignId = String(r.campaign_id || '');
    if (!campaignId) continue;

    map.set(campaignId, {
      campaign_id: campaignId,
      product_category: String(r.product_category || 'all_jewellery'),
      paid_orders: n(r.paid_orders),
      paid_revenue: n(r.paid_revenue),
      order_created: n(r.order_created),
      cart_events: n(r.cart_events),
      checkout_events: n(r.checkout_events),
      whatsapp_events: n(r.whatsapp_events),
      price_asked_events: n(r.price_asked_events),
      refunds: n(r.refunds),
      cancelled: n(r.cancelled),
      negative_value: n(r.negative_value),
      total_events: n(r.total_events),
      avg_confidence: n(r.avg_confidence),
    });
  }

  return map;
}

function enrichMetricsWithBuyerEvents(
  metrics: ParsedInsights,
  signal: BuyerEventSignal,
): ParsedInsights {
  const spend = n(metrics.spend);
  const eventRevenue = n(signal.paid_revenue);
  const metaRevenue = n(metrics.revenue);
  const revenue = Math.max(metaRevenue, eventRevenue);

  return {
    ...metrics,
    revenue,
    roas: spend > 0 && revenue > 0 ? round(revenue / spend, 2) : n(metrics.roas),
    conversions: Math.max(n(metrics.conversions), signal.paid_orders),
    leads: Math.max(
      n(metrics.leads),
      signal.whatsapp_events +
        signal.price_asked_events +
        signal.cart_events +
        signal.checkout_events,
    ),
    cpa:
      signal.paid_orders > 0 && spend > 0
        ? round(spend / signal.paid_orders, 2)
        : n(metrics.cpa),
  };
}

function scoreCampaign(
  campaign: MetaCampaign,
  metrics: ParsedInsights,
  buyerEventSignal: BuyerEventSignal,
): CampaignBrainRow {

  const spend = n(metrics.spend);
  const revenue = n(metrics.revenue);
  const roas = n(metrics.roas);
  const ctr = n(metrics.ctr);
  const cpc = n(metrics.cpc);
  const cpm = n(metrics.cpm);
  const frequency = n(metrics.frequency);
  const clicks = n(metrics.clicks);
  const impressions = n(metrics.impressions);
  const conversions = n(metrics.conversions);
const productCategory =
  buyerEventSignal.product_category || inferProductCategory(campaign.name || '');

const audienceCluster = inferAudienceCluster(campaign.name || '', productCategory);

  const paidOrders = n(buyerEventSignal.paid_orders);
const paidRevenue = n(buyerEventSignal.paid_revenue);
const orderCreated = n(buyerEventSignal.order_created);
const cartEvents = n(buyerEventSignal.cart_events);
const checkoutEvents = n(buyerEventSignal.checkout_events);
const whatsappEvents = n(buyerEventSignal.whatsapp_events);
const priceAskedEvents = n(buyerEventSignal.price_asked_events);
const refunds = n(buyerEventSignal.refunds);
const cancelled = n(buyerEventSignal.cancelled);

const hasHardBuyerSignal = paidOrders > 0 || paidRevenue > 0 || revenue > 0 || roas > 0;
const hasIntentEventSignal =
  orderCreated > 0 ||
  cartEvents > 0 ||
  checkoutEvents > 0 ||
  whatsappEvents > 0 ||
  priceAskedEvents > 0;
const hasNegativeBuyerSignal = refunds > 0 || cancelled > 0;

  const reasons: string[] = [];

  const ctrScore = clamp((ctr / 3) * 25);
  const cpcScore = cpc > 0 ? clamp((12 / cpc) * 15) : 5;
  const conversionScore = conversions > 0 ? clamp(25 + conversions * 5, 25, 45) : 0;
  const roasScore = roas > 0 ? clamp(roas * 12, 0, 35) : 0;
  const clickDepthScore = clicks >= 50 ? 10 : clicks >= 20 ? 7 : clicks >= 10 ? 4 : 0;

  let buyerIntentScore = ctrScore + cpcScore + conversionScore + roasScore + clickDepthScore;

  // Meta-only guardrail: clicks without conversion should not look like strong buyer intent.
  if (spend > 500 && conversions === 0 && revenue === 0) {
    buyerIntentScore = Math.min(buyerIntentScore, 58);
  }

  if (spend > 1000 && conversions === 0 && revenue === 0) {
    buyerIntentScore = Math.min(buyerIntentScore, 45);
  }

  buyerIntentScore = clamp(buyerIntentScore);

  let wasteScore = 0;
  if (spend > 300 && clicks === 0) wasteScore += 40;
  if (spend > 700 && conversions === 0) wasteScore += 35;
  if (spend > 1000 && revenue === 0) wasteScore += 35;
  if (ctr > 0 && ctr < 0.7) wasteScore += 15;
  if (cpc > 20) wasteScore += 15;
  if (frequency > 3 && ctr < 1.2) wasteScore += 15;
  wasteScore = clamp(wasteScore);

  const productAffinityScore = clamp(
    buyerIntentScore * 0.6 +
      (conversions > 0 ? 20 : 0) +
      (roas > 0 ? Math.min(20, roas * 5) : 0),
  );

  const creativeSignalScore = clamp(
    ctrScore * 1.6 +
      cpcScore +
      (clicks > 20 ? 15 : 0) +
      (frequency > 3 ? -10 : 0) +
      (conversions > 0 ? 20 : 0),
  );

  const retargetingPriority = clamp(
    (clicks > 20 ? 30 : 0) +
      (spend > 500 ? 20 : 0) +
      (conversions === 0 ? 20 : 0) +
      (ctr > 1 ? 15 : 0) +
      (impressions > 1000 ? 15 : 0),
  );

if (hasHardBuyerSignal) {
  buyerIntentScore = Math.max(
    buyerIntentScore,
    clamp(82 + paidOrders * 4 + Math.min(10, paidRevenue / 500), 82, 100),
  );
  wasteScore = Math.max(0, wasteScore - 25);
  reasons.push('Hard buyer signal exists from order/revenue event data.');
}

if (!hasHardBuyerSignal && hasIntentEventSignal) {
  buyerIntentScore = Math.max(buyerIntentScore, 62);
  reasons.push('Intent event signal exists from cart/WhatsApp/price/order-created activity.');
}

if (!hasHardBuyerSignal && spend > 0) {
  buyerIntentScore = Math.min(buyerIntentScore, 68);
  reasons.push('Soft signal only: clicks/leads exist, but revenue/order proof is missing.');
}

if (hasNegativeBuyerSignal) {
  wasteScore = clamp(wasteScore + refunds * 25 + cancelled * 20, 0, 100);
  buyerIntentScore = Math.max(0, buyerIntentScore - refunds * 15 - cancelled * 12);
  reasons.push('Negative buyer signal exists from refund/cancel event data.');
}

  if (hasHardBuyerSignal && buyerIntentScore >= 70) {
    reasons.push('Strong buyer signal confirmed by revenue/ROAS.');
  }

  if (!hasHardBuyerSignal && clicks > 20) {
    reasons.push('Traffic signal exists; validate with retargeting before scaling.');
  }

  if (buyerIntentScore >= 50 && conversions === 0) {
    reasons.push('Engagement exists, but purchase signal is still missing.');
  }

  if (wasteScore >= 70) reasons.push('High waste risk: spend is not producing buyer outcomes.');
  if (creativeSignalScore >= 65) reasons.push('Creative appears to be attracting attention.');
  if (retargetingPriority >= 60) reasons.push('Enough traffic exists to consider retargeting.');
  if (frequency > 3) reasons.push('Frequency is rising; watch for fatigue.');
  if (roas === 0 && spend > 0) reasons.push('ROAS is zero until revenue/order attribution is connected.');

  let recommendationHint = 'watch';
  if (wasteScore >= 70) recommendationHint = 'reduce_or_pause_test';
  else if (hasHardBuyerSignal && buyerIntentScore >= 70) recommendationHint = 'scale_carefully';
  else if (!hasHardBuyerSignal && retargetingPriority >= 50) recommendationHint = 'validate_with_retargeting';
  else if (!hasHardBuyerSignal && clicks > 20) recommendationHint = 'connect_revenue_before_scaling';
  else if (retargetingPriority >= 60) recommendationHint = 'build_retargeting_test';
  else if (creativeSignalScore >= 65) recommendationHint = 'make_variation';
  else if (spend < 500) recommendationHint = 'collect_more_data';

  if (!reasons.length) reasons.push('Not enough strong signal yet. Keep collecting data.');

return {
  campaign,
  metrics,
  productCategory,
  audienceCluster,
  buyerIntentScore: round(buyerIntentScore),
  wasteScore: round(wasteScore),
  productAffinityScore: round(productAffinityScore),
  creativeSignalScore: round(creativeSignalScore),
  retargetingPriority: round(retargetingPriority),
  recommendationHint,
  reasons,
  buyerEventSignal,
};
}

function buildTargetingRecommendation(row: CampaignBrainRow) {
  const campaignName = row.campaign.name || row.campaign.id;
  const category = row.productCategory.replace(/_/g, ' ');
  const hasHardBuyerSignal = n(row.metrics.revenue) > 0 || n(row.metrics.roas) > 0;
  const clicks = n(row.metrics.clicks);
  const spend = n(row.metrics.spend);

  if (row.wasteScore >= 70) {
    return {
      id: id('buyer_brain', 'waste', row.campaign.id),
      recommendation_type: 'waste_control',
      priority: 'high',
      title: `Control waste in ${campaignName}`,
      description:
        `${campaignName} is showing high spend risk without enough buyer signal. Keep it under watch before scaling.`,
      suggested_action: 'review_targeting_and_creative',
      suggested_budget: 0,
      kill_rule: 'If spend crosses Rs. 700 with no conversion/order/WhatsApp signal, pause or rebuild test.',
      scale_rule: 'Do not scale until buyer intent score is above 65 and revenue/order signal exists.',
    };
  }

  if (!hasHardBuyerSignal && spend > 100 && clicks > 20) {
    return {
      id: id('buyer_brain', 'validate', row.campaign.id),
      recommendation_type: 'buyer_validation',
      priority: row.wasteScore >= 40 ? 'high' : 'medium',
      title: `Validate buyer quality for ${campaignName}`,
      description:
        `${campaignName} has traffic/lead signal for ${category}, but no revenue/order proof yet. Do not scale cold budget until buyer quality is confirmed.`,
      suggested_action: 'validate_with_retargeting_and_order_attribution',
      suggested_budget: 300,
      kill_rule: 'Kill or rebuild if retargeting spend crosses Rs. 500 with no WhatsApp/order/revenue signal.',
      scale_rule: 'Scale only after revenue/order attribution confirms real buyers.',
    };
  }

  if (hasHardBuyerSignal && row.buyerIntentScore >= 70) {
    return {
      id: id('buyer_brain', 'scale_test', row.campaign.id),
      recommendation_type: 'scale_test',
      priority: 'medium',
      title: `Test scale path for ${campaignName}`,
      description:
        `${campaignName} has confirmed buyer signal for ${category}. Scale slowly and watch ROAS stability.`,
      suggested_action: 'scale_test',
      suggested_budget: 500,
      kill_rule: 'Stop scale if ROAS drops or CPC rises 30%.',
      scale_rule: 'Increase budget max 15-20% after 2 stable days.',
    };
  }

  if (row.retargetingPriority >= 60) {
    return {
      id: id('buyer_brain', 'retarget', row.campaign.id),
      recommendation_type: 'retargeting_test',
      priority: 'medium',
      title: `Create retargeting test for ${category}`,
      description:
        `${campaignName} has enough click/traffic signal. Build a soft retargeting angle for ${category} viewers.`,
      suggested_action: 'create_retargeting_test',
      suggested_budget: 300,
      kill_rule: 'Kill if retargeting spend crosses Rs. 500 with no buyer signal.',
      scale_rule: 'Scale only if retargeting CPA beats cold campaign CPA.',
    };
  }

  if (row.creativeSignalScore >= 65) {
    return {
      id: id('buyer_brain', 'creative_variant', row.campaign.id),
      recommendation_type: 'creative_variant',
      priority: 'low',
      title: `Create new creative variation for ${category}`,
      description:
        `${campaignName} has creative attention signal. Make a fresh Kaapav-style light luxury variation before fatigue rises.`,
      suggested_action: 'make_creative_variation',
      suggested_budget: 0,
      kill_rule: 'Stop weak variation if CTR stays below 0.8%.',
      scale_rule: 'Promote variation only if buyer/revenue signal appears.',
    };
  }

  return null;
}

async function upsertSignalScore(env: Env, row: CampaignBrainRow) {
  const metrics = row.metrics;
  const scoreId = id('bbs', row.campaign.id, 'meta');

  await env.DB.prepare(
    `INSERT INTO buyer_signal_scores (
      id, entity_type, entity_id, source,
      buyer_intent_score, waste_score, product_affinity_score,
      creative_signal_score, retargeting_priority,
      spend, revenue, roas, ctr, cpc, cpm, frequency,
      clicks, impressions, conversions,
      product_category, audience_cluster, recommendation_hint,
      reasons_json, raw_json, calculated_at, updated_at
    ) VALUES (?, 'campaign', ?, 'meta', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
    ON CONFLICT(entity_type, entity_id, source)
    DO UPDATE SET
      buyer_intent_score = excluded.buyer_intent_score,
      waste_score = excluded.waste_score,
      product_affinity_score = excluded.product_affinity_score,
      creative_signal_score = excluded.creative_signal_score,
      retargeting_priority = excluded.retargeting_priority,
      spend = excluded.spend,
      revenue = excluded.revenue,
      roas = excluded.roas,
      ctr = excluded.ctr,
      cpc = excluded.cpc,
      cpm = excluded.cpm,
      frequency = excluded.frequency,
      clicks = excluded.clicks,
      impressions = excluded.impressions,
      conversions = excluded.conversions,
      product_category = excluded.product_category,
      audience_cluster = excluded.audience_cluster,
      recommendation_hint = excluded.recommendation_hint,
      reasons_json = excluded.reasons_json,
      raw_json = excluded.raw_json,
      calculated_at = CURRENT_TIMESTAMP,
      updated_at = CURRENT_TIMESTAMP`,
  )
    .bind(
      scoreId,
      row.campaign.id,
      row.buyerIntentScore,
      row.wasteScore,
      row.productAffinityScore,
      row.creativeSignalScore,
      row.retargetingPriority,
      round(metrics.spend),
      round(metrics.revenue),
      round(metrics.roas),
      round(metrics.ctr),
      round(metrics.cpc),
      round(metrics.cpm),
      round(metrics.frequency),
      Math.round(metrics.clicks),
      Math.round(metrics.impressions),
      Math.round(metrics.conversions),
      row.productCategory,
      row.audienceCluster,
      row.recommendationHint,
      JSON.stringify(row.reasons),
JSON.stringify({
  campaign_id: row.campaign.id,
  campaign_name: row.campaign.name,
  status: row.campaign.effective_status || row.campaign.status,
  objective: row.campaign.objective,
  metrics: row.metrics,
  buyer_event_signal: row.buyerEventSignal,
}),
    )
    .run();
}

async function upsertProductAffinity(env: Env, rows: CampaignBrainRow[]) {
  const grouped = new Map<string, CampaignBrainRow[]>();

  for (const row of rows) {
    const arr = grouped.get(row.productCategory) ?? [];
    arr.push(row);
    grouped.set(row.productCategory, arr);
  }

  for (const [category, items] of grouped.entries()) {
    const spend = items.reduce((s, r) => s + n(r.metrics.spend), 0);
    const revenue = items.reduce((s, r) => s + n(r.metrics.revenue), 0);
    const clicks = items.reduce((s, r) => s + n(r.metrics.clicks), 0);
    const impressions = items.reduce((s, r) => s + n(r.metrics.impressions), 0);
    const conversions = items.reduce((s, r) => s + n(r.metrics.conversions), 0);
    const avgIntent =
      items.reduce((s, r) => s + r.buyerIntentScore, 0) / Math.max(1, items.length);

    const best = [...items].sort((a, b) => b.buyerIntentScore - a.buyerIntentScore)[0];

    const reasons = [
      `${items.length} campaign(s) mapped to ${category}.`,
      `Average buyer intent score: ${round(avgIntent)}.`,
      spend > 0 && revenue === 0
        ? 'Revenue attribution is missing; Trio/order data will make this sharper later.'
        : 'Revenue signal available.',
    ];

    await env.DB.prepare(
      `INSERT INTO product_affinity_scores (
        id, product_category, source, buyer_intent_score,
        spend, revenue, roas, clicks, impressions, conversions,
        best_campaign_id, insight, reasons_json,
        calculated_at, updated_at
      ) VALUES (?, ?, 'meta', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT(product_category, source)
      DO UPDATE SET
        buyer_intent_score = excluded.buyer_intent_score,
        spend = excluded.spend,
        revenue = excluded.revenue,
        roas = excluded.roas,
        clicks = excluded.clicks,
        impressions = excluded.impressions,
        conversions = excluded.conversions,
        best_campaign_id = excluded.best_campaign_id,
        insight = excluded.insight,
        reasons_json = excluded.reasons_json,
        calculated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP`,
    )
      .bind(
        id('pas', category, 'meta'),
        category,
        round(avgIntent),
        round(spend),
        round(revenue),
        spend > 0 ? round(revenue / spend) : 0,
        Math.round(clicks),
        Math.round(impressions),
        Math.round(conversions),
        best?.campaign.id ?? null,
        `${category.replace(/_/g, ' ')} is currently scoring ${round(avgIntent)}/100 buyer intent from Meta-side signals.`,
        JSON.stringify(reasons),
      )
      .run();
  }
}

function categoryAudienceCluster(category: string): string {
  return `${category
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '_')
    .replace(/^_+|_+$/g, '')}_catalogue_intent_buyers`;
}

function scoreSheetCategorySignal(signal: {
  product_views: number;
  carts: number;
  checkouts: number;
  customers: number;
  total_value: number;
  order_created: number;
  paid_orders: number;
  paid_revenue: number;
  refunds: number;
  cancelled: number;
}): number {
  const viewScore = Math.min(10, signal.product_views * 0.7);
  const cartScore = Math.min(20, signal.carts * 5);
  const checkoutScore = Math.min(25, signal.checkouts * 8);
  const orderScore = Math.min(
    35,
    signal.paid_orders * 12 + signal.order_created * 4,
  );
  const customerScore = Math.min(10, signal.customers * 1.5);
  const valueScore = Math.min(
    10,
    Math.max(signal.total_value, signal.paid_revenue) / 2500,
  );
  const negativePenalty = signal.refunds * 15 + signal.cancelled * 10;

  return clamp(
    viewScore +
      cartScore +
      checkoutScore +
      orderScore +
      customerScore +
      valueScore -
      negativePenalty,
  );
}

async function getTopSheetProductsForCategory(
  env: Env,
  category: string,
): Promise<Array<Record<string, unknown>>> {
  const rows = await env.DB.prepare(
    `SELECT
      product_sku,
      product_name,
      product_category,
      COUNT(*) AS events,
      SUM(intent_weight) AS intent_score,
      SUM(event_value) AS total_value,
      SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS carts,
      SUM(CASE WHEN event_type = 'checkout_started' THEN 1 ELSE 0 END) AS checkouts
    FROM buyer_events
    WHERE source = 'sheet'
      AND product_category = ?
      AND product_sku IS NOT NULL
      AND product_sku != ''
      AND product_category IS NOT NULL
      AND product_category != ''
      AND product_category NOT IN ('Jewellery', 'All Jewellery')
      AND product_category NOT LIKE '%,%'
      AND event_type IN ('product_view', 'add_to_cart', 'checkout_started')
    GROUP BY product_sku, product_name, product_category
    ORDER BY SUM(intent_weight) DESC, SUM(event_value) DESC
    LIMIT 5`,
  )
    .bind(category)
    .all();

  return (rows.results ?? []).map((row: any) => ({
    product_sku: row.product_sku,
    product_name: row.product_name,
    product_category: row.product_category,
    events: n(row.events),
    intent_score: n(row.intent_score),
    total_value: n(row.total_value),
    carts: n(row.carts),
    checkouts: n(row.checkouts),
  }));
}

async function upsertSheetCategoryRecommendation(
  env: Env,
  signal: SheetCategorySignal,
): Promise<number> {
  const recId = id('buyer_brain', 'sheet_category', signal.product_category);

if (
  signal.buyer_intent_score < 55 &&
  signal.paid_orders === 0
) {
    await env.DB.prepare(
      `UPDATE targeting_recommendations
       SET status = 'superseded',
           priority = 'low',
           buyer_intent_score = ?,
           confidence = ?,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = ?
         AND recommendation_type = 'category_intent'
         AND status IN ('open', 'pending_approval', 'superseded')`,
    )
      .bind(signal.buyer_intent_score, signal.confidence, recId)
      .run();

    return 0;
  }

  const priority =
    signal.paid_orders >= 2 || signal.buyer_intent_score >= 80
      ? 'high'
      : signal.paid_orders >= 1 ||
          signal.checkouts >= 1 ||
          signal.carts >= 2 ||
          signal.buyer_intent_score >= 65
        ? 'medium'
        : 'low';

  const audienceCluster = categoryAudienceCluster(signal.product_category);
  const hasOrderProof = signal.paid_orders > 0 || signal.paid_revenue > 0;

  const reasons = [
    `${signal.events} buyer event(s) found for ${signal.product_category}.`,
    `${signal.product_views} view(s), ${signal.carts} cart(s), ${signal.checkouts} checkout-started signal(s).`,
    `${signal.paid_orders} paid order(s), Rs. ${round(signal.paid_revenue)} paid revenue.`,
    `${signal.customers} unique customer(s) showed category interest.`,
    hasOrderProof
      ? 'Revenue/order proof exists, so this category can move from soft intent to buyer-proof retargeting.'
      : 'No paid-order proof yet; keep this as catalogue intent only.',
  ];

  await env.DB.prepare(
    `INSERT INTO targeting_recommendations (
      id, source, recommendation_type, priority, status,
      title, description, campaign_id, product_category, audience_cluster,
      buyer_intent_score, waste_score, confidence,
      suggested_action, suggested_budget, kill_rule, scale_rule,
      payload_json, reasons_json, updated_at
    ) VALUES (?, 'buyer_brain', 'category_intent', ?, 'open', ?, ?, NULL, ?, ?, ?, 0, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(id)
    DO UPDATE SET
      recommendation_type = excluded.recommendation_type,
      priority = excluded.priority,
      status = 'open',
      title = excluded.title,
      description = excluded.description,
      product_category = excluded.product_category,
      audience_cluster = excluded.audience_cluster,
      buyer_intent_score = excluded.buyer_intent_score,
      waste_score = excluded.waste_score,
      confidence = excluded.confidence,
      suggested_action = excluded.suggested_action,
      suggested_budget = excluded.suggested_budget,
      kill_rule = excluded.kill_rule,
      scale_rule = excluded.scale_rule,
      payload_json = excluded.payload_json,
      reasons_json = excluded.reasons_json,
      updated_at = CURRENT_TIMESTAMP`,
  )
    .bind(
      recId,
      priority,
      hasOrderProof
        ? `Retarget ${signal.product_category} buyer proof`
        : `Retarget ${signal.product_category} catalogue intent`,
      hasOrderProof
        ? `${signal.product_category} has catalogue intent plus paid-order proof. Build a tighter retargeting test around proven buyers and checkout starters.`
        : `${signal.product_category} is showing catalogue intent. Build a soft retargeting test around viewers, carts, and checkout starters.`,
      signal.product_category,
      audienceCluster,
      signal.buyer_intent_score,
      signal.confidence,
      hasOrderProof
        ? 'create_revenue_proven_retargeting_test'
        : 'create_catalogue_retargeting_test',
      priority === 'high' ? 700 : priority === 'medium' ? 400 : 250,
      hasOrderProof
        ? 'Pause if spend crosses Rs. 700 without repeat WhatsApp/order signal.'
        : 'Pause this retargeting test if spend crosses Rs. 500 with no WhatsApp/order signal.',
      hasOrderProof
        ? 'Scale only if order/revenue proof stays stable for 2 days.'
        : 'Scale only after catalogue retargeting produces WhatsApp/order/revenue proof.',
      JSON.stringify({
        source: 'sheet',
        signal_type: hasOrderProof
          ? 'catalogue_plus_order_category_proof'
          : 'catalogue_category_intent',
        product_category: signal.product_category,
        events: signal.events,
        customers: signal.customers,
        product_views: signal.product_views,
        carts: signal.carts,
        checkouts: signal.checkouts,
        order_created: signal.order_created,
        paid_orders: signal.paid_orders,
        paid_revenue: signal.paid_revenue,
        refunds: signal.refunds,
        cancelled: signal.cancelled,
        total_value: signal.total_value,
        top_products: signal.top_products,
      }),
      JSON.stringify(reasons),
    )
    .run();

  return 1;
}


async function upsertSheetProductAffinityFromEvents(
  env: Env,
): Promise<{ affinitiesCreated: number; recommendationsCreated: number }> {
  const rows = await env.DB.prepare(
    `SELECT
      product_category,
      COUNT(*) AS events,
      COUNT(DISTINCT customer_key) AS customers,
      SUM(CASE WHEN event_type = 'product_view' THEN 1 ELSE 0 END) AS product_views,
      SUM(CASE WHEN event_type = 'add_to_cart' THEN 1 ELSE 0 END) AS carts,
      SUM(CASE WHEN event_type = 'checkout_started' THEN 1 ELSE 0 END) AS checkouts,
      SUM(CASE WHEN event_type = 'order_created' THEN 1 ELSE 0 END) AS order_created,
      SUM(CASE WHEN event_type = 'order_paid' THEN 1 ELSE 0 END) AS paid_orders,
      SUM(CASE WHEN event_type = 'order_paid' THEN COALESCE(event_value, 0) ELSE 0 END) AS paid_revenue,
      SUM(CASE WHEN event_type = 'refund_created' THEN 1 ELSE 0 END) AS refunds,
      SUM(CASE WHEN event_type = 'order_cancelled' THEN 1 ELSE 0 END) AS cancelled,
      SUM(event_value) AS total_value,
      SUM(intent_weight) AS intent_score,
      AVG(confidence) AS avg_confidence
    FROM buyer_events
    WHERE source = 'sheet'
      AND product_category IS NOT NULL
      AND product_category != ''
      AND product_category NOT IN ('Jewellery', 'All Jewellery')
      AND product_category NOT LIKE '%,%'
      AND event_type IN (
        'product_view',
        'add_to_cart',
        'checkout_started',
        'order_created',
        'order_paid',
        'order_cancelled',
        'refund_created'
      )
    GROUP BY product_category
    ORDER BY SUM(intent_weight) DESC
    LIMIT 50`,
  ).all();

  let affinitiesCreated = 0;
  let recommendationsCreated = 0;

  for (const row of rows.results ?? []) {
    const r = row as any;

    const baseSignal = {
      events: n(r.events),
      customers: n(r.customers),
      product_views: n(r.product_views),
      carts: n(r.carts),
      checkouts: n(r.checkouts),
      order_created: n(r.order_created),
      paid_orders: n(r.paid_orders),
      paid_revenue: n(r.paid_revenue),
      refunds: n(r.refunds),
      cancelled: n(r.cancelled),
      total_value: n(r.total_value),
    };

    const buyerIntentScore = round(scoreSheetCategorySignal(baseSignal));
    const confidence = round(
      clamp(
        n(r.avg_confidence) +
          Math.min(10, baseSignal.customers) +
          Math.min(8, baseSignal.paid_orders * 2),
        50,
        98,
      ),
    );

    const signal: SheetCategorySignal = {
      product_category: String(r.product_category || ''),
      ...baseSignal,
      intent_score: n(r.intent_score),
      avg_confidence: n(r.avg_confidence),
      buyer_intent_score: buyerIntentScore,
      confidence,
      top_products: await getTopSheetProductsForCategory(
        env,
        String(r.product_category || ''),
      ),
    };

    const reasons = [
      `${signal.events} buyer event(s) for ${signal.product_category}.`,
      `${signal.product_views} product view(s), ${signal.carts} cart(s), ${signal.checkouts} checkout-started event(s).`,
      `${signal.paid_orders} paid order(s), Rs. ${round(signal.paid_revenue)} paid revenue.`,
      signal.refunds + signal.cancelled > 0
        ? `${signal.refunds} refund(s), ${signal.cancelled} cancelled order(s) detected.`
        : 'No refund/cancellation drag detected.',
    ];

    const insight =
      signal.paid_orders > 0
        ? `${signal.product_category} is scoring ${signal.buyer_intent_score}/100 with ${signal.paid_orders} paid order(s), Rs. ${round(signal.paid_revenue)} revenue, ${signal.carts} carts and ${signal.checkouts} checkout starts.`
        : `${signal.product_category} is scoring ${signal.buyer_intent_score}/100 from catalogue behaviour: ${signal.carts} carts and ${signal.checkouts} checkout starts.`;

    await env.DB.prepare(
      `INSERT INTO product_affinity_scores (
        id, product_category, source, buyer_intent_score,
        spend, revenue, roas, clicks, impressions, conversions,
        best_campaign_id, insight, reasons_json,
        calculated_at, updated_at
      ) VALUES (?, ?, 'sheet', ?, 0, ?, 0, ?, 0, ?, NULL, ?, ?, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP)
      ON CONFLICT(product_category, source)
      DO UPDATE SET
        buyer_intent_score = excluded.buyer_intent_score,
        spend = excluded.spend,
        revenue = excluded.revenue,
        roas = excluded.roas,
        clicks = excluded.clicks,
        impressions = excluded.impressions,
        conversions = excluded.conversions,
        best_campaign_id = excluded.best_campaign_id,
        insight = excluded.insight,
        reasons_json = excluded.reasons_json,
        calculated_at = CURRENT_TIMESTAMP,
        updated_at = CURRENT_TIMESTAMP`,
    )
      .bind(
        id('pas', signal.product_category, 'sheet'),
        signal.product_category,
        signal.buyer_intent_score,
        round(signal.paid_revenue),
        Math.round(signal.events),
        Math.round(signal.carts + signal.checkouts + signal.paid_orders),
        insight,
        JSON.stringify({ reasons, signal }),
      )
      .run();

    affinitiesCreated += 1;
    recommendationsCreated += await upsertSheetCategoryRecommendation(env, signal);
  }

  return { affinitiesCreated, recommendationsCreated };
}

async function upsertRecommendation(env: Env, row: CampaignBrainRow): Promise<number> {
  const rec = buildTargetingRecommendation(row);
  if (!rec) return 0;

  await env.DB.prepare(
    `INSERT INTO targeting_recommendations (
      id, source, recommendation_type, priority, status,
      title, description, campaign_id, product_category, audience_cluster,
      buyer_intent_score, waste_score, confidence,
      suggested_action, suggested_budget, kill_rule, scale_rule,
      payload_json, reasons_json, updated_at
    ) VALUES (?, 'buyer_brain', ?, ?, 'open', ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)
    ON CONFLICT(id)
    DO UPDATE SET
      recommendation_type = excluded.recommendation_type,
      priority = excluded.priority,
      title = excluded.title,
      description = excluded.description,
      campaign_id = excluded.campaign_id,
      product_category = excluded.product_category,
      audience_cluster = excluded.audience_cluster,
      buyer_intent_score = excluded.buyer_intent_score,
      waste_score = excluded.waste_score,
      confidence = excluded.confidence,
      suggested_action = excluded.suggested_action,
      suggested_budget = excluded.suggested_budget,
      kill_rule = excluded.kill_rule,
      scale_rule = excluded.scale_rule,
      payload_json = excluded.payload_json,
      reasons_json = excluded.reasons_json,
      updated_at = CURRENT_TIMESTAMP`,
  )
    .bind(
      rec.id,
      rec.recommendation_type,
      rec.priority,
      rec.title,
      rec.description,
      row.campaign.id,
      row.productCategory,
      row.audienceCluster,
      row.buyerIntentScore,
      row.wasteScore,
      Math.max(45, Math.min(95, row.buyerIntentScore + 10)),
      rec.suggested_action,
      rec.suggested_budget,
      rec.kill_rule,
      rec.scale_rule,
      JSON.stringify({
        source: 'meta',
        campaign_id: row.campaign.id,
        campaign_name: row.campaign.name,
        product_category: row.productCategory,
        recommendation_hint: row.recommendationHint,
      }),
      JSON.stringify(row.reasons),
    )
    .run();

  return 1;
}

export async function runBuyerBrainEngine(
  env: Env,
  options: { source?: string; datePreset?: string; limit?: number } = {},
): Promise<BuyerBrainRunResult> {
  const started = Date.now();
  const runId = id('buyer_brain_run', started);
  const datePreset = options.datePreset || 'last_30d';
  const limit = Math.min(100, Math.max(1, Number(options.limit ?? 50)));

  await env.DB.prepare(
    `INSERT INTO buyer_brain_runs (id, source, status, started_at)
     VALUES (?, ?, 'started', CURRENT_TIMESTAMP)`,
  )
    .bind(runId, options.source || 'manual')
    .run();

  try {
    const campaigns = await MetaApi.getCampaigns(env, datePreset, limit);
    const buyerEventSignals = await getBuyerEventSignals(env);

const rows: CampaignBrainRow[] = campaigns.map((campaign) => {
  const rawMetrics = MetaApi.parseInsights(campaign.insights?.data || []);
  const inferredCategory = inferProductCategory(campaign.name || '');

  const buyerEventSignal =
    buyerEventSignals.get(campaign.id) ||
    emptyBuyerEventSignal(campaign.id, inferredCategory);

  const metrics = enrichMetricsWithBuyerEvents(rawMetrics, buyerEventSignal);

  return scoreCampaign(campaign, metrics, buyerEventSignal);
});

    let scoresCreated = 0;
    let recommendationsCreated = 0;

    for (const row of rows) {
      await upsertSignalScore(env, row);
      scoresCreated += 1;
      recommendationsCreated += await upsertRecommendation(env, row);
    }

await upsertProductAffinity(env, rows);

const sheetAffinityResult = await upsertSheetProductAffinityFromEvents(env);
scoresCreated += sheetAffinityResult.affinitiesCreated;
recommendationsCreated += sheetAffinityResult.recommendationsCreated;

const durationMs = Date.now() - started;

    const result: BuyerBrainRunResult = {
      ok: true,
      runId,
      campaignsProcessed: rows.length,
      scoresCreated,
      recommendationsCreated,
      durationMs,
    };

    await env.DB.prepare(
      `UPDATE buyer_brain_runs
       SET status = 'completed',
           campaigns_processed = ?,
           scores_created = ?,
           recommendations_created = ?,
           finished_at = CURRENT_TIMESTAMP,
           duration_ms = ?,
           result_json = ?
       WHERE id = ?`,
    )
      .bind(
        result.campaignsProcessed,
        result.scoresCreated,
        result.recommendationsCreated,
        result.durationMs,
        JSON.stringify(result),
        runId,
      )
      .run();

    return result;
  } catch (err: any) {
    const durationMs = Date.now() - started;

    await env.DB.prepare(
      `UPDATE buyer_brain_runs
       SET status = 'failed',
           finished_at = CURRENT_TIMESTAMP,
           duration_ms = ?,
           error = ?
       WHERE id = ?`,
    )
      .bind(durationMs, err?.message ?? String(err), runId)
      .run();

    throw err;
  }
}

export async function getBuyerBrainSummary(env: Env) {
  const summary = await env.DB.prepare(
    `SELECT
      COUNT(*) AS total_scores,
      ROUND(AVG(buyer_intent_score), 2) AS avg_buyer_intent,
      ROUND(AVG(waste_score), 2) AS avg_waste,
      ROUND(MAX(buyer_intent_score), 2) AS best_buyer_intent,
      ROUND(MAX(waste_score), 2) AS worst_waste
     FROM buyer_signal_scores`,
  ).first();

  const topSignals = await env.DB.prepare(
    `SELECT *
     FROM buyer_signal_scores
     ORDER BY buyer_intent_score DESC
     LIMIT 5`,
  ).all();

  const worstWaste = await env.DB.prepare(
    `SELECT *
     FROM buyer_signal_scores
     ORDER BY waste_score DESC
     LIMIT 5`,
  ).all();

  const productAffinity = await env.DB.prepare(
    `SELECT *
     FROM product_affinity_scores
     ORDER BY buyer_intent_score DESC
     LIMIT 8`,
  ).all();

  const recs = await env.DB.prepare(
    `SELECT *
     FROM targeting_recommendations
     WHERE status IN ('open', 'pending_approval')
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
     LIMIT 10`,
  ).all();

  const latestRun = await env.DB.prepare(
    `SELECT *
     FROM buyer_brain_runs
     ORDER BY started_at DESC
     LIMIT 1`,
  ).first();

  return {
    summary,
    topSignals: topSignals.results ?? [],
    worstWaste: worstWaste.results ?? [],
    productAffinity: productAffinity.results ?? [],
    recommendations: recs.results ?? [],
    latestRun,
  };
}