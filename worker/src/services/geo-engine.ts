// ═══════════════════════════════════════════════════════════════
// GEO INTENT LAYER
// Detects city-level ROAS and lead quality clusters.
// Uses CRM lead data + performance snapshots to find:
// - Which cities drive best ROAS
// - Which cities generate most leads
// - Which geos to scale vs suppress
// Outputs: geo_intent_scores table + geo recommendations
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type GeoStatus =
  | 'hot'
  | 'strong'
  | 'average'
  | 'weak'
  | 'suppress';

export type GeoIntentResult = {
  city: string;
  state: string;
  country: string;
  totalLeads: number;
  convertedLeads: number;
  conversionRate: number;
  totalRevenue: number;
  avgOrderValue: number;
  refundCount: number;
  intentScore: number;
  status: GeoStatus;
  recommendation: string;
};

// ─────────────────────────────────────────────
// Known high-intent Indian cities for Kaapav
// ─────────────────────────────────────────────

const TIER1_CITIES = new Set([
  'mumbai', 'delhi', 'bangalore', 'bengaluru',
  'hyderabad', 'pune', 'chennai', 'kolkata',
  'ahmedabad', 'surat', 'jaipur', 'lucknow',
]);

const HIGH_JEWELLERY_CITIES = new Set([
  'surat', 'ahmedabad', 'rajkot', 'jaipur',
  'mumbai', 'pune', 'nagpur', 'indore',
  'vadodara', 'gandhinagar', 'anand',
]);

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function normalize(value: number, min: number, max: number): number {
  if (max <= min) return 0;
  return Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
}

function extractCity(locationText: string): {
  city: string;
  state: string;
  country: string;
} {
  if (!locationText) return { city: 'unknown', state: '', country: 'India' };

  // Try to parse "City, State" or "City" format
  const parts = locationText
    .split(',')
    .map((p) => p.trim().toLowerCase());

  return {
    city:    parts[0] ?? 'unknown',
    state:   parts[1] ?? '',
    country: parts[2] ?? 'India',
  };
}

function geoStatusFromScore(score: number): GeoStatus {
  if (score >= 80) return 'hot';
  if (score >= 65) return 'strong';
  if (score >= 45) return 'average';
  if (score >= 25) return 'weak';
  return 'suppress';
}

