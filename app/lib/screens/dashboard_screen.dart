import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import '../models/intelligence_summary.dart';
import '../providers/app_providers.dart';
import '../providers/intelligence_provider.dart';
import '../widgets/buttons.dart';
import '../widgets/campaign_tile.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';

enum _CampaignSort { roas, spend, cpa }

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  int _period = 1; // 0=7D, 1=30D
  String get _datePreset => _period == 0 ? 'last_7d' : 'last_30d';

  DateTime? _lastRefresh;

  // Dashboard Options
  bool _showPulse = true;
  bool _showDerived = true;
  bool _showPlatformMix = true;
  bool _showWorkerInsights = true;
  bool _showCrm = true;

  _CampaignSort _campaignSort = _CampaignSort.roas;

  // Kaapav targets (can later move to settings)
  static const double _targetRoas = 4.0;
  static const double _targetCpa = 150.0;

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
    ref.invalidate(campaignsProvider);
    ref.invalidate(dashboardSummaryProvider(_datePreset));
    ref.invalidate(dashboardDailyProvider(_datePreset));
    ref.invalidate(notificationsCountProvider);
    ref.invalidate(crmStatsProvider);
    ref.invalidate(connectionStatusProvider);
    ref.invalidate(intelligenceSummaryProvider);

    await Future.wait([
      ref.read(campaignsProvider.notifier).refresh(),
      ref.read(dashboardSummaryProvider(_datePreset).future),
      ref.read(dashboardDailyProvider(_datePreset).future),
      ref.read(notificationsCountProvider.future),
      ref.read(crmStatsProvider.future),
      ref.read(connectionStatusProvider.future),
      ref.read(intelligenceSummaryProvider.future),
    ]);

    _lastRefresh = DateTime.now();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Dashboard refreshed'),
        backgroundColor: C.success,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(campaignsProvider);
    final summaryAsync = ref.watch(dashboardSummaryProvider(_datePreset));
    final dailyAsync = ref.watch(dashboardDailyProvider(_datePreset));
    final unreadCountAsync = ref.watch(notificationsCountProvider);
    final crmStatsAsync = ref.watch(crmStatsProvider);
    final connAsync = ref.watch(connectionStatusProvider);
    final intelAsync = ref.watch(intelligenceSummaryProvider);

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          // Animated BG
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    -0.5 + _bgC.value * 0.3,
                    -0.8 + _bgC.value * 0.2,
                  ),
                  radius: 1.5,
                  colors: [
                    C.primary.withValues(alpha: 0.07),
                    C.purple.withValues(alpha: 0.045),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: C.primary,
              backgroundColor: C.bgCard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: _appBar(
                      unreadCountAsync.valueOrNull ?? 0,
                      onOpenOptions: _openDashboardOptions,
                    ),
                  ),

                  SliverToBoxAdapter(child: _quickActions()),

                  SliverToBoxAdapter(child: _trustBar(connAsync, intelAsync)),

                  if (_showPulse)
                    SliverToBoxAdapter(
                      child: _pulseCard(
                        campaignsAsync: campaignsAsync,
                        summaryAsync: summaryAsync,
                        intelAsync: intelAsync,
                        connAsync: connAsync,
                      ),
                    ),

                  // HERO upgraded (targets + smoother delta)
                  SliverToBoxAdapter(
                    child: _performanceHeroV2(summaryAsync, dailyAsync),
                  ),

                  if (_showWorkerInsights)
                    SliverToBoxAdapter(
                      child: _decisionQueue(intelAsync),
                    ),

                  SliverToBoxAdapter(child: _riskRadar(campaignsAsync, intelAsync)),

                  SliverToBoxAdapter(
                    child: _healthAndFunnel(
                      summaryAsync: summaryAsync,
                      campaignsAsync: campaignsAsync,
                      intelAsync: intelAsync,
                    ),
                  ),

                  if (_showDerived)
                    SliverToBoxAdapter(
                      child: _derivedMetrics(summaryAsync, campaignsAsync),
                    ),

                  if (_showPlatformMix)
                    SliverToBoxAdapter(
                      child: _platformMix(campaignsAsync),
                    ),

                  SliverToBoxAdapter(
                    child: _quickStats(campaignsAsync, summaryAsync, crmStatsAsync),
                  ),

                  SliverToBoxAdapter(
                    child: _topCampaigns(campaignsAsync),
                  ),

                  if (_showCrm)
                    SliverToBoxAdapter(
                      child: _crmSnapshot(crmStatsAsync),
                    ),

                  const SliverToBoxAdapter(child: SizedBox(height: 110)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // APP BAR
  // ══════════════════════════════════════════════════════════════

  Widget _appBar(int unreadCount, {required VoidCallback onOpenOptions}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: C.primaryGrad,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withValues(alpha: 0.35),
                  blurRadius: 14,
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kaapav Ad Engine',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.2,
                  ),
                ),
                Text(
                  'ROAS Intelligence Console • ${_period == 0 ? '7D' : '30D'}',
                  style: const TextStyle(color: C.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          const LiveDot(),
          const SizedBox(width: 8),
          GlassIconBtn(
            icon: Icons.tune_rounded,
            badge: false,
            badgeCount: '0',
            onTap: () {
              HapticFeedback.selectionClick();
              onOpenOptions();
            },
          ),
          const SizedBox(width: 8),
          GlassIconBtn(
            icon: Icons.notifications_outlined,
            badge: unreadCount > 0,
            badgeCount: unreadCount.toString(),
            onTap: () => context.push('/more/notifications'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DASHBOARD OPTIONS (FIXED + WORKING)
  // ══════════════════════════════════════════════════════════════

  void _openDashboardOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: GlassCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: StatefulBuilder(
              builder: (ctx, setSheet) {
                Widget sw({
                  required String title,
                  required String subtitle,
                  required bool value,
                  required ValueChanged<bool> onChanged,
                }) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: C.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: const TextStyle(
                                  color: C.textSecondary,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: value,
                          onChanged: (v) {
                            HapticFeedback.selectionClick();
                            onChanged(v);
                            setSheet(() {});
                            setState(() {});
                          },
                          activeTrackColor: C.primary,
                          inactiveTrackColor: C.glassBorder.withValues(alpha: 0.65),
                          inactiveThumbColor: C.textMuted,
                        ),
                      ],
                    ),
                  );
                }

                Widget sortChip(String label, _CampaignSort v) {
                  final sel = _campaignSort == v;
                  return Expanded(
                    child: GlassCard(
                      radius: 14,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      onTap: () {
                        HapticFeedback.selectionClick();
                        _campaignSort = v;
                        setSheet(() {});
                        setState(() {});
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            label,
                            style: TextStyle(
                              color: sel ? C.textPrimary : C.textSecondary,
                              fontSize: 11,
                              fontWeight: sel ? FontWeight.w900 : FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: sel ? C.primary : C.glassBorder,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: C.glassBorder,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Row(
                      children: [
                        Icon(Icons.tune_rounded, color: C.textPrimary, size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Dashboard Options',
                          style: TextStyle(
                            color: C.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),

                    sw(
                      title: 'Show Pulse card',
                      subtitle: 'Alerts, readiness, last refresh',
                      value: _showPulse,
                      onChanged: (v) => _showPulse = v,
                    ),
                    sw(
                      title: 'Show Worker insights',
                      subtitle: 'Decision queue, candidates, seeds',
                      value: _showWorkerInsights,
                      onChanged: (v) => _showWorkerInsights = v,
                    ),
                    sw(
                      title: 'Show Derived metrics',
                      subtitle: 'CPC, CPM, CVR, AOV',
                      value: _showDerived,
                      onChanged: (v) => _showDerived = v,
                    ),
                    sw(
                      title: 'Show Platform mix',
                      subtitle: 'Spend distribution by platform',
                      value: _showPlatformMix,
                      onChanged: (v) => _showPlatformMix = v,
                    ),
                    sw(
                      title: 'Show CRM snapshot',
                      subtitle: 'Lead stages + pipeline value',
                      value: _showCrm,
                      onChanged: (v) => _showCrm = v,
                    ),

                    const SizedBox(height: 12),
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Top Campaigns sorting',
                        style: TextStyle(
                          color: C.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        sortChip('ROAS', _CampaignSort.roas),
                        const SizedBox(width: 10),
                        sortChip('Spend', _CampaignSort.spend),
                        const SizedBox(width: 10),
                        sortChip('CPA', _CampaignSort.cpa),
                      ],
                    ),

                    const SizedBox(height: 14),
                    OutlineBtn(
                      label: 'Close',
                      icon: Icons.check_rounded,
                      onTap: () => Navigator.pop(context),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QUICK ACTIONS
  // ══════════════════════════════════════════════════════════════

  Widget _quickActions() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: SizedBox(
        height: 56,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: [
            _actionChip(
              icon: Icons.link_rounded,
              label: 'Connect',
              color: C.primary,
              onTap: () => context.go('/connect'),
            ),
            _actionChip(
              icon: Icons.rocket_launch_rounded,
              label: 'AutoPilot',
              color: C.purple,
              onTap: () => context.go('/autopilot'),
            ),
            _actionChip(
              icon: Icons.campaign_rounded,
              label: 'Campaigns',
              color: C.blue,
              onTap: () => context.go('/campaigns'),
            ),
            _actionChip(
              icon: Icons.groups_2_rounded,
              label: 'CRM',
              color: C.gold,
              onTap: () => context.go('/crm'),
            ),
            _actionChip(
              icon: Icons.analytics_rounded,
              label: 'Analytics',
              color: C.success,
              onTap: () => context.push('/more/analytics'),
            ),
            _actionChip(
              icon: Icons.refresh_rounded,
              label: 'Refresh',
              color: C.info,
              onTap: _refresh,
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color.withValues(alpha: 0.18)),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: const TextStyle(
                color: C.textPrimary,
                fontWeight: FontWeight.w900,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TRUST BAR
  // ══════════════════════════════════════════════════════════════

  Widget _trustBar(
    AsyncValue<Map<String, dynamic>> connAsync,
    AsyncValue<IntelligenceSummary> intelAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: connAsync.when(
          loading: () => const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2, color: C.primary),
              ),
              SizedBox(width: 10),
              Text(
                'Checking Worker connection...',
                style: TextStyle(color: C.textSecondary, fontSize: 12),
              ),
            ],
          ),
          error: (_, __) => Row(
            children: [
              const Icon(Icons.cloud_off_rounded, color: C.error, size: 18),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Worker status unavailable',
                  style: TextStyle(color: C.textSecondary, fontSize: 12),
                ),
              ),
              OutlineBtn(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onTap: () => ref.invalidate(connectionStatusProvider),
              ),
            ],
          ),
          data: (m) {
            final workerOnline = m['workerOnline'] == true;
            final workerReady = m['workerReady'] == true;
            final mode = (m['mode']?.toString() ?? 'none');

            final color = (workerOnline && workerReady) ? C.success : (workerOnline ? C.warning : C.error);
            final text = (workerOnline && workerReady)
                ? 'Worker Ready'
                : workerOnline
                    ? 'Worker Online • Not Authenticated'
                    : 'Worker Offline';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.hub_rounded, color: color, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '$text • Mode: $mode',
                        style: const TextStyle(
                          color: C.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    OutlineBtn(
                      label: 'Connect',
                      icon: Icons.link_rounded,
                      onTap: () => context.go('/connect'),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: intelAsync.when(
                        loading: () => _tinyPill('Open Recs', '...', C.textMuted),
                        error: (_, __) => _tinyPill('Open Recs', '—', C.textMuted),
                        data: (intel) => _tinyPill(
                          'Open Recs',
                          '${intel.openRecommendations}',
                          intel.openRecommendations > 0 ? C.warning : C.success,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: intelAsync.when(
                        loading: () => _tinyPill('Fatigue', '...', C.textMuted),
                        error: (_, __) => _tinyPill('Fatigue', '—', C.textMuted),
                        data: (intel) => _tinyPill(
                          'Fatigue Alerts',
                          '${intel.fatigueAlerts}',
                          intel.fatigueAlerts > 0 ? C.warning : C.textSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlineBtn(
                        label: 'Recompute',
                        icon: Icons.auto_awesome_rounded,
                        color: C.primary,
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await ref.read(intelligenceActionsProvider).recompute();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Intelligence recompute triggered'),
                              backgroundColor: C.success,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _tinyPill(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: C.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.glassBorder),
      ),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: C.textMuted, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PULSE CARD
  // ══════════════════════════════════════════════════════════════

  Widget _pulseCard({
    required AsyncValue<List<Campaign>> campaignsAsync,
    required AsyncValue<InsightsSummary> summaryAsync,
    required AsyncValue<IntelligenceSummary> intelAsync,
    required AsyncValue<Map<String, dynamic>> connAsync,
  }) {
    final campaigns = campaignsAsync.valueOrNull ?? const <Campaign>[];

    final nearBudget = campaigns
        .where((c) => c.isActive && c.dailyBudget > 0 && c.spend >= c.dailyBudget * 0.85)
        .length;

    final lowRoas = campaigns.where((c) => c.spend >= 1000 && c.roas > 0 && c.roas < 2).length;

    final intel = intelAsync.valueOrNull;
    final fatigue = (intel?.fatigueAlerts ?? 0);

    final conn = connAsync.valueOrNull;
    final workerReady = conn?['workerReady'] == true;
    final workerOnline = conn?['workerOnline'] == true;

    final statusColor = (workerOnline && workerReady)
        ? C.success
        : workerOnline
            ? C.warning
            : C.error;

    final updatedText =
        _lastRefresh == null ? 'Not refreshed yet' : 'Updated ${_timeAgo(_lastRefresh!)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: GlassCard(
        radius: 20,
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        C.primary.withValues(alpha: 0.22),
                        C.purple.withValues(alpha: 0.14),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.glassBorder),
                  ),
                  child: const Icon(Icons.insights_rounded, color: C.primary, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Today Pulse',
                        style: TextStyle(
                          color: C.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Health, alerts & readiness at a glance',
                        style: TextStyle(color: C.textSecondary, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: statusColor.withValues(alpha: 0.22)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        workerReady ? 'Ready' : (workerOnline ? 'Online' : 'Offline'),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _pulseMetric(
                    'Budget Near',
                    '$nearBudget',
                    nearBudget > 0 ? C.warning : C.textMuted,
                    Icons.electric_bolt_rounded,
                    onTap: () => context.go('/campaigns'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pulseMetric(
                    'Low ROAS',
                    '$lowRoas',
                    lowRoas > 0 ? C.error : C.textMuted,
                    Icons.trending_down_rounded,
                    onTap: () => context.go('/campaigns'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _pulseMetric(
                    'Fatigue',
                    '$fatigue',
                    fatigue > 0 ? C.warning : C.textMuted,
                    Icons.repeat_rounded,
                    onTap: () => context.go('/autopilot'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            summaryAsync.when(
              loading: () => _subLine(updatedText, trailing: 'Loading metrics...'),
              error: (_, __) => _subLine(updatedText, trailing: 'Metrics error'),
              data: (s) => _subLine(
                updatedText,
                trailing: 'Spend ${U.money(s.totalSpend)} • Rev ${U.money(s.totalRevenue)}',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pulseMetric(
    String label,
    String value,
    Color color,
    IconData icon, {
    required VoidCallback onTap,
  }) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: C.glassBorder),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: C.textMuted,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    color: color,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _subLine(String leading, {required String trailing}) {
    return Row(
      children: [
        Expanded(
          child: Text(
            leading,
            style: const TextStyle(color: C.textSecondary, fontSize: 11),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          trailing,
          style: const TextStyle(color: C.textSecondary, fontSize: 11),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PERFORMANCE HERO v2 (targets + smoothed delta)
  // ══════════════════════════════════════════════════════════════

  Widget _performanceHeroV2(
    AsyncValue<InsightsSummary> summaryAsync,
    AsyncValue<List<DayInsight>> dailyAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: GlassCard(
        radius: 24,
        turquoise: true,
        glow: true,
        padding: EdgeInsets.zero,
        child: summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              height: 260,
              child: Center(child: CircularProgressIndicator(color: C.primary)),
            ),
          ),
          error: (_, __) => _errorCard('Failed to load performance summary'),
          data: (s) {
            final daily = dailyAsync.valueOrNull ?? const <DayInsight>[];
            final chartData = daily.isNotEmpty
                ? daily.map((e) => e.roas).toList(growable: false)
                : <double>[s.avgRoas];

            final roasDelta = _windowDeltaPct(chartData, window: 3);

            final roasProgress = _clamp01(s.avgRoas / _targetRoas);
            final cpaProgress = (s.avgCpa <= 0) ? 0.0 : _clamp01(_targetCpa / s.avgCpa);

            final profitProxy = s.totalRevenue - s.totalSpend;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 18, 18, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _period == 0 ? 'Last 7 days' : 'Last 30 days',
                              style: const TextStyle(color: C.textSecondary, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  U.roas(s.avgRoas),
                                  style: const TextStyle(
                                    color: C.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: -1.0,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: ChangePill(
                                    change: '${roasDelta >= 0 ? '+' : ''}${roasDelta.toStringAsFixed(1)}%',
                                    isUp: roasDelta >= 0,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Spend ${U.money(s.totalSpend)} • Revenue ${U.money(s.totalRevenue)}',
                              style: const TextStyle(color: C.textMuted, fontSize: 11),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: C.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.glassBorder),
                        ),
                        child: Row(
                          children: [
                            _periodBtn(0, '7D'),
                            _periodBtn(1, '30D'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // KPIs
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Row(
                    children: [
                      _miniKpi('CPA', U.money(s.avgCpa), C.warning, Icons.ads_click),
                      _miniKpi('CTR', U.pct(s.avgCtr), C.purple, Icons.touch_app),
                      _miniKpi(
                        'Profit*',
                        profitProxy >= 0 ? U.money(profitProxy) : '-${U.money(profitProxy.abs())}',
                        profitProxy >= 0 ? C.success : C.error,
                        Icons.ssid_chart_rounded,
                      ),
                      _miniKpi('Orders', U.num(s.totalConversions.toDouble()), C.success, Icons.shopping_bag_rounded),
                    ],
                  ),
                ),

                // Targets
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
                  child: Column(
                    children: [
                      _targetRow(
                        label: 'ROAS Target ${_targetRoas.toStringAsFixed(0)}x',
                        valueText: U.roas(s.avgRoas),
                        progress: roasProgress,
                        good: s.avgRoas >= _targetRoas,
                        gradient: s.avgRoas >= _targetRoas ? C.successGrad : C.primaryGrad,
                      ),
                      const SizedBox(height: 10),
                      _targetRow(
                        label: 'CPA Target ≤ ${U.money(_targetCpa)}',
                        valueText: U.money(s.avgCpa),
                        progress: cpaProgress,
                        good: s.avgCpa > 0 && s.avgCpa <= _targetCpa,
                        gradient: (s.avgCpa > 0 && s.avgCpa <= _targetCpa)
                            ? C.successGrad
                            : LinearGradient(colors: [C.warning, C.pink]),
                      ),
                    ],
                  ),
                ),

                // Chart
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
                  child: RoasLineChart(
                    data: chartData.isEmpty ? <double>[0.0] : chartData,
                    height: 130,
                  ),
                ),

                // Footer CTA
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          _lastRefresh == null
                              ? 'Pull to refresh to sync latest data'
                              : 'Last refresh: ${_timeAgo(_lastRefresh!)}',
                          style: const TextStyle(color: C.textMuted, fontSize: 10.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => context.push('/more/analytics'),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: C.bgCard,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: C.glassBorder),
                          ),
                          child: const Text(
                            'Deep dive',
                            style: TextStyle(
                              color: C.textSecondary,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _periodBtn(int index, String label) {
    final sel = index == _period;
    return GestureDetector(
      onTap: () {
        if (_period == index) return;
        HapticFeedback.selectionClick();
        setState(() => _period = index);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: sel ? C.primaryGrad : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.black : C.textMuted,
            fontSize: 11,
            fontWeight: sel ? FontWeight.w900 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _miniKpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _targetRow({
    required String label,
    required String valueText,
    required double progress,
    required bool good,
    required Gradient gradient,
  }) {
    final labelColor = good ? C.success : C.textSecondary;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: labelColor, fontSize: 10.5, fontWeight: FontWeight.w900),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              _gradientProgress(progress: progress, gradient: gradient),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          valueText,
          style: TextStyle(
            color: good ? C.success : C.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }

  Widget _gradientProgress({required double progress, required Gradient gradient}) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: _clamp01(progress)),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Stack(
            children: [
              Container(height: 8, color: C.glassWhite),
              FractionallySizedBox(
                widthFactor: v,
                child: Container(height: 8, decoration: BoxDecoration(gradient: gradient)),
              ),
            ],
          ),
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DECISION QUEUE (Worker insights) - cleaner than repeating cards later
  // ══════════════════════════════════════════════════════════════

  Widget _decisionQueue(AsyncValue<IntelligenceSummary> intelAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      child: Column(
        children: [
          SectionHeader(
            title: 'Decision Queue (AI)',
            action: 'Open AutoPilot',
            onAction: () => context.go('/autopilot'),
          ),
          const SizedBox(height: 10),
          intelAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(color: C.primary),
            ),
            error: (e, _) => _errorCard('Failed to load intelligence: $e'),
            data: (intel) {
              final topScale =
                  intel.topScalableCampaigns.isNotEmpty ? intel.topScalableCampaigns.first : null;
              final topAudience = intel.topHotAudiences.isNotEmpty ? intel.topHotAudiences.first : null;
              final topSeed = intel.topSeedBuyers.isNotEmpty ? intel.topSeedBuyers.first : null;

              return Column(
                children: [
                  _intelRowCard(
                    icon: Icons.bolt_rounded,
                    color: intel.openRecommendations > 0 ? C.warning : C.success,
                    title: 'Open Recommendations',
                    subtitle: '${intel.openRecommendations} open • ${intel.fatigueAlerts} fatigue alerts',
                    action: 'Review',
                    onTap: () => context.go('/autopilot'),
                  ),
                  const SizedBox(height: 8),
                  _intelRowCard(
                    icon: Icons.trending_up_rounded,
                    color: C.success,
                    title: 'Top Scale Candidate',
                    subtitle: topScale == null
                        ? 'No scale candidate yet — recompute Worker intelligence'
                        : '${topScale.title} • Score ${topScale.score.toStringAsFixed(0)}',
                    action: 'Queue',
                    onTap: () => context.go('/autopilot'),
                  ),
                  const SizedBox(height: 8),
                  _intelRowCard(
                    icon: Icons.people_alt_rounded,
                    color: C.blue,
                    title: 'Hottest Audience',
                    subtitle: topAudience == null
                        ? 'No audience intent scores yet — recompute'
                        : '${topAudience.name} • Intent ${topAudience.score.toStringAsFixed(0)}',
                    action: 'View',
                    onTap: () => context.go('/autopilot'),
                  ),
                  const SizedBox(height: 8),
                  _intelRowCard(
                    icon: Icons.workspace_premium_rounded,
                    color: C.gold,
                    title: 'Seed Strength',
                    subtitle: topSeed == null
                        ? '${intel.topBuyerCount} top buyers (Gold/Platinum)'
                        : 'Top seed: ${topSeed.name} • Score ${topSeed.score.toStringAsFixed(0)}',
                    action: 'Buyers',
                    onTap: () => context.go('/autopilot'),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _intelRowCard({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
    required String action,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: C.textSecondary, fontSize: 11),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(10)),
            child: Text(
              action,
              style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // RISK RADAR
  // ══════════════════════════════════════════════════════════════

  Widget _riskRadar(
    AsyncValue<List<Campaign>> campaignsAsync,
    AsyncValue<IntelligenceSummary> intelAsync,
  ) {
    final campaigns = campaignsAsync.valueOrNull ?? const <Campaign>[];

    final lowRoas =
        campaigns.where((c) => c.isActive && c.spend >= 1000 && c.roas > 0 && c.roas < 2).length;
    final highCpa =
        campaigns.where((c) => c.isActive && c.spend >= 1000 && c.cpa > 250).length;
    final fatigueByFreq = campaigns.where((c) => c.isActive && c.frequency >= 3.5).length;

    final intelFatigue = intelAsync.valueOrNull?.fatigueAlerts ?? 0;
    final fatigue = (intelFatigue > 0) ? intelFatigue : fatigueByFreq;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'Risk Radar'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _riskChip(
                  label: 'Low ROAS',
                  value: '$lowRoas',
                  color: lowRoas > 0 ? C.error : C.textMuted,
                  icon: Icons.trending_down_rounded,
                  onTap: () => context.go('/campaigns'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _riskChip(
                  label: 'High CPA',
                  value: '$highCpa',
                  color: highCpa > 0 ? C.warning : C.textMuted,
                  icon: Icons.warning_amber_rounded,
                  onTap: () => context.go('/campaigns'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _riskChip(
                  label: 'Fatigue',
                  value: '$fatigue',
                  color: fatigue > 0 ? C.warning : C.textMuted,
                  icon: Icons.repeat_rounded,
                  onTap: () => context.go('/autopilot'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _riskChip({
    required String label,
    required String value,
    required Color color,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.glassBorder),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: C.textSecondary, fontSize: 11, fontWeight: FontWeight.w900),
                ),
                Text(
                  value,
                  style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HEALTH + FUNNEL (FIXED CTR/CVR units)
  // ══════════════════════════════════════════════════════════════

  Widget _healthAndFunnel({
    required AsyncValue<InsightsSummary> summaryAsync,
    required AsyncValue<List<Campaign>> campaignsAsync,
    required AsyncValue<IntelligenceSummary> intelAsync,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'Performance Health'),
          const SizedBox(height: 10),
          summaryAsync.when(
            loading: () => const GlassCard(
              radius: 18,
              padding: EdgeInsets.all(18),
              child: Center(child: CircularProgressIndicator(color: C.primary)),
            ),
            error: (_, __) => _errorCard('Failed to load health'),
            data: (s) {
              final campaigns = campaignsAsync.valueOrNull ?? const <Campaign>[];
              final intel = intelAsync.valueOrNull;

              // CTR/CVR shown as percentage values
              final impressions = math.max(1.0, s.totalImpressions);
              final clicks = math.max(1.0, s.totalClicks);
              
              final ctrPct = (s.totalClicks / impressions) * 100.0;
              final cvrPct = (s.totalConversions / clicks) * 100.0;

              final score = _healthScore(
                roas: s.avgRoas,
                cpa: s.avgCpa,
                ctrPct: s.avgCtr, // assuming avgCtr comes from Meta as percent (e.g. 3.8)
                fatigueAlerts: intel?.fatigueAlerts ?? 0,
                openRecs: intel?.openRecommendations ?? 0,
              );

              final healthColor = score >= 75 ? C.success : (score >= 55 ? C.warning : C.error);

              final active = campaigns.where((c) => c.isActive).length;
              final paused = campaigns.where((c) => c.status.toLowerCase() == 'paused').length;

              return Row(
                children: [
                  Expanded(
                    child: GlassCard(
                      radius: 18,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Health Score', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              _RingGauge(value: score / 100.0, color: healthColor, size: 54, stroke: 8),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${score.toStringAsFixed(0)}/100',
                                      style: const TextStyle(
                                        color: C.textPrimary,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 18,
                                      ),
                                    ),
                                    Text(
                                      _healthLabel(score),
                                      style: TextStyle(
                                        color: healthColor,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _kv('Active', '$active', C.success),
                          const SizedBox(height: 6),
                          _kv('Paused', '$paused', C.textMuted),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GlassCard(
                      radius: 18,
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Funnel', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                          const SizedBox(height: 10),
                          _funnelRow('Impressions', U.num(s.totalImpressions.toDouble()), C.blue),
                          const SizedBox(height: 8),
                          _funnelRow('Clicks', U.num(s.totalClicks.toDouble()), C.purple, right: 'CTR ${U.pct(ctrPct)}'),
                          const SizedBox(height: 8),
                          _funnelRow('Orders', U.num(s.totalConversions.toDouble()), C.success, right: 'CVR ${U.pct(cvrPct)}'),
                          const SizedBox(height: 10),
                          _pacingLine(
                            label: 'Revenue / Spend',
                            left: U.money(s.totalRevenue),
                            right: U.money(s.totalSpend),
                            color: C.gold,
                            ratio: s.totalSpend <= 0 ? 0 : (s.totalRevenue / s.totalSpend).clamp(0, 8) / 8.0,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, Color color) {
    return Row(
      children: [
        Expanded(child: Text(k, style: const TextStyle(color: C.textMuted, fontSize: 11))),
        Text(v, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      ],
    );
  }

  Widget _funnelRow(String label, String value, Color color, {String? right}) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 8),
        Expanded(child: Text(label, style: const TextStyle(color: C.textSecondary, fontSize: 11))),
        if (right != null) ...[
          Text(right, style: const TextStyle(color: C.textMuted, fontSize: 10)),
          const SizedBox(width: 10),
        ],
        Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
      ],
    );
  }

  Widget _pacingLine({
    required String label,
    required String left,
    required String right,
    required Color color,
    required double ratio,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: C.glassWhite)),
                FractionallySizedBox(
                  widthFactor: ratio,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color.withValues(alpha: 0.8), color.withValues(alpha: 0.25)],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(left, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
            ),
            Text(right, style: const TextStyle(color: C.textSecondary, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  // ══════════════════════════════════════════════════════════════
  // DERIVED METRICS (FIXED CVR units)
  // ══════════════════════════════════════════════════════════════

  Widget _derivedMetrics(
    AsyncValue<InsightsSummary> summaryAsync,
    AsyncValue<List<Campaign>> campaignsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'Derived Metrics'),
          const SizedBox(height: 10),
          summaryAsync.when(
            loading: () => const GlassCard(
              radius: 18,
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: C.primary)),
            ),
            error: (_, __) => _errorCard('Failed to compute derived metrics'),
            data: (s) {
              final impressions = math.max(1.0, s.totalImpressions);
              final clicks = math.max(1.0, s.totalClicks);
              final conv = math.max(1.0, s.totalConversions);

              final cpc = s.totalSpend / clicks;
              final cpm = (s.totalSpend / impressions) * 1000.0;

              final cvrPct = (s.totalConversions / clicks) * 100.0;
              final aov = s.totalRevenue / conv;

              final campaigns = campaignsAsync.valueOrNull ?? const <Campaign>[];
              final freqValues = campaigns.where((c) => c.frequency > 0).map((c) => c.frequency).toList();
              final freqAvg = freqValues.isEmpty ? 0.0 : freqValues.reduce((a, b) => a + b) / freqValues.length;

              return GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _metricPill('CPC', U.money(cpc), Icons.mouse_rounded, C.blue)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricPill('CPM', U.money(cpm), Icons.view_day_rounded, C.purple)),
                        const SizedBox(width: 10),
                        Expanded(child: _metricPill('CVR', U.pct(cvrPct), Icons.shopping_cart_checkout_rounded, C.success)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(child: _metricPill('AOV', U.money(aov), Icons.receipt_long_rounded, C.gold)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricPill(
                            'Avg Frequency',
                            freqAvg == 0 ? '—' : freqAvg.toStringAsFixed(2),
                            Icons.repeat_rounded,
                            freqAvg >= 3.5 ? C.warning : C.textSecondary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _metricPill(
                            'Efficiency',
                            _efficiencyLabel(s.avgRoas, s.avgCpa),
                            Icons.auto_graph_rounded,
                            _efficiencyColor(s.avgRoas, s.avgCpa),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: C.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10, fontWeight: FontWeight.w900)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PLATFORM MIX
  // ══════════════════════════════════════════════════════════════

  Widget _platformMix(AsyncValue<List<Campaign>> campaignsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'Platform Mix'),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const GlassCard(
              radius: 18,
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator(color: C.primary)),
            ),
            error: (_, __) => _errorCard('Failed to load platform mix'),
            data: (campaigns) {
              if (campaigns.isEmpty) return _emptyConnectCard();

              final spendBy = <String, double>{};
              for (final c in campaigns) {
                final k = (c.platform.isEmpty ? 'Unknown' : c.platform);
                spendBy[k] = (spendBy[k] ?? 0) + c.spend;
              }

              final total = spendBy.values.fold<double>(0, (a, b) => a + b);
              if (total <= 0) {
                return GlassCard(
                  radius: 18,
                  padding: const EdgeInsets.all(14),
                  child: const Text(
                    'No spend recorded for current range.',
                    style: TextStyle(color: C.textSecondary, fontSize: 12),
                  ),
                );
              }

              final entries = spendBy.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

              Color colorFor(String p) {
                final s = p.toLowerCase();
                if (s.contains('facebook')) return C.blue;
                if (s.contains('instagram')) return C.purple;
                if (s.contains('google')) return C.success;
                return C.gold;
              }

              return GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        height: 10,
                        child: Row(
                          children: entries.map((e) {
                            final f = (e.value / total).clamp(0.0, 1.0);
                            return Expanded(
                              flex: math.max(1, (f * 1000).round()),
                              child: Container(color: colorFor(e.key).withValues(alpha: 0.75)),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...entries.take(4).map((e) {
                      final p = (e.value / total) * 100.0;
                      final c = colorFor(e.key);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: c, shape: BoxShape.circle)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                e.key,
                                style: const TextStyle(color: C.textSecondary, fontSize: 11),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              U.money(e.value),
                              style: const TextStyle(color: C.textPrimary, fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              '${p.toStringAsFixed(1)}%',
                              style: TextStyle(color: c, fontSize: 11, fontWeight: FontWeight.w900),
                            ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // QUICK STATS
  // ══════════════════════════════════════════════════════════════

  Widget _quickStats(
    AsyncValue<List<Campaign>> campaignsAsync,
    AsyncValue<InsightsSummary> summaryAsync,
    AsyncValue<Map<String, dynamic>> crmStatsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'Quick Stats'),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: C.primary),
            ),
            error: (_, __) => _errorCard('Failed to load quick stats'),
            data: (campaigns) {
              final summary = summaryAsync.valueOrNull;
              final crm = crmStatsAsync.valueOrNull;

              final activeCampaigns = campaigns.where((c) => c.isActive).length;

              final totalImpressions =
                  summary?.totalImpressions ?? campaigns.fold<double>(0, (sum, c) => sum + c.impressions);
              final totalClicks =
                  summary?.totalClicks ?? campaigns.fold<double>(0, (sum, c) => sum + c.clicks);
              final totalOrders =
                  summary?.totalConversions ?? campaigns.fold<double>(0, (sum, c) => sum + c.conversions);
              final totalSpend =
                  summary?.totalSpend ?? campaigns.fold<double>(0, (sum, c) => sum + c.spend);

              final leadsToday =
                  (crm?['new_today'] as num?)?.toInt() ?? (crm?['newLeadsToday'] as num?)?.toInt() ?? 0;

              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  MetricCard(
                    label: 'Active',
                    value: activeCampaigns.toString(),
                    change: '',
                    isUp: true,
                    icon: Icons.campaign_rounded,
                    color: C.primary,
                  ),
                  MetricCard(
                    label: 'Impr.',
                    value: U.num(totalImpressions.toDouble()),
                    change: '',
                    isUp: true,
                    icon: Icons.visibility_rounded,
                    color: C.blue,
                  ),
                  MetricCard(
                    label: 'Clicks',
                    value: U.num(totalClicks.toDouble()),
                    change: '',
                    isUp: true,
                    icon: Icons.touch_app_rounded,
                    color: C.purple,
                  ),
                  MetricCard(
                    label: 'Orders',
                    value: U.num(totalOrders.toDouble()),
                    change: '',
                    isUp: true,
                    icon: Icons.shopping_bag_rounded,
                    color: C.success,
                  ),
                  MetricCard(
                    label: 'Spend',
                    value: U.money(totalSpend),
                    change: '',
                    isUp: true,
                    icon: Icons.account_balance_wallet_rounded,
                    color: C.pink,
                  ),
                  MetricCard(
                    label: 'Leads',
                    value: leadsToday.toString(),
                    change: '',
                    isUp: true,
                    icon: Icons.person_add_rounded,
                    color: C.gold,
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TOP CAMPAIGNS (uses _campaignSort from Options sheet)
  // ══════════════════════════════════════════════════════════════

  Widget _topCampaigns(AsyncValue<List<Campaign>> campaignsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          SectionHeader(
            title: 'Top Campaigns',
            action: 'View All',
            onAction: () => context.go('/campaigns'),
          ),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator(color: C.primary)),
            error: (e, _) => _errorCard('Failed to load campaigns: $e'),
            data: (campaigns) {
              if (campaigns.isEmpty) return _emptyConnectCard();

              final sorted = [...campaigns];
              switch (_campaignSort) {
                case _CampaignSort.roas:
                  sorted.sort((a, b) => b.roas.compareTo(a.roas));
                  break;
                case _CampaignSort.spend:
                  sorted.sort((a, b) => b.spend.compareTo(a.spend));
                  break;
                case _CampaignSort.cpa:
                  sorted.sort((a, b) => a.cpa.compareTo(b.cpa));
                  break;
              }

              final top = sorted.take(4).toList();
              return Column(
                children: top
                    .map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: CampaignTile(
                          name: c.name,
                          status: c.status,
                          platform: c.platform,
                          spend: c.spend,
                          roas: c.roas,
                          cpa: c.cpa,
                          onTap: () => context.push('/campaign-detail', extra: c),
                        ),
                      ),
                    )
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _emptyConnectCard() {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: C.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: C.primary.withValues(alpha: 0.25)),
            ),
            child: const Icon(Icons.link_rounded, color: C.primary),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No campaigns loaded',
                  style: TextStyle(color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w900),
                ),
                SizedBox(height: 2),
                Text(
                  'Connect to Worker to fetch real campaign data.',
                  style: TextStyle(color: C.textSecondary, fontSize: 11),
                ),
              ],
            ),
          ),
          OutlineBtn(
            label: 'Connect',
            icon: Icons.arrow_forward_rounded,
            onTap: () => context.go('/connect'),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // CRM SNAPSHOT
  // ══════════════════════════════════════════════════════════════

  int _intFrom(Map<String, dynamic>? m, List<String> keys) {
    if (m == null) return 0;
    for (final k in keys) {
      final v = m[k];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) {
        final p = int.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  double _doubleFrom(Map<String, dynamic>? m, List<String> keys) {
    if (m == null) return 0;
    for (final k in keys) {
      final v = m[k];
      if (v is double) return v;
      if (v is num) return v.toDouble();
      if (v is String) {
        final p = double.tryParse(v);
        if (p != null) return p;
      }
    }
    return 0;
  }

  Widget _crmSnapshot(AsyncValue<Map<String, dynamic>> crmStatsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          SectionHeader(
            title: 'CRM Snapshot',
            action: 'Open CRM',
            onAction: () => context.go('/crm'),
          ),
          const SizedBox(height: 10),
          crmStatsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(14),
              child: CircularProgressIndicator(color: C.primary),
            ),
            error: (e, _) => _errorCard('Failed to load CRM stats: $e'),
            data: (m) {
              final newCount = _intFrom(m, ['new', 'New', 'stage_new']);
              final contacted = _intFrom(m, ['contacted', 'Contacted', 'stage_contacted']);
              final qualified = _intFrom(m, ['qualified', 'Qualified', 'stage_qualified']);
              final converted = _intFrom(m, ['converted', 'Converted', 'stage_converted']);
              final lost = _intFrom(m, ['lost', 'Lost', 'stage_lost']);
              final pipelineValue = _doubleFrom(m, ['pipeline_value', 'pipelineValue', 'value']);

              return GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        _crmPill('New', '$newCount', C.info),
                        const SizedBox(width: 8),
                        _crmPill('Contacted', '$contacted', C.warning),
                        const SizedBox(width: 8),
                        _crmPill('Qualified', '$qualified', C.purple),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _crmPill('Converted', '$converted', C.success),
                        const SizedBox(width: 8),
                        _crmPill('Lost', '$lost', C.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                            decoration: BoxDecoration(
                              color: C.glassWhite,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: C.glassBorder),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.currency_rupee_rounded, color: C.gold, size: 16),
                                const SizedBox(width: 6),
                                const Expanded(
                                  child: Text('Pipeline', style: TextStyle(color: C.textMuted, fontSize: 10)),
                                ),
                                Text(
                                  U.money(pipelineValue),
                                  style: const TextStyle(color: C.gold, fontWeight: FontWeight.w900, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _crmPill(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: C.glassWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: C.glassBorder),
        ),
        child: Row(
          children: [
            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(color: C.textMuted, fontSize: 10),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              value,
              style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // Shared + helpers
  // ══════════════════════════════════════════════════════════════

  Widget _errorCard(String message) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: C.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(color: C.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  // Smoothed delta: last N avg vs prev N avg
  double _windowDeltaPct(List<double> data, {int window = 3}) {
    if (data.length < window * 2) return 0.0;
    final a = data.sublist(data.length - window, data.length);
    final b = data.sublist(data.length - window * 2, data.length - window);

    double avg(List<double> x) => x.reduce((p, c) => p + c) / x.length;

    final last = avg(a);
    final prev = avg(b);
    if (prev == 0) return 0.0;
    return ((last - prev) / prev) * 100.0;
  }

  String _timeAgo(DateTime dt) {
    final d = DateTime.now().difference(dt);
    if (d.inSeconds < 10) return 'just now';
    if (d.inMinutes < 1) return '${d.inSeconds}s ago';
    if (d.inHours < 1) return '${d.inMinutes}m ago';
    if (d.inDays < 1) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }

  double _clamp01(double v) => v < 0 ? 0 : (v > 1 ? 1 : v);

double _healthScore({
  required double roas,
  required double cpa,
  required double ctrPct,
  required int fatigueAlerts,
  required int openRecs,
}) {
  var score = 60.0;

  // ROAS
  if (roas >= 5) {
    score += 18;
  } else if (roas >= 3) {
    score += 10;
  } else if (roas >= 2) {
    score += 2;
  } else {
    score -= 12;
  }

  // CPA
  if (cpa <= 200) {
    score += 10;
  } else if (cpa <= 280) {
    score += 3;
  } else {
    score -= 10;
  }

  // CTR (avgCtr is percent like 3.8)
  if (ctrPct >= 3.0) {
    score += 6;
  } else if (ctrPct >= 1.5) {
    score += 2;
  } else {
    score -= 6;
  }

  // Ops penalties
  score -= math.min(18.0, fatigueAlerts * 2.0);
  score -= math.min(14.0, openRecs * 1.2);

  return score.clamp(0.0, 100.0);
}

  String _healthLabel(double score) {
    if (score >= 80) {
  return 'Excellent';
}
if (score >= 65) {
  return 'Healthy';
}
if (score >= 50) {
  return 'Watchlist';
}
return 'Critical';
  }

  String _efficiencyLabel(double roas, double cpa) {
    if (roas >= 4 && cpa <= 220) return 'Great';
    if (roas >= 2.5 && cpa <= 280) return 'Good';
    if (roas >= 2) return 'OK';
    return 'Poor';
  }

  Color _efficiencyColor(double roas, double cpa) {
    if (roas >= 4 && cpa <= 220) return C.success;
    if (roas >= 2.5 && cpa <= 280) return C.warning;
    if (roas >= 2) return C.textSecondary;
    return C.error;
  }
}

// ══════════════════════════════════════════════════════════════
// Ring Gauge (no deps)
// ══════════════════════════════════════════════════════════════

class _RingGauge extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final double size;
  final double stroke;

  const _RingGauge({
    required this.value,
    required this.color,
    required this.size,
    required this.stroke,
  });

  @override
  Widget build(BuildContext context) {
    final v = value.clamp(0.0, 1.0);
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _RingGaugePainter(value: v, color: color, stroke: stroke),
      ),
    );
  }
}

class _RingGaugePainter extends CustomPainter {
  final double value;
  final Color color;
  final double stroke;

  _RingGaugePainter({
    required this.value,
    required this.color,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) / 2) - stroke / 2;

    final bg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = C.glassBorder.withValues(alpha: 0.8);

    final fg = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: [color, color.withValues(alpha: 0.25)],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawCircle(center, radius, bg);

    final start = -math.pi / 2;
    final sweep = (2 * math.pi) * value;
    canvas.drawArc(Rect.fromCircle(center: center, radius: radius), start, sweep, false, fg);
  }

  @override
  bool shouldRepaint(covariant _RingGaugePainter old) {
    return old.value != value || old.color != color || old.stroke != stroke;
  }
}