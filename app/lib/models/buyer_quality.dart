class BuyerQuality {
  final String id;
  final String? leadId;
  final String phone;
  final String? customerName;

  final int totalOrders;
  final double totalRevenue;
  final double avgOrderValue;
  final int repeatOrders;

  /// Important: Worker can store this as 0-1 or 0-100.
  /// We keep the raw value and render safely in UI.
  final double prepaidRatio;

  final int refundCount;
  final double responseScore;
  final double buyerQualityScore;

  final String buyerTier; // platinum | gold | silver | risk
  final bool lookalikeSeedEligible;

  final String? productAffinity;
  final DateTime updatedAt;

  const BuyerQuality({
    required this.id,
    required this.leadId,
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

  bool get isPlatinum => buyerTier == 'platinum';
  bool get isGold => buyerTier == 'gold';
  bool get isSeedEligible => lookalikeSeedEligible;

  String get displayName =>
      (customerName?.trim().isNotEmpty ?? false) ? customerName!.trim() : phone;

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

  static bool _b01(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is num) return v.toInt() == 1;
    final s = v.toString().toLowerCase().trim();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  factory BuyerQuality.fromJson(Map<String, dynamic> json) {
    return BuyerQuality(
      id: json['id']?.toString() ?? '',
      leadId: (json['leadId'] ?? json['lead_id'])?.toString(),
      phone: json['phone']?.toString() ?? '',
      customerName: (json['customerName'] ?? json['customer_name'])?.toString(),
      totalOrders: _i(json['totalOrders'] ?? json['total_orders']),
      totalRevenue: _d(json['totalRevenue'] ?? json['total_revenue']),
      avgOrderValue: _d(json['avgOrderValue'] ?? json['avg_order_value']),
      repeatOrders: _i(json['repeatOrders'] ?? json['repeat_orders']),
      prepaidRatio: _d(json['prepaidRatio'] ?? json['prepaid_ratio']),
      refundCount: _i(json['refundCount'] ?? json['refund_count']),
      responseScore: _d(json['responseScore'] ?? json['response_score']),
      buyerQualityScore:
          _d(json['buyerQualityScore'] ?? json['buyer_quality_score']),
      buyerTier: (json['buyerTier'] ?? json['buyer_tier'] ?? 'silver')
          .toString()
          .toLowerCase(),
      lookalikeSeedEligible: _b01(
        json['lookalikeSeedEligible'] ?? json['lookalike_seed_eligible'],
      ),
      productAffinity:
          (json['productAffinity'] ?? json['product_affinity'])?.toString(),
      updatedAt: _dt(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'leadId': leadId,
      'phone': phone,
      'customerName': customerName,
      'totalOrders': totalOrders,
      'totalRevenue': totalRevenue,
      'avgOrderValue': avgOrderValue,
      'repeatOrders': repeatOrders,
      'prepaidRatio': prepaidRatio,
      'refundCount': refundCount,
      'responseScore': responseScore,
      'buyerQualityScore': buyerQualityScore,
      'buyerTier': buyerTier,
      'lookalikeSeedEligible': lookalikeSeedEligible ? 1 : 0,
      'productAffinity': productAffinity,
      'updatedAt': updatedAt.toIso8601String(),
    };
  }
}