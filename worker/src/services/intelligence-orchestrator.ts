// ═══════════════════════════════════════════════════════════════
// INTELLIGENCE ORCHESTRATOR
// Runs all 4 Phase 1 engines in sequence and persists results.
// Called by: cron 0 */6 * * * AND POST /api/intelligence/recompute
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';
import { runBuyerEngine }    from './buyer-engine';
import { runAudienceEngine } from './audience-engine';
import { runCreativeEngine } from './creative-engine';
import { runFatigueEngine }  from './fatigue-engine';
import { notify }            from './fcm';
import { runScaleEngine }          from './scale-engine';
import { runRefundAdjustedRoas }   from './refund-roas';
import { runGeoEngine }            from './geo-engine';
import { runResponseSpeedEngine }  from './response-speed';
import { runRealtimeMonitor }      from './realtime-monitor';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type OrchestratorOptions = {
  source: 'manual' | 'cron_6h' | 'daily_report';
  notifyCritical?: boolean;
};

export type OrchestratorResult = {
  ok: boolean;
  source: string;
  durationMs: number;
  engines: {
    buyer: { processed: number; upserted: number };
    audience: { processed: number; upserted: number };
    creative: { processed: number; upserted: number };
    fatigue: {
      processed: number;
      fatiguing: number;
      burntOut: number;
      recommendationsCreated: number;
    };
  };
  criticalAlerts: number;
};

// ─────────────────────────────────────────────
// Main Orchestrator
// ─────────────────────────────────────────────

