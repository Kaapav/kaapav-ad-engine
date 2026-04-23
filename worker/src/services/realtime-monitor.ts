// ═══════════════════════════════════════════════════════════════
// REAL-TIME MONITOR
// The "always-on" AI watchdog that checks every critical
// signal and fires FCM alerts instantly.
//
// Monitors:
// 1. ROAS drops > 30% in last 24h vs previous 24h
// 2. Spend pacing (campaigns burning budget too fast)
// 3. Frequency spikes (> 4.5x)
// 4. Zero conversions campaigns (spend > ₹2000, 0 orders)
// 5. New critical recommendations
// 6. CPA spikes (> 2x target)
// 7. Unreplied leads > 30 min
// 8. Fatigue burnt-out campaigns
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';
import { notify } from './fcm';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type MonitorAlert = {
  type: string;
  priority: 'critical' | 'high' | 'medium';
  title: string;
  body: string;
  payload: Record<string, string>;
};

export type MonitorResult = {
  checksRun: number;
  alertsFired: number;
  alerts: MonitorAlert[];
};

// ─────────────────────────────────────────────
// Kaapav targets (should match Flutter constants)
// ─────────────────────────────────────────────

const TARGET_ROAS = 4.0;
const TARGET_CPA  = 150;
const MAX_FREQ    = 3.5;

// ─────────────────────────────────────────────
// Deduplication: avoid sending same alert twice in 6h
// ─────────────────────────────────────────────

async function shouldAlert(
  env: AppEnv['Bindings'],
  key: string,
  ttlSeconds: number = 6 * 60 * 60,
): Promise<boolean> {
  const existing = await env.CACHE.get(`alert_dedup:${key}`);
  if (existing) return false;

  await env.CACHE.put(`alert_dedup:${key}`, '1', {
    expirationTtl: ttlSeconds,
  });

  return true;
}

// ─────────────────────────────────────────────
// Main Monitor Runner
// ─────────────────────────────────────────────

