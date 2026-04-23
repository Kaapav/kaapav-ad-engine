// ═══════════════════════════════════════════════════════════════
// CREATIVE MATCH MODEL
// Maps to creative_scores D1 table
// ═══════════════════════════════════════════════════════════════

class CreativeMatch {
  final String  id;
  final String? adId;
  final String? creativeId;
  final String? campaignId;
  final String? adsetId;
  final String? audienceKey;
  final String  creativeName;
  final String? creativeType;
  final String? hookType;
  final String? angle;
  final String? productTag;
  final double  spend;
  final double  revenue;
  final double  roas;
  final double  ctr;
  final int     conversions;
  final double  matchScore;
  final double  fatigueScore;
  final String  status;         // winner / test_more / weak / stop
  final List<String> reasons;
  final DateTime createdAt;

  const CreativeMatch({
    required this.id,
    this.adId,
    this.creativeId,
    this.campaignId,
    this.adsetId,
    this.audienceKey,
    required this.creativeName,
    this.creativeType,
    this.hookType,
    this.angle,
    this.productTag,
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

  // ── Getters ────────────────────────────────────────────────
  bool get isWinner    => status == 'winner';
  bool get isTestMore  => status == 'test_more';
  bool get isWeak      => status == 'weak';
  bool get isStop      => status == 'stop';

  // Fatigue label
  String get fatigueLabel {
    if (fatigueScore >= 75) return 'Burnt Out';
    if (fatigueScore >= 50) return 'Fatiguing';
    if (fatigueScore >= 25) return 'Stable';
    return 'Fresh';
  }

  factory CreativeMatch.fromJson(Map<String, dynamic> j) {
    List<String> parseReasons(dynamic raw) {
      if (raw == null) return const [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String && raw.isNotEmpty) {
        try {
          if (raw.startsWith('[')) {
            return raw
                .substring(1, raw.length - 1)
                .split(',')
                .map((s) =>
                    s.trim().replaceAll('"', '').replaceAll("'", ''))
                .where((s) => s.isNotEmpty)
                .toList();
          }
        } catch (_) {}
        return [raw];
      }
      return const [];
    }

    return CreativeMatch(
      id:           j['id']?.toString()            ?? '',
      adId:         j['ad_id']?.toString(),
      creativeId:   j['creative_id']?.toString(),
      campaignId:   j['campaign_id']?.toString(),
      adsetId:      j['adset_id']?.toString(),
      audienceKey:  j['audience_key']?.toString(),
      creativeName: j['creative_name']?.toString() ??
          j['campaign_id']?.toString() ?? 'Unknown Creative',
      creativeType: j['creative_type']?.toString(),
      hookType:     j['hook_type']?.toString(),
      angle:        j['angle']?.toString(),
      productTag:   j['product_tag']?.toString(),
      spend:        (j['spend'] as num?)?.toDouble()        ?? 0,
      revenue:      (j['revenue'] as num?)?.toDouble()      ?? 0,
      roas:         (j['roas'] as num?)?.toDouble()         ?? 0,
      ctr:          (j['ctr'] as num?)?.toDouble()          ?? 0,
      conversions:  (j['conversions'] as num?)?.toInt()     ?? 0,
      matchScore:   (j['match_score'] as num?)?.toDouble()  ?? 0,
      fatigueScore: (j['fatigue_score'] as num?)?.toDouble() ?? 0,
      status:       j['status']?.toString()                 ?? 'weak',
      reasons:      parseReasons(j['reasons']),
      createdAt:    DateTime.tryParse(
                      j['created_at']?.toString() ?? '',
                    ) ??
                    DateTime.now(),
    );
  }
}