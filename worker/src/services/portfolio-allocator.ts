import type { Bindings } from '../types';

type CampaignAllocation = {
  campaignId: string;
  name: string;
  currentBudget: number;
  currentRoas: number;
  winRate: number; // Historical consistency 0-1
  recommendedBudget: number;
  confidence: number;
  expectedReturn: number;
};

// ═══════════════════════════════════════════════════
// PORTFOLIO OPTIMIZATION ENGINE
// Uses Kelly Criterion for optimal bet sizing + Modern Portfolio Theory
// Maximizes expected log wealth (ROAS) while minimizing variance
// ═══════════════════════════════════════════════════

export async function optimizeBudgetAllocation(
  env: Bindings,
  totalBudget: number,
  minBudgetPerCampaign: number = 500
): Promise<{
  allocations: CampaignAllocation[];
  expectedPortfolioRoas: number;
  riskLevel: 'conservative' | 'balanced' | 'aggressive';
}> {
  // Fetch campaign performance + volatility
  const campaigns = await env.DB.prepare(
    `SELECT 
      entity_id as campaign_id,
      AVG(roas) as avg_roas,
      COUNT(*) as days,
      AVG((roas - (SELECT AVG(roas) FROM meta_daily WHERE entity_type='campaign')) * 
          (roas - (SELECT AVG(roas) FROM meta_daily WHERE entity_type='campaign'))) as variance
     FROM meta_daily 
     WHERE entity_type = 'campaign' 
     AND entity_date >= date('now', '-14 days')
     GROUP BY entity_id
     HAVING COUNT(*) >= 3`
  ).all<any>();

  if (!campaigns.results || campaigns.results.length === 0) {
    return { allocations: [], expectedPortfolioRoas: 0, riskLevel: 'conservative' };
  }

  // Calculate Kelly fraction for each campaign
  // f* = (bp - q) / b
  // where b = odds (ROAS), p = win probability, q = loss probability
  const allocations: CampaignAllocation[] = campaigns.results.map(c => {
    const roas = Number(c.avg_roas) || 0;
    const variance = Number(c.variance) || 1;
    const days = Number(c.days);
    
    // Win rate: % of days with ROAS > 2
    const winRate = calculateWinRate(env, c.campaign_id);
    
    // Edge calculation
    const b = roas; // payout ratio
    const p = winRate;
    const q = 1 - p;
    
    // Kelly fraction (capped at 0.4 for safety - half-Kelly)
    let kellyFraction = (b * p - q) / b;
    kellyFraction = Math.max(0, Math.min(0.4, kellyFraction));
    
    // Adjust for volatility (sharpe-like ratio)
    const volatilityPenalty = Math.min(1, 1 / (1 + variance));
    
    return {
      campaignId: c.campaign_id,
      name: '', // Will fetch later
      currentBudget: 0, // Will fetch
      currentRoas: roas,
      winRate: p,
      recommendedBudget: 0, // Calculated below
      confidence: days > 7 ? 0.9 : 0.6,
      expectedReturn: roas * kellyFraction * volatilityPenalty,
    };
  });

  // Filter positive edge campaigns only
  const positiveEdge = allocations.filter(a => a.expectedReturn > 0);
  
  if (positiveEdge.length === 0) {
    return { allocations: [], expectedPortfolioRoas: 0, riskLevel: 'conservative' };
  }

  // Normalize weights to sum to totalBudget
  const totalEdge = positiveEdge.reduce((s, a) => s + a.expectedReturn, 0);
  
  positiveEdge.forEach(a => {
    const weight = a.expectedReturn / totalEdge;
    a.recommendedBudget = Math.max(minBudgetPerCampaign, totalBudget * weight);
  });

  // Re-normalize if we hit minimums
  const allocated = positiveEdge.reduce((s, a) => s + a.recommendedBudget, 0);
  if (allocated > totalBudget) {
    const scale = totalBudget / allocated;
    positiveEdge.forEach(a => a.recommendedBudget *= scale);
  }

  // Calculate portfolio expected return
  const portfolioRoas = positiveEdge.reduce((s, a) => {
    return s + (a.currentRoas * (a.recommendedBudget / totalBudget));
  }, 0);

  // Risk classification
  const avgVariance = campaigns.results.reduce((s, c) => s + Number(c.variance), 0) / campaigns.results.length;
  let riskLevel: 'conservative' | 'balanced' | 'aggressive';
  if (avgVariance < 0.5) riskLevel = 'conservative';
  else if (avgVariance < 2) riskLevel = 'balanced';
  else riskLevel = 'aggressive';

  return {
    allocations: positiveEdge,
    expectedPortfolioRoas: portfolioRoas,
    riskLevel,
  };
}

