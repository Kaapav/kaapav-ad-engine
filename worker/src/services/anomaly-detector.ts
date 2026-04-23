import type { Bindings } from '../types';

type Anomaly = {
  type: 'spike' | 'drop' | 'flatline' | 'volatility';
  severity: 'low' | 'medium' | 'high' | 'critical';
  campaignId: string;
  metric: string;
  expectedValue: number;
  actualValue: number;
  deviation: number; // Standard deviations
  timestamp: string;
  recommendation: string;
};

// ═══════════════════════════════════════════════════
// ANOMALY DETECTION ENGINE
// Uses Statistical Process Control (SPC) + Isolation Forest concepts
// Detects: Sudden drops, unnatural spikes, flatlines (bot traffic)
// ═══════════════════════════════════════════════════

export async function detectAnomalies(
  env: Bindings,
  lookbackHours: number = 6
): Promise<Anomaly[]> {
  const anomalies: Anomaly[] = [];
  
  // Check recent performance vs historical baseline
  const campaigns = await env.DB.prepare(
    `SELECT DISTINCT entity_id FROM meta_daily WHERE entity_type = 'campaign'`
  ).all<{ entity_id: string }>();
  
  for (const { entity_id } of campaigns.results || []) {
    // Fetch recent vs baseline
    const recent = await fetchRecentMetrics(env, entity_id, lookbackHours);
    const baseline = await fetchBaselineMetrics(env, entity_id, 14); // 14 day baseline
    
    if (baseline.mean === 0) continue;
    
    // CTR Anomaly
    const ctrZScore = (recent.ctr - baseline.meanCtr) / baseline.stdCtr;
    if (Math.abs(ctrZScore) > 3) {
      anomalies.push({
        type: ctrZScore > 0 ? 'spike' : 'drop',
        severity: Math.abs(ctrZScore) > 4 ? 'critical' : 'high',
        campaignId: entity_id,
        metric: 'CTR',
        expectedValue: baseline.meanCtr,
        actualValue: recent.ctr,
        deviation: ctrZScore,
        timestamp: new Date().toISOString(),
        recommendation: ctrZScore > 0 
          ? 'Creative fatigue reversed or viral moment - scale budget 20%' 
          : 'Creative fatigue or audience saturation - rotate immediately',
      });
    }
    
    // ROAS Anomaly
    const roasZScore = (recent.roas - baseline.meanRoas) / baseline.stdRoas;
    if (roasZScore < -2.5) { // Only care about drops for ROAS
      anomalies.push({
        type: 'drop',
        severity: roasZScore < -4 ? 'critical' : 'high',
        campaignId: entity_id,
        metric: 'ROAS',
        expectedValue: baseline.meanRoas,
        actualValue: recent.roas,
        deviation: roasZScore,
        timestamp: new Date().toISOString(),
        recommendation: roasZScore < -3 
          ? 'Immediate pause - potential tracking issue or audience exhaustion' 
          : 'Reduce budget 30% and investigate creative/landing page',
      });
    }
    
    // Flatline detection (zero conversions but spend > 0)
    if (recent.conversions === 0 && recent.spend > 1000 && baseline.meanConversions > 2) {
      anomalies.push({
        type: 'flatline',
        severity: 'critical',
        campaignId: entity_id,
        metric: 'conversions',
        expectedValue: baseline.meanConversions,
        actualValue: 0,
        deviation: -99,
        timestamp: new Date().toISOString(),
        recommendation: 'Tracking pixel failure or landing page down - investigate immediately',
      });
    }
    
    // CPM Volatility (competitor entering auction)
    const cpmZScore = (recent.cpm - baseline.meanCpm) / baseline.stdCpm;
    if (cpmZScore > 3) {
      anomalies.push({
        type: 'spike',
        severity: 'medium',
        campaignId: entity_id,
        metric: 'CPM',
        expectedValue: baseline.meanCpm,
        actualValue: recent.cpm,
        deviation: cpmZScore,
        timestamp: new Date().toISOString(),
        recommendation: 'Auction competition increased - narrow audience or increase bid cap',
      });
    }
  }
  
  // Store anomalies for alerting
  for (const anomaly of anomalies) {
    await storeAnomaly(env, anomaly);
  }
  
  return anomalies.sort((a, b) => Math.abs(b.deviation) - Math.abs(a.deviation));
}

