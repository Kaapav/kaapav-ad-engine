import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/campaign.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/status_badge.dart';
import '../widgets/charts.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

class CampaignDetailScreen extends StatefulWidget {
  final Campaign campaign;
  const CampaignDetailScreen({super.key, required this.campaign});
  @override
  State<CampaignDetailScreen> createState() => _CampaignDetailScreenState();
}

class _CampaignDetailScreenState extends State<CampaignDetailScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  late Campaign _campaign;
  int _chartMetric = 0; // 0=ROAS, 1=Spend

  @override
  void initState() {
    super.initState();
    _campaign = widget.campaign;
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final c = _campaign;
    final isFb = c.platform.toLowerCase() == 'facebook';

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          // ANIMATED BG
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.3 + _bgC.value * 0.6, -0.7 + _bgC.value * 0.2),
                  radius: 1.5,
                  colors: [
                    (isFb ? C.facebook : C.instagram).withValues(alpha: 0.06),
                    C.primary.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // BACK + TITLE
                SliverToBoxAdapter(child: _header(c, isFb)),
                // STATUS + QUICK ACTIONS
                SliverToBoxAdapter(child: _statusActions(c)),
                // HERO METRICS
                SliverToBoxAdapter(child: _heroMetrics(c)),
                // PERFORMANCE CHART
                SliverToBoxAdapter(child: _performanceChart(c)),
                // FULL METRICS GRID
                SliverToBoxAdapter(child: _metricsGrid(c)),
                // AD SETS
                if (c.adSets.isNotEmpty) SliverToBoxAdapter(child: _adSetsSection(c)),
                // ACTIONS
                SliverToBoxAdapter(child: _actionsSection(c)),
                // BOTTOM PADDING
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ HEADER ═══
  Widget _header(Campaign c, bool isFb) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: Glass.card(radius: 12),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: C.textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isFb ? [C.facebook, const Color(0xFF0A5BC4)] : [C.instagram, const Color(0xFF833AB4)],
              ),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(isFb ? Icons.facebook_rounded : Icons.camera_alt_rounded, color: Colors.white, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.name, style: const TextStyle(color: C.textPrimary, fontSize: 15, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                Row(
                  children: [
                    Text(K.objectives[c.objective] ?? c.objective, style: const TextStyle(color: C.textSecondary, fontSize: 11)),
                    const SizedBox(width: 6),
                    Text('•', style: TextStyle(color: C.textMuted)),
                    const SizedBox(width: 6),
                    Text(K.bidStrategies[c.bidStrategy] ?? c.bidStrategy, style: const TextStyle(color: C.textMuted, fontSize: 11)),
                  ],
                ),
              ],
            ),
          ),
          GlassIconBtn(icon: Icons.more_vert_rounded, onTap: () => _showMoreSheet(c)),
        ],
      ),
    );
  }

  // ═══ STATUS + QUICK ACTIONS ═══
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
            Text('Since ${U.dateFull(c.startDate)}', style: const TextStyle(color: C.textMuted, fontSize: 11)),
            const Spacer(),
            // TOGGLE
            GestureDetector(
              onTap: () {
                HapticFeedback.mediumImpact();
                setState(() {
                  _campaign = c.copyWith(status: c.isActive ? 'Paused' : 'Active');
                });
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Campaign ${_campaign.isActive ? "activated" : "paused"}'),
                  backgroundColor: C.bgCard,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: c.isActive ? C.dangerGrad : C.successGrad,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(c.isActive ? Icons.pause_rounded : Icons.play_arrow_rounded, color: Colors.white, size: 14),
                    const SizedBox(width: 4),
                    Text(c.isActive ? 'Pause' : 'Activate', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ HERO METRICS ═══
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
            _heroItem('ROAS', U.roas(c.roas), c.roas >= 4 ? C.success : c.roas >= 2 ? C.primary : C.error),
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
          Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  Widget _divider() => Container(width: 1, height: 36, color: C.glassBorder);

  // ═══ PERFORMANCE CHART ═══
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
                  const Text('Performance', style: TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Container(
                    decoration: BoxDecoration(color: C.bgCard, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.glassBorder)),
                    child: Row(
                      children: ['ROAS', 'Spend'].asMap().entries.map((e) {
                        final sel = e.key == _chartMetric;
                        return GestureDetector(
                          onTap: () => setState(() => _chartMetric = e.key),
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

  // ═══ FULL METRICS GRID ═══
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
              MetricCard(label: 'Impressions', value: U.num(c.impressions.toDouble()), icon: Icons.visibility_rounded, color: C.blue),
              MetricCard(label: 'Reach', value: U.num(c.reach.toDouble()), icon: Icons.people_outline, color: C.purple),
              MetricCard(label: 'Clicks', value: U.num(c.clicks.toDouble()), icon: Icons.touch_app_rounded, color: C.pink),
              MetricCard(label: 'CTR', value: U.pct(c.ctr), icon: Icons.ads_click, color: C.primary),
              MetricCard(label: 'CPC', value: U.money(c.cpc), icon: Icons.payments_outlined, color: C.warning),
              MetricCard(label: 'CPM', value: U.money(c.cpm), icon: Icons.price_change_outlined, color: C.info),
              MetricCard(label: 'Conversions', value: '${c.conversions}', icon: Icons.shopping_bag_rounded, color: C.success),
              MetricCard(label: 'Frequency', value: c.frequency.toStringAsFixed(2), icon: Icons.repeat_rounded, color: c.frequency > 3 ? C.error : C.textSecondary),
              MetricCard(label: 'Daily Budget', value: U.money(c.dailyBudget), icon: Icons.account_balance_wallet, color: C.gold),
            ],
          ),
        ],
      ),
    );
  }

  // ═══ AD SETS SECTION ═══
  Widget _adSetsSection(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          SectionHeader(title: 'Ad Sets (${c.adSets.length})'),
          const SizedBox(height: 10),
          ...c.adSets.map((as_) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _adSetTile(as_),
              )),
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
                child: Text(adSet.name, style: const TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              StatusBadge(status: adSet.status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _adSetMetric('ROAS', U.roas(adSet.roas), adSet.roas >= 4 ? C.success : C.primary),
              _adSetMetric('Spend', U.money(adSet.spend), C.blue),
              _adSetMetric('CPA', U.money(adSet.cpa), C.warning),
              _adSetMetric('CTR', U.pct(adSet.ctr), C.purple),
              _adSetMetric('Conv.', '${adSet.conversions}', C.success),
            ],
          ),
          // TARGETING INFO
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: C.glassWhite,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.glassBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _targetRow('👤', '${adSet.targeting.genders.join(", ")} • ${adSet.targeting.ageMin}-${adSet.targeting.ageMax}'),
                if (adSet.targeting.locations.isNotEmpty)
                  _targetRow('📍', adSet.targeting.locations.join(', ')),
                if (adSet.targeting.interests.isNotEmpty)
                  _targetRow('🎯', adSet.targeting.interests.join(', ')),
                if (adSet.targeting.lookalike != null)
                  _targetRow('👥', adSet.targeting.lookalike!),
                if (adSet.targeting.customAudience != null)
                  _targetRow('🔄', adSet.targeting.customAudience!),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _adSetMetric(String label, String value, Color color) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 1),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _targetRow(String emoji, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 11)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: C.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }

  // ═══ ACTIONS SECTION ═══
  Widget _actionsSection(Campaign c) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
      child: Column(
        children: [
          const SectionHeader(title: 'Quick Actions'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _actionBtn(Icons.trending_up, 'Scale Budget', C.success, () => _showScaleSheet(c))),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.content_copy_rounded, 'Duplicate', C.blue, () {})),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(child: _actionBtn(Icons.people_alt_rounded, 'View Leads', C.purple, () {})),
              const SizedBox(width: 8),
              Expanded(child: _actionBtn(Icons.insights_rounded, 'Export Report', C.primary, () {})),
            ],
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: C.glassBorder),
              ),
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(2)))),
                  const SizedBox(height: 16),
                  const Text('Scale Budget', style: TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('Current: ${U.money(c.dailyBudget)}/day', style: const TextStyle(color: C.textSecondary, fontSize: 13)),
                  const SizedBox(height: 20),
                  // SLIDER
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('+${scalePct.toInt()}%', style: const TextStyle(color: C.primary, fontSize: 28, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 12),
                      Text('→ ${U.money(c.dailyBudget * (1 + scalePct / 100))}/day', style: const TextStyle(color: C.success, fontSize: 16, fontWeight: FontWeight.w600)),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: ['+10%', '+25%', '+50%', '+100%'].map((t) => Text(t, style: const TextStyle(color: C.textMuted, fontSize: 10))).toList(),
                  ),
                  const SizedBox(height: 20),
                  PrimaryBtn(
                    label: 'Apply Scale',
                    icon: Icons.trending_up,
                    onTap: () {
                      final newBudget = c.dailyBudget * (1 + scalePct / 100);
                      setState(() => _campaign = c.copyWith(dailyBudget: newBudget));
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text('Budget scaled to ${U.money(newBudget)}/day'),
                        backgroundColor: C.bgCard,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ));
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
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: C.glassBorder),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                _sheetOption(Icons.edit_rounded, 'Edit Campaign', C.primary, () {}),
                _sheetOption(Icons.content_copy_rounded, 'Duplicate', C.blue, () {}),
                _sheetOption(Icons.file_download_outlined, 'Export Report', C.success, () {}),
                _sheetOption(Icons.share_rounded, 'Share Insights', C.purple, () {}),
                _sheetOption(Icons.delete_outline_rounded, 'Delete Campaign', C.error, () {}),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sheetOption(IconData icon, String label, Color color, VoidCallback onTap) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
        child: Icon(icon, color: color, size: 18),
      ),
      title: Text(label, style: TextStyle(color: color == C.error ? C.error : C.textPrimary, fontSize: 14)),
      onTap: () { Navigator.pop(context); onTap(); },
    );
  }
}