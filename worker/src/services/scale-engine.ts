// ═══════════════════════════════════════════════════════════════
// SCALE DECISION ENGINE
// Combines ALL Phase 1 signals into a single final decision
// per campaign. Uses audience intent + creative match + buyer
// quality + fatigue score + ROAS + stability to decide:
// scale_budget / hold / reduce_budget / pause /
// rotate_creative / retarget / duplicate
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type DecisionAction =
  | 'scale_budget'
  | 'hold'
  | 'reduce_budget'
  | 'pause'
  | 'rotate_creative'
  | 'retarget'
  | 'duplicate';

export type DecisionPriority = 'low' | 'medium' | 'high' | 'critical';

export type ScaleDecision = {
  campaignId: string;
  campaignName: string;
  action: DecisionAction;
  priority: DecisionPriority;
  confidence: number;      // 0–100
  scaleScore: number;      // 0–100
  explanation: string;
  reasons: string[];
  payload: {
    budgetDeltaPercent?: number;
    suggestedCreativeRotation?: boolean;
    suggestedRetargeting?: boolean;
    audienceIntentScore?: number;
    creativeMatchScore?: number;
    fatigueScore?: number;
    trueRoas?: number;
    adjustedRevenue?: number;
  };
};

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function normalize(value: number, min: number, max: number): number {
  if (max <= min) return 0;
  return Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
}

function clamp(v: number, min: number, max: number): number {
  return Math.min(max, Math.max(min, v));
}

// ─────────────────────────────────────────────
// Canonical Scale Decision Score Formula
// ─────────────────────────────────────────────

function computeScaleScore(input: {
  audienceIntentScore: number;  // 0–100 from audience_scores
  creativeMatchScore: number;   // 0–100 from creative_scores
  stabilityScore: number;       // 0–100 (spend consistency)
  purchaseVolumeScore: number;  // 0–100 (conversions count)
  roasScore: number;            // 0–100
  cpaScore: number;             // 0–100
  fatiguePenalty: number;       // 0–100 (subtracts)
  refundPenalty: number;        // 0–100 (subtracts)
}): number {
  const raw =
    input.audienceIntentScore  * 0.30 +
    input.creativeMatchScore   * 0.25 +
    input.stabilityScore       * 0.15 +
    input.purchaseVolumeScore  * 0.10 +
    input.roasScore            * 0.10 +
    input.cpaScore             * 0.10 -
    input.fatiguePenalty       * 0.20 -
    input.refundPenalty        * 0.10;

  return Math.min(100, Math.max(0, raw));
}

// ─────────────────────────────────────────────
// Decide action from scale score + supporting signals
// ─────────────────────────────────────────────

function decideAction(input: {
  scaleScore: number;
  fatigueScore: number;
  fatigueLabel: string;
  trueRoas: number;
  spend: number;
  conversions: number;
  refundCount: number;
}): {
  action: DecisionAction;
  priority: DecisionPriority;
  budgetDeltaPercent: number;
} {
  const {
    scaleScore,
    fatigueScore,
    fatigueLabel,
    trueRoas,
    spend,
    conversions,
    refundCount,
  } = input;

  // Burnt out → rotate creative no matter what
  if (fatigueLabel === 'burnt_out' || fatigueScore >= 75) {
    return {
      action: 'rotate_creative',
      priority: 'critical',
      budgetDeltaPercent: 0,
    };
  }

  // Dead spend → pause
  if (trueRoas < 1.0 && spend >= 2000) {
    return {
      action: 'pause',
      priority: 'critical',
      budgetDeltaPercent: 0,
    };
  }

  // Low ROAS + decent spend → reduce
  if (trueRoas < 2.0 && spend >= 1000) {
    return {
      action: 'reduce_budget',
      priority: 'high',
      budgetDeltaPercent: -30,
    };
  }

  // Scale winner
  if (scaleScore >= 80) {
    // High conviction → scale aggressively
    const delta = scaleScore >= 90 ? 20 : 15;
    return {
      action: 'scale_budget',
      priority: 'high',
      budgetDeltaPercent: delta,
    };
  }

  // Moderate scale candidate
  if (scaleScore >= 65) {
    // Fatiguing creative → rotate before scaling
    if (fatigueLabel === 'fatiguing') {
      return {
        action: 'rotate_creative',
        priority: 'medium',
        budgetDeltaPercent: 0,
      };
    }

    return {
      action: 'hold',
      priority: 'medium',
      budgetDeltaPercent: 0,
    };
  }

  // Low conversions but decent ROAS → retarget
  if (trueRoas >= 3.0 && conversions <= 5 && spend >= 500) {
    return {
      action: 'retarget',
      priority: 'medium',
      budgetDeltaPercent: 0,
    };
  }

  // Very low scale score → reduce
  if (scaleScore < 45) {
    return {
      action: 'reduce_budget',
      priority: 'medium',
      budgetDeltaPercent: -20,
    };
  }

  return {
    action: 'hold',
    priority: 'low',
    budgetDeltaPercent: 0,
  };
}

