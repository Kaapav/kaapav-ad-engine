import { Hono } from 'hono';
import type { AppEnv, AutoRule } from '../types';

const app = new Hono<AppEnv>();

// GET /
app.get('/', async (c) => {
  const result = await c.env.DB.prepare('SELECT * FROM rules ORDER BY created_at DESC').all<AutoRule>();
  return c.json({ success: true, data: result.results });
});

// POST /
app.post('/', async (c) => {
  const body = await c.req.json();
  const id = crypto.randomUUID();

  await c.env.DB.prepare(
    `INSERT INTO rules (id, name, metric, operator, threshold, action_type, action_value,
     condition_text, action_text, enabled, check_interval) VALUES (?,?,?,?,?,?,?,?,?,?,?)`
  ).bind(
    id, body.name, body.metric, body.operator, body.threshold,
    body.action_type, body.action_value || null,
    body.condition_text || `${body.metric} ${body.operator} ${body.threshold}`,
    body.action_text || body.action_type,
    body.enabled !== undefined ? (body.enabled ? 1 : 0) : 1,
    body.check_interval || 360
  ).run();

  return c.json({ success: true, data: { id, ...body } }, 201);
});

// PATCH /:id — Toggle enabled
app.patch('/:id', async (c) => {
  const id = c.req.param('id');
  const body = await c.req.json();

  if (body.enabled !== undefined) {
    await c.env.DB.prepare('UPDATE rules SET enabled = ? WHERE id = ?')
      .bind(body.enabled ? 1 : 0, id).run();
  }

  return c.json({ success: true, data: { id, enabled: body.enabled } });
});

// DELETE /:id
app.delete('/:id', async (c) => {
  await c.env.DB.prepare('DELETE FROM rules WHERE id = ?').bind(c.req.param('id')).run();
  return c.json({ success: true });
});

export default app;