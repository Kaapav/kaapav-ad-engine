import { Hono } from 'hono';
import type { AppEnv } from './types';

import { corsMiddleware } from './middleware/cors';
import { apiAuth } from './middleware/auth';

import campaignsRoutes from './routes/campaigns';
import leadsRoutes from './routes/leads';
import rulesRoutes from './routes/rules';
import webhooksRoutes from './routes/webhooks';
import notificationsRoutes from './routes/notifications';
import analyticsRoutes from './routes/analytics';
import bridgeRoutes from './routes/bridge';
import sheetsRoutes from './routes/sheets';

import * as MetaApi from './services/meta-api';
import { notify } from './services/fcm';
import { evaluateRules } from './services/rule-engine';
import { runIntelligenceOrchestrator } 
  from './services/intelligence-orchestrator';

const app = new Hono<AppEnv>();

// ─────────────────────────────────────────────
// Global middleware
// ─────────────────────────────────────────────
app.use('*', corsMiddleware);

// ─────────────────────────────────────────────
// Root
// ─────────────────────────────────────────────
app.get('/', (c) => {
  return c.json({
    success: true,
    data: {
      name: 'Kaapav Ad Engine API',
      version: '1.1.0',
      environment: c.env.ENVIRONMENT,
      api_version: c.env.META_API_VERSION,
      intelligence: true,
    },
  });
});

// ─────────────────────────────────────────────
// Health
// ─────────────────────────────────────────────
app.get('/health', async (c) => {
  try {
    await c.env.DB.prepare('SELECT 1 as ok').first();

    const summary = await getIntelligenceSummary(c.env);

    return c.json({
      success: true,
      data: {
        status: 'ok',
        db: true,
        cache: true,
        time: new Date().toISOString(),
        intelligence: {
          avgAudienceScore: summary.avgAudienceScore,
          avgCreativeMatchScore: summary.avgCreativeMatchScore,
          fatigueAlerts: summary.fatigueAlerts,
          openRecommendations: summary.openRecommendations,
        },
      },
    });
  } catch (err: any) {
    return c.json(
      {
        success: false,
        error: err.message,
      },
      500,
    );
  }
});

