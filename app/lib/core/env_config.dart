class EnvConfig {
  EnvConfig._();

  static const String workerBaseUrl =
      'https://kaapav-ad-engine-api.kaapavin.workers.dev';

  static const String whatsappBotUrl = 'https://wa.kaapav.com';
  static const String appVersion = '1.0.0';
  static const String environment =
      String.fromEnvironment('ENV', defaultValue: 'production');

  static String get healthUrl => '$workerBaseUrl/health';
  static String get authLoginUrl => '$workerBaseUrl/auth/login';
  static String get campaignsUrl => '$workerBaseUrl/api/campaigns';
  static String get leadsUrl => '$workerBaseUrl/api/leads';
  static String get rulesUrl => '$workerBaseUrl/api/rules';
  static String get analyticsUrl => '$workerBaseUrl/api/analytics';
  static String get notificationsUrl => '$workerBaseUrl/api/notifications';
  static String get bridgeUrl => '$workerBaseUrl/api/bridge';
  static String get sheetsUrl => '$workerBaseUrl/api/sheets';

  static String get metaWebhookUrl => '$workerBaseUrl/api/webhooks/meta';
  static String get whatsappWebhookUrl => '$workerBaseUrl/api/webhooks/whatsapp';
}