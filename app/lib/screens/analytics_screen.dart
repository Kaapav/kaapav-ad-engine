import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import '../providers/app_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/glass_card.dart';

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  int _period = 2; // 0=7D, 1=14D, 2=30D
  int _chartType = 0; // 0=ROAS, 1=Spend, 2=Revenue, 3=CPA

  String get _datePreset => switch (_period) {
        0 => 'last_7d',
        1 => 'last_14d',
        _ => 'last_30d',
      };

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

  List<double> _chartDataFromDaily(List<DayInsight> daily) {
    switch (_chartType) {
      case 0:
        return daily.map((d) => d.roas).toList();
      case 1:
        return daily.map((d) => d.spend).toList();
      case 2:
        return daily.map((d) => d.revenue).toList();
      case 3:
        return daily.map((d) => d.cpa).toList();
      default:
        return daily.map((d) => d.roas).toList();
    }
  }

  Color get _chartColor => switch (_chartType) {
        0 => C.primary,
        1 => C.blue,
        2 => C.success,
        3 => C.warning,
        _ => C.primary,
      };

  String _chartLabel() => switch (_chartType) {
        0 => 'ROAS',
        1 => 'Spend',
        2 => 'Revenue',
        3 => 'CPA',
        _ => 'ROAS',
      };

  Future<void> _refresh() async {
    ref.invalidate(dashboardSummaryProvider(_datePreset));
    ref.invalidate(dashboardDailyProvider(_datePreset));
    ref.invalidate(campaignsProvider);

    await Future.wait([
      ref.read(dashboardSummaryProvider(_datePreset).future),
      ref.read(dashboardDailyProvider(_datePreset).future),
      ref.read(campaignsProvider.notifier).refresh(),
    ]);

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('✅ Analytics refreshed'),
        backgroundColor: C.success,
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(dashboardSummaryProvider(_datePreset));
    final dailyAsync = ref.watch(dashboardDailyProvider(_datePreset));
    final campaignsAsync = ref.watch(campaignsProvider);

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
                    -0.3 + _bgC.value * 0.6,
                    -0.6 + _bgC.value * 0.2,
                  ),
                  radius: 1.5,
                  colors: [
                    C.primary.withValues(alpha: 0.05),
                    C.purple.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              onRefresh: _refresh,
              color: C.primary,
              backgroundColor: C.bgCard,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _header()),
                  SliverToBoxAdapter(child: _overviewCards(summaryAsync)),
                  SliverToBoxAdapter(child: _mainChart(dailyAsync)),
                  SliverToBoxAdapter(child: _platformBreakdown(campaignsAsync)),
                  SliverToBoxAdapter(child: _objectiveBreakdown(campaignsAsync)),
                  SliverToBoxAdapter(child: _topPerformers(campaignsAsync)),
                  SliverToBoxAdapter(child: _conversionFunnel(summaryAsync)),
                  const SliverToBoxAdapter(child: SizedBox(height: 40)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38,
              height: 38,
              decoration: Glass.card(radius: 12),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: C.textPrimary,
                size: 16,
              ),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Analytics',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Deep performance insights',
                  style: TextStyle(
                    color: C.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          OutlineBtn(
            label: 'Export',
            icon: Icons.file_download_outlined,
            onTap: () {},
          ),
        ],
      ),
    );
  }

  Widget _overviewCards(AsyncValue<InsightsSummary> summaryAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: summaryAsync.when(
        loading: () => const _AnalyticsLoadingCard(height: 150),
        error: (error, _) => _errorCard('Failed to load overview'),
        data: (summary) {
          final profit = summary.totalRevenue - summary.totalSpend;

          return GlassCard(
            radius: 20,
            turquoise: true,
            glow: true,
            padding: const EdgeInsets.all(18),
            child: Column(
              children: [
                Row(
                  children: [
                    _overviewItem('Total Spend', U.money(summary.totalSpend), C.blue),
                    Container(width: 1, height: 34, color: C.glassBorder),
                    _overviewItem('Revenue', U.money(summary.totalRevenue), C.success),
                    Container(width: 1, height: 34, color: C.glassBorder),
                    _overviewItem(
                      'ROAS',
                      U.roas(summary.avgRoas),
                      summary.avgRoas >= 4 ? C.success : C.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                const Divider(color: C.glassBorder, height: 1),
                const SizedBox(height: 14),
                Row(
                  children: [
                    _overviewItem('CPA', U.money(summary.avgCpa), C.warning),
                    Container(width: 1, height: 34, color: C.glassBorder),
                    _overviewItem(
                      'Conversions',
                      U.num(summary.totalConversions.toDouble()),
                      C.purple,
                    ),
                    Container(width: 1, height: 34, color: C.glassBorder),
                    _overviewItem('Profit', U.money(profit), C.success),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _overviewItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
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
      ),
    );
  }

  Widget _mainChart(AsyncValue<List<DayInsight>> dailyAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Column(
                children: [
                  Row(
                    children: ['ROAS', 'Spend', 'Revenue', 'CPA']
                        .asMap()
                        .entries
                        .map((e) {
                      final sel = e.key == _chartType;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _chartType = e.key),
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            padding: const EdgeInsets.symmetric(vertical: 7),
                            decoration: BoxDecoration(
                              gradient: sel ? C.primaryGrad : null,
                              color: sel ? null : C.glassWhite,
                              borderRadius: BorderRadius.circular(8),
                              border:
                                  sel ? null : Border.all(color: C.glassBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              e.value,
                              style: TextStyle(
                                color: sel ? Colors.black : C.textMuted,
                                fontSize: 11,
                                fontWeight:
                                    sel ? FontWeight.w700 : FontWeight.w400,
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: C.bgCard,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: C.glassBorder),
                        ),
                        child: Row(
                          children: ['7D', '14D', '30D'].asMap().entries.map((e) {
                            final sel = e.key == _period;
                            return GestureDetector(
                              onTap: () => setState(() => _period = e.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  gradient: sel ? C.primaryGrad : null,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  e.value,
                                  style: TextStyle(
                                    color: sel ? Colors.black : C.textMuted,
                                    fontSize: 10,
                                    fontWeight:
                                        sel ? FontWeight.w700 : FontWeight.w400,
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
              child: dailyAsync.when(
                loading: () => const SizedBox(
                  height: 160,
                  child: Center(
                    child: CircularProgressIndicator(color: C.primary),
                  ),
                ),
                error: (_, __) => SizedBox(
                  height: 160,
                  child: Center(
                    child: Text(
                      'Failed to load ${_chartLabel()} chart',
                      style: const TextStyle(color: C.textSecondary),
                    ),
                  ),
                ),
                data: (daily) {
                  final data = _chartDataFromDaily(daily);
                  return RoasLineChart(
                    data: data.isEmpty ? <double>[0] : data,
                    height: 160,
                    color: _chartColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformBreakdown(AsyncValue<List<Campaign>> campaignsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Platform Breakdown'),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const _AnalyticsLoadingCard(height: 140),
            error: (_, __) => _errorCard('Failed to load platform breakdown'),
            data: (campaigns) {
              final fb = campaigns.where((c) => c.platform == 'Facebook').toList();
              final ig = campaigns.where((c) => c.platform == 'Instagram').toList();

              final fbSpend = fb.fold<double>(0, (s, c) => s + c.spend);
              final igSpend = ig.fold<double>(0, (s, c) => s + c.spend);
              final fbRevenue = fb.fold<double>(0, (s, c) => s + c.revenue);
              final igRevenue = ig.fold<double>(0, (s, c) => s + c.revenue);

              return Row(
                children: [
                  Expanded(
                    child: _platformCard(
                      'Facebook',
                      Icons.facebook_rounded,
                      C.facebook,
                      fb.length,
                      fbSpend,
                      fbRevenue,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _platformCard(
                      'Instagram',
                      Icons.camera_alt_rounded,
                      C.instagram,
                      ig.length,
                      igSpend,
                      igRevenue,
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

  Widget _platformCard(
    String name,
    IconData icon,
    Color color,
    int count,
    double spend,
    double revenue,
  ) {
    final roas = spend > 0 ? revenue / spend : 0.0;

    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _miniRow('Campaigns', '$count'),
          _miniRow('Spend', U.money(spend)),
          _miniRow('Revenue', U.money(revenue)),
          _miniRow('ROAS', U.roas(roas)),
        ],
      ),
    );
  }

  Widget _miniRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: C.textMuted,
              fontSize: 10,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: C.textPrimary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _objectiveBreakdown(AsyncValue<List<Campaign>> campaignsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'By Objective'),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const _AnalyticsLoadingCard(height: 160),
            error: (_, __) => _errorCard('Failed to load objective breakdown'),
            data: (campaigns) {
              final groups = <String, List<Campaign>>{};
              for (final c in campaigns) {
                groups.putIfAbsent(c.objective, () => []).add(c);
              }

              final segments = groups.entries.toList();
              final colors = [C.primary, C.blue, C.purple, C.pink, C.gold];

              return GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    DonutChart(
                      size: 100.0,
                      segments: segments.asMap().entries.map((e) {
                        final spend = e.value.value
                            .fold<double>(0, (s, c) => s + c.spend);
                        return DonutSegment(
                          value: spend,
                          color: colors[e.key % colors.length],
                          label: e.value.key,
                        );
                      }).toList(),
                      center: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${campaigns.length}',
                            style: const TextStyle(
                              color: C.textPrimary,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const Text(
                            'Total',
                            style: TextStyle(
                              color: C.textMuted,
                              fontSize: 9,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        children: segments.asMap().entries.map((e) {
                          final spend = e.value.value
                              .fold<double>(0, (s, c) => s + c.spend);
                          final color = colors[e.key % colors.length];
                          final objectiveName =
                              e.value.key.replaceAll('OUTCOME_', '');

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    objectiveName,
                                    style: const TextStyle(
                                      color: C.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ),
                                Text(
                                  U.money(spend),
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
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

  Widget _topPerformers(AsyncValue<List<Campaign>> campaignsAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Top Performers by ROAS'),
          const SizedBox(height: 10),
          campaignsAsync.when(
            loading: () => const _AnalyticsLoadingCard(height: 180),
            error: (_, __) => _errorCard('Failed to load top performers'),
            data: (campaigns) {
              final sorted = [...campaigns]
                ..sort((a, b) => b.roas.compareTo(a.roas));
              final top = sorted.take(5).toList();

              return GlassCard(
                radius: 16,
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: top.asMap().entries.map((e) {
                    final c = e.value;
                    final rank = e.key + 1;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 24,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: rank <= 3 ? C.primaryGrad : null,
                              color: rank > 3 ? C.glassWhite : null,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                '$rank',
                                style: TextStyle(
                                  color: rank <= 3
                                      ? Colors.black
                                      : C.textMuted,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              c.name,
                              style: const TextStyle(
                                color: C.textPrimary,
                                fontSize: 12,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: c.roas >= 5
                                  ? C.successGrad
                                  : c.roas >= 3
                                      ? C.primaryGrad
                                      : C.dangerGrad,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '${c.roas.toStringAsFixed(1)}x',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _conversionFunnel(AsyncValue<InsightsSummary> summaryAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Conversion Funnel'),
          const SizedBox(height: 10),
          summaryAsync.when(
            loading: () => const _AnalyticsLoadingCard(height: 220),
            error: (_, __) => _errorCard('Failed to load conversion funnel'),
            data: (summary) {
final impressions = summary.totalImpressions.toDouble();
final clicks = summary.totalClicks.toDouble();
final conversions = summary.totalConversions.toDouble();

// Temporary derived funnel until worker provides dedicated funnel API
final addToCart = clicks * 0.13;
final checkout = addToCart * 0.39;
final purchase = conversions;

final funnel = <(String, double, Color)>[
  ('Impressions', impressions, C.blue),
  ('Clicks', clicks, C.purple),
  ('Add to Cart', addToCart, C.pink),
  ('Checkout', checkout, C.warning),
  ('Purchase', purchase, C.success),
];

              return GlassCard(
                radius: 18,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: funnel.asMap().entries.map((e) {
                    final (label, count, color) = e.value;
                    final maxCount = funnel.first.$2 == 0 ? 1 : funnel.first.$2;
                    final pct = count / maxCount;
                    final prev = e.key > 0 ? funnel[e.key - 1].$2 : count;
                    final convRate =
                        prev == 0 ? 0.0 : (count / prev * 100);

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(
                                width: 90,
                                child: Text(
                                  label,
                                  style: const TextStyle(
                                    color: C.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Stack(
                                    children: [
                                      Container(
                                        height: 18,
                                        decoration: BoxDecoration(
                                          color: C.glassWhite,
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                      ),
                                      FractionallySizedBox(
                                        widthFactor: pct.clamp(0.0, 1.0),
                                        child: Container(
                                          height: 18,
                                          decoration: BoxDecoration(
                                            color: color.withValues(alpha: 0.3),
                                            borderRadius:
                                                BorderRadius.circular(4),
                                            border: Border.all(
                                              color: color.withValues(alpha: 0.5),
                                            ),
                                          ),
                                          alignment: Alignment.centerRight,
                                          padding: const EdgeInsets.only(right: 6),
                                          child: Text(
                                            U.num(count.toDouble()),
                                            style: TextStyle(
                                              color: color,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 42,
                                child: Text(
                                  '${convRate.toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    color: color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (e.key < funnel.length - 1)
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 90,
                                top: 2,
                                bottom: 2,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.arrow_downward_rounded,
                                    color: C.textMuted.withValues(alpha: 0.3),
                                    size: 12,
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              );
            },
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

class _AnalyticsLoadingCard extends StatelessWidget {
  const _AnalyticsLoadingCard({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        height: height,
        child: const Center(
          child: CircularProgressIndicator(color: C.primary),
        ),
      ),
    );
  }
}