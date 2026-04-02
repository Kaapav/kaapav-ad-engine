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
    required this.campaignId,
    required this.stage,
    required this.source,
    this.product,
    this.value,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.activities = const [],
  });

  Lead copyWith({String? stage, String? notes, double? value}) {
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
}

class LeadActivity {
  final String type; // 'call', 'whatsapp', 'note', 'stage_change', 'order'
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
        _ => '•',
      };
}