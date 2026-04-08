import type { Bindings, IntelligenceSummary } from '../types';
import * as MetaApi from './meta-api';
import { notify } from './fcm';

export type BootstrapOptions = {
  source: 'manual' | 'cron_6h' | 'daily_report';
  notifyCritical?: boolean;
};

export async function runIntelligenceBootstrap(
  env: Bindings,
  options: BootstrapOptions,
): Promise<{
  ok: true;
  source: string;
  snapshotsSaved: number;
  recommendationsUpserted: number;
  summary: IntelligenceSummary;
}> {
  const raw = await MetaApi.getCampaigns(env, 'last_7d', 50);

  const campaigns = raw.map((mc) => {
    const parsed = MetaApi.parseInsights(mc.insights?.data || []) as Record<
      string,
      any
    >;

    return {
      id: mc.id,
      name: mc.name,
      objective: mc.objective,
      status: mc.effective_status || mc.status,
      spend: Number(parsed.spend ?? 0),
      revenue: Number(parsed.revenue ?? 0),
      roas: Number(parsed.roas ?? 0),
      cpa: Number(parsed.cpa ?? 0),
      ctr: Number(parsed.ctr ?? 0),
      cpc: Number(parsed.cpc ?? 0),
      cpm: Number(parsed.cpm ?? 0),
      frequency: Number(parsed.frequency ?? 0),
      leads: Number(parsed.leads ?? 0),
      conversions: Number(parsed.conversions ?? 0),
    };
  });

  await persistCampaignSnapshots(env, campaigns);

  const activeRecommendationIds = new Set<string>();
  let recommendationsUpserted = 0;

  for (const campaign of campaigns) {
    // Scale candidate
    if (campaign.roas >= 4 && campaign.spend >= 1500) {
      const id = `bootstrap:scale:${campaign.id}`;
      activeRecommendationIds.add(id);

      await upsertRecommendation(env, {
        id,
        entityType: 'campaign',
        entityId: campaign.id,
        priority: campaign.roas >= 5 ? 'high' : 'medium',
        actionType: 'scale_budget',
        title: `Scale ${campaign.name} by 15%`,
        description:
          `Strong ROAS (${campaign.roas.toFixed(2)}x)` +
          `${campaign.frequency > 0 ? `, frequency ${campaign.frequency.toFixed(2)}x` : ''}` +
          `, and spend ₹${Math.round(campaign.spend)} indicate a scalable winner.`,
        score: Math.min(100, Math.round(campaign.roas * 18)),
        payload: {
          source: 'bootstrap',
          budgetDeltaPercent: 15,
          campaignId: campaign.id,
        },
      });

      recommendationsUpserted++;
    }

    // Pause / reduce candidate
    if (campaign.roas > 0 && campaign.roas < 2 && campaign.spend >= 1000) {
      const id = `bootstrap:pause:${campaign.id}`;
      activeRecommendationIds.add(id);

      await upsertRecommendation(env, {
        id,
        entityType: 'campaign',
        entityId: campaign.id,
        priority: campaign.roas < 1.5 ? 'critical' : 'high',
        actionType: 'pause',
        title: `Pause or cut spend for ${campaign.name}`,
        description:
          `ROAS is only ${campaign.roas.toFixed(2)}x after spend ₹${Math.round(campaign.spend)}.` +
          ` This campaign looks inefficient and should be reviewed immediately.`,
        score: Math.max(1, 100 - Math.round(campaign.roas * 30)),
        payload: {
          source: 'bootstrap',
          campaignId: campaign.id,
          suggestedAction: 'pause_or_reduce',
        },
      });

      recommendationsUpserted++;
    }

    // Fatigue candidate
    if (campaign.frequency >= 3.5) {
      const id = `bootstrap:fatigue:${campaign.id}`;
      activeRecommendationIds.add(id);

      await upsertRecommendation(env, {
        id,
        entityType: 'campaign',
        entityId: campaign.id,
        priority: campaign.frequency >= 4.5 ? 'critical' : 'high',
        actionType: 'rotate_creative',
        title: `Rotate creative for ${campaign.name}`,
        description:
          `Frequency is ${campaign.frequency.toFixed(2)}x, which suggests rising audience fatigue.` +
          ` Rotate creatives or narrow delivery before performance drops further.`,
        score: Math.min(100, Math.round(campaign.frequency * 20)),
        payload: {
          source: 'bootstrap',
          campaignId: campaign.id,
          reason: 'fatigue',
        },
      });

      recommendationsUpserted++;
    }
  }

  await resolveStaleBootstrapRecommendations(env, [...activeRecommendationIds]);

  const summary = await getIntelligenceSummary(env);

  await env.DB.prepare(
    'INSERT INTO activity_log (id, type, title, description) VALUES (?, ?, ?, ?)',
  )
    .bind(
      crypto.randomUUID(),
      'intelligence',
      'Intelligence bootstrap recomputed',
      `Source: ${options.source}, Snapshots: ${campaigns.length}, Recommendations: ${recommendationsUpserted}`,
    )
    .run();

  if (options.notifyCritical) {
    const critical = await env.DB.prepare(
      `SELECT COUNT(*) as count
       FROM optimization_recommendations
       WHERE status = 'open' AND priority = 'critical'`,
    ).first<{ count: number }>();

    const criticalCount = Number(critical?.count ?? 0);

    if (criticalCount > 0) {
await notify(
  env,
  'alert',
  '⚠️ Critical Optimization Alerts',
  `${criticalCount} critical recommendation(s) need attention`,
  {
    type: 'intelligence_alert',
    criticalCount: String(criticalCount),
  },
);
    }
  }

  return {
    ok: true,
    source: options.source,
    snapshotsSaved: campaigns.length,
    recommendationsUpserted,
    summary,
  };
}

