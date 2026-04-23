// ═══════════════════════════════════════════════════════════════
// INTELLIGENCE SUMMARY MODEL
// Top-level summary returned by Worker /api/intelligence/summary
// ═══════════════════════════════════════════════════════════════

class ScaleCandidate {
  final String id;
  final String title;
  final double score;

  const ScaleCandidate({
    required this.id,
    required this.title,
    required this.score,
  });

  factory ScaleCandidate.fromJson(Map<String, dynamic> j) =>
      ScaleCandidate(
        id:    j['id']?.toString()    ?? '',
        title: j['title']?.toString() ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

class HotAudience {
  final String key;
  final String name;
  final double score;

  const HotAudience({
    required this.key,
    required this.name,
    required this.score,
  });

  factory HotAudience.fromJson(Map<String, dynamic> j) => HotAudience(
        key:   j['key']?.toString()  ?? '',
        name:  j['name']?.toString() ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

class SeedBuyer {
  final String phone;
  final String name;
  final double score;

  const SeedBuyer({
    required this.phone,
    required this.name,
    required this.score,
  });

  factory SeedBuyer.fromJson(Map<String, dynamic> j) => SeedBuyer(
        phone: j['phone']?.toString() ?? '',
        name:  j['name']?.toString()  ?? '',
        score: (j['score'] as num?)?.toDouble() ?? 0,
      );
}

class IntelligenceSummary {
  final double avgAudienceScore;
  final double avgCreativeMatchScore;
  final int    topBuyerCount;
  final int    fatigueAlerts;
  final int    openRecommendations;
  final List<ScaleCandidate> topScalableCampaigns;
  final List<HotAudience>    topHotAudiences;
  final List<SeedBuyer>      topSeedBuyers;
  final DateTime?            lastComputedAt;

  const IntelligenceSummary({
    this.avgAudienceScore      = 0,
    this.avgCreativeMatchScore = 0,
    this.topBuyerCount         = 0,
    this.fatigueAlerts         = 0,
    this.openRecommendations   = 0,
    this.topScalableCampaigns  = const [],
    this.topHotAudiences       = const [],
    this.topSeedBuyers         = const [],
    this.lastComputedAt,
  });

  factory IntelligenceSummary.fromJson(Map<String, dynamic> j) {
    List<T> parseList<T>(
      dynamic raw,
      T Function(Map<String, dynamic>) fromJson,
    ) {
      if (raw == null) return const [];
      if (raw is List) {
        return raw
            .whereType<Map<String, dynamic>>()
            .map(fromJson)
            .toList();
      }
      return const [];
    }

    return IntelligenceSummary(
      avgAudienceScore:
          (j['avgAudienceScore'] as num?)?.toDouble() ?? 0,
      avgCreativeMatchScore:
          (j['avgCreativeMatchScore'] as num?)?.toDouble() ?? 0,
      topBuyerCount:
          (j['topBuyerCount'] as num?)?.toInt() ?? 0,
      fatigueAlerts:
          (j['fatigueAlerts'] as num?)?.toInt() ?? 0,
      openRecommendations:
          (j['openRecommendations'] as num?)?.toInt() ?? 0,
      topScalableCampaigns: parseList(
        j['topScalableCampaigns'],
        ScaleCandidate.fromJson,
      ),
      topHotAudiences: parseList(
        j['topHotAudiences'],
        HotAudience.fromJson,
      ),
      topSeedBuyers: parseList(
        j['topSeedBuyers'],
        SeedBuyer.fromJson,
      ),
      lastComputedAt: j['lastComputedAt'] != null
          ? DateTime.tryParse(j['lastComputedAt'].toString())
          : null,
    );
  }

  // Empty/loading state
  static const empty = IntelligenceSummary();
}