-- ═══════════════════════════════════════════════════════════════
-- KAAPAV AD ENGINE — D1 Schema v2.3.1 (FINAL)
-- Base tables + Intelligence tables + Bridge tables (WhatsApp + Attribution + Meta Daily)
-- Phone policy (for now): phone = 10-digit Indian mobile number (TEXT)
-- Normalize in Worker before insert/upsert.
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- Base tables
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS leads (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL, -- 10-digit
  email TEXT,
  campaign TEXT,
  campaign_id TEXT,
  stage TEXT NOT NULL DEFAULT 'New',
  source TEXT NOT NULL DEFAULT 'Manual',
  product TEXT,
  value REAL DEFAULT 0,
  notes TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS lead_activities (
  id TEXT PRIMARY KEY,
  lead_id TEXT NOT NULL,
  type TEXT NOT NULL,
  description TEXT NOT NULL,
  by_user TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE CASCADE
);

CREATE TABLE IF NOT EXISTS rules (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  metric TEXT NOT NULL,
  operator TEXT NOT NULL,
  threshold REAL NOT NULL,
  action_type TEXT NOT NULL,
  action_value REAL,
  condition_text TEXT NOT NULL,
  action_text TEXT NOT NULL,
  enabled INTEGER NOT NULL DEFAULT 1,
  triggered_count INTEGER NOT NULL DEFAULT 0,
  last_triggered TEXT,
  applied_to TEXT,
  check_interval INTEGER NOT NULL DEFAULT 360,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS activity_log (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  campaign_id TEXT,
  rule_id TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS campaign_cache (
  campaign_id TEXT PRIMARY KEY,
  data TEXT NOT NULL,
  fetched_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS notifications (
  id TEXT PRIMARY KEY,
  type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL,
  payload TEXT,
  read INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS device_tokens (
  token TEXT PRIMARY KEY,
  device_name TEXT,
  platform TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS whatsapp_bridge (
  id TEXT PRIMARY KEY,
  lead_id TEXT,
  phone TEXT NOT NULL, -- 10-digit
  direction TEXT NOT NULL DEFAULT 'outbound',
  message_type TEXT,
  template_name TEXT,
  status TEXT NOT NULL DEFAULT 'sent',
  wa_message_id TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now')),
  FOREIGN KEY (lead_id) REFERENCES leads(id) ON DELETE SET NULL
);

-- ─────────────────────────────────────────────
-- Intelligence tables
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS audience_scores (
  id TEXT PRIMARY KEY,
  entity_date TEXT NOT NULL,
  campaign_id TEXT,
  adset_id TEXT,
  audience_key TEXT NOT NULL,
  audience_name TEXT,
  spend REAL NOT NULL DEFAULT 0,
  revenue REAL NOT NULL DEFAULT 0,
  roas REAL NOT NULL DEFAULT 0,
  cpa REAL NOT NULL DEFAULT 0,
  ctr REAL NOT NULL DEFAULT 0,       -- percent (3.8 means 3.8%)
  cpc REAL NOT NULL DEFAULT 0,
  cpm REAL NOT NULL DEFAULT 0,
  frequency REAL NOT NULL DEFAULT 0,
  clicks INTEGER NOT NULL DEFAULT 0,
  conversions INTEGER NOT NULL DEFAULT 0,
  leads INTEGER NOT NULL DEFAULT 0,
  intent_score REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'watch',
  reasons TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS creative_scores (
  id TEXT PRIMARY KEY,
  entity_date TEXT NOT NULL,
  ad_id TEXT,
  creative_id TEXT,
  campaign_id TEXT,
  adset_id TEXT,
  audience_key TEXT,
  creative_name TEXT,
  creative_type TEXT,
  hook_type TEXT,
  angle TEXT,
  product_tag TEXT,
  spend REAL NOT NULL DEFAULT 0,
  revenue REAL NOT NULL DEFAULT 0,
  roas REAL NOT NULL DEFAULT 0,
  ctr REAL NOT NULL DEFAULT 0,       -- percent
  conversions INTEGER NOT NULL DEFAULT 0,
  match_score REAL NOT NULL DEFAULT 0,
  fatigue_score REAL NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'test',
  reasons TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS buyer_scores (
  id TEXT PRIMARY KEY,
  lead_id TEXT,
  phone TEXT NOT NULL, -- 10-digit
  customer_name TEXT,
  total_orders INTEGER NOT NULL DEFAULT 0,
  total_revenue REAL NOT NULL DEFAULT 0,
  avg_order_value REAL NOT NULL DEFAULT 0,
  repeat_orders INTEGER NOT NULL DEFAULT 0,
  prepaid_ratio REAL NOT NULL DEFAULT 0,
  refund_count INTEGER NOT NULL DEFAULT 0,
  response_score REAL NOT NULL DEFAULT 0,
  buyer_quality_score REAL NOT NULL DEFAULT 0,
  buyer_tier TEXT NOT NULL DEFAULT 'silver',
  lookalike_seed_eligible INTEGER NOT NULL DEFAULT 0,
  product_affinity TEXT,
  updated_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS optimization_recommendations (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,  -- campaign | adset | ad | audience | buyer
  entity_id TEXT NOT NULL,
  priority TEXT NOT NULL,     -- low | medium | high | critical
  action_type TEXT NOT NULL,  -- scale_budget | pause | reduce_budget | rotate_creative | retarget | duplicate | hold
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  score REAL,
  status TEXT NOT NULL DEFAULT 'open', -- open | applied | dismissed
  payload TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS performance_snapshots (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,   -- campaign | adset | ad | account
  entity_id TEXT NOT NULL,
  snapshot_date TEXT NOT NULL, -- YYYY-MM-DD
  spend REAL NOT NULL DEFAULT 0,
  revenue REAL NOT NULL DEFAULT 0,
  roas REAL NOT NULL DEFAULT 0,
  cpa REAL NOT NULL DEFAULT 0,
  ctr REAL NOT NULL DEFAULT 0,       -- percent
  cpc REAL NOT NULL DEFAULT 0,
  cpm REAL NOT NULL DEFAULT 0,
  frequency REAL NOT NULL DEFAULT 0,
  conversions INTEGER NOT NULL DEFAULT 0,
  extra TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─────────────────────────────────────────────
-- Bridge tables (WhatsApp truth signals + Attribution + Meta Daily)
-- ─────────────────────────────────────────────

-- 1) Order Signals — aligns with kaapav-app.orders + your Sheets fields
CREATE TABLE IF NOT EXISTS order_signals (
  order_id TEXT PRIMARY KEY,
  phone TEXT NOT NULL, -- 10-digit
  customer_name TEXT,
  source TEXT DEFAULT 'whatsapp',

  total REAL DEFAULT 0,
  status TEXT DEFAULT 'pending',
  payment_status TEXT DEFAULT 'unpaid',
  payment_id TEXT,
  payment_method TEXT,
  paid_at TEXT,

  shiprocket_order_id TEXT,
  shipment_id TEXT,
  awb_number TEXT,
  tracking_url TEXT,

  shipped_at TEXT,
  delivered_at TEXT,
  cancelled_at TEXT,

  created_at TEXT DEFAULT (datetime('now')),
  updated_at TEXT DEFAULT (datetime('now'))
);

-- 2) WA / Order Events — aligns with kaapav-app.order_events + your "order events sheet"
CREATE TABLE IF NOT EXISTS wa_order_events (
  id TEXT PRIMARY KEY,
  order_id TEXT,
  phone TEXT, -- 10-digit (optional)
  event_type TEXT NOT NULL,
  event_source TEXT,
  message TEXT,
  meta_json TEXT,
  created_at TEXT DEFAULT (datetime('now'))
);

-- 3) Attribution Map — phone → campaign/adset/ad (bridge; can be empty initially)
CREATE TABLE IF NOT EXISTS attribution_map (
  phone TEXT PRIMARY KEY, -- 10-digit

  source TEXT DEFAULT 'unknown', -- meta_click_to_whatsapp | whatsapp_direct | unknown
  source_platform TEXT,          -- facebook | instagram | unknown

  campaign_id TEXT,
  adset_id TEXT,
  ad_id TEXT,

  confidence REAL DEFAULT 0,     -- 0..100
  first_seen TEXT DEFAULT (datetime('now')),
  last_seen TEXT DEFAULT (datetime('now')),

  data_json TEXT
);

-- 4) Meta Daily — typed Meta metrics for Sheets + intelligence
CREATE TABLE IF NOT EXISTS meta_daily (
  id TEXT PRIMARY KEY,
  entity_date TEXT NOT NULL,     -- YYYY-MM-DD

  entity_type TEXT NOT NULL,     -- account | campaign | adset | ad
  entity_id TEXT NOT NULL,
  entity_name TEXT,

  spend REAL NOT NULL DEFAULT 0,
  impressions INTEGER NOT NULL DEFAULT 0,
  reach INTEGER NOT NULL DEFAULT 0,
  clicks INTEGER NOT NULL DEFAULT 0,

  ctr REAL NOT NULL DEFAULT 0,   -- percent (3.8 means 3.8%)
  cpc REAL NOT NULL DEFAULT 0,
  cpm REAL NOT NULL DEFAULT 0,
  frequency REAL NOT NULL DEFAULT 0,

  conversions INTEGER NOT NULL DEFAULT 0,
  revenue REAL NOT NULL DEFAULT 0,
  roas REAL NOT NULL DEFAULT 0,

  created_at TEXT DEFAULT (datetime('now'))
);

-- ─────────────────────────────────────────────
-- REFUND ADJUSTED ROAS TABLE
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS refund_adjusted_roas (
  id                TEXT PRIMARY KEY,
  campaign_id       TEXT NOT NULL,
  campaign_name     TEXT,
  meta_roas         REAL NOT NULL DEFAULT 0,
  true_roas         REAL NOT NULL DEFAULT 0,
  gross_revenue     REAL NOT NULL DEFAULT 0,
  refunded_revenue  REAL NOT NULL DEFAULT 0,
  adjusted_revenue  REAL NOT NULL DEFAULT 0,
  total_spend       REAL NOT NULL DEFAULT 0,
  refund_count      INTEGER NOT NULL DEFAULT 0,
  refund_rate       REAL NOT NULL DEFAULT 0,
  roas_delta        REAL NOT NULL DEFAULT 0,
  trust_level       TEXT NOT NULL DEFAULT 'high',
  computed_at       TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_refund_roas_campaign
  ON refund_adjusted_roas(campaign_id);

CREATE INDEX IF NOT EXISTS idx_refund_roas_computed
  ON refund_adjusted_roas(computed_at DESC);

CREATE INDEX IF NOT EXISTS idx_refund_roas_trust
  ON refund_adjusted_roas(trust_level);

-- ─────────────────────────────────────────────
-- Indexes (base)
-- ─────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_leads_stage ON leads(stage);
CREATE INDEX IF NOT EXISTS idx_leads_phone ON leads(phone);
CREATE INDEX IF NOT EXISTS idx_leads_campaign ON leads(campaign_id);

CREATE INDEX IF NOT EXISTS idx_activities_lead ON lead_activities(lead_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_type ON activity_log(type);

CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);

CREATE INDEX IF NOT EXISTS idx_wa_bridge_lead ON whatsapp_bridge(lead_id);
CREATE INDEX IF NOT EXISTS idx_wa_bridge_phone ON whatsapp_bridge(phone);

-- ─────────────────────────────────────────────
-- Indexes (intelligence)
-- ─────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_audience_scores_date ON audience_scores(entity_date);
CREATE INDEX IF NOT EXISTS idx_audience_scores_status ON audience_scores(status);
CREATE INDEX IF NOT EXISTS idx_audience_scores_campaign ON audience_scores(campaign_id);

CREATE INDEX IF NOT EXISTS idx_creative_scores_date ON creative_scores(entity_date);
CREATE INDEX IF NOT EXISTS idx_creative_scores_status ON creative_scores(status);
CREATE INDEX IF NOT EXISTS idx_creative_scores_campaign ON creative_scores(campaign_id);

CREATE INDEX IF NOT EXISTS idx_buyer_scores_tier ON buyer_scores(buyer_tier);
CREATE INDEX IF NOT EXISTS idx_buyer_scores_seed ON buyer_scores(lookalike_seed_eligible);

CREATE INDEX IF NOT EXISTS idx_recommendations_status ON optimization_recommendations(status);
CREATE INDEX IF NOT EXISTS idx_recommendations_priority ON optimization_recommendations(priority);
CREATE INDEX IF NOT EXISTS idx_recommendations_entity ON optimization_recommendations(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_snapshots_entity_date
  ON performance_snapshots(entity_type, entity_id, snapshot_date);

-- ─────────────────────────────────────────────
-- Indexes (bridge)
-- ─────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_order_signals_phone ON order_signals(phone);
CREATE INDEX IF NOT EXISTS idx_order_signals_payment_status ON order_signals(payment_status);
CREATE INDEX IF NOT EXISTS idx_order_signals_paid_at ON order_signals(paid_at);
CREATE INDEX IF NOT EXISTS idx_order_signals_updated_at ON order_signals(updated_at);

CREATE INDEX IF NOT EXISTS idx_wa_events_order_id ON wa_order_events(order_id);
CREATE INDEX IF NOT EXISTS idx_wa_events_phone ON wa_order_events(phone);
CREATE INDEX IF NOT EXISTS idx_wa_events_type ON wa_order_events(event_type);
CREATE INDEX IF NOT EXISTS idx_wa_events_created ON wa_order_events(created_at);

CREATE INDEX IF NOT EXISTS idx_attr_campaign ON attribution_map(campaign_id);
CREATE INDEX IF NOT EXISTS idx_attr_adset ON attribution_map(adset_id);
CREATE INDEX IF NOT EXISTS idx_attr_ad ON attribution_map(ad_id);
CREATE INDEX IF NOT EXISTS idx_attr_source ON attribution_map(source);

CREATE INDEX IF NOT EXISTS idx_meta_daily_date ON meta_daily(entity_date);
CREATE INDEX IF NOT EXISTS idx_meta_daily_entity ON meta_daily(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_meta_daily_entity_date ON meta_daily(entity_type, entity_id, entity_date);

-- Prevent duplicates for same day/entity in meta_daily (enables safe upsert logic)
CREATE UNIQUE INDEX IF NOT EXISTS uq_meta_daily_key
  ON meta_daily(entity_date, entity_type, entity_id);

-- Add to audience_scores table
CREATE UNIQUE INDEX IF NOT EXISTS 
  idx_audience_scores_key 
  ON audience_scores(audience_key);

-- Add to creative_scores table  
CREATE UNIQUE INDEX IF NOT EXISTS idx_creative_scores_ad_audience
  ON creative_scores(ad_id, audience_key)
  WHERE ad_id IS NOT NULL;

-- Add to buyer_scores table
CREATE UNIQUE INDEX IF NOT EXISTS 
  idx_buyer_scores_phone 
  ON buyer_scores(phone);

-- ─────────────────────────────────────────────
-- GEO INTENT SCORES
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS geo_intent_scores (
  id               TEXT PRIMARY KEY,
  city             TEXT NOT NULL,
  state            TEXT,
  country          TEXT DEFAULT 'India',
  total_leads      INTEGER DEFAULT 0,
  converted_leads  INTEGER DEFAULT 0,
  conversion_rate  REAL DEFAULT 0,
  total_revenue    REAL DEFAULT 0,
  avg_order_value  REAL DEFAULT 0,
  refund_count     INTEGER DEFAULT 0,
  intent_score     REAL DEFAULT 0,
  status           TEXT DEFAULT 'average',
  recommendation   TEXT,
  computed_at      TEXT NOT NULL
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_geo_city
  ON geo_intent_scores(city);

CREATE INDEX IF NOT EXISTS idx_geo_status
  ON geo_intent_scores(status);

CREATE INDEX IF NOT EXISTS idx_geo_score
  ON geo_intent_scores(intent_score DESC);

-- ─────────────────────────────────────────────
-- SEED SYNC LOG
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS seed_sync_log (
  id            TEXT PRIMARY KEY,
  audience_id   TEXT,
  audience_name TEXT,
  seed_count    INTEGER DEFAULT 0,
  synced_at     TEXT NOT NULL,
  status        TEXT DEFAULT 'success',
  error         TEXT
);

CREATE INDEX IF NOT EXISTS idx_seed_sync_date
  ON seed_sync_log(synced_at DESC);

-- ─────────────────────────────────────────────
-- RESPONSE SPEED INSIGHTS
-- ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS response_speed_insights (
  id              TEXT PRIMARY KEY,
  bucket          TEXT NOT NULL,
  count           INTEGER DEFAULT 0,
  conversion_rate REAL DEFAULT 0,
  avg_revenue     REAL DEFAULT 0,
  computed_at     TEXT NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_response_speed_date
  ON response_speed_insights(computed_at DESC);

CREATE INDEX IF NOT EXISTS idx_response_speed_bucket
  ON response_speed_insights(bucket);