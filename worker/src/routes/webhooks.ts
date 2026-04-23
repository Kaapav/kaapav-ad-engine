import { Hono } from 'hono';
import type { AppEnv, WebhookPayload, Lead } from '../types';
import { verifyMetaSignature } from '../middleware/auth';
import * as MetaApi from '../services/meta-api';
import { notify } from '../services/fcm';
import { normalizePhone10 } from '../lib/phone';

const app = new Hono<AppEnv>();

function s(v: any): string {
  return (v === null || v === undefined) ? '' : String(v);
}

function n(v: any): number {
  const x = Number(v);
  return Number.isFinite(x) ? x : 0;
}

function pickStr(obj: any, keys: string[]): string {
  for (const k of keys) {
    const v = obj?.[k];
    if (typeof v === 'string' && v.trim()) return v.trim();
  }
  return '';
}

function pickNum(obj: any, keys: string[]): number | null {
  for (const k of keys) {
    const v = obj?.[k];
    if (v === null || v === undefined) continue;
    const x = Number(v);
    if (Number.isFinite(x)) return x;
  }
  return null;
}

function nullIfEmpty(x: string): string | null {
  const t = (x ?? '').trim();
  return t ? t : null;
}

// ─────────────────────────────────────────────
// GET /meta — Meta verification challenge
// ─────────────────────────────────────────────
app.get('/meta', (c) => {
  const mode = c.req.query('hub.mode');
  const token = c.req.query('hub.verify_token');
  const challenge = c.req.query('hub.challenge');

  if (mode === 'subscribe' && token === c.env.API_SECRET_KEY) {
    return c.text(challenge || '', 200);
  }
  return c.text('Forbidden', 403);
});

