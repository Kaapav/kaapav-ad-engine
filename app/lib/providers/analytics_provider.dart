// lib/providers/analytics_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/insights.dart';
import '../services/worker_api.dart';
import 'app_providers.dart';

/// Analytics data state
class AnalyticsState {
  final InsightsSummary? summary;
  final List<DayInsight> daily;
  final Map<String, dynamic>? crmStats;
  final bool loading;
  final String? error;

  AnalyticsState({
    this.summary,
    this.daily = const [],
    this.crmStats,
    this.loading = false,
    this.error,
  });

  AnalyticsState copyWith({
    InsightsSummary? summary,
    List<DayInsight>? daily,
    Map<String, dynamic>? crmStats,
    bool? loading,
    String? error,
  }) {
    return AnalyticsState(
      summary: summary ?? this.summary,
      daily: daily ?? this.daily,
      crmStats: crmStats ?? this.crmStats,
      loading: loading ?? this.loading,
      error: error,
    );
  }
}

/// Analytics Provider
class AnalyticsNotifier extends StateNotifier<AnalyticsState> {
  final WorkerApiService _api;
  // ignore: unused_field
  final Ref _ref;

  AnalyticsNotifier(this._api, this._ref) : super(AnalyticsState()) {
    loadSummary();
  }

  /// Load analytics summary
  Future<void> loadSummary({String datePreset = 'last_30d'}) async {
    state = state.copyWith(loading: true, error: null);

    try {
      final summary = await _api.getAnalyticsSummary(datePreset: datePreset);
      state = state.copyWith(
        summary: summary,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Load daily breakdown
  Future<void> loadDaily({String datePreset = 'last_30d'}) async {
    state = state.copyWith(loading: true, error: null);

    try {
      final daily = await _api.getAnalyticsDaily(datePreset: datePreset);
      state = state.copyWith(
        daily: daily,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Load CRM stats
  Future<void> loadCrmStats() async {
    try {
      final stats = await _api.getCrmStats();
      state = state.copyWith(crmStats: stats);
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Load all analytics data
  Future<void> loadAll({String datePreset = 'last_30d'}) async {
    state = state.copyWith(loading: true, error: null);

    try {
      final results = await Future.wait([
        _api.getAnalyticsSummary(datePreset: datePreset),
        _api.getAnalyticsDaily(datePreset: datePreset),
        _api.getCrmStats(),
      ]);

      state = state.copyWith(
        summary: results[0] as InsightsSummary,
        daily: results[1] as List<DayInsight>,
        crmStats: results[2] as Map<String, dynamic>,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Refresh all data
  Future<void> refresh({String datePreset = 'last_30d'}) async {
    return loadAll(datePreset: datePreset);
  }
}

/// Provider
final analyticsProvider =
    StateNotifierProvider<AnalyticsNotifier, AnalyticsState>((ref) {
  final api = ref.watch(workerApiProvider);
  return AnalyticsNotifier(api, ref);
});