export async function persistCampaignSnapshots(
  env: Bindings,
  campaigns: Array<{
    id: string;
    name: string;
    objective?: string;
    status?: string;
    spend?: number;
    revenue?: number;
    roas?: number;
    cpa?: number;
    ctr?: number;
    cpc?: number;
    cpm?: number;
    frequency?: number;
    conversions?: number;
    leads?: number;
  }>,
): Promise<void> {
  const snapshotDate = new Date().toISOString();

  for (const campaign of campaigns) {
    await env.DB.prepare(
      `INSERT INTO performance_snapshots (
        id, entity_type, entity_id, snapshot_date,
        spend, revenue, roas, cpa, ctr, cpc, cpm, frequency, conversions, extra, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      `,
    )
      .bind(
        crypto.randomUUID(),
        'campaign',
        campaign.id,
        snapshotDate,
        Number(campaign.spend ?? 0),
        Number(campaign.revenue ?? 0),
        Number(campaign.roas ?? 0),
        Number(campaign.cpa ?? 0),
        Number(campaign.ctr ?? 0),
        Number(campaign.cpc ?? 0),
        Number(campaign.cpm ?? 0),
        Number(campaign.frequency ?? 0),
        Number(campaign.conversions ?? 0),
        JSON.stringify({
          name: campaign.name,
          objective: campaign.objective,
          status: campaign.status,
          leads: campaign.leads ?? 0,
        }),
        snapshotDate,
      )
      .run();
  }
}

async function upsertRecommendation(
  env: Bindings,
  input: {
    id: string;
    entityType: string;
    entityId: string;
    priority: 'low' | 'medium' | 'high' | 'critical';
    actionType:
      | 'scale_budget'
      | 'hold'
      | 'reduce_budget'
      | 'pause'
      | 'rotate_creative'
      | 'retarget'
      | 'duplicate';
    title: string;
    description: string;
    score: number;
    payload?: Record<string, unknown>;
  },
): Promise<void> {
  const now = new Date().toISOString();

  await env.DB.prepare(
    `INSERT INTO optimization_recommendations (
      id, entity_type, entity_id, priority, action_type,
      title, description, score, status, payload, created_at
    ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
    ON CONFLICT(id) DO UPDATE SET
      entity_type = excluded.entity_type,
      entity_id = excluded.entity_id,
      priority = excluded.priority,
      action_type = excluded.action_type,
      title = excluded.title,
      description = excluded.description,
      score = excluded.score,
      status = 'open',
      payload = excluded.payload
    `,
  )
    .bind(
      input.id,
      input.entityType,
      input.entityId,
      input.priority,
      input.actionType,
      input.title,
      input.description,
      input.score,
      'open',
      JSON.stringify(input.payload ?? {}),
      now,
    )
    .run();
}

