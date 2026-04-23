// ═══════════════════════════════════════════════════════════════
// PLATINUM SEED AUTO-SYNC
// Finds Gold/Platinum buyers eligible for Meta Custom Audience.
// Hashes phone numbers (SHA-256) per Meta requirements.
// Creates/updates a "Kaapav Platinum Buyers" custom audience
// via Meta Graph API using the Custom Audience API.
// ═══════════════════════════════════════════════════════════════

import type { AppEnv } from '../types';

// ─────────────────────────────────────────────
// Types
// ─────────────────────────────────────────────

export type SeedSyncResult = {
  seedCount: number;
  audienceId: string | null;
  audienceName: string;
  syncedAt: string;
  success: boolean;
  error?: string;
};

// ─────────────────────────────────────────────
// SHA-256 hash (Web Crypto API — available in CF Workers)
// ─────────────────────────────────────────────

async function sha256(text: string): Promise<string> {
  const msgBuffer  = new TextEncoder().encode(text);
  const hashBuffer = await crypto.subtle.digest('SHA-256', msgBuffer);
  const hashArray  = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, '0')).join('');
}

// ─────────────────────────────────────────────
// Normalize phone for Meta hashing
// Remove spaces, dashes, parens. Add country code if missing.
// ─────────────────────────────────────────────

function normalizePhone(phone: string): string {
  let cleaned = phone.replace(/[\s\-\(\)\+]/g, '');

  // Add India country code if not present
  if (cleaned.startsWith('0')) {
    cleaned = '91' + cleaned.slice(1);
  } else if (cleaned.length === 10) {
    cleaned = '91' + cleaned;
  }

  return cleaned.toLowerCase();
}

// ─────────────────────────────────────────────
// Main Seed Sync Runner
// ─────────────────────────────────────────────

