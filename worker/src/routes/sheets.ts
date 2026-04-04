import { Hono } from 'hono';
import type { AppEnv, Lead } from '../types';
import * as MetaApi from '../services/meta-api';
import * as Sheets from '../services/sheets';

const app = new Hono<AppEnv>();

// NOTE:
// Pass sheetId in body for now.
// Later you can store SHEET_ID in Wrangler vars/secrets if you want.

// POST /sync-campaigns
app.post('/sync-campaigns', async (c) => {
  try {
    const body = await c.req.json();
    const sheetId = body.sheetId;

    if (!sheetId) {
      return c.json({ success: false, error: 'sheetId is required' }, 400);
    }

    const raw = await MetaApi.getCampaigns(c.env, body.date_preset || 'last_30d', 50);

    const campaigns = raw.map((mc) => {
      const p = MetaApi.parseInsights(mc.insights?.data || []);
      return {
        name: mc.name,
        status: mc.effective_status || mc.status,
        spend: p.spend,
        revenue: p.revenue,
        roas: p.roas,
        cpa: p.cpa,
      };
    });

    await Sheets.syncCampaigns(c.env, sheetId, campaigns);

    return c.json({
      success: true,
      data: { synced: campaigns.length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// POST /sync-leads
app.post('/sync-leads', async (c) => {
  try {
    const body = await c.req.json();
    const sheetId = body.sheetId;

    if (!sheetId) {
      return c.json({ success: false, error: 'sheetId is required' }, 400);
    }

    const leads = await c.env.DB.prepare(
      'SELECT name, phone, stage, campaign, value, created_at FROM leads ORDER BY created_at DESC LIMIT 500'
    ).all<Pick<Lead, 'name' | 'phone' | 'stage' | 'campaign' | 'value' | 'created_at'>>();

    await Sheets.syncLeads(c.env, sheetId, leads.results || []);

    return c.json({
      success: true,
      data: { synced: leads.results?.length || 0 },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

export default app;