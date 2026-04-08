class IntelligenceSummary {
  final double avgAudienceScore;
  final double avgCreativeMatchScore;
  final int topBuyerCount;
  final int fatigueAlerts;
  final int openRecommendations;

  final List<IntelligenceTopItem> topScalableCampaigns;
  final List<IntelligenceAudienceItem> topHotAudiences;
  final List<IntelligenceBuyerItem> topSeedBuyers;

  final DateTime? lastComputedAt;

  const IntelligenceSummary({
    required this.avgAudienceScore,
    required this.avgCreativeMatchScore,
    required this.topBuyerCount,
    required this.fatigueAlerts,
    required this.openRecommendations,
    required this.topScalableCampaigns,
    required this.topHotAudiences,
    required this.topSeedBuyers,
    this.lastComputedAt,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  static int _i(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString()) ?? 0;
  }

  static DateTime? _dtNullable(dynamic v) {
    if (v == null) return null;
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString());
  }

  static Map<String, dynamic> _map(dynamic v) {
    return (v as Map).map((k, val) => MapEntry(k.toString(), val));
  }

  factory IntelligenceSummary.fromJson(Map<String, dynamic> json) {
    final tsc = (json['topScalableCampaigns'] ?? json['top_scalable_campaigns'])
        as List?;
    final tha =
        (json['topHotAudiences'] ?? json['top_hot_audiences']) as List?;
    final tsb = (json['topSeedBuyers'] ?? json['top_seed_buyers']) as List?;

    return IntelligenceSummary(
      avgAudienceScore: _d(json['avgAudienceScore'] ?? json['avg_audience_score']),
      avgCreativeMatchScore: _d(
        json['avgCreativeMatchScore'] ?? json['avg_creative_match_score'],
      ),
      topBuyerCount: _i(json['topBuyerCount'] ?? json['top_buyer_count']),
      fatigueAlerts: _i(json['fatigueAlerts'] ?? json['fatigue_alerts']),
      openRecommendations:
          _i(json['openRecommendations'] ?? json['open_recommendations']),
      topScalableCampaigns: (tsc ?? const [])
          .map((e) => IntelligenceTopItem.fromJson(_map(e)))
          .toList(),
      topHotAudiences: (tha ?? const [])
          .map((e) => IntelligenceAudienceItem.fromJson(_map(e)))
          .toList(),
      topSeedBuyers: (tsb ?? const [])
          .map((e) => IntelligenceBuyerItem.fromJson(_map(e)))
          .toList(),
      lastComputedAt:
          _dtNullable(json['lastComputedAt'] ?? json['last_computed_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'avgAudienceScore': avgAudienceScore,
      'avgCreativeMatchScore': avgCreativeMatchScore,
      'topBuyerCount': topBuyerCount,
      'fatigueAlerts': fatigueAlerts,
      'openRecommendations': openRecommendations,
      'topScalableCampaigns':
          topScalableCampaigns.map((e) => e.toJson()).toList(),
      'topHotAudiences': topHotAudiences.map((e) => e.toJson()).toList(),
      'topSeedBuyers': topSeedBuyers.map((e) => e.toJson()).toList(),
      'lastComputedAt': lastComputedAt?.toIso8601String(),
    };
  }
}

class IntelligenceTopItem {
  final String id;
  final String title;
  final double score;

  const IntelligenceTopItem({
    required this.id,
    required this.title,
    required this.score,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory IntelligenceTopItem.fromJson(Map<String, dynamic> json) {
    return IntelligenceTopItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      score: _d(json['score']),
    );
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'score': score};
}

class IntelligenceAudienceItem {
  final String key;
  final String name;
  final double score;

  const IntelligenceAudienceItem({
    required this.key,
    required this.name,
    required this.score,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory IntelligenceAudienceItem.fromJson(Map<String, dynamic> json) {
    return IntelligenceAudienceItem(
      key: json['key']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      score: _d(json['score']),
    );
  }

  Map<String, dynamic> toJson() => {'key': key, 'name': name, 'score': score};
}

class IntelligenceBuyerItem {
  final String phone;
  final String name;
  final double score;

  const IntelligenceBuyerItem({
    required this.phone,
    required this.name,
    required this.score,
  });

  static double _d(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }

  factory IntelligenceBuyerItem.fromJson(Map<String, dynamic> json) {
    return IntelligenceBuyerItem(
      phone: json['phone']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      score: _d(json['score']),
    );
  }

  Map<String, dynamic> toJson() => {'phone': phone, 'name': name, 'score': score};
}