// ─────────────────────────────────────────────
// POST /meta — Meta webhook events (leadgen)
// ─────────────────────────────────────────────
app.post('/meta', async (c) => {
  const rawBody = await c.req.text();
  const signature = c.req.header('X-Hub-Signature-256');

  const valid = await verifyMetaSignature(rawBody, signature, c.env.META_APP_SECRET);
  if (!valid) return c.json({ success: false, error: 'Invalid signature' }, 401);

  const payload: WebhookPayload = JSON.parse(rawBody);

  for (const entry of payload.entry ?? []) {
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
  value: { leadgen_id: string; page_id: string },
): Promise<void> {
  try {
    const fields = await MetaApi.getLeadData(env, value.leadgen_id);

    const rawPhone = fields.phone_number || fields.phone || '';
    const phone = normalizePhone10(rawPhone);
    if (!phone) {
      console.warn('Leadgen: invalid phone, skipping', rawPhone);
      return;
    }

    const id = crypto.randomUUID();
    const name =
      `${fields.first_name || ''} ${fields.last_name || ''}`.trim() || 'Unknown';

    const email = fields.email || null;
    const campaign = fields._campaign_name || '';
    const campaignId = fields._campaign_id || null;

    const now = new Date().toISOString();

    // Save lead
    await env.DB.prepare(
      `INSERT INTO leads (id, name, phone, email, campaign, campaign_id, stage, source, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, 'New', 'Facebook Lead Ad', ?, ?)`,
    )
      .bind(id, name, phone, email, campaign, campaignId, now, now)
      .run();

    // Activity
    await env.DB.prepare(
      `INSERT INTO lead_activities (id, lead_id, type, description, created_at)
       VALUES (?, ?, ?, ?, datetime('now'))`,
    )
      .bind(crypto.randomUUID(), id, 'note', `Captured from Lead Ad: ${campaign}`)
      .run();

    // FCM
    await notify(env, 'lead', '🎯 New Lead!', `${name} from ${campaign}`, {
      lead_id: id,
      phone,
      campaign_id: campaignId ?? '',
    });

    // WhatsApp auto-followup (bridge to kaapav-app)
    if (env.WHATSAPP_BOT_URL && phone) {
      try {
        await fetch(`${env.WHATSAPP_BOT_URL}/api/auto-followup`, {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'X-API-Key': env.API_SECRET_KEY,
          },
          body: JSON.stringify({
            phone,
            name,
            source: 'Facebook Lead Ad',
          }),
        });

        await env.DB.prepare(
          `INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, status, created_at)
           VALUES (?, ?, ?, 'outbound', 'auto_followup', 'sent', datetime('now'))`,
        )
          .bind(crypto.randomUUID(), id, phone)
          .run();
      } catch (e) {
        console.warn('WA auto-followup failed:', e);
      }
    }
  } catch (err) {
    console.error('Leadgen handler failed:', err);
  }
}

// ─────────────────────────────────────────────
// POST /whatsapp — From kaapav-app (WhatsApp worker)
// Auth: X-API-Key must match API_SECRET_KEY
//
// Supports your existing payload format:
// { event, phone, data } OR { event_type, phone, data }
// and will NOT assume extra fields beyond what is sent.
// ─────────────────────────────────────────────
app.post('/whatsapp', async (c) => {
  const apiKey = c.req.header('X-API-Key');
  if (apiKey !== c.env.API_SECRET_KEY) {
    return c.json({ success: false, error: 'Unauthorized' }, 401);
  }

  const raw = await c.req.json<any>();

  const event = String(raw?.event ?? raw?.event_type ?? '').trim();
  const phone = normalizePhone10(String(raw?.phone ?? '').trim());
  const data = raw?.data ?? {};

  if (!event) return c.json({ success: false, error: 'Missing event' }, 400);
  if (!phone) return c.json({ success: false, error: 'Invalid phone' }, 400);

  // Extract optional aligned fields (NO assumptions: only use if present)
  const orderId =
    pickStr(data, ['order_id', 'orderId']) ||
    pickStr(raw, ['order_id']) ||
    '';

  const total = pickNum(data, ['total', 'amount', 'value']);
  const status = pickStr(data, ['status']);
  const paymentStatus = pickStr(data, ['payment_status', 'paymentStatus']);
  const paymentId = pickStr(data, ['payment_id', 'paymentId']);
  const paymentMethod = pickStr(data, ['payment_method', 'paymentMethod']);
  const paidAt = pickStr(data, ['paid_at', 'paidAt']);

  const shiprocketOrderId = pickStr(data, ['shiprocket_order_id']);
  const shipmentId = pickStr(data, ['shipment_id']);
  const awbNumber = pickStr(data, ['awb_number']);
  const trackingUrl = pickStr(data, ['tracking_url']);

  const shippedAt = pickStr(data, ['shipped_at']);
  const deliveredAt = pickStr(data, ['delivered_at']);
  const cancelledAt = pickStr(data, ['cancelled_at']);

  const message = pickStr(data, ['message']);

  // 1) append to wa_order_events (aligned with your table)
  await c.env.DB.prepare(
    `INSERT INTO wa_order_events
      (id, order_id, phone, event_type, event_source, message, meta_json, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'))`,
  )
    .bind(
      crypto.randomUUID(),
      nullIfEmpty(orderId),
      phone,
      event,
      'kaapav-app',
      nullIfEmpty(message),
      JSON.stringify(data ?? {}),
    )
    .run();

  // 2) upsert order_signals if order_id exists
  if (orderId) {
    await c.env.DB.prepare(
      `INSERT INTO order_signals (
        order_id, phone, customer_name, source,
        total, status, payment_status, payment_id, payment_method, paid_at,
        shiprocket_order_id, shipment_id, awb_number, tracking_url,
        shipped_at, delivered_at, cancelled_at,
        created_at, updated_at
      ) VALUES (
        ?, ?, ?, ?,
        ?, ?, ?, ?, ?, ?,
        ?, ?, ?, ?,
        ?, ?, ?,
        datetime('now'), datetime('now')
      )
      ON CONFLICT(order_id) DO UPDATE SET
        phone=excluded.phone,
        customer_name=COALESCE(excluded.customer_name, order_signals.customer_name),
        source=COALESCE(excluded.source, order_signals.source),
        total=COALESCE(excluded.total, order_signals.total),
        status=COALESCE(excluded.status, order_signals.status),
        payment_status=COALESCE(excluded.payment_status, order_signals.payment_status),
        payment_id=COALESCE(excluded.payment_id, order_signals.payment_id),
        payment_method=COALESCE(excluded.payment_method, order_signals.payment_method),
        paid_at=COALESCE(excluded.paid_at, order_signals.paid_at),
        shiprocket_order_id=COALESCE(excluded.shiprocket_order_id, order_signals.shiprocket_order_id),
        shipment_id=COALESCE(excluded.shipment_id, order_signals.shipment_id),
        awb_number=COALESCE(excluded.awb_number, order_signals.awb_number),
        tracking_url=COALESCE(excluded.tracking_url, order_signals.tracking_url),
        shipped_at=COALESCE(excluded.shipped_at, order_signals.shipped_at),
        delivered_at=COALESCE(excluded.delivered_at, order_signals.delivered_at),
        cancelled_at=COALESCE(excluded.cancelled_at, order_signals.cancelled_at),
        updated_at=datetime('now')`,
    )
      .bind(
        orderId,
        phone,
        nullIfEmpty(pickStr(data, ['customer_name', 'customerName'])),
        nullIfEmpty(pickStr(data, ['source'])) ?? 'whatsapp',

        total,
        nullIfEmpty(status),
        nullIfEmpty(paymentStatus),
        nullIfEmpty(paymentId),
        nullIfEmpty(paymentMethod),
        nullIfEmpty(paidAt),

        nullIfEmpty(shiprocketOrderId),
        nullIfEmpty(shipmentId),
        nullIfEmpty(awbNumber),
        nullIfEmpty(trackingUrl),

        nullIfEmpty(shippedAt),
        nullIfEmpty(deliveredAt),
        nullIfEmpty(cancelledAt),
      )
      .run();
  }

  // 3) Attribution map (ONLY if provided by sender; no assumptions)
  // If later you add referral/utm capture, just include campaign_id/adset_id/ad_id in data.
  const campaignId = pickStr(data, ['campaign_id', 'campaignId']);
  const adsetId = pickStr(data, ['adset_id', 'adsetId']);
  const adId = pickStr(data, ['ad_id', 'adId']);
  const sourcePlatform = pickStr(data, ['source_platform', 'sourcePlatform']);

  if (campaignId || adsetId || adId) {
    await c.env.DB.prepare(
      `INSERT INTO attribution_map (
        phone, source, source_platform, campaign_id, adset_id, ad_id,
        confidence, first_seen, last_seen, data_json
      ) VALUES (?, ?, ?, ?, ?, ?, ?, datetime('now'), datetime('now'), ?)
      ON CONFLICT(phone) DO UPDATE SET
        source = COALESCE(NULLIF(excluded.source, ''), attribution_map.source),
        source_platform = COALESCE(NULLIF(excluded.source_platform, ''), attribution_map.source_platform),
        campaign_id = COALESCE(NULLIF(excluded.campaign_id, ''), attribution_map.campaign_id),
        adset_id = COALESCE(NULLIF(excluded.adset_id, ''), attribution_map.adset_id),
        ad_id = COALESCE(NULLIF(excluded.ad_id, ''), attribution_map.ad_id),
        confidence = MAX(attribution_map.confidence, excluded.confidence),
        last_seen = datetime('now'),
        data_json = excluded.data_json`,
    )
      .bind(
        phone,
        'meta_click_to_whatsapp',
        nullIfEmpty(sourcePlatform) ?? 'unknown',
        nullIfEmpty(campaignId),
        nullIfEmpty(adsetId),
        nullIfEmpty(adId),
        80,
        JSON.stringify(data ?? {}),
      )
      .run();
  }

  // 4) Find lead by phone (normalized)
  const lead = await c.env.DB.prepare(
    `SELECT * FROM leads WHERE phone = ? ORDER BY updated_at DESC LIMIT 1`,
  )
    .bind(phone)
    .first<Lead>();

  // 5) Apply your existing CRM/lead update logic (NO changes in behavior)
  switch (event) {
    case 'order_placed':
      if (lead) {
        await c.env.DB.prepare(
          `UPDATE leads
           SET stage='Converted', value=?, product=?, updated_at=datetime('now')
           WHERE id=?`,
        )
          .bind(total ?? 0, nullIfEmpty(pickStr(data, ['product'])), lead.id)
          .run();

        await c.env.DB.prepare(
          `INSERT INTO lead_activities (id, lead_id, type, description, created_at)
           VALUES (?, ?, 'order', ?, datetime('now'))`,
        )
          .bind(
            crypto.randomUUID(),
            lead.id,
            `Order placed — ₹${Math.round(total ?? 0)}`,
          )
          .run();
      }

      await notify(c.env, 'alert', '🛒 New Order!', `${lead?.name || phone} — ₹${Math.round(total ?? 0)}`, {
        lead_id: lead?.id ?? '',
        phone,
        order_id: orderId,
      });
      break;

    case 'customer_reply':
      if (lead && lead.stage === 'New') {
        await c.env.DB.prepare(
          `UPDATE leads SET stage='Contacted', updated_at=datetime('now') WHERE id=?`,
        )
          .bind(lead.id)
          .run();

        await c.env.DB.prepare(
          `INSERT INTO lead_activities (id, lead_id, type, description, created_at)
           VALUES (?, ?, 'whatsapp', 'Customer replied on WhatsApp', datetime('now'))`,
        )
          .bind(crypto.randomUUID(), lead.id)
          .run();
      }
      break;

    case 'payment_confirmed':
      if (lead) {
        await c.env.DB.prepare(
          `INSERT INTO lead_activities (id, lead_id, type, description, created_at)
           VALUES (?, ?, 'note', ?, datetime('now'))`,
        )
          .bind(
            crypto.randomUUID(),
            lead.id,
            `Payment confirmed — ₹${Math.round(total ?? 0)}`,
          )
          .run();
      }
      break;

    case 'shipping_update':
      if (lead) {
        await c.env.DB.prepare(
          `INSERT INTO lead_activities (id, lead_id, type, description, created_at)
           VALUES (?, ?, 'note', ?, datetime('now'))`,
        )
          .bind(
            crypto.randomUUID(),
            lead.id,
            `Shipping update — ${status || 'updated'}`,
          )
          .run();
      }
      break;
  }

  // 6) Log bridge message (your existing table)
  await c.env.DB.prepare(
    `INSERT INTO whatsapp_bridge (id, lead_id, phone, direction, message_type, status, created_at)
     VALUES (?, ?, ?, 'inbound', ?, 'received', datetime('now'))`,
  )
    .bind(crypto.randomUUID(), lead?.id ?? null, phone, event)
    .run();

  return c.json({ success: true });
});

export default app;