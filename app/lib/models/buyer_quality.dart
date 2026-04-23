// ═══════════════════════════════════════════════════════════════
// BUYER QUALITY MODEL
// Maps to buyer_scores D1 table
// ═══════════════════════════════════════════════════════════════

class BuyerQuality {
  final String  id;
  final String? leadId;
  final String  phone;
  final String  customerName;
  final int     totalOrders;
  final double  totalRevenue;
  final double  avgOrderValue;
  final int     repeatOrders;
  final double  prepaidRatio;
  final int     refundCount;
  final double  responseScore;
  final double  buyerQualityScore;
  final String  buyerTier;           // platinum / gold / silver / risk
  final bool    lookalikeSeedEligible;
  final String  productAffinity;
  final DateTime updatedAt;

  const BuyerQuality({
    required this.id,
    this.leadId,
    required this.phone,
    required this.customerName,
    required this.totalOrders,
    required this.totalRevenue,
    required this.avgOrderValue,
    required this.repeatOrders,
    required this.prepaidRatio,
    required this.refundCount,
    required this.responseScore,
    required this.buyerQualityScore,
    required this.buyerTier,
    required this.lookalikeSeedEligible,
    required this.productAffinity,
    required this.updatedAt,
  });

  // ── Getters ────────────────────────────────────────────────
  bool get isPlatinum    => buyerTier == 'platinum';
  bool get isGold        => buyerTier == 'gold';
  bool get isSilver      => buyerTier == 'silver';
  bool get isRisk        => buyerTier == 'risk';
  bool get isSeedEligible => lookalikeSeedEligible;

  factory BuyerQuality.fromJson(Map<String, dynamic> j) {
    bool parseBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v.toInt() == 1;
      final s = v.toString().trim().toLowerCase();
      return s == '1' || s == 'true';
    }

    return BuyerQuality(
      id:           j['id']?.toString()              ?? '',
      leadId:       j['lead_id']?.toString(),
      phone:        j['phone']?.toString()            ?? '',
      customerName: j['customer_name']?.toString()   ??
          j['phone']?.toString() ?? 'Unknown',
      totalOrders:  (j['total_orders'] as num?)?.toInt()    ?? 0,
      totalRevenue: (j['total_revenue'] as num?)?.toDouble() ?? 0,
      avgOrderValue:(j['avg_order_value'] as num?)?.toDouble() ?? 0,
      repeatOrders: (j['repeat_orders'] as num?)?.toInt()   ?? 0,
      prepaidRatio: (j['prepaid_ratio'] as num?)?.toDouble() ?? 0,
      refundCount:  (j['refund_count'] as num?)?.toInt()    ?? 0,
      responseScore:(j['response_score'] as num?)?.toDouble() ?? 0,
      buyerQualityScore:
          (j['buyer_quality_score'] as num?)?.toDouble() ?? 0,
      buyerTier:    j['buyer_tier']?.toString() ?? 'silver',
      lookalikeSeedEligible:
          parseBool(j['lookalike_seed_eligible']),
      productAffinity:
          j['product_affinity']?.toString() ?? 'general',
      updatedAt: DateTime.tryParse(
                   j['updated_at']?.toString() ?? '',
                 ) ??
                 DateTime.now(),
    );
  }
}