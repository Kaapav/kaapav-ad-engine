import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campaign.dart';
import '../models/lead.dart';
import '../data/mock_data.dart';
import '../services/meta_api_service.dart';
import '../services/notification_service.dart';

// ═══════════════════════════════════════════════════════════
// META API SERVICE
// ═══════════════════════════════════════════════════════════
final metaApiProvider = Provider<MetaApiService>((ref) => MetaApiService());

// ═══════════════════════════════════════════════════════════
// NOTIFICATION SERVICE
// ═══════════════════════════════════════════════════════════
final notificationProvider = Provider<NotificationService>((ref) => NotificationService());

// ═══════════════════════════════════════════════════════════
// CAMPAIGNS
// ═══════════════════════════════════════════════════════════
final campaignsProvider = StateNotifierProvider<CampaignsNotifier, AsyncValue<List<Campaign>>>((ref) {
  return CampaignsNotifier(ref.read(metaApiProvider));
});

class CampaignsNotifier extends StateNotifier<AsyncValue<List<Campaign>>> {
  // ignore: unused_field
  final MetaApiService _api;
  CampaignsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      // In production, call _api.getCampaigns()
      await Future.delayed(const Duration(milliseconds: 800));
      state = AsyncValue.data(MockData.campaigns);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh() async => load();

  void toggleStatus(String id) {
    state.whenData((campaigns) {
      state = AsyncValue.data(campaigns.map((c) {
        if (c.id == id) return c.copyWith(status: c.isActive ? 'Paused' : 'Active');
        return c;
      }).toList());
    });
  }

  void scaleBudget(String id, double newBudget) {
    state.whenData((campaigns) {
      state = AsyncValue.data(campaigns.map((c) {
        if (c.id == id) return c.copyWith(dailyBudget: newBudget);
        return c;
      }).toList());
    });
  }
}

// ═══════════════════════════════════════════════════════════
// LEADS / CRM
// ═══════════════════════════════════════════════════════════
final leadsProvider = StateNotifierProvider<LeadsNotifier, AsyncValue<List<Lead>>>((ref) {
  return LeadsNotifier();
});

class LeadsNotifier extends StateNotifier<AsyncValue<List<Lead>>> {
  LeadsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    try {
      await Future.delayed(const Duration(milliseconds: 600));
      state = AsyncValue.data(MockData.leads);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void updateStage(String id, String stage) {
    state.whenData((leads) {
      state = AsyncValue.data(leads.map((l) {
        if (l.id == id) return l.copyWith(stage: stage);
        return l;
      }).toList());
    });
  }

  void addLead(Lead lead) {
    state.whenData((leads) {
      state = AsyncValue.data([lead, ...leads]);
    });
  }
}

// ═══════════════════════════════════════════════════════════
// AUTOMATION RULES
// ═══════════════════════════════════════════════════════════
final rulesProvider = StateNotifierProvider<RulesNotifier, List<AutoRule>>((ref) {
  return RulesNotifier();
});

class AutoRule {
  final String id;
  final String name;
  final String condition;
  final String action;
  final String metric;
  final String operator;
  final double threshold;
  final String actionType;
  final double? actionValue;
  final bool enabled;
  final int triggeredCount;
  final DateTime? lastTriggered;
  final String? appliedTo; // 'all', campaign id, etc.
  final Duration checkInterval;

  const AutoRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.action,
    this.metric = 'roas',
    this.operator = '<',
    this.threshold = 2.0,
    this.actionType = 'pause',
    this.actionValue,
    this.enabled = true,
    this.triggeredCount = 0,
    this.lastTriggered,
    this.appliedTo = 'all',
    this.checkInterval = const Duration(hours: 6),
  });

  AutoRule copyWith({bool? enabled, int? triggeredCount, DateTime? lastTriggered}) {
    return AutoRule(
      id: id, name: name, condition: condition, action: action,
      metric: metric, operator: operator, threshold: threshold,
      actionType: actionType, actionValue: actionValue,
      enabled: enabled ?? this.enabled,
      triggeredCount: triggeredCount ?? this.triggeredCount,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      appliedTo: appliedTo, checkInterval: checkInterval,
    );
  }
}

class RulesNotifier extends StateNotifier<List<AutoRule>> {
  RulesNotifier() : super(_defaultRules);

