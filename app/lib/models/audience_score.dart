import 'dart:convert';

class AudienceScore {
  final String id;
  final String? campaignId;
  final String? adsetId;
  final String audienceKey;
  final String? audienceName;

  final double spend;
  final double revenue;
  final double roas;
  final double cpa;
  final double ctr;
  final double cpc;
  final double cpm;
  final double frequency;

  final int clicks;
  final int conversions;
  final int leads;

  final double intentScore;
  final String status; // hot | scalable | watch | kill
  final List<String> reasons;

  final DateTime createdAt;

  const AudienceScore({
    required this.id,
    required this.campaignId,
    required this.adsetId,
    required this.audienceKey,
    required this.audienceName,
    required this.spend,
    required this.revenue,
    required this.roas,
    required this.cpa,
    required this.ctr,
    required this.cpc,
    required this.cpm,
    required this.frequency,
    required this.clicks,
    required this.conversions,
    required this.leads,
    required this.intentScore,
    required this.status,
    required this.reasons,
    required this.createdAt,
  });

  bool get isHot => status == 'hot';
  bool get isScalable => status == 'scalable';
  bool get isWatch => status == 'watch';
  bool get isKill => status == 'kill';

  String get displayName => (audienceName?.trim().isNotEmpty ?? false)
      ? audienceName!.trim()
      : audienceKey;

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
    final s = v.toString();
    return DateTime.tryParse(s) ?? DateTime.fromMillisecondsSinceEpoch(0);
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

      // could be a JSON string list
      try {
        final decoded = jsonDecode(s);
        if (decoded is List) {
          return decoded
              .map((e) => e.toString())
              .where((x) => x.trim().isNotEmpty)
              .toList();
        }
      } catch (_) {}

      // or a bullet / newline separated string
      final lines = s
          .split(RegExp(r'[\n•]+'))
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      return lines.isNotEmpty ? lines : <String>[s];
    }
    return <String>[v.toString()];
  }

  factory AudienceScore.fromJson(Map<String, dynamic> json) {
    return AudienceScore(
      id: json['id']?.toString() ?? '',
      campaignId: (json['campaignId'] ?? json['campaign_id'])?.toString(),
      adsetId: (json['adsetId'] ?? json['adset_id'])?.toString(),
      audienceKey:
          (json['audienceKey'] ?? json['audience_key'])?.toString() ?? '',
      audienceName: (json['audienceName'] ?? json['audience_name'])?.toString(),
      spend: _d(json['spend']),
      revenue: _d(json['revenue']),
      roas: _d(json['roas']),
      cpa: _d(json['cpa']),
      ctr: _d(json['ctr']),
      cpc: _d(json['cpc']),
      cpm: _d(json['cpm']),
      frequency: _d(json['frequency']),
      clicks: _i(json['clicks']),
      conversions: _i(json['conversions']),
      leads: _i(json['leads']),
      intentScore: _d(json['intentScore'] ?? json['intent_score']),
      status: (json['status']?.toString() ?? 'watch').toLowerCase(),
      reasons: _reasons(json['reasons']),
      createdAt: _dt(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'campaignId': campaignId,
      'adsetId': adsetId,
      'audienceKey': audienceKey,
      'audienceName': audienceName,
      'spend': spend,
      'revenue': revenue,
      'roas': roas,
      'cpa': cpa,
      'ctr': ctr,
      'cpc': cpc,
      'cpm': cpm,
      'frequency': frequency,
      'clicks': clicks,
      'conversions': conversions,
      'leads': leads,
      'intentScore': intentScore,
      'status': status,
      'reasons': reasons,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}