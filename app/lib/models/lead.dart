class Lead {
  final String id;
  final String name;
  final String phone;
  final String? email;
  final String campaign;
  final String campaignId;
  final String stage;
  final String source;
  final String? product;
  final double? value;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<LeadActivity> activities;

  const Lead({
    required this.id,
    required this.name,
    required this.phone,
    this.email,
    required this.campaign,
    this.campaignId = '',
    this.stage = 'New',
    this.source = 'Facebook',
    this.product,
    this.value,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.activities = const [],
  });

  Lead copyWith({
    String? stage,
    String? notes,
    double? value,
  }) {
    return Lead(
      id: id,
      name: name,
      phone: phone,
      email: email,
      campaign: campaign,
      campaignId: campaignId,
      stage: stage ?? this.stage,
      source: source,
      product: product,
      value: value ?? this.value,
      notes: notes ?? this.notes,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
      activities: activities,
    );
  }

  factory Lead.fromJson(Map<String, dynamic> json) {
    return Lead(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ??
          json['full_name'] as String? ??
          '',
      phone: json['phone'] as String? ??
          json['phone_number'] as String? ??
          '',
      email: json['email'] as String?,
      campaign: json['campaign'] as String? ??
          json['campaign_name'] as String? ??
          '',
      campaignId: json['campaignId'] as String? ??
          json['campaign_id'] as String? ??
          '',
      stage: json['stage'] as String? ?? 'New',
      source: json['source'] as String? ??
          json['platform'] as String? ??
          'Facebook',
      product: json['product'] as String?,
      value: (json['value'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : json['created_time'] != null
              ? DateTime.parse(json['created_time'])
              : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'])
          : DateTime.now(),
      activities: json['activities'] != null
          ? (json['activities'] as List)
              .map((a) => LeadActivity.fromJson(a as Map<String, dynamic>))
              .toList()
          : [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'email': email,
        'campaign': campaign,
        'campaignId': campaignId,
        'stage': stage,
        'source': source,
        'product': product,
        'value': value,
        'notes': notes,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'activities': activities.map((a) => a.toJson()).toList(),
      };
}

class LeadActivity {
  final String type;
  final String description;
  final DateTime timestamp;
  final String? by;

  const LeadActivity({
    required this.type,
    required this.description,
    required this.timestamp,
    this.by,
  });

  String get icon => switch (type) {
        'call' => '📞',
        'whatsapp' => '💬',
        'note' => '📝',
        'stage_change' => '🔄',
        'order' => '🛒',
        _ => '📋',
      };

  factory LeadActivity.fromJson(Map<String, dynamic> json) {
    return LeadActivity(
      type: json['type'] as String? ?? 'note',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      by: json['by'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'type': type,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'by': by,
      };
}