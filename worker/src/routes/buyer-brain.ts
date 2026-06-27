import { Hono } from 'hono';
import type { AppEnv } from '../types';
import {
  getBuyerBrainSummary,
  runBuyerBrainEngine,
} from '../services/buyer-brain-engine';

const app = new Hono<AppEnv>();

function limitParam(value: unknown, fallback = 50, max = 200): number {
  const n = Number(value ?? fallback);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(1, Math.floor(n)));
}

function str(value: unknown, fallback = ''): string {
  const s = value?.toString().trim();
  return s && s.length > 0 ? s : fallback;
}

function nullableStr(value: unknown): string | null {
  const s = value?.toString().trim();
  return s && s.length > 0 ? s : null;
}

function num(value: unknown, fallback = 0): number {
  const n = Number(value);
  return Number.isFinite(n) ? n : fallback;
}

function normalizeEventType(value: unknown): string {
  const raw = str(value, 'manual_signal').toLowerCase();

  const allowed = new Set([
    'page_view',
    'product_view',
    'add_to_cart',
    'checkout_started',
    'order_created',
    'order_paid',
    'order_cancelled',
    'refund_created',
    'whatsapp_clicked',
    'whatsapp_message',
    'price_asked',
    'catalog_clicked',
    'manual_signal',
  ]);

  return allowed.has(raw) ? raw : 'manual_signal';
}

function intentWeight(eventType: string, eventValue: number): number {
  switch (eventType) {
    case 'order_paid':
      return eventValue > 0 ? 100 : 85;
    case 'order_created':
      return 75;
    case 'checkout_started':
      return 60;
    case 'add_to_cart':
      return 50;
    case 'price_asked':
      return 45;
    case 'whatsapp_message':
      return 42;
    case 'whatsapp_clicked':
      return 35;
    case 'catalog_clicked':
      return 28;
    case 'product_view':
      return 18;
    case 'refund_created':
    case 'order_cancelled':
      return -70;
    default:
      return 10;
  }
}

