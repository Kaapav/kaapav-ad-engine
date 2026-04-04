import type { Bindings } from '../types';

interface FcmMessage {
  title: string;
  body: string;
  data?: Record<string, string>;
}

// ─── Send to all registered device tokens ───
export async function sendPushNotification(env: Bindings, msg: FcmMessage): Promise<void> {
  const result = await env.DB.prepare('SELECT token FROM device_tokens').all<{ token: string }>();
  if (!result.results?.length) return;

  // FCM Legacy HTTP API
  // TODO: Migrate to FCM HTTP v1 API with service account JWT
  const fcmUrl = 'https://fcm.googleapis.com/fcm/send';

  await Promise.allSettled(
    result.results.map((row) =>
      fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `key=${env.FCM_SERVER_KEY}`,
        },
        body: JSON.stringify({
          to: row.token,
          notification: { title: msg.title, body: msg.body, sound: 'default' },
          data: msg.data || {},
          priority: 'high',
        }),
      })
    )
  );
}

// ─── Save notification to D1 + send push ───
export async function notify(
  env: Bindings,
  type: string,
  title: string,
  body: string,
  payload?: Record<string, string>
): Promise<string> {
  const id = crypto.randomUUID();

  await env.DB.prepare(
    'INSERT INTO notifications (id, type, title, body, payload) VALUES (?, ?, ?, ?, ?)'
  ).bind(id, type, title, body, payload ? JSON.stringify(payload) : null).run();

  await sendPushNotification(env, {
    title,
    body,
    data: { type, notification_id: id, ...(payload || {}) },
  });

  return id;
}