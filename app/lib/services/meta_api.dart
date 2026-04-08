import 'package:dio/dio.dart';

import '../core/constants.dart';
import '../core/env_config.dart';
import '../services/meta_auth.dart';

class MetaApiService {
  late final Dio _workerDio;
  late final Dio _metaDio;

  // Direct Meta fallback (legacy / transitional)
  String accessToken = '';
  String adAccountId = '';
  String pixelId = '';

  MetaApiService() {
    _workerDio = Dio(
      BaseOptions(
        baseUrl: EnvConfig.workerBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    );

    _metaDio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {'Content-Type': 'application/json'},
      ),
    )..interceptors.add(_MetaInterceptor(this));
  }

  /// Legacy configure (direct Meta).
  /// Worker-first rule: if Worker auth exists, Worker will be used anyway.
  void configure({
    required String token,
    required String accountId,
    String? pixel,
  }) {
    accessToken = token;
    adAccountId = accountId;
    if (pixel != null) pixelId = pixel;
  }

  Future<Map<String, String>> _workerHeaders() async {
    final auth = MetaAuth();
    final apiKey = await auth.getApiKey();
    final session = await auth.getSessionToken();

    if (apiKey != null && apiKey.trim().isNotEmpty) {
      return {'X-API-Key': apiKey.trim()};
    }
    if (session != null && session.trim().isNotEmpty) {
      return {'Authorization': 'Bearer ${session.trim()}'};
    }
    return {};
  }

  Future<bool> _hasWorkerAuth() async {
    final h = await _workerHeaders();
    return h.isNotEmpty;
  }

  // ═══════════════════════════════════════════════════════════
  // CAMPAIGNS (Worker-first)
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getCampaigns({
    String datePreset = 'last_30d',
    int limit = 50,
  }) async {
    // Worker-first
    if (await _hasWorkerAuth()) {
      final res = await _workerDio.get(
        '/api/campaigns',
        queryParameters: {
          'date_preset': datePreset,
          'limit': limit,
        },
        options: Options(headers: await _workerHeaders()),
      );
      return (res.data as Map).cast<String, dynamic>();
    }

    // Fallback: direct Meta only if configured
    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Worker not connected and direct Meta not configured.');
    }

    final res = await _metaDio.get(
      K.campaigns(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields':
            'name,objective,status,daily_budget,lifetime_budget,bid_strategy,start_time,stop_time,updated_time',
        'limit': limit,
        'date_preset': datePreset,
      },
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getCampaignInsights(
    String campaignId, {
    String datePreset = 'last_30d',
    String? timeIncrement,
  }) async {
    if (await _hasWorkerAuth()) {
      final res = await _workerDio.get(
        '/api/campaigns/$campaignId/insights',
        queryParameters: {
          'date_preset': datePreset,
          if (timeIncrement != null) 'time_increment': timeIncrement,
        },
        options: Options(headers: await _workerHeaders()),
      );
      return (res.data as Map).cast<String, dynamic>();
    }

    if (accessToken.isEmpty) {
      throw Exception('Worker not connected and direct Meta not configured.');
    }

    final params = <String, dynamic>{
      'access_token': accessToken,
      'fields': K.insightFields.join(','),
      'date_preset': datePreset,
    };
    if (timeIncrement != null) params['time_increment'] = timeIncrement;

    final res =
        await _metaDio.get(K.campaignInsights(campaignId), queryParameters: params);
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getAccountInsights({
    String datePreset = 'last_30d',
    String? timeIncrement,
  }) async {
    if (await _hasWorkerAuth()) {
      // Worker has /api/analytics/summary and /api/analytics/daily
      final path = (timeIncrement == '1') ? '/api/analytics/daily' : '/api/analytics/summary';
      final res = await _workerDio.get(
        path,
        queryParameters: {'date_preset': datePreset},
        options: Options(headers: await _workerHeaders()),
      );
      return (res.data as Map).cast<String, dynamic>();
    }

    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Worker not connected and direct Meta not configured.');
    }

    final params = <String, dynamic>{
      'access_token': accessToken,
      'fields': K.insightFields.join(','),
      'date_preset': datePreset,
    };
    if (timeIncrement != null) params['time_increment'] = timeIncrement;

    final res = await _metaDio.get(K.insights(adAccountId), queryParameters: params);
    return (res.data as Map).cast<String, dynamic>();
  }

  // ═══════════════════════════════════════════════════════════
  // CAMPAIGN ACTIONS (Worker-first)
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> updateCampaignStatus(
    String campaignId,
    String status,
  ) async {
    if (await _hasWorkerAuth()) {
      final res = await _workerDio.patch(
        '/api/campaigns/$campaignId',
        data: {'status': status},
        options: Options(headers: await _workerHeaders()),
      );
      return (res.data as Map).cast<String, dynamic>();
    }

    if (accessToken.isEmpty) {
      throw Exception('Worker not connected and direct Meta not configured.');
    }

    final res = await _metaDio.post(
      K.campaign(campaignId),
      queryParameters: {'access_token': accessToken},
      data: {'status': status},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> updateCampaignBudget(
    String campaignId, {
    double? dailyBudget,
    double? lifetimeBudget,
  }) async {
    if (await _hasWorkerAuth()) {
      final data = <String, dynamic>{};
      if (dailyBudget != null) data['daily_budget'] = dailyBudget;
      if (lifetimeBudget != null) data['lifetime_budget'] = lifetimeBudget;

      final res = await _workerDio.patch(
        '/api/campaigns/$campaignId',
        data: data,
        options: Options(headers: await _workerHeaders()),
      );
      return (res.data as Map).cast<String, dynamic>();
    }

    if (accessToken.isEmpty) {
      throw Exception('Worker not connected and direct Meta not configured.');
    }

    final data = <String, dynamic>{};
    if (dailyBudget != null) data['daily_budget'] = (dailyBudget * 100).toInt();
    if (lifetimeBudget != null) {
      data['lifetime_budget'] = (lifetimeBudget * 100).toInt();
    }

    final res = await _metaDio.post(
      K.campaign(campaignId),
      queryParameters: {'access_token': accessToken},
      data: data,
    );
    return (res.data as Map).cast<String, dynamic>();
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
    if (await _hasWorkerAuth()) {
      final res = await _workerDio.post(
        '/api/campaigns',
        data: {
          'name': name,
          'objective': objective,
          'status': status,
          if (bidStrategy != null) 'bid_strategy': bidStrategy,
          if (dailyBudget != null) 'daily_budget': dailyBudget,
          if (lifetimeBudget != null) 'lifetime_budget': lifetimeBudget,
          if (specialAdCategories != null)
            'special_ad_categories': specialAdCategories,
        },
        options: Options(headers: await _workerHeaders()),
      );
      return (res.data as Map).cast<String, dynamic>();
    }

    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Worker not connected and direct Meta not configured.');
    }

    final data = <String, dynamic>{
      'name': name,
      'objective': objective,
      'status': status,
      'special_ad_categories': specialAdCategories ?? [],
    };
    if (bidStrategy != null) data['bid_strategy'] = bidStrategy;
    if (dailyBudget != null) data['daily_budget'] = (dailyBudget * 100).toInt();
    if (lifetimeBudget != null) {
      data['lifetime_budget'] = (lifetimeBudget * 100).toInt();
    }

    final res = await _metaDio.post(
      K.campaigns(adAccountId),
      queryParameters: {'access_token': accessToken},
      data: data,
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  // ═══════════════════════════════════════════════════════════
  // The below remain direct Meta until Worker routes exist
  // ═══════════════════════════════════════════════════════════

  Future<Map<String, dynamic>> getAdSets({int limit = 50}) async {
    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Direct Meta not configured for ad sets.');
    }
    final res = await _metaDio.get(
      K.adsets(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields':
            'name,status,targeting,daily_budget,lifetime_budget,bid_amount,optimization_goal,campaign_id',
        'limit': limit,
      },
    );
    return (res.data as Map).cast<String, dynamic>();
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
    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Direct Meta not configured for ad set creation.');
    }

    final data = <String, dynamic>{
      'campaign_id': campaignId,
      'name': name,
      'targeting': targeting,
      'optimization_goal': optimizationGoal,
      'billing_event': billingEvent ?? 'IMPRESSIONS',
      'status': status ?? 'PAUSED',
    };
    if (dailyBudget != null) data['daily_budget'] = (dailyBudget * 100).toInt();

    final res = await _metaDio.post(
      K.adsets(adAccountId),
      queryParameters: {'access_token': accessToken},
      data: data,
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getCustomAudiences({int limit = 50}) async {
    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Direct Meta not configured for audiences.');
    }

    final res = await _metaDio.get(
      K.audiences(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields': 'name,approximate_count,subtype,time_created,time_updated',
        'limit': limit,
      },
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> getAds({int limit = 50}) async {
    if (accessToken.isEmpty || adAccountId.isEmpty) {
      throw Exception('Direct Meta not configured for ads.');
    }

    final res = await _metaDio.get(
      K.ads(adAccountId),
      queryParameters: {
        'access_token': accessToken,
        'fields': 'name,status,creative,adset_id,campaign_id',
        'limit': limit,
      },
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  Future<Map<String, dynamic>> sendConversionEvent({
    required String eventName,
    required Map<String, dynamic> userData,
    Map<String, dynamic>? customData,
    String? eventSourceUrl,
  }) async {
    if (accessToken.isEmpty || pixelId.isEmpty) {
      throw Exception('Direct Meta not configured for Conversions API.');
    }

    final event = <String, dynamic>{
      'event_name': eventName,
      'event_time': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'action_source': 'website',
      'user_data': userData,
    };
    if (customData != null) event['custom_data'] = customData;
    if (eventSourceUrl != null) event['event_source_url'] = eventSourceUrl;

    final res = await _metaDio.post(
      K.conversionsApi(pixelId),
      queryParameters: {'access_token': accessToken},
      data: {'data': [event]},
    );
    return (res.data as Map).cast<String, dynamic>();
  }

  static Map<String, dynamic> buildTargeting({
    int ageMin = 18,
    int ageMax = 65,
    List<int>? genders,
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
if (geoLocations != null) {
  targeting['geo_locations'] = {'cities': geoLocations};
}

if (interests != null) {
  targeting['flexible_spec'] = [
    {'interests': interests}
  ];
}
    if (behaviors != null) {
      targeting['flexible_spec'] = [
        ...(targeting['flexible_spec'] ?? []),
        {'behaviors': behaviors}
      ];
    }
    if (customAudiences != null) {
      targeting['custom_audiences'] = customAudiences.map((id) => {'id': id}).toList();
    }
    if (excludedAudiences != null) {
      targeting['excluded_custom_audiences'] =
          excludedAudiences.map((id) => {'id': id}).toList();
    }
    return targeting;
  }
}

class _MetaInterceptor extends Interceptor {
  final MetaApiService _service;
  _MetaInterceptor(this._service);

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (!options.queryParameters.containsKey('access_token') &&
        _service.accessToken.isNotEmpty) {
      options.queryParameters['access_token'] = _service.accessToken;
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final data = err.response?.data;
    if (data is Map && data.containsKey('error')) {
      final metaError = data['error'];
      final code = metaError['code'];
      final message = metaError['message'] ?? 'Unknown Meta API error';

      handler.next(
        DioException(
          requestOptions: err.requestOptions,
          response: err.response,
          message: 'Meta API Error ($code): $message',
        ),
      );
      return;
    }
    handler.next(err);
  }
}