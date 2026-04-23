// ═══════════════════════════════════════════════════════════════
// AUDIENCE INTENT ENGINE
// Scores every campaign/adset audience cluster by:
// CTR + CVR + ROAS + CPA + ATC + Revenue Quality - Frequency
// Outputs: intent_score, status (hot/scalable/watch/kill)
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type AudienceStatus = 'hot' | 'scalable' | 'watch' | 'kill';

export type AudienceScoreResult = {
  audienceKey: string;
  audienceName: string;
  campaignId: string;
  spend: number;
  revenue: number;
  roas: number;
  cpa: number;
  ctr: number;
  cpc: number;
  cpm: number;
  frequency: number;
  clicks: number;
  conversions: number;
  leads: number;
  intentScore: number;
  status: AudienceStatus;
  reasons: string[];
};

// ─────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────

function normalize(value: number, min: number, max: number): number {
  if (max <= min) return 0;
  return Math.min(100, Math.max(0, ((value - min) / (max - min)) * 100));
}

function audienceStatusFromScore(score: number): AudienceStatus {
  if (score >= 80) return 'hot';
  if (score >= 65) return 'scalable';
  if (score >= 45) return 'watch';
  return 'kill';
}

// ─────────────────────────────────────────────
// Canonical Audience Intent Score Formula
// ─────────────────────────────────────────────

function computeIntentScore(input: {
  ctrScore: number;         // 0–100
  cvrScore: number;         // 0–100
  roasScore: number;        // 0–100
  cpaScore: number;         // 0–100
  revenueQualityScore: number; // 0–100
  leadQualityScore: number; // 0–100
  frequencyPenalty: number; // 0–100
}): number {
  const raw =
    input.ctrScore            * 0.10 +
    input.cvrScore            * 0.20 +
    input.roasScore           * 0.25 +
    input.cpaScore            * 0.20 +
    input.revenueQualityScore * 0.10 +
    input.leadQualityScore    * 0.15 -
    input.frequencyPenalty    * 0.10;

  return Math.min(100, Math.max(0, raw));
}

// ─────────────────────────────────────────────
// Build reasons array for UI display
// ─────────────────────────────────────────────

function buildReasons(
  data: {
    roas: number;
    cpa: number;
    ctr: number;
    frequency: number;
    conversions: number;
    spend: number;
  },
  status: AudienceStatus,
): string[] {
  const reasons: string[] = [];

  if (data.roas >= 5) reasons.push(`Excellent ROAS ${data.roas.toFixed(2)}x`);
  else if (data.roas >= 3) reasons.push(`Good ROAS ${data.roas.toFixed(2)}x`);
  else if (data.roas < 2 && data.spend >= 500) reasons.push(`Low ROAS ${data.roas.toFixed(2)}x — review urgently`);

  if (data.cpa <= 150) reasons.push(`Strong CPA ₹${Math.round(data.cpa)}`);
  else if (data.cpa > 300) reasons.push(`High CPA ₹${Math.round(data.cpa)} — reduce spend`);

  if (data.ctr >= 3) reasons.push(`High CTR ${data.ctr.toFixed(2)}%`);
  else if (data.ctr < 1) reasons.push(`Low CTR ${data.ctr.toFixed(2)}% — creative may need refresh`);

  if (data.frequency >= 4.5) reasons.push(`Frequency ${data.frequency.toFixed(2)}x — severe fatigue risk`);
  else if (data.frequency >= 3.5) reasons.push(`Frequency ${data.frequency.toFixed(2)}x — monitor fatigue`);

  if (data.conversions === 0 && data.spend >= 1000) reasons.push(`Zero conversions despite ₹${Math.round(data.spend)} spend`);

  if (status === 'hot') reasons.push('Scale immediately');
  if (status === 'kill') reasons.push('Stop spend — reallocate budget');

  return reasons;
}

// ─────────────────────────────────────────────
// Main Engine Runner
// ─────────────────────────────────────────────

