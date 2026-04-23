// ═══════════════════════════════════════════════════════════════
// AUDIENCE SCORE MODEL
// Maps to audience_scores D1 table
// ═══════════════════════════════════════════════════════════════

class AudienceScore {
  final String  id;
  final String  audienceKey;
  final String  audienceName;
  final String? campaignId;
  final String? adsetId;
  final double  spend;
  final double  revenue;
  final double  roas;
  final double  cpa;
  final double  ctr;
  final double  cpc;
  final double  cpm;
  final double  frequency;
  final int     clicks;
  final int     conversions;
  final int     leads;
  final double  intentScore;
  final String  status;         // hot / scalable / watch / kill
  final List<String> reasons;
  final DateTime createdAt;

  const AudienceScore({
    required this.id,
    required this.audienceKey,
    required this.audienceName,
    this.campaignId,
    this.adsetId,
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

  // ── Getters ────────────────────────────────────────────────
  bool get isHot       => status == 'hot';
  bool get isScalable  => status == 'scalable';
  bool get isWatch     => status == 'watch';
  bool get isKill      => status == 'kill';

  factory AudienceScore.fromJson(Map<String, dynamic> j) {
    List<String> parseReasons(dynamic raw) {
      if (raw == null) return const [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      if (raw is String) {
        try {
          final decoded = raw.trim();
          if (decoded.startsWith('[')) {
            // JSON array string
            final list = decoded
                .substring(1, decoded.length - 1)
                .split(',')
                .map((s) => s
                    .trim()
                    .replaceAll('"', '')
                    .replaceAll("'", ''))
                .where((s) => s.isNotEmpty)
                .toList();
            return list;
          }
        } catch (_) {}
        return [raw];
      }
      return const [];
    }

    return AudienceScore(
      id:           j['id']?.toString()           ?? '',
      audienceKey:  j['audience_key']?.toString() ?? '',
      audienceName: j['audience_name']?.toString() ??
          j['audience_key']?.toString() ?? '',
      campaignId:   j['campaign_id']?.toString(),
      adsetId:      j['adset_id']?.toString(),
      spend:        (j['spend'] as num?)?.toDouble()       ?? 0,
      revenue:      (j['revenue'] as num?)?.toDouble()     ?? 0,
      roas:         (j['roas'] as num?)?.toDouble()        ?? 0,
      cpa:          (j['cpa'] as num?)?.toDouble()         ?? 0,
      ctr:          (j['ctr'] as num?)?.toDouble()         ?? 0,
      cpc:          (j['cpc'] as num?)?.toDouble()         ?? 0,
      cpm:          (j['cpm'] as num?)?.toDouble()         ?? 0,
      frequency:    (j['frequency'] as num?)?.toDouble()   ?? 0,
      clicks:       (j['clicks'] as num?)?.toInt()         ?? 0,
      conversions:  (j['conversions'] as num?)?.toInt()    ?? 0,
      leads:        (j['leads'] as num?)?.toInt()          ?? 0,
      intentScore:  (j['intent_score'] as num?)?.toDouble() ?? 0,
      status:       j['status']?.toString()                ?? 'watch',
      reasons:      parseReasons(j['reasons']),
      createdAt:    DateTime.tryParse(
                      j['created_at']?.toString() ?? '',
                    ) ??
                    DateTime.now(),
    );
  }
}