  static final _defaultRules = [
    AutoRule(
      id: 'r001', name: 'Kill Low ROAS',
      condition: 'ROAS < 2.0x for 3 days',
      action: 'Pause campaign automatically',
      metric: 'roas', operator: '<', threshold: 2.0,
      actionType: 'pause',
      enabled: true, triggeredCount: 3,
      lastTriggered: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AutoRule(
      id: 'r002', name: 'Scale Winners',
      condition: 'ROAS > 4.0x for 5 days',
      action: 'Increase budget by 20%',
      metric: 'roas', operator: '>', threshold: 4.0,
      actionType: 'scale_budget', actionValue: 20,
      enabled: true, triggeredCount: 7,
      lastTriggered: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    AutoRule(
      id: 'r003', name: 'CPA Guardian',
      condition: 'CPA > ₹250 for 2 days',
      action: 'Reduce budget by 30%',
      metric: 'cpa', operator: '>', threshold: 250,
      actionType: 'reduce_budget', actionValue: 30,
      enabled: true, triggeredCount: 1,
      lastTriggered: DateTime.now().subtract(const Duration(days: 5)),
    ),
    AutoRule(
      id: 'r004', name: 'Frequency Cap Alert',
      condition: 'Frequency > 3.5',
      action: 'Send alert + pause campaign',
      metric: 'frequency', operator: '>', threshold: 3.5,
      actionType: 'alert_and_pause',
      enabled: true, triggeredCount: 2,
      lastTriggered: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AutoRule(
      id: 'r005', name: 'CTR Drop Alert',
      condition: 'CTR < 1.5% for 3 days',
      action: 'Notify — creative fatigue likely',
      metric: 'ctr', operator: '<', threshold: 1.5,
      actionType: 'alert',
      enabled: false, triggeredCount: 0,
    ),
    AutoRule(
      id: 'r006', name: 'Budget Utilization',
      condition: 'Spend < 70% of daily budget',
      action: 'Alert — low delivery',
      metric: 'budget_util', operator: '<', threshold: 70,
      actionType: 'alert',
      enabled: true, triggeredCount: 4,
      lastTriggered: DateTime.now().subtract(const Duration(hours: 12)),
    ),
  ];

  void toggle(String id) {
    state = state.map((r) {
      if (r.id == id) return r.copyWith(enabled: !r.enabled);
      return r;
    }).toList();
  }

  void addRule(AutoRule rule) {
    state = [rule, ...state];
  }

  void deleteRule(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void trigger(String id) {
    state = state.map((r) {
      if (r.id == id) return r.copyWith(triggeredCount: r.triggeredCount + 1, lastTriggered: DateTime.now());
      return r;
    }).toList();
  }
}

// ═══════════════════════════════════════════════════════════
// SETTINGS
// ═══════════════════════════════════════════════════════════
final settingsProvider = StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class AppSettings {
  final bool pushNotifications;
  final bool budgetAlerts;
  final bool dailyReport;
  final bool autoScale;
  final bool autoKill;
  final double roasThreshold;
  final double cpaThreshold;
  final String currency;
  final String dateFormat;
  final String refreshInterval;

  const AppSettings({
    this.pushNotifications = true,
    this.budgetAlerts = true,
    this.dailyReport = true,
    this.autoScale = true,
    this.autoKill = true,
    this.roasThreshold = 2.0,
    this.cpaThreshold = 250,
    this.currency = '₹',
    this.dateFormat = 'dd MMM yyyy',
    this.refreshInterval = '15 min',
  });

  AppSettings copyWith({
    bool? pushNotifications, bool? budgetAlerts, bool? dailyReport,
    bool? autoScale, bool? autoKill, double? roasThreshold, double? cpaThreshold,
    String? currency, String? dateFormat, String? refreshInterval,
  }) {
    return AppSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      dailyReport: dailyReport ?? this.dailyReport,
      autoScale: autoScale ?? this.autoScale,
      autoKill: autoKill ?? this.autoKill,
      roasThreshold: roasThreshold ?? this.roasThreshold,
      cpaThreshold: cpaThreshold ?? this.cpaThreshold,
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }
}

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void update(AppSettings Function(AppSettings) updater) {
    state = updater(state);
  }
}

// ═══════════════════════════════════════════════════════════
// DATE PRESET
// ═══════════════════════════════════════════════════════════
final datePresetProvider = StateProvider<String>((ref) => 'last_30d');

// ═══════════════════════════════════════════════════════════
// ACTIVITY LOG
// ═══════════════════════════════════════════════════════════
final activityLogProvider = StateNotifierProvider<ActivityLogNotifier, List<ActivityEntry>>((ref) {
  return ActivityLogNotifier();
});

class ActivityEntry {
  final String id;
  final String type; // 'rule_triggered', 'campaign_paused', 'budget_scaled', 'alert'
  final String title;
  final String description;
  final DateTime timestamp;
  final String? campaignId;
  final String? ruleId;

  const ActivityEntry({
    required this.id, required this.type, required this.title,
    required this.description, required this.timestamp,
    this.campaignId, this.ruleId,
  });
}

class ActivityLogNotifier extends StateNotifier<List<ActivityEntry>> {
  ActivityLogNotifier() : super(_defaultLogs);

  static final _defaultLogs = [
    ActivityEntry(id: 'a001', type: 'rule_triggered', title: 'Scale Winners triggered', description: 'Navratri Sale budget increased 20% → ₹4,200/day', timestamp: DateTime.now().subtract(const Duration(hours: 6)), campaignId: 'c001', ruleId: 'r002'),
    ActivityEntry(id: 'a002', type: 'budget_scaled', title: 'Budget auto-scaled', description: 'Temple Jewellery ₹2,000 → ₹2,400/day (ROAS 4.5x)', timestamp: DateTime.now().subtract(const Duration(hours: 12)), campaignId: 'c005', ruleId: 'r002'),
    ActivityEntry(id: 'a003', type: 'alert', title: 'Frequency alert', description: 'Reels Gold Plated Set frequency 3.8x — creative fatigue', timestamp: DateTime.now().subtract(const Duration(days: 1)), campaignId: 'c002', ruleId: 'r004'),
    ActivityEntry(id: 'a004', type: 'campaign_paused', title: 'Auto-paused campaign', description: 'Test Campaign ROAS 1.2x for 3 days — paused by Kill Low ROAS rule', timestamp: DateTime.now().subtract(const Duration(days: 2)), ruleId: 'r001'),
    ActivityEntry(id: 'a005', type: 'rule_triggered', title: 'CPA Guardian triggered', description: 'Lookalike campaign CPA ₹280 — budget reduced 30%', timestamp: DateTime.now().subtract(const Duration(days: 3)), campaignId: 'c003', ruleId: 'r003'),
    ActivityEntry(id: 'a006', type: 'alert', title: 'Low delivery alert', description: 'WhatsApp Catalog spent only 55% of daily budget', timestamp: DateTime.now().subtract(const Duration(days: 3)), campaignId: 'c008', ruleId: 'r006'),
  ];

  void add(ActivityEntry entry) {
    state = [entry, ...state];
  }
}