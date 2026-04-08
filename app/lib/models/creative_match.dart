import 'dart:convert';

class CreativeMatch {
  final String id;

  final String? adId;
  final String? creativeId;
  final String? campaignId;
  final String? adsetId;
  final String? audienceKey;

  final String? creativeName;
  final String? creativeType;
  final String? hookType;
  final String? angle;
  final String? productTag;

  final double spend;
  final double revenue;
  final double roas;
  final double ctr;
  final int conversions;

  final double matchScore;
  final double fatigueScore;
  final String status; // winner | test | fatiguing | loser
  final List<String> reasons;

  final DateTime createdAt;

  const CreativeMatch({
    required this.id,
    required this.adId,
    required this.creativeId,
    required this.campaignId,
    required this.adsetId,
    required this.audienceKey,
    required this.creativeName,
    required this.creativeType,
    required this.hookType,
    required this.angle,
    required this.productTag,
    required this.spend,
    required this.revenue,
    required this.roas,
    required this.ctr,
    required this.conversions,
    required this.matchScore,
    required this.fatigueScore,
    required this.status,
    required this.reasons,
    required this.createdAt,
  });

  bool get isWinner => status == 'winner';
  bool get isTest => status == 'test';
  bool get isFatiguing => status == 'fatiguing';
  bool get isLoser => status == 'loser';

  String get displayName => (creativeName?.trim().isNotEmpty ?? false)
      ? creativeName!.trim()
      : (creativeId ?? adId ?? 'Creative');

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

  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static List<String> _reasons(dynamic v) {
    if (v == null) return const <String>[];
    if (v is List) {
      return v
          .map((e) => e.toString())
          .where((s) => s.trim().isNotEmpty)
          .toList();
    }
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return const <String>[];

      try {
        final decoded = jsonDecode(s);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((x) => x.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}

      final lines = s
          .split(RegExp(r'[\n•]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      return lines.isNotEmpty ? lines : <String>[s];
    }
    return <String>[v.toString()];
  }

  factory CreativeMatch.fromJson(Map<String, dynamic> json) {
    return CreativeMatch(
      id: json['id']?.toString() ?? '',
      adId: (json['adId'] ?? json['ad_id'])?.toString(),
      creativeId: (json['creativeId'] ?? json['creative_id'])?.toString(),
      campaignId: (json['campaignId'] ?? json['campaign_id'])?.toString(),
      adsetId: (json['adsetId'] ?? json['adset_id'])?.toString(),
      audienceKey: (json['audienceKey'] ?? json['audience_key'])?.toString(),
      creativeName: (json['creativeName'] ?? json['creative_name'])?.toString(),
      creativeType: (json['creativeType'] ?? json['creative_type'])?.toString(),
      hookType: (json['hookType'] ?? json['hook_type'])?.toString(),
      angle: json['angle']?.toString(),
      productTag: (json['productTag'] ?? json['product_tag'])?.toString(),
      spend: _d(json['spend']),
      revenue: _d(json['revenue']),
      roas: _d(json['roas']),
      ctr: _d(json['ctr']),
      conversions: _i(json['conversions']),
      matchScore: _d(json['matchScore'] ?? json['match_score']),
      fatigueScore: _d(json['fatigueScore'] ?? json['fatigue_score']),
      status: (json['status']?.toString() ?? 'test').toLowerCase(),
      reasons: _reasons(json['reasons']),
      createdAt: _dt(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'adId': adId,
      'creativeId': creativeId,
      'campaignId': campaignId,
      'adsetId': adsetId,
      'audienceKey': audienceKey,
      'creativeName': creativeName,
      'creativeType': creativeType,
      'hookType': hookType,
      'angle': angle,
      'productTag': productTag,
      'spend': spend,
      'revenue': revenue,
      'roas': roas,
      'ctr': ctr,
      'conversions': conversions,
      'matchScore': matchScore,
      'fatigueScore': fatigueScore,
      'status': status,
      'reasons': reasons,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}