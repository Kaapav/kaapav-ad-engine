-- ═══════════════════════════════════════════════════════════════
-- KAAPAV AD ENGINE — D1 Schema v2.3
-- Base tables + Intelligence tables
-- ═══════════════════════════════════════════════════════════════

-- ─────────────────────────────────────────────
-- Base tables
-- ─────────────────────────────────────────────

CREATE TABLE IF NOT EXISTS leads (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  phone TEXT NOT NULL,
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
  phone TEXT NOT NULL,
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
  ctr REAL NOT NULL DEFAULT 0,
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
  ctr REAL NOT NULL DEFAULT 0,
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
  phone TEXT NOT NULL,
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
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  priority TEXT NOT NULL,
  action_type TEXT NOT NULL,
  title TEXT NOT NULL,
  description TEXT NOT NULL,
  score REAL,
  status TEXT NOT NULL DEFAULT 'open',
  payload TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS performance_snapshots (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  snapshot_date TEXT NOT NULL,
  spend REAL NOT NULL DEFAULT 0,
  revenue REAL NOT NULL DEFAULT 0,
  roas REAL NOT NULL DEFAULT 0,
  cpa REAL NOT NULL DEFAULT 0,
  ctr REAL NOT NULL DEFAULT 0,
  cpc REAL NOT NULL DEFAULT 0,
  cpm REAL NOT NULL DEFAULT 0,
  frequency REAL NOT NULL DEFAULT 0,
  conversions INTEGER NOT NULL DEFAULT 0,
  extra TEXT,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

-- ─────────────────────────────────────────────
-- Base indexes
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
-- Intelligence indexes
-- ─────────────────────────────────────────────

CREATE INDEX IF NOT EXISTS idx_audience_scores_date
  ON audience_scores(entity_date);

CREATE INDEX IF NOT EXISTS idx_audience_scores_status
  ON audience_scores(status);

CREATE INDEX IF NOT EXISTS idx_audience_scores_campaign
  ON audience_scores(campaign_id);

CREATE INDEX IF NOT EXISTS idx_creative_scores_date
  ON creative_scores(entity_date);

CREATE INDEX IF NOT EXISTS idx_creative_scores_status
  ON creative_scores(status);

CREATE INDEX IF NOT EXISTS idx_creative_scores_campaign
  ON creative_scores(campaign_id);

CREATE INDEX IF NOT EXISTS idx_buyer_scores_tier
  ON buyer_scores(buyer_tier);

CREATE INDEX IF NOT EXISTS idx_buyer_scores_seed
  ON buyer_scores(lookalike_seed_eligible);

CREATE INDEX IF NOT EXISTS idx_recommendations_status
  ON optimization_recommendations(status);

CREATE INDEX IF NOT EXISTS idx_recommendations_priority
  ON optimization_recommendations(priority);

CREATE INDEX IF NOT EXISTS idx_recommendations_entity
  ON optimization_recommendations(entity_type, entity_id);

CREATE INDEX IF NOT EXISTS idx_snapshots_entity_date
  ON performance_snapshots(entity_type, entity_id, snapshot_date);