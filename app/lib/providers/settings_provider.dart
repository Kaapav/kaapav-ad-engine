import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/app_settings.dart';
import '../services/local_storage.dart';
import '../services/worker_api.dart';
import 'app_providers.dart';

class SettingsNotifier extends StateNotifier<AppSettings> {
  // ignore: unused_field
  final WorkerApiService _api;

  SettingsNotifier(this._api)
      : super(const AppSettings()) {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      state = state.copyWith(
        pushNotifications:
            LocalStorageService.getSetting<bool>('pushNotifications') ?? true,
        budgetAlerts:
            LocalStorageService.getSetting<bool>('budgetAlerts') ?? true,
        dailyReport:
            LocalStorageService.getSetting<bool>('dailyReport') ?? true,
        autoScale:
            LocalStorageService.getSetting<bool>('autoScale') ?? false,
        autoKill:
            LocalStorageService.getSetting<bool>('autoKill') ?? true,
        roasThreshold:
            LocalStorageService.getSetting<double>('roasThreshold') ?? 2.0,
        cpaThreshold:
            LocalStorageService.getSetting<double>('cpaThreshold') ?? 250.0,
        currency:
            LocalStorageService.getSetting<String>('currency') ?? '₹',
        dateFormat:
            LocalStorageService.getSetting<String>('dateFormat') ?? 'dd MMM yyyy',
refreshInterval:
    LocalStorageService.getSetting<String>('refreshInterval') ?? '300',
      );
    } catch (e) {
      debugPrint('Failed to load settings: $e');
    }
  }

  Future<void> update(AppSettings Function(AppSettings) updater) async {
    final newSettings = updater(state);
    state = newSettings;

    try {
      await LocalStorageService.saveSetting(
        'pushNotifications',
        newSettings.pushNotifications,
      );
      await LocalStorageService.saveSetting(
        'budgetAlerts',
        newSettings.budgetAlerts,
      );
      await LocalStorageService.saveSetting(
        'dailyReport',
        newSettings.dailyReport,
      );
      await LocalStorageService.saveSetting(
        'autoScale',
        newSettings.autoScale,
      );
      await LocalStorageService.saveSetting(
        'autoKill',
        newSettings.autoKill,
      );
      await LocalStorageService.saveSetting(
        'roasThreshold',
        newSettings.roasThreshold,
      );
      await LocalStorageService.saveSetting(
        'cpaThreshold',
        newSettings.cpaThreshold,
      );
      await LocalStorageService.saveSetting(
        'currency',
        newSettings.currency,
      );
      await LocalStorageService.saveSetting(
        'dateFormat',
        newSettings.dateFormat,
      );
      await LocalStorageService.saveSetting(
        'refreshInterval',
        newSettings.refreshInterval,
      );
    } catch (e) {
      debugPrint('Failed to save settings: $e');
    }
  }

  Future<void> togglePushNotifications() async {
    await update((s) => s.copyWith(pushNotifications: !s.pushNotifications));
  }

  Future<void> toggleBudgetAlerts() async {
    await update((s) => s.copyWith(budgetAlerts: !s.budgetAlerts));
  }

  Future<void> toggleDailyReport() async {
    await update((s) => s.copyWith(dailyReport: !s.dailyReport));
  }

  Future<void> toggleAutoScale() async {
    await update((s) => s.copyWith(autoScale: !s.autoScale));
  }

  Future<void> toggleAutoKill() async {
    await update((s) => s.copyWith(autoKill: !s.autoKill));
  }

  Future<void> setRoasThreshold(double value) async {
    await update((s) => s.copyWith(roasThreshold: value));
  }

  Future<void> setCpaThreshold(double value) async {
    await update((s) => s.copyWith(cpaThreshold: value));
  }

  Future<void> reset() async {
    state = const AppSettings();
    await LocalStorageService.clearCache();
  }
}

final settingsProvider =
    StateNotifierProvider<SettingsNotifier, AppSettings>((ref) {
  final api = ref.watch(workerApiProvider);
  return SettingsNotifier(api);
});