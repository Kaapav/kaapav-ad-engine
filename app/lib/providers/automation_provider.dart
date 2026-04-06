// lib/providers/automation_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/rule.dart';
import '../services/worker_api.dart';
import 'app_providers.dart';

/// Automation state
class AutomationState {
  final List<AutoRule> rules;
  final bool loading;
  final String? error;

  AutomationState({
    this.rules = const [],
    this.loading = false,
    this.error,
  });

  AutomationState copyWith({
    List<AutoRule>? rules,
    bool? loading,
    String? error,
  }) {
    return AutomationState(
      rules: rules ?? this.rules,
      loading: loading ?? this.loading,
      error: error,
    );
  }

  int get activeCount => rules.where((r) => r.enabled).length;
  int get totalTriggered => rules.fold(0, (sum, r) => sum + r.triggeredCount);
}

/// Automation Provider
class AutomationNotifier extends StateNotifier<AutomationState> {
  final WorkerApiService _api;
  // ignore: unused_field
  final Ref _ref;

  AutomationNotifier(this._api, this._ref) : super(AutomationState()) {
    loadRules();
  }

  /// Load all rules from Worker
  Future<void> loadRules() async {
    state = state.copyWith(loading: true, error: null);

    try {
      final rules = await _api.getRules();
      state = state.copyWith(
        rules: rules,
        loading: false,
      );
    } catch (e) {
      state = state.copyWith(
        loading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  /// Toggle rule on/off
  Future<void> toggleRule(String id) async {
    final rule = state.rules.firstWhere((r) => r.id == id);
    final newEnabled = !rule.enabled;

    // Optimistic update
    state = state.copyWith(
      rules: state.rules.map((r) {
        if (r.id == id) {
          return r.copyWith(enabled: newEnabled);
        }
        return r;
      }).toList(),
    );

    try {
      await _api.toggleRule(id, newEnabled);
      // Reload to get server truth
      await loadRules();
    } catch (e) {
      // Revert on error
      await loadRules();
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Create new rule
  Future<void> createRule({
    required String name,
    required String metric,
    required String operator,
    required double threshold,
    required String actionType,
    double? actionValue,
    bool enabled = true,
  }) async {
    try {
      // Generate condition and action text
      final conditionText = '$metric $operator $threshold';
      final actionText = actionValue != null
          ? '$actionType $actionValue%'
          : actionType;

      await _api.createRule(
        name: name,
        metric: metric,
        operator: operator,
        threshold: threshold,
        actionType: actionType,
        actionValue: actionValue,
        conditionText: conditionText,
        actionText: actionText,
        enabled: enabled,
      );

      await loadRules();
    } catch (e) {
      state = state.copyWith(
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Delete rule
  Future<void> deleteRule(String id) async {
    // Optimistic delete
    final originalRules = state.rules;
    state = state.copyWith(
      rules: state.rules.where((r) => r.id != id).toList(),
    );

    try {
      await _api.deleteRule(id);
    } catch (e) {
      // Revert on error
      state = state.copyWith(
        rules: originalRules,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      rethrow;
    }
  }

  /// Refresh rules
  Future<void> refresh() => loadRules();
}

/// Provider
final automationProvider =
    StateNotifierProvider<AutomationNotifier, AutomationState>((ref) {
  final api = ref.watch(workerApiProvider);
  return AutomationNotifier(api, ref);
});