export async function runIntelligenceOrchestrator(
  env: AppEnv['Bindings'],
  options: OrchestratorOptions,
): Promise<OrchestratorResult> {
  const startTime = Date.now();

  console.log(
    `[Intelligence] Starting full recompute. Source: ${options.source}`,
  );

  // ── Phase 1: Step 1 — Buyer Engine ───────────────────────────
  let buyerResult = { processed: 0, upserted: 0 };
  try {
    buyerResult = await runBuyerEngine(env);
    console.log(
      `[Buyer] processed=${buyerResult.processed} upserted=${buyerResult.upserted}`,
    );
  } catch (err) {
    console.error('[Buyer Engine] Failed:', err);
  }

  // ── Phase 1: Step 2 — Audience Engine ────────────────────────
  let audienceResult = { processed: 0, upserted: 0 };
  try {
    audienceResult = await runAudienceEngine(env);
    console.log(
      `[Audience] processed=${audienceResult.processed} upserted=${audienceResult.upserted}`,
    );
  } catch (err) {
    console.error('[Audience Engine] Failed:', err);
  }

  // ── Phase 1: Step 3 — Creative Engine ────────────────────────
  // Needs audience scores → runs after Step 2
  let creativeResult = { processed: 0, upserted: 0 };
  try {
    creativeResult = await runCreativeEngine(env);
    console.log(
      `[Creative] processed=${creativeResult.processed} upserted=${creativeResult.upserted}`,
    );
  } catch (err) {
    console.error('[Creative Engine] Failed:', err);
  }

  // ── Phase 1: Step 4 — Fatigue Engine ─────────────────────────
  // Needs creative scores → runs after Step 3
  let fatigueResult = {
    processed: 0,
    fatiguing: 0,
    burntOut: 0,
    recommendationsCreated: 0,
  };
  try {
    fatigueResult = await runFatigueEngine(env);
    console.log(
      `[Fatigue] processed=${fatigueResult.processed} ` +
        `fatiguing=${fatigueResult.fatiguing} burntOut=${fatigueResult.burntOut}`,
    );
  } catch (err) {
    console.error('[Fatigue Engine] Failed:', err);
  }

  // ── Phase 2: Step 5 — Refund-Adjusted ROAS ───────────────────
  // Runs before Scale Engine so true ROAS is available
  let refundResult = {
    processed: 0,
    upserted: 0,
    totalRefundedRevenue: 0,
    avgRoasDelta: 0,
  };
  try {
    refundResult = await runRefundAdjustedRoas(env);
    console.log(
      `[Refund ROAS] processed=${refundResult.processed} ` +
        `refunded=₹${refundResult.totalRefundedRevenue} ` +
        `avgDelta=${refundResult.avgRoasDelta}`,
    );
  } catch (err) {
    console.error('[Refund ROAS Engine] Failed:', err);
  }

  // ── Phase 2: Step 6 — Scale Decision Engine ──────────────────
  // Uses ALL Phase 1 outputs + refund ROAS → runs last
  let scaleResult = {
    processed: 0,
    decisionsGenerated: 0,
    scaleCount: 0,
    pauseCount: 0,
    reduceCount: 0,
    rotateCount: 0,
  };
  try {
    scaleResult = await runScaleEngine(env);
    console.log(
      `[Scale] decisions=${scaleResult.decisionsGenerated} ` +
        `scale=${scaleResult.scaleCount} pause=${scaleResult.pauseCount} ` +
        `reduce=${scaleResult.reduceCount} rotate=${scaleResult.rotateCount}`,
    );
  } catch (err) {
    console.error('[Scale Engine] Failed:', err);
  }

  // ── Phase 4: Step 7 — Geo Engine ─────────────────────────────
  let geoResult = {
    processed: 0, upserted: 0,
    hotGeos: 0, suppressGeos: 0,
  };
  try {
    geoResult = await runGeoEngine(env);
    console.log(
      `[Geo] processed=${geoResult.processed} ` +
      `hot=${geoResult.hotGeos} suppress=${geoResult.suppressGeos}`,
    );
  } catch (err) {
    console.error('[Geo Engine] Failed:', err);
  }

  // ── Phase 4: Step 8 — Response Speed ─────────────────────────
  let responseResult = {
    processed: 0, unreplied: 0, insights: [], alertsSent: 0,
  };
  try {
    responseResult = await runResponseSpeedEngine(env);
    console.log(
      `[Response Speed] unreplied=${responseResult.unreplied} ` +
      `alerts=${responseResult.alertsSent}`,
    );
  } catch (err) {
    console.error('[Response Speed Engine] Failed:', err);
  }

  // ── Phase 4: Step 9 — Real-Time Monitor ──────────────────────
  let monitorResult = {
    checksRun: 0, alertsFired: 0, alerts: [],
  };
  try {
    monitorResult = await runRealtimeMonitor(env);
    console.log(
      `[Monitor] checks=${monitorResult.checksRun} ` +
      `alerts=${monitorResult.alertsFired}`,
    );
  } catch (err) {
    console.error('[Realtime Monitor] Failed:', err);
  }

  // ── Activity Log ──────────────────────────────────────────────
  const durationMs = Date.now() - startTime;

  await env.DB.prepare(
    `INSERT INTO activity_log (id, type, title, description, created_at)
     VALUES (?, ?, ?, ?, ?)`,
  )
    .bind(
      crypto.randomUUID(),
      'intelligence',
      'Full Intelligence Recompute (Phase 1 + 2)',
      `Source: ${options.source} | ` +
        `Buyers: ${buyerResult.upserted} | ` +
        `Audiences: ${audienceResult.upserted} | ` +
        `Creatives: ${creativeResult.upserted} | ` +
        `Fatigue Recs: ${fatigueResult.recommendationsCreated} | ` +
        `Refund-ROAS: ${refundResult.upserted} (₹${refundResult.totalRefundedRevenue} refunded) | ` +
        `Scale Decisions: ${scaleResult.decisionsGenerated} | ` +
        `Duration: ${durationMs}ms`,
      new Date().toISOString(),
    )
    .run();

  // ── Critical Alert Notification ───────────────────────────────
  let criticalAlerts = 0;

  if (options.notifyCritical) {
    try {
      const critical = await env.DB.prepare(
        `SELECT COUNT(*) as count
         FROM optimization_recommendations
         WHERE status = 'open' AND priority = 'critical'`,
      ).first<{ count: number }>();

      criticalAlerts = Number(critical?.count ?? 0);

      if (criticalAlerts > 0) {
        const msg =
          `${criticalAlerts} critical alert(s): ` +
          `${scaleResult.pauseCount} to pause, ` +
          `${fatigueResult.burntOut} burnt out, ` +
          `refunded ₹${refundResult.totalRefundedRevenue}`;

        await notify(
          env,
          'alert',
          '⚠️ Critical Intelligence Alerts',
          msg,
          {
            type: 'intelligence_critical',
            criticalCount: String(criticalAlerts),
            pauseCount: String(scaleResult.pauseCount),
            burntOut: String(fatigueResult.burntOut),
            refundedRevenue: String(refundResult.totalRefundedRevenue),
          },
        );
      }
    } catch (err) {
      console.error('[Orchestrator] FCM notify failed:', err);
    }
  }

  return {
    ok: true,
    source: options.source,
    durationMs,
    engines: {
      buyer:    buyerResult,
      audience: audienceResult,
      creative: creativeResult,
      fatigue:  fatigueResult,
    },
    criticalAlerts,
  };
}
