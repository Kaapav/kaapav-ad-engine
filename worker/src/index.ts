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

const app = new Hono<AppEnv>();

// Global middleware
app.use('*', corsMiddleware);

// Root
app.get('/', (c) => {
  return c.json({
    success: true,
    data: {
      name: 'Kaapav Ad Engine API',
      version: '1.0.0',
      environment: c.env.ENVIRONMENT,
      api_version: c.env.META_API_VERSION,
    },
  });
});

// Health
app.get('/health', async (c) => {
  try {
    await c.env.DB.prepare('SELECT 1 as ok').first();
    return c.json({
      success: true,
      data: {
        status: 'ok',
        db: true,
        cache: true,
        time: new Date().toISOString(),
      },
    });
  } catch (err: any) {
    return c.json({
      success: false,
      error: err.message,
    }, 500);
  }
});

// Auth
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

// Public webhook routes
app.route('/api/webhooks', webhooksRoutes);

// Protected API routes
app.use('/api/*', apiAuth);

app.route('/api/campaigns', campaignsRoutes);
app.route('/api/leads', leadsRoutes);
app.route('/api/rules', rulesRoutes);
app.route('/api/notifications', notificationsRoutes);
app.route('/api/analytics', analyticsRoutes);
app.route('/api/bridge', bridgeRoutes);
app.route('/api/sheets', sheetsRoutes);

// Cron handler
export default {
  fetch: app.fetch,

  async scheduled(
    controller: ScheduledController,
    env: AppEnv['Bindings'],
    ctx: ExecutionContext
  ) {
    switch (controller.cron) {
      // Every 6 hours → evaluate rules
      case '0 */6 * * *':
        ctx.waitUntil(evaluateRules(env));
        break;

      // Every day 8 AM → daily report
      case '0 8 * * *':
        ctx.waitUntil(sendDailyReport(env));
        break;

      // Every 2 hours → refresh campaigns cache
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
    const parsed = MetaApi.parseInsights(insights);

    await notify(
      env,
      'report',
      '📊 Daily Report',
      `Spend ₹${Math.round(parsed.spend)} • Revenue ₹${Math.round(parsed.revenue)} • ROAS ${parsed.roas.toFixed(2)}x • Leads ${parsed.leads}`,
      {
        type: 'daily_report',
      }
    );

    await env.DB.prepare(
      'INSERT INTO activity_log (id, type, title, description) VALUES (?, ?, ?, ?)'
    ).bind(
      crypto.randomUUID(),
      'daily_report',
      'Daily report sent',
      `Spend ₹${Math.round(parsed.spend)}, Revenue ₹${Math.round(parsed.revenue)}, ROAS ${parsed.roas.toFixed(2)}x, Leads ${parsed.leads}`
    ).run();
  } catch (err) {
    console.error('Daily report cron failed:', err);
  }
}

async function refreshCampaignCache(env: AppEnv['Bindings']): Promise<void> {
  try {
    const raw = await MetaApi.getCampaigns(env, 'last_30d', 50);

    const data = raw.map((mc) => ({
      id: mc.id,
      name: mc.name,
      objective: mc.objective,
      status: mc.effective_status || mc.status,
      daily_budget: parseInt(mc.daily_budget || '0') / 100,
      lifetime_budget: parseInt(mc.lifetime_budget || '0') / 100,
      ...MetaApi.parseInsights(mc.insights?.data || []),
    }));

    await env.CACHE.put('campaigns:last_30d:50', JSON.stringify(data), {
      expirationTtl: 60 * 60 * 2,
    });

    await env.CACHE.put('campaigns:last_7d:50', JSON.stringify(data), {
      expirationTtl: 60 * 60 * 2,
    });

    console.log(`✅ Campaign cache refreshed: ${data.length} campaigns`);
  } catch (err) {
    console.error('Campaign cache refresh failed:', err);
  }
}