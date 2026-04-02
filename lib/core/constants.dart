class K {
  // META API
  static const metaBase = 'https://graph.facebook.com/v21.0';
  static String campaigns(String id) => '$metaBase/act_$id/campaigns';
  static String campaign(String id) => '$metaBase/$id';
  static String adsets(String id) => '$metaBase/act_$id/adsets';
  static String ads(String id) => '$metaBase/act_$id/ads';
  static String insights(String id) => '$metaBase/act_$id/insights';
  static String campaignInsights(String id) => '$metaBase/$id/insights';
  static String audiences(String id) => '$metaBase/act_$id/customaudiences';
  static String conversionsApi(String pixelId) => '$metaBase/$pixelId/events';

  // SHEETS API
  static const sheetsBase = 'https://sheets.googleapis.com/v4/spreadsheets';

  // INSIGHT FIELDS
  static const insightFields = [
    'campaign_name', 'campaign_id', 'objective', 'spend',
    'impressions', 'reach', 'clicks', 'cpc', 'cpm', 'ctr',
    'actions', 'action_values', 'cost_per_action_type',
    'purchase_roas', 'frequency', 'date_start', 'date_stop',
  ];

  // OBJECTIVES
  static const objectives = {
    'OUTCOME_SALES': 'Sales',
    'OUTCOME_LEADS': 'Leads',
    'OUTCOME_TRAFFIC': 'Traffic',
    'OUTCOME_AWARENESS': 'Awareness',
    'OUTCOME_ENGAGEMENT': 'Engagement',
  };

  // BID STRATEGIES
  static const bidStrategies = {
    'LOWEST_COST_WITHOUT_CAP': 'Highest Volume',
    'COST_CAP': 'Cost Per Result Goal',
    'MINIMUM_ROAS': 'ROAS Goal',
  };

  // DATE PRESETS
  static const datePresets = ['today', 'yesterday', 'last_7d', 'last_14d', 'last_30d', 'last_90d'];

  // CRM STAGES
  static const crmStages = ['New', 'Contacted', 'Qualified', 'Converted', 'Lost'];

  // APP
  static const appName = 'Kaapav Ad Engine';
  static const currency = '₹';
}