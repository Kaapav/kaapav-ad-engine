// ═══════════════════════════════════════════════════════════════
// INTELLIGENCE PROVIDERS
// All intelligence data from Worker → Flutter
// ═══════════════════════════════════════════════════════════════

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/audience_score.dart';
import '../models/buyer_quality.dart';
import '../models/creative_match.dart';
import '../models/intelligence_summary.dart';
import '../models/optimization_recommendation.dart';
import '../services/worker_api.dart';
import 'app_providers.dart';


// ─────────────────────────────────────────────
// Query classes (typed filters)
// ─────────────────────────────────────────────

class AudienceQuery {
  final String? status;
  final String? campaignId;
  final int limit;

  const AudienceQuery({
    this.status,
    this.campaignId,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) =>
      other is AudienceQuery &&
      other.status == status &&
      other.campaignId == campaignId &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(status, campaignId, limit);
}

class CreativeQuery {
  final String? status;
  final String? campaignId;
  final String? audienceKey;
  final int limit;

  const CreativeQuery({
    this.status,
    this.campaignId,
    this.audienceKey,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) =>
      other is CreativeQuery &&
      other.status == status &&
      other.campaignId == campaignId &&
      other.audienceKey == audienceKey &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(status, campaignId, audienceKey, limit);
}

class BuyerQuery {
  final String? tier;
  final bool?   seedOnly;
  final String? affinity;
  final int limit;

  const BuyerQuery({
    this.tier,
    this.seedOnly,
    this.affinity,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) =>
      other is BuyerQuery &&
      other.tier == tier &&
      other.seedOnly == seedOnly &&
      other.affinity == affinity &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(tier, seedOnly, affinity, limit);
}

class RecommendationQuery {
  final String? status;
  final String? priority;
  final int limit;

  const RecommendationQuery({
    this.status,
    this.priority,
    this.limit = 100,
  });

  @override
  bool operator ==(Object other) =>
      other is RecommendationQuery &&
      other.status == status &&
      other.priority == priority &&
      other.limit == limit;

  @override
  int get hashCode =>
      Object.hash(status, priority, limit);
}

// ─────────────────────────────────────────────
// Intelligence Summary (top-level)
// ─────────────────────────────────────────────

final intelligenceSummaryProvider =
    FutureProvider<IntelligenceSummary>((ref) async {
  final api = ref.watch(workerApiProvider);
  return api.getIntelligenceSummary();
});

// ─────────────────────────────────────────────
// Audience Scores
// ─────────────────────────────────────────────

final audienceScoresProvider =
    FutureProvider.family<List<AudienceScore>, AudienceQuery>(
        (ref, query) async {
  final api = ref.watch(workerApiProvider);
  return api.getAudienceScores(
    status:     query.status,
    campaignId: query.campaignId,
    limit:      query.limit,
  );
});

// ─────────────────────────────────────────────
// Creative Matches
// ─────────────────────────────────────────────

final creativeMatchesProvider =
    FutureProvider.family<List<CreativeMatch>, CreativeQuery>(
        (ref, query) async {
  final api = ref.watch(workerApiProvider);
  return api.getCreativeMatches(
    status:      query.status,
    campaignId:  query.campaignId,
    audienceKey: query.audienceKey,
    limit:       query.limit,
  );
});

// ─────────────────────────────────────────────
// Buyer Quality
// ─────────────────────────────────────────────

final buyerQualityProvider =
    FutureProvider.family<List<BuyerQuality>, BuyerQuery>(
        (ref, query) async {
  final api = ref.watch(workerApiProvider);
  return api.getBuyerQuality(
    tier:     query.tier,
    lookalikeSeedEligible:  query.seedOnly,   
    productAffinity:        query.affinity,
    limit:    query.limit,
  );
});

// ─────────────────────────────────────────────
// Recommendations
// ─────────────────────────────────────────────

final recommendationsProvider = FutureProvider.family<
    List<OptimizationRecommendation>,
    RecommendationQuery>((ref, query) async {
  final api = ref.watch(workerApiProvider);
  return api.getRecommendations(
    status:   query.status,
    priority: query.priority,
    limit:    query.limit,
  );
});

// ─────────────────────────────────────────────
// Refund-Adjusted ROAS
// ─────────────────────────────────────────────

final refundRoasProvider =
    FutureProvider<Map<String, dynamic>>((ref) async {
  final api = ref.watch(workerApiProvider);
  return api.getRefundRoas();
});

// ─────────────────────────────────────────────
// Intelligence Actions (apply / dismiss / recompute)
// ─────────────────────────────────────────────

class IntelligenceActions {
  final WorkerApiService _api;
  final Ref _ref;

  IntelligenceActions(this._api, this._ref);

  Future<void> apply(String id) async {
    await _api.applyRecommendation(id);
    _ref.invalidate(
      recommendationsProvider(const RecommendationQuery(status: 'open')),
    );
    _ref.invalidate(intelligenceSummaryProvider);
  }

  Future<void> dismiss(String id) async {
    await _api.dismissRecommendation(id);
    _ref.invalidate(
      recommendationsProvider(const RecommendationQuery(status: 'open')),
    );
    _ref.invalidate(intelligenceSummaryProvider);
  }

  Future<Map<String, dynamic>> recompute() async {
    final result = await _api.recomputeIntelligence();
    // Invalidate all intelligence data after recompute
    _ref.invalidate(intelligenceSummaryProvider);
    _ref.invalidate(
      audienceScoresProvider(const AudienceQuery()),
    );
    _ref.invalidate(
      creativeMatchesProvider(const CreativeQuery()),
    );
    _ref.invalidate(
      buyerQualityProvider(const BuyerQuery()),
    );
    _ref.invalidate(
      recommendationsProvider(const RecommendationQuery(status: 'open')),
    );
    _ref.invalidate(refundRoasProvider);
    return result;
  }
}

final intelligenceActionsProvider =
    Provider<IntelligenceActions>((ref) {
  final api = ref.watch(workerApiProvider);
  return IntelligenceActions(api, ref);
});