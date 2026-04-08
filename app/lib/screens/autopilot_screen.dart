import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/rule.dart';
import '../models/optimization_recommendation.dart';
import '../providers/app_providers.dart';
import '../providers/intelligence_provider.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/inputs.dart';
import '../widgets/rule_card.dart';
import '../widgets/empty_state.dart';
import '../widgets/recommendation_card.dart';

class AutoPilotScreen extends ConsumerStatefulWidget {
  const AutoPilotScreen({super.key});

  @override
  ConsumerState<AutoPilotScreen> createState() => _AutoPilotScreenState();
}

class _AutoPilotScreenState extends ConsumerState<AutoPilotScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  /// 0 = Rules, 1 = Activity, 2 = AI Decisions
  int _viewMode = 0;

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    // Don’t assume every notifier has refresh/load.
    // Invalidate is safe and works for Async providers & notifiers.
    ref.invalidate(rulesProvider);
    ref.invalidate(activityLogProvider);

    // Refresh recommendations list (family provider)
    ref.invalidate(
      recommendationsProvider(const RecommendationQuery(status: 'open')),
    );

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ AutoPilot refreshed'),
        backgroundColor: C.success,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rulesAsync = ref.watch(rulesProvider);
    final activityLogAsync = ref.watch(activityLogProvider);

    final recsAsync = ref.watch(
      recommendationsProvider(const RecommendationQuery(status: 'open')),
    );

    final rules = rulesAsync.valueOrNull ?? const <AutoRule>[];
    final activeRules = rules.where((r) => r.enabled).length;
    final totalTriggers = rules.fold<int>(0, (s, r) => s + r.triggeredCount);

    final openRecs = recsAsync.valueOrNull ?? const <OptimizationRecommendation>[];
    final criticalRecs = openRecs.where((r) => r.priority == 'critical').length;

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.3 - _bgC.value * 0.4,
                    -0.6 + _bgC.value * 0.3,
                  ),
                  radius: 1.5,
                  colors: [
                    C.gold.withValues(alpha: 0.05),
                    C.primary.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                _statsBar(
                  activeRules: activeRules,
                  totalRules: rules.length,
                  triggers: totalTriggers,
                  openRecs: openRecs.length,
                  criticalRecs: criticalRecs,
                ),
                _viewToggle(),
                const SizedBox(height: 8),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _refresh,
                    color: C.primary,
                    backgroundColor: C.bgCard,
                    child: _viewBody(
                      rulesAsync: rulesAsync,
                      activityAsync: activityLogAsync,
                      recsAsync: recsAsync,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _viewBody({
    required AsyncValue<List<AutoRule>> rulesAsync,
    required AsyncValue<List<ActivityEntry>> activityAsync,
    required AsyncValue<List<OptimizationRecommendation>> recsAsync,
  }) {
    if (_viewMode == 0) return _rulesAsyncView(rulesAsync);
    if (_viewMode == 1) return _activityAsyncView(activityAsync);
    return _decisionsAsyncView(recsAsync);
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AutoPilot',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Rules • Activity • AI Decisions',
                  style: TextStyle(
                    color: C.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          OutlineBtn(
            label: 'New Rule',
            icon: Icons.add_rounded,
            onTap: _showCreateRule,
          ),
        ],
      ),
    );
  }

  Widget _statsBar({
    required int activeRules,
    required int totalRules,
    required int triggers,
    required int openRecs,
    required int criticalRecs,
  }) {
    final savedEstimate = triggers * 300.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem(
              'Active Rules',
              '$activeRules/$totalRules',
              C.success,
              Icons.toggle_on_rounded,
            ),
            Container(width: 1, height: 28, color: C.glassBorder),
            _statItem(
              'Triggers',
              '$triggers',
              C.purple,
              Icons.electric_bolt_rounded,
            ),
            Container(width: 1, height: 28, color: C.glassBorder),
            _statItem(
              'Open Recs',
              '$openRecs',
              criticalRecs > 0 ? C.error : C.gold,
              criticalRecs > 0
                  ? Icons.warning_amber_rounded
                  : Icons.auto_awesome_rounded,
            ),
            Container(width: 1, height: 28, color: C.glassBorder),
            _statItem(
              'Saved',
              U.money(savedEstimate),
              C.gold,
              Icons.savings_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: C.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _viewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: C.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.glassBorder),
            ),
            child: Row(
              children: [
                _toggleBtn(0, Icons.rule_rounded, 'Rules'),
                _toggleBtn(1, Icons.history_rounded, 'Activity'),
                _toggleBtn(2, Icons.auto_awesome_rounded, 'AI Decisions'),
              ],
            ),
          ),
          const Spacer(),
        ],
      ),
    );
  }

  Widget _toggleBtn(int index, IconData icon, String label) {
    final sel = _viewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          gradient: sel ? C.primaryGrad : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: sel ? Colors.black : C.textMuted, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: sel ? Colors.black : C.textMuted,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------
  // Rules
  // ---------------------------

  Widget _rulesAsyncView(AsyncValue<List<AutoRule>> rulesAsync) {
    return rulesAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: C.primary),
      ),
      error: (error, _) => _errorState(
        title: 'Unable to load rules',
        message: error.toString(),
        onRetry: () => ref.invalidate(rulesProvider),
      ),
      data: (rules) => _rulesView(rules),
    );
  }

  Widget _rulesView(List<AutoRule> rules) {
    if (rules.isEmpty) {
      return EmptyState(
        icon: Icons.rule_rounded,
        title: 'No rules yet',
        subtitle: 'Create your first automation rule',
        actionLabel: 'Create Rule',
        onAction: _showCreateRule,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: rules.length,
      itemBuilder: (_, i) {
        final rule = rules[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Dismissible(
            key: Key(rule.id),
            direction: DismissDirection.endToStart,
            confirmDismiss: (_) async => _showDeleteConfirm(rule.name),
            onDismissed: (_) async {
              await ref.read(rulesProvider.notifier).deleteRule(rule.id);

              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Rule "${rule.name}" deleted'),
                  backgroundColor: C.error,
                ),
              );
            },
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                gradient: C.dangerGrad,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: Colors.white,
                size: 24,
              ),
            ),
            child: RuleCard(
              name: rule.name,
              condition: rule.condition,
              action: rule.action,
              enabled: rule.enabled,
              triggeredCount: rule.triggeredCount,
              lastTriggered:
                  rule.lastTriggered != null ? U.ago(rule.lastTriggered!) : null,
              onToggle: (_) async {
                HapticFeedback.lightImpact();
                await ref.read(rulesProvider.notifier).toggle(rule.id);
              },
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showDeleteConfirm(String name) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Delete Rule', style: TextStyle(color: C.textPrimary)),
        content: Text(
          'Are you sure you want to delete "$name"?',
          style: const TextStyle(color: C.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: C.error)),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // Activity
  // ---------------------------

  Widget _activityAsyncView(AsyncValue<List<ActivityEntry>> activityAsync) {
    return activityAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: C.primary),
      ),
      error: (error, _) => _errorState(
        title: 'Unable to load activity',
        message: error.toString(),
        onRetry: () => ref.invalidate(activityLogProvider),
      ),
      data: (logs) => _activityView(logs),
    );
  }

  Widget _activityView(List<ActivityEntry> logs) {
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No activity yet',
        subtitle: 'Rule triggers and actions will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (_, i) => _activityItem(logs[i], i == logs.length - 1),
    );
  }

  Widget _activityItem(ActivityEntry entry, bool isLast) {
    late final Color color;
    late final IconData icon;

    switch (entry.type) {
      case 'scale':
        color = C.success;
        icon = Icons.trending_up_rounded;
        break;
      case 'pause':
        color = C.error;
        icon = Icons.pause_circle_rounded;
        break;
      case 'alert':
        color = C.warning;
        icon = Icons.warning_amber_rounded;
        break;
      case 'budget':
        color = C.blue;
        icon = Icons.account_balance_wallet_rounded;
        break;
      case 'reduce':
        color = C.purple;
        icon = Icons.trending_down_rounded;
        break;
      default:
        color = C.info;
        icon = Icons.info_rounded;
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: color.withValues(alpha: 0.4),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(icon, color: color, size: 16),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 1.5,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      color: C.glassBorder,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: GlassCard(
                radius: 14,
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            entry.title,
                            style: const TextStyle(
                              color: C.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            entry.type.toUpperCase(),
                            style: TextStyle(
                              color: color,
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.description,
                      style: const TextStyle(
                        color: C.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      U.ago(entry.timestamp),
                      style: const TextStyle(
                        color: C.textMuted,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------
  // AI Decisions (Worker Recommendations)
  // ---------------------------

  Widget _decisionsAsyncView(
    AsyncValue<List<OptimizationRecommendation>> recsAsync,
  ) {
    return recsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: C.primary),
      ),
      error: (error, _) => _errorState(
        title: 'Unable to load recommendations',
        message: error.toString(),
        onRetry: () => ref.invalidate(
          recommendationsProvider(const RecommendationQuery(status: 'open')),
        ),
      ),
      data: (recs) => _decisionsView(recs),
    );
  }

  Widget _decisionsView(List<OptimizationRecommendation> recs) {
    if (recs.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'No recommendations',
        subtitle: 'Run recompute to generate optimization decisions',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount: recs.length,
      itemBuilder: (_, i) {
        final rec = recs[i];

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: RecommendationCard(
            rec: rec,
            onApply: () async {
              HapticFeedback.mediumImpact();
              await ref.read(intelligenceActionsProvider).apply(rec.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('✅ Recommendation applied'),
                  backgroundColor: C.success,
                ),
              );
            },
            onDismiss: () async {
              HapticFeedback.lightImpact();
              await ref.read(intelligenceActionsProvider).dismiss(rec.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Dismissed'),
                  backgroundColor: C.bgCard,
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ---------------------------
  // Create Rule (same logic, cleaned execution)
  // ---------------------------

  void _showCreateRule() {
    HapticFeedback.mediumImpact();

    final nameCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController();
    final actionValueCtrl = TextEditingController();

    String selectedMetric = 'roas';
    String selectedOperator = '<';
    String selectedAction = 'pause';

    final metrics = <String>[
      'roas',
      'cpa',
      'ctr',
      'cpc',
      'cpm',
      'frequency',
      'spend',
      'budget_util',
      'impressions',
      'clicks',
      'conversions',
      'leads',
    ];

    final operators = <String>['<', '>', '<=', '>=', '==', '!='];

    final actions = [
      {
        'key': 'pause',
        'label': 'Pause Campaign',
        'icon': Icons.pause_circle_rounded,
        'color': C.error,
      },
      {
        'key': 'scale_budget',
        'label': 'Scale Budget (+%)',
        'icon': Icons.trending_up_rounded,
        'color': C.success,
      },
      {
        'key': 'reduce_budget',
        'label': 'Reduce Budget (-%)',
        'icon': Icons.trending_down_rounded,
        'color': C.purple,
      },
      {
        'key': 'alert',
        'label': 'Send Alert',
        'icon': Icons.notifications_active_rounded,
        'color': C.warning,
      },
      {
        'key': 'alert_and_pause',
        'label': 'Alert & Pause',
        'icon': Icons.warning_amber_rounded,
        'color': C.pink,
      },
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetCtx) => StatefulBuilder(
        builder: (sheetCtx, setSheetState) => DraggableScrollableSheet(
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          minChildSize: 0.5,
          builder: (sheetCtx, scrollCtrl) => ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [C.bgCard, C.bgDeep],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(24)),
                  border: Border.all(color: C.glassBorder),
                ),
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.all(24),
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: C.glassBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create Rule',
                      style: TextStyle(
                        color: C.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Automate actions based on performance',
                      style: TextStyle(color: C.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 24),
                    GlassInput(
                      label: 'Rule Name',
                      hint: 'e.g. Kill Low ROAS',
                      controller: nameCtrl,
                      prefixIcon: Icons.label_rounded,
                    ),
                    const SizedBox(height: 24),

                    // Condition card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  gradient: C.primaryGrad,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'IF',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Condition',
                                style: TextStyle(
                                  color: C.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Metric',
                            style: TextStyle(
                              color: C.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: metrics.map((m) {
                              final sel = selectedMetric == m;
                              return GestureDetector(
                                onTap: () =>
                                    setSheetState(() => selectedMetric = m),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: sel
                                        ? C.primary.withValues(alpha: 0.15)
                                        : C.glassWhite,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: sel
                                          ? C.primary.withValues(alpha: 0.5)
                                          : C.glassBorder,
                                    ),
                                  ),
                                  child: Text(
                                    m.toUpperCase(),
                                    style: TextStyle(
                                      color: sel ? C.primary : C.textSecondary,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Operator',
                                      style: TextStyle(
                                        color: C.textMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Wrap(
                                      spacing: 4,
                                      runSpacing: 4,
                                      children: operators.map((op) {
                                        final sel = selectedOperator == op;
                                        return GestureDetector(
                                          onTap: () => setSheetState(
                                            () => selectedOperator = op,
                                          ),
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 10,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: sel
                                                  ? C.primary.withValues(
                                                      alpha: 0.15,
                                                    )
                                                  : C.glassWhite,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: sel
                                                    ? C.primary
                                                    : C.glassBorder,
                                              ),
                                            ),
                                            child: Text(
                                              op,
                                              style: TextStyle(
                                                color: sel
                                                    ? C.primary
                                                    : C.textSecondary,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ),
                                        );
                                      }).toList(),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 3,
                                child: GlassInput(
                                  label: 'Threshold',
                                  hint: 'e.g. 2.0',
                                  controller: thresholdCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  prefixIcon: Icons.speed_rounded,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Action card
                    GlassCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: C.gold,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Text(
                                  'THEN',
                                  style: TextStyle(
                                    color: Colors.black,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'Action',
                                style: TextStyle(
                                  color: C.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          ...actions.map((a) {
                            final sel = selectedAction == a['key'] as String;
                            return GestureDetector(
                              onTap: () => setSheetState(
                                () => selectedAction = a['key'] as String,
                              ),
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? (a['color'] as Color)
                                          .withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: sel
                                        ? (a['color'] as Color)
                                            .withValues(alpha: 0.4)
                                        : C.glassBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      sel
                                          ? Icons.radio_button_checked
                                          : Icons.radio_button_off,
                                      color: sel
                                          ? a['color'] as Color
                                          : C.textMuted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 10),
                                    Icon(
                                      a['icon'] as IconData,
                                      color: sel
                                          ? a['color'] as Color
                                          : C.textMuted,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      a['label'] as String,
                                      style: TextStyle(
                                        color: sel
                                            ? C.textPrimary
                                            : C.textSecondary,
                                        fontSize: 13,
                                        fontWeight: sel
                                            ? FontWeight.w600
                                            : FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          if (selectedAction == 'scale_budget' ||
                              selectedAction == 'reduce_budget') ...[
                            const SizedBox(height: 8),
                            GlassInput(
                              label: 'Percentage (%)',
                              hint: 'e.g. 20',
                              controller: actionValueCtrl,
                              keyboardType: TextInputType.number,
                              prefixIcon: Icons.percent_rounded,
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    PrimaryBtn(
                      label: 'Create Rule',
                      onTap: () async {
                        final name = nameCtrl.text.trim();
                        final thrText = thresholdCtrl.text.trim();

                        if (name.isEmpty || thrText.isEmpty) {
                          ScaffoldMessenger.of(sheetCtx).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill name and threshold'),
                              backgroundColor: C.error,
                            ),
                          );
                          return;
                        }

                        final threshold = double.tryParse(thrText);
                        if (threshold == null) {
                          ScaffoldMessenger.of(sheetCtx).showSnackBar(
                            const SnackBar(
                              content: Text('Threshold must be a valid number'),
                              backgroundColor: C.error,
                            ),
                          );
                          return;
                        }

                        String? actionValue;
                        if (selectedAction == 'scale_budget' ||
                            selectedAction == 'reduce_budget') {
                          final raw = actionValueCtrl.text.trim();
                          if (raw.isEmpty) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content:
                                    Text('Please enter percentage for budget action'),
                                backgroundColor: C.error,
                              ),
                            );
                            return;
                          }
                          final v = double.tryParse(raw);
                          if (v == null || v <= 0) {
                            ScaffoldMessenger.of(sheetCtx).showSnackBar(
                              const SnackBar(
                                content: Text('Percentage must be a valid number'),
                                backgroundColor: C.error,
                              ),
                            );
                            return;
                          }
                          actionValue = raw;
                        }

                        final rule = AutoRule(
                          id: 'temp_${DateTime.now().millisecondsSinceEpoch}',
                          name: name,
                          condition:
                              '${selectedMetric.toUpperCase()} $selectedOperator $threshold',
                          action:
                              '${selectedAction.replaceAll('_', ' ')}${actionValue != null ? ' $actionValue%' : ''}',
                          metric: selectedMetric,
                          operator: selectedOperator,
                          threshold: threshold,
                          actionType: selectedAction,
                          actionValue: actionValue,
                          enabled: true,
                          triggeredCount: 0,
                        );

                        await ref.read(rulesProvider.notifier).addRule(rule);

                        if (!sheetCtx.mounted) return;
                        Navigator.of(sheetCtx).pop();

                        HapticFeedback.heavyImpact();

                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('✅ Rule "${rule.name}" created'),
                            backgroundColor: C.success,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------
  // Shared error UI
  // ---------------------------

  Widget _errorState({
    required String title,
    required String message,
    required VoidCallback onRetry,
  }) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded, color: C.error, size: 28),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: C.textSecondary, fontSize: 12),
                ),
                const SizedBox(height: 14),
                OutlineBtn(
                  label: 'Retry',
                  icon: Icons.refresh_rounded,
                  onTap: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}