async function calculateWinRate(env: Bindings, campaignId: string): Promise<number> {
  const result = await env.DB.prepare(
    `SELECT 
      COUNT(CASE WHEN roas >= 2 THEN 1 END) as wins,
      COUNT(*) as total
     FROM meta_daily 
     WHERE entity_type = 'campaign' AND entity_id = ?`
  ).bind(campaignId).first<any>();
  
  if (!result || result.total === 0) return 0.5;
  return Number(result.wins) / Number(result.total);
}

export async function generateRebalancingRecommendations(
  env: Bindings
): Promise<Array<{
  campaignId: string;
  action: 'increase' | 'decrease' | 'pause';
  currentBudget: number;
  recommendedBudget: number;
  reason: string;
}>> {
  const totalBudget = await getCurrentTotalBudget(env);
  const optimal = await optimizeBudgetAllocation(env, totalBudget);
  
  const currentAllocations = await getCurrentBudgets(env);
  const recommendations: Array<{campaignId: string; action: 'increase' | 'decrease' | 'pause'; currentBudget: number; recommendedBudget: number; reason: string}> = [];
  
  for (const opt of optimal.allocations) {
    const current = currentAllocations.find(c => c.id === opt.campaignId);
    if (!current) continue;
    
    const diff = opt.recommendedBudget - current.budget;
    const diffPct = Math.abs(diff) / current.budget;
    
    if (diffPct > 0.25) { // Only suggest if >25% change
      recommendations.push({
        campaignId: opt.campaignId,
        action: diff > 0 ? 'increase' : 'decrease',
        currentBudget: current.budget,
        recommendedBudget: Math.round(opt.recommendedBudget),
        reason: `Kelly optimization: ${opt.winRate > 0.7 ? 'High win rate' : 'Positive edge'} (${opt.confidence > 0.8 ? 'high' : 'medium'} confidence)`,
      });
    }
  }
  
  // Find campaigns to pause (negative edge)
  const allCampaigns = await env.DB.prepare(
    `SELECT DISTINCT entity_id FROM meta_daily WHERE entity_type = 'campaign'`
  ).all<{ entity_id: string }>();
  
  const optimizedIds = new Set(optimal.allocations.map(a => a.campaignId));
  for (const c of allCampaigns.results || []) {
    if (!optimizedIds.has(c.entity_id)) {
      const current = currentAllocations.find(x => x.id === c.entity_id);
      if (current && current.budget > 1000) {
        recommendations.push({
          campaignId: c.entity_id,
          action: 'pause',
          currentBudget: current.budget,
          recommendedBudget: 0,
          reason: 'Negative Kelly edge - capital better allocated elsewhere',
        });
      }
    }
  }
  
  return recommendations;
}

async function getCurrentTotalBudget(env: Bindings): Promise<number> {
  // Sum of last 7 days spend * 7 (weekly projection)
  const result = await env.DB.prepare(
    `SELECT SUM(spend) as total FROM meta_daily 
     WHERE entity_type = 'campaign' 
     AND entity_date >= date('now', '-7 days')`
  ).first<{ total: number }>();
  return (result?.total || 50000) * 4; // Default 50K/week if no data
}

async function getCurrentBudgets(env: Bindings): Promise<Array<{id: string; budget: number}>> {
  // This would ideally fetch from Meta API, using recent spend as proxy
  const rows = await env.DB.prepare(
    `SELECT entity_id as id, AVG(spend) as budget 
     FROM meta_daily 
     WHERE entity_type = 'campaign'
     AND entity_date >= date('now', '-3 days')
     GROUP BY entity_id`
  ).all<{ id: string; budget: number }>();
  return rows.results || [];
}