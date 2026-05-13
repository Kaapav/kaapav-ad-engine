import type { Bindings, AutoRule, CampaignParsed } from '../types';
import * as MetaApi from './meta-api';
import { notify } from './fcm';

// ─── Types ───
type CompoundRule = AutoRule & {
  condition2_metric?: string;
  condition2_operator?: string;
  condition2_threshold?: number;
};

// ─── Minimum spend guard ───
// Never evaluate rules on campaigns with less than this spend
// Protects learning phase campaigns
const MIN_SPEND_FOR_EVALUATION = 500; // ₹500

// ─── Extract metric value from campaign ───
function extractMetric(c: CampaignParsed, metric: string): number {
  const map: Record<string, number> = {
    roas:         c.roas,
    cpa:          c.cpa,
    ctr:          c.ctr,
    cpc:          c.cpc,
    cpm:          c.cpm,
    frequency:    c.frequency,
    spend:        c.spend,
    impressions:  c.impressions,
    clicks:       c.clicks,
    conversions:  c.conversions,
    leads:        c.leads ?? 0,
    budget_util:  c.daily_budget > 0
      ? (c.spend / c.daily_budget) * 100
      : 0,
  };
  return map[metric] ?? 0;
}

// ─── Evaluate single condition ───
function check(value: number, op: string, threshold: number): boolean {
  switch (op) {
    case '<':  return value < threshold;
    case '>':  return value > threshold;
    case '<=': return value <= threshold;
    case '>=': return value >= threshold;
    case '==': return value === threshold;
    case '!=': return value !== threshold;
    default:   return false;
  }
}

// ─── Evaluate compound rule (condition1 AND condition2 if present) ───
function evaluateRule(
  rule: CompoundRule,
  campaign: CampaignParsed,
): boolean {
  // Primary condition
  const v1 = extractMetric(campaign, rule.metric);
  if (!check(v1, rule.operator, rule.threshold)) return false;

  // Secondary condition (AND logic) — only if defined
  if (
    rule.condition2_metric &&
    rule.condition2_operator &&
    rule.condition2_threshold != null
  ) {
    const v2 = extractMetric(campaign, rule.condition2_metric);
    if (!check(v2, rule.condition2_operator, rule.condition2_threshold)) {
      return false;
    }
  }

  return true;
}

// ─── Built-in safety guards ───
// Applied regardless of rule config — protects learning phase
function passesGuards(
  campaign: CampaignParsed,
  rule: CompoundRule,
): { pass: boolean; reason: string } {

  // Guard 1: Never touch campaigns with < ₹500 spend (learning phase)
  if (campaign.spend < MIN_SPEND_FOR_EVALUATION) {
    return {
      pass: false,
      reason: `Skipped — spend ₹${campaign.spend} below minimum ₹${MIN_SPEND_FOR_EVALUATION} (learning phase)`,
    };
  }

  // Guard 2: Never pause a campaign that's already paused
  if (
    (rule.action_type === 'pause' || rule.action_type === 'alert_and_pause') &&
    campaign.status !== 'ACTIVE'
  ) {
    return {
      pass: false,
      reason: `Skipped — campaign already ${campaign.status}`,
    };
  }

  // Guard 3: Never scale a fatigued campaign (frequency > 3.5)
  if (rule.action_type === 'scale_budget' && campaign.frequency > 3.5) {
    return {
      pass: false,
      reason: `Skipped scale — frequency ${campaign.frequency.toFixed(2)}x is too high (fatigue risk)`,
    };
  }

  // Guard 4: Never reduce budget below ₹200/day
  if (rule.action_type === 'reduce_budget') {
    const pct = Number(rule.action_value ?? 30);
    const newBudget = campaign.daily_budget * (1 - pct / 100);
    if (newBudget < 200) {
      return {
        pass: false,
        reason: `Skipped — budget would drop below ₹200/day minimum`,
      };
    }
  }

  return { pass: true, reason: '' };
}

