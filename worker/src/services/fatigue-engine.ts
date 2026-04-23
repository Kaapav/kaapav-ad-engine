// ═══════════════════════════════════════════════════════════════
// FATIGUE ENGINE (DEEP)
// Detects creative and audience fatigue using time-series trends
// Generates rotate_creative / retarget recommendations
// Labels: fresh / stable / fatiguing / burnt_out
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type FatigueLabel =
  | 'fresh'
  | 'stable'
  | 'fatiguing'
  | 'burnt_out';

export type FatigueResult = {
  campaignId: string;
  campaignName: string;
  fatigueScore: number;
  fatigueLabel: FatigueLabel;
  frequency: number;
  ctrTrend: number;
  roasTrend: number;
  cpmTrend: number;
  recommendedAction: 'none' | 'monitor' | 'rotate_creative' | 'pause';
  signals: string[];
};

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function fatigueLabel(score: number): FatigueLabel {
  if (score >= 75) return 'burnt_out';
  if (score >= 50) return 'fatiguing';
  if (score >= 25) return 'stable';
  return 'fresh';
}

function recommendedAction(
  label: FatigueLabel,
  roas: number,
): FatigueResult['recommendedAction'] {
  if (label === 'burnt_out') return 'pause';
  if (label === 'fatiguing') return 'rotate_creative';
  if (label === 'stable' && roas < 2) return 'monitor';
  return 'none';
}

function trendPct(recent: number, prev: number): number {
  if (prev === 0) return 0;
  return ((recent - prev) / prev) * 100;
}