type BaselineStats = {
  meanCtr: number;
  stdCtr: number;
  meanRoas: number;
  stdRoas: number;
  meanConversions: number;
  meanCpm: number;
  stdCpm: number;
};

async function fetchBaselineMetrics(
  env: Bindings, 
  campaignId: string, 
  days: number
): Promise<BaselineStats> {
  const rows = await env.DB.prepare(
    `SELECT ctr, roas, conversions, cpm 
     FROM meta_daily 
     WHERE entity_type = 'campaign' AND entity_id = ?
     AND entity_date >= date('now', '-${days} days')
     AND entity_date < date('now', '-1 day')` // Exclude today for baseline
  ).bind(campaignId).all<any>();
  
  const data = rows.results || [];
  if (data.length === 0) {
    return { meanCtr: 0, stdCtr: 1, meanRoas: 0, stdRoas: 1, meanConversions: 0, meanCpm: 0, stdCpm: 1 };
  }
  
  return {
    meanCtr: mean(data.map(d => d.ctr)),
    stdCtr: stdDev(data.map(d => d.ctr)) || 0.1,
    meanRoas: mean(data.map(d => d.roas)),
    stdRoas: stdDev(data.map(d => d.roas)) || 0.5,
    meanConversions: mean(data.map(d => d.conversions)),
    meanCpm: mean(data.map(d => d.cpm)),
    stdCpm: stdDev(data.map(d => d.cpm)) || 1,
  };
}

async function fetchRecentMetrics(env: Bindings, campaignId: string, hours: number) {
  // Using meta_daily as proxy for recent (last entry)
  const row = await env.DB.prepare(
    `SELECT ctr, roas, conversions, spend, cpm 
     FROM meta_daily 
     WHERE entity_type = 'campaign' AND entity_id = ?
     ORDER BY entity_date DESC LIMIT 1`
  ).bind(campaignId).first<any>();
  
  return {
    ctr: row?.ctr || 0,
    roas: row?.roas || 0,
    conversions: row?.conversions || 0,
    spend: row?.spend || 0,
    cpm: row?.cpm || 0,
  };
}

function mean(values: number[]): number {
  if (values.length === 0) return 0;
  return values.reduce((a, b) => a + b, 0) / values.length;
}

function stdDev(values: number[]): number {
  if (values.length < 2) return 0;
  const m = mean(values);
  const variance = values.reduce((s, v) => s + Math.pow(v - m, 2), 0) / values.length;
  return Math.sqrt(variance);
}

async function storeAnomaly(env: Bindings, anomaly: Anomaly) {
  await env.DB.prepare(
    `INSERT INTO optimization_recommendations 
     (id, entity_type, entity_id, priority, action_type, title, description, score, status, payload, created_at)
     VALUES (?, 'anomaly', ?, ?, 'alert', ?, ?, ?, 'open', ?, datetime('now'))
     ON CONFLICT(id) DO UPDATE SET
       description = excluded.description,
       score = excluded.score`
  ).bind(
    `anomaly:${anomaly.campaignId}:${anomaly.metric}:${anomaly.timestamp.slice(0, 10)}`,
    anomaly.campaignId,
    anomaly.severity,
    `${anomaly.type.toUpperCase()}: ${anomaly.metric} in ${anomaly.campaignId.slice(-6)}`,
    `${anomaly.metric} ${anomaly.type}: ${anomaly.actualValue.toFixed(2)} vs ${anomaly.expectedValue.toFixed(2)} (${anomaly.deviation.toFixed(1)}σ). ${anomaly.recommendation}`,
    Math.abs(anomaly.deviation) * 10,
    JSON.stringify(anomaly)
  ).run();
}