// ═══════════════════════════════════════════════════════════════
// CREATIVE MATCH ENGINE
// Scores every campaign's creative against its audience cluster
// CTR + Hook + Conversion + ROAS + AOV + AudienceFit - Fatigue
// Outputs: match_score, fatigue_score, status (winner/test/weak/stop)
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type CreativeStatus = 'winner' | 'test_more' | 'weak' | 'stop';

export type CreativeMatchResult = {
  campaignId: string;
  creativeName: string;
  audienceKey: string;
  matchScore: number;
  fatigueScore: number;
  status: CreativeStatus;
  reasons: string[];
};

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function normalize(value: number, min: number, max: number): number {
  if (max <= min) return 0;
  return Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
}

function creativeStatusFromScore(score: number): CreativeStatus {
  if (score >= 80) return 'winner';
  if (score >= 60) return 'test_more';
  if (score >= 40) return 'weak';
  return 'stop';
}

// ─────────────────────────────────────────────
// Canonical Creative Match Score Formula
// ─────────────────────────────────────────────

function computeMatchScore(input: {
  ctrScore: number;          // 0–100
  hookScore: number;         // 0–100
  conversionScore: number;   // 0–100
  roasScore: number;         // 0–100
  aovScore: number;          // 0–100
  audienceFitScore: number;  // 0–100
  fatiguePenalty: number;    // 0–100
}): number {
  const raw =
    input.ctrScore         * 0.15 +
    input.hookScore        * 0.10 +
    input.conversionScore  * 0.30 +
    input.roasScore        * 0.20 +
    input.aovScore         * 0.10 +
    input.audienceFitScore * 0.15 -
    input.fatiguePenalty   * 0.15;

  return Math.min(100, Math.max(0, raw));
}

// ─────────────────────────────────────────────
// Fatigue Score Formula
// Higher frequency + declining CTR + declining ROAS = more fatigue
// ─────────────────────────────────────────────

function computeFatigueScore(input: {
  frequency: number;
  ctr: number;
  roas: number;
  cpm: number;
  // trend signals (compare recent 3d vs prev 3d)
  ctrTrend: number;  // negative = declining
  roasTrend: number; // negative = declining
  cpmTrend: number;  // positive = rising (bad)
}): number {
  let score = 0;

  // Frequency component (0–40 pts)
  if (input.frequency >= 5.0) score += 40;
  else if (input.frequency >= 4.0) score += 30;
  else if (input.frequency >= 3.5) score += 20;
  else if (input.frequency >= 3.0) score += 10;
  else score += 0;

  // CTR component (0–25 pts)
  if (input.ctr < 0.5) score += 25;
  else if (input.ctr < 1.0) score += 15;
  else if (input.ctr < 1.5) score += 8;
  else score += 0;

  // ROAS component (0–20 pts)
  if (input.roas < 1.5) score += 20;
  else if (input.roas < 2.5) score += 10;
  else score += 0;

  // Trend penalties (0–15 pts)
  if (input.ctrTrend < -20) score += 8;   // CTR dropped > 20%
  if (input.roasTrend < -20) score += 7;  // ROAS dropped > 20%

  return Math.min(100, Math.max(0, score));
}

function fatigueLabel(score: number): string {
  if (score >= 75) return 'burnt_out';
  if (score >= 50) return 'fatiguing';
  if (score >= 25) return 'stable';
  return 'fresh';
}

// ─────────────────────────────────────────────
// Build reasons
// ─────────────────────────────────────────────

