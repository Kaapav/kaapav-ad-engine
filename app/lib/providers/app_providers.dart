import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/meta_api.dart';
import '../services/notification_service.dart';
import '../models/campaign.dart';
import '../models/lead.dart';
import '../models/app_settings.dart';
import '../models/rule.dart';
import '../data/mock_data.dart';
import '../services/worker_api.dart';

// ═══ SERVICE PROVIDERS ═══
final metaApiProvider = Provider<MetaApiService>((ref) => MetaApiService());
final notificationProvider =
    Provider<NotificationService>((ref) => NotificationService());

// ═══ DATE PRESET ═══
final datePresetProvider = StateProvider<String>((ref) => 'last_30d');

// ═══ CAMPAIGNS ═══
final campaignsProvider =
    StateNotifierProvider<CampaignsNotifier, AsyncValue<List<Campaign>>>(
        (ref) {
  final api = ref.watch(metaApiProvider);
  return CampaignsNotifier(api);
});

final workerApiProvider = Provider<WorkerApiService>((ref) {
  return WorkerApiService();
});

class CampaignsNotifier extends StateNotifier<AsyncValue<List<Campaign>>> {
  final MetaApiService _api; // ignore: unused_field

  CampaignsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 500));
    state = AsyncValue.data(MockData.campaigns);
  }

  Future<void> refresh() async {
    await Future.delayed(const Duration(seconds: 1));
    state = AsyncValue.data(MockData.campaigns);
  }

  void toggleStatus(String id) {
    state.whenData((campaigns) {
      final updated = campaigns.map((c) {
        if (c.id == id) {
          final newStatus = c.isActive ? 'PAUSED' : 'ACTIVE';
          return c.copyWith(status: newStatus);
        }
        return c;
      }).toList();
      state = AsyncValue.data(updated);
    });
  }

  void scaleBudget(String id, double budget) {
    state.whenData((campaigns) {
      final updated = campaigns.map((c) {
        if (c.id == id) return c.copyWith(dailyBudget: budget);
        return c;
      }).toList();
      state = AsyncValue.data(updated);
    });
  }
}

// ═══ LEADS ═══
final leadsProvider =
    StateNotifierProvider<LeadsNotifier, AsyncValue<List<Lead>>>((ref) {
  return LeadsNotifier();
});

class LeadsNotifier extends StateNotifier<AsyncValue<List<Lead>>> {
  LeadsNotifier() : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    state = const AsyncValue.loading();
    await Future.delayed(const Duration(milliseconds: 500));
    state = AsyncValue.data(MockData.leads);
  }

  void updateStage(String id, String stage) {
    state.whenData((leads) {
      final updated = leads.map((l) {
        if (l.id == id) return l.copyWith(stage: stage);
        return l;
      }).toList();
      state = AsyncValue.data(updated);
    });
  }

  void addLead(Lead lead) {
    state.whenData((leads) {
      state = AsyncValue.data([lead, ...leads]);
    });
  }
}

// ═══ RULES ═══
final rulesProvider =
    StateNotifierProvider<RulesNotifier, List<AutoRule>>((ref) {
  return RulesNotifier();
});

class RulesNotifier extends StateNotifier<List<AutoRule>> {
  RulesNotifier() : super(_defaultRules);

