import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kaapav_ad_engine/core/env_config.dart';
import 'package:kaapav_ad_engine/models/audience_score.dart';
import 'package:kaapav_ad_engine/models/buyer_quality.dart';
import 'package:kaapav_ad_engine/models/creative_match.dart';
import 'package:kaapav_ad_engine/models/intelligence_summary.dart';
import 'package:kaapav_ad_engine/models/optimization_recommendation.dart';
import 'package:kaapav_ad_engine/services/meta_auth.dart';

typedef JsonMap = Map<String, dynamic>;

class IntelligenceQuery {
  final String? datePreset;
  final String? status;
  final String? campaignId;
  final String? adsetId;
  final String? audienceKey;

  const IntelligenceQuery({
    this.datePreset,
    this.status,
    this.campaignId,
    this.adsetId,
    this.audienceKey,
  });

  Map<String, dynamic> toParams() {
    final p = <String, dynamic>{};
    if (datePreset != null) p['date_preset'] = datePreset;
    if (status != null) p['status'] = status;
    if (campaignId != null) p['campaign_id'] = campaignId;
    if (adsetId != null) p['adset_id'] = adsetId;
    if (audienceKey != null) p['audience_key'] = audienceKey;
    return p;
  }
}

class BuyerQuery {
  final String? tier;
  final bool? lookalikeSeedEligible;
  final String? productAffinity;

  const BuyerQuery({
    this.tier,
    this.lookalikeSeedEligible,
    this.productAffinity,
  });

  Map<String, dynamic> toParams() {
    final p = <String, dynamic>{};
    if (tier != null) p['tier'] = tier;
    if (lookalikeSeedEligible != null) {
      p['lookalike_seed_eligible'] = lookalikeSeedEligible! ? '1' : '0';
    }
    if (productAffinity != null) p['product_affinity'] = productAffinity;
    return p;
  }
}

class RecommendationQuery {
  final String? status;
  final String? priority;

  const RecommendationQuery({this.status, this.priority});

  Map<String, dynamic> toParams() {
    final p = <String, dynamic>{};
    if (status != null) p['status'] = status;
    if (priority != null) p['priority'] = priority;
    return p;
  }
}

class WorkerIntelligenceApi {
  final Dio _dio;
  final MetaAuth _auth;

  WorkerIntelligenceApi(this._dio, this._auth);

  Future<Map<String, String>> _headers() async {
    final apiKey = await _auth.getApiKey();
    final session = await _auth.getSessionToken();

    final h = <String, String>{'Content-Type': 'application/json'};

    // Rule: prefer API key if present, else session
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      h['X-API-Key'] = apiKey.trim();
      return h;
    }

    if (session != null && session.trim().isNotEmpty) {
      h['Authorization'] = 'Bearer ${session.trim()}';
      return h;
    }

