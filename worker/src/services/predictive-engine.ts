import type { Bindings } from '../types';

type TimeSeriesPoint = {
  date: string;
  spend: number;
  revenue: number;
  roas: number;
  ctr: number;
  cpm: number;
  conversions: number;
};

type PredictionResult = {
  predictedRoas: number;
  confidence: number;
  trend: 'accelerating' | 'stable' | 'declining' | 'volatile';
  recommendation: 'aggressive_scale' | 'moderate_scale' | 'hold' | 'reduce';
  expectedRevenue: number;
  riskScore: number; // 0-100, higher = riskier
};

// ═══════════════════════════════════════════════════
// PREDICTIVE AI ENGINE
// Uses exponential smoothing + trend analysis for forecasting
// ═══════════════════════════════════════════════════

export async function predictCampaignPerformance(
  env: Bindings,
  campaignId: string,
  days: number = 7
): Promise<PredictionResult> {
  const history = await fetchCampaignHistory(env, campaignId, 30);
  
  if (history.length < 7) {
    return {
      predictedRoas: 0,
      confidence: 0,
      trend: 'volatile',
      recommendation: 'hold',
      expectedRevenue: 0,
      riskScore: 100,
    };
  }

  // Double exponential smoothing (Holt's method) for trend
  const alpha = 0.3; // Smoothing factor
  const beta = 0.1;  // Trend smoothing
  
  let level = history[0].roas;
  let trend = (history[1].roas - history[0].roas);
  
  for (let i = 1; i < history.length; i++) {
    const prevLevel = level;
    level = alpha * history[i].roas + (1 - alpha) * (level + trend);
    trend = beta * (level - prevLevel) + (1 - beta) * trend;
  }

  // Forecast next N days
  const forecastRoas = level + (trend * days);
  
  // Calculate confidence based on variance
  const variance = calculateVariance(history.map(h => h.roas));
  const confidence = Math.max(0, 100 - (variance * 50));
  
  // Trend classification
  let trendDirection: PredictionResult['trend'];
  if (trend > 0.15) trendDirection = 'accelerating';
  else if (trend > -0.05) trendDirection = 'stable';
  else if (trend > -0.3) trendDirection = 'declining';
  else trendDirection = 'volatile';

  // Risk calculation (frequency + volatility + ROAS stability)
  const avgFreq = history.reduce((s, h) => s + (h.cpm / 10), 0) / history.length; // proxy
  const volatility = variance / Math.abs(forecastRoas);
  const riskScore = Math.min(100, (avgFreq * 10) + (volatility * 30) + (forecastRoas < 2 ? 40 : 0));

  // Recommendation logic
  let rec: PredictionResult['recommendation'];
  if (forecastRoas > 4.5 && trendDirection === 'accelerating' && riskScore < 30) {
    rec = 'aggressive_scale';
  } else if (forecastRoas > 3.5 && riskScore < 50) {
    rec = 'moderate_scale';
  } else if (forecastRoas < 1.8 || trendDirection === 'declining') {
    rec = 'reduce';
  } else {
    rec = 'hold';
  }

  // Expected revenue calculation
  const avgSpend = history.slice(-3).reduce((s, h) => s + h.spend, 0) / 3;
  const expectedRevenue = avgSpend * forecastRoas * days;

  return {
    predictedRoas: Math.max(0, forecastRoas),
    confidence,
    trend: trendDirection,
    recommendation: rec,
    expectedRevenue,
    riskScore,
  };
}

export async function predictLTVCohort(
  env: Bindings,
  phone: string
): Promise<{
  predicted90DayLTV: number;
  predictedRepeatRate: number;
  churnRisk: 'low' | 'medium' | 'high';
}> {
  const buyer = await env.DB.prepare(
    `SELECT * FROM buyer_scores WHERE phone = ?`
  ).bind(phone).first<any>();

  if (!buyer) {
    return { predicted90DayLTV: 0, predictedRepeatRate: 0, churnRisk: 'high' };
  }

  // RFM-inspired prediction
  const recency = daysSince(buyer.updated_at);
  const frequency = buyer.total_orders;
  const monetary = buyer.avg_order_value;

  // Cohort-based prediction using similar buyers
  const similarBuyers = await env.DB.prepare(
    `SELECT AVG(total_revenue) as avg_ltv, COUNT(*) as count
     FROM buyer_scores 
     WHERE buyer_tier = ? 
     AND total_orders >= ? 
     AND ABS(avg_order_value - ?) < 1000
     AND updated_at > datetime('now', '-90 days')`
  ).bind(buyer.buyer_tier, frequency, monetary).first<any>();

  const baseLTV = similarBuyers?.avg_ltv || monetary;
  
  // Adjust for recency decay
  const recencyMultiplier = Math.max(0.3, 1 - (recency / 90));
  
  // Adjust for tier momentum
  const tierMultiplier = buyer.buyer_tier === 'platinum' ? 1.5 : 
                        buyer.buyer_tier === 'gold' ? 1.2 : 0.9;

  const predictedLTV = baseLTV * recencyMultiplier * tierMultiplier;
  
  // Churn prediction
  let churnRisk: 'low' | 'medium' | 'high';
  if (recency > 60 && frequency < 2) churnRisk = 'high';
  else if (recency > 30 && buyer.buyer_tier === 'risk') churnRisk = 'medium';
  else churnRisk = 'low';

  return {
    predicted90DayLTV: predictedLTV,
    predictedRepeatRate: buyer.repeat_orders / Math.max(1, buyer.total_orders),
    churnRisk,
  };
}

async function fetchCampaignHistory(env: Bindings, campaignId: string, days: number): Promise<TimeSeriesPoint[]> {
  const rows = await env.DB.prepare(
    `SELECT entity_date as date, spend, roas, ctr, cpm, conversions
     FROM meta_daily 
     WHERE entity_type = 'campaign' AND entity_id = ?
     AND entity_date >= date('now', '-${days} days')
     ORDER BY entity_date ASC`
  ).bind(campaignId).all<any>();

  return (rows.results || []).map(r => ({
    date: r.date,
    spend: Number(r.spend),
    revenue: Number(r.spend) * Number(r.roas),
    roas: Number(r.roas),
    ctr: Number(r.ctr),
    cpm: Number(r.cpm),
    conversions: Number(r.conversions),
  }));
}

function calculateVariance(values: number[]): number {
  if (values.length < 2) return 0;
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  return values.reduce((s, v) => s + Math.pow(v - mean, 2), 0) / values.length;
}

function daysSince(dateStr: string): number {
  const date = new Date(dateStr);
  return Math.floor((Date.now() - date.getTime()) / (1000 * 60 * 60 * 24));
}