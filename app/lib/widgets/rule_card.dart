import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'glass_card.dart';

class RuleCard extends StatefulWidget {
  final String name;
  final String condition;
  final String action;
  final bool enabled;
  final int triggeredCount;
  final String? lastTriggered;
  final String? metric;
  final String? actionType;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const RuleCard({
    super.key,
    required this.name,
    required this.condition,
    required this.action,
    required this.enabled,
    this.triggeredCount = 0,
    this.lastTriggered,
    this.metric,
    this.actionType,
    this.onToggle,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<RuleCard> createState() => _RuleCardState();
}

class _RuleCardState extends State<RuleCard> {
  bool _expanded = false;

  Color get _actionColor => switch (widget.actionType) {
        'pause'           => C.error,
        'scale_budget'    => C.success,
        'reduce_budget'   => C.warning,
        'alert'           => C.info,
        'alert_and_pause' => C.warning,
        _                 => C.primary,
      };

  IconData get _actionIcon => switch (widget.actionType) {
        'pause'           => Icons.pause_circle_rounded,
        'scale_budget'    => Icons.trending_up_rounded,
        'reduce_budget'   => Icons.trending_down_rounded,
        'alert'           => Icons.notifications_rounded,
        'alert_and_pause' => Icons.warning_rounded,
        _                 => Icons.bolt_rounded,
      };

  IconData get _metricIcon => switch (widget.metric) {
        'roas'        => Icons.auto_graph_rounded,
        'cpa'         => Icons.ads_click_rounded,
        'ctr'         => Icons.touch_app_rounded,
        'cpc'         => Icons.monetization_on_rounded,
        'cpm'         => Icons.bar_chart_rounded,
        'frequency'   => Icons.repeat_rounded,
        'spend'       => Icons.currency_rupee_rounded,
        'budget_util' => Icons.pie_chart_rounded,
        _             => Icons.analytics_rounded,
      };

  void _showDeleteConfirm() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: Glass.card(radius: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  color: C.error.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.delete_rounded, color: C.error, size: 26),
              ),
              const SizedBox(height: 14),
              const Text('Delete Rule?', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text(
                '"${widget.name}" will be permanently deleted.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: C.glassWhite,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.glassBorder),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Cancel', style: TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDelete?.call();
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: C.error.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: C.error.withValues(alpha: 0.4)),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Delete', style: TextStyle(color: C.error, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      radius: 18,
      turquoise: widget.enabled,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ──
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (widget.enabled ? _actionColor : C.textMuted).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(_actionIcon, color: widget.enabled ? _actionColor : C.textMuted, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.name,
                  style: const TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              // Edit button
              GestureDetector(
                onTap: () { HapticFeedback.lightImpact(); widget.onEdit?.call(); },
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: C.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.primary.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.edit_rounded, color: C.primary, size: 15),
                ),
              ),
              const SizedBox(width: 6),
              // Delete button
              GestureDetector(
                onTap: _showDeleteConfirm,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: C.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: C.error.withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.delete_rounded, color: C.error, size: 15),
                ),
              ),
              const SizedBox(width: 6),
              // Toggle
              Switch(
                value: widget.enabled,
                onChanged: widget.onToggle,
                activeTrackColor: C.primary,
              ),
            ],
          ),
          const SizedBox(height: 12),

          // ── Condition + Action ──
          _row(_metricIcon, 'IF', widget.condition),
          const SizedBox(height: 6),
          _row(_actionIcon, 'THEN', widget.action, color: _actionColor),

          // ── Stats row ──
          if (widget.triggeredCount > 0 || widget.lastTriggered != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                if (widget.triggeredCount > 0) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: C.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${widget.triggeredCount}x triggered',
                      style: const TextStyle(color: C.purple, fontSize: 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
                const Spacer(),
                if (widget.lastTriggered != null)
                  Text('Last: ${widget.lastTriggered}', style: const TextStyle(color: C.textMuted, fontSize: 10)),
              ],
            ),
          ],

          // ── Expand toggle ──
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () { HapticFeedback.selectionClick(); setState(() => _expanded = !_expanded); },
            child: Row(
              children: [
                Text(
                  _expanded ? 'Hide details' : 'Show details',
                  style: const TextStyle(color: C.textMuted, fontSize: 10),
                ),
                const SizedBox(width: 4),
                Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: C.textMuted, size: 14),
              ],
            ),
          ),

          // ── Expanded details ──
          if (_expanded) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.glassWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.glassBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _detailRow('Metric', widget.metric?.toUpperCase() ?? '—'),
                  _detailRow('Action Type', widget.actionType?.replaceAll('_', ' ').toUpperCase() ?? '—'),
                  _detailRow('Status', widget.enabled ? '🟢 Active' : '⚪ Disabled'),
                  _detailRow('Total Triggers', '${widget.triggeredCount}'),
                  if (widget.lastTriggered != null)
                    _detailRow('Last Triggered', widget.lastTriggered!),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(IconData icon, String label, String text, {Color? color}) {
    final c = color ?? C.primary;
    return Row(
      children: [
        Icon(icon, color: c.withValues(alpha: 0.6), size: 14),
        const SizedBox(width: 6),
        Text('$label: ', style: TextStyle(color: c.withValues(alpha: 0.8), fontSize: 11, fontWeight: FontWeight.w600)),
        Expanded(child: Text(text, style: const TextStyle(color: C.textSecondary, fontSize: 11))),
      ],
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10))),
          Expanded(child: Text(value, style: const TextStyle(color: C.textPrimary, fontSize: 10, fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}