function buildReasons(
  data: {
    roas: number;
    ctr: number;
    frequency: number;
    fatigueScore: number;
    matchScore: number;
  },
  status: CreativeStatus,
): string[] {
  const reasons: string[] = [];

  if (status === 'winner') {
    reasons.push('Strong conversion rate for this audience');
    if (data.roas >= 5) reasons.push(`ROAS ${data.roas.toFixed(2)}x — scale budget`);
  }

  if (status === 'stop') {
    reasons.push('Low conversion and ROAS — stop spend');
  }

  if (data.fatigueScore >= 75) {
    reasons.push(`Burnt out — frequency ${data.frequency.toFixed(2)}x, rotate immediately`);
  } else if (data.fatigueScore >= 50) {
    reasons.push(`Fatiguing — frequency ${data.frequency.toFixed(2)}x`);
  }

  if (data.ctr < 1.0) reasons.push(`Low CTR ${data.ctr.toFixed(2)}% — hook not working`);
  if (data.ctr >= 3.0) reasons.push(`High CTR ${data.ctr.toFixed(2)}% — hook is strong`);

  return reasons;
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runCreativeEngine(
  env: AppEnv['Bindings'],
): Promise<{ processed: number; upserted: number }> {
  // Load snapshots grouped by campaign
  const snapshots = await env.DB.prepare(
    `SELECT
       entity_id as campaign_id,
       snapshot_date,
       spend, revenue, roas, cpa, ctr,
       cpc, cpm, frequency, conversions, extra
     FROM performance_snapshots
     WHERE entity_type = 'campaign'
       AND snapshot_date >= datetime('now', '-14 days')
     ORDER BY entity_id ASC, snapshot_date ASC`,
  ).all<{
    campaign_id: string;
    snapshot_date: string;
    spend: number;
    revenue: number;
    roas: number;
    cpa: number;
    ctr: number;
    cpc: number;
    cpm: number;
    frequency: number;
    conversions: number;
    extra: string;
  }>();

  if (!snapshots.results?.length) {
    return { processed: 0, upserted: 0 };
  }

  // Load audience scores for audience fit calculation
  const audienceScores = await env.DB.prepare(
    `SELECT audience_key, campaign_id, intent_score
     FROM audience_scores`,
  ).all<{
    audience_key: string;
    campaign_id: string;
    intent_score: number;
  }>();

  const audienceScoreMap = new Map<string, number>();
  for (const a of audienceScores.results ?? []) {
    audienceScoreMap.set(a.campaign_id, Number(a.intent_score ?? 0));
  }

  // Group snapshots by campaign
  const byCampaign = new Map<
    string,
    typeof snapshots.results
  >();

  for (const s of snapshots.results) {
    const arr = byCampaign.get(s.campaign_id) ?? [];
    arr.push(s);
    byCampaign.set(s.campaign_id, arr);
  }

  // ── Population benchmarks ────────────────────────────────────
  const allRoas = snapshots.results.map((s) => s.roas).filter((v) => v > 0);
  const allCtr  = snapshots.results.map((s) => s.ctr).filter((v) => v > 0);

  const maxRoas = allRoas.length ? Math.max(...allRoas) : 8;
  const maxCtr  = allCtr.length  ? Math.max(...allCtr)  : 8;

  let upserted = 0;

  for (const [campaignId, history] of byCampaign.entries()) {
    if (history.length < 1) continue;

    // Sort by date ascending
    const sorted = history.sort(
      (a, b) =>
        new Date(a.snapshot_date).getTime() -
        new Date(b.snapshot_date).getTime(),
    );

    // Aggregate overall
    const totalSpend    = sorted.reduce((s, r) => s + r.spend, 0);
    const totalRevenue  = sorted.reduce((s, r) => s + r.revenue, 0);
    const totalConv     = sorted.reduce((s, r) => s + r.conversions, 0);

    if (totalSpend < 300) continue;

    const avgRoas      = totalSpend > 0 ? totalRevenue / totalSpend : 0;
    const avgCtr       = sorted.reduce((s, r) => s + r.ctr, 0) / sorted.length;
    const avgCpm       = sorted.reduce((s, r) => s + r.cpm, 0) / sorted.length;
    const avgFreq      = sorted.reduce((s, r) => s + r.frequency, 0) / sorted.length;

    const avgAov       = totalConv > 0 ? totalRevenue / totalConv : 0;
    const totalClicks  = sorted.reduce((s, r) => {
      return s + (r.cpc > 0 ? r.spend / r.cpc : 0);
    }, 0);
    const overallCvr   = totalClicks > 0 ? totalConv / totalClicks : 0;

    const extra = (() => {
      try {
        return JSON.parse(sorted[sorted.length - 1]?.extra ?? '{}');
      } catch { return {}; }
    })();

    const creativeName  = extra.name ?? campaignId;
    const audienceKey   = `campaign:${campaignId}`;

    // ── Trend calculation (recent 3 vs prev 3 snapshots) ────────
    const recent = sorted.slice(-3);
    const prev   = sorted.slice(-6, -3);

    const avgRecent = (key: keyof typeof sorted[0]) =>
      recent.length
        ? recent.reduce((s, r) => s + Number(r[key] ?? 0), 0) / recent.length
        : 0;

    const avgPrev = (key: keyof typeof sorted[0]) =>
      prev.length
        ? prev.reduce((s, r) => s + Number(r[key] ?? 0), 0) / prev.length
        : 0;

    const trendPct = (recentVal: number, prevVal: number) =>
      prevVal > 0 ? ((recentVal - prevVal) / prevVal) * 100 : 0;

    const ctrTrend  = trendPct(avgRecent('ctr'), avgPrev('ctr'));
    const roasTrend = trendPct(avgRecent('roas'), avgPrev('roas'));
    const cpmTrend  = trendPct(avgRecent('cpm'), avgPrev('cpm'));

    // ── Score components ────────────────────────────────────────

    const ctrScore        = normalize(avgCtr, 0, maxCtr);
    // Hook score: approximate from CTR (no thumbstop data yet)
    const hookScore       = ctrScore;
    const conversionScore = normalize(overallCvr * 100, 0, 5);
    const roasScore       = normalize(avgRoas, 0, maxRoas);
    const aovScore        = normalize(avgAov, 0, 15000); // Kaapav max AOV ~₹15k

    // Audience fit score: how aligned is this campaign with its audience intent?
    const audienceFitScore = audienceScoreMap.get(campaignId) ?? 50;

    const fatigueScore = computeFatigueScore({
      frequency: avgFreq,
      ctr: avgCtr,
      roas: avgRoas,
      cpm: avgCpm,
      ctrTrend,
      roasTrend,
      cpmTrend,
    });

    const fatiguePenalty = fatigueScore; // direct mapping 0–100

    const matchScore = computeMatchScore({
      ctrScore,
      hookScore,
      conversionScore,
      roasScore,
      aovScore,
      audienceFitScore,
      fatiguePenalty,
    });

    const status  = creativeStatusFromScore(matchScore);
    const reasons = buildReasons(
      {
        roas: avgRoas,
        ctr: avgCtr,
        frequency: avgFreq,
        fatigueScore,
        matchScore,
      },
      status,
    );

    // ── Upsert to D1 ─────────────────────────────────────────
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO creative_scores (
        id, entity_date, ad_id, creative_id,
        campaign_id, adset_id, audience_key,
        creative_name, creative_type, hook_type, angle, product_tag,
        spend, revenue, roas, ctr, conversions,
        match_score, fatigue_score, status, reasons, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(campaign_id, audience_key) DO UPDATE SET
        creative_name  = excluded.creative_name,
        spend          = excluded.spend,
        revenue        = excluded.revenue,
        roas           = excluded.roas,
        ctr            = excluded.ctr,
        conversions    = excluded.conversions,
        match_score    = excluded.match_score,
        fatigue_score  = excluded.fatigue_score,
        status         = excluded.status,
        reasons        = excluded.reasons,
        created_at     = excluded.created_at`,
    )
      .bind(
        crypto.randomUUID(),
        now,
        null,    // ad_id (not available without adset-level API)
        null,    // creative_id
        campaignId,
        null,    // adset_id
        audienceKey,
        creativeName,
        'campaign_level',
        null,    // hook_type (future: from ad creative data)
        null,    // angle
        extra.product ?? null,
        totalSpend,
        totalRevenue,
        Math.round(avgRoas * 100) / 100,
        Math.round(avgCtr  * 100) / 100,
        totalConv,
        Math.round(matchScore    * 100) / 100,
        Math.round(fatigueScore  * 100) / 100,
        status,
        JSON.stringify(reasons),
        now,
      )
      .run();

    upserted++;
  }

  return {
    processed: byCampaign.size,
    upserted,
  };
}