  static final _defaultRules = [
    AutoRule(
      id: 'r001',
      name: 'Kill Low ROAS',
      condition: 'ROAS < 2.0',
      action: 'Pause Campaign',
      metric: 'roas',
      operator: '<',
      threshold: 2.0,
      actionType: 'pause',
      enabled: true,
      triggeredCount: 3,
      lastTriggered: DateTime.now().subtract(const Duration(days: 2)),
    ),
    AutoRule(
      id: 'r002',
      name: 'Scale Winners',
      condition: 'ROAS > 4.0',
      action: 'Scale Budget +20%',
      metric: 'roas',
      operator: '>',
      threshold: 4.0,
      actionType: 'scale_budget',
      actionValue: '20',
      enabled: true,
      triggeredCount: 7,
      lastTriggered: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    AutoRule(
      id: 'r003',
      name: 'CPA Guardian',
      condition: 'CPA > 250',
      action: 'Reduce Budget -30%',
      metric: 'cpa',
      operator: '>',
      threshold: 250,
      actionType: 'reduce_budget',
      actionValue: '30',
      enabled: true,
      triggeredCount: 1,
      lastTriggered: DateTime.now().subtract(const Duration(days: 3)),
    ),
    AutoRule(
      id: 'r004',
      name: 'Frequency Cap Alert',
      condition: 'Frequency > 3.5',
      action: 'Alert & Pause',
      metric: 'frequency',
      operator: '>',
      threshold: 3.5,
      actionType: 'alert_and_pause',
      enabled: true,
      triggeredCount: 2,
      lastTriggered: DateTime.now().subtract(const Duration(days: 1)),
    ),
    AutoRule(
      id: 'r005',
      name: 'CTR Drop Alert',
      condition: 'CTR < 1.5',
      action: 'Send Alert',
      metric: 'ctr',
      operator: '<',
      threshold: 1.5,
      actionType: 'alert',
      enabled: false,
      triggeredCount: 0,
    ),
    AutoRule(
      id: 'r006',
      name: 'Budget Utilization',
      condition: 'Budget Util < 70',
      action: 'Send Alert',
      metric: 'budget_util',
      operator: '<',
      threshold: 70,
      actionType: 'alert',
      enabled: true,
      triggeredCount: 4,
      lastTriggered: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  void toggle(String id) {
    state = state.map((r) {
      if (r.id == id) return r.copyWith(enabled: !r.enabled);
      return r;
    }).toList();
  }

  void addRule(AutoRule rule) {
    state = [...state, rule];
  }

  void deleteRule(String id) {
    state = state.where((r) => r.id != id).toList();
  }

  void trigger(String id) {
    state = state.map((r) {
      if (r.id == id) {
        return r.copyWith(
          triggeredCount: r.triggeredCount + 1,
          lastTriggered: DateTime.now(),
        );
      }
      return r;
    }).toList();
  }
}

// ═══ SETTINGS ═══
final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void update(AppSettings Function(AppSettings) updater) {
    state = updater(state);
  }
}

// ═══ ACTIVITY LOG ═══
final activityLogProvider =
    StateNotifierProvider<ActivityLogNotifier, List<ActivityEntry>>((ref) {
  return ActivityLogNotifier();
});

class ActivityLogNotifier extends StateNotifier<List<ActivityEntry>> {
  ActivityLogNotifier() : super(_defaultLogs);

  static final _defaultLogs = [
    ActivityEntry(
      id: 'a001',
      type: 'scale',
      title: 'Scale Winners triggered',
      description:
          'Navratri Jewellery Sale ROAS 6.2x → Budget +20% to ₹4,200/day',
      timestamp: DateTime.now().subtract(const Duration(hours: 6)),
      campaignId: 'c001',
      ruleId: 'r002',
    ),
    ActivityEntry(
      id: 'a002',
      type: 'budget',
      title: 'Budget auto-scaled',
      description:
          'Temple Jewellery Collection budget ₹2,000 → ₹2,400/day',
      timestamp: DateTime.now().subtract(const Duration(hours: 12)),
      campaignId: 'c005',
    ),
    ActivityEntry(
      id: 'a003',
      type: 'alert',
      title: 'Frequency alert triggered',
      description:
          'Reels Gold Plated Set frequency reached 3.8x — exceeds 3.5x cap',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      campaignId: 'c002',
      ruleId: 'r004',
    ),
    ActivityEntry(
      id: 'a004',
      type: 'pause',
      title: 'Campaign auto-paused',
      description:
          'Test Campaign paused — ROAS dropped to 1.2x (below 2.0x threshold)',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      ruleId: 'r001',
    ),
    ActivityEntry(
      id: 'a005',
      type: 'reduce',
      title: 'CPA Guardian triggered',
      description:
          'Lookalike 1% Buyers CPA ₹310 → Budget reduced by 30%',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      campaignId: 'c003',
      ruleId: 'r003',
    ),
    ActivityEntry(
      id: 'a006',
      type: 'alert',
      title: 'Low delivery alert',
      description:
          'WhatsApp Catalog Push only 55% budget utilization today',
      timestamp: DateTime.now().subtract(const Duration(days: 3)),
      campaignId: 'c008',
      ruleId: 'r006',
    ),
  ];

  void add(ActivityEntry entry) {
    state = [entry, ...state];
  }
}