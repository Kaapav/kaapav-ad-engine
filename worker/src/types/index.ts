// ─────────────────────────────────────────────
// Cloudflare Bindings
// ─────────────────────────────────────────────

export type Bindings = {
  DB: D1Database;
  CACHE: KVNamespace;
  SESSIONS: KVNamespace;
  META_ACCESS_TOKEN: string;
  META_APP_SECRET: string;
  META_PIXEL_ID: string;
  META_AD_ACCOUNT_ID: string;
  WHATSAPP_TOKEN: string;
  WHATSAPP_PHONE_ID: string;
  FCM_SERVER_KEY: string;
  GOOGLE_SHEETS_TOKEN: string;
  API_SECRET_KEY: string;
  WHATSAPP_BOT_URL: string;
  ENVIRONMENT: string;
  META_API_VERSION: string;
  GOOGLE_CLIENT_EMAIL: string;
  GOOGLE_PRIVATE_KEY: string;
};

export type AppEnv = {
  Bindings: Bindings;
  Variables: {
    authenticated?: boolean;
  };
};

// ─────────────────────────────────────────────
// D1 Models
// ─────────────────────────────────────────────

export interface Lead {
  id: string;
  name: string;
  phone: string;
  email: string | null;
  campaign: string | null;
  campaign_id: string | null;
  stage: string;
  source: string;
  product: string | null;
  value: number;
  notes: string | null;
  created_at: string;
  updated_at: string;
}

export interface LeadActivity {
  id: string;
  lead_id: string;
  type: string;
  description: string;
  by_user: string | null;
  created_at: string;
}

export interface AutoRule {
  id: string;
  name: string;
  metric: string;
  operator: string;
  threshold: number;
  action_type: string;
  action_value: number | null;
  condition_text: string;
  action_text: string;
  enabled: number;
  triggered_count: number;
  last_triggered: string | null;
  applied_to: string | null;
  check_interval: number;
  created_at: string;
}

export interface ActivityEntry {
  id: string;
  type: string;
  title: string;
  description: string;
  campaign_id: string | null;
  rule_id: string | null;
  created_at: string;
}

export interface AppNotification {
  id: string;
  type: string;
  title: string;
  body: string;
  payload: string | null;
  read: number;
  created_at: string;
}

export interface DeviceToken {
  token: string;
  device_name: string | null;
  platform: string | null;
  created_at: string;
}

export interface WhatsAppBridgeEntry {
  id: string;
  lead_id: string | null;
  phone: string;
  direction: string;
  message_type: string | null;
  template_name: string | null;
  status: string;
  wa_message_id: string | null;
  created_at: string;
}

export interface CampaignCacheRow {
  campaign_id: string;
  data: string;
  fetched_at: string;
}

// ─────────────────────────────────────────────
// Rule / Automation helper types
// ─────────────────────────────────────────────

export type RuleMetric =
  | 'roas'
  | 'cpa'
  | 'ctr'
  | 'cpc'
  | 'cpm'
  | 'frequency'
  | 'spend'
  | 'budget_util'
  | 'impressions'
  | 'clicks'
  | 'conversions'
  | 'leads';

export type RuleOperator = '<' | '>' | '<=' | '>=' | '==' | '!=';

export type RuleActionType =
  | 'pause'
  | 'scale_budget'
  | 'reduce_budget'
  | 'alert'
  | 'alert_and_pause';

// ─────────────────────────────────────────────
// Meta API Types
// ─────────────────────────────────────────────

export interface MetaCampaign {
  id: string;
  name: string;
  objective: string;
  status: string;
  effective_status?: string;
  daily_budget?: string;
  lifetime_budget?: string;
  created_time?: string;
  updated_time?: string;
  insights?: { data: MetaInsight[] };
  adsets?: { data: MetaAdSet[] };
}

export interface MetaAdSet {
  id: string;
  name: string;
  status: string;
  daily_budget?: string;
  targeting?: Record<string, unknown>;
  insights?: { data: MetaInsight[] };
}

export interface MetaAd {
  id: string;
  name: string;
  status?: string;
  effective_status?: string;
  adset_id?: string;
  campaign_id?: string;
  creative?: MetaCreativeRef;
  insights?: { data: MetaInsight[] };
}

export interface MetaCreativeRef {
  id: string;
  name?: string;
  title?: string;
  body?: string;
  object_story_spec?: Record<string, unknown>;
}

export interface MetaCreative {
  id: string;
  name?: string;
  title?: string;
  body?: string;
  object_story_spec?: Record<string, unknown>;
  asset_feed_spec?: Record<string, unknown>;
}

export interface MetaInsight {
  campaign_name?: string;
  spend: string;
  impressions: string;
  reach?: string;
  clicks?: string;
  cpc?: string;
  cpm?: string;
  ctr?: string;
  frequency?: string;
  actions?: Array<{ action_type: string; value: string }>;
  action_values?: Array<{ action_type: string; value: string }>;
  purchase_roas?: Array<{ action_type: string; value: string }>;
  date_start: string;
  date_stop: string;
}

export interface ParsedInsights {
  spend: number;
  revenue: number;
  roas: number;
  cpa: number;
  ctr: number;
  cpc: number;
  cpm: number;
  impressions: number;
  reach: number;
  clicks: number;
  conversions: number;
  leads: number;
  frequency: number;
}

export interface CampaignParsed extends ParsedInsights {
  id: string;
  name: string;
  objective: string;
  status: string;
  daily_budget: number;
  lifetime_budget: number;
}

