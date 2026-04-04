import { Hono } from 'hono';
import type { AppEnv } from '../types';
import * as MetaApi from '../services/meta-api';

const app = new Hono<AppEnv>();

// GET /summary — Account-level insights
app.get('/summary', async (c) => {
  const datePreset = c.req.query('date_preset') || 'last_30d';
  const cacheKey = `analytics:summary:${datePreset}`;

  const cached = await c.env.CACHE.get(cacheKey);
  if (cached) return c.json({ success: true, data: JSON.parse(cached), meta: { cached: true } });

  try {
    const insights = await MetaApi.getAccountInsights(c.env, datePreset);
    const data = MetaApi.parseInsights(insights);
    await c.env.CACHE.put(cacheKey, JSON.stringify(data), { expirationTtl: 1800 });
    return c.json({ success: true, data, meta: { cached: false } });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /daily — Daily breakdown
app.get('/daily', async (c) => {
  const datePreset = c.req.query('date_preset') || 'last_30d';
  const cacheKey = `analytics:daily:${datePreset}`;

  const cached = await c.env.CACHE.get(cacheKey);
  if (cached) return c.json({ success: true, data: JSON.parse(cached), meta: { cached: true } });

  try {
    const insights = await MetaApi.getAccountInsights(c.env, datePreset, '1');
    const data = insights.map((d) => ({ date: d.date_start, ...MetaApi.parseInsights([d]) }));
    await c.env.CACHE.put(cacheKey, JSON.stringify(data), { expirationTtl: 1800 });
    return c.json({ success: true, data, meta: { cached: false } });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /crm-stats — Pipeline stage counts + values from D1
app.get('/crm-stats', async (c) => {
  const stages = ['New', 'Contacted', 'Qualified', 'Converted', 'Lost'];
  const stats: Record<string, { count: number; value: number }> = {};

  for (const stage of stages) {
    const row = await c.env.DB.prepare(
      'SELECT COUNT(*) as count, COALESCE(SUM(value), 0) as total_value FROM leads WHERE stage = ?'
    ).bind(stage).first<{ count: number; total_value: number }>();
    stats[stage] = { count: row?.count || 0, value: row?.total_value || 0 };
  }

  const total = await c.env.DB.prepare(
    'SELECT COUNT(*) as count, COALESCE(SUM(value), 0) as total_value FROM leads'
  ).first<{ count: number; total_value: number }>();

  return c.json({
    success: true,
    data: { stages: stats, total_leads: total?.count || 0, total_value: total?.total_value || 0 },
  });
});

export default app;