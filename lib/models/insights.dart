class DayInsight {
  final DateTime date;
  final double spend;
  final double revenue;
  final double roas;
  final double cpa;
  final double ctr;
  final double cpc;
  final double cpm;
  final int impressions;
  final int reach;
  final int clicks;
  final int conversions;
  final double frequency;

  const DayInsight({
    required this.date,
    this.spend = 0,
    this.revenue = 0,
    this.roas = 0,
    this.cpa = 0,
    this.ctr = 0,
    this.cpc = 0,
    this.cpm = 0,
    this.impressions = 0,
    this.reach = 0,
    this.clicks = 0,
    this.conversions = 0,
    this.frequency = 0,
  });
}

class InsightsSummary {
  final double totalSpend;
  final double totalRevenue;
  final double avgRoas;
  final double avgCpa;
  final double avgCtr;
  final double avgCpc;
  final int totalImpressions;
  final int totalReach;
  final int totalClicks;
  final int totalConversions;
  final List<DayInsight> daily;

  const InsightsSummary({
    this.totalSpend = 0,
    this.totalRevenue = 0,
    this.avgRoas = 0,
    this.avgCpa = 0,
    this.avgCtr = 0,
    this.avgCpc = 0,
    this.totalImpressions = 0,
    this.totalReach = 0,
    this.totalClicks = 0,
    this.totalConversions = 0,
    this.daily = const [],
  });

  List<double> get roasTrend => daily.map((d) => d.roas).toList();
  List<double> get spendTrend => daily.map((d) => d.spend).toList();
  List<double> get cpaTrend => daily.map((d) => d.cpa).toList();
}

class ActionBreakdown {
  final String actionType;
  final int count;
  final double cost;
  final double value;

  const ActionBreakdown({
    required this.actionType,
    this.count = 0,
    this.cost = 0,
    this.value = 0,
  });

  static String friendlyName(String type) => switch (type) {
        'purchase' => 'Purchases',
        'add_to_cart' => 'Add to Cart',
        'initiate_checkout' => 'Checkout Started',
        'lead' => 'Leads',
        'link_click' => 'Link Clicks',
        'landing_page_view' => 'Landing Page Views',
        'view_content' => 'Content Views',
        'add_payment_info' => 'Payment Info Added',
        _ => type,
      };
}