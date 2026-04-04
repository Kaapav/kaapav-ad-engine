// lib/providers/sheets_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/worker_api.dart';
import 'app_providers.dart';

/// Sheets sync state
class SheetsState {
  final bool syncing;
  final String? error;
  final DateTime? lastSync;
  final String? lastSyncType;

  SheetsState({
    this.syncing = false,
    this.error,
    this.lastSync,
    this.lastSyncType,
  });

  SheetsState copyWith({
    bool? syncing,
    String? error,
    DateTime? lastSync,
    String? lastSyncType,
  }) {
    return SheetsState(
      syncing: syncing ?? this.syncing,
      error: error,
      lastSync: lastSync ?? this.lastSync,
      lastSyncType: lastSyncType ?? this.lastSyncType,
    );
  }
}

/// Sheets Provider
class SheetsNotifier extends StateNotifier<SheetsState> {
  final WorkerApiService _api;
  // ignore: unused_field
  final Ref _ref;

  SheetsNotifier(this._api, this._ref) : super(SheetsState());

  /// Sync campaigns to Google Sheets
  Future<void> syncCampaigns(String sheetId, {String datePreset = 'last_30d'}) async {
    state = state.copyWith(syncing: true, error: null);

    try {
      await _api.syncCampaignsToSheets(sheetId, datePreset: datePreset);
      state = state.copyWith(
        syncing: false,
        lastSync: DateTime.now(),
        lastSyncType: 'Campaigns',
      );
    } catch (e) {
      state = state.copyWith(
        syncing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Sync leads to Google Sheets
  Future<void> syncLeads(String sheetId) async {
    state = state.copyWith(syncing: true, error: null);

    try {
      await _api.syncLeadsToSheets(sheetId);
      state = state.copyWith(
        syncing: false,
        lastSync: DateTime.now(),
        lastSyncType: 'Leads',
      );
    } catch (e) {
      state = state.copyWith(
        syncing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Sync both campaigns and leads
  Future<void> syncAll(String sheetId, {String datePreset = 'last_30d'}) async {
    state = state.copyWith(syncing: true, error: null);

    try {
      await _api.syncCampaignsToSheets(sheetId, datePreset: datePreset);
      await _api.syncLeadsToSheets(sheetId);
      state = state.copyWith(
        syncing: false,
        lastSync: DateTime.now(),
        lastSyncType: 'All Data',
      );
    } catch (e) {
      state = state.copyWith(
        syncing: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

/// Provider
final sheetsProvider =
    StateNotifierProvider<SheetsNotifier, SheetsState>((ref) {
  final api = ref.watch(workerApiProvider);
  return SheetsNotifier(api, ref);
});