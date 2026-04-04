import 'dart:async';
import 'package:flutter/material.dart';
import '../models/campaign.dart';
import '../models/rule.dart';

class AutomationEngine {
  Timer? _timer;
  bool _running = false;

  bool get isRunning => _running;

  void start({
    required List<AutoRule> rules,
    required List<Campaign> campaigns,
    Duration interval = const Duration(minutes: 15),
  }) {
    if (_running) return;
    _running = true;
    debugPrint('🤖 AutomationEngine started');
    _timer = Timer.periodic(interval, (_) {
      _runCycle(rules, campaigns);
    });
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _running = false;
    debugPrint('🤖 AutomationEngine stopped');
  }

  void _runCycle(List<AutoRule> rules, List<Campaign> campaigns) {
    final enabled = rules.where((r) => r.enabled).toList();
    if (enabled.isEmpty) return;

    for (final rule in enabled) {
      for (final campaign in campaigns) {
        final value = _getMetricValue(campaign, rule.metric);
        if (_compare(value, rule.operator, rule.threshold)) {
          debugPrint(
              '🤖 Rule "${rule.name}" triggered for "${campaign.name}" (${rule.metric}=$value)');
        }
      }
    }
  }

  double _getMetricValue(Campaign campaign, String metric) {
    return switch (metric) {
      'roas' => campaign.roas,
      'cpa' => campaign.cpa,
      'ctr' => campaign.ctr,
      'cpc' => campaign.cpc,
      'cpm' => campaign.cpm,
      'frequency' => campaign.frequency,
      'spend' => campaign.spend,
      'budget_util' => campaign.dailyBudget > 0
          ? (campaign.spend / campaign.dailyBudget) * 100
          : 0,
      'impressions' => campaign.impressions.toDouble(),
      'clicks' => campaign.clicks.toDouble(),
      'conversions' => campaign.conversions.toDouble(),
      _ => 0,
    };
  }

  bool _compare(double value, String op, double threshold) {
    return switch (op) {
      '<' => value < threshold,
      '>' => value > threshold,
      '<=' => value <= threshold,
      '>=' => value >= threshold,
      '==' => value == threshold,
      '!=' => value != threshold,
      _ => false,
    };
  }

  void dispose() {
    stop();
  }
}