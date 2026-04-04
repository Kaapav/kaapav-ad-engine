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
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime updatedAt;
  final List<AdSet> adSets;
  final List<double> roasHistory;
  final List<double> spendHistory;

  const Campaign({
    required this.id,
    required this.name,
    this.objective = 'OUTCOME_SALES',
    this.status = 'ACTIVE',
    this.platform = 'Facebook',
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
    this.startDate,
    this.endDate,
    required this.updatedAt,
    this.adSets = const [],
    this.roasHistory = const [],
    this.spendHistory = const [],
  });

  bool get isActive => status.toUpperCase() == 'ACTIVE';
  bool get isPaused =>
      status.toUpperCase() == 'PAUSED' ||
      status.toUpperCase() == 'CAMPAIGN_PAUSED';
  bool get isLearning =>
      status.toUpperCase() == 'LEARNING' ||
      status.toUpperCase() == 'IN_PROCESS';

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

  factory Campaign.fromJson(Map<String, dynamic> json) {
    return Campaign(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ??
          json['campaign_name'] as String? ??
          '',
      objective: json['objective'] as String? ?? 'OUTCOME_SALES',
      status: json['effective_status'] as String? ??
          json['status'] as String? ??
          'UNKNOWN',
      platform: json['platform'] as String? ?? 'Facebook',
      bidStrategy:
          json['bid_strategy'] as String? ?? 'LOWEST_COST_WITHOUT_CAP',
      dailyBudget: _toDouble(json['daily_budget']),
      lifetimeBudget: _toDouble(json['lifetime_budget']),
      spend: _toDouble(json['spend']),
      revenue: _toDouble(json['revenue']),
      roas: _toDouble(json['purchase_roas'] ?? json['roas']),
      cpa: _toDouble(json['cpa'] ?? json['cost_per_action_type']),
      ctr: _toDouble(json['ctr']),
      cpc: _toDouble(json['cpc']),
      cpm: _toDouble(json['cpm']),
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      reach: (json['reach'] as num?)?.toInt() ?? 0,
      clicks: (json['clicks'] as num?)?.toInt() ?? 0,
      conversions: (json['conversions'] as num?)?.toInt() ?? 0,
      leads: (json['leads'] as num?)?.toInt() ?? 0,
      frequency: _toDouble(json['frequency']),
      startDate: json['start_time'] != null
          ? DateTime.tryParse(json['start_time'])
          : json['startDate'] != null
              ? DateTime.tryParse(json['startDate'])
              : null,
      endDate: json['stop_time'] != null
          ? DateTime.tryParse(json['stop_time'])
          : json['endDate'] != null
              ? DateTime.tryParse(json['endDate'])
              : null,
      updatedAt: json['updated_time'] != null
          ? DateTime.parse(json['updated_time'])
          : json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'])
              : DateTime.now(),
      adSets: json['adsets'] != null
          ? (json['adsets'] as List)
              .map((a) => AdSet.fromJson(a as Map<String, dynamic>))
              .toList()
          : [],
      roasHistory: json['roasHistory'] != null
          ? (json['roasHistory'] as List)
              .map((e) => (e as num).toDouble())
              .toList()
          : [],
      spendHistory: json['spendHistory'] != null
          ? (json['spendHistory'] as List)
              .map((e) => (e as num).toDouble())
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'objective': objective,
        'status': status,
        'platform': platform,
        'bid_strategy': bidStrategy,
        'daily_budget': dailyBudget,
        'lifetime_budget': lifetimeBudget,
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
        'leads': leads,
        'frequency': frequency,
        'startDate': startDate?.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'adsets': adSets.map((a) => a.toJson()).toList(),
        'roasHistory': roasHistory,
        'spendHistory': spendHistory,
      };

  static double _toDouble(dynamic v) {
    if (v == null) return 0.0;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v) ?? 0.0;
    if (v is List && v.isNotEmpty) {
      final first = v.first;
      if (first is Map) return double.tryParse('${first['value']}') ?? 0.0;
    }
    return 0.0;
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
    this.status = 'ACTIVE',
    this.spend = 0,
    this.roas = 0,
    this.cpa = 0,
    this.ctr = 0,
    this.impressions = 0,
    this.conversions = 0,
    this.targeting = const TargetingSpec(),
  });

  factory AdSet.fromJson(Map<String, dynamic> json) {
    return AdSet(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      status: json['effective_status'] as String? ??
          json['status'] as String? ??
          'UNKNOWN',
      spend: (json['spend'] as num?)?.toDouble() ?? 0.0,
      roas: (json['roas'] as num?)?.toDouble() ?? 0.0,
      cpa: (json['cpa'] as num?)?.toDouble() ?? 0.0,
      ctr: (json['ctr'] as num?)?.toDouble() ?? 0.0,
      impressions: (json['impressions'] as num?)?.toInt() ?? 0,
      conversions: (json['conversions'] as num?)?.toInt() ?? 0,
      targeting: json['targeting'] != null
          ? TargetingSpec.fromJson(json['targeting'] as Map<String, dynamic>)
          : const TargetingSpec(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'status': status,
        'spend': spend,
        'roas': roas,
        'cpa': cpa,
        'ctr': ctr,
        'impressions': impressions,
        'conversions': conversions,
        'targeting': targeting.toJson(),
      };
}

class TargetingSpec {
  final int ageMin;
  final int ageMax;
  final List<String> genders;
  final List<String>? locations;
  final List<String>? interests;
  final String? lookalike;
  final String? customAudience;

  const TargetingSpec({
    this.ageMin = 18,
    this.ageMax = 65,
    this.genders = const ['All'],
    this.locations,
    this.interests,
    this.lookalike,
    this.customAudience,
  });

  factory TargetingSpec.fromJson(Map<String, dynamic> json) {
    return TargetingSpec(
      ageMin: json['age_min'] as int? ?? json['ageMin'] as int? ?? 18,
      ageMax: json['age_max'] as int? ?? json['ageMax'] as int? ?? 65,
      genders: json['genders'] != null
          ? List<String>.from(json['genders'])
          : const ['All'],
      locations: json['locations'] != null
          ? List<String>.from(json['locations'])
          : json['geo_locations']?['cities'] != null
              ? (json['geo_locations']['cities'] as List)
                  .map((c) => c['name'] as String? ?? '')
                  .toList()
              : null,
      interests: json['interests'] != null
          ? List<String>.from(json['interests'])
          : json['flexible_spec'] != null
              ? (json['flexible_spec'] as List)
                  .expand((f) => (f['interests'] as List?) ?? [])
                  .map((i) => i['name'] as String? ?? '')
                  .toList()
              : null,
      lookalike: json['lookalike'] as String?,
      customAudience: json['customAudience'] as String? ??
          json['custom_audiences']?.first?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'ageMin': ageMin,
        'ageMax': ageMax,
        'genders': genders,
        'locations': locations,
        'interests': interests,
        'lookalike': lookalike,
        'customAudience': customAudience,
      };
}