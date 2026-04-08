import { Hono } from 'hono';
import type { AppEnv, ApiResponse } from '../types';
import {
  getIntelligenceSummary,
  runIntelligenceBootstrap,
} from '../services/intelligence-orchestrator';

const app = new Hono<AppEnv>();

app.get('/summary', async (c) => {
  try {
    const summary = await getIntelligenceSummary(c.env);
    return c.json({ success: true, data: summary } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.post('/recompute', async (c) => {
  try {
    const result = await runIntelligenceBootstrap(c.env, {
      source: 'manual',
      notifyCritical: true,
    });
    return c.json({ success: true, data: result } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.get('/audiences', async (c) => {
  try {
    const q = c.req.query();

    const status = q.status?.trim();
    const campaignId = q.campaign_id?.trim();
    const adsetId = q.adset_id?.trim();
    const limit = Math.min(200, Math.max(1, Number(q.limit ?? 100)));

    const where: string[] = [];
    const bind: unknown[] = [];

    if (status) {
      where.push('status = ?');
      bind.push(status);
    }
    if (campaignId) {
      where.push('campaign_id = ?');
      bind.push(campaignId);
    }
    if (adsetId) {
      where.push('adset_id = ?');
      bind.push(adsetId);
    }

    const sql =
      `SELECT *
       FROM audience_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY created_at DESC
       LIMIT ?`;

    bind.push(limit);

    const rows = await c.env.DB.prepare(sql).bind(...bind).all();
    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.get('/creatives', async (c) => {
  try {
    const q = c.req.query();

    const status = q.status?.trim();
    const campaignId = q.campaign_id?.trim();
    const adsetId = q.adset_id?.trim();
    const audienceKey = q.audience_key?.trim();
    const limit = Math.min(200, Math.max(1, Number(q.limit ?? 100)));

    const where: string[] = [];
    const bind: unknown[] = [];

    if (status) {
      where.push('status = ?');
      bind.push(status);
    }
    if (campaignId) {
      where.push('campaign_id = ?');
      bind.push(campaignId);
    }
    if (adsetId) {
      where.push('adset_id = ?');
      bind.push(adsetId);
    }
    if (audienceKey) {
      where.push('audience_key = ?');
      bind.push(audienceKey);
    }

    const sql =
      `SELECT *
       FROM creative_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY created_at DESC
       LIMIT ?`;

    bind.push(limit);

    const rows = await c.env.DB.prepare(sql).bind(...bind).all();
    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.get('/buyers', async (c) => {
  try {
    const q = c.req.query();

    const tier = q.tier?.trim();
    const seed = q.lookalike_seed_eligible?.trim();
    const affinity = q.product_affinity?.trim();
    const limit = Math.min(200, Math.max(1, Number(q.limit ?? 100)));

    const where: string[] = [];
    const bind: unknown[] = [];

    if (tier) {
      where.push('buyer_tier = ?');
      bind.push(tier);
    }
    if (seed === '0' || seed === '1') {
      where.push('lookalike_seed_eligible = ?');
      bind.push(Number(seed));
    }
    if (affinity) {
      where.push('product_affinity = ?');
      bind.push(affinity);
    }

    const sql =
      `SELECT *
       FROM buyer_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY buyer_quality_score DESC
       LIMIT ?`;

    bind.push(limit);

    const rows = await c.env.DB.prepare(sql).bind(...bind).all();
    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.get('/recommendations', async (c) => {
  try {
    const q = c.req.query();

    const status = q.status?.trim();
    const priority = q.priority?.trim();
    const limit = Math.min(200, Math.max(1, Number(q.limit ?? 100)));

    const where: string[] = [];
    const bind: unknown[] = [];

    if (status) {
      where.push('status = ?');
      bind.push(status);
    }
    if (priority) {
      where.push('priority = ?');
      bind.push(priority);
    }

    const sql =
      `SELECT *
       FROM optimization_recommendations
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY
         CASE priority
           WHEN 'critical' THEN 4
           WHEN 'high' THEN 3
           WHEN 'medium' THEN 2
           WHEN 'low' THEN 1
           ELSE 0
         END DESC,
         COALESCE(score, 0) DESC,
         created_at DESC
       LIMIT ?`;

    bind.push(limit);

    const rows = await c.env.DB.prepare(sql).bind(...bind).all();
    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.post('/recommendations/:id/apply', async (c) => {
  try {
    const id = c.req.param('id');

    const result = await c.env.DB.prepare(
      `UPDATE optimization_recommendations
       SET status = 'applied'
       WHERE id = ?`,
    )
      .bind(id)
      .run();

    if ((result.meta?.changes ?? 0) === 0) {
      return c.json(
        {
          success: false,
          error: 'Recommendation not found',
        } satisfies ApiResponse,
        404,
      );
    }

    return c.json({
      success: true,
      data: { id, status: 'applied' },
    } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

app.post('/recommendations/:id/dismiss', async (c) => {
  try {
    const id = c.req.param('id');

    const result = await c.env.DB.prepare(
      `UPDATE optimization_recommendations
       SET status = 'dismissed'
       WHERE id = ?`,
    )
      .bind(id)
      .run();

    if ((result.meta?.changes ?? 0) === 0) {
      return c.json(
        {
          success: false,
          error: 'Recommendation not found',
        } satisfies ApiResponse,
        404,
      );
    }

    return c.json({
      success: true,
      data: { id, status: 'dismissed' },
    } satisfies ApiResponse);
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

export default app;