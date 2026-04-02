import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../data/mock_data.dart';
import '../widgets/glass_card.dart';
import '../widgets/charts.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  int _period = 2; // 0=7D, 1=14D, 2=30D
  int _chartType = 0; // 0=ROAS, 1=Spend, 2=Revenue, 3=CPA

  final _roasData = <double>[2.8, 3.0, 3.2, 3.5, 3.3, 3.8, 4.0, 3.9, 4.2, 3.8, 4.1, 3.9, 4.3, 4.5, 4.2, 4.0, 4.4, 4.6, 4.3, 4.8, 4.5, 4.2, 4.6, 4.9, 4.7, 4.5, 4.8, 5.1, 4.9, 5.2];
  final _spendData = <double>[3200, 3500, 3800, 4100, 3900, 4200, 4400, 4300, 4600, 4100, 4400, 4200, 4600, 4800, 4500, 4300, 4700, 4900, 4600, 5100, 4800, 4500, 4900, 5200, 5000, 4800, 5100, 5400, 5200, 5500];
  final _revenueData = <double>[8960, 10500, 12160, 14350, 12870, 15960, 17600, 16770, 19320, 15580, 18040, 16380, 19780, 21600, 18900, 17200, 20680, 22540, 19780, 24480, 21600, 18900, 22540, 25480, 23500, 21600, 24480, 27540, 25480, 28600];
  final _cpaData = <double>[210, 195, 188, 175, 182, 168, 160, 164, 155, 170, 158, 165, 152, 148, 155, 162, 150, 145, 152, 140, 148, 155, 145, 138, 142, 148, 140, 132, 138, 130];

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); super.dispose(); }

  List<double> get _currentData {
    final all = switch (_chartType) { 0 => _roasData, 1 => _spendData, 2 => _revenueData, 3 => _cpaData, _ => _roasData };
    return switch (_period) { 0 => all.sublist(23), 1 => all.sublist(16), _ => all };
  }

  Color get _chartColor => switch (_chartType) { 0 => C.primary, 1 => C.blue, 2 => C.success, 3 => C.warning, _ => C.primary };

  @override
  Widget build(BuildContext context) {
    final campaigns = MockData.campaigns;
    final totalSpend = campaigns.fold(0.0, (s, c) => s + c.spend);
    final totalRevenue = campaigns.fold(0.0, (s, c) => s + c.revenue);
    final totalConversions = campaigns.fold(0, (s, c) => s + c.conversions);
    final avgRoas = totalSpend > 0 ? totalRevenue / totalSpend : 0.0;
    final avgCpa = totalConversions > 0 ? totalSpend / totalConversions : 0.0;

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3 + _bgC.value * 0.6, -0.6 + _bgC.value * 0.2),
                  radius: 1.5,
                  colors: [C.primary.withValues(alpha: 0.05), C.purple.withValues(alpha: 0.03), C.bgDeep],
                ),
              ),
            ),
          ),
          SafeArea(
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header()),
                SliverToBoxAdapter(child: _overviewCards(totalSpend, totalRevenue, avgRoas, avgCpa, totalConversions)),
                SliverToBoxAdapter(child: _mainChart()),
                SliverToBoxAdapter(child: _platformBreakdown(campaigns)),
                SliverToBoxAdapter(child: _objectiveBreakdown(campaigns)),
                SliverToBoxAdapter(child: _topPerformers(campaigns)),
                SliverToBoxAdapter(child: _conversionFunnel()),
                const SliverToBoxAdapter(child: SizedBox(height: 40)),
              ],
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
            child: Container(width: 38, height: 38, decoration: Glass.card(radius: 12), child: const Icon(Icons.arrow_back_ios_new_rounded, color: C.textPrimary, size: 16)),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Analytics', style: TextStyle(color: C.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                Text('Deep performance insights', style: TextStyle(color: C.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          OutlineBtn(label: 'Export', icon: Icons.file_download_outlined, onTap: () {}),
        ],
      ),
    );
  }

  Widget _overviewCards(double spend, double revenue, double roas, double cpa, int conversions) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GlassCard(
        radius: 20, turquoise: true, glow: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                _overviewItem('Total Spend', U.money(spend), C.blue),
                Container(width: 1, height: 34, color: C.glassBorder),
                _overviewItem('Revenue', U.money(revenue), C.success),
                Container(width: 1, height: 34, color: C.glassBorder),
                _overviewItem('ROAS', U.roas(roas), roas >= 4 ? C.success : C.warning),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(color: C.glassBorder, height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                _overviewItem('CPA', U.money(cpa), C.warning),
                Container(width: 1, height: 34, color: C.glassBorder),
                _overviewItem('Conversions', '$conversions', C.purple),
                Container(width: 1, height: 34, color: C.glassBorder),
                _overviewItem('Profit', U.money(revenue - spend), C.success),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _overviewItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _mainChart() {
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
                  // METRIC SELECTOR
                  Row(
                    children: ['ROAS', 'Spend', 'Revenue', 'CPA'].asMap().entries.map((e) {
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
                              border: sel ? null : Border.all(color: C.glassBorder),
                            ),
                            alignment: Alignment.center,
                            child: Text(e.value, style: TextStyle(color: sel ? Colors.black : C.textMuted, fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 10),
                  // PERIOD SELECTOR
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        decoration: BoxDecoration(color: C.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.glassBorder)),
                        child: Row(
                          children: ['7D', '14D', '30D'].asMap().entries.map((e) {
                            final sel = e.key == _period;
                            return GestureDetector(
                              onTap: () => setState(() => _period = e.key),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(gradient: sel ? C.primaryGrad : null, borderRadius: BorderRadius.circular(6)),
                                child: Text(e.value, style: TextStyle(color: sel ? Colors.black : C.textMuted, fontSize: 10, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
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
              child: RoasLineChart(data: _currentData, height: 160, color: _chartColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _platformBreakdown(List campaigns) {
    final fb = campaigns.where((c) => c.platform == 'Facebook').toList();
    final ig = campaigns.where((c) => c.platform == 'Instagram').toList();
    final fbSpend = fb.fold(0.0, (s, c) => s + c.spend);
    final igSpend = ig.fold(0.0, (s, c) => s + c.spend);
    final fbRevenue = fb.fold(0.0, (s, c) => s + c.revenue);
    final igRevenue = ig.fold(0.0, (s, c) => s + c.revenue);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Platform Breakdown'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _platformCard('Facebook', Icons.facebook_rounded, C.facebook, fb.length, fbSpend, fbRevenue)),
              const SizedBox(width: 10),
              Expanded(child: _platformCard('Instagram', Icons.camera_alt_rounded, C.instagram, ig.length, igSpend, igRevenue)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _platformCard(String name, IconData icon, Color color, int count, double spend, double revenue) {
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
                width: 32, height: 32,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(9)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(name, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
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
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
          Text(value, style: const TextStyle(color: C.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _objectiveBreakdown(List campaigns) {
    final groups = <String, List>{};
    for (final c in campaigns) {
      final obj = c.objective as String;
      groups.putIfAbsent(obj, () => []).add(c);
    }

    final segments = groups.entries.toList();
    final colors = [C.primary, C.blue, C.purple, C.pink, C.gold];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'By Objective'),
          const SizedBox(height: 10),
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                DonutChart(
                  size: 100,
                  segments: segments.asMap().entries.map((e) {
                    final spend = e.value.value.fold(0.0, (s, c) => s + c.spend);
                    return DonutSegment(value: spend, color: colors[e.key % colors.length], label: e.value.key);
                  }).toList(),
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('${campaigns.length}', style: const TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                      const Text('Total', style: TextStyle(color: C.textMuted, fontSize: 9)),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    children: segments.asMap().entries.map((e) {
                      final spend = e.value.value.fold(0.0, (s, c) => s + c.spend);
                      final color = colors[e.key % colors.length];
                      final objectiveName = e.value.key.replaceAll('OUTCOME_', '');
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Row(
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 8),
                            Expanded(child: Text(objectiveName, style: const TextStyle(color: C.textSecondary, fontSize: 11))),
                            Text(U.money(spend), style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _topPerformers(List campaigns) {
    final sorted = [...campaigns]..sort((a, b) => b.roas.compareTo(a.roas));
    final top = sorted.take(5);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Top Performers by ROAS'),
          const SizedBox(height: 10),
          GlassCard(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              children: top.toList().asMap().entries.map((e) {
                final c = e.value;
                final rank = e.key + 1;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          gradient: rank <= 3 ? C.primaryGrad : null,
                          color: rank > 3 ? C.glassWhite : null,
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('$rank', style: TextStyle(color: rank <= 3 ? Colors.black : C.textMuted, fontSize: 10, fontWeight: FontWeight.w700))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.name, style: const TextStyle(color: C.textPrimary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          gradient: c.roas >= 5 ? C.successGrad : c.roas >= 3 ? C.primaryGrad : C.dangerGrad,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('${c.roas.toStringAsFixed(1)}x', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800)),
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
  }

  Widget _conversionFunnel() {
    final funnel = [
      ('Impressions', 456500, C.blue),
      ('Clicks', 98260, C.purple),
      ('Add to Cart', 12400, C.pink),
      ('Checkout', 4800, C.warning),
      ('Purchase', 682, C.success),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Conversion Funnel'),
          const SizedBox(height: 10),
          GlassCard(
            radius: 18,
            padding: const EdgeInsets.all(16),
            child: Column(
              children: funnel.asMap().entries.map((e) {
                final (label, count, color) = e.value;
                final maxCount = funnel.first.$2;
                final pct = count / maxCount;
                final convRate = e.key > 0 ? (count / funnel[e.key - 1].$2 * 100).toStringAsFixed(1) : '100';

                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          SizedBox(width: 90, child: Text(label, style: const TextStyle(color: C.textSecondary, fontSize: 11))),
                          Expanded(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: Stack(
                                children: [
                                  Container(height: 18, decoration: BoxDecoration(color: C.glassWhite, borderRadius: BorderRadius.circular(4))),
                                  FractionallySizedBox(
                                    widthFactor: pct,
                                    child: Container(
                                      height: 18,
                                      decoration: BoxDecoration(color: color.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(4), border: Border.all(color: color.withValues(alpha: 0.5))),
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 6),
                                      child: Text(U.num(count.toDouble()), style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w700)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(width: 38, child: Text('$convRate%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600))),
                        ],
                      ),
                      if (e.key < funnel.length - 1)
                        Padding(
                          padding: const EdgeInsets.only(left: 90, top: 2, bottom: 2),
                          child: Row(
                            children: [
                              Icon(Icons.arrow_downward_rounded, color: C.textMuted.withValues(alpha: 0.3), size: 12),
                            ],
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
  }
}