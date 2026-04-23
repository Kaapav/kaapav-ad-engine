import { Hono } from 'hono';
import type { AppEnv, ApiResponse } from '../types';

import { notify } from '../services/fcm';
import * as MetaApi from '../services/meta-api';
import {
  getIntelligenceSummary,
  runIntelligenceBootstrap,
} from '../services/intelligence-orchestrator';

const app = new Hono<AppEnv>();

function clampLimit(x: any, def = 100, min = 1, max = 200) {
  const n = Number(x ?? def);
  if (!Number.isFinite(n)) return def;
  return Math.min(max, Math.max(min, Math.floor(n)));
}

function parseJson(payload: any): Record<string, unknown> {
  try {
    if (!payload) return {};
    if (typeof payload === 'object') return payload;
    return JSON.parse(String(payload));
  } catch {
    return {};
  }
}

// ─────────────────────────────────────────────
// GET /summary
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// POST /recompute
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// GET /audiences
// ─────────────────────────────────────────────
app.get('/audiences', async (c) => {
  try {
    const q = c.req.query();

    const status = q.status?.trim();
    const campaignId = q.campaign_id?.trim();
    const adsetId = q.adset_id?.trim();
    const limit = clampLimit(q.limit, 100);

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

// ─────────────────────────────────────────────
// GET /creatives
// ─────────────────────────────────────────────
app.get('/creatives', async (c) => {
  try {
    const q = c.req.query();

    const status = q.status?.trim();
    const campaignId = q.campaign_id?.trim();
    const adsetId = q.adset_id?.trim();
    const audienceKey = q.audience_key?.trim();
    const limit = clampLimit(q.limit, 100);

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

// ─────────────────────────────────────────────
// GET /buyers
// ─────────────────────────────────────────────
app.get('/buyers', async (c) => {
  try {
    const q = c.req.query();

    const tier = q.tier?.trim();
    const seed = q.lookalike_seed_eligible?.trim();
    const affinity = q.product_affinity?.trim();
    const limit = clampLimit(q.limit, 100);

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

// ─────────────────────────────────────────────
// GET /recommendations
// ─────────────────────────────────────────────
app.get('/recommendations', async (c) => {
  try {
    const q = c.req.query();

    const status = q.status?.trim();
    const priority = q.priority?.trim();
    const entityType = q.entity_type?.trim();
    const entityId = q.entity_id?.trim();
    const limit = clampLimit(q.limit, 100);

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
    if (entityType) {
      where.push('entity_type = ?');
      bind.push(entityType);
    }
    if (entityId) {
      where.push('entity_id = ?');
      bind.push(entityId);
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

// ─────────────────────────────────────────────
// POST /recommendations/:id/apply
// ADVANCED: actually executes Meta actions for campaign recos
// ─────────────────────────────────────────────
app.post('/recommendations/:id/apply', async (c) => {
  try {
    const id = c.req.param('id');

    const rec = await c.env.DB.prepare(
      `SELECT * FROM optimization_recommendations WHERE id = ? LIMIT 1`,
    )
      .bind(id)
      .first<any>();

    if (!rec) {
      return c.json(
        { success: false, error: 'Recommendation not found' } satisfies ApiResponse,
        404,
      );
    }

    if (String(rec.status) !== 'open') {
      return c.json(
        { success: false, error: `Recommendation not open (${rec.status})` } satisfies ApiResponse,
        409,
      );
    }

    const payload = parseJson(rec.payload);

    // Execute only what is deterministic and supported now:
    // campaign: pause / scale_budget / reduce_budget
    if (rec.entity_type === 'campaign') {
      const campaignId = String(rec.entity_id);
      const action = String(rec.action_type);

      if (action === 'pause') {
        await MetaApi.updateCampaignStatus(c.env, campaignId, 'PAUSED');
      } else if (action === 'scale_budget') {
        const pct = Number(payload['budget_delta_percent'] ?? 15);
        const info = await MetaApi.getCampaignBudgetInfo(c.env, campaignId);
        const cur = Number(info.daily_budget_inr ?? 0);
        const next = Math.max(1, cur * (1 + pct / 100));
        await MetaApi.updateCampaignBudget(c.env, campaignId, next);
      } else if (action === 'reduce_budget') {
        const pct = Number(payload['budget_delta_percent'] ?? 20);
        const info = await MetaApi.getCampaignBudgetInfo(c.env, campaignId);
        const cur = Number(info.daily_budget_inr ?? 0);
        const next = Math.max(1, cur * (1 - pct / 100));
        await MetaApi.updateCampaignBudget(c.env, campaignId, next);
      } else if (action === 'rotate_creative' || action === 'retarget' || action === 'duplicate' || action === 'hold') {
        // For now: treat as an operator task (no fake automation).
        // We still mark applied and log it.
      } else {
        return c.json(
          { success: false, error: `Unsupported action_type for apply: ${action}` } satisfies ApiResponse,
          400,
        );
      }

      // status update
      await c.env.DB.prepare(
        `UPDATE optimization_recommendations SET status = 'applied' WHERE id = ?`,
      )
        .bind(id)
        .run();

      // activity log
      await c.env.DB.prepare(
        `INSERT INTO activity_log (id, type, title, description, campaign_id, created_at)
         VALUES (?, 'recommendation', ?, ?, ?, datetime('now'))`,
      )
        .bind(
          crypto.randomUUID(),
          `Applied: ${String(rec.title ?? '')}`,
          String(rec.description ?? ''),
          campaignId,
        )
        .run();

      // FCM
      await notify(c.env, 'rule', '✅ Recommendation Applied', String(rec.title ?? ''), {
        type: 'recommendation_applied',
        id,
        action_type: action,
        entity_type: 'campaign',
        entity_id: campaignId,
      });

      return c.json(
        { success: true, data: { id, status: 'applied' } } satisfies ApiResponse,
      );
    }

    // Non-campaign entities not supported for apply yet (no guessing)
    return c.json(
      { success: false, error: `Apply not supported for entity_type=${rec.entity_type}` } satisfies ApiResponse,
      400,
    );
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

// ─────────────────────────────────────────────
// POST /recommendations/:id/dismiss
// ─────────────────────────────────────────────
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
        { success: false, error: 'Recommendation not found' } satisfies ApiResponse,
        404,
      );
    }

    await c.env.DB.prepare(
      `INSERT INTO activity_log (id, type, title, description, created_at)
       VALUES (?, 'recommendation', 'Dismissed recommendation', ?, datetime('now'))`,
    )
      .bind(crypto.randomUUID(), id)
      .run();

    return c.json(
      { success: true, data: { id, status: 'dismissed' } } satisfies ApiResponse,
    );
  } catch (err: any) {
    return c.json(
      { success: false, error: err?.message ?? 'Failed' } satisfies ApiResponse,
      500,
    );
  }
});

export default app;