function buildGeoRecommendation(
  city: string,
  status: GeoStatus,
  convRate: number,
  aov: number,
  refundCount: number,
): string {
  switch (status) {
    case 'hot':
      return `Scale targeting in ${city} — hot geo with ${(convRate * 100).toFixed(1)}% CVR`;
    case 'strong':
      return `${city} is a strong market. Increase bid for this geo.`;
    case 'average':
      return `${city} is average. Test different creatives before scaling.`;
    case 'weak':
      return `${city} is underperforming. Reduce bid or exclude.`;
    case 'suppress':
      return `Suppress ${city} — low quality leads, high refunds or zero conversions.`;
  }
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runGeoEngine(
  env: AppEnv['Bindings'],
): Promise<{
  processed: number;
  upserted: number;
  hotGeos: number;
  suppressGeos: number;
}> {
  // ── Load all leads with location data ────────────────────────
  const leads = await env.DB.prepare(
    `SELECT
       l.id,
       l.name,
       l.phone,
       l.stage,
       l.value,
       l.notes,
       l.campaign_id,
       l.created_at
     FROM leads l
     ORDER BY l.created_at DESC`,
  ).all<{
    id: string;
    name: string;
    phone: string;
    stage: string;
    value: number;
    notes: string | null;
    campaign_id: string | null;
    created_at: string;
  }>();

  if (!leads.results?.length) {
    return { processed: 0, upserted: 0, hotGeos: 0, suppressGeos: 0 };
  }

  // ── Load lead activities for refund signals ───────────────────
  const activities = await env.DB.prepare(
    `SELECT lead_id, type, description
     FROM lead_activities`,
  ).all<{
    lead_id: string;
    type: string;
    description: string;
  }>();

  const actsByLead = new Map<string, typeof activities.results>();
  for (const a of activities.results ?? []) {
    const arr = actsByLead.get(a.lead_id) ?? [];
    arr.push(a);
    actsByLead.set(a.lead_id, arr);
  }

  // ── Extract geo from lead notes/name heuristics ───────────────
  // In production: store city in a dedicated column
  // For now: parse from notes field or phone prefix heuristics
  const geoMap = new Map<
    string,
    {
      city: string;
      state: string;
      totalLeads: number;
      convertedLeads: number;
      totalRevenue: number;
      refundCount: number;
      avgAov: number[];
    }
  >();

  const REFUND_KEYWORDS = [
    'refund', 'return', 'cancel', 'rto', 'ndr', 'wapas',
  ];

  for (const lead of leads.results ?? []) {
    // Extract geo from notes (format: "city:Mumbai" or "Mumbai, Maharashtra")
    let city  = 'unknown';
    let state = '';

    const notes = lead.notes ?? '';

    // Try "city:CityName" pattern
    const cityMatch = notes.match(/city[:\s]+([a-zA-Z\s]+)/i);
    if (cityMatch) {
      city = cityMatch[1].trim().toLowerCase();
    } else {
      // Fallback: check if any known city is mentioned in notes
      const lowerNotes = notes.toLowerCase();
      for (const knownCity of [...TIER1_CITIES, ...HIGH_JEWELLERY_CITIES]) {
        if (lowerNotes.includes(knownCity)) {
          city = knownCity;
          break;
        }
      }
    }

    if (city === 'unknown') continue; // skip leads with no geo data

    const isConverted = lead.stage === 'Converted';
    const value       = Number(lead.value ?? 0);

    // Check refunds
    const acts = actsByLead.get(lead.id) ?? [];
    const hasRefund = acts.some(
      (a) =>
        a.type === 'refund' ||
        REFUND_KEYWORDS.some((kw) =>
          (a.description ?? '').toLowerCase().includes(kw),
        ),
    );

    const existing = geoMap.get(city) ?? {
      city,
      state,
      totalLeads:     0,
      convertedLeads: 0,
      totalRevenue:   0,
      refundCount:    0,
      avgAov:         [],
    };

    existing.totalLeads++;
    if (isConverted) {
      existing.convertedLeads++;
      if (value > 0) {
        existing.totalRevenue += value;
        existing.avgAov.push(value);
      }
    }
    if (hasRefund) existing.refundCount++;

    geoMap.set(city, existing);
  }

  if (!geoMap.size) {
    return { processed: 0, upserted: 0, hotGeos: 0, suppressGeos: 0 };
  }

  // ── Population benchmarks ─────────────────────────────────────
  const allConvRates = [...geoMap.values()]
    .filter((g) => g.totalLeads >= 2)
    .map(
      (g) =>
        g.convertedLeads / Math.max(1, g.totalLeads),
    );

  const allRevenues = [...geoMap.values()]
    .map((g) => g.totalRevenue)
    .filter((v) => v > 0);

  const maxConvRate = allConvRates.length
    ? Math.max(...allConvRates)
    : 0.5;
  const maxRevenue  = allRevenues.length
    ? Math.max(...allRevenues)
    : 100000;

  let upserted    = 0;
  let hotGeos     = 0;
  let suppressGeos = 0;

  for (const [city, data] of geoMap.entries()) {
    if (data.totalLeads < 2) continue; // skip very sparse geos

    const conversionRate = data.convertedLeads /
      Math.max(1, data.totalLeads);

    const avgOrderValue  = data.avgAov.length
      ? data.avgAov.reduce((s, v) => s + v, 0) / data.avgAov.length
      : 0;

    // ── Score components ────────────────────────────────────────

    // Conversion rate score
    const convScore = normalize(conversionRate, 0, maxConvRate);

    // Revenue score
    const revenueScore = normalize(data.totalRevenue, 0, maxRevenue);

    // AOV score: bridal/premium jewellery cities score higher
    const aovScore = normalize(avgOrderValue, 0, 20000);

    // Volume score: more leads = more signal confidence
    const volumeScore = normalize(data.totalLeads, 2, 50);

    // Refund penalty
    const refundRate    = data.totalLeads > 0
      ? data.refundCount / data.totalLeads
      : 0;
    const refundPenalty = Math.min(100, refundRate * 200);

    // Known jewellery city bonus
    const cityBonus = HIGH_JEWELLERY_CITIES.has(city) ? 10 : 0;

    const intentScore = Math.min(
      100,
      Math.max(
        0,
        convScore     * 0.30 +
        revenueScore  * 0.25 +
        aovScore      * 0.20 +
        volumeScore   * 0.15 +
        cityBonus     * 0.10 -
        refundPenalty * 0.20,
      ),
    );

    const status         = geoStatusFromScore(intentScore);
    const recommendation = buildGeoRecommendation(
      city,
      status,
      conversionRate,
      avgOrderValue,
      data.refundCount,
    );

    // ── Upsert to D1 ─────────────────────────────────────────
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO geo_intent_scores (
        id, city, state, country,
        total_leads, converted_leads, conversion_rate,
        total_revenue, avg_order_value, refund_count,
        intent_score, status, recommendation, computed_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(city) DO UPDATE SET
        total_leads     = excluded.total_leads,
        converted_leads = excluded.converted_leads,
        conversion_rate = excluded.conversion_rate,
        total_revenue   = excluded.total_revenue,
        avg_order_value = excluded.avg_order_value,
        refund_count    = excluded.refund_count,
        intent_score    = excluded.intent_score,
        status          = excluded.status,
        recommendation  = excluded.recommendation,
        computed_at     = excluded.computed_at`,
    )
      .bind(
        crypto.randomUUID(),
        city,
        data.state,
        'India',
        data.totalLeads,
        data.convertedLeads,
        Math.round(conversionRate * 1000) / 1000,
        Math.round(data.totalRevenue),
        Math.round(avgOrderValue),
        data.refundCount,
        Math.round(intentScore * 100) / 100,
        status,
        recommendation,
        now,
      )
      .run();

    // ── Generate geo recommendation ────────────────────────────
    if (status === 'hot' || status === 'suppress') {
      const recId   = `geo:${status}:${city}`;
      const priority =
        status === 'suppress' ? 'high' : 'medium';

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
          'geo',
          city,
          priority,
          status === 'hot' ? 'scale_budget' : 'reduce_budget',
          recommendation.slice(0, 100),
          recommendation,
          Math.round(intentScore),
          'open',
          JSON.stringify({
            source:         'geo_engine',
            city,
            intentScore,
            conversionRate,
            avgOrderValue,
            totalLeads:     data.totalLeads,
            convertedLeads: data.convertedLeads,
            refundCount:    data.refundCount,
          }),
          now,
        )
        .run();
    }

    if (status === 'hot') hotGeos++;
    if (status === 'suppress') suppressGeos++;
    upserted++;
  }

  return {
    processed: geoMap.size,
    upserted,
    hotGeos,
    suppressGeos,
  };
}