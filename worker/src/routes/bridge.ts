import { Hono } from 'hono';
import type { AppEnv } from '../types';

const app = new Hono<AppEnv>();

// POST /followup — Send follow-up via WhatsApp bot
app.post('/followup', async (c) => {
  if (!c.env.WHATSAPP_BOT_URL) {
    return c.json({ success: false, error: 'WhatsApp bot URL not configured' }, 400);
  }

  const body = await c.req.json();

  try {
    const res = await fetch(`${c.env.WHATSAPP_BOT_URL}/api/auto-followup`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-API-Key': c.env.API_SECRET_KEY,
      },
      body: JSON.stringify(body),
    });

    await c.env.DB.prepare(
      'INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, template_name, status) VALUES (?,?,?,?,?,?,?)'
    ).bind(
      crypto.randomUUID(),
      body.lead_id || null,
      body.phone,
      'outbound',
      'followup',
      body.template || null,
      res.ok ? 'sent' : 'failed'
    ).run();

    const result = await res.json();
    return c.json({ success: true, data: result });
  } catch (err: any) {
    return c.json({ success: false, error: err.message }, 500);
  }
});

// POST /sync-leads — Sync unconverted leads to WhatsApp bot
app.post('/sync-leads', async (c) => {
  if (!c.env.WHATSAPP_BOT_URL) {
    return c.json({ success: false, error: 'WhatsApp bot URL not configured' }, 400);
  }

  const leads = await c.env.DB.prepare(
    "SELECT id, name, phone, product, campaign FROM leads WHERE stage NOT IN ('Converted', 'Lost') AND phone IS NOT NULL ORDER BY updated_at DESC LIMIT 100"
  ).all<{
    id: string;
    name: string;
    phone: string;
    product: string | null;
    campaign: string | null;
  }>();

  let synced = 0;

  for (const lead of leads.results || []) {
    try {
      const res = await fetch(`${c.env.WHATSAPP_BOT_URL}/api/leads/sync`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-API-Key': c.env.API_SECRET_KEY,
        },
        body: JSON.stringify({
          lead_id: lead.id,
          name: lead.name,
          phone: lead.phone,
          product: lead.product,
          campaign: lead.campaign,
        }),
      });

      await c.env.DB.prepare(
        'INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, status) VALUES (?, ?, ?, ?, ?, ?)'
      ).bind(
        crypto.randomUUID(),
        lead.id,
        lead.phone,
        'outbound',
        'sync_lead',
        res.ok ? 'sent' : 'failed'
      ).run();

      if (res.ok) synced++;
    } catch {
      await c.env.DB.prepare(
        'INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, status) VALUES (?, ?, ?, ?, ?, ?)'
      ).bind(
        crypto.randomUUID(),
        lead.id,
        lead.phone,
        'outbound',
        'sync_lead',
        'failed'
      ).run();
    }
  }

  return c.json({
    success: true,
    data: {
      total: leads.results?.length || 0,
      synced,
    },
  });
});

// GET /stats — WhatsApp bridge stats
app.get('/stats', async (c) => {
  const sent = await c.env.DB.prepare(
    "SELECT COUNT(*) as count FROM whatsapp_bridge WHERE direction = 'outbound'"
  ).first<{ count: number }>();

  const received = await c.env.DB.prepare(
    "SELECT COUNT(*) as count FROM whatsapp_bridge WHERE direction = 'inbound'"
  ).first<{ count: number }>();

  const converted = await c.env.DB.prepare(
    "SELECT COUNT(*) as count FROM leads WHERE stage = 'Converted'"
  ).first<{ count: number }>();

  return c.json({
    success: true,
    data: {
      outbound: sent?.count || 0,
      inbound: received?.count || 0,
      conversions: converted?.count || 0,
    },
  });
});

export default app;