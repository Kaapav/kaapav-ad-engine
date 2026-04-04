import { Hono } from 'hono';
import type { AppEnv } from '../types';
import * as MetaApi from '../services/meta-api';

const app = new Hono<AppEnv>();

// GET / — List all campaigns (KV cached 15min)
app.get('/', async (c) => {
  const datePreset = c.req.query('date_preset') || 'last_30d';
  const limit = parseInt(c.req.query('limit') || '50');
  const cacheKey = `campaigns:${datePreset}:${limit}`;

  // Check cache
  const cached = await c.env.CACHE.get(cacheKey);
  if (cached) {
    return c.json({ success: true, data: JSON.parse(cached), meta: { cached: true } });
  }

  try {
    const raw = await MetaApi.getCampaigns(c.env, datePreset, limit);
    const data = raw.map((mc) => ({
      id: mc.id,
      name: mc.name,
      objective: mc.objective,
      status: mc.effective_status || mc.status,
      daily_budget: parseInt(mc.daily_budget || '0') / 100,
      lifetime_budget: parseInt(mc.lifetime_budget || '0') / 100,
      ...MetaApi.parseInsights(mc.insights?.data || []),
    }));

    await c.env.CACHE.put(cacheKey, JSON.stringify(data), { expirationTtl: 900 });
    return c.json({ success: true, data, meta: { total: data.length, cached: false } });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /:id — Single campaign + adsets + insights
app.get('/:id', async (c) => {
  try {
    const data = await MetaApi.getCampaignDetail(c.env, c.req.param('id'), c.req.query('date_preset') || 'last_30d');
    return c.json({ success: true, data });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /:id/insights — Daily insights
app.get('/:id/insights', async (c) => {
  try {
    const raw = await MetaApi.getCampaignInsights(
      c.env, c.req.param('id'),
      c.req.query('date_preset') || 'last_30d',
      c.req.query('time_increment') || '1'
    );
    const data = raw.map((d) => ({ date: d.date_start, ...MetaApi.parseInsights([d]) }));
    return c.json({ success: true, data });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// POST / — Create campaign
app.post('/', async (c) => {
  try {
    const body = await c.req.json();
    const result = await MetaApi.createCampaign(c.env, body);
    await invalidateCache(c.env);
    return c.json({ success: true, data: result }, 201);
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// PATCH /:id — Update status/budget
app.patch('/:id', async (c) => {
  const id = c.req.param('id');
  try {
    const body = await c.req.json();
    if (body.status) await MetaApi.updateCampaignStatus(c.env, id, body.status);
    if (body.daily_budget || body.lifetime_budget)
      await MetaApi.updateCampaignBudget(c.env, id, body.daily_budget, body.lifetime_budget);

    await invalidateCache(c.env);
    return c.json({ success: true, data: { id, ...body } });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

async function invalidateCache(env: AppEnv['Bindings']) {
  await Promise.allSettled([
    env.CACHE.delete('campaigns:last_7d:50'),
    env.CACHE.delete('campaigns:last_30d:50'),
    env.CACHE.delete('campaigns:last_14d:50'),
  ]);
}

export default app;