// ─────────────────────────────────────────────
// Webhook Types
// ─────────────────────────────────────────────

export interface WebhookPayload {
  object: string;
  entry: Array<{
    id: string;
    time: number;
    changes?: Array<{
      field: string;
      value: Record<string, unknown>;
    }>;
  }>;
}

export interface BridgeMessage {
  action: 'send_followup' | 'send_template' | 'send_order' | 'sync_lead';
  lead_id?: string;
  phone: string;
  template?: string;
  params?: Record<string, string>;
  lead_data?: Partial<Lead>;
}

// ─────────────────────────────────────────────
// Intelligence Types
// ─────────────────────────────────────────────

export type ScoreStatus = 'hot' | 'scalable' | 'watch' | 'kill';

export type BuyerTier = 'platinum' | 'gold' | 'silver' | 'risk';

export type CreativeScoreStatus =
  | 'winner'
  | 'test'
  | 'fatiguing'
  | 'loser';

export type RecommendationPriority =
  | 'low'
  | 'medium'
  | 'high'
  | 'critical';

export type DecisionAction =
  | 'scale_budget'
  | 'hold'
  | 'reduce_budget'
  | 'pause'
  | 'rotate_creative'
  | 'retarget'
  | 'duplicate';

export interface AudienceScoreRow {
  id: string;
  entity_date: string;
  campaign_id: string | null;
  adset_id: string | null;
  audience_key: string;
  audience_name: string | null;
  spend: number;
  revenue: number;
  roas: number;
  cpa: number;
  ctr: number;
  cpc: number;
  cpm: number;
  frequency: number;
  clicks: number;
  conversions: number;
  leads: number;
  intent_score: number;
  status: ScoreStatus;
  reasons: string | null;
  created_at: string;
}

export interface CreativeScoreRow {
  id: string;
  entity_date: string;
  ad_id: string | null;
  creative_id: string | null;
  campaign_id: string | null;
  adset_id: string | null;
  audience_key: string | null;
  creative_name: string | null;
  creative_type: string | null;
  hook_type: string | null;
  angle: string | null;
  product_tag: string | null;
  spend: number;
  revenue: number;
  roas: number;
  ctr: number;
  conversions: number;
  match_score: number;
  fatigue_score: number;
  status: string;
  reasons: string | null;
  created_at: string;
}

export interface BuyerScoreRow {
  id: string;
  lead_id: string | null;
  phone: string;
  customer_name: string | null;
  total_orders: number;
  total_revenue: number;
  avg_order_value: number;
  repeat_orders: number;
  prepaid_ratio: number;
  refund_count: number;
  response_score: number;
  buyer_quality_score: number;
  buyer_tier: BuyerTier;
  lookalike_seed_eligible: number;
  product_affinity: string | null;
  updated_at: string;
}

export interface OptimizationRecommendation {
  id: string;
  entity_type: string;
  entity_id: string;
  priority: RecommendationPriority;
  action_type: DecisionAction;
  title: string;
  description: string;
  score: number | null;
  status: string;
  payload: string | null;
  created_at: string;
}

export interface PerformanceSnapshot {
  id: string;
  entity_type: string;
  entity_id: string;
  snapshot_date: string;
  spend: number;
  revenue: number;
  roas: number;
  cpa: number;
  ctr: number;
  cpc: number;
  cpm: number;
  frequency: number;
  conversions: number;
  extra: string | null;
  created_at: string;
}

export interface IntelligenceSummary {
  avgAudienceScore: number;
  avgCreativeMatchScore: number;
  topBuyerCount: number;
  fatigueAlerts: number;
  openRecommendations: number;
  topScalableCampaigns: Array<{
    id: string;
    title: string;
    score: number;
  }>;
  topHotAudiences: Array<{
    key: string;
    name: string;
    score: number;
  }>;
  topSeedBuyers: Array<{
    phone: string;
    name: string;
    score: number;
  }>;
}

// ─────────────────────────────────────────────
// Parsed / Engine helper models
// ─────────────────────────────────────────────

export interface AudienceScoreReasoned extends AudienceScoreRow {
  reason_list?: string[];
}

export interface CreativeScoreReasoned extends CreativeScoreRow {
  reason_list?: string[];
}

export interface BuyerScoreReasoned extends BuyerScoreRow {
  product_affinity_list?: string[];
}

export interface RecommendationPayload {
  campaignId?: string;
  adsetId?: string;
  adId?: string;
  creativeId?: string;
  audienceKey?: string;
  budgetDeltaPercent?: number;
  suggestedAction?: string;
  reason?: string;
  source?: string;
  [key: string]: unknown;
}

// ─────────────────────────────────────────────
// Generic Meta response helpers
// ─────────────────────────────────────────────

export interface MetaPaging {
  previous?: string;
  next?: string;
}

export interface MetaListResponse<T> {
  data: T[];
  paging?: MetaPaging;
}

export interface MetaErrorPayload {
  error?: {
    message?: string;
    type?: string;
    code?: number;
    error_subcode?: number;
    fbtrace_id?: string;
  };
}

// ─────────────────────────────────────────────
// API Response
// ─────────────────────────────────────────────

export interface ApiResponse<T = unknown> {
  success: boolean;
  data?: T;
  error?: string;
  meta?: {
    total?: number;
    page?: number;
    cached?: boolean;
    unread?: number;
  };
}