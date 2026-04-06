import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import '../providers/app_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/campaign_tile.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});
  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  int _period = 1;


  String get _datePreset => _period == 0 ? 'last_7d' : 'last_30d';

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

    await Future.wait([
      ref.read(campaignsProvider.notifier).refresh(),
      ref.read(dashboardSummaryProvider(_datePreset).future),
      ref.read(dashboardDailyProvider(_datePreset).future),
      ref.read(notificationsCountProvider.future),
      ref.read(crmStatsProvider.future),
    ]);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Dashboard refreshed'),
        backgroundColor: C.success,
        duration: const Duration(seconds: 1),
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
                    -0.5 + _bgC.value * 0.3,
                    -0.8 + _bgC.value * 0.2,
                  ),
                  radius: 1.5,
                  colors: [
                    C.primary.withValues(alpha: 0.06),
                    C.purple.withValues(alpha: 0.04),
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
                    child: _appBar(unreadCountAsync.valueOrNull ?? 0),
                  ),
                  SliverToBoxAdapter(child: _alert(campaignsAsync)),
                  SliverToBoxAdapter(
                    child: _roasHero(summaryAsync, dailyAsync),
                  ),
                  SliverToBoxAdapter(
                    child: _quickStats(
                      campaignsAsync,
                      summaryAsync,
                      crmStatsAsync,
                    ),
                  ),
                  SliverToBoxAdapter(
  child: _topCampaigns(),
                  ),
                  SliverToBoxAdapter(
                    child: _aiInsight(campaignsAsync),
                  ),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
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

  Widget _appBar(int unreadCount) {
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
                  color: C.primary.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: const Icon(
              Icons.auto_awesome,
              color: Colors.black,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Kaapav Ad Engine',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Fashion Jewellery',
                  style: TextStyle(
                    color: C.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const LiveDot(),
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
  // ALERT BANNER
  // ══════════════════════════════════════════════════════════════

  Widget _alert(AsyncValue<List<Campaign>> campaignsAsync) {
    final campaigns = campaignsAsync.valueOrNull ?? [];
    final highSpend = campaigns
        .where((c) => c.dailyBudget > 0 && c.spend >= c.dailyBudget * 0.85)
        .length;

    if (highSpend == 0) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: C.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.electric_bolt_rounded,
                color: C.warning,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Budget Alert: $highSpend campaign${highSpend == 1 ? '' : 's'} near limit',
                    style: const TextStyle(
                      color: C.textPrimary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Text(
                    'Auto-scale enabled • Review recommended',
                    style: TextStyle(
                      color: C.textMuted,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: C.warning.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: C.warning.withValues(alpha: 0.3),
                ),
              ),
              child: const Text(
                'Review',
                style: TextStyle(
                  color: C.warning,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // ROAS HERO
  // ══════════════════════════════════════════════════════════════

  Widget _roasHero(
    AsyncValue<InsightsSummary> summaryAsync,
    AsyncValue<List<DayInsight>> dailyAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: GlassCard(
        radius: 22,
        turquoise: true,
        glow: true,
        padding: EdgeInsets.zero,
        child: summaryAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(20),
            child: SizedBox(
              height: 220,
              child: Center(child: CircularProgressIndicator(color: C.primary)),
            ),
          ),
          error: (_, __) => _errorCard('Failed to load performance summary'),
          data: (summary) {
            final chartData = dailyAsync.valueOrNull?.map((e) => e.roas).toList() ??
                <double>[summary.avgRoas];

            final previousRoas = chartData.length > 1
                ? chartData[chartData.length - 2]
                : summary.avgRoas;

            final roasChange = previousRoas == 0
                ? 0.0
                : ((summary.avgRoas - previousRoas) / previousRoas) * 100;

            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ROAS Performance',
                              style: TextStyle(
                                color: C.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  U.roas(summary.avgRoas),
                                  style: const TextStyle(
                                    color: C.textPrimary,
                                    fontSize: 34,
                                    fontWeight: FontWeight.w700,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 6),
                                  child: ChangePill(
                                    change:
                                        '${roasChange >= 0 ? '+' : ''}${roasChange.toStringAsFixed(1)}%',
                                    isUp: roasChange >= 0,
                                  ),
                                ),
                              ],
                            ),
                            const Text(
                              'Return on Ad Spend',
                              style: TextStyle(
                                color: C.textMuted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: C.bgCard,
                          borderRadius: BorderRadius.circular(10),
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
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Row(
                    children: [
                      _miniKpi('Spend', U.money(summary.totalSpend), C.blue,
                          Icons.paid_outlined),
                      _miniKpi(
                        'Revenue',
                        U.money(summary.totalRevenue),
                        C.success,
                        Icons.trending_up,
                      ),
                      _miniKpi(
                        'CPA',
                        U.money(summary.avgCpa),
                        C.warning,
                        Icons.ads_click,
                      ),
                      _miniKpi(
                        'CTR',
                        U.pct(summary.avgCtr),
                        C.purple,
                        Icons.touch_app,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
                  child: RoasLineChart(
                    data: chartData.isEmpty ? <double>[0] : chartData,
                    height: 130,
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
        setState(() {
          _period = index;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: sel ? C.primaryGrad : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: sel ? Colors.black : C.textMuted,
            fontSize: 11,
            fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    );
  }

  Widget _miniKpi(String label, String value, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color: C.textMuted,
              fontSize: 10,
            ),
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
              final totalImpressions = summary?.totalImpressions ??
                  campaigns.fold<double>(0, (sum, c) => sum + c.impressions);
              final totalClicks = summary?.totalClicks ??
                  campaigns.fold<double>(0, (sum, c) => sum + c.clicks);
              final totalOrders = summary?.totalConversions ??
                  campaigns.fold<double>(0, (sum, c) => sum + c.conversions);
              final totalSpend = summary?.totalSpend ??
                  campaigns.fold<double>(0, (sum, c) => sum + c.spend);
              final leadsToday =
                  (crm?['new_today'] as num?)?.toInt() ??
                  (crm?['newLeadsToday'] as num?)?.toInt() ??
                  0;

              return GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.95,
                children: [
                  MetricCard(
                    label: 'Active Campaigns',
                    value: activeCampaigns.toString(),
                    change: '',
                    isUp: true,
                    icon: Icons.campaign_rounded,
                    color: C.primary,
                  ),
                  MetricCard(
                    label: 'Impressions',
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
                    label: 'Total Spend',
                    value: U.money(totalSpend),
                    change: '',
                    isUp: true,
                    icon: Icons.account_balance_wallet,
                    color: C.pink,
                  ),
                  MetricCard(
                    label: 'Leads Today',
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
  // TOP CAMPAIGNS
  // ══════════════════════════════════════════════════════════════

  Widget _topCampaigns() {
  final campaignsAsync = ref.watch(campaignsProvider);

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
          error: (_, __) => _hardcodedCampaigns(), // fallback
          data: (campaigns) {
            if (campaigns.isEmpty) return _hardcodedCampaigns();
            final top = campaigns.take(4).toList();
            return Column(
              children: top.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: CampaignTile(
                  name: c.name,
                  status: c.status,
                  platform: c.platform,
                  spend: c.spend,
                  roas: c.roas,
                  cpa: c.cpa,
                ),
              )).toList(),
            );
          },
        ),
      ],
    ),
  );
}

Widget _hardcodedCampaigns() {
  return const Column(
    children: [
      CampaignTile(name: 'Navratri Jewellery Sale', status: 'Active', platform: 'Facebook', spend: 28400, roas: 6.2, cpa: 145),
      SizedBox(height: 8),
      CampaignTile(name: 'Reels - Gold Plated Set', status: 'Active', platform: 'Instagram', spend: 19200, roas: 5.8, cpa: 162),
      SizedBox(height: 8),
      CampaignTile(name: 'Lookalike 1% Buyers', status: 'Learning', platform: 'Facebook', spend: 12800, roas: 3.1, cpa: 210),
    ],
  );
}

  // ══════════════════════════════════════════════════════════════
  // AI INSIGHTS
  // Temporary derived insights until worker endpoint exists
  // ══════════════════════════════════════════════════════════════

  Widget _aiInsight(AsyncValue<List<Campaign>> campaignsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'AI Insights'),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(color: C.primary),
            ),
            error: (_, __) => _errorCard('Failed to load insights'),
            data: (campaigns) {
              if (campaigns.isEmpty) {
                return const SizedBox.shrink();
              }

              final sortedByRoas = [...campaigns]
                ..sort((a, b) => b.roas.compareTo(a.roas));

              final top = sortedByRoas.first;
              final fatigue = campaigns.firstWhere(
                (c) => c.frequency >= 3.5,
                orElse: () => campaigns.first,
              );
              final audience = campaigns.firstWhere(
                (c) => c.platform.toLowerCase().contains('facebook'),
                orElse: () => campaigns.first,
              );

              return Column(
                children: [
                  _insightCard(
                    Icons.trending_up,
                    C.success,
                    'Scale Opportunity',
                    '${top.name} ROAS ${U.roas(top.roas)} — consider scaling budget',
                    'Scale',
                  ),
                  const SizedBox(height: 8),
                  _insightCard(
                    Icons.warning_amber_rounded,
                    C.warning,
                    'Creative Fatigue',
                    '${fatigue.name} frequency ${fatigue.frequency.toStringAsFixed(1)}x — review creatives',
                    'Review',
                  ),
                  const SizedBox(height: 8),
                  _insightCard(
                    Icons.people_alt_rounded,
                    C.blue,
                    'Audience Tip',
                    '${audience.platform} campaigns are driving strong reach — create a dedicated audience test',
                    'Create',
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _insightCard(
    IconData icon,
    Color color,
    String title,
    String subtitle,
    String action,
  ) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: color.withValues(alpha: 0.2),
              ),
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
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: C.textSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: C.primaryGrad,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              action,
              style: const TextStyle(
                color: Colors.black,
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(String message) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: C.error),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: C.textSecondary,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}