// ─── Main: Evaluate all active rules against all campaigns ───
export async function evaluateRules(env: Bindings): Promise<number> {

  // 1. Fetch active rules from D1
  const rulesResult = await env.DB.prepare(
    `SELECT id, name, metric, operator, threshold,
            action_type, action_value, enabled,
            condition2_metric, condition2_operator, condition2_threshold
     FROM rules
     WHERE enabled = 1`,
  ).all<CompoundRule>();

  const rules = rulesResult.results ?? [];
  if (!rules.length) {
    console.log('[Rules] No active rules found.');
    return 0;
  }

  // 2. Fetch campaigns from Meta (last 7 days for freshest data)
  let campaigns: CampaignParsed[];
  try {
    const raw = await MetaApi.getCampaigns(env, 'last_7d', 50);
    campaigns = raw.map((mc) => {
      const p = MetaApi.parseInsights(mc.insights?.data ?? []) as any;
      return {
        id:               mc.id,
        name:             mc.name,
        objective:        mc.objective,
        status:           mc.effective_status ?? mc.status,
        daily_budget:     parseInt(mc.daily_budget ?? '0') / 100,
        lifetime_budget:  parseInt(mc.lifetime_budget ?? '0') / 100,
        ...p,
      } as CampaignParsed;
    });
  } catch (err) {
    console.error('[Rules] Failed to fetch campaigns:', err);
    return 0;
  }

  console.log(`[Rules] Evaluating ${rules.length} rules × ${campaigns.length} campaigns`);

  let triggered = 0;
  let skipped = 0;

  for (const rule of rules) {
    for (const campaign of campaigns) {

      // Safety guards first
      const guard = passesGuards(campaign, rule);
      if (!guard.pass) {
        skipped++;
        console.log(`[Rules] "${rule.name}" → "${campaign.name}": ${guard.reason}`);
        continue;
      }

      // Compound condition evaluation
      if (!evaluateRule(rule, campaign)) continue;

      // ── Triggered ──
      triggered++;
      let desc = '';

      try {
        switch (rule.action_type) {

          case 'pause':
            await MetaApi.updateCampaignStatus(env, campaign.id, 'PAUSED');
            desc = `Paused "${campaign.name}" — ${rule.metric} was ${extractMetric(campaign, rule.metric).toFixed(2)}`;
            if (rule.condition2_metric) {
              const v2 = extractMetric(campaign, rule.condition2_metric);
              desc += ` AND ${rule.condition2_metric} was ${v2.toFixed(2)}`;
            }
            break;

          case 'scale_budget': {
            const pct = Number(rule.action_value ?? 20);
            const newBudget = campaign.daily_budget * (1 + pct / 100);
            await MetaApi.updateCampaignBudget(env, campaign.id, newBudget);
            desc = `Scaled "${campaign.name}" +${pct}% → ₹${Math.round(newBudget)}/day (ROAS: ${campaign.roas.toFixed(2)}x)`;
            break;
          }

          case 'reduce_budget': {
            const pct = Number(rule.action_value ?? 30);
            const newBudget = Math.max(
              campaign.daily_budget * (1 - pct / 100),
              200,
            );
            await MetaApi.updateCampaignBudget(env, campaign.id, newBudget);
            desc = `Reduced "${campaign.name}" -${pct}% → ₹${Math.round(newBudget)}/day`;
            break;
          }

          case 'alert':
            desc = `Alert: "${campaign.name}" ${rule.metric} = ${extractMetric(campaign, rule.metric).toFixed(2)} (threshold: ${rule.threshold})`;
            break;

          case 'alert_and_pause':
            await MetaApi.updateCampaignStatus(env, campaign.id, 'PAUSED');
            desc = `Alert+Paused: "${campaign.name}" — ${rule.metric} = ${extractMetric(campaign, rule.metric).toFixed(2)}`;
            break;

          default:
            desc = `Unknown action "${rule.action_type}" for rule "${rule.name}"`;
        }
      } catch (err) {
        console.error(`[Rules] Action failed — "${rule.name}" on "${campaign.name}":`, err);
        desc = `Action failed: ${(err as Error).message}`;
      }

      // Update trigger count in D1
      await env.DB.prepare(
        `UPDATE rules
         SET triggered_count = triggered_count + 1,
             last_triggered  = datetime('now')
         WHERE id = ?`,
      ).bind(rule.id).run();

      // Log to activity_log
      await env.DB.prepare(
        `INSERT INTO activity_log
           (id, type, title, description, campaign_id, rule_id, created_at)
         VALUES (?, ?, ?, ?, ?, ?, datetime('now'))`,
      ).bind(
        crypto.randomUUID(),
        'rule_triggered',
        rule.name,
        desc,
        campaign.id,
        rule.id,
      ).run();

      // FCM push
      await notify(env, 'rule', `⚡ ${rule.name}`, desc, {
        campaign_id: campaign.id,
        rule_id:     String(rule.id),
        action_type: rule.action_type,
      });

      console.log(`[Rules] TRIGGERED: "${rule.name}" → ${desc}`);
    }
  }

  // Invalidate campaign cache if anything changed
  if (triggered > 0) {
    await Promise.allSettled([
      env.CACHE.delete('campaigns:last_7d:50'),
      env.CACHE.delete('campaigns:last_30d:50'),
      env.CACHE.delete('campaigns:last_14d:50'),
    ]);
  }

  console.log(`[Rules] Done: ${triggered} triggered, ${skipped} skipped by guards`);
  return triggered;
}