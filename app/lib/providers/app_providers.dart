import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/env_config.dart';
import '../models/app_settings.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import '../models/lead.dart';
import '../models/rule.dart';
import '../services/meta_auth.dart';
import '../services/notification_service.dart';
import '../services/worker_api.dart';

// ══════════════════════════════════════════════════════════════
// SERVICE PROVIDERS
// ══════════════════════════════════════════════════════════════

final notificationProvider =
    Provider<NotificationService>((ref) => NotificationService());

final workerApiProvider = Provider<WorkerApiService>((ref) {
  return WorkerApiService();
});

final metaAuthProvider = Provider<MetaAuth>((ref) => MetaAuth());

// ══════════════════════════════════════════════════════════════
// DATE PRESET (global shared state)
// ══════════════════════════════════════════════════════════════

final datePresetProvider = StateProvider<String>((ref) => 'last_30d');

// ══════════════════════════════════════════════════════════════
// DASHBOARD / ANALYTICS PROVIDERS (Worker-first)
// ══════════════════════════════════════════════════════════════

final dashboardSummaryProvider =
    FutureProvider.family<InsightsSummary, String>((ref, datePreset) async {
  final api = ref.watch(workerApiProvider);
  return api.getAnalyticsSummary(datePreset: datePreset);
});

final dashboardDailyProvider =
    FutureProvider.family<List<DayInsight>, String>((ref, datePreset) async {
  final api = ref.watch(workerApiProvider);
  return api.getAnalyticsDaily(datePreset: datePreset);
});

bool _isReadFlag(dynamic v) {
  // Worker/D1 typically returns 0/1 (int), sometimes bool.
  if (v == null) return false;
  if (v is bool) return v;
  if (v is num) return v.toInt() == 1;
  final s = v.toString().trim().toLowerCase();
  return s == '1' || s == 'true' || s == 'yes';
}

final notificationsCountProvider = FutureProvider<int>((ref) async {
  final api = ref.watch(workerApiProvider);
  final notifications = await api.getNotifications(limit: 50);
  return notifications.where((n) => !_isReadFlag(n['read'])).length;
});

final crmStatsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(workerApiProvider);
  return api.getCrmStats();
});

// ══════════════════════════════════════════════════════════════
// CAMPAIGNS (Worker-first)
// ══════════════════════════════════════════════════════════════

final campaignsProvider =
    StateNotifierProvider<CampaignsNotifier, AsyncValue<List<Campaign>>>((ref) {
  final api = ref.watch(workerApiProvider);
  final datePreset = ref.watch(datePresetProvider);
  return CampaignsNotifier(api, datePreset);
});

class CampaignsNotifier extends StateNotifier<AsyncValue<List<Campaign>>> {
  final WorkerApiService _api;
  final String _datePreset;

