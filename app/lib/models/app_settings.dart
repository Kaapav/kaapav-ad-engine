class AppSettings {
  final bool pushNotifications;
  final bool budgetAlerts;
  final bool dailyReport;
  final bool autoScale;
  final bool autoKill;
  final double roasThreshold;
  final double cpaThreshold;
  final String currency;
  final String dateFormat;
  final String refreshInterval;

  const AppSettings({
    this.pushNotifications = true,
    this.budgetAlerts = true,
    this.dailyReport = true,
    this.autoScale = true,
    this.autoKill = false,
    this.roasThreshold = 2.0,
    this.cpaThreshold = 250,
    this.currency = '₹ INR',
    this.dateFormat = 'DD MMM YYYY',
    this.refreshInterval = '15 min',
  });

  AppSettings copyWith({
    bool? pushNotifications,
    bool? budgetAlerts,
    bool? dailyReport,
    bool? autoScale,
    bool? autoKill,
    double? roasThreshold,
    double? cpaThreshold,
    String? currency,
    String? dateFormat,
    String? refreshInterval,
  }) {
    return AppSettings(
      pushNotifications: pushNotifications ?? this.pushNotifications,
      budgetAlerts: budgetAlerts ?? this.budgetAlerts,
      dailyReport: dailyReport ?? this.dailyReport,
      autoScale: autoScale ?? this.autoScale,
      autoKill: autoKill ?? this.autoKill,
      roasThreshold: roasThreshold ?? this.roasThreshold,
      cpaThreshold: cpaThreshold ?? this.cpaThreshold,
      currency: currency ?? this.currency,
      dateFormat: dateFormat ?? this.dateFormat,
      refreshInterval: refreshInterval ?? this.refreshInterval,
    );
  }

  Map<String, dynamic> toJson() => {
        'pushNotifications': pushNotifications,
        'budgetAlerts': budgetAlerts,
        'dailyReport': dailyReport,
        'autoScale': autoScale,
        'autoKill': autoKill,
        'roasThreshold': roasThreshold,
        'cpaThreshold': cpaThreshold,
        'currency': currency,
        'dateFormat': dateFormat,
        'refreshInterval': refreshInterval,
      };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    return AppSettings(
      pushNotifications: json['pushNotifications'] as bool? ?? true,
      budgetAlerts: json['budgetAlerts'] as bool? ?? true,
      dailyReport: json['dailyReport'] as bool? ?? true,
      autoScale: json['autoScale'] as bool? ?? true,
      autoKill: json['autoKill'] as bool? ?? false,
      roasThreshold: (json['roasThreshold'] as num?)?.toDouble() ?? 2.0,
      cpaThreshold: (json['cpaThreshold'] as num?)?.toDouble() ?? 250,
      currency: json['currency'] as String? ?? '₹ INR',
      dateFormat: json['dateFormat'] as String? ?? 'DD MMM YYYY',
      refreshInterval: json['refreshInterval'] as String? ?? '15 min',
    );
  }
}