// ═══════════════════════════════════════════════════════════════
// WHATSAPP RESPONSE SPEED ENGINE
// Tracks the speed of lead follow-up responses.
// Correlates response speed with conversion rate.
// Generates alerts when leads are NOT responded to in time.
// Key insight: Leads replied within 5min have 4x higher CVR.
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';
import { notify } from './fcm';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type ResponseSpeedBucket =
  | 'instant'      // < 5 min
  | 'fast'         // 5–30 min
  | 'moderate'     // 30 min – 2 hr
  | 'slow'         // 2–24 hr
  | 'missed'       // > 24 hr or no reply
  | 'no_contact';  // lead not contacted at all

export type ResponseSpeedInsight = {
  bucket: ResponseSpeedBucket;
  count: number;
  conversionRate: number;
  avgRevenue: number;
};

// ─────────────────────────────────────────────
// Speed bucket from minutes
// ─────────────────────────────────────────────

function getBucket(minutes: number | null): ResponseSpeedBucket {
  if (minutes === null) return 'no_contact';
  if (minutes < 5)   return 'instant';
  if (minutes < 30)  return 'fast';
  if (minutes < 120) return 'moderate';
  if (minutes < 1440) return 'slow';
  return 'missed';
}

// ─────────────────────────────────────────────
// Speed score (used for lead quality)
// ─────────────────────────────────────────────

