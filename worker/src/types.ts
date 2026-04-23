// Core entity types
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
};

export type AppEnv = {
  Bindings: Bindings;
};

// Meta API Types
export type MetaCampaign = {
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
};

export type MetaAdSet = {
  id: string;
  name: string;
  status: string;
  daily_budget?: string;
  targeting?: MetaTargeting;
  campaign_id?: string;
};

export type MetaTargeting = {
  age_min?: number;
  age_max?: number;
  genders?: number[];
  geo_locations?: any;
  interests?: any[];
  behaviors?: any[];
  custom_audiences?: { id: string }[];
  excluded_custom_audiences?: { id: string }[];
};

export type MetaInsight = {
  date_start?: string;
  date_stop?: string;
  spend?: string | number;
  impressions?: string | number;
  reach?: string | number;
  clicks?: string | number;
  cpc?: string | number;
  cpm?: string | number;
  ctr?: string | number;
  frequency?: string | number;
  actions?: MetaAction[];
  action_values?: MetaActionValue[];
  purchase_roas?: MetaROAS[];
};

export type MetaAction = {
  action_type: string;
  value: string | number;
};

export type MetaActionValue = {
  action_type: string;
  value: string | number;
};

export type MetaROAS = {
  action_type: string;
  value: string | number;
};

export type ParsedInsights = {
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
};

// Database Types
export type Lead = {
  id: string;
  name: string;
  phone: string;
  email?: string;
  campaign?: string;
  campaign_id?: string;
  stage: 'New' | 'Contacted' | 'Qualified' | 'Converted' | 'Lost';
  source: string;
  product?: string;
  value?: number;
  notes?: string;
  created_at: string;
  updated_at: string;
};

export type OrderSignal = {
  order_id: string;
  phone: string;
  customer_name?: string;
  source: string;
  total: number;
  status: string;
  payment_status: string;
  payment_id?: string;
  payment_method?: string;
  paid_at?: string;
  created_at: string;
  updated_at: string;
};

export type BuyerScore = {
  id: string;
  lead_id?: string;
  phone: string;
  customer_name?: string;
  total_orders: number;
  total_revenue: number;
  avg_order_value: number;
  repeat_orders: number;
  prepaid_ratio: number;
  refund_count: number;
  response_score: number;
  buyer_quality_score: number;
  buyer_tier: 'platinum' | 'gold' | 'silver' | 'risk';
  lookalike_seed_eligible: number;
  product_affinity?: string;
  updated_at: string;
};

export type AudienceScore = {
  id: string;
  entity_date: string;
  campaign_id?: string;
  adset_id?: string;
  audience_key: string;
  audience_name?: string;
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
  status: 'hot' | 'scalable' | 'watch' | 'kill';
  reasons?: string;
  created_at: string;
};

export type CreativeScore = {
  id: string;
  entity_date: string;
  ad_id?: string;
  creative_id?: string;
  campaign_id?: string;
  adset_id?: string;
  audience_key?: string;
  creative_name?: string;
  creative_type?: string;
  hook_type?: string;
  angle?: string;
  product_tag?: string;
  spend: number;
  revenue: number;
  roas: number;
  ctr: number;
  conversions: number;
  match_score: number;
  fatigue_score: number;
  status: 'winner' | 'test' | 'fatiguing' | 'loser';
  reasons?: string;
  created_at: string;
};

export type OptimizationRecommendation = {
  id: string;
  entity_type: string;
  entity_id: string;
  priority: 'low' | 'medium' | 'high' | 'critical';
  action_type: 'scale_budget' | 'hold' | 'reduce_budget' | 'pause' | 'rotate_creative' | 'retarget' | 'duplicate';
  title: string;
  description: string;
  score?: number;
  status: 'open' | 'applied' | 'dismissed' | 'resolved';
  payload?: string;
  created_at: string;
};

export type AutoRule = {
  id: string;
  name: string;
  metric: string;
  operator: '<' | '>' | '<=' | '>=' | '==' | '!=';
  threshold: number;
  action_type: string;
  action_value?: number;
  condition_text: string;
  action_text: string;
  enabled: number;
  triggered_count: number;
  last_triggered?: string;
  applied_to?: string;
  check_interval: number;
};

export type CampaignParsed = ParsedInsights & {
  id: string;
  name: string;
  objective: string;
  status: string;
  daily_budget: number;
  lifetime_budget: number;
};

// Webhook Types
export type WebhookPayload = {
  object: string;
  entry: WebhookEntry[];
};

export type WebhookEntry = {
  id: string;
  time: number;
  changes: WebhookChange[];
};

export type WebhookChange = {
  field: string;
  value: any;
};

// Intelligence Engine Types
export type ScoreWeights = {
  [key: string]: number;
};

export type IntelligenceContext = {
  env: Bindings;
  datePreset: string;
  startDate: string;
  endDate: string;
};