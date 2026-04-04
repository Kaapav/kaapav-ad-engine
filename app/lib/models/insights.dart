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

  factory DayInsight.fromJson(Map<String, dynamic> json) {
    return DayInsight(
      date: json['date'] != null
          ? DateTime.parse(json['date'])
          : json['date_start'] != null
              ? DateTime.parse(json['date_start'])
              : DateTime.now(),
      spend: (json['spend'] as num?)?.toDouble() ?? 0.0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0.0,
      roas: (json['roas'] as num?)?.toDouble() ?? 0.0,
      cpa: (json['cpa'] as num?)?.toDouble() ?? 0.0,
      ctr: (json['ctr'] as num?)?.toDouble() ?? 0.0,
      cpc: (json['cpc'] as num?)?.toDouble() ?? 0.0,
      cpm: (json['cpm'] as num?)?.toDouble() ?? 0.0,
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      reach: (json['reach'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      conversions: (json['conversions'] as num?)?.toInt() ?? 0,
      frequency: (json['frequency'] as num?)?.toDouble() ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'spend': spend,
        'revenue': revenue,
        'roas': roas,
        'cpa': cpa,
        'ctr': ctr,
        'cpc': cpc,
        'cpm': cpm,
        'impressions': impressions,
        'reach': reach,
        'clicks': clicks,
        'conversions': conversions,
        'frequency': frequency,
      };
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

  factory InsightsSummary.fromJson(Map<String, dynamic> json) {
    return InsightsSummary(
      totalSpend: (json['totalSpend'] as num?)?.toDouble() ?? 0.0,
      totalRevenue: (json['totalRevenue'] as num?)?.toDouble() ?? 0.0,
      avgRoas: (json['avgRoas'] as num?)?.toDouble() ?? 0.0,
      avgCpa: (json['avgCpa'] as num?)?.toDouble() ?? 0.0,
      avgCtr: (json['avgCtr'] as num?)?.toDouble() ?? 0.0,
      avgCpc: (json['avgCpc'] as num?)?.toDouble() ?? 0.0,
      totalImpressions: (json['totalImpressions'] as num?)?.toInt() ?? 0,
      totalReach: (json['totalReach'] as num?)?.toInt() ?? 0,
      totalClicks: (json['totalClicks'] as num?)?.toInt() ?? 0,
      totalConversions: (json['totalConversions'] as num?)?.toInt() ?? 0,
      daily: json['daily'] != null
          ? (json['daily'] as List)
              .map((d) => DayInsight.fromJson(d as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'totalSpend': totalSpend,
        'totalRevenue': totalRevenue,
        'avgRoas': avgRoas,
        'avgCpa': avgCpa,
        'avgCtr': avgCtr,
        'avgCpc': avgCpc,
        'totalImpressions': totalImpressions,
        'totalReach': totalReach,
        'totalClicks': totalClicks,
        'totalConversions': totalConversions,
        'daily': daily.map((d) => d.toJson()).toList(),
      };
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