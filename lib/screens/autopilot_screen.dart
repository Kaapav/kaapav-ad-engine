import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/rule_card.dart';
import '../widgets/buttons.dart';
import '../widgets/loading.dart';

class AutoPilotScreen extends ConsumerStatefulWidget {
  const AutoPilotScreen({super.key});
  @override
  ConsumerState<AutoPilotScreen> createState() => _AutoPilotScreenState();
}

class _AutoPilotScreenState extends ConsumerState<AutoPilotScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  int _viewMode = 0; // 0=Rules, 1=Activity Log

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final rules = ref.watch(rulesProvider);
    final logs = ref.watch(activityLogProvider);
    final activeCount = rules.where((r) => r.enabled).length;
    final totalTriggers = rules.fold(0, (s, r) => s + r.triggeredCount);

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(-0.4 + _bgC.value * 0.5, -0.6 + _bgC.value * 0.3),
                  radius: 1.5,
                  colors: [C.purple.withValues(alpha: 0.06), C.primary.withValues(alpha: 0.03), C.bgDeep],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _header(),
                _statsBar(activeCount, totalTriggers, rules.length),
                _viewToggle(),
                Expanded(
                  child: _viewMode == 0 ? _rulesView(rules) : _activityView(logs),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('AutoPilot', style: TextStyle(color: C.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(8)),
                      child: const Text('AI', style: TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
                    ),
                  ],
                ),
                const Text('Automated campaign optimization rules', style: TextStyle(color: C.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          OutlineBtn(label: 'New Rule', icon: Icons.add_rounded, onTap: () => _showCreateRule()),
        ],
      ),
    );
  }

  Widget _statsBar(int active, int triggers, int total) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 16,
        turquoise: true,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('Active Rules', '$active/$total', C.success, Icons.bolt_rounded),
            Container(width: 1, height: 30, color: C.glassBorder),
            _statItem('Total Triggers', '$triggers', C.purple, Icons.electric_bolt_rounded),
            Container(width: 1, height: 30, color: C.glassBorder),
            _statItem('Saved', '₹12.4K', C.primary, Icons.savings_rounded),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value, Color color, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
        Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _viewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(color: C.bgCard, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.glassBorder)),
            child: Row(
              children: [
                _toggleBtn(0, Icons.rule_rounded, 'Rules'),
                _toggleBtn(1, Icons.history_rounded, 'Activity Log'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleBtn(int index, IconData icon, String label) {
    final sel = _viewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(gradient: sel ? C.primaryGrad : null, borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon, color: sel ? Colors.black : C.textMuted, size: 14),
            const SizedBox(width: 5),
            Text(label, style: TextStyle(color: sel ? Colors.black : C.textMuted, fontSize: 12, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
          ],
        ),
      ),
    );
  }

  // ═══ RULES VIEW ═══
  Widget _rulesView(List<AutoRule> rules) {
    if (rules.isEmpty) {
      return const EmptyState(
        icon: Icons.auto_awesome_rounded,
        title: 'No rules yet',
        subtitle: 'Create your first automation rule to optimize campaigns automatically',
        actionLabel: 'Create Rule',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: rules.length,
      itemBuilder: (_, i) {
        final r = rules[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Dismissible(
            key: Key(r.id),
            direction: DismissDirection.endToStart,
            background: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              decoration: BoxDecoration(
                gradient: C.dangerGrad,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
            ),
            confirmDismiss: (_) => _confirmDelete(r.name),
            onDismissed: (_) => ref.read(rulesProvider.notifier).deleteRule(r.id),
            child: RuleCard(
              name: r.name,
              condition: r.condition,
              action: r.action,
              enabled: r.enabled,
              triggeredCount: r.triggeredCount,
              lastTriggered: r.lastTriggered != null ? U.ago(r.lastTriggered!) : null,
              onToggle: (v) {
                HapticFeedback.mediumImpact();
                ref.read(rulesProvider.notifier).toggle(r.id);
              },
            ),
          ),
        );
      },
    );
  }

  Future<bool> _confirmDelete(String name) async {
    return await showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: Glass.blur,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: Glass.card(radius: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 50, height: 50,
                    decoration: BoxDecoration(color: C.error.withValues(alpha: 0.12), shape: BoxShape.circle),
                    child: const Icon(Icons.delete_outline_rounded, color: C.error, size: 24),
                  ),
                  const SizedBox(height: 14),
                  const Text('Delete Rule?', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text('"$name" will be permanently deleted', style: const TextStyle(color: C.textMuted, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlineBtn(label: 'Cancel', onTap: () => Navigator.pop(context, false))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context, true),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(gradient: C.dangerGrad, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Text('Delete', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ) ?? false;
  }

  // ═══ ACTIVITY LOG VIEW ═══
  Widget _activityView(List<ActivityEntry> logs) {
    if (logs.isEmpty) {
      return const EmptyState(
        icon: Icons.history_rounded,
        title: 'No activity yet',
        subtitle: 'Rule triggers and automated actions will appear here',
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      physics: const BouncingScrollPhysics(),
      itemCount: logs.length,
      itemBuilder: (_, i) {
        final log = logs[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _logCard(log, i == logs.length - 1),
        );
      },
    );
  }

  Widget _logCard(ActivityEntry log, bool isLast) {
    final color = switch (log.type) {
      'rule_triggered' => C.purple,
      'campaign_paused' => C.error,
      'budget_scaled' => C.success,
      'alert' => C.warning,
      _ => C.textMuted,
    };
    final icon = switch (log.type) {
      'rule_triggered' => Icons.bolt_rounded,
      'campaign_paused' => Icons.pause_circle_rounded,
      'budget_scaled' => Icons.trending_up_rounded,
      'alert' => Icons.warning_amber_rounded,
      _ => Icons.info_outline,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle, border: Border.all(color: color.withValues(alpha: 0.3))),
              child: Icon(icon, color: color, size: 16),
            ),
            if (!isLast) Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(vertical: 4), color: C.glassBorder),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassCard(
            radius: 14,
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(log.title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600))),
                    Text(U.ago(log.timestamp), style: const TextStyle(color: C.textMuted, fontSize: 10)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(log.description, style: const TextStyle(color: C.textSecondary, fontSize: 11)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ═══ CREATE RULE SHEET ═══
  void _showCreateRule() {
    String? metric;
    String? operator;
    String? actionType;
    final nameCtrl = TextEditingController();
    final thresholdCtrl = TextEditingController();
    final actionValueCtrl = TextEditingController();

    final metrics = {
      'roas': 'ROAS',
      'cpa': 'CPA (₹)',
      'ctr': 'CTR (%)',
      'frequency': 'Frequency',
      'spend': 'Daily Spend (₹)',
      'budget_util': 'Budget Utilization (%)',
    };
    final operators = {'<': 'Less than', '>': 'Greater than', '<=': 'Less or equal', '>=': 'Greater or equal'};
    final actions = {
      'pause': 'Pause Campaign',
      'scale_budget': 'Increase Budget by %',
      'reduce_budget': 'Reduce Budget by %',
      'alert': 'Send Alert Only',
      'alert_and_pause': 'Alert + Pause Campaign',
    };

    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => StatefulBuilder(
        builder: (context, setModalState) {
          final canCreate = nameCtrl.text.isNotEmpty && metric != null && operator != null && thresholdCtrl.text.isNotEmpty && actionType != null;

          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.5,
            builder: (_, scrollController) => ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: BackdropFilter(
                filter: Glass.blur,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [C.bgCard, C.bgDeep]),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border.all(color: C.glassBorder),
                  ),
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(2)))),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(12)),
                            child: const Icon(Icons.bolt_rounded, color: Colors.black, size: 20),
                          ),
                          const SizedBox(width: 12),
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Create Rule', style: TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                              Text('Set up automated campaign optimization', style: TextStyle(color: C.textMuted, fontSize: 11)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // RULE NAME
                      const Text('Rule Name', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: nameCtrl,
                        onChanged: (_) => setModalState(() {}),
                        style: const TextStyle(color: C.textPrimary, fontSize: 14),
                        cursorColor: C.primary,
                        decoration: InputDecoration(
                          hintText: 'e.g. Kill Low ROAS',
                          hintStyle: const TextStyle(color: C.textMuted),
                          filled: true, fillColor: C.glassWhite,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.glassBorder)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.glassBorder)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: C.primary, width: 2)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // CONDITION: IF metric operator threshold
                      GlassCard(
                        radius: 16,
                        turquoise: true,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.visibility_rounded, color: C.primary.withValues(alpha: 0.6), size: 16),
                                const SizedBox(width: 6),
                                const Text('IF', style: TextStyle(color: C.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            // Metric
                            const Text('Metric', style: TextStyle(color: C.textMuted, fontSize: 11)),
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6, runSpacing: 6,
                              children: metrics.entries.map((e) {
                                final sel = metric == e.key;
                                return GestureDetector(
                                  onTap: () => setModalState(() => metric = e.key),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: sel ? C.primary.withValues(alpha: 0.15) : C.glassWhite,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: sel ? C.primary.withValues(alpha: 0.5) : C.glassBorder),
                                    ),
                                    child: Text(e.value, style: TextStyle(color: sel ? C.primary : C.textPrimary, fontSize: 12, fontWeight: sel ? FontWeight.w600 : FontWeight.w400)),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            // Operator + Threshold
                            Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Condition', style: TextStyle(color: C.textMuted, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 12),
                                        decoration: BoxDecoration(color: C.glassWhite, borderRadius: BorderRadius.circular(10), border: Border.all(color: C.glassBorder)),
                                        child: DropdownButtonHideUnderline(
                                          child: DropdownButton<String>(
                                            value: operator,
                                            hint: const Text('Select', style: TextStyle(color: C.textMuted, fontSize: 13)),
                                            isExpanded: true,
                                            dropdownColor: C.bgCard,
                                            iconEnabledColor: C.primary,
                                            style: const TextStyle(color: C.textPrimary, fontSize: 13, fontFamily: 'Sora'),
                                            items: operators.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                                            onChanged: (v) => setModalState(() => operator = v),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text('Threshold', style: TextStyle(color: C.textMuted, fontSize: 11)),
                                      const SizedBox(height: 6),
                                      TextField(
                                        controller: thresholdCtrl,
                                        onChanged: (_) => setModalState(() {}),
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(color: C.textPrimary, fontSize: 14),
                                        cursorColor: C.primary,
                                        decoration: InputDecoration(
                                          hintText: '2.0',
                                          hintStyle: const TextStyle(color: C.textMuted),
                                          filled: true, fillColor: C.glassWhite,
                                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.glassBorder)),
                                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.glassBorder)),
                                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.primary, width: 2)),
                                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // ACTION: THEN
                      GlassCard(
                        radius: 16,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.play_arrow_rounded, color: C.primary.withValues(alpha: 0.6), size: 16),
                                const SizedBox(width: 6),
                                const Text('THEN', style: TextStyle(color: C.primary, fontSize: 13, fontWeight: FontWeight.w700)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ...actions.entries.map((e) {
                              final sel = actionType == e.key;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 6),
                                child: GestureDetector(
                                  onTap: () => setModalState(() => actionType = e.key),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    decoration: BoxDecoration(
                                      color: sel ? C.primary.withValues(alpha: 0.12) : C.glassWhite,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: sel ? C.primary.withValues(alpha: 0.5) : C.glassBorder),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 16, height: 16,
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            gradient: sel ? C.primaryGrad : null,
                                            border: sel ? null : Border.all(color: C.glassBorder, width: 2),
                                          ),
                                          child: sel ? const Icon(Icons.check_rounded, color: Colors.black, size: 10) : null,
                                        ),
                                        const SizedBox(width: 10),
                                        Text(e.value, style: TextStyle(color: sel ? C.primary : C.textPrimary, fontSize: 13)),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            }),
                            // Action value for scale/reduce
                            if (actionType == 'scale_budget' || actionType == 'reduce_budget') ...[
                              const SizedBox(height: 10),
                              TextField(
                                controller: actionValueCtrl,
                                keyboardType: TextInputType.number,
                                style: const TextStyle(color: C.textPrimary, fontSize: 14),
                                cursorColor: C.primary,
                                decoration: InputDecoration(
                                  hintText: 'Percentage (e.g. 20)',
                                  hintStyle: const TextStyle(color: C.textMuted),
                                  suffixText: '%',
                                  suffixStyle: const TextStyle(color: C.primary, fontWeight: FontWeight.w700),
                                  filled: true, fillColor: C.glassWhite,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.glassBorder)),
                                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.glassBorder)),
                                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: C.primary, width: 2)),
                                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      PrimaryBtn(
                        label: '⚡ Create Rule',
                        icon: Icons.bolt_rounded,
                        onTap: canCreate ? () {
                          final threshold = double.tryParse(thresholdCtrl.text) ?? 0;
                          final actionVal = double.tryParse(actionValueCtrl.text);
                          final conditionStr = '${metrics[metric]} ${operators[operator]} $threshold';
                          final actionStr = actions[actionType] ?? actionType!;

                          ref.read(rulesProvider.notifier).addRule(AutoRule(
                            id: 'r${DateTime.now().millisecondsSinceEpoch}',
                            name: nameCtrl.text,
                            condition: conditionStr,
                            action: actionVal != null ? '$actionStr ($actionVal%)' : actionStr,
                            metric: metric!,
                            operator: operator!,
                            threshold: threshold,
                            actionType: actionType!,
                            actionValue: actionVal,
                            enabled: true,
                          ));

                          Navigator.pop(context);
                          HapticFeedback.heavyImpact();
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Rule "${nameCtrl.text}" created!'),
                            backgroundColor: C.bgCard,
                            behavior: SnackBarBehavior.floating,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ));
                        } : null,
                      ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}