export async function runAudienceEngine(
  env: AppEnv['Bindings'],
): Promise<{ processed: number; upserted: number }> {
  // Load recent performance snapshots (last 7 days of campaigns)
  const snapshots = await env.DB.prepare(
    `SELECT
       entity_id as campaign_id,
       AVG(spend)       as spend,
       AVG(revenue)     as revenue,
       AVG(roas)        as roas,
       AVG(cpa)         as cpa,
       AVG(ctr)         as ctr,
       AVG(cpc)         as cpc,
       AVG(cpm)         as cpm,
       AVG(frequency)   as frequency,
       SUM(conversions) as conversions,
       extra
     FROM performance_snapshots
     WHERE entity_type = 'campaign'
       AND snapshot_date >= datetime('now', '-7 days')
     GROUP BY entity_id
     ORDER BY AVG(roas) DESC`,
  ).all<{
    campaign_id: string;
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

  // ── Population benchmarks for normalization ──────────────────
  const allRoas = snapshots.results.map((s) => s.roas).filter((v) => v > 0);
  const allCpa  = snapshots.results.map((s) => s.cpa).filter((v) => v > 0);
  const allCtr  = snapshots.results.map((s) => s.ctr).filter((v) => v > 0);

  const maxRoas = allRoas.length ? Math.max(...allRoas) : 8;
  const minCpa  = allCpa.length  ? Math.min(...allCpa)  : 50;
  const maxCpa  = allCpa.length  ? Math.max(...allCpa)  : 500;
  const maxCtr  = allCtr.length  ? Math.max(...allCtr)  : 8;

  let upserted = 0;

  for (const snap of snapshots.results) {
    const extra = (() => {
      try { return JSON.parse(snap.extra ?? '{}'); }
      catch { return {}; }
    })();

    // Audience key = campaign_id (can be refined per adset later)
    const audienceKey   = `campaign:${snap.campaign_id}`;
    const audienceName  = extra.name ?? snap.campaign_id;
    const leads         = Number(extra.leads ?? 0);
    const spend         = Number(snap.spend ?? 0);
    const revenue       = Number(snap.revenue ?? 0);
    const roas          = Number(snap.roas ?? 0);
    const cpa           = Number(snap.cpa ?? 0);
    const ctr           = Number(snap.ctr ?? 0);
    const cpc           = Number(snap.cpc ?? 0);
    const cpm           = Number(snap.cpm ?? 0);
    const frequency     = Number(snap.frequency ?? 0);
    const conversions   = Number(snap.conversions ?? 0);
    const clicks        = cpc > 0 ? spend / cpc : 0;

    // Skip campaigns with insufficient spend (noise floor)
    if (spend < 300) continue;

    // ── Score components ────────────────────────────────────────

    // CTR score
    const ctrScore = normalize(ctr, 0, maxCtr);

    // CVR score: conversions / clicks
    const cvr = clicks > 0 ? (conversions / clicks) * 100 : 0;
    const cvrScore = normalize(cvr, 0, 5); // 5% CVR = ceiling

    // ROAS score
    const roasScore = normalize(roas, 0, maxRoas);

    // CPA score: lower CPA = higher score (inverted)
    const cpaScore = cpa > 0
      ? normalize(maxCpa - cpa, maxCpa - maxCpa, maxCpa - minCpa)
      : 0;

    // Revenue quality: revenue per lead
    const revenuePerLead = leads > 0 ? revenue / leads : 0;
    const revenueQualityScore = normalize(revenuePerLead, 0, 10000);

    // Lead quality: conversion rate of leads
    const leadConvRate = leads > 0 ? (conversions / leads) * 100 : 0;
    const leadQualityScore = normalize(leadConvRate, 0, 50);

    // Frequency penalty: 0–3 = no penalty, 3–5 = penalty, 5+ = max
    const freqPenaltyRaw = Math.max(0, frequency - 3.0);
    const frequencyPenalty = normalize(freqPenaltyRaw, 0, 2); // 5.0 freq = max penalty

    const intentScore = computeIntentScore({
      ctrScore,
      cvrScore,
      roasScore,
      cpaScore,
      revenueQualityScore,
      leadQualityScore,
      frequencyPenalty,
    });

        const status = audienceStatusFromScore(intentScore);
    const reasons = buildReasons(
      { roas, cpa, ctr, frequency, conversions, spend },
      status,
    );

    // ── Upsert to D1 ─────────────────────────────────────────
    const now = new Date().toISOString();

    await env.DB.prepare(
      `INSERT INTO audience_scores (
        id, entity_date, campaign_id, adset_id,
        audience_key, audience_name,
        spend, revenue, roas, cpa, ctr, cpc, cpm,
        frequency, clicks, conversions, leads,
        intent_score, status, reasons, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(audience_key) DO UPDATE SET
        campaign_id    = excluded.campaign_id,
        audience_name  = excluded.audience_name,
        spend          = excluded.spend,
        revenue        = excluded.revenue,
        roas           = excluded.roas,
        cpa            = excluded.cpa,
        ctr            = excluded.ctr,
        cpc            = excluded.cpc,
        cpm            = excluded.cpm,
        frequency      = excluded.frequency,
        clicks         = excluded.clicks,
        conversions    = excluded.conversions,
        leads          = excluded.leads,
        intent_score   = excluded.intent_score,
        status         = excluded.status,
        reasons        = excluded.reasons,
        created_at     = excluded.created_at`,
    )
      .bind(
        crypto.randomUUID(),
        now,
        snap.campaign_id,
        null,
        audienceKey,
        audienceName,
        spend,
        revenue,
        roas,
        cpa,
        ctr,
        cpc,
        cpm,
        frequency,
        Math.round(clicks),
        conversions,
        leads,
        Math.round(intentScore * 100) / 100,
        status,
        JSON.stringify(reasons),
        now,
      )
      .run();

    upserted++;
  }

  return {
    processed: snapshots.results.length,
    upserted,
  };
}