    // Not authenticated
    throw Exception('Not authenticated. Please connect to Worker first.');
  }

  Never _throwUserFacing(String message) {
    throw Exception(message);
  }

  String _extractError(dynamic data) {
    if (data is Map) {
      final err = data['error'];
      if (err != null) return err.toString();
    }
    return 'Request failed';
  }

  Future<JsonMap> _get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final res = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: Options(headers: await _headers()),
      );

      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      _throwUserFacing('Unexpected response from server.');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        _throwUserFacing('Worker endpoint not implemented yet: $path');
      }
      _throwUserFacing(_extractError(e.response?.data));
    } catch (_) {
      _throwUserFacing('Request failed.');
    }
  }

  Future<JsonMap> _post(
    String path, {
    Object? body,
    Map<String, dynamic>? params,
  }) async {
    try {
      final res = await _dio.post(
        path,
        data: body,
        queryParameters: params,
        options: Options(headers: await _headers()),
      );

      final data = res.data;
      if (data is Map<String, dynamic>) return data;
      _throwUserFacing('Unexpected response from server.');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) {
        _throwUserFacing('Worker endpoint not implemented yet: $path');
      }
      _throwUserFacing(_extractError(e.response?.data));
    } catch (_) {
      _throwUserFacing('Request failed.');
    }
  }

  Future<IntelligenceSummary> getSummary() async {
    final json = await _get('/api/intelligence/summary');
    if (json['success'] != true) {
      _throwUserFacing(json['error']?.toString() ?? 'Failed to load summary.');
    }
    final data = (json['data'] as Map).map((k, v) => MapEntry(k.toString(), v));
    return IntelligenceSummary.fromJson(data);
  }

  Future<Map<String, dynamic>> recompute() async {
    final json = await _post('/api/intelligence/recompute');
    if (json['success'] != true) {
      _throwUserFacing(json['error']?.toString() ?? 'Recompute failed.');
    }
    return (json['data'] as Map?)?.map((k, v) => MapEntry(k.toString(), v)) ??
        <String, dynamic>{};
  }

  Future<List<AudienceScore>> getAudiences(IntelligenceQuery q) async {
    final json = await _get(
      '/api/intelligence/audiences',
      queryParameters: q.toParams(),
    );
    if (json['success'] != true) {
      _throwUserFacing(json['error']?.toString() ?? 'Failed to load audiences.');
    }
    final list = (json['data'] as List? ?? const []);
    return list
        .map((e) => AudienceScore.fromJson(
              (e as Map).map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  Future<List<CreativeMatch>> getCreatives(IntelligenceQuery q) async {
    final json = await _get(
      '/api/intelligence/creatives',
      queryParameters: q.toParams(),
    );
    if (json['success'] != true) {
      _throwUserFacing(json['error']?.toString() ?? 'Failed to load creatives.');
    }
    final list = (json['data'] as List? ?? const []);
    return list
        .map((e) => CreativeMatch.fromJson(
              (e as Map).map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  Future<List<BuyerQuality>> getBuyers(BuyerQuery q) async {
    final json = await _get(
      '/api/intelligence/buyers',
      queryParameters: q.toParams(),
    );
    if (json['success'] != true) {
      _throwUserFacing(json['error']?.toString() ?? 'Failed to load buyers.');
    }
    final list = (json['data'] as List? ?? const []);
    return list
        .map((e) => BuyerQuality.fromJson(
              (e as Map).map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  Future<List<OptimizationRecommendation>> getRecommendations(
    RecommendationQuery q,
  ) async {
    final json = await _get(
      '/api/intelligence/recommendations',
      queryParameters: q.toParams(),
    );
    if (json['success'] != true) {
      _throwUserFacing(
        json['error']?.toString() ?? 'Failed to load recommendations.',
      );
    }
    final list = (json['data'] as List? ?? const []);
    return list
        .map((e) => OptimizationRecommendation.fromJson(
              (e as Map).map((k, v) => MapEntry(k.toString(), v)),
            ))
        .toList();
  }

  Future<void> applyRecommendation(String id) async {
    final json = await _post('/api/intelligence/recommendations/$id/apply');
    if (json['success'] != true) {
      _throwUserFacing(
        json['error']?.toString() ?? 'Failed to apply recommendation.',
      );
    }
  }

  Future<void> dismissRecommendation(String id) async {
    final json = await _post('/api/intelligence/recommendations/$id/dismiss');
    if (json['success'] != true) {
      _throwUserFacing(
        json['error']?.toString() ?? 'Failed to dismiss recommendation.',
      );
    }
  }
}

// ─────────────────────────────────────────────
// Providers
// ─────────────────────────────────────────────

final _dioProvider = Provider<Dio>((ref) {
  return Dio(
    BaseOptions(
      baseUrl: EnvConfig.workerBaseUrl,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );
});

final intelligenceApiProvider = Provider<WorkerIntelligenceApi>((ref) {
  final dio = ref.watch(_dioProvider);
  return WorkerIntelligenceApi(dio, MetaAuth());
});

final intelligenceSummaryProvider = FutureProvider<IntelligenceSummary>((ref) {
  return ref.watch(intelligenceApiProvider).getSummary();
});

final audienceScoresProvider =
    FutureProvider.family<List<AudienceScore>, IntelligenceQuery>((ref, q) {
  return ref.watch(intelligenceApiProvider).getAudiences(q);
});

final creativeMatchesProvider =
    FutureProvider.family<List<CreativeMatch>, IntelligenceQuery>((ref, q) {
  return ref.watch(intelligenceApiProvider).getCreatives(q);
});

final buyerQualityProvider =
    FutureProvider.family<List<BuyerQuality>, BuyerQuery>((ref, q) {
  return ref.watch(intelligenceApiProvider).getBuyers(q);
});

final recommendationsProvider = FutureProvider.family<
    List<OptimizationRecommendation>, RecommendationQuery>((ref, q) {
  return ref.watch(intelligenceApiProvider).getRecommendations(q);
});

final intelligenceActionsProvider = Provider<_IntelligenceActions>((ref) {
  final api = ref.watch(intelligenceApiProvider);
  return _IntelligenceActions(api, ref);
});

class _IntelligenceActions {
  final WorkerIntelligenceApi _api;
  final Ref _ref;

  _IntelligenceActions(this._api, this._ref);

  Future<void> recompute() async {
    await _api.recompute();
    _ref.invalidate(intelligenceSummaryProvider);
  }

  Future<void> apply(String id) async {
    await _api.applyRecommendation(id);
    _ref.invalidate(recommendationsProvider);
    _ref.invalidate(intelligenceSummaryProvider);
  }

  Future<void> dismiss(String id) async {
    await _api.dismissRecommendation(id);
    _ref.invalidate(recommendationsProvider);
    _ref.invalidate(intelligenceSummaryProvider);
  }
}