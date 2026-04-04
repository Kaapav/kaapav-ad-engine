//lib/services/rule_engine.dart
import '../models/campaign.dart';
import '../models/rule.dart';
import 'notification_service.dart';

class RuleEngine {
  final NotificationService _notifications;

  RuleEngine(this._notifications);

  // ═══ EVALUATE ALL RULES ═══
  List<RuleAction> evaluate(List<AutoRule> rules, List<Campaign> campaigns) {
    final actions = <RuleAction>[];

    for (final rule in rules) {
      if (!rule.enabled) continue;

      for (final campaign in campaigns) {
        if (!campaign.isActive && rule.actionType != 'alert') continue;

        final metricValue = _getMetricValue(rule.metric, campaign);
        if (metricValue == null) continue;

        final triggered = _compare(metricValue, rule.operator, rule.threshold);

        if (triggered) {
          actions.add(RuleAction(
            rule: rule,
            campaign: campaign,
            metricValue: metricValue,
            action: _buildAction(rule, campaign),
          ));
        }
      }
    }

    return actions;
  }

  // ═══ EXECUTE ACTIONS ═══
  Future<List<RuleResult>> executeActions(List<RuleAction> actions) async {
    final results = <RuleResult>[];

    for (final action in actions) {
      try {
        final result = await _executeAction(action);
        results.add(result);

        await _notifications.showAutoPilotAction(
          title: action.rule.name,
          body: result.description,
          ruleId: action.rule.id,
          campaignId: action.campaign.id,
        );
      } catch (e) {
        results.add(RuleResult(
          action: action,
          success: false,
          description: 'Failed: ${e.toString()}',
        ));
      }
    }

    return results;
  }

  // ═══ GET METRIC VALUE ═══
  double? _getMetricValue(String metric, Campaign campaign) {
    return switch (metric) {
      'roas'        => campaign.roas,
      'cpa'         => campaign.cpa,
      'ctr'         => campaign.ctr,
      'cpc'         => campaign.cpc,
      'cpm'         => campaign.cpm,
      'frequency'   => campaign.frequency,
      'spend'       => campaign.spend,
      'budget_util' => campaign.dailyBudget > 0
          ? (campaign.spend / campaign.dailyBudget) * 100
          : null,
      'impressions' => campaign.impressions.toDouble(),
      'clicks'      => campaign.clicks.toDouble(),
      'conversions' => campaign.conversions.toDouble(),
      _             => null,
    };
  }

  // ═══ COMPARE VALUES ═══
  bool _compare(double value, String operator, double threshold) {
    return switch (operator) {
      '<'  => value < threshold,
      '>'  => value > threshold,
      '<=' => value <= threshold,
      '>=' => value >= threshold,
      '==' => value == threshold,
      '!=' => value != threshold,
      _    => false,
    };
  }

  // ═══ BUILD ACTION DESCRIPTION ═══
  ActionDetails _buildAction(AutoRule rule, Campaign campaign) {
    // Parse actionValue String? → double safely
    final pct = double.tryParse(rule.actionValue ?? '') ?? 0.0;

    return switch (rule.actionType) {
      'pause' => ActionDetails(
          type: 'pause',
          description:
              'Pause "${campaign.name}" — ${rule.metric} ${rule.operator} ${rule.threshold}',
          newStatus: 'PAUSED',
        ),
      'scale_budget' => ActionDetails(
          type: 'scale_budget',
          description:
              'Scale "${campaign.name}" budget +${pct.toInt()}%',
          newBudget: campaign.dailyBudget * (1 + pct / 100),
        ),
      'reduce_budget' => ActionDetails(
          type: 'reduce_budget',
          description:
              'Reduce "${campaign.name}" budget -${pct.toInt()}%',
          newBudget: campaign.dailyBudget * (1 - pct / 100),
        ),
      'alert' => ActionDetails(
          type: 'alert',
          description:
              'Alert: "${campaign.name}" ${rule.metric} is ${_getMetricValue(rule.metric, campaign)?.toStringAsFixed(1)}',
        ),
      'alert_and_pause' => ActionDetails(
          type: 'alert_and_pause',
          description:
              'Alert + Pause: "${campaign.name}" — ${rule.metric} exceeded threshold',
          newStatus: 'PAUSED',
        ),
      _ => ActionDetails(
          type: 'unknown',
          description: 'Unknown action',
        ),
    };
  }

  // ═══ EXECUTE SINGLE ACTION ═══
  Future<RuleResult> _executeAction(RuleAction action) async {
    await Future.delayed(const Duration(milliseconds: 200));
    return RuleResult(
      action: action,
      success: true,
      description: action.action.description,
    );
  }
}

// ═══ DATA CLASSES ═══
class RuleAction {
  final AutoRule rule;
  final Campaign campaign;
  final double metricValue;
  final ActionDetails action;

  const RuleAction({
    required this.rule,
    required this.campaign,
    required this.metricValue,
    required this.action,
  });
}

class ActionDetails {
  final String type;
  final String description;
  final String? newStatus;
  final double? newBudget;

  const ActionDetails({
    required this.type,
    required this.description,
    this.newStatus,
    this.newBudget,
  });
}

class RuleResult {
  final RuleAction action;
  final bool success;
  final String description;

  const RuleResult({
    required this.action,
    required this.success,
    required this.description,
  });
}