// ─────────────────────────────────────────────
// Auth
// ─────────────────────────────────────────────
app.post('/auth/login', async (c) => {
  try {
    const body = await c.req.json();

    if (body.api_key !== c.env.API_SECRET_KEY) {
      return c.json({ success: false, error: 'Invalid API key' }, 401);
    }

    const token = crypto.randomUUID();
    await c.env.SESSIONS.put(token, '1', {
      expirationTtl: 60 * 60 * 24 * 30,
    });

    return c.json({
      success: true,
      data: { token },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// Public webhook routes
// ─────────────────────────────────────────────
app.route('/api/webhooks', webhooksRoutes);

// ─────────────────────────────────────────────
// Protected API routes
// ─────────────────────────────────────────────
app.use('/api/*', apiAuth);

app.route('/api/campaigns', campaignsRoutes);
app.route('/api/leads', leadsRoutes);
app.route('/api/rules', rulesRoutes);
app.route('/api/notifications', notificationsRoutes);
app.route('/api/analytics', analyticsRoutes);
app.route('/api/bridge', bridgeRoutes);
app.route('/api/sheets', sheetsRoutes);

// ─────────────────────────────────────────────
// Intelligence endpoints (bootstrap version)
// Later these can move into dedicated routes/intelligence.ts
// ─────────────────────────────────────────────
app.get('/api/intelligence/summary', async (c) => {
  try {
    const summary = await getIntelligenceSummary(c.env);

    return c.json({
      success: true,
      data: summary,
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

app.post('/api/intelligence/recompute', async (c) => {
  const result = await runIntelligenceOrchestrator(c.env, {
    source: 'manual',
    notifyCritical: true,
  });
  return c.json({ success: true, data: result });
});

// ─────────────────────────────────────────────
// Intelligence list endpoints (D1-backed)
// ─────────────────────────────────────────────

// GET /api/intelligence/audiences
app.get('/api/intelligence/audiences', async (c) => {
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
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/intelligence/creatives
app.get('/api/intelligence/creatives', async (c) => {
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
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/intelligence/buyers
app.get('/api/intelligence/buyers', async (c) => {
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
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/intelligence/recommendations
app.get('/api/intelligence/recommendations', async (c) => {
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
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// POST /api/intelligence/recommendations/:id/apply
app.post('/api/intelligence/recommendations/:id/apply', async (c) => {
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
      return c.json({ success: false, error: 'Recommendation not found' }, 404);
    }

    return c.json({ success: true, data: { id, status: 'applied' } });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// POST /api/intelligence/recommendations/:id/dismiss
app.post('/api/intelligence/recommendations/:id/dismiss', async (c) => {
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
      return c.json({ success: false, error: 'Recommendation not found' }, 404);
    }

    return c.json({ success: true, data: { id, status: 'dismissed' } });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/intelligence/refund-roas
app.get('/api/intelligence/refund-roas', async (c) => {
  try {
    const q     = c.req.query();
    const limit = Math.min(100, Math.max(1, Number(q.limit ?? 50)));
    const trust = q.trust_level?.trim();

    const where: string[] = [];
    const bind: unknown[] = [];

    if (trust) {
      where.push('trust_level = ?');
      bind.push(trust);
    }

    // Get latest per campaign using subquery
    const sql =
      `SELECT r.*
       FROM refund_adjusted_roas r
       INNER JOIN (
         SELECT campaign_id, MAX(computed_at) as latest
         FROM refund_adjusted_roas
         GROUP BY campaign_id
       ) m ON r.campaign_id = m.campaign_id
          AND r.computed_at = m.latest
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY ABS(roas_delta) DESC
       LIMIT ?`;

    bind.push(limit);

    const rows = await c.env.DB.prepare(sql).bind(...bind).all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// GET /api/intelligence/scale-decisions
app.get('/api/intelligence/scale-decisions', async (c) => {
  try {
    const q        = c.req.query();
    const limit    = Math.min(100, Math.max(1, Number(q.limit ?? 50)));
    const action   = q.action_type?.trim();
    const priority = q.priority?.trim();

    const where: string[] = [
      `status = 'open'`,
      `id LIKE 'scale:%'`,
    ];
    const bind: unknown[] = [];

    if (action) {
      where.push('action_type = ?');
      bind.push(action);
    }

    if (priority) {
      where.push('priority = ?');
      bind.push(priority);
    }

    const sql =
      `SELECT *
       FROM optimization_recommendations
       WHERE ${where.join(' AND ')}
       ORDER BY
         CASE priority
           WHEN 'critical' THEN 4
           WHEN 'high'     THEN 3
           WHEN 'medium'   THEN 2
           WHEN 'low'      THEN 1
           ELSE 0
         END DESC,
         COALESCE(score, 0) DESC
       LIMIT ?`;

    bind.push(limit);

    const rows = await c.env.DB.prepare(sql).bind(...bind).all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// GET /api/intelligence/geo
// ─────────────────────────────────────────────
app.get('/api/intelligence/geo', async (c) => {
  try {
    const q      = c.req.query();
    const status = q.status?.trim();
    const limit  = Math.min(100, Math.max(1, Number(q.limit ?? 50)));

    const where: string[] = [];
    const bind:  unknown[] = [];

    if (status) {
      where.push('status = ?');
      bind.push(status);
    }

    const sql =
      `SELECT *
       FROM geo_intent_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY intent_score DESC
       LIMIT ?`;

    bind.push(limit);
    const rows = await c.env.DB.prepare(sql).bind(...bind).all();

    return c.json({
      success: true,
      data:    rows.results ?? [],
      meta:    { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// GET /api/intelligence/response-speed
// ─────────────────────────────────────────────
app.get('/api/intelligence/response-speed', async (c) => {
  try {
    const rows = await c.env.DB.prepare(
      `SELECT bucket, count, conversion_rate,
              avg_revenue, computed_at
       FROM response_speed_insights
       ORDER BY computed_at DESC
       LIMIT 12`,
    ).all();

    return c.json({
      success: true,
      data:    rows.results ?? [],
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// GET /api/intelligence/seed-log
// ─────────────────────────────────────────────
app.get('/api/intelligence/seed-log', async (c) => {
  try {
    const rows = await c.env.DB.prepare(
      `SELECT * FROM seed_sync_log
       ORDER BY synced_at DESC
       LIMIT 10`,
    ).all();

    return c.json({
      success: true,
      data:    rows.results ?? [],
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// POST /api/intelligence/seed-sync
// Manual trigger for Platinum Seed Sync
// ─────────────────────────────────────────────
app.post('/api/intelligence/seed-sync', async (c) => {
  try {
    const { runSeedSync } = await import('./services/seed-sync');
    const result = await runSeedSync(c.env);

    return c.json({
      success: true,
      data:    result,
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// POST /api/intelligence/monitor
// Manual trigger for real-time monitor
// ─────────────────────────────────────────────
app.post('/api/intelligence/monitor', async (c) => {
  try {
    const { runRealtimeMonitor } = await import('./services/realtime-monitor');
    const result = await runRealtimeMonitor(c.env);

    return c.json({
      success: true,
      data:    result,
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// ─────────────────────────────────────────────
// Export handler
// ─────────────────────────────────────────────
export default {
  fetch: app.fetch,

  async scheduled(
    controller: ScheduledController,
    env: AppEnv['Bindings'],
    ctx: ExecutionContext,
  ) {
    switch (controller.cron) {
      // Every 6 hours → evaluate rules + bootstrap intelligence refresh
      case '0 */6 * * *':
  ctx.waitUntil(
    Promise.all([
      evaluateRules(env),
      runIntelligenceOrchestrator(env, {
        source: 'cron_6h',
        notifyCritical: true,
      }),
    ]),
  );
  break;
 
  // ADD this case to your scheduled switch:
case '*/30 * * * *':
  ctx.waitUntil(
    Promise.all([
      runRealtimeMonitor(env),
      runResponseSpeedEngine(env),
    ]),
  );
  break;

      // Every day 8 AM → daily report
      case '30 2 * * *':
        ctx.waitUntil(sendDailyReport(env));
        break;

      // Every 2 hours → refresh campaigns cache + snapshots
      case '0 */2 * * *':
        ctx.waitUntil(refreshCampaignCache(env));
        break;
    }
  },
};

// ─────────────────────────────────────────────
// Cron jobs
// ─────────────────────────────────────────────

async function sendDailyReport(env: AppEnv['Bindings']): Promise<void> {
  try {
    const insights = await MetaApi.getAccountInsights(env, 'yesterday');
    const parsed = MetaApi.parseInsights(insights) as Record<string, any>;
    const intelligence = await getIntelligenceSummary(env);

    const body =
      `Spend ₹${Math.round(parsed.spend ?? 0)} • ` +
      `Revenue ₹${Math.round(parsed.revenue ?? 0)} • ` +
      `ROAS ${Number(parsed.roas ?? 0).toFixed(2)}x • ` +
      `Leads ${parsed.leads ?? 0} • ` +
      `Open Recs ${intelligence.openRecommendations}`;

await notify(env, 'report', '📊 Daily Report', body, {
  type: 'daily_report',
  intelligence: JSON.stringify({
    hotAudiences: intelligence.topHotAudiences.length,
    scalableCampaigns: intelligence.topScalableCampaigns.length,
    fatigueAlerts: intelligence.fatigueAlerts,
  }),
});


    await env.DB.prepare(
      'INSERT INTO activity_log (id, type, title, description) VALUES (?, ?, ?, ?)',
    )
      .bind(
        crypto.randomUUID(),
        'daily_report',
        'Daily report sent',
        body,
      )
      .run();
  } catch (err) {
    console.error('Daily report cron failed:', err);
  }
}

async function refreshCampaignCache(env: AppEnv['Bindings']): Promise<void> {
  try {
    const toRow = (mc: any) => {
      const parsed = MetaApi.parseInsights(mc.insights?.data || []) as Record<string, any>;

      return {
        id: mc.id,
        name: mc.name,
        objective: mc.objective,
        status: mc.effective_status || mc.status,
        daily_budget: parseInt(mc.daily_budget || '0', 10) / 100,
        lifetime_budget: parseInt(mc.lifetime_budget || '0', 10) / 100,
        spend: Number(parsed.spend ?? 0),
        revenue: Number(parsed.revenue ?? 0),
        roas: Number(parsed.roas ?? 0),
        cpa: Number(parsed.cpa ?? 0),
        ctr: Number(parsed.ctr ?? 0),
        cpc: Number(parsed.cpc ?? 0),
        cpm: Number(parsed.cpm ?? 0),
        frequency: Number(parsed.frequency ?? 0),
        leads: Number(parsed.leads ?? 0),
        conversions: Number(parsed.conversions ?? 0),
      };
    };

    const raw30 = await MetaApi.getCampaigns(env, 'last_30d', 50);
    const raw7 = await MetaApi.getCampaigns(env, 'last_7d', 50);

    const data30 = raw30.map(toRow);
    const data7 = raw7.map(toRow);

    await env.CACHE.put('campaigns:last_30d:50', JSON.stringify(data30), {
      expirationTtl: 60 * 60 * 2,
    });

    await env.CACHE.put('campaigns:last_7d:50', JSON.stringify(data7), {
      expirationTtl: 60 * 60 * 2,
    });

    // snapshot the 7d view (more relevant for decisions)
    await persistCampaignSnapshots(env, data7);

    console.log(`✅ Campaign cache refreshed: 30d=${data30.length}, 7d=${data7.length}`);
  } catch (err) {
    console.error('Campaign cache refresh failed:', err);
  }
}

// ─────────────────────────────────────────────
// Intelligence bootstrap layer
// This is step-1 implementation before full engines
// ─────────────────────────────────────────────

type BootstrapOptions = {
  source: 'manual' | 'cron_6h' | 'daily_report';
  notifyCritical?: boolean;
};

type IntelligenceSummary = {
  avgAudienceScore: number;
  avgCreativeMatchScore: number;
  topBuyerCount: number;
  fatigueAlerts: number;
  openRecommendations: number;
  topScalableCampaigns: Array<{ id: string; title: string; score: number }>;
  topHotAudiences: Array<{ key: string; name: string; score: number }>;
  topSeedBuyers: Array<{ phone: string; name: string; score: number }>;
};

async function runIntelligenceBootstrap(
  env: AppEnv['Bindings'],
  options: BootstrapOptions,
): Promise<{
  ok: true;
  source: string;
  snapshotsSaved: number;
  recommendationsUpserted: number;
  summary: IntelligenceSummary;
}> {
  const raw = await MetaApi.getCampaigns(env, 'last_7d', 50);

  const campaigns = raw.map((mc) => {
    const parsed = MetaApi.parseInsights(mc.insights?.data || []) as Record<
      string,
      any
    >;

    return {
      id: mc.id,
      name: mc.name,
      objective: mc.objective,
      status: mc.effective_status || mc.status,
      spend: Number(parsed.spend ?? 0),
      revenue: Number(parsed.revenue ?? 0),
      roas: Number(parsed.roas ?? 0),
      cpa: Number(parsed.cpa ?? 0),
      ctr: Number(parsed.ctr ?? 0),
      cpc: Number(parsed.cpc ?? 0),
      cpm: Number(parsed.cpm ?? 0),
      frequency: Number(parsed.frequency ?? 0),
      leads: Number(parsed.leads ?? 0),
      conversions: Number(parsed.conversions ?? 0),
    };
  });

  await persistCampaignSnapshots(env, campaigns);

  const activeRecommendationIds = new Set<string>();
  let recommendationsUpserted = 0;

  for (const campaign of campaigns) {
    // Scale candidate
    if (campaign.roas >= 4 && campaign.spend >= 1500) {
      const id = `bootstrap:scale:${campaign.id}`;
      activeRecommendationIds.add(id);

      await upsertRecommendation(env, {
        id,
        entityType: 'campaign',
        entityId: campaign.id,
        priority: campaign.roas >= 5 ? 'high' : 'medium',
        actionType: 'scale_budget',
        title: `Scale ${campaign.name} by 15%`,
        description:
          `Strong ROAS (${campaign.roas.toFixed(2)}x)` +
          `${campaign.frequency > 0 ? `, frequency ${campaign.frequency.toFixed(2)}x` : ''}` +
          `, and spend ₹${Math.round(campaign.spend)} indicate a scalable winner.`,
        score: Math.min(100, Math.round(campaign.roas * 18)),
        payload: {
          source: 'bootstrap',
          budgetDeltaPercent: 15,
          campaignId: campaign.id,
        },
      });

      recommendationsUpserted++;
    }

    // Reduce / pause candidate
    if (campaign.roas > 0 && campaign.roas < 2 && campaign.spend >= 1000) {
      const id = `bootstrap:pause:${campaign.id}`;
      activeRecommendationIds.add(id);

      await upsertRecommendation(env, {
        id,
        entityType: 'campaign',
        entityId: campaign.id,
        priority: campaign.roas < 1.5 ? 'critical' : 'high',
        actionType: 'pause',
        title: `Pause or cut spend for ${campaign.name}`,
        description:
          `ROAS is only ${campaign.roas.toFixed(2)}x after spend ₹${Math.round(campaign.spend)}.` +
          ` This campaign looks inefficient and should be reviewed immediately.`,
        score: Math.max(1, 100 - Math.round(campaign.roas * 30)),
        payload: {
          source: 'bootstrap',
          campaignId: campaign.id,
          suggestedAction: 'pause_or_reduce',
        },
      });

      recommendationsUpserted++;
    }

    // Fatigue candidate
    if (campaign.frequency >= 3.5) {
      const id = `bootstrap:fatigue:${campaign.id}`;
      activeRecommendationIds.add(id);

      await upsertRecommendation(env, {
        id,
        entityType: 'campaign',
        entityId: campaign.id,
        priority: campaign.frequency >= 4.5 ? 'critical' : 'high',
        actionType: 'rotate_creative',
        title: `Rotate creative for ${campaign.name}`,
        description:
          `Frequency is ${campaign.frequency.toFixed(2)}x, which suggests rising audience fatigue.` +
          ` Rotate creatives or narrow delivery before performance drops further.`,
        score: Math.min(100, Math.round(campaign.frequency * 20)),
        payload: {
          source: 'bootstrap',
          campaignId: campaign.id,
          reason: 'fatigue',
        },
      });

      recommendationsUpserted++;
    }
  }

  await resolveStaleBootstrapRecommendations(env, [...activeRecommendationIds]);

  const summary = await getIntelligenceSummary(env);

  await env.DB.prepare(
    'INSERT INTO activity_log (id, type, title, description) VALUES (?, ?, ?, ?)',
  )
    .bind(
      crypto.randomUUID(),
      'intelligence',
      'Intelligence bootstrap recomputed',
      `Source: ${options.source}, Snapshots: ${campaigns.length}, Recommendations: ${recommendationsUpserted}`,
    )
    .run();

  if (options.notifyCritical) {
    const critical = await env.DB
      .prepare(
        `SELECT COUNT(*) as count
         FROM optimization_recommendations
         WHERE status = 'open' AND priority = 'critical'`,
      )
      .first<{ count: number }>();

    const criticalCount = Number(critical?.count ?? 0);

    if (criticalCount > 0) {
await notify(
  env,
  'alert',
  '⚠️ Critical Optimization Alerts',
  `${criticalCount} critical recommendation(s) need attention`,
  {
    type: 'intelligence_alert',
    criticalCount: String(criticalCount),
  },
);
    }
  }

  return {
    ok: true,
    source: options.source,
    snapshotsSaved: campaigns.length,
    recommendationsUpserted,
    summary,
  };
}

async function persistCampaignSnapshots(
  env: AppEnv['Bindings'],
  campaigns: Array<{
    id: string;
    name: string;
    objective?: string;
    status?: string;
    spend?: number;
    revenue?: number;
    roas?: number;
    cpa?: number;
    ctr?: number;
    cpc?: number;
    cpm?: number;
    frequency?: number;
    conversions?: number;
    leads?: number;
  }>,
): Promise<void> {
  const snapshotDate = new Date().toISOString();

  for (const campaign of campaigns) {
    await env.DB.prepare(
      `INSERT INTO performance_snapshots (
        id, entity_type, entity_id, snapshot_date,
        spend, revenue, roas, cpa, ctr, cpc, cpm, frequency, conversions, extra, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
    )
      .bind(
        crypto.randomUUID(),
        'campaign',
        campaign.id,
        snapshotDate,
        Number(campaign.spend ?? 0),
        Number(campaign.revenue ?? 0),
        Number(campaign.roas ?? 0),
        Number(campaign.cpa ?? 0),
        Number(campaign.ctr ?? 0),
        Number(campaign.cpc ?? 0),
        Number(campaign.cpm ?? 0),
        Number(campaign.frequency ?? 0),
        Number(campaign.conversions ?? 0),
        JSON.stringify({
          name: campaign.name,
          objective: campaign.objective,
          status: campaign.status,
          leads: campaign.leads ?? 0,
        }),
        snapshotDate,
      )
      .run();
  }
}

async function upsertRecommendation(
  env: AppEnv['Bindings'],
  input: {
    id: string;
    entityType: string;
    entityId: string;
    priority: 'low' | 'medium' | 'high' | 'critical';
    actionType:
      | 'scale_budget'
      | 'hold'
      | 'reduce_budget'
      | 'pause'
      | 'rotate_creative'
      | 'retarget'
      | 'duplicate';
    title: string;
    description: string;
    score: number;
    payload?: Record<string, unknown>;
  },
): Promise<void> {
  const now = new Date().toISOString();

  await env.DB.prepare(
    `INSERT INTO optimization_recommendations (
      id, entity_type, entity_id, priority, action_type,
      title, description, score, status, payload, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      entity_type = excluded.entity_type,
      entity_id = excluded.entity_id,
      priority = excluded.priority,
      action_type = excluded.action_type,
      title = excluded.title,
      description = excluded.description,
      score = excluded.score,
      status = 'open',
      payload = excluded.payload
    `,
  )
    .bind(
      input.id,
      input.entityType,
      input.entityId,
      input.priority,
      input.actionType,
      input.title,
      input.description,
      input.score,
      'open',
      JSON.stringify(input.payload ?? {}),
      now,
    )
    .run();
}

async function resolveStaleBootstrapRecommendations(
  env: AppEnv['Bindings'],
  activeIds: string[],
): Promise<void> {
  const existing = await env.DB
    .prepare(
      `SELECT id
       FROM optimization_recommendations
       WHERE id LIKE 'bootstrap:%' AND status = 'open'`,
    )
    .all<{ id: string }>();

  const rows = existing.results ?? [];

  for (const row of rows) {
    if (!activeIds.includes(row.id)) {
      await env.DB.prepare(
        `UPDATE optimization_recommendations
         SET status = 'resolved'
         WHERE id = ?`,
      )
        .bind(row.id)
        .run();
    }
  }
}

async function getIntelligenceSummary(
  env: AppEnv['Bindings'],
): Promise<IntelligenceSummary> {
  const avgAudience = await env.DB
    .prepare(
      `SELECT COALESCE(ROUND(AVG(intent_score), 2), 0) as value
       FROM audience_scores`,
    )
    .first<{ value: number }>();

  const avgCreative = await env.DB
    .prepare(
      `SELECT COALESCE(ROUND(AVG(match_score), 2), 0) as value
       FROM creative_scores`,
    )
    .first<{ value: number }>();

  const topBuyerCount = await env.DB
    .prepare(
      `SELECT COUNT(*) as count
       FROM buyer_scores
       WHERE buyer_tier IN ('platinum', 'gold')`,
    )
    .first<{ count: number }>();

  const fatigueAlerts = await env.DB
    .prepare(
      `SELECT COUNT(*) as count
       FROM creative_scores
       WHERE fatigue_score >= 50`,
    )
    .first<{ count: number }>();

  const openRecommendations = await env.DB
    .prepare(
      `SELECT COUNT(*) as count
       FROM optimization_recommendations
       WHERE status = 'open'`,
    )
    .first<{ count: number }>();

  const scalableCampaigns = await env.DB
    .prepare(
      `SELECT entity_id as id, title, COALESCE(score, 0) as score
       FROM optimization_recommendations
       WHERE status = 'open' AND action_type = 'scale_budget'
       ORDER BY COALESCE(score, 0) DESC
       LIMIT 3`,
    )
    .all<{ id: string; title: string; score: number }>();

  const hotAudiences = await env.DB
    .prepare(
      `SELECT audience_key as key,
              COALESCE(audience_name, audience_key) as name,
              COALESCE(intent_score, 0) as score
       FROM audience_scores
       ORDER BY COALESCE(intent_score, 0) DESC
       LIMIT 3`,
    )
    .all<{ key: string; name: string; score: number }>();

  const seedBuyers = await env.DB
    .prepare(
      `SELECT phone,
              COALESCE(customer_name, phone) as name,
              COALESCE(buyer_quality_score, 0) as score
       FROM buyer_scores
       WHERE lookalike_seed_eligible = 1
       ORDER BY COALESCE(buyer_quality_score, 0) DESC
       LIMIT 3`,
    )
    .all<{ phone: string; name: string; score: number }>();

  return {
    avgAudienceScore: Number(avgAudience?.value ?? 0),
    avgCreativeMatchScore: Number(avgCreative?.value ?? 0),
    topBuyerCount: Number(topBuyerCount?.count ?? 0),
    fatigueAlerts: Number(fatigueAlerts?.count ?? 0),
    openRecommendations: Number(openRecommendations?.count ?? 0),
    topScalableCampaigns: scalableCampaigns.results ?? [],
    topHotAudiences: hotAudiences.results ?? [],
    topSeedBuyers: seedBuyers.results ?? [],
  };
}