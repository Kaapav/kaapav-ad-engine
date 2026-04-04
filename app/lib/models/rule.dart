class AutoRule {
  final String id;
  final String name;
  final String condition;
  final String action;
  final String metric;
  final String operator;
  final double threshold;
  final String actionType;
  final String? actionValue;
  final bool enabled;
  final int triggeredCount;
  final DateTime? lastTriggered;
  final String? appliedTo;
  final String? checkInterval;

  const AutoRule({
    required this.id,
    required this.name,
    required this.condition,
    required this.action,
    required this.metric,
    required this.operator,
    required this.threshold,
    required this.actionType,
    this.actionValue,
    this.enabled = true,
    this.triggeredCount = 0,
    this.lastTriggered,
    this.appliedTo,
    this.checkInterval,
  });

  AutoRule copyWith({
    bool? enabled,
    int? triggeredCount,
    DateTime? lastTriggered,
  }) {
    return AutoRule(
      id: id,
      name: name,
      condition: condition,
      action: action,
      metric: metric,
      operator: operator,
      threshold: threshold,
      actionType: actionType,
      actionValue: actionValue,
      enabled: enabled ?? this.enabled,
      triggeredCount: triggeredCount ?? this.triggeredCount,
      lastTriggered: lastTriggered ?? this.lastTriggered,
      appliedTo: appliedTo,
      checkInterval: checkInterval,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'condition': condition,
        'action': action,
        'metric': metric,
        'operator': operator,
        'threshold': threshold,
        'actionType': actionType,
        'actionValue': actionValue,
        'enabled': enabled,
        'triggeredCount': triggeredCount,
        'lastTriggered': lastTriggered?.toIso8601String(),
        'appliedTo': appliedTo,
        'checkInterval': checkInterval,
      };

  factory AutoRule.fromJson(Map<String, dynamic> json) {
    return AutoRule(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      condition: json['condition'] as String? ?? '',
      action: json['action'] as String? ?? '',
      metric: json['metric'] as String? ?? 'roas',
      operator: json['operator'] as String? ?? '<',
      threshold: (json['threshold'] as num?)?.toDouble() ?? 0,
      actionType: json['actionType'] as String? ?? 'pause',
      actionValue: json['actionValue'] as String?,
      enabled: json['enabled'] as bool? ?? true,
      triggeredCount: json['triggeredCount'] as int? ?? 0,
      lastTriggered: json['lastTriggered'] != null
          ? DateTime.parse(json['lastTriggered'])
          : null,
      appliedTo: json['appliedTo'] as String?,
      checkInterval: json['checkInterval'] as String?,
    );
  }
}

class ActivityEntry {
  final String id;
  final String type;
  final String title;
  final String description;
  final DateTime timestamp;
  final String? campaignId;
  final String? ruleId;

  const ActivityEntry({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.timestamp,
    this.campaignId,
    this.ruleId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'title': title,
        'description': description,
        'timestamp': timestamp.toIso8601String(),
        'campaignId': campaignId,
        'ruleId': ruleId,
      };

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: json['id'] as String? ?? '',
      type: json['type'] as String? ?? 'info',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      timestamp: json['timestamp'] != null
          ? DateTime.parse(json['timestamp'])
          : DateTime.now(),
      campaignId: json['campaignId'] as String?,
      ruleId: json['ruleId'] as String?,
    );
  }
}