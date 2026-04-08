import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../core/env_config.dart';
import '../models/campaign.dart';
import '../models/insights.dart';
import '../models/lead.dart';
import '../models/rule.dart';
import 'meta_auth.dart';

/// 🔥 Production-ready Worker API Service
/// All external business/API access should go through Cloudflare Worker.
/// Meta tokens must never live in Flutter.
class WorkerApiService {
  late final Dio _dio;
  final MetaAuth _auth;

  WorkerApiService({MetaAuth? auth}) : _auth = auth ?? MetaAuth() {
    _dio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.workerBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 20),
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) => status != null && status < 400,
      ),
    );

    _dio.interceptors.add(_WorkerInterceptor(_auth));

    if (kDebugMode) {
      _dio.interceptors.add(
        LogInterceptor(
          requestBody: true,
          responseBody: true,
          requestHeader: false,
          responseHeader: false,
          error: true,
          logPrint: (obj) => debugPrint(obj.toString()),
        ),
      );
    }
  }
 
   // ══════════════════════════════════════════════════════════════
  // Core response helpers
  // ══════════════════════════════════════════════════════════════

  Map<String, dynamic> _asMap(dynamic value, {String context = 'response'}) {
    if (value is Map<String, dynamic>) return value;
    throw Exception('Invalid $context format');
  }

  List<dynamic> _asList(dynamic value, {String context = 'response list'}) {
    if (value is List) return value;
    throw Exception('Invalid $context format');
  }

  dynamic _unwrapData(Response response, {String fallbackError = 'Request failed'}) {
    final body = _asMap(response.data, context: 'API response');

    final success = body['success'] == true;
    if (!success) {
      throw Exception(_extractApiError(body, fallbackError: fallbackError));
    }

    return body['data'];
  }

  List<dynamic> _unwrapList(Response response, {String fallbackError = 'Request failed'}) {
    final data = _unwrapData(response, fallbackError: fallbackError);
    return _asList(data, context: 'API data list');
  }

  String _extractApiError(
    Map<String, dynamic> body, {
    String fallbackError = 'Request failed',
  }) {
    final error = body['error'];

    if (error is String && error.trim().isNotEmpty) {
      return error.trim();
    }

    if (error is Map<String, dynamic>) {
      final message = error['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }

    return fallbackError;
  }

Never _throwDioError(
  DioException e, {
  String fallbackMessage = 'Network request failed',
}) {
  debugPrint('DIO ERROR TYPE: ${e.type}');
  debugPrint('DIO ERROR MESSAGE: ${e.message}');
  debugPrint('DIO ERROR: ${e.error}');
  debugPrint('DIO RESPONSE: ${e.response?.data}');
  debugPrint('DIO STATUS: ${e.response?.statusCode}');
    if (e.response?.data is Map<String, dynamic>) {
      final body = e.response!.data as Map<String, dynamic>;
      throw Exception(_extractApiError(body, fallbackError: fallbackMessage));
    }

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
        throw Exception('Connection timeout. Please try again.');
      case DioExceptionType.sendTimeout:
        throw Exception('Request timeout while sending data.');
      case DioExceptionType.receiveTimeout:
        throw Exception('Server took too long to respond.');
      case DioExceptionType.connectionError:
        throw Exception('No internet connection or server unreachable.');
      case DioExceptionType.badCertificate:
        throw Exception('Secure connection failed.');
      case DioExceptionType.cancel:
  throw Exception(e.error?.toString() ?? 'Request was cancelled.');
      case DioExceptionType.badResponse:
        throw Exception(fallbackMessage);
      case DioExceptionType.unknown:
        if (e.error is SocketException) {
          throw Exception('No internet connection.');
        }
        throw Exception(e.message ?? fallbackMessage);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Authentication
  // ══════════════════════════════════════════════════════════════

  /// Login with API key and persist session token.
  Future<String> login(String apiKey) async {
    try {
      final response = await _dio.post(
        '/auth/login',
        data: {'api_key': apiKey},
      );

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Login failed'),
        context: 'login data',
      );

      final token = data['token']?.toString();
      if (token == null || token.isEmpty) {
        throw Exception('Login succeeded but no session token was returned.');
      }

      await _auth.saveApiKey(apiKey);
      await _auth.saveSessionToken(token);

      return token;
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Login failed');
    }
  }

  Future<void> logout() async {
    await _auth.deleteSessionToken();
    await _auth.deleteApiKey();
  }

Future<bool> isConfigured() async {
  return (await _auth.hasApiKey()) || (await _auth.hasSessionToken());
}
  // ══════════════════════════════════════════════════════════════
  // Campaigns
  // ══════════════════════════════════════════════════════════════

Future<List<Campaign>> getCampaigns({
  String datePreset = 'last_30d',
  int limit = 50,
}) async {
  try {
    debugPrint('CALLING getCampaigns');
    final response = await _dio.get(
      '/api/campaigns',
      queryParameters: {
        'date_preset': datePreset,
        'limit': limit,
      },
    );
    debugPrint('getCampaigns STATUS: ${response.statusCode}');
    debugPrint('getCampaigns DATA: ${response.data}');


      final list = _unwrapList(
        response,
        fallbackError: 'Failed to fetch campaigns',
      );

      return list
          .map((json) => Campaign.fromJson(_asMap(json, context: 'campaign')))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch campaigns');
    }
  }

  Future<Campaign> getCampaign(
    String id, {
    String datePreset = 'last_30d',
  }) async {
    try {
      final response = await _dio.get(
        '/api/campaigns/$id',
        queryParameters: {'date_preset': datePreset},
      );

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Campaign not found'),
        context: 'campaign',
      );

      return Campaign.fromJson(data);
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Campaign not found');
    }
  }

  Future<List<DayInsight>> getCampaignInsights(
    String id, {
    String datePreset = 'last_30d',
    String timeIncrement = '1',
  }) async {
    try {
      final response = await _dio.get(
        '/api/campaigns/$id/insights',
        queryParameters: {
          'date_preset': datePreset,
          'time_increment': timeIncrement,
        },
      );

      final list = _unwrapList(
        response,
        fallbackError: 'Failed to fetch campaign insights',
      );

      return list
          .map((json) => DayInsight.fromJson(_asMap(json, context: 'day insight')))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch campaign insights');
    }
  }

  Future<void> updateCampaignStatus(String id, String status) async {
    try {
      final response = await _dio.patch(
        '/api/campaigns/$id',
        data: {'status': status},
      );

      _unwrapData(response, fallbackError: 'Failed to update campaign status');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to update campaign status');
    }
  }

  Future<void> updateCampaignBudget(
    String id, {
    double? dailyBudget,
    double? lifetimeBudget,
  }) async {
    try {
      final response = await _dio.patch(
        '/api/campaigns/$id',
        data: {
          if (dailyBudget != null) 'daily_budget': dailyBudget,
          if (lifetimeBudget != null) 'lifetime_budget': lifetimeBudget,
        },
      );

      _unwrapData(response, fallbackError: 'Failed to update campaign budget');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to update campaign budget');
    }
  }

  Future<String> createCampaign({
    required String name,
    required String objective,
    String status = 'PAUSED',
    double? dailyBudget,
    double? lifetimeBudget,
    String? bidStrategy,
  }) async {
    try {
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

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Failed to create campaign'),
        context: 'campaign create response',
      );

      final id = data['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Campaign created but no id was returned.');
      }

      return id;
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to create campaign');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Leads
  // ══════════════════════════════════════════════════════════════

  Future<List<Lead>> getLeads({
    String? stage,
    String? search,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      final response = await _dio.get(
        '/api/leads',
        queryParameters: {
          if (stage != null && stage.isNotEmpty && stage != 'All') 'stage': stage,
          if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
          'limit': limit,
          'offset': offset,
        },
      );

      final list = _unwrapList(
        response,
        fallbackError: 'Failed to fetch leads',
      );

      return list
          .map((json) => Lead.fromJson(_asMap(json, context: 'lead')))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch leads');
    }
  }

  Future<Lead> getLead(String id) async {
    try {
      final response = await _dio.get('/api/leads/$id');

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Lead not found'),
        context: 'lead',
      );

      return Lead.fromJson(data);
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Lead not found');
    }
  }

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
    try {
      final response = await _dio.post(
        '/api/leads',
        data: {
          'name': name,
          'phone': phone,
          if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
          if (campaign != null && campaign.trim().isNotEmpty) 'campaign': campaign.trim(),
          if (campaignId != null && campaignId.trim().isNotEmpty) 'campaign_id': campaignId.trim(),
          'stage': stage,
          'source': source,
          if (product != null && product.trim().isNotEmpty) 'product': product.trim(),
          'value': value,
          if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
        },
      );

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Failed to create lead'),
        context: 'lead create response',
      );

      final id = data['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Lead created but no id was returned.');
      }

      return id;
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to create lead');
    }
  }

  Future<void> updateLead(
    String id, {
    String? stage,
    String? notes,
    double? value,
    String? product,
    String? email,
    String? activityNote,
  }) async {
    try {
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

      _unwrapData(response, fallbackError: 'Failed to update lead');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to update lead');
    }
  }

  Future<void> deleteLead(String id) async {
    try {
      final response = await _dio.delete('/api/leads/$id');
      _unwrapData(response, fallbackError: 'Failed to delete lead');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to delete lead');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Analytics
  // ══════════════════════════════════════════════════════════════

  Future<InsightsSummary> getAnalyticsSummary({
    String datePreset = 'last_30d',
  }) async {
    try {
      final response = await _dio.get(
        '/api/analytics/summary',
        queryParameters: {'date_preset': datePreset},
      );

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Failed to fetch analytics summary'),
        context: 'analytics summary',
      );

      return InsightsSummary.fromJson(data);
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch analytics summary');
    }
  }

  Future<List<DayInsight>> getAnalyticsDaily({
    String datePreset = 'last_30d',
  }) async {
    try {
      final response = await _dio.get(
        '/api/analytics/daily',
        queryParameters: {'date_preset': datePreset},
      );

      final list = _unwrapList(
        response,
        fallbackError: 'Failed to fetch analytics daily data',
      );

      return list
          .map((json) => DayInsight.fromJson(_asMap(json, context: 'analytics day')))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch analytics daily data');
    }
  }

Future<Map<String, dynamic>> getCrmStats() async {
  try {
    debugPrint('CALLING getCrmStats');
    final response = await _dio.get('/api/analytics/crm-stats');
    debugPrint('getCrmStats STATUS: ${response.statusCode}');
    debugPrint('getCrmStats DATA: ${response.data}');

      return _asMap(
        _unwrapData(response, fallbackError: 'Failed to fetch CRM stats'),
        context: 'crm stats',
      );
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch CRM stats');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Rules
  // ══════════════════════════════════════════════════════════════

  Future<List<AutoRule>> getRules() async {
    try {
      final response = await _dio.get('/api/rules');

      final list = _unwrapList(
        response,
        fallbackError: 'Failed to fetch automation rules',
      );

      return list
          .map((json) => AutoRule.fromJson(_asMap(json, context: 'rule')))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch automation rules');
    }
  }

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
    try {
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

      final data = _asMap(
        _unwrapData(response, fallbackError: 'Failed to create automation rule'),
        context: 'rule create response',
      );

      final id = data['id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Rule created but no id was returned.');
      }

      return id;
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to create automation rule');
    }
  }

  Future<void> toggleRule(String id, bool enabled) async {
    try {
      final response = await _dio.patch(
        '/api/rules/$id',
        data: {'enabled': enabled},
      );

      _unwrapData(response, fallbackError: 'Failed to update automation rule');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to update automation rule');
    }
  }

  Future<void> deleteRule(String id) async {
    try {
      final response = await _dio.delete('/api/rules/$id');
      _unwrapData(response, fallbackError: 'Failed to delete automation rule');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to delete automation rule');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Notifications
  // ══════════════════════════════════════════════════════════════

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    try {
      final response = await _dio.get(
        '/api/notifications',
        queryParameters: {'limit': limit},
      );

      final list = _unwrapList(
        response,
        fallbackError: 'Failed to fetch notifications',
      );

      return list
          .map((item) => _asMap(item, context: 'notification'))
          .toList();
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch notifications');
    }
  }

  Future<void> registerDevice(
    String fcmToken, {
    String? deviceName,
    String platform = 'android',
  }) async {
    try {
      final response = await _dio.post(
        '/api/notifications/register-device',
        data: {
          'token': fcmToken,
          if (deviceName != null && deviceName.trim().isNotEmpty)
            'device_name': deviceName.trim(),
          'platform': platform,
        },
      );

      _unwrapData(response, fallbackError: 'Failed to register device');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to register device');
    }
  }

  Future<void> markNotificationsRead() async {
    try {
      final response = await _dio.post('/api/notifications/mark-read');
      _unwrapData(response, fallbackError: 'Failed to mark notifications as read');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to mark notifications as read');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Bridge / WhatsApp
  // ══════════════════════════════════════════════════════════════

  Future<void> sendFollowUp({
    required String phone,
    String? leadId,
    String? name,
    String? product,
  }) async {
    try {
      final response = await _dio.post(
        '/api/bridge/followup',
        data: {
          'phone': phone,
          if (leadId != null && leadId.trim().isNotEmpty) 'lead_id': leadId.trim(),
          if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
          if (product != null && product.trim().isNotEmpty) 'product': product.trim(),
        },
      );

      _unwrapData(response, fallbackError: 'Failed to send WhatsApp follow-up');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to send WhatsApp follow-up');
    }
  }

  Future<Map<String, dynamic>> getBridgeStats() async {
    try {
      final response = await _dio.get('/api/bridge/stats');

      return _asMap(
        _unwrapData(response, fallbackError: 'Failed to fetch bridge stats'),
        context: 'bridge stats',
      );
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to fetch bridge stats');
    }
  }

  // ══════════════════════════════════════════════════════════════
  // Sheets
  // ══════════════════════════════════════════════════════════════

  Future<void> syncCampaignsToSheets(
    String sheetId, {
    String datePreset = 'last_30d',
  }) async {
    try {
      final response = await _dio.post(
        '/api/sheets/sync-campaigns',
        data: {
          'sheetId': sheetId,
          'date_preset': datePreset,
        },
      );

      _unwrapData(response, fallbackError: 'Failed to sync campaigns to Sheets');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to sync campaigns to Sheets');
    }
  }

  Future<void> syncLeadsToSheets(String sheetId) async {
    try {
      final response = await _dio.post(
        '/api/sheets/sync-leads',
        data: {'sheetId': sheetId},
      );

      _unwrapData(response, fallbackError: 'Failed to sync leads to Sheets');
    } on DioException catch (e) {
      _throwDioError(e, fallbackMessage: 'Failed to sync leads to Sheets');
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Dio interceptor for Worker auth
// ══════════════════════════════════════════════════════════════

class _WorkerInterceptor extends Interceptor {
  final MetaAuth _auth;

  _WorkerInterceptor(this._auth);

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.path.contains('/auth/login')) {
      handler.next(options);
      return;
    }

    final apiKey = await _auth.getApiKey();
    final sessionToken = await _auth.getSessionToken();

    debugPrint('REQUEST PATH: ${options.path}');
    debugPrint('API KEY: $apiKey');
    debugPrint('SESSION TOKEN: $sessionToken');

if (sessionToken != null && sessionToken.trim().isNotEmpty) {
  options.headers['Authorization'] = 'Bearer ${sessionToken.trim()}';
} else if (apiKey != null && apiKey.trim().isNotEmpty) {
  options.headers['X-API-Key'] = apiKey.trim();
}

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 401) {
      _auth.deleteSessionToken();
    }

    handler.next(err);
  }
}