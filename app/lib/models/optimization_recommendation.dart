import 'dart:convert';

class OptimizationRecommendation {
  final String id;
  final String entityType;
  final String entityId;

  final String priority; // low | medium | high | critical
  final String actionType; // DecisionAction
  final String title;
  final String description;

  final double? score;
  final String status; // open | applied | dismissed | resolved

  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  const OptimizationRecommendation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.priority,
    required this.actionType,
    required this.title,
    required this.description,
    required this.score,
    required this.status,
    required this.payload,
    required this.createdAt,
  });

  bool get isCritical => priority == 'critical';
  bool get isOpen => status == 'open';
  bool get isActionable => isOpen;

  static double? _dNullable(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime _dt(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    return DateTime.tryParse(v.toString()) ??
        DateTime.fromMillisecondsSinceEpoch(0);
  }

  static Map<String, dynamic>? _payload(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.map((k, val) => MapEntry(k.toString(), val));
    if (v is String) {
      final s = v.trim();
      if (s.isEmpty) return null;
      try {
        final decoded = jsonDecode(s);
        if (decoded is Map) {
          return decoded.map((k, val) => MapEntry(k.toString(), val));
        }
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  factory OptimizationRecommendation.fromJson(Map<String, dynamic> json) {
    return OptimizationRecommendation(
      id: json['id']?.toString() ?? '',
      entityType: (json['entityType'] ?? json['entity_type'] ?? '').toString(),
      entityId: (json['entityId'] ?? json['entity_id'] ?? '').toString(),
      priority: (json['priority'] ?? 'medium').toString().toLowerCase(),
      actionType: (json['actionType'] ?? json['action_type'] ?? 'hold')
          .toString()
          .toLowerCase(),
      title: (json['title'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      score: _dNullable(json['score']),
      status: (json['status'] ?? 'open').toString().toLowerCase(),
      payload: _payload(json['payload']),
      createdAt: _dt(json['createdAt'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entityType': entityType,
      'entityId': entityId,
      'priority': priority,
      'actionType': actionType,
      'title': title,
      'description': description,
      'score': score,
      'status': status,
      'payload': payload,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}