  CampaignsNotifier(this._api, this._datePreset)
      : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final campaigns = await _api.getCampaigns(datePreset: _datePreset);
      state = AsyncValue.data(campaigns);
    } catch (e, st) {
      final configured = await _api.isConfigured();
      if (!configured) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh() async {
    try {
      final campaigns = await _api.getCampaigns(datePreset: _datePreset);
      state = AsyncValue.data(campaigns);
    } catch (e, st) {
      final configured = await _api.isConfigured();
      if (!configured) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> toggleStatus(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final campaign = current.cast<Campaign?>().firstWhere(
          (c) => c?.id == id,
          orElse: () => null,
        );
    if (campaign == null) return;

    final newStatus = campaign.isActive ? 'PAUSED' : 'ACTIVE';

    final optimistic = current.map((c) {
      if (c.id == id) return c.copyWith(status: newStatus);
      return c;
    }).toList();

    state = AsyncValue.data(optimistic);

    try {
      await _api.updateCampaignStatus(id, newStatus);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }

  Future<void> scaleBudget(String id, double budget) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final optimistic = current.map((c) {
      if (c.id == id) return c.copyWith(dailyBudget: budget);
      return c;
    }).toList();

    state = AsyncValue.data(optimistic);

    try {
      await _api.updateCampaignBudget(id, dailyBudget: budget);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// LEADS (Worker-first)
// ══════════════════════════════════════════════════════════════

final leadsProvider =
    StateNotifierProvider<LeadsNotifier, AsyncValue<List<Lead>>>((ref) {
  final api = ref.watch(workerApiProvider);
  return LeadsNotifier(api);
});

class LeadsNotifier extends StateNotifier<AsyncValue<List<Lead>>> {
  final WorkerApiService _api;

  // keep for offline fallback later
  // ignore: unused_field
  List<Lead> _lastGoodData = const [];

  LeadsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({
    String? stage,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    state = const AsyncValue.loading();
    try {
      final leads = await _api.getLeads(
        stage: stage,
        search: search,
        limit: limit,
        offset: offset,
      );
      _lastGoodData = leads;
      state = AsyncValue.data(leads);
    } catch (e, st) {
      final configured = await _api.isConfigured();
      if (!configured) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh({
    String? stage,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final leads = await _api.getLeads(
        stage: stage,
        search: search,
        limit: limit,
        offset: offset,
      );
      _lastGoodData = leads;
      state = AsyncValue.data(leads);
    } catch (e, st) {
      final configured = await _api.isConfigured();
      if (!configured) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> updateStage(String id, String stage) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final optimistic = current.map((l) {
      if (l.id == id) {
        return l.copyWith(stage: stage);
      }
      return l;
    }).toList();

    _lastGoodData = optimistic;
    state = AsyncValue.data(optimistic);

    try {
      await _api.updateLead(
        id,
        stage: stage,
        activityNote: 'Stage updated to $stage',
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }

  Future<void> addLead(Lead lead) async {
    try {
      await _api.createLead(
        name: lead.name,
        phone: lead.phone,
        email: lead.email,
        campaign: lead.campaign,
        campaignId: lead.campaignId,
        stage: lead.stage,
        source: lead.source,
        product: lead.product,
        value: lead.value ?? 0,
        notes: lead.notes,
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteLead(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final optimistic = current.where((l) => l.id != id).toList();
    _lastGoodData = optimistic;
    state = AsyncValue.data(optimistic);

    try {
      await _api.deleteLead(id);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }
}

// ══════════════════════════════════════════════════════════════
// RULES (Worker-first)
// ══════════════════════════════════════════════════════════════

final rulesProvider =
    StateNotifierProvider<RulesNotifier, AsyncValue<List<AutoRule>>>((ref) {
  final api = ref.watch(workerApiProvider);
  return RulesNotifier(api);
});

class RulesNotifier extends StateNotifier<AsyncValue<List<AutoRule>>> {
  final WorkerApiService _api;

  RulesNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load() async {
    try {
      state = const AsyncValue.loading();
      final rules = await _api.getRules();
      state = AsyncValue.data(rules);
    } catch (e, st) {
      final configured = await _api.isConfigured();
      if (!configured) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> refresh() async {
    try {
      final rules = await _api.getRules();
      state = AsyncValue.data(rules);
    } catch (e, st) {
      final configured = await _api.isConfigured();
      if (!configured) {
        state = const AsyncValue.data([]);
      } else {
        state = AsyncValue.error(e, st);
      }
    }
  }

  Future<void> toggle(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final rule = current.cast<AutoRule?>().firstWhere(
          (r) => r?.id == id,
          orElse: () => null,
        );
    if (rule == null) return;

    final newEnabled = !rule.enabled;

    final optimistic = current.map((r) {
      if (r.id == id) return r.copyWith(enabled: newEnabled);
      return r;
    }).toList();

    state = AsyncValue.data(optimistic);

    try {
      await _api.toggleRule(id, newEnabled);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }

  Future<void> addRule(AutoRule rule) async {
    try {
      await _api.createRule(
        name: rule.name,
        metric: rule.metric,
        operator: rule.operator,
        threshold: rule.threshold,
        actionType: rule.actionType,
        actionValue:
            rule.actionValue == null ? null : double.tryParse(rule.actionValue!),
        conditionText: rule.condition,
        actionText: rule.action,
        enabled: rule.enabled,
        checkInterval: int.parse((rule.checkInterval ?? 360).toString()),
      );
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> deleteRule(String id) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final optimistic = current.where((r) => r.id != id).toList();
    state = AsyncValue.data(optimistic);

    try {
      await _api.deleteRule(id);
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }

  Future<void> trigger(String id) async {
    await refresh();
  }
}

// ══════════════════════════════════════════════════════════════
// NOTIFICATIONS (Worker-first)
// ══════════════════════════════════════════════════════════════

final notificationsProvider = StateNotifierProvider<
    NotificationsNotifier, AsyncValue<List<Map<String, dynamic>>>>((ref) {
  final api = ref.watch(workerApiProvider);
  return NotificationsNotifier(api);
});

class NotificationsNotifier
    extends StateNotifier<AsyncValue<List<Map<String, dynamic>>>> {
  final WorkerApiService _api;

  NotificationsNotifier(this._api) : super(const AsyncValue.loading()) {
    load();
  }

  Future<void> load({int limit = 50}) async {
    try {
      state = const AsyncValue.loading();
      final items = await _api.getNotifications(limit: limit);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> refresh({int limit = 50}) async {
    try {
      final items = await _api.getNotifications(limit: limit);
      state = AsyncValue.data(items);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> markAllRead() async {
    final current = state.valueOrNull ?? const <Map<String, dynamic>>[];

    final optimistic = current.map((n) {
      return {
        ...n,
        'read': 1,
      };
    }).toList();

    state = AsyncValue.data(optimistic);

    try {
      await _api.markNotificationsRead();
      await refresh();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      await load();
    }
  }

  void markLocalRead(String id) {
    final current = state.valueOrNull ?? const <Map<String, dynamic>>[];

    final updated = current.map((n) {
      if (n['id']?.toString() == id) {
        return {
          ...n,
          'read': 1,
        };
      }
      return n;
    }).toList();

    state = AsyncValue.data(updated);
  }
}

// ══════════════════════════════════════════════════════════════
// SETTINGS (Local)
// ══════════════════════════════════════════════════════════════

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  return SettingsNotifier();
});

class SettingsNotifier extends StateNotifier<AppSettings> {
  SettingsNotifier() : super(const AppSettings());

  void update(AppSettings Function(AppSettings) updater) {
    state = updater(state);
  }

  void reset() {
    state = const AppSettings();
  }
}

// ══════════════════════════════════════════════════════════════
// ACTIVITY LOG
// NOTE: still local until Worker exposes /api/activity_log route
// ══════════════════════════════════════════════════════════════

final activityLogProvider =
    StateNotifierProvider<ActivityLogNotifier, AsyncValue<List<ActivityEntry>>>(
        (ref) {
  return ActivityLogNotifier();
});

class ActivityLogNotifier
    extends StateNotifier<AsyncValue<List<ActivityEntry>>> {
  ActivityLogNotifier() : super(const AsyncValue.data([]));

  void add(ActivityEntry entry) {
    final current = state.valueOrNull ?? [];
    state = AsyncValue.data([entry, ...current]);
  }

  void clear() {
    state = const AsyncValue.data([]);
  }
}

// ══════════════════════════════════════════════════════════════
// DETAIL PROVIDERS
// ══════════════════════════════════════════════════════════════

final campaignDetailProvider =
    FutureProvider.family<Campaign, String>((ref, id) async {
  final api = ref.watch(workerApiProvider);
  final datePreset = ref.watch(datePresetProvider);
  return api.getCampaign(id, datePreset: datePreset);
});

final leadDetailProvider = FutureProvider.family<Lead, String>((ref, id) async {
  final api = ref.watch(workerApiProvider);
  return api.getLead(id);
});

// ══════════════════════════════════════════════════════════════
// CONNECTION STATUS (Worker-first)
// ══════════════════════════════════════════════════════════════

final connectionStatusProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final auth = ref.watch(metaAuthProvider);

  final apiKey = await auth.getApiKey();
  final sessionToken = await auth.getSessionToken();

  // legacy/direct meta fields (still displayed for now)
  final accountId = await auth.getAccountId();
  final pixelId = await auth.getPixelId();
  final hasMetaAuth = await auth.hasValidConfig();

  bool workerOnline = false;
  final dio = Dio();

  try {
    final response = await dio.get(
      EnvConfig.healthUrl,
      options: Options(
        validateStatus: (status) => status != null && status < 500,
        receiveTimeout: const Duration(seconds: 5),
        sendTimeout: const Duration(seconds: 5),
      ),
    );

    final status = response.statusCode ?? 0;
    workerOnline = status >= 200 && status < 300;
  } catch (_) {
    workerOnline = false;
  } finally {
    dio.close(force: true);
  }

  final hasApiKey = apiKey != null && apiKey.trim().isNotEmpty;
  final hasSessionToken = sessionToken != null && sessionToken.trim().isNotEmpty;

  final workerReady = workerOnline && (hasApiKey || hasSessionToken);

  // connected is true if worker is ready OR (legacy) direct meta config exists
  final connected = workerReady || hasMetaAuth;

  final mode = workerReady
      ? 'worker'
      : hasMetaAuth
          ? 'direct_meta'
          : 'none';

  return {
    'hasApiKey': hasApiKey,
    'hasSessionToken': hasSessionToken,
    'hasMetaAuth': hasMetaAuth,
    'accountId': accountId,
    'pixelId': pixelId,
    'workerOnline': workerOnline,
    'workerReady': workerReady,
    'mode': mode,
    'connected': connected,
  };
});