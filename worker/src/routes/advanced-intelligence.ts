import { Hono } from 'hono';
import type { AppEnv } from '../types';
import { predictCampaignPerformance, predictLTVCohort } from '../services/predictive-engine';
import { optimizeBudgetAllocation, generateRebalancingRecommendations } from '../services/portfolio-allocator';
import { detectAnomalies } from '../services/anomaly-detector';

const app = new Hono<AppEnv>();

// GET /api/advanced/predict/:campaignId
app.get('/predict/:campaignId', async (c) => {
  try {
    const days = parseInt(c.req.query('days') || '7');
    const prediction = await predictCampaignPerformance(c.env, c.req.param('campaignId'), days);
    return c.json({ success: true, data: prediction });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/advanced/portfolio/optimize
app.get('/portfolio/optimize', async (c) => {
  try {
    const totalBudget = parseInt(c.req.query('budget') || '100000');
    const allocation = await optimizeBudgetAllocation(c.env, totalBudget);
    return c.json({ success: true, data: allocation });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// POST /api/advanced/portfolio/rebalance
app.post('/portfolio/rebalance', async (c) => {
  try {
    const recs = await generateRebalancingRecommendations(c.env);
    return c.json({ success: true, data: recs, count: recs.length });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/advanced/anomalies
app.get('/anomalies', async (c) => {
  try {
    const hours = parseInt(c.req.query('hours') || '6');
    const anomalies = await detectAnomalies(c.env, hours);
    return c.json({ success: true, data: anomalies, count: anomalies.length });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/advanced/ltv/:phone
app.get('/ltv/:phone', async (c) => {
  try {
    const ltv = await predictLTVCohort(c.env, c.req.param('phone'));
    return c.json({ success: true, data: ltv });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

export default app;