export async function runSeedSync(
  env: AppEnv['Bindings'],
): Promise<SeedSyncResult> {
  const syncedAt = new Date().toISOString();

  // ── Step 1: Load seed-eligible buyers ────────────────────────
  const buyers = await env.DB.prepare(
    `SELECT phone, customer_name, buyer_quality_score
     FROM buyer_scores
     WHERE lookalike_seed_eligible = 1
       AND buyer_tier IN ('platinum', 'gold')
     ORDER BY buyer_quality_score DESC`,
  ).all<{
    phone: string;
    customer_name: string;
    buyer_quality_score: number;
  }>();

  if (!buyers.results?.length) {
    return {
      seedCount:    0,
      audienceId:   null,
      audienceName: 'Kaapav Platinum Buyers',
      syncedAt,
      success:      false,
      error:        'No seed-eligible buyers found',
    };
  }

  // Minimum 100 users for Meta Custom Audience
  // (Meta requires at least 100 matched users)
  if (buyers.results.length < 100) {
    await env.DB.prepare(
      `INSERT INTO activity_log (id, type, title, description, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        'seed_sync',
        'Seed Sync Skipped',
        `Only ${buyers.results.length} seed buyers — need 100+ for Meta Custom Audience`,
        syncedAt,
      )
      .run();

    return {
      seedCount:    buyers.results.length,
      audienceId:   null,
      audienceName: 'Kaapav Platinum Buyers',
      syncedAt,
      success:      false,
      error:        `Need 100+ buyers. Currently ${buyers.results.length}.`,
    };
  }

  // ── Step 2: Hash phone numbers (SHA-256) ──────────────────────
  const hashedPhones: string[] = [];

  for (const buyer of buyers.results) {
    const normalized = normalizePhone(buyer.phone);
    if (normalized.length >= 10) {
      const hashed = await sha256(normalized);
      hashedPhones.push(hashed);
    }
  }

  if (!hashedPhones.length) {
    return {
      seedCount:    0,
      audienceId:   null,
      audienceName: 'Kaapav Platinum Buyers',
      syncedAt,
      success:      false,
      error:        'No valid phone numbers after normalization',
    };
  }

  // ── Step 3: Check if audience already exists in KV ───────────
  const AUDIENCE_KEY  = 'seed:platinum_audience_id';
  const audienceName  = 'Kaapav Platinum Buyers — LAL Seed';
  let audienceId: string | null = await env.CACHE.get(AUDIENCE_KEY);

  const metaBase    = `https://graph.facebook.com/${env.META_API_VERSION}`;
  const accountId   = env.META_AD_ACCOUNT_ID;
  const accessToken = env.META_ACCESS_TOKEN;

  try {
    if (!audienceId) {
      // ── Create new custom audience ────────────────────────────
      const createRes = await fetch(
        `${metaBase}/act_${accountId}/customaudiences`,
        {
          method:  'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            name:        audienceName,
            subtype:     'CUSTOM',
            description: 'Kaapav platinum and gold buyers — lookalike seed',
            customer_file_source: 'USER_PROVIDED_ONLY',
            access_token: accessToken,
          }),
        },
      );

      const createData = (await createRes.json()) as Record<string, any>;

      if (createData.error) {
        throw new Error(
          `Meta API error creating audience: ${createData.error.message}`,
        );
      }

      audienceId = createData.id as string;

      // Cache for 30 days
      await env.CACHE.put(AUDIENCE_KEY, audienceId, {
        expirationTtl: 60 * 60 * 24 * 30,
      });

      console.log(`[Seed Sync] Created Meta Custom Audience: ${audienceId}`);
    }

    // ── Step 4: Upload hashed phone data in batches ───────────
    // Meta allows max 10,000 per batch
    const BATCH_SIZE = 10000;
    let uploaded     = 0;

    for (let i = 0; i < hashedPhones.length; i += BATCH_SIZE) {
      const batch  = hashedPhones.slice(i, i + BATCH_SIZE);

      const schema = ['PHONE'];
      const data   = batch.map((hash) => [hash]);

      const uploadRes = await fetch(
        `${metaBase}/${audienceId}/users`,
        {
          method:  'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            payload: {
              schema,
              data,
            },
            access_token: accessToken,
          }),
        },
      );

      const uploadData = (await uploadRes.json()) as Record<string, any>;

      if (uploadData.error) {
        console.error(
          `[Seed Sync] Upload batch ${i} error:`,
          uploadData.error,
        );
      } else {
        uploaded += batch.length;
      }
    }

    // ── Step 5: Log success ───────────────────────────────────
    await env.DB.prepare(
      `INSERT INTO activity_log (id, type, title, description, created_at)
       VALUES (?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        'seed_sync',
        'Platinum Seed Sync Completed',
        `Synced ${uploaded} hashed phones to Meta Custom Audience "${audienceName}" (ID: ${audienceId})`,
        syncedAt,
      )
      .run();

    // ── Step 6: Update D1 seed_sync_log ──────────────────────
    await env.DB.prepare(
      `INSERT INTO seed_sync_log (
        id, audience_id, audience_name,
        seed_count, synced_at, status
      ) VALUES (?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        audienceId,
        audienceName,
        uploaded,
        syncedAt,
        'success',
      )
      .run();

    return {
      seedCount:   uploaded,
      audienceId,
      audienceName,
      syncedAt,
      success:     true,
    };
  } catch (err: any) {
    console.error('[Seed Sync] Failed:', err);

    await env.DB.prepare(
      `INSERT INTO seed_sync_log (
        id, audience_id, audience_name,
        seed_count, synced_at, status, error
      ) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        crypto.randomUUID(),
        audienceId ?? 'unknown',
        audienceName,
        0,
        syncedAt,
        'failed',
        err.message ?? 'Unknown error',
      )
      .run();

    return {
      seedCount:    0,
      audienceId,
      audienceName,
      syncedAt,
      success:      false,
      error:        err.message ?? 'Unknown error',
    };
  }
}