app.get('/summary', async (c) => {
  try {
    const data = await getBuyerBrainSummary(c.env);
    return c.json({ success: true, data });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/recompute', async (c) => {
  try {
    const q = c.req.query();

    const data = await runBuyerBrainEngine(c.env, {
      source: 'manual',
      datePreset: q.date_preset || 'last_30d',
      limit: limitParam(q.limit, 50, 100),
    });

    return c.json({ success: true, data });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/events', async (c) => {
  try {
    const body = await c.req.json().catch(() => null);
    const input = Array.isArray(body) ? body : [body];

    const events = input.filter((x) => x && typeof x === 'object');

    if (!events.length) {
      return c.json(
        { success: false, error: 'Expected event object or event array' },
        400,
      );
    }

    let inserted = 0;

    for (let i = 0; i < events.length; i++) {
      const e = events[i] as Record<string, unknown>;

      const eventType = normalizeEventType(e.event_type);
      const eventValue = num(e.event_value, 0);
      const source = str(e.source, 'manual');
      const sourceRef = nullableStr(e.source_ref);

      const id =
        nullableStr(e.id) ||
        [
          'buyer_event',
          source,
          sourceRef || Date.now().toString(),
          i.toString(),
        ]
          .join(':')
          .replace(/\s+/g, '_')
          .toLowerCase();

      await c.env.DB.prepare(
        `INSERT OR REPLACE INTO buyer_events (
          id,
          source,
          source_ref,
          event_type,
          event_time,

          customer_key,
          phone_hash,
          email_hash,

          campaign_id,
          campaign_name,
          adset_id,
          adset_name,
          ad_id,
          ad_name,
          creative_id,

          product_sku,
          product_category,
          product_name,

          event_value,
          currency,
          intent_weight,
          confidence,

          raw_json,
          created_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, CURRENT_TIMESTAMP)`,
      )
        .bind(
          id,
          source,
          sourceRef,
          eventType,
          str(e.event_time, new Date().toISOString()),

          nullableStr(e.customer_key),
          nullableStr(e.phone_hash),
          nullableStr(e.email_hash),

          nullableStr(e.campaign_id),
          nullableStr(e.campaign_name),
          nullableStr(e.adset_id),
          nullableStr(e.adset_name),
          nullableStr(e.ad_id),
          nullableStr(e.ad_name),
          nullableStr(e.creative_id),

          nullableStr(e.product_sku),
          nullableStr(e.product_category),
          nullableStr(e.product_name),

          eventValue,
          str(e.currency, 'INR'),
          num(e.intent_weight, intentWeight(eventType, eventValue)),
          num(e.confidence, 70),

          JSON.stringify(e),
        )
        .run();

      inserted += 1;
    }

    return c.json({
      success: true,
      data: {
        inserted,
      },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/events', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (q.source) {
      where.push('source = ?');
      bind.push(q.source);
    }

    if (q.event_type) {
      where.push('event_type = ?');
      bind.push(q.event_type);
    }

    if (q.campaign_id) {
      where.push('campaign_id = ?');
      bind.push(q.campaign_id);
    }

    if (q.product_category) {
      where.push('product_category = ?');
      bind.push(q.product_category);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM buyer_events
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY event_time DESC, created_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/scores', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (q.entity_type) {
      where.push('entity_type = ?');
      bind.push(q.entity_type);
    }

    if (q.product_category) {
      where.push('product_category = ?');
      bind.push(q.product_category);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM buyer_signal_scores
       ${where.length ? `WHERE ${where.join(' AND ')}` : ''}
       ORDER BY buyer_intent_score DESC, calculated_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/waste', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM buyer_signal_scores
       ORDER BY waste_score DESC, spend DESC, calculated_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/product-affinity', async (c) => {
  try {
    const q = c.req.query();
    const limit = limitParam(q.limit, 50, 200);

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM product_affinity_scores
       ORDER BY buyer_intent_score DESC, calculated_at DESC
       LIMIT ?`,
    )
      .bind(limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.get('/recommendations', async (c) => {
  try {
    const q = c.req.query();
    const status = q.status?.trim();
    const priority = q.priority?.trim();
    const limit = limitParam(q.limit, 50, 200);

    const where: string[] = [];
    const bind: unknown[] = [];

    if (status) {
      where.push('status = ?');
      bind.push(status);
    } else {
      where.push(`status IN ('open', 'pending_approval')`);
    }

    if (priority) {
      where.push('priority = ?');
      bind.push(priority);
    }

    const rows = await c.env.DB.prepare(
      `SELECT *
       FROM targeting_recommendations
       WHERE ${where.join(' AND ')}
       ORDER BY
         CASE priority
           WHEN 'critical' THEN 4
           WHEN 'high' THEN 3
           WHEN 'medium' THEN 2
           WHEN 'low' THEN 1
           ELSE 0
         END DESC,
         buyer_intent_score DESC,
         created_at DESC
       LIMIT ?`,
    )
      .bind(...bind, limit)
      .all();

    return c.json({
      success: true,
      data: rows.results ?? [],
      meta: { total: (rows.results ?? []).length },
    });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

app.post('/recommendations/:id/dismiss', async (c) => {
  try {
    const id = c.req.param('id');

    const result = await c.env.DB.prepare(
      `UPDATE targeting_recommendations
       SET status = 'dismissed',
           dismissed_at = CURRENT_TIMESTAMP,
           updated_at = CURRENT_TIMESTAMP
       WHERE id = ?`,
    )
      .bind(id)
      .run();

    if ((result.meta?.changes ?? 0) === 0) {
      return c.json({ success: false, error: 'Recommendation not found' }, 404);
    }

    await c.env.DB.prepare(
      `INSERT INTO action_ledger (
        id, source, action_type, entity_type, entity_id,
        recommendation_id, status, actor, reason, created_at
      ) VALUES (?, 'buyer_brain', 'dismiss_recommendation', 'targeting_recommendation', ?, ?, 'recorded', 'user', 'Dismissed buyer brain recommendation', CURRENT_TIMESTAMP)`,
    )
      .bind(crypto.randomUUID(), id, id)
      .run();

    return c.json({ success: true, data: { id, status: 'dismissed' } });
  } catch (err: any) {
    return c.json({ success: false, error: err?.message ?? 'Failed' }, 500);
  }
});

export default app;