async function resolveStaleBootstrapRecommendations(
  env: Bindings,
  activeIds: string[],
): Promise<void> {
  const existing = await env.DB.prepare(
    `SELECT id
     FROM optimization_recommendations
     WHERE id LIKE 'bootstrap:%' AND status = 'open'`,
  ).all<{ id: string }>();

  const rows = existing.results ?? [];

  for (const row of rows) {
    if (!activeIds.includes(row.id)) {
      await env.DB.prepare(
        `UPDATE optimization_recommendations
         SET status = 'resolved'
         WHERE id = ?`,
      )
        .bind(row.id)
        .run();
    }
  }
}

export async function getIntelligenceSummary(
  env: Bindings,
): Promise<IntelligenceSummary> {
  const avgAudience = await env.DB.prepare(
    `SELECT COALESCE(ROUND(AVG(intent_score), 2), 0) as value
     FROM audience_scores`,
  ).first<{ value: number }>();

  const avgCreative = await env.DB.prepare(
    `SELECT COALESCE(ROUND(AVG(match_score), 2), 0) as value
     FROM creative_scores`,
  ).first<{ value: number }>();

  const topBuyerCount = await env.DB.prepare(
    `SELECT COUNT(*) as count
     FROM buyer_scores
     WHERE buyer_tier IN ('platinum', 'gold')`,
  ).first<{ count: number }>();

  const fatigueAlerts = await env.DB.prepare(
    `SELECT COUNT(*) as count
     FROM creative_scores
     WHERE fatigue_score >= 50`,
  ).first<{ count: number }>();

  const openRecommendations = await env.DB.prepare(
    `SELECT COUNT(*) as count
     FROM optimization_recommendations
     WHERE status = 'open'`,
  ).first<{ count: number }>();

  const scalableCampaigns = await env.DB.prepare(
    `SELECT entity_id as id, title, COALESCE(score, 0) as score
     FROM optimization_recommendations
     WHERE status = 'open' AND action_type = 'scale_budget'
     ORDER BY COALESCE(score, 0) DESC
     LIMIT 3`,
  ).all<{ id: string; title: string; score: number }>();

  const hotAudiences = await env.DB.prepare(
    `SELECT audience_key as key,
            COALESCE(audience_name, audience_key) as name,
            COALESCE(intent_score, 0) as score
     FROM audience_scores
     ORDER BY COALESCE(intent_score, 0) DESC
     LIMIT 3`,
  ).all<{ key: string; name: string; score: number }>();

  const seedBuyers = await env.DB.prepare(
    `SELECT phone,
            COALESCE(customer_name, phone) as name,
            COALESCE(buyer_quality_score, 0) as score
     FROM buyer_scores
     WHERE lookalike_seed_eligible = 1
     ORDER BY COALESCE(buyer_quality_score, 0) DESC
     LIMIT 3`,
  ).all<{ phone: string; name: string; score: number }>();

  return {
    avgAudienceScore: Number(avgAudience?.value ?? 0),
    avgCreativeMatchScore: Number(avgCreative?.value ?? 0),
    topBuyerCount: Number(topBuyerCount?.count ?? 0),
    fatigueAlerts: Number(fatigueAlerts?.count ?? 0),
    openRecommendations: Number(openRecommendations?.count ?? 0),
    topScalableCampaigns: scalableCampaigns.results ?? [],
    topHotAudiences: hotAudiences.results ?? [],
    topSeedBuyers: seedBuyers.results ?? [],
  };
}