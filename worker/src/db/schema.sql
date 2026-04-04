-- ════════════════════════════════════════════
-- KAAPAV AD ENGINE — D1 Schema
-- 8 Tables + 8 Indexes
-- ════════════════════════════════════════════

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

-- Indexes
CREATE INDEX IF NOT EXISTS idx_leads_stage ON leads(stage);
CREATE INDEX IF NOT EXISTS idx_leads_phone ON leads(phone);
CREATE INDEX IF NOT EXISTS idx_leads_campaign ON leads(campaign_id);
CREATE INDEX IF NOT EXISTS idx_activities_lead ON lead_activities(lead_id);
CREATE INDEX IF NOT EXISTS idx_activity_log_type ON activity_log(type);
CREATE INDEX IF NOT EXISTS idx_notifications_read ON notifications(read);
CREATE INDEX IF NOT EXISTS idx_wa_bridge_lead ON whatsapp_bridge(lead_id);
CREATE INDEX IF NOT EXISTS idx_wa_bridge_phone ON whatsapp_bridge(phone);