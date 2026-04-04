// lib/services/worker_api.dart
import 'package:dio/dio.dart';
import '../core/env_config.dart';
import '../models/campaign.dart';
import '../models/lead.dart';
import '../models/insights.dart';
import '../models/rule.dart';
import 'meta_auth.dart';

/// 🔥 GOAT Worker API Service
/// All Meta API calls go through Cloudflare Worker
/// Zero Meta tokens in Flutter, all server-side
class WorkerApiService {
  late final Dio _dio;
  final _auth = MetaAuth();

  WorkerApiService() {
    _dio = Dio(BaseOptions(
      baseUrl: EnvConfig.workerBaseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      validateStatus: (status) => status! < 500,
    ));

    _dio.interceptors.add(_WorkerInterceptor(_auth));
  }

  // ══════════════════════════════════════════════════════════════
  // Authentication
  // ══════════════════════════════════════════════════════════════

  /// Login with API key, get session token
  Future<String> login(String apiKey) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'api_key': apiKey},
    );

    if (response.data['success'] == true) {
      return response.data['data']['token'];
    }
    throw Exception(response.data['error'] ?? 'Login failed');
  }

  // ══════════════════════════════════════════════════════════════
  // Campaigns
  // ══════════════════════════════════════════════════════════════

  /// Get all campaigns
  Future<List<Campaign>> getCampaigns({
    String datePreset = 'last_30d',
    int limit = 50,
  }) async {
    final response = await _dio.get(
      '/api/campaigns',
      queryParameters: {
        'date_preset': datePreset,
        'limit': limit,
      },
    );

    if (response.data['success'] == true) {
      return (response.data['data'] as List)
          .map((json) => Campaign.fromJson(json))
          .toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch campaigns');
  }

  /// Get single campaign with details
  Future<Campaign> getCampaign(String id, {String datePreset = 'last_30d'}) async {
    final response = await _dio.get(
      '/api/campaigns/$id',
      queryParameters: {'date_preset': datePreset},
    );

    if (response.data['success'] == true) {
      return Campaign.fromJson(response.data['data']);
    }
    throw Exception(response.data['error'] ?? 'Campaign not found');
  }

  /// Get campaign insights
  Future<List<DayInsight>> getCampaignInsights(
    String id, {
    String datePreset = 'last_30d',
    String timeIncrement = '1',
  }) async {
    final response = await _dio.get(
      '/api/campaigns/$id/insights',
      queryParameters: {
        'date_preset': datePreset,
        'time_increment': timeIncrement,
      },
    );

    if (response.data['success'] == true) {
      return (response.data['data'] as List)
          .map((json) => DayInsight.fromJson(json))
          .toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch insights');
  }

  /// Update campaign status
  Future<void> updateCampaignStatus(String id, String status) async {
    final response = await _dio.patch(
      '/api/campaigns/$id',
      data: {'status': status},
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to update status');
    }
  }

  /// Update campaign budget
  Future<void> updateCampaignBudget(
    String id, {
    double? dailyBudget,
    double? lifetimeBudget,
  }) async {
    final response = await _dio.patch(
      '/api/campaigns/$id',
      data: {
        if (dailyBudget != null) 'daily_budget': dailyBudget,
        if (lifetimeBudget != null) 'lifetime_budget': lifetimeBudget,
      },
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to update budget');
    }
  }

  /// Create campaign
  Future<String> createCampaign({
    required String name,
    required String objective,
    String status = 'PAUSED',
    double? dailyBudget,
    double? lifetimeBudget,
    String? bidStrategy,
  }) async {
    final response = await _dio.post(
      '/api/campaigns',
      data: {
        'name': name,
        'objective': objective,
        'status': status,
        if (dailyBudget != null) 'daily_budget': dailyBudget,
        if (lifetimeBudget != null) 'lifetime_budget': lifetimeBudget,
        if (bidStrategy != null) 'bid_strategy': bidStrategy,
      },
    );

    if (response.data['success'] == true) {
      return response.data['data']['id'];
    }
    throw Exception(response.data['error'] ?? 'Failed to create campaign');
  }

  // ══════════════════════════════════════════════════════════════
  // Leads
  // ══════════════════════════════════════════════════════════════

  /// Get all leads
  Future<List<Lead>> getLeads({
    String? stage,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    final response = await _dio.get(
      '/api/leads',
      queryParameters: {
        if (stage != null) 'stage': stage,
        if (search != null) 'search': search,
        'limit': limit,
        'offset': offset,
      },
    );

    if (response.data['success'] == true) {
      return (response.data['data'] as List)
          .map((json) => Lead.fromJson(json))
          .toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch leads');
  }

  /// Get single lead with activities
  Future<Lead> getLead(String id) async {
    final response = await _dio.get('/api/leads/$id');

    if (response.data['success'] == true) {
      return Lead.fromJson(response.data['data']);
    }
    throw Exception(response.data['error'] ?? 'Lead not found');
  }

  /// Create lead
  Future<String> createLead({
    required String name,
    required String phone,
    String? email,
    String? campaign,
    String? campaignId,
    String stage = 'New',
    String source = 'Manual',
    String? product,
    double value = 0,
    String? notes,
  }) async {
    final response = await _dio.post(
      '/api/leads',
      data: {
        'name': name,
        'phone': phone,
        if (email != null) 'email': email,
        if (campaign != null) 'campaign': campaign,
        if (campaignId != null) 'campaign_id': campaignId,
        'stage': stage,
        'source': source,
        if (product != null) 'product': product,
        'value': value,
        if (notes != null) 'notes': notes,
      },
    );

    if (response.data['success'] == true) {
      return response.data['data']['id'];
    }
    throw Exception(response.data['error'] ?? 'Failed to create lead');
  }

  /// Update lead
  Future<void> updateLead(
    String id, {
    String? stage,
    String? notes,
    double? value,
    String? product,
    String? email,
    String? activityNote,
  }) async {
    final response = await _dio.patch(
      '/api/leads/$id',
      data: {
        if (stage != null) 'stage': stage,
        if (notes != null) 'notes': notes,
        if (value != null) 'value': value,
        if (product != null) 'product': product,
        if (email != null) 'email': email,
        if (activityNote != null) 'activity_note': activityNote,
      },
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to update lead');
    }
  }

  /// Delete lead
  Future<void> deleteLead(String id) async {
    final response = await _dio.delete('/api/leads/$id');

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to delete lead');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Analytics
  // ══════════════════════════════════════════════════════════════

  /// Get account summary
  Future<InsightsSummary> getAnalyticsSummary({
    String datePreset = 'last_30d',
  }) async {
    final response = await _dio.get(
      '/api/analytics/summary',
      queryParameters: {'date_preset': datePreset},
    );

    if (response.data['success'] == true) {
      return InsightsSummary.fromJson(response.data['data']);
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch analytics');
  }

  /// Get daily breakdown
  Future<List<DayInsight>> getAnalyticsDaily({
    String datePreset = 'last_30d',
  }) async {
    final response = await _dio.get(
      '/api/analytics/daily',
      queryParameters: {'date_preset': datePreset},
    );

    if (response.data['success'] == true) {
      return (response.data['data'] as List)
          .map((json) => DayInsight.fromJson(json))
          .toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch daily data');
  }

  /// Get CRM stats
  Future<Map<String, dynamic>> getCrmStats() async {
    final response = await _dio.get('/api/analytics/crm-stats');

    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch CRM stats');
  }

  // ══════════════════════════════════════════════════════════════
  // Rules
  // ══════════════════════════════════════════════════════════════

  /// Get all rules
  Future<List<AutoRule>> getRules() async {
    final response = await _dio.get('/api/rules');

    if (response.data['success'] == true) {
      return (response.data['data'] as List)
          .map((json) => AutoRule.fromJson(json))
          .toList();
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch rules');
  }

  /// Create rule
  Future<String> createRule({
    required String name,
    required String metric,
    required String operator,
    required double threshold,
    required String actionType,
    double? actionValue,
    String? conditionText,
    String? actionText,
    bool enabled = true,
    int checkInterval = 360,
  }) async {
    final response = await _dio.post(
      '/api/rules',
      data: {
        'name': name,
        'metric': metric,
        'operator': operator,
        'threshold': threshold,
        'action_type': actionType,
        if (actionValue != null) 'action_value': actionValue,
        if (conditionText != null) 'condition_text': conditionText,
        if (actionText != null) 'action_text': actionText,
        'enabled': enabled,
        'check_interval': checkInterval,
      },
    );

    if (response.data['success'] == true) {
      return response.data['data']['id'];
    }
    throw Exception(response.data['error'] ?? 'Failed to create rule');
  }

  /// Toggle rule
  Future<void> toggleRule(String id, bool enabled) async {
    final response = await _dio.patch(
      '/api/rules/$id',
      data: {'enabled': enabled},
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to toggle rule');
    }
  }

  /// Delete rule
  Future<void> deleteRule(String id) async {
    final response = await _dio.delete('/api/rules/$id');

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to delete rule');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Notifications
  // ══════════════════════════════════════════════════════════════

  /// Get notifications
  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    final response = await _dio.get(
      '/api/notifications',
      queryParameters: {'limit': limit},
    );

    if (response.data['success'] == true) {
      return List<Map<String, dynamic>>.from(response.data['data']);
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch notifications');
  }

  /// Register device for FCM
  Future<void> registerDevice(String fcmToken, {String? deviceName}) async {
    final response = await _dio.post(
      '/api/notifications/register-device',
      data: {
        'token': fcmToken,
        if (deviceName != null) 'device_name': deviceName,
        'platform': 'android',
      },
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to register device');
    }
  }

  /// Mark all as read
  Future<void> markNotificationsRead() async {
    final response = await _dio.post('/api/notifications/mark-read');

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to mark as read');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Bridge (WhatsApp)
  // ══════════════════════════════════════════════════════════════

  /// Send follow-up via WhatsApp bot
  Future<void> sendFollowUp({
    required String phone,
    String? leadId,
    String? name,
    String? product,
  }) async {
    final response = await _dio.post(
      '/api/bridge/followup',
      data: {
        'phone': phone,
        if (leadId != null) 'lead_id': leadId,
        if (name != null) 'name': name,
        if (product != null) 'product': product,
      },
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to send follow-up');
    }
  }

  /// Get bridge stats
  Future<Map<String, dynamic>> getBridgeStats() async {
    final response = await _dio.get('/api/bridge/stats');

    if (response.data['success'] == true) {
      return response.data['data'];
    }
    throw Exception(response.data['error'] ?? 'Failed to fetch stats');
  }

  // ══════════════════════════════════════════════════════════════
  // Sheets
  // ══════════════════════════════════════════════════════════════

  /// Sync campaigns to Google Sheets
  Future<void> syncCampaignsToSheets(String sheetId, {String datePreset = 'last_30d'}) async {
    final response = await _dio.post(
      '/api/sheets/sync-campaigns',
      data: {
        'sheetId': sheetId,
        'date_preset': datePreset,
      },
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to sync campaigns');
    }
  }

  /// Sync leads to Google Sheets
  Future<void> syncLeadsToSheets(String sheetId) async {
    final response = await _dio.post(
      '/api/sheets/sync-leads',
      data: {'sheetId': sheetId},
    );

    if (response.data['success'] != true) {
      throw Exception(response.data['error'] ?? 'Failed to sync leads');
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Dio Interceptor for Worker Auth
// ══════════════════════════════════════════════════════════════

class _WorkerInterceptor extends Interceptor {
  final MetaAuth _auth;

  _WorkerInterceptor(this._auth);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Skip auth for login endpoint
    if (options.path.contains('/auth/login')) {
      return handler.next(options);
    }

    // Try API key first
    final apiKey = await _auth.getApiKey();
    if (apiKey != null) {
      options.headers['X-API-Key'] = apiKey;
      return handler.next(options);
    }

    // Fall back to session token
    final sessionToken = await _auth.getSessionToken();
    if (sessionToken != null) {
      options.headers['Authorization'] = 'Bearer $sessionToken';
      return handler.next(options);
    }

    // No auth available
    handler.reject(
      DioException(
        requestOptions: options,
        error: 'No authentication credentials available',
        type: DioExceptionType.cancel,
      ),
    );
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Handle 401 Unauthorized
    if (err.response?.statusCode == 401) {
      // Clear invalid credentials
      _auth.deleteApiKey();
      _auth.deleteSessionToken();
    }

    handler.next(err);
  }
}