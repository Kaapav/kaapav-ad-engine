// ─── Cloudflare Bindings ───
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
  Variables: {
    authenticated?: boolean;
  };
};

// ─── D1 Models ───
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

// ─── Meta API Types ───
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

// ─── Webhook Types ───
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

// ─── API Response ───
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