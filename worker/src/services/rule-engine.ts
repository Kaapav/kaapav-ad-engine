import type { Bindings, AutoRule, CampaignParsed } from '../types';
import * as MetaApi from './meta-api';
import { notify } from './fcm';

// ─── Extract metric value from campaign ───
function extractMetric(c: CampaignParsed, metric: string): number {
  const map: Record<string, number> = {
    roas: c.roas,
    cpa: c.cpa,
    ctr: c.ctr,
    cpc: c.cpc,
    cpm: c.cpm,
    frequency: c.frequency,
    spend: c.spend,
    impressions: c.impressions,
    clicks: c.clicks,
    conversions: c.conversions,
    budget_util: c.daily_budget > 0 ? (c.spend / c.daily_budget) * 100 : 0,
  };
  return map[metric] ?? 0;
}

// ─── Evaluate condition ───
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

// ─── Main: Evaluate all active rules against all campaigns ───
export async function evaluateRules(env: Bindings): Promise<number> {
  // 1. Fetch active rules from D1
  const rulesResult = await env.DB.prepare(
    'SELECT * FROM rules WHERE enabled = 1'
  ).all<AutoRule>();
  const rules = rulesResult.results || [];
  if (!rules.length) return 0;

  // 2. Fetch campaigns from Meta
  let campaigns: CampaignParsed[];
  try {
    const raw = await MetaApi.getCampaigns(env, 'last_7d', 50);
    campaigns = raw.map((mc) => {
      const p = MetaApi.parseInsights(mc.insights?.data || []);
      return {
        id: mc.id,
        name: mc.name,
        objective: mc.objective,
        status: mc.effective_status || mc.status,
        daily_budget: parseInt(mc.daily_budget || '0') / 100,
        lifetime_budget: parseInt(mc.lifetime_budget || '0') / 100,
        ...p,
      };
    });
  } catch (err) {
    console.error('Rule evaluation — failed to fetch campaigns:', err);
    return 0;
  }

  // 3. Evaluate + execute
  let triggered = 0;

  for (const rule of rules) {
    for (const campaign of campaigns) {
      if (campaign.status !== 'ACTIVE') continue;

      const value = extractMetric(campaign, rule.metric);
      if (!check(value, rule.operator, rule.threshold)) continue;

      // ── Triggered! Execute action ──
      triggered++;
      let desc = '';

      try {
        switch (rule.action_type) {
          case 'pause':
            await MetaApi.updateCampaignStatus(env, campaign.id, 'PAUSED');
            desc = `Paused "${campaign.name}" — ${rule.metric} was ${value.toFixed(2)}`;
            break;

          case 'scale_budget': {
            const pct = rule.action_value || 20;
            const newBudget = campaign.daily_budget * (1 + pct / 100);
            await MetaApi.updateCampaignBudget(env, campaign.id, newBudget);
            desc = `Scaled "${campaign.name}" budget +${pct}% → ₹${Math.round(newBudget)}/day`;
            break;
          }

          case 'reduce_budget': {
            const pct = rule.action_value || 30;
            const newBudget = Math.max(campaign.daily_budget * (1 - pct / 100), 100);
            await MetaApi.updateCampaignBudget(env, campaign.id, newBudget);
            desc = `Reduced "${campaign.name}" budget -${pct}% → ₹${Math.round(newBudget)}/day`;
            break;
          }

          case 'alert':
            desc = `Alert: "${campaign.name}" ${rule.metric} = ${value.toFixed(2)} (threshold: ${rule.threshold})`;
            break;

          case 'alert_and_pause':
            await MetaApi.updateCampaignStatus(env, campaign.id, 'PAUSED');
            desc = `Alert+Paused: "${campaign.name}" ${rule.metric} = ${value.toFixed(2)}`;
            break;
        }
      } catch (err) {
        console.error(`Action failed for rule "${rule.name}" on "${campaign.name}":`, err);
        desc = `Action failed: ${(err as Error).message}`;
      }

      // Update trigger count
      await env.DB.prepare(
        "UPDATE rules SET triggered_count = triggered_count + 1, last_triggered = datetime('now') WHERE id = ?"
      ).bind(rule.id).run();

      // Log activity
      await env.DB.prepare(
        'INSERT INTO activity_log (id, type, title, description, campaign_id, rule_id) VALUES (?, ?, ?, ?, ?, ?)'
      ).bind(crypto.randomUUID(), 'rule_triggered', rule.name, desc, campaign.id, rule.id).run();

      // Push notification
      await notify(env, 'rule', `⚡ ${rule.name}`, desc, {
        campaign_id: campaign.id,
        rule_id: rule.id,
      });
    }
  }

  // Invalidate campaign cache
  if (triggered > 0) {
    await env.CACHE.delete('campaigns:last_7d:50');
    await env.CACHE.delete('campaigns:last_30d:50');
  }

  console.log(`✅ Rule evaluation complete: ${triggered} actions triggered`);
  return triggered;
}