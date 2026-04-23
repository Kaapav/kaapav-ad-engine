// lib/models/optimization_recommendation.dart

class OptimizationRecommendation {
  final String id;
  final String entityType;
  final String entityId;
  final String priority;
  final String actionType;
  final String title;
  final String description;
  final int? score;
  final String status;
  final Map<String, dynamic>? payload;
  final DateTime createdAt;

  OptimizationRecommendation({
    required this.id,
    required this.entityType,
    required this.entityId,
    required this.priority,
    required this.actionType,
    required this.title,
    required this.description,
    this.score,
    required this.status,
    this.payload,
    required this.createdAt,
  });

  factory OptimizationRecommendation.fromJson(Map<String, dynamic> json) {
    return OptimizationRecommendation(
      id: json['id']?.toString() ?? '',
      entityType: json['entity_type']?.toString() ?? '',
      entityId: json['entity_id']?.toString() ?? '',
      priority: json['priority']?.toString() ?? 'medium',
      actionType: json['action_type']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      score: json['score'] as int?,
      status: json['status']?.toString() ?? 'open',
      payload: json['payload'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? 
          DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'entity_type': entityType,
      'entity_id': entityId,
      'priority': priority,
      'action_type': actionType,
      'title': title,
      'description': description,
      'score': score,
      'status': status,
      'payload': payload,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isCritical => priority == 'critical';
  bool get isHigh => priority == 'high';
  bool get isMedium => priority == 'medium';
  bool get isLow => priority == 'low';
  
  bool get isOpen => status == 'open';
  bool get isApplied => status == 'applied';
  bool get isDismissed => status == 'dismissed';
  
  bool get isActionable => isOpen && actionType.isNotEmpty;

  OptimizationRecommendation copyWith({
    String? id,
    String? entityType,
    String? entityId,
    String? priority,
    String? actionType,
    String? title,
    String? description,
    int? score,
    String? status,
    Map<String, dynamic>? payload,
    DateTime? createdAt,
  }) {
    return OptimizationRecommendation(
      id: id ?? this.id,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      priority: priority ?? this.priority,
      actionType: actionType ?? this.actionType,
      title: title ?? this.title,
      description: description ?? this.description,
      score: score ?? this.score,
      status: status ?? this.status,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}