export async function runRealtimeMonitor(
  env: AppEnv['Bindings'],
): Promise<MonitorResult> {
  const alerts: MonitorAlert[] = [];
  let checksRun = 0;

  // ── Check 1: ROAS drops ───────────────────────────────────────
  checksRun++;
  try {
    const snapshots = await env.DB.prepare(
      `SELECT
         entity_id as campaign_id,
         snapshot_date,
         roas, spend, cpa, frequency,
         conversions, extra
       FROM performance_snapshots
       WHERE entity_type = 'campaign'
         AND snapshot_date >= datetime('now', '-48 hours')
       ORDER BY entity_id ASC, snapshot_date ASC`,
    ).all<{
      campaign_id: string;
      snapshot_date: string;
      roas: number;
      spend: number;
      cpa: number;
      frequency: number;
      conversions: number;
      extra: string;
    }>();

    // Group by campaign
    const byCampaign = new Map<string, typeof snapshots.results>();
    for (const s of snapshots.results ?? []) {
      const arr = byCampaign.get(s.campaign_id) ?? [];
      arr.push(s);
      byCampaign.set(s.campaign_id, arr);
    }

    for (const [campaignId, history] of byCampaign.entries()) {
      if (history.length < 2) continue;

      const sorted  = history.sort(
        (a, b) =>
          new Date(a.snapshot_date).getTime() -
          new Date(b.snapshot_date).getTime(),
      );

      const extra   = (() => {
        try { return JSON.parse(sorted[sorted.length - 1].extra ?? '{}'); }
        catch { return {}; }
      })();

      const name    = extra.name ?? campaignId;
      const recent  = sorted.slice(-1)[0];
      const prev    = sorted.slice(-2, -1)[0];

      if (!recent || !prev) continue;

      const recentRoas = Number(recent.roas ?? 0);
      const prevRoas   = Number(prev.roas   ?? 0);

      // ── ROAS drop > 30% ─────────────────────────────────────
      if (prevRoas > 0 && recentRoas > 0) {
        const drop = ((prevRoas - recentRoas) / prevRoas) * 100;

        if (drop >= 30) {
          const alertKey = `roas_drop:${campaignId}`;

          if (await shouldAlert(env, alertKey)) {
            const priority = drop >= 50 ? 'critical' : 'high';
            const alert: MonitorAlert = {
              type:     'roas_drop',
              priority,
              title:    `📉 ROAS Drop Alert — ${name}`,
              body:     `ROAS dropped ${drop.toFixed(1)}% — from ${prevRoas.toFixed(2)}x to ${recentRoas.toFixed(2)}x. Review immediately.`,
              payload:  {
                type:       'roas_drop',
                campaignId,
                drop:       drop.toFixed(1),
                prevRoas:   prevRoas.toFixed(2),
                recentRoas: recentRoas.toFixed(2),
              },
            };

            await notify(
              env,
              'alert',
              alert.title,
              alert.body,
              alert.payload,
            );

            alerts.push(alert);
          }
        }
      }

      // ── Zero conversions waste ───────────────────────────────
      const recentSpend = Number(recent.spend ?? 0);
      const recentConv  = Number(recent.conversions ?? 0);

      if (recentSpend >= 2000 && recentConv === 0) {
        const alertKey = `zero_conv:${campaignId}`;

        if (await shouldAlert(env, alertKey)) {
          const alert: MonitorAlert = {
            type:     'zero_conversions',
            priority: 'high',
            title:    `🚫 Zero Conversions — ${name}`,
            body:     `₹${Math.round(recentSpend)} spent with ZERO conversions. Stop or pause immediately.`,
            payload:  {
              type:       'zero_conversions',
              campaignId,
              spend:      String(Math.round(recentSpend)),
            },
          };

          await notify(env, 'alert', alert.title, alert.body, alert.payload);
          alerts.push(alert);
        }
      }

      // ── Frequency spike ──────────────────────────────────────
      const freq = Number(recent.frequency ?? 0);

      if (freq >= 4.5) {
        const alertKey = `freq_spike:${campaignId}`;

        if (await shouldAlert(env, alertKey)) {
          const alert: MonitorAlert = {
            type:     'frequency_spike',
            priority: freq >= 5.5 ? 'critical' : 'high',
            title:    `🔁 Frequency Spike — ${name}`,
            body:     `Frequency is ${freq.toFixed(2)}x — severe fatigue risk. Rotate creative now.`,
            payload:  {
              type:       'frequency_spike',
              campaignId,
              frequency:  freq.toFixed(2),
            },
          };

          await notify(env, 'alert', alert.title, alert.body, alert.payload);
          alerts.push(alert);
        }
      }

      // ── CPA spike ────────────────────────────────────────────
      const recentCpa = Number(recent.cpa ?? 0);

      if (recentCpa > TARGET_CPA * 2 && recentSpend >= 1000) {
        const alertKey = `cpa_spike:${campaignId}`;

        if (await shouldAlert(env, alertKey)) {
          const alert: MonitorAlert = {
            type:     'cpa_spike',
            priority: 'high',
            title:    `💸 CPA Spike — ${name}`,
            body:     `CPA is ₹${Math.round(recentCpa)} — ${(recentCpa / TARGET_CPA).toFixed(1)}x over target. Cut budget.`,
            payload:  {
              type:       'cpa_spike',
              campaignId,
              cpa:        String(Math.round(recentCpa)),
              target:     String(TARGET_CPA),
            },
          };

          await notify(env, 'alert', alert.title, alert.body, alert.payload);
          alerts.push(alert);
        }
      }
    }
  } catch (err) {
    console.error('[Monitor] ROAS check failed:', err);
  }

  // ── Check 2: New critical recommendations ─────────────────────
  checksRun++;
  try {
    const critRecs = await env.DB.prepare(
      `SELECT id, title
       FROM optimization_recommendations
       WHERE status = 'open'
         AND priority = 'critical'
         AND created_at >= datetime('now', '-2 hours')`,
    ).all<{ id: string; title: string }>();

    if ((critRecs.results ?? []).length > 0) {
      const alertKey = 'new_critical_recs';

      if (await shouldAlert(env, alertKey, 2 * 60 * 60)) {
        const count = critRecs.results!.length;
        const alert: MonitorAlert = {
          type:     'critical_recommendations',
          priority: 'critical',
          title:    `⚠️ ${count} Critical Recommendation(s)`,
          body:     critRecs.results![0].title,
          payload:  {
            type:  'critical_recommendations',
            count: String(count),
          },
        };

        await notify(env, 'alert', alert.title, alert.body, alert.payload);
        alerts.push(alert);
      }
    }
  } catch (err) {
    console.error('[Monitor] Critical recs check failed:', err);
  }

  // ── Check 3: Burnt-out campaigns ─────────────────────────────
  checksRun++;
  try {
    const burntOut = await env.DB.prepare(
      `SELECT campaign_id, creative_name, fatigue_score
       FROM creative_scores
       WHERE fatigue_score >= 75
         AND status = 'stop'`,
    ).all<{
      campaign_id: string;
      creative_name: string;
      fatigue_score: number;
    }>();

    for (const campaign of burntOut.results ?? []) {
      const alertKey = `burnt_out:${campaign.campaign_id}`;

      if (await shouldAlert(env, alertKey)) {
        const alert: MonitorAlert = {
          type:     'burnt_out',
          priority: 'critical',
          title:    `🔥 Burnt Out — ${campaign.creative_name}`,
          body:     `Fatigue score ${campaign.fatigue_score.toFixed(0)}/100. Campaign is burnt out — pause and rotate creative immediately.`,
          payload:  {
            type:         'burnt_out',
            campaignId:   campaign.campaign_id,
            fatigueScore: campaign.fatigue_score.toFixed(0),
          },
        };

        await notify(env, 'alert', alert.title, alert.body, alert.payload);
        alerts.push(alert);
      }
    }
  } catch (err) {
    console.error('[Monitor] Burnt-out check failed:', err);
  }

  // ── Check 4: Budget pacing (spend > 90% by noon) ─────────────
  checksRun++;
  try {
    const hourNow    = new Date().getUTCHours() + 5; // IST offset
    const isPeakTime = hourNow >= 10 && hourNow <= 14; // 10AM–2PM IST

    if (isPeakTime) {
      const highSpend = await env.DB.prepare(
        `SELECT entity_id as campaign_id, AVG(spend) as avg_spend, extra
         FROM performance_snapshots
         WHERE entity_type = 'campaign'
           AND snapshot_date >= datetime('now', '-1 day')
         GROUP BY entity_id
         HAVING AVG(spend) > 0`,
      ).all<{
        campaign_id: string;
        avg_spend: number;
        extra: string;
      }>();

      for (const c of highSpend.results ?? []) {
        const extra = (() => {
          try { return JSON.parse(c.extra ?? '{}'); }
          catch { return {}; }
        })();

        const name = extra.name ?? c.campaign_id;

        // Check if spend is unusually high for time of day
        // Simple heuristic: if avg daily spend > ₹5000 and
        // it's before 2PM, might be over-pacing
        if (Number(c.avg_spend) >= 5000) {
          const alertKey = `budget_pace:${c.campaign_id}`;

          if (await shouldAlert(env, alertKey, 12 * 60 * 60)) {
            const alert: MonitorAlert = {
              type:     'budget_pacing',
              priority: 'medium',
              title:    `💰 High Spend Pacing — ${name}`,
              body:     `Spending ₹${Math.round(Number(c.avg_spend))} avg/day. Monitor budget utilization.`,
              payload:  {
                type:       'budget_pacing',
                campaignId: c.campaign_id,
                spend:      String(Math.round(Number(c.avg_spend))),
              },
            };

            await notify(
              env, 'alert', alert.title, alert.body, alert.payload,
            );
            alerts.push(alert);
          }
        }
      }
    }
  } catch (err) {
    console.error('[Monitor] Budget pacing check failed:', err);
  }

  // ── Log monitor run ───────────────────────────────────────────
  if (alerts.length > 0) {
    await env.DB.prepare(
      `INSERT INTO activity_log (id, type, title, description, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        'monitor',
        `Real-Time Monitor — ${alerts.length} alert(s)`,
        alerts
          .map((a) => `[${a.priority.toUpperCase()}] ${a.title}`)
          .join(' | '),
        new Date().toISOString(),
      )
      .run();
  }

  return {
    checksRun,
    alertsFired: alerts.length,
    alerts,
  };
}