function avg(arr: number[]): number {
  if (!arr.length) return 0;
  return arr.reduce((s, v) => s + v, 0) / arr.length;
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runFatigueEngine(
  env: AppEnv['Bindings'],
): Promise<{
  processed: number;
  fatiguing: number;
  burntOut: number;
  recommendationsCreated: number;
}> {
  // Load all performance snapshots with time dimension
  const snapshots = await env.DB.prepare(
    `SELECT
       entity_id  as campaign_id,
       snapshot_date,
       spend, roas, ctr, cpm, frequency, conversions, extra
     FROM performance_snapshots
     WHERE entity_type = 'campaign'
       AND snapshot_date >= datetime('now', '-14 days')
     ORDER BY entity_id ASC, snapshot_date ASC`,
  ).all<{
    campaign_id: string;
    snapshot_date: string;
    spend: number;
    roas: number;
    ctr: number;
    cpm: number;
    frequency: number;
    conversions: number;
    extra: string;
  }>();

  if (!snapshots.results?.length) {
    return { processed: 0, fatiguing: 0, burntOut: 0, recommendationsCreated: 0 };
  }

  // Group by campaign
  const byCampaign = new Map<string, typeof snapshots.results>();
  for (const s of snapshots.results) {
    const arr = byCampaign.get(s.campaign_id) ?? [];
    arr.push(s);
    byCampaign.set(s.campaign_id, arr);
  }

  let fatiguing     = 0;
  let burntOut      = 0;
  let recsCreated   = 0;

  for (const [campaignId, history] of byCampaign.entries()) {
    if (history.length < 3) continue; // need minimum data

    // Sort ascending by date
    const sorted = history.sort(
      (a, b) =>
        new Date(a.snapshot_date).getTime() -
        new Date(b.snapshot_date).getTime(),
    );

    // Recent 3 vs prev 3 windows
    const recentWindow = sorted.slice(-3);
    const prevWindow   = sorted.slice(-6, -3);

    const recentCtr  = avg(recentWindow.map((r) => r.ctr));
    const recentRoas = avg(recentWindow.map((r) => r.roas));
    const recentCpm  = avg(recentWindow.map((r) => r.cpm));
    const recentFreq = avg(recentWindow.map((r) => r.frequency));

    const prevCtr    = avg(prevWindow.map((r) => r.ctr));
    const prevRoas   = avg(prevWindow.map((r) => r.roas));
    const prevCpm    = avg(prevWindow.map((r) => r.cpm));

    const ctrTrend   = trendPct(recentCtr, prevCtr);   // negative = declining
    const roasTrend  = trendPct(recentRoas, prevRoas); // negative = declining
    const cpmTrend   = trendPct(recentCpm, prevCpm);   // positive = rising (bad)

    const currentRoas = recentRoas;

    // ── Compute fatigue score ───────────────────────────────────

    let score = 0;

    // Frequency signal (0–40)
    if (recentFreq >= 5.0)      score += 40;
    else if (recentFreq >= 4.0) score += 30;
    else if (recentFreq >= 3.5) score += 20;
    else if (recentFreq >= 3.0) score += 10;

    // CTR decline signal (0–20)
    if (ctrTrend < -30)      score += 20;
    else if (ctrTrend < -20) score += 14;
    else if (ctrTrend < -10) score += 7;

    // ROAS decline signal (0–20)
    if (roasTrend < -30)      score += 20;
    else if (roasTrend < -20) score += 14;
    else if (roasTrend < -10) score += 7;

    // CPM rise signal (0–10)
    if (cpmTrend > 30)      score += 10;
    else if (cpmTrend > 15) score += 5;

    // Absolute CTR floor (0–10)
    if (recentCtr < 0.5)      score += 10;
    else if (recentCtr < 1.0) score += 5;

    const fatigueScore = Math.min(100, Math.max(0, score));
    const label        = fatigueLabel(fatigueScore);
    const action       = recommendedAction(label, currentRoas);

    // ── Build signals ────────────────────────────────────────────
    const signals: string[] = [];

    if (recentFreq >= 3.5) {
      signals.push(
        `Frequency ${recentFreq.toFixed(2)}x — ${recentFreq >= 4.5 ? 'severe' : 'moderate'} fatigue`,
      );
    }
    if (ctrTrend < -15) {
      signals.push(
        `CTR declined ${Math.abs(ctrTrend).toFixed(1)}% vs previous window`,
      );
    }
    if (roasTrend < -15) {
      signals.push(
        `ROAS declined ${Math.abs(roasTrend).toFixed(1)}% vs previous window`,
      );
    }
    if (cpmTrend > 15) {
      signals.push(
        `CPM rising ${cpmTrend.toFixed(1)}% — market saturation signal`,
      );
    }
    if (label === 'fresh') {
      signals.push('Healthy creative — no fatigue detected');
    }

    // Extract campaign name from extra
    const extra = (() => {
      try {
        return JSON.parse(
          sorted[sorted.length - 1]?.extra ?? '{}',
        );
      } catch { return {}; }
    })();

    const campaignName = extra.name ?? campaignId;

    // ── Update creative_scores fatigue field ──────────────────
    await env.DB.prepare(
      `UPDATE creative_scores
       SET fatigue_score = ?,
           status = CASE
             WHEN ? >= 75 THEN 'stop'
             WHEN ? >= 50 THEN 'weak'
             WHEN status = 'winner' THEN 'winner'
             ELSE status
           END
       WHERE campaign_id = ?`,
    )
      .bind(
        fatigueScore,
        fatigueScore,
        fatigueScore,
        campaignId,
      )
      .run();

    // ── Generate fatigue recommendation ──────────────────────
    if (action === 'rotate_creative' || action === 'pause') {
      const recId = `fatigue:${action}:${campaignId}`;

      const priority = label === 'burnt_out' ? 'critical' : 'high';

      const title =
        action === 'pause'
          ? `Pause ${campaignName} — burnt out`
          : `Rotate creative for ${campaignName}`;

      const description =
        action === 'pause'
          ? `Fatigue score ${fatigueScore.toFixed(0)}/100. ` +
            `Frequency ${recentFreq.toFixed(2)}x with ROAS declining ${Math.abs(roasTrend).toFixed(1)}%. ` +
            `Pause immediately and refresh creative before relaunching.`
          : `Fatigue score ${fatigueScore.toFixed(0)}/100. ` +
            `Frequency ${recentFreq.toFixed(2)}x and CTR declining ${Math.abs(ctrTrend).toFixed(1)}%. ` +
            `Rotate to fresh creatives to maintain performance.`;

      const now = new Date().toISOString();

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
          action,
          title,
          description,
          fatigueScore,
          'open',
          JSON.stringify({
            source: 'fatigue_engine',
            fatigueScore,
            fatigueLabel: label,
            frequency: recentFreq,
            ctrTrend,
            roasTrend,
            signals,
          }),
          now,
        )
        .run();

      recsCreated++;
    }

    // ── Counters ─────────────────────────────────────────────
    if (label === 'burnt_out') burntOut++;
    else if (label === 'fatiguing') fatiguing++;
  }

  return {
    processed: byCampaign.size,
    fatiguing,
    burntOut,
    recommendationsCreated: recsCreated,
  };
}