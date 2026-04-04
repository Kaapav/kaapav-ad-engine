import 'package:dio/dio.dart';
import '../core/constants.dart';

class MetaApiService {
  late final Dio _dio;

  // Set these from .env / secure storage in production
  String accessToken = '';
  String adAccountId = '';
  String pixelId = '';

  MetaApiService() {
    _dio = Dio(BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
    ));
    _dio.interceptors.add(_MetaInterceptor(this));
  }

  void configure({required String token, required String accountId, String? pixel}) {
    accessToken = token;
    adAccountId = accountId;
    if (pixel != null) pixelId = pixel;
  }

  // ═══════════════════════════════════════════════════════════
  // CAMPAIGNS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getCampaigns({
    String datePreset = 'last_30d',
    int limit = 50,
  }) async {
    final res = await _dio.get(
      K.campaigns(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields': 'name,objective,status,daily_budget,lifetime_budget,bid_strategy,start_time,stop_time,updated_time',
        'limit': limit,
        'date_preset': datePreset,
      },
    );
    return res.data;
  }

  Future<Map<String, dynamic>> getCampaignInsights(
    String campaignId, {
    String datePreset = 'last_30d',
    String? timeIncrement,
  }) async {
    final params = <String, dynamic>{
      'access_token': accessToken,
      'fields': K.insightFields.join(','),
      'date_preset': datePreset,
    };
    if (timeIncrement != null) params['time_increment'] = timeIncrement;

    final res = await _dio.get(K.campaignInsights(campaignId), queryParameters: params);
    return res.data;
  }

  Future<Map<String, dynamic>> getAccountInsights({
    String datePreset = 'last_30d',
    String? timeIncrement,
  }) async {
    final params = <String, dynamic>{
      'access_token': accessToken,
      'fields': K.insightFields.join(','),
      'date_preset': datePreset,
    };
    if (timeIncrement != null) params['time_increment'] = timeIncrement;

    final res = await _dio.get(K.insights(adAccountId), queryParameters: params);
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // CAMPAIGN ACTIONS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> updateCampaignStatus(String campaignId, String status) async {
    final res = await _dio.post(
      K.campaign(campaignId),
      queryParameters: {'access_token': accessToken},
      data: {'status': status},
    );
    return res.data;
  }

  Future<Map<String, dynamic>> updateCampaignBudget(String campaignId, {double? dailyBudget, double? lifetimeBudget}) async {
    final data = <String, dynamic>{};
    if (dailyBudget != null) data['daily_budget'] = (dailyBudget * 100).toInt(); // Meta uses cents
    if (lifetimeBudget != null) data['lifetime_budget'] = (lifetimeBudget * 100).toInt();

    final res = await _dio.post(
      K.campaign(campaignId),
      queryParameters: {'access_token': accessToken},
      data: data,
    );
    return res.data;
  }

  Future<Map<String, dynamic>> createCampaign({
    required String name,
    required String objective,
    required String status,
    String? bidStrategy,
    double? dailyBudget,
    double? lifetimeBudget,
    Map<String, dynamic>? specialAdCategories,
  }) async {
    final data = <String, dynamic>{
      'name': name,
      'objective': objective,
      'status': status,
      'special_ad_categories': specialAdCategories ?? [],
    };
    if (bidStrategy != null) data['bid_strategy'] = bidStrategy;
    if (dailyBudget != null) data['daily_budget'] = (dailyBudget * 100).toInt();
    if (lifetimeBudget != null) data['lifetime_budget'] = (lifetimeBudget * 100).toInt();

    final res = await _dio.post(
      K.campaigns(adAccountId),
      queryParameters: {'access_token': accessToken},
      data: data,
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // AD SETS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getAdSets({int limit = 50}) async {
    final res = await _dio.get(
      K.adsets(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields': 'name,status,targeting,daily_budget,lifetime_budget,bid_amount,optimization_goal,campaign_id',
        'limit': limit,
      },
    );
    return res.data;
  }

  Future<Map<String, dynamic>> createAdSet({
    required String campaignId,
    required String name,
    required Map<String, dynamic> targeting,
    required String optimizationGoal,
    double? dailyBudget,
    String? billingEvent,
    String? status,
  }) async {
    final data = <String, dynamic>{
      'campaign_id': campaignId,
      'name': name,
      'targeting': targeting,
      'optimization_goal': optimizationGoal,
      'billing_event': billingEvent ?? 'IMPRESSIONS',
      'status': status ?? 'PAUSED',
    };
    if (dailyBudget != null) data['daily_budget'] = (dailyBudget * 100).toInt();

    final res = await _dio.post(
      K.adsets(adAccountId),
      queryParameters: {'access_token': accessToken},
      data: data,
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // AUDIENCES
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getCustomAudiences({int limit = 50}) async {
    final res = await _dio.get(
      K.audiences(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields': 'name,approximate_count,subtype,time_created,time_updated',
        'limit': limit,
      },
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // CONVERSIONS API (SERVER-SIDE EVENTS)
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendConversionEvent({
    required String eventName,
    required Map<String, dynamic> userData,
    Map<String, dynamic>? customData,
    String? eventSourceUrl,
  }) async {
    final event = <String, dynamic>{
      'event_name': eventName,
      'event_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'action_source': 'website',
      'user_data': userData,
    };
    if (customData != null) event['custom_data'] = customData;
    if (eventSourceUrl != null) event['event_source_url'] = eventSourceUrl;

    final res = await _dio.post(
      K.conversionsApi(pixelId),
      queryParameters: {'access_token': accessToken},
      data: {'data': [event]},
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // HELPERS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> getAds({int limit = 50}) async {
    final res = await _dio.get(
      K.ads(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields': 'name,status,creative,adset_id,campaign_id',
        'limit': limit,
      },
    );
    return res.data;
  }

  // Build targeting spec for Meta API
  static Map<String, dynamic> buildTargeting({
    int ageMin = 18,
    int ageMax = 65,
    List<int>? genders, // 1=male, 2=female
    List<Map<String, dynamic>>? geoLocations,
    List<Map<String, dynamic>>? interests,
    List<Map<String, dynamic>>? behaviors,
    List<String>? customAudiences,
    List<String>? excludedAudiences,
  }) {
    final targeting = <String, dynamic>{
      'age_min': ageMin,
      'age_max': ageMax,
    };
    if (genders != null) targeting['genders'] = genders;
    if (geoLocations != null) targeting['geo_locations'] = {'cities': geoLocations};
    if (interests != null) targeting['flexible_spec'] = [{'interests': interests}];
    if (behaviors != null) targeting['flexible_spec'] = [...(targeting['flexible_spec'] ?? []), {'behaviors': behaviors}];
    if (customAudiences != null) targeting['custom_audiences'] = customAudiences.map((id) => {'id': id}).toList();
    if (excludedAudiences != null) targeting['excluded_custom_audiences'] = excludedAudiences.map((id) => {'id': id}).toList();
    return targeting;
  }
}

// ═══════════════════════════════════════════════════════════
// DIO INTERCEPTOR — LOGGING + ERROR HANDLING
// ═══════════════════════════════════════════════════════════
class _MetaInterceptor extends Interceptor {
  final MetaApiService _service;
  _MetaInterceptor(this._service);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add token if missing
    if (!options.queryParameters.containsKey('access_token') && _service.accessToken.isNotEmpty) {
      options.queryParameters['access_token'] = _service.accessToken;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    // Parse Meta API errors
    final data = err.response?.data;
    if (data is Map && data.containsKey('error')) {
      final metaError = data['error'];
      final code = metaError['code'];
      final message = metaError['message'] ?? 'Unknown Meta API error';

      // Handle token expiry
      if (code == 190) {
        // Token expired — trigger refresh flow
      }

      // Handle rate limiting
      if (code == 32 || code == 4) {
        // Rate limited — back off
      }

      handler.next(DioException(
        requestOptions: err.requestOptions,
        response: err.response,
        message: 'Meta API Error ($code): $message',
      ));
      return;
    }
    handler.next(err);
  }
}