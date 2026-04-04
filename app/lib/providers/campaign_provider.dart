import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import 'app_providers.dart';

/// Currently selected campaign for detail view
final selectedCampaignProvider = StateProvider<Campaign?>((ref) => null);

/// Campaign insights for detail screen
final campaignInsightsProvider =
    FutureProvider.family<InsightsSummary, String>((ref, campaignId) async {
  await Future.delayed(const Duration(milliseconds: 600));
  // Mock — replace with real API
  final daily = List.generate(30, (i) {
    return DayInsight(
      date: DateTime.now().subtract(Duration(days: 29 - i)),
      spend: 800 + (i * 40).toDouble(),
      revenue: 3500 + (i * 200).toDouble(),
      roas: 3.5 + (i * 0.06),
      cpa: 170 - (i * 1.5),
      impressions: 5000 + (i * 200),
      clicks: 800 + (i * 30),
      conversions: 4 + (i ~/ 5),
    );
  });

  return InsightsSummary(
    totalSpend: 28400,
    totalRevenue: 176080,
    avgRoas: 6.2,
    avgCpa: 145,
    avgCtr: 4.2,
    avgCpc: 5.8,
    totalImpressions: 456500,
    totalReach: 380000,
    totalClicks: 18200,
    totalConversions: 196,
    daily: daily,
  );
});

/// Active campaign count
final activeCampaignCountProvider = Provider<int>((ref) {
  final campaigns = ref.watch(campaignsProvider);
  return campaigns.when(
    data: (list) => list.where((c) => c.isActive).length,
    loading: () => 0,
    error: (_, __) => 0,
  );
});