class Campaign {
  final String id;
  final String name;
  final String objective;
  final String status;
  final String platform;
  final String bidStrategy;
  final double dailyBudget;
  final double lifetimeBudget;
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
  final int leads;
  final double frequency;
  final DateTime startDate;
  final DateTime? endDate;
  final DateTime updatedAt;
  final List<AdSet> adSets;
  final List<double> roasHistory;
  final List<double> spendHistory;

  const Campaign({
    required this.id,
    required this.name,
    required this.objective,
    required this.status,
    required this.platform,
    this.bidStrategy = 'LOWEST_COST_WITHOUT_CAP',
    this.dailyBudget = 0,
    this.lifetimeBudget = 0,
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
    this.leads = 0,
    this.frequency = 0,
    required this.startDate,
    this.endDate,
    required this.updatedAt,
    this.adSets = const [],
    this.roasHistory = const [],
    this.spendHistory = const [],
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isPaused => status.toUpperCase() == 'PAUSED';
  bool get isLearning => status.toUpperCase() == 'LEARNING';

  Campaign copyWith({
    String? status,
    double? dailyBudget,
    double? spend,
    double? roas,
  }) {
    return Campaign(
      id: id,
      name: name,
      objective: objective,
      status: status ?? this.status,
      platform: platform,
      bidStrategy: bidStrategy,
      dailyBudget: dailyBudget ?? this.dailyBudget,
      lifetimeBudget: lifetimeBudget,
      spend: spend ?? this.spend,
      revenue: revenue,
      roas: roas ?? this.roas,
      cpa: cpa,
      ctr: ctr,
      cpc: cpc,
      cpm: cpm,
      impressions: impressions,
      reach: reach,
      clicks: clicks,
      conversions: conversions,
      leads: leads,
      frequency: frequency,
      startDate: startDate,
      endDate: endDate,
      updatedAt: updatedAt,
      adSets: adSets,
      roasHistory: roasHistory,
      spendHistory: spendHistory,
    );
  }
}

class AdSet {
  final String id;
  final String name;
  final String status;
  final double spend;
  final double roas;
  final double cpa;
  final double ctr;
  final int impressions;
  final int conversions;
  final TargetingSpec targeting;

  const AdSet({
    required this.id,
    required this.name,
    required this.status,
    this.spend = 0,
    this.roas = 0,
    this.cpa = 0,
    this.ctr = 0,
    this.impressions = 0,
    this.conversions = 0,
    required this.targeting,
  });
}

class TargetingSpec {
  final int ageMin;
  final int ageMax;
  final List<String> genders;
  final List<String> locations;
  final List<String> interests;
  final String? lookalike;
  final String? customAudience;

  const TargetingSpec({
    this.ageMin = 18,
    this.ageMax = 65,
    this.genders = const ['All'],
    this.locations = const [],
    this.interests = const [],
    this.lookalike,
    this.customAudience,
  });
}