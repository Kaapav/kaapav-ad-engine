import { Hono } from 'hono';
import type { AppEnv, AppNotification } from '../types';

const app = new Hono<AppEnv>();

// GET /
app.get('/', async (c) => {
  const limit = parseInt(c.req.query('limit') || '50');

  const result = await c.env.DB.prepare(
    'SELECT * FROM notifications ORDER BY created_at DESC LIMIT ?'
  ).bind(limit).all<AppNotification>();

  const unread = await c.env.DB.prepare(
    'SELECT COUNT(*) as count FROM notifications WHERE read = 0'
  ).first<{ count: number }>();

  return c.json({
    success: true,
    data: result.results,
    meta: { total: result.results?.length || 0, unread: unread?.count || 0 },
  });
});

// POST /register-device
app.post('/register-device', async (c) => {
  const body = await c.req.json();

  await c.env.DB.prepare(
    `INSERT OR REPLACE INTO device_tokens (token, device_name, platform, created_at)
     VALUES (?, ?, ?, datetime('now'))`
  ).bind(body.token, body.device_name || null, body.platform || 'android').run();

  return c.json({ success: true });
});

// POST /mark-read
app.post('/mark-read', async (c) => {
  await c.env.DB.prepare('UPDATE notifications SET read = 1 WHERE read = 0').run();
  return c.json({ success: true });
});

export default app;