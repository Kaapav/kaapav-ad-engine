import { Hono } from 'hono';
import type { AppEnv, Lead, LeadActivity } from '../types';

const app = new Hono<AppEnv>();

// GET / — List leads
app.get('/', async (c) => {
  const stage = c.req.query('stage');
  const search = c.req.query('search');
  const limit = parseInt(c.req.query('limit') || '50');
  const offset = parseInt(c.req.query('offset') || '0');

  let sql = 'SELECT * FROM leads';
  const conditions: string[] = [];
  const params: any[] = [];

  if (stage && stage !== 'All') {
    conditions.push('stage = ?');
    params.push(stage);
  }
  if (search) {
    conditions.push('(name LIKE ? OR phone LIKE ? OR campaign LIKE ?)');
    params.push(`%${search}%`, `%${search}%`, `%${search}%`);
  }

  if (conditions.length) sql += ' WHERE ' + conditions.join(' AND ');
  sql += ' ORDER BY updated_at DESC LIMIT ? OFFSET ?';

  const countParams = [...params];
  params.push(limit, offset);

  const result = await c.env.DB.prepare(sql).bind(...params).all<Lead>();

  let countSql = 'SELECT COUNT(*) as total FROM leads';
  if (conditions.length) countSql += ' WHERE ' + conditions.join(' AND ');
  const count = await c.env.DB.prepare(countSql).bind(...countParams).first<{ total: number }>();

  return c.json({
    success: true,
    data: result.results,
    meta: { total: count?.total || 0, page: Math.floor(offset / limit) + 1 },
  });
});

// GET /:id — Single lead + activities
app.get('/:id', async (c) => {
  const id = c.req.param('id');
  const lead = await c.env.DB.prepare('SELECT * FROM leads WHERE id = ?').bind(id).first<Lead>();
  if (!lead) return c.json({ success: false, error: 'Lead not found' }, 404);

  const activities = await c.env.DB.prepare(
    'SELECT * FROM lead_activities WHERE lead_id = ? ORDER BY created_at DESC'
  ).bind(id).all<LeadActivity>();

  return c.json({ success: true, data: { ...lead, activities: activities.results } });
});

// POST / — Create lead
app.post('/', async (c) => {
  const body = await c.req.json();
  const id = crypto.randomUUID();
  const now = new Date().toISOString();

  await c.env.DB.prepare(
    `INSERT INTO leads (id, name, phone, email, campaign, campaign_id, stage, source, product, value, notes, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`
  ).bind(
    id, body.name, body.phone, body.email || null,
    body.campaign || null, body.campaign_id || null,
    body.stage || 'New', body.source || 'Manual',
    body.product || null, body.value || 0, body.notes || null,
    now, now
  ).run();

  // Creation activity
  await c.env.DB.prepare(
    'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
  ).bind(crypto.randomUUID(), id, 'note', `Lead created from ${body.source || 'Manual'}`).run();

  // Auto-followup via WhatsApp bot
  if (c.env.WHATSAPP_BOT_URL && body.phone) {
    try {
      await fetch(`${c.env.WHATSAPP_BOT_URL}/api/auto-followup`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-API-Key': c.env.API_SECRET_KEY },
        body: JSON.stringify({ phone: body.phone, name: body.name, product: body.product }),
      });
    } catch { /* silent */ }
  }

  return c.json({ success: true, data: { id, ...body } }, 201);
});

// PATCH /:id — Update lead
app.patch('/:id', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();

  const lead = await c.env.DB.prepare('SELECT * FROM leads WHERE id = ?').bind(id).first<Lead>();
  if (!lead) return c.json({ success: false, error: 'Lead not found' }, 404);

  const sets: string[] = [];
  const vals: any[] = [];

  for (const key of ['stage', 'notes', 'value', 'product', 'email'] as const) {
    if (body[key] !== undefined) { sets.push(`${key} = ?`); vals.push(body[key]); }
  }
  sets.push("updated_at = datetime('now')");

  if (sets.length > 1) {
    await c.env.DB.prepare(`UPDATE leads SET ${sets.join(', ')} WHERE id = ?`).bind(...vals, id).run();
  }

  // Log stage change
  if (body.stage && body.stage !== lead.stage) {
    await c.env.DB.prepare(
      'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), id, 'stage_change', `Stage: ${lead.stage} → ${body.stage}`).run();
  }

  // Log custom note
  if (body.activity_note) {
    await c.env.DB.prepare(
      'INSERT INTO lead_activities (id, lead_id, type, description) VALUES (?, ?, ?, ?)'
    ).bind(crypto.randomUUID(), id, 'note', body.activity_note).run();
  }

  return c.json({ success: true, data: { id, ...body } });
});

// DELETE /:id
app.delete('/:id', async (c) => {
  const id = c.req.param('id');
  await c.env.DB.batch([
    c.env.DB.prepare('DELETE FROM lead_activities WHERE lead_id = ?').bind(id),
    c.env.DB.prepare('DELETE FROM leads WHERE id = ?').bind(id),
  ]);
  return c.json({ success: true });
});

export default app;