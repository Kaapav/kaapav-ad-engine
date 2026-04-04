import { Hono } from 'hono';
import type { AppEnv, WebhookPayload, Lead } from '../types';
import { verifyMetaSignature } from '../middleware/auth';
import * as MetaApi from '../services/meta-api';
import { notify } from '../services/fcm';

const app = new Hono<AppEnv>();

// ─── GET /meta — Meta verification challenge ───
app.get('/meta', (c) => {
  const mode = c.req.query('hub.mode');
  const token = c.req.query('hub.verify_token');
  const challenge = c.req.query('hub.challenge');

  if (mode === 'subscribe' && token === c.env.API_SECRET_KEY) {
    return c.text(challenge || '', 200);
  }
  return c.text('Forbidden', 403);
});

// ─── POST /meta — Meta webhook events ───
app.post('/meta', async (c) => {
  const rawBody = await c.req.text();
  const signature = c.req.header('X-Hub-Signature-256');

  const valid = await verifyMetaSignature(rawBody, signature, c.env.META_APP_SECRET);
  if (!valid) return c.json({ success: false, error: 'Invalid signature' }, 401);

  const payload: WebhookPayload = JSON.parse(rawBody);

  for (const entry of payload.entry) {
    for (const change of entry.changes || []) {
      if (change.field === 'leadgen') {
        await handleLeadgen(c.env, change.value as any);
      }
    }
  }

  return c.text('EVENT_RECEIVED', 200);
});

async function handleLeadgen(
  env: AppEnv['Bindings'],
  value: { leadgen_id: string; page_id: string }
): Promise<void> {
  try {
    const fields = await MetaApi.getLeadData(env, value.leadgen_id);

    const id = crypto.randomUUID();
    const name = `${fields.first_name || ''} ${fields.last_name || ''}`.trim() || 'Unknown';
    const phone = fields.phone_number || fields.phone || '';
    const email = fields.email || null;
    const campaign = fields._campaign_name || '';
    const now = new Date().toISOString();

    // Save lead
    await env.DB.prepare(
      `INSERT INTO leads (id, name, phone, email, campaign, stage, source, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, 'New', 'Facebook Lead Ad', ?, ?)`
    ).bind(id, name, phone, email, campaign, now, now).run();

    // Activity
    await env.DB.prepare(
      'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), id, 'note', `Captured from Lead Ad: ${campaign}`).run();

    // FCM
    await notify(env, 'lead', '🎯 New Lead!', `${name} from ${campaign}`, { lead_id: id });

    // WhatsApp auto-followup
    if (env.WHATSAPP_BOT_URL && phone) {
      try {
        await fetch(`${env.WHATSAPP_BOT_URL}/api/auto-followup`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json', 'X-API-Key': env.API_SECRET_KEY },
          body: JSON.stringify({ phone, name, source: 'Facebook Lead Ad' }),
        });

        await env.DB.prepare(
          'INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, status) VALUES (?, ?, ?, ?, ?, ?)'
        ).bind(crypto.randomUUID(), id, phone, 'outbound', 'auto_followup', 'sent').run();
      } catch { /* silent */ }
    }
  } catch (err) {
    console.error('Leadgen handler failed:', err);
  }
}

// ─── POST /whatsapp — From WhatsApp autoresponder ───
app.post('/whatsapp', async (c) => {
  const apiKey = c.req.header('X-API-Key');
  if (apiKey !== c.env.API_SECRET_KEY) {
    return c.json({ success: false, error: 'Unauthorized' }, 401);
  }

  const { event, phone, data } = await c.req.json();

  // Find lead by phone
  const lead = await c.env.DB.prepare(
    'SELECT * FROM leads WHERE phone = ? OR phone = ? ORDER BY updated_at DESC LIMIT 1'
  ).bind(phone, phone.replace(/^\+/, '')).first<Lead>();

  switch (event) {
    case 'order_placed':
      if (lead) {
        await c.env.DB.prepare(
          "UPDATE leads SET stage = 'Converted', value = ?, product = ?, updated_at = datetime('now') WHERE id = ?"
        ).bind(data?.amount || 0, data?.product || null, lead.id).run();

        await c.env.DB.prepare(
          'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
        ).bind(crypto.randomUUID(), lead.id, 'order',
          `Order: ${data?.product || 'N/A'} — ₹${data?.amount || 0}`).run();
      }
      await notify(c.env, 'alert', '🛒 New Order!',
        `${lead?.name || phone} — ₹${data?.amount || 0}`, { lead_id: lead?.id || '' });
      break;

    case 'customer_reply':
      if (lead && lead.stage === 'New') {
        await c.env.DB.prepare(
          "UPDATE leads SET stage = 'Contacted', updated_at = datetime('now') WHERE id = ?"
        ).bind(lead.id).run();

        await c.env.DB.prepare(
          'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
        ).bind(crypto.randomUUID(), lead.id, 'whatsapp', 'Customer replied on WhatsApp').run();
      }
      break;

    case 'payment_confirmed':
      if (lead) {
        await c.env.DB.prepare(
          'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
        ).bind(crypto.randomUUID(), lead.id, 'note',
          `Payment confirmed: ₹${data?.amount || 0}`).run();
      }
      break;

    case 'shipping_update':
      if (lead) {
        await c.env.DB.prepare(
          'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
        ).bind(crypto.randomUUID(), lead.id, 'note',
          `Shipping: ${data?.status || 'updated'}`).run();
      }
      break;
  }

  // Log bridge message
  await c.env.DB.prepare(
    'INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, status) VALUES (?, ?, ?, ?, ?, ?)'
  ).bind(crypto.randomUUID(), lead?.id || null, phone, 'inbound', event, 'received').run();

  return c.json({ success: true });
});

export default app;