// ─────────────────────────────────────────────
// Build explanation text
// ─────────────────────────────────────────────

function buildExplanation(
  action: DecisionAction,
  input: {
    campaignName: string;
    scaleScore: number;
    trueRoas: number;
    audienceIntentScore: number;
    creativeMatchScore: number;
    fatigueScore: number;
    fatigueLabel: string;
    budgetDeltaPercent: number;
    refundCount: number;
  },
): { explanation: string; reasons: string[] } {
  const reasons: string[] = [];
  let explanation = '';

  // ROAS signal
  if (input.trueRoas >= 5) {
    reasons.push(
      `Excellent True ROAS ${input.trueRoas.toFixed(2)}x (refund-adjusted)`,
    );
  } else if (input.trueRoas >= 3) {
    reasons.push(`Good True ROAS ${input.trueRoas.toFixed(2)}x`);
  } else if (input.trueRoas < 2) {
    reasons.push(
      `Low True ROAS ${input.trueRoas.toFixed(2)}x — inefficient spend`,
    );
  }

  // Audience signal
  if (input.audienceIntentScore >= 80) {
    reasons.push(
      `Hot audience (Intent ${input.audienceIntentScore.toFixed(0)}/100)`,
    );
  } else if (input.audienceIntentScore >= 65) {
    reasons.push(
      `Scalable audience (Intent ${input.audienceIntentScore.toFixed(0)}/100)`,
    );
  } else if (input.audienceIntentScore < 45) {
    reasons.push(
      `Low audience intent (${input.audienceIntentScore.toFixed(0)}/100)`,
    );
  }

  // Creative signal
  if (input.creativeMatchScore >= 80) {
    reasons.push(
      `Winning creative match (${input.creativeMatchScore.toFixed(0)}/100)`,
    );
  } else if (input.creativeMatchScore < 40) {
    reasons.push(
      `Poor creative match (${input.creativeMatchScore.toFixed(0)}/100)`,
    );
  }

  // Fatigue signal
  if (input.fatigueLabel === 'burnt_out') {
    reasons.push(
      `Campaign burnt out (Fatigue ${input.fatigueScore.toFixed(0)}/100)`,
    );
  } else if (input.fatigueLabel === 'fatiguing') {
    reasons.push(
      `Creative fatiguing (Fatigue ${input.fatigueScore.toFixed(0)}/100)`,
    );
  }

  // Refund signal
  if (input.refundCount > 0) {
    reasons.push(
      `${input.refundCount} refund(s) detected — impacts true ROAS`,
    );
  }

  // Build explanation per action
  switch (action) {
    case 'scale_budget':
      explanation =
        `Scale ${input.campaignName} by ${input.budgetDeltaPercent}%. ` +
        `Scale score ${input.scaleScore.toFixed(0)}/100. ` +
        `Strong signals across audience, creative and ROAS.`;
      break;

    case 'hold':
      explanation =
        `Hold ${input.campaignName} — monitor for 2–3 more days. ` +
        `Score ${input.scaleScore.toFixed(0)}/100. ` +
        `Not enough conviction to scale or cut yet.`;
      break;

    case 'reduce_budget':
      explanation =
        `Reduce spend for ${input.campaignName} by ${Math.abs(input.budgetDeltaPercent)}%. ` +
        `Scale score ${input.scaleScore.toFixed(0)}/100. ` +
        `Low ROAS or weak audience signals warrant pullback.`;
      break;

    case 'pause':
      explanation =
        `Pause ${input.campaignName} immediately. ` +
        `True ROAS ${input.trueRoas.toFixed(2)}x is below break-even. ` +
        `Stop waste and review targeting + creative.`;
      break;

    case 'rotate_creative':
      explanation =
        `Rotate creative for ${input.campaignName}. ` +
        `Fatigue score ${input.fatigueScore.toFixed(0)}/100. ` +
        `Audience still has intent — fresh creative can recover performance.`;
      break;

    case 'retarget':
      explanation =
        `Launch retargeting for ${input.campaignName}. ` +
        `ROAS is decent but conversions are low. ` +
        `Warm audience exists — retarget product viewers and ATC.`;
      break;

    case 'duplicate':
      explanation =
        `Duplicate ${input.campaignName} with a fresh audience. ` +
        `Creative is working but current audience is saturating.`;
      break;
  }

  return { explanation, reasons };
}

