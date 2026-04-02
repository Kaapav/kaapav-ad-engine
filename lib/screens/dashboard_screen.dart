import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/campaign_tile.dart';
import '../widgets/charts.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  int _period = 1; // 0=7D, 1=30D

  // MOCK DATA for Kaapav Fashion Jewellery
  final _roasData = [2.8, 3.0, 3.2, 3.5, 3.3, 3.8, 4.0, 3.9, 4.2, 3.8, 4.1, 3.9, 4.3, 4.5, 4.2, 4.0, 4.4, 4.6, 4.3, 4.8, 4.5, 4.2, 4.6, 4.9, 4.7, 4.5, 4.8, 5.1, 4.9, 5.2];

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
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
                  center: Alignment(-0.5 + _bgC.value * 0.3, -0.8 + _bgC.value * 0.2),
                  radius: 1.5,
                  colors: [C.primary.withValues(alpha: 0.06), C.purple.withValues(alpha: 0.04), C.bgDeep],
                ),
              ),
            ),
          ),

          // CONTENT
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // APP BAR
                SliverToBoxAdapter(child: _appBar()),
                // ALERT
                SliverToBoxAdapter(child: _alert()),
                // ROAS HERO
                SliverToBoxAdapter(child: _roasHero()),
                // QUICK STATS
                SliverToBoxAdapter(child: _quickStats()),
                // TOP CAMPAIGNS
                SliverToBoxAdapter(child: _topCampaigns()),
                // AI INSIGHT
                SliverToBoxAdapter(child: _aiInsight()),
                // BOTTOM PADDING for nav
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ═══ APP BAR ═══
  Widget _appBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(
              gradient: C.primaryGrad,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.4), blurRadius: 12)],
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.black, size: 20),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Kaapav Ad Engine', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                Text('Fashion Jewellery', style: TextStyle(color: C.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          const LiveDot(),
          const SizedBox(width: 8),
          GlassIconBtn(icon: Icons.notifications_outlined, badge: true, badgeCount: '3', onTap: () {}),
        ],
      ),
    );
  }

  // ═══ ALERT BANNER ═══
  Widget _alert() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: C.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.electric_bolt_rounded, color: C.warning, size: 16),
            ),
            const SizedBox(width: 10),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Budget Alert: 2 campaigns near daily limit', style: TextStyle(color: C.textPrimary, fontSize: 11, fontWeight: FontWeight.w600)),
                  Text('Auto-scale enabled • Increasing by 15%', style: TextStyle(color: C.textMuted, fontSize: 10)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: C.warning.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: C.warning.withValues(alpha: 0.3))),
              child: const Text('Review', style: TextStyle(color: C.warning, fontSize: 10, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ ROAS HERO ═══
  Widget _roasHero() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: GlassCard(
        radius: 22,
        turquoise: true,
        glow: true,
        padding: EdgeInsets.zero,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('ROAS Performance', style: TextStyle(color: C.textSecondary, fontSize: 12)),
                        const SizedBox(height: 4),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text('5.2x', style: TextStyle(color: C.textPrimary, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -1)),
                            const SizedBox(width: 10),
                            const Padding(
                              padding: EdgeInsets.only(bottom: 6),
                              child: ChangePill(change: '+22.4%', isUp: true),
                            ),
                          ],
                        ),
                        const Text('Return on Ad Spend', style: TextStyle(color: C.textMuted, fontSize: 11)),
                      ],
                    ),
                  ),
                  // PERIOD SELECTOR
                  Container(
                    decoration: BoxDecoration(color: C.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.glassBorder)),
                    child: Row(
                      children: ['7D', '30D'].asMap().entries.map((e) {
                        final sel = e.key == _period;
                        return GestureDetector(
                          onTap: () => setState(() => _period = e.key),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(gradient: sel ? C.primaryGrad : null, borderRadius: BorderRadius.circular(8)),
                            child: Text(e.value, style: TextStyle(color: sel ? Colors.black : C.textMuted, fontSize: 11, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            ),
            // KPI ROW
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
              child: Row(
                children: [
                  _miniKpi('Spend', '₹1.24L', C.blue, Icons.paid_outlined),
                  _miniKpi('Revenue', '₹6.45L', C.success, Icons.trending_up),
                  _miniKpi('CPA', '₹182', C.warning, Icons.ads_click),
                  _miniKpi('CTR', '3.8%', C.purple, Icons.touch_app),
                ],
              ),
            ),
            // CHART
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 14, 8, 16),
              child: RoasLineChart(
                data: _period == 0 ? _roasData.sublist(23) : _roasData,
                height: 130,
              ),
            ),
          ],
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
          Text(value, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700)),
          Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
        ],
      ),
    );
  }

  // ═══ QUICK STATS GRID ═══
  Widget _quickStats() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'Quick Stats'),
          const SizedBox(height: 10),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            childAspectRatio: 0.95,
            children: const [
              MetricCard(label: 'Active Campaigns', value: '8', change: '+2', isUp: true, icon: Icons.campaign_rounded, color: C.primary),
              MetricCard(label: 'Impressions', value: '1.8M', change: '+18%', isUp: true, icon: Icons.visibility_rounded, color: C.blue),
              MetricCard(label: 'Clicks', value: '67.2K', change: '+24%', isUp: true, icon: Icons.touch_app_rounded, color: C.purple),
              MetricCard(label: 'Orders', value: '342', change: '+31%', isUp: true, icon: Icons.shopping_bag_rounded, color: C.success),
              MetricCard(label: 'Total Spend', value: '₹1.24L', change: '+12%', isUp: true, icon: Icons.account_balance_wallet, color: C.pink),
              MetricCard(label: 'Leads Today', value: '47', change: '+15', isUp: true, icon: Icons.person_add_rounded, color: C.gold),
            ],
          ),
        ],
      ),
    );
  }

  // ═══ TOP CAMPAIGNS ═══
  Widget _topCampaigns() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          SectionHeader(title: 'Top Campaigns', action: 'View All', onAction: () {}),
          const SizedBox(height: 10),
          ...[
            const CampaignTile(name: 'Navratri Jewellery Sale', status: 'Active', platform: 'Facebook', spend: 28400, roas: 6.2, cpa: 145),
            const SizedBox(height: 8),
            const CampaignTile(name: 'Reels - Gold Plated Set', status: 'Active', platform: 'Instagram', spend: 19200, roas: 5.8, cpa: 162),
            const SizedBox(height: 8),
            const CampaignTile(name: 'Lookalike 1% Buyers', status: 'Learning', platform: 'Facebook', spend: 12800, roas: 3.1, cpa: 210),
            const SizedBox(height: 8),
            const CampaignTile(name: 'Bridal Collection Lead', status: 'Paused', platform: 'Instagram', spend: 8500, roas: 0, cpa: 0),
          ],
        ],
      ),
    );
  }

  // ═══ AI INSIGHT ═══
  Widget _aiInsight() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Column(
        children: [
          const SectionHeader(title: 'AI Insights'),
          const SizedBox(height: 10),
          _insightCard(
            Icons.trending_up, C.success,
            'Scale Opportunity',
            'Navratri Sale ROAS 6.2x for 5 days — scale budget by ₹5,000',
            'Scale',
          ),
          const SizedBox(height: 8),
          _insightCard(
            Icons.warning_amber_rounded, C.warning,
            'Creative Fatigue',
            'Gold Plated Set creative is 32 days old — frequency 3.8x',
            'Replace',
          ),
          const SizedBox(height: 8),
          _insightCard(
            Icons.people_alt_rounded, C.blue,
            'Audience Tip',
            'Women 25-40 in Maharashtra driving 68% revenue — create dedicated campaign',
            'Create',
          ),
        ],
      ),
    );
  }

  Widget _insightCard(IconData icon, Color color, String title, String subtitle, String action) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 40, height: 40,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.2))),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: C.textSecondary, fontSize: 11), maxLines: 2),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(8)),
            child: Text(action, style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}