function speedScore(bucket: ResponseSpeedBucket): number {
  switch (bucket) {
    case 'instant':    return 100;
    case 'fast':       return 75;
    case 'moderate':   return 50;
    case 'slow':       return 25;
    case 'missed':     return 5;
    case 'no_contact': return 0;
  }
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runResponseSpeedEngine(
  env: AppEnv['Bindings'],
): Promise<{
  processed: number;
  unreplied: number;
  insights: ResponseSpeedInsight[];
  alertsSent: number;
}> {
  const now = new Date();

  // ── Load all leads created in last 48h ───────────────────────
  const recentLeads = await env.DB.prepare(
    `SELECT
       l.id, l.phone, l.name,
       l.stage, l.value, l.campaign,
       l.created_at
     FROM leads l
     WHERE l.created_at >= datetime('now', '-48 hours')
     ORDER BY l.created_at DESC`,
  ).all<{
    id: string;
    phone: string;
    name: string;
    stage: string;
    value: number;
    campaign: string;
    created_at: string;
  }>();

  // ── Load all WhatsApp messages ────────────────────────────────
  const waMessages = await env.DB.prepare(
    `SELECT phone, direction, created_at
     FROM whatsapp_bridge
     WHERE created_at >= datetime('now', '-48 hours')
     ORDER BY phone ASC, created_at ASC`,
  ).all<{
    phone: string;
    direction: string;
    created_at: string;
  }>();

  // ── Load full lead history (for CVR analysis) ─────────────────
  const allLeads = await env.DB.prepare(
    `SELECT id, phone, stage, value, created_at
     FROM leads
     ORDER BY created_at ASC`,
  ).all<{
    id: string;
    phone: string;
    stage: string;
    value: number;
    created_at: string;
  }>();

  // ── Build WA message map by phone ────────────────────────────
  const waByPhone = new Map<
    string,
    Array<{ direction: string; created_at: string }>
  >();

  for (const m of waMessages.results ?? []) {
    const arr = waByPhone.get(m.phone) ?? [];
    arr.push(m);
    waByPhone.set(m.phone, arr);
  }

  // ── Analyze response speed per recent lead ────────────────────
  const bucketStats = new Map<
    ResponseSpeedBucket,
    { count: number; converted: number; revenue: number }
  >();

  const unrepliedLeads: Array<{
    id: string;
    name: string;
    phone: string;
    campaign: string;
    minutesSinceLead: number;
  }> = [];

  for (const lead of recentLeads.results ?? []) {
    const leadTime   = new Date(lead.created_at).getTime();
    const waHistory  = waByPhone.get(lead.phone) ?? [];

    // First outbound message after lead was created
    const firstOutbound = waHistory
      .filter(
        (m) =>
          m.direction === 'outbound' &&
          new Date(m.created_at).getTime() >= leadTime,
      )
      .sort(
        (a, b) =>
          new Date(a.created_at).getTime() -
          new Date(b.created_at).getTime(),
      )[0];

    let responseMinutes: number | null = null;

    if (firstOutbound) {
      const outTime     = new Date(firstOutbound.created_at).getTime();
      responseMinutes   = (outTime - leadTime) / (1000 * 60);
    }

    const bucket    = getBucket(responseMinutes);
    const isConverted = lead.stage === 'Converted';
    const value     = Number(lead.value ?? 0);

    const existing = bucketStats.get(bucket) ?? {
      count: 0, converted: 0, revenue: 0,
    };

    existing.count++;
    if (isConverted) {
      existing.converted++;
      existing.revenue += value;
    }

    bucketStats.set(bucket, existing);

    // Flag unreplied leads > 30 min old
    if (
      (bucket === 'missed' || bucket === 'no_contact') &&
      responseMinutes === null
    ) {
      const minutesSinceLead =
        (now.getTime() - leadTime) / (1000 * 60);

      if (minutesSinceLead >= 30) {
        unrepliedLeads.push({
          id:               lead.id,
          name:             lead.name,
          phone:            lead.phone,
          campaign:         lead.campaign,
          minutesSinceLead: Math.round(minutesSinceLead),
        });
      }
    }
  }

  // ── Build insights array ──────────────────────────────────────
  const insights: ResponseSpeedInsight[] = [];

  const bucketOrder: ResponseSpeedBucket[] = [
    'instant', 'fast', 'moderate', 'slow', 'missed', 'no_contact',
  ];

  for (const bucket of bucketOrder) {
    const stats = bucketStats.get(bucket);
    if (!stats) continue;

    const conversionRate = stats.count > 0
      ? stats.converted / stats.count
      : 0;

    const avgRevenue = stats.converted > 0
      ? stats.revenue / stats.converted
      : 0;

    insights.push({
      bucket,
      count:          stats.count,
      conversionRate: Math.round(conversionRate * 1000) / 1000,
      avgRevenue:     Math.round(avgRevenue),
    });
  }

  // ── Persist insights to D1 ───────────────────────────────────
  const insightDate = now.toISOString();

  for (const insight of insights) {
    await env.DB.prepare(
      `INSERT INTO response_speed_insights (
        id, bucket, count, conversion_rate,
        avg_revenue, computed_at
      ) VALUES (?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        insight.bucket,
        insight.count,
        insight.conversionRate,
        insight.avgRevenue,
        insightDate,
      )
      .run();
  }

  // ── Alert for unreplied leads ─────────────────────────────────
  let alertsSent = 0;

  if (unrepliedLeads.length > 0) {
    const names = unrepliedLeads
      .slice(0, 3)
      .map((l) => l.name)
      .join(', ');

    const body = unrepliedLeads.length === 1
      ? `${unrepliedLeads[0].name} (${unrepliedLeads[0].minutesSinceLead}m ago) from ${unrepliedLeads[0].campaign} — no follow-up yet`
      : `${unrepliedLeads.length} leads unreplied: ${names}${unrepliedLeads.length > 3 ? ' and more' : ''}`;

    await notify(
      env,
      'alert',
      '⚡ Unreplied Leads Alert',
      body,
      {
        type:          'unreplied_leads',
        count:         String(unrepliedLeads.length),
        leadIds:       unrepliedLeads.map((l) => l.id).join(','),
      },
    );

    alertsSent++;

    // Log to activity
    await env.DB.prepare(
      `INSERT INTO activity_log (id, type, title, description, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        'alert',
        'Unreplied Leads Alert',
        body,
        insightDate,
      )
      .run();
  }

  return {
    processed:   recentLeads.results?.length ?? 0,
    unreplied:   unrepliedLeads.length,
    insights,
    alertsSent,
  };
}