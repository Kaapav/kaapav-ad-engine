import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/theme.dart';
import '../widgets/cards/metric_card.dart';
import '../widgets/cards/funnel_card.dart';
import '../widgets/charts/spend_revenue_chart.dart';
import '../widgets/tables/optimizer_log_table.dart';

class OverviewScreen extends ConsumerWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: EdgeInsets.zero,
      children: [
        Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Overview', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white)),
            SizedBox(height: 4),
            Text('Your ad performance at a glance', style: TextStyle(fontSize: 13, color: KaapavColors.dark400)),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(color: KaapavColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: KaapavColors.success.withOpacity(0.2))),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(LucideIcons.trendingUp, size: 16, color: KaapavColors.success), SizedBox(width: 6),
              Text('4.2x', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: KaapavColors.success)),
            ])),
        ]),
        const SizedBox(height: 20),
        LayoutBuilder(builder: (context, c) {
          final w = (c.maxWidth - 12) / 2;
          return Wrap(spacing: 12, runSpacing: 12, children: [
            SizedBox(width: w, child: MetricCard(title: 'ROAS', value: '4.2x', subtitle: 'Last 7 days', changePercent: 12.5, icon: LucideIcons.target, accentColor: KaapavColors.success)),
            SizedBox(width: w, child: MetricCard(title: 'AD SPEND', value: '\u{20B9}12.4K', subtitle: 'Last 7 days', changePercent: 8.3, icon: LucideIcons.wallet, accentColor: KaapavColors.kaapav500)),
            SizedBox(width: w, child: MetricCard(title: 'REVENUE', value: '\u{20B9}52.1K', subtitle: 'Last 7 days', changePercent: 24.7, icon: LucideIcons.indianRupee, accentColor: const Color(0xFF8B5CF6))),
            SizedBox(width: w, child: MetricCard(title: 'ORDERS', value: '47', subtitle: 'Via WhatsApp', changePercent: 15.2, icon: LucideIcons.shoppingBag, accentColor: KaapavColors.info)),
          ]);
        }),
        const SizedBox(height: 20),
        SpendRevenueChart(data: const [
          SpendRevenueData(label: 'Mon', spend: 1800, revenue: 7200),
          SpendRevenueData(label: 'Tue', spend: 2100, revenue: 8400),
          SpendRevenueData(label: 'Wed', spend: 1600, revenue: 6800),
          SpendRevenueData(label: 'Thu', spend: 2400, revenue: 9600),
          SpendRevenueData(label: 'Fri', spend: 1900, revenue: 8100),
          SpendRevenueData(label: 'Sat', spend: 1400, revenue: 5900),
          SpendRevenueData(label: 'Sun', spend: 1200, revenue: 6100),
        ]),
        const SizedBox(height: 20),
        FunnelCard(steps: const [
          FunnelStep(label: 'Impressions', value: 45200, color: KaapavColors.info, icon: LucideIcons.eye),
          FunnelStep(label: 'Clicks', value: 2150, color: Color(0xFF8B5CF6), icon: LucideIcons.mousePointerClick),
          FunnelStep(label: 'WhatsApp Leads', value: 340, color: KaapavColors.success, icon: LucideIcons.messageCircle),
          FunnelStep(label: 'Purchases', value: 47, color: KaapavColors.kaapav500, icon: LucideIcons.shoppingBag),
        ]),
        const SizedBox(height: 20),
        OptimizerLogList(actions: [
          OptimizerAction(type: 'scaled', adName: 'Bracelet_Summer_Reel_01', roas: 5.2, reason: 'ROAS above 4x', timestamp: DateTime.now().subtract(const Duration(hours: 2))),
          OptimizerAction(type: 'paused', adName: 'Ring_Collection_Story_03', roas: 0.8, reason: 'ROAS below 1.5x', timestamp: DateTime.now().subtract(const Duration(hours: 5))),
          OptimizerAction(type: 'alert', adName: 'Earring_Set_Carousel_02', roas: 1.9, reason: 'High spend declining ROAS', timestamp: DateTime.now().subtract(const Duration(hours: 8))),
        ]),
        const SizedBox(height: 100),
      ],
    );
  }
}
