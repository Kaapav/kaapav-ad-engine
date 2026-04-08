import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/campaign.dart';
import '../providers/app_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_badge.dart';

class CampaignDetailScreen extends ConsumerStatefulWidget {
  final Campaign campaign;

  const CampaignDetailScreen({
    super.key,
    required this.campaign,
  });

  @override
  ConsumerState<CampaignDetailScreen> createState() =>
      _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends ConsumerState<CampaignDetailScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  int _chartMetric = 0; // 0=ROAS, 1=Spend
  bool _busy = false;

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

  void _snack(String msg, {Color? color}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: color ?? C.bgCard,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _notReady(String feature) {
    _snack('$feature not implemented yet.', color: C.bgCard);
  }

  Future<void> _refresh() async {
    ref.invalidate(campaignDetailProvider(widget.campaign.id));
    ref.invalidate(campaignsProvider);

    await Future.wait([
      ref.read(campaignDetailProvider(widget.campaign.id).future),
      ref.read(campaignsProvider.notifier).refresh(),
    ]);
  }

  Future<void> _toggleStatus(Campaign c) async {
    if (_busy) return;
    _busy = true;

    final wasActive = c.isActive;

    final notifier = ref.read(campaignsProvider.notifier);
    try {
      await notifier.toggleStatus(c.id);
      ref.invalidate(campaignDetailProvider(c.id));

      if (!mounted) return;
      _snack(
        wasActive ? 'Campaign paused' : 'Campaign activated',
        color: C.bgCard,
      );
    } catch (_) {
      if (!mounted) return;
      _snack('Failed to update status', color: C.error);
    } finally {
      _busy = false;
    }
  }

  Future<void> _applyBudgetScale(Campaign c, double newBudget) async {
    if (_busy) return;
    _busy = true;

    final notifier = ref.read(campaignsProvider.notifier);
    try {
      await notifier.scaleBudget(c.id, newBudget);
      ref.invalidate(campaignDetailProvider(c.id));

      if (!mounted) return;
      _snack('Budget scaled to ${U.money(newBudget)}/day');
    } catch (_) {
      if (!mounted) return;
      _snack('Failed to scale budget', color: C.error);
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final campaignAsync = ref.watch(campaignDetailProvider(widget.campaign.id));
    final c = campaignAsync.valueOrNull ?? widget.campaign;

    final isFb = c.platform.toLowerCase() == 'facebook';
    final platformColor = isFb ? C.facebook : C.instagram;

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
                    -0.7 + _bgC.value * 0.2,
                  ),
                  radius: 1.5,
                  colors: [
                    platformColor.withValues(alpha: 0.06),
                    C.primary.withValues(alpha: 0.03),
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
                  SliverToBoxAdapter(child: _header(c, isFb)),
                  if (campaignAsync.isLoading)
                    const SliverToBoxAdapter(
                      child: Padding(
                        padding: EdgeInsets.only(top: 10),
                        child: Center(
                          child: CircularProgressIndicator(color: C.primary),
                        ),
                      ),
                    ),
                  SliverToBoxAdapter(child: _statusActions(c)),
                  SliverToBoxAdapter(child: _heroMetrics(c)),
                  SliverToBoxAdapter(child: _performanceChart(c)),
                  SliverToBoxAdapter(child: _metricsGrid(c)),
                  if (c.adSets.isNotEmpty)
                    SliverToBoxAdapter(child: _adSetsSection(c)),
                  SliverToBoxAdapter(child: _actionsSection(c)),
                  const SliverToBoxAdapter(child: SizedBox(height: 100)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(Campaign c, bool isFb) {
    final platformGrad = LinearGradient(
      colors: isFb
          ? [C.facebook, const Color(0xFF0A5BC4)]
          : [C.instagram, const Color(0xFF833AB4)],
    );

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
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: platformGrad,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              isFb ? Icons.facebook_rounded : Icons.camera_alt_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  c.name,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                Row(
                  children: [
                    Text(
                      K.objectives[c.objective] ?? c.objective,
                      style: const TextStyle(
                        color: C.textSecondary,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('•', style: TextStyle(color: C.textMuted)),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        K.bidStrategies[c.bidStrategy] ?? c.bidStrategy,
                        style: const TextStyle(
                          color: C.textMuted,
                          fontSize: 11,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          GlassIconBtn(
            icon: Icons.more_vert_rounded,
            onTap: () => _showMoreSheet(c),
          ),
        ],
      ),
    );
  }

  Widget _statusActions(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            StatusBadge(status: c.status),
            const SizedBox(width: 10),
            Text(
              'Since ${c.startDate != null ? U.dateFull(c.startDate!) : '—'}',
              style: const TextStyle(color: C.textMuted, fontSize: 11),
            ),
            const Spacer(),
            GestureDetector(
              onTap: () async {
                HapticFeedback.mediumImpact();
                await _toggleStatus(c);
              },
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: c.isActive ? C.dangerGrad : C.successGrad,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      c.isActive
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      c.isActive ? 'Pause' : 'Activate',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _heroMetrics(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GlassCard(
        radius: 20,
        turquoise: true,
        glow: true,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            _heroItem(
              'ROAS',
              U.roas(c.roas),
              c.roas >= 4 ? C.success : (c.roas >= 2 ? C.primary : C.error),
            ),
            _divider(),
            _heroItem('Spend', U.money(c.spend), C.blue),
            _divider(),
            _heroItem('Revenue', U.money(c.revenue), C.success),
            _divider(),
            _heroItem('CPA', U.money(c.cpa), c.cpa <= 150 ? C.success : C.warning),
          ],
        ),
      ),
    );
  }

  Widget _heroItem(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: C.glassBorder);

  Widget _performanceChart(Campaign c) {
    final data = _chartMetric == 0 ? c.roasHistory : c.spendHistory;
    if (data.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: GlassCard(
        radius: 20,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 0),
              child: Row(
                children: [
                  const Text(
                    'Performance',
                    style: TextStyle(
                      color: C.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(
                      color: C.bgCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: C.glassBorder),
                    ),
                    child: Row(
                      children: ['ROAS', 'Spend'].asMap().entries.map((e) {
                        final sel = e.key == _chartMetric;
                        return GestureDetector(
                          onTap: () => setState(() => _chartMetric = e.key),
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
                                fontWeight: sel
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 14),
              child: RoasLineChart(
                data: data,
                height: 140,
                color: _chartMetric == 0 ? C.primary : C.blue,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricsGrid(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'All Metrics'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.0,
            children: [
              MetricCard(
                label: 'Impressions',
                value: U.num(c.impressions.toDouble()),
                icon: Icons.visibility_rounded,
                color: C.blue,
              ),
              MetricCard(
                label: 'Reach',
                value: U.num(c.reach.toDouble()),
                icon: Icons.people_outline,
                color: C.purple,
              ),
              MetricCard(
                label: 'Clicks',
                value: U.num(c.clicks.toDouble()),
                icon: Icons.touch_app_rounded,
                color: C.pink,
              ),
              MetricCard(
                label: 'CTR',
                value: U.pct(c.ctr),
                icon: Icons.ads_click,
                color: C.primary,
              ),
              MetricCard(
                label: 'CPC',
                value: U.money(c.cpc),
                icon: Icons.payments_outlined,
                color: C.warning,
              ),
              MetricCard(
                label: 'CPM',
                value: U.money(c.cpm),
                icon: Icons.price_change_outlined,
                color: C.info,
              ),
              MetricCard(
                label: 'Conversions',
                value: '${c.conversions}',
                icon: Icons.shopping_bag_rounded,
                color: C.success,
              ),
              MetricCard(
                label: 'Frequency',
                value: c.frequency.toStringAsFixed(2),
                icon: Icons.repeat_rounded,
                color: c.frequency >= 3.5 ? C.warning : C.textSecondary,
              ),
              MetricCard(
                label: 'Daily Budget',
                value: U.money(c.dailyBudget),
                icon: Icons.account_balance_wallet,
                color: C.gold,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adSetsSection(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          SectionHeader(title: 'Ad Sets (${c.adSets.length})'),
          const SizedBox(height: 10),
          ...c.adSets.map(
            (as_) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _adSetTile(as_),
            ),
          ),
        ],
      ),
    );
  }

  Widget _adSetTile(AdSet adSet) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  adSet.name,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              StatusBadge(status: adSet.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _adSetMetric(
                'ROAS',
                U.roas(adSet.roas),
                adSet.roas >= 4 ? C.success : C.primary,
              ),
              _adSetMetric('Spend', U.money(adSet.spend), C.blue),
              _adSetMetric('CPA', U.money(adSet.cpa), C.warning),
              _adSetMetric('CTR', U.pct(adSet.ctr), C.purple),
              _adSetMetric('Conv.', '${adSet.conversions}', C.success),
            ],
          ),
        ],
      ),
    );
  }

  Widget _adSetMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _actionsSection(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  Icons.trending_up,
                  'Scale Budget',
                  C.success,
                  () => _showScaleSheet(c),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  Icons.people_alt_rounded,
                  'Open CRM',
                  C.purple,
                  () => context.go('/crm'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _actionBtn(
                  Icons.insights_rounded,
                  'Analytics',
                  C.blue,
                  () => context.push('/more/analytics'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _actionBtn(
                  Icons.table_chart_rounded,
                  'Sheets',
                  C.success,
                  () => context.push('/more/sheets'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showScaleSheet(Campaign c) {
    double scalePct = 20;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: Glass.blur,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [C.bgCard, C.bgDeep]),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: C.glassBorder),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  const SizedBox(height: 16),
                  const Text(
                    'Scale Budget',
                    style: TextStyle(
                      color: C.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Current: ${U.money(c.dailyBudget)}/day',
                    style: const TextStyle(
                      color: C.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '+${scalePct.toInt()}%',
                        style: const TextStyle(
                          color: C.primary,
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '→ ${U.money(c.dailyBudget * (1 + scalePct / 100))}/day',
                        style: const TextStyle(
                          color: C.success,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Slider(
                    value: scalePct,
                    min: 10,
                    max: 100,
                    divisions: 9,
                    activeColor: C.primary,
                    inactiveColor: C.glassBorder,
                    onChanged: (v) => setModalState(() => scalePct = v),
                  ),
                  const SizedBox(height: 20),
                  PrimaryBtn(
                    label: 'Apply Scale',
                    icon: Icons.trending_up,
                    onTap: () async {
                      final newBudget = c.dailyBudget * (1 + scalePct / 100);
                      Navigator.pop(context);
                      await _applyBudgetScale(c, newBudget);
                    },
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showMoreSheet(Campaign c) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: Glass.blur,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.bgCard, C.bgDeep]),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: C.glassBorder),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                const SizedBox(height: 16),
                _sheetOption(
                  Icons.copy_rounded,
                  'Copy Campaign ID',
                  C.primary,
                  () async {
                    await Clipboard.setData(ClipboardData(text: c.id));
                    if (!mounted) return;
                    _snack('✅ Campaign ID copied');
                  },
                ),
                _sheetOption(
                  Icons.picture_as_pdf_rounded,
                  'Export Report',
                  C.success,
                  () => _notReady('Export report'),
                ),
                _sheetOption(
                  Icons.content_copy_rounded,
                  'Duplicate Campaign',
                  C.blue,
                  () => _notReady('Duplicate campaign'),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(
        label,
        style: TextStyle(
          color: color == C.error ? C.error : C.textPrimary,
          fontSize: 14,
        ),
      ),
      onTap: () {
        Navigator.pop(context);
        onTap();
      },
    );
  }
}