// ─────────────────────────────────────────────
// Minimum data guardrail
// ─────────────────────────────────────────────

function meetsMinimumThreshold(spend: number, conversions: number): boolean {
  // Require at least ₹500 spend OR 1 conversion
  // to avoid acting on noise
  return spend >= 500 || conversions >= 1;
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runScaleEngine(
  env: AppEnv['Bindings'],
): Promise<{
  processed: number;
  decisionsGenerated: number;
  scaleCount: number;
  pauseCount: number;
  reduceCount: number;
  rotateCount: number;
}> {
  // ── Load all performance snapshots (7d aggregated) ───────────
  const snapshots = await env.DB.prepare(
    `SELECT
       entity_id          as campaign_id,
       AVG(spend)         as spend,
       AVG(revenue)       as revenue,
       AVG(roas)          as roas,
       AVG(cpa)           as cpa,
       AVG(ctr)           as ctr,
       SUM(conversions)   as conversions,
       AVG(frequency)     as frequency,
       COUNT(*)           as snapshot_count,
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
    cpa: number;
    ctr: number;
    conversions: number;
    frequency: number;
    snapshot_count: number;
    extra: string;
  }>();

  if (!snapshots.results?.length) {
    return {
      processed: 0,
      decisionsGenerated: 0,
      scaleCount: 0,
      pauseCount: 0,
      reduceCount: 0,
      rotateCount: 0,
    };
  }

  // ── Load audience scores ─────────────────────────────────────
  const audienceScores = await env.DB.prepare(
    `SELECT campaign_id,
            COALESCE(intent_score, 0) as intent_score,
            status as audience_status
     FROM audience_scores`,
  ).all<{
    campaign_id: string;
    intent_score: number;
    audience_status: string;
  }>();

  const audienceMap = new Map<
    string,
    { intentScore: number; status: string }
  >();
  for (const a of audienceScores.results ?? []) {
    audienceMap.set(a.campaign_id, {
      intentScore: Number(a.intent_score),
      status: a.audience_status,
    });
  }

  // ── Load creative scores ─────────────────────────────────────
  const creativeScores = await env.DB.prepare(
    `SELECT campaign_id,
            COALESCE(match_score, 0)   as match_score,
            COALESCE(fatigue_score, 0) as fatigue_score,
            status                     as creative_status
     FROM creative_scores`,
  ).all<{
    campaign_id: string;
    match_score: number;
    fatigue_score: number;
    creative_status: string;
  }>();

  const creativeMap = new Map<
    string,
    {
      matchScore: number;
      fatigueScore: number;
      creativeStatus: string;
    }
  >();
  for (const c of creativeScores.results ?? []) {
    creativeMap.set(c.campaign_id, {
      matchScore: Number(c.match_score),
      fatigueScore: Number(c.fatigue_score),
      creativeStatus: c.creative_status,
    });
  }

  // ── Load refund-adjusted ROAS ─────────────────────────────────
  const adjustedRoas = await env.DB.prepare(
    `SELECT campaign_id,
            true_roas,
            adjusted_revenue,
            refund_count
     FROM refund_adjusted_roas
     ORDER BY computed_at DESC`,
  ).all<{
    campaign_id: string;
    true_roas: number;
    adjusted_revenue: number;
    refund_count: number;
  }>();

  // Use most recent per campaign
  const adjustedRoasMap = new Map<
    string,
    { trueRoas: number; adjustedRevenue: number; refundCount: number }
  >();
  for (const r of adjustedRoas.results ?? []) {
    if (!adjustedRoasMap.has(r.campaign_id)) {
      adjustedRoasMap.set(r.campaign_id, {
        trueRoas: Number(r.true_roas),
        adjustedRevenue: Number(r.adjusted_revenue),
        refundCount: Number(r.refund_count),
      });
    }
  }

  // ── Population benchmarks ─────────────────────────────────────
  const allRoas       = snapshots.results
    .map((s) => s.roas)
    .filter((v) => v > 0);
  const allCpa        = snapshots.results
    .map((s) => s.cpa)
    .filter((v) => v > 0);
  const allConversions = snapshots.results
    .map((s) => s.conversions)
    .filter((v) => v > 0);
  const allSpends     = snapshots.results
    .map((s) => s.spend)
    .filter((v) => v > 0);

  const maxRoas    = allRoas.length ? Math.max(...allRoas) : 8;
  const minCpa     = allCpa.length  ? Math.min(...allCpa)  : 50;
  const maxCpa     = allCpa.length  ? Math.max(...allCpa)  : 500;
  const maxConv    = allConversions.length
    ? Math.max(...allConversions)
    : 100;
  const maxSpend   = allSpends.length ? Math.max(...allSpends) : 100000;

  // ── Score + decide per campaign ───────────────────────────────
  let decisionsGenerated = 0;
  let scaleCount  = 0;
  let pauseCount  = 0;
  let reduceCount = 0;
  let rotateCount = 0;

  for (const snap of snapshots.results) {
    const spend       = Number(snap.spend ?? 0);
    const revenue     = Number(snap.revenue ?? 0);
    const roas        = Number(snap.roas ?? 0);
    const cpa         = Number(snap.cpa ?? 0);
    const conversions = Number(snap.conversions ?? 0);
    const frequency   = Number(snap.frequency ?? 0);

    // Minimum data check
    if (!meetsMinimumThreshold(spend, conversions)) continue;

    const extra = (() => {
      try { return JSON.parse(snap.extra ?? '{}'); }
      catch { return {}; }
    })();

    const campaignName = extra.name ?? snap.campaign_id;

    // Get Phase 1 signals
    const audience = audienceMap.get(snap.campaign_id) ?? {
      intentScore: 50,
      status: 'watch',
    };

    const creative = creativeMap.get(snap.campaign_id) ?? {
      matchScore: 50,
      fatigueScore: 0,
      creativeStatus: 'test_more',
    };

    const adjusted = adjustedRoasMap.get(snap.campaign_id) ?? {
      trueRoas: roas,
      adjustedRevenue: revenue,
      refundCount: 0,
    };

    const trueRoas    = adjusted.trueRoas;
    const refundCount = adjusted.refundCount;

    // ── Score components ──────────────────────────────────────

    // Audience intent score (from Phase 1)
    const audienceIntentScore = audience.intentScore;

    // Creative match score (from Phase 1)
    const creativeMatchScore = creative.matchScore;

    // Stability score: how many snapshots do we have?
    // More data = more confident = higher stability
    const stabilityScore = normalize(
      snap.snapshot_count,
      1,
      7,    // 7 days = max stability
    );

    // Purchase volume score
    const purchaseVolumeScore = normalize(conversions, 0, maxConv);

    // ROAS score (use TRUE roas, not Meta roas)
    const roasScore = normalize(trueRoas, 0, maxRoas);

    // CPA score: lower = better (inverted)
    const cpaScore =
      cpa > 0
        ? normalize(maxCpa - cpa, 0, maxCpa - minCpa)
        : 50;

    // Fatigue penalty (from Phase 1)
    const fatiguePenalty = creative.fatigueScore;

    // Refund penalty: each refund reduces score
    const refundPenalty = Math.min(100, refundCount * 25);

    const scaleScore = computeScaleScore({
      audienceIntentScore,
      creativeMatchScore,
      stabilityScore,
      purchaseVolumeScore,
      roasScore,
      cpaScore,
      fatiguePenalty,
      refundPenalty,
    });

    const fatigueLabel = (() => {
      const fs = creative.fatigueScore;
      if (fs >= 75) return 'burnt_out';
      if (fs >= 50) return 'fatiguing';
      if (fs >= 25) return 'stable';
      return 'fresh';
    })();

    // ── Get final decision ──────────────────────────────────────
    const { action, priority, budgetDeltaPercent } = decideAction({
      scaleScore,
      fatigueScore: creative.fatigueScore,
      fatigueLabel,
      trueRoas,
      spend,
      conversions,
      refundCount,
    });

    const confidence = clamp(
      action === 'scale_budget'
        ? scaleScore
        : action === 'pause'
          ? 100 - scaleScore
          : 50 + Math.abs(scaleScore - 50),
      0,
      100,
    );

    const { explanation, reasons } = buildExplanation(action, {
      campaignName,
      scaleScore,
      trueRoas,
      audienceIntentScore,
      creativeMatchScore,
      fatigueScore: creative.fatigueScore,
      fatigueLabel,
      budgetDeltaPercent,
      refundCount,
    });

    // ── Upsert recommendation ────────────────────────────────────
    const recId  = `scale:${action}:${snap.campaign_id}`;
    const now    = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO optimization_recommendations (
        id, entity_type, entity_id, priority, action_type,
        title, description, score, status, payload, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(id) DO UPDATE SET
        priority    = excluded.priority,
        action_type = excluded.action_type,
        title       = excluded.title,
        description = excluded.description,
        score       = excluded.score,
        status      = 'open',
        payload     = excluded.payload`,
    )
      .bind(
        recId,
        'campaign',
        snap.campaign_id,
        priority,
        action,
        explanation.slice(0, 120),  // title = first 120 chars
        explanation,
        Math.round(scaleScore),
        'open',
        JSON.stringify({
          source: 'scale_engine',
          scaleScore,
          confidence,
          budgetDeltaPercent,
          trueRoas,
          audienceIntentScore,
          creativeMatchScore,
          fatigueScore: creative.fatigueScore,
          refundCount,
          reasons,
        }),
        now,
      )
      .run();

    decisionsGenerated++;

    // ── Counters ───────────────────────────────────────────────
    if (action === 'scale_budget') scaleCount++;
    else if (action === 'pause') pauseCount++;
    else if (action === 'reduce_budget') reduceCount++;
    else if (action === 'rotate_creative') rotateCount++;
  }

  return {
    processed: snapshots.results.length,
    decisionsGenerated,
    scaleCount,
    pauseCount,
    reduceCount,
    rotateCount,
  };
}