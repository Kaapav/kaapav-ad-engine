// lib/providers/dashboard_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import '../services/worker_api.dart';
import 'app_providers.dart';

/// Dashboard state
class DashboardState {
  final InsightsSummary? summary;
  final List<Campaign> topCampaigns;
  final Map<String, dynamic>? crmStats;
  final bool loading;
  final String? error;
  final DateTime? lastRefresh;

  DashboardState({
    this.summary,
    this.topCampaigns = const [],
    this.crmStats,
    this.loading = false,
    this.error,
    this.lastRefresh,
  });

  DashboardState copyWith({
    InsightsSummary? summary,
    List<Campaign>? topCampaigns,
    Map<String, dynamic>? crmStats,
    bool? loading,
    String? error,
    DateTime? lastRefresh,
  }) {
    return DashboardState(
      summary: summary ?? this.summary,
      topCampaigns: topCampaigns ?? this.topCampaigns,
      crmStats: crmStats ?? this.crmStats,
      loading: loading ?? this.loading,
      error: error,
      lastRefresh: lastRefresh ?? this.lastRefresh,
    );
  }
}

/// Dashboard Provider
class DashboardNotifier extends StateNotifier<DashboardState> {
  final WorkerApiService _api;
  // ignore: unused_field
  final Ref _ref;

  DashboardNotifier(this._api, this._ref) : super(DashboardState()) {
    loadDashboard();
  }

  /// Load all dashboard data
  Future<void> loadDashboard({String datePreset = 'last_30d'}) async {
    state = state.copyWith(loading: true, error: null);

    try {
      // Fetch all data in parallel
      final results = await Future.wait([
        _api.getAnalyticsSummary(datePreset: datePreset),
        _api.getCampaigns(datePreset: datePreset, limit: 10),
        _api.getCrmStats(),
      ]);

      final summary = results[0] as InsightsSummary;
      final campaigns = results[1] as List<Campaign>;
      final crmStats = results[2] as Map<String, dynamic>;

      // Sort campaigns by ROAS descending, take top 5
      final topCampaigns = [...campaigns]
        ..sort((a, b) => b.roas.compareTo(a.roas));

      state = state.copyWith(
        summary: summary,
        topCampaigns: topCampaigns.take(5).toList(),
        crmStats: crmStats,
        loading: false,
        lastRefresh: DateTime.now(),
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Refresh dashboard
  Future<void> refresh({String datePreset = 'last_30d'}) async {
    return loadDashboard(datePreset: datePreset);
  }

  /// Quick metric getters
  double get totalSpend => state.summary?.totalSpend ?? 0;
  double get totalRevenue => state.summary?.totalRevenue ?? 0;
  double get avgRoas => state.summary?.avgRoas ?? 0;
  int get activeCampaigns => state.topCampaigns.where((c) => c.isActive).length;
  int get totalLeads => state.crmStats?['total_leads'] ?? 0;
  double get pipelineValue => (state.crmStats?['total_value'] ?? 0).toDouble();
}

/// Provider
final dashboardProvider =
    StateNotifierProvider<DashboardNotifier, DashboardState>((ref) {
  final api = ref.watch(workerApiProvider);
  return DashboardNotifier(api, ref);
});