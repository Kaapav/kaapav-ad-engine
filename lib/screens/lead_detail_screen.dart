import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../models/lead.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';

class LeadDetailScreen extends StatefulWidget {
  final Lead lead;
  const LeadDetailScreen({super.key, required this.lead});
  @override
  State<LeadDetailScreen> createState() => _LeadDetailScreenState();
}

class _LeadDetailScreenState extends State<LeadDetailScreen> {
  late Lead _lead;

  @override
  void initState() {
    super.initState();
    _lead = widget.lead;
  }

  Color get _stageColor => switch (_lead.stage) {
        'New' => C.info,
        'Contacted' => C.warning,
        'Qualified' => C.purple,
        'Converted' => C.success,
        'Lost' => C.error,
        _ => C.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            _header(),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                child: Column(
                  children: [
                    _profileCard(),
                    const SizedBox(height: 10),
                    _stageSelector(),
                    const SizedBox(height: 10),
                    _quickActions(),
                    const SizedBox(height: 10),
                    _details(),
                    const SizedBox(height: 10),
                    _activityTimeline(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: Glass.card(radius: 12),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: C.textPrimary, size: 16),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(child: Text('Lead Details', style: TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700))),
          GlassIconBtn(icon: Icons.more_vert_rounded, onTap: () {}),
        ],
      ),
    );
  }

  Widget _profileCard() {
    return GlassCard(
      radius: 20,
      turquoise: true,
      glow: true,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: _stageColor.withValues(alpha: 0.15), shape: BoxShape.circle, border: Border.all(color: _stageColor.withValues(alpha: 0.4), width: 2)),
            child: Center(child: Text(_lead.name[0], style: TextStyle(color: _stageColor, fontSize: 26, fontWeight: FontWeight.w700))),
          ),
          const SizedBox(height: 12),
          Text(_lead.name, style: const TextStyle(color: C.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(_lead.phone, style: const TextStyle(color: C.textSecondary, fontSize: 14)),
          if (_lead.email != null) ...[
            const SizedBox(height: 2),
            Text(_lead.email!, style: const TextStyle(color: C.textMuted, fontSize: 12)),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(color: _stageColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20), border: Border.all(color: _stageColor.withValues(alpha: 0.3))),
            child: Text(_lead.stage, style: TextStyle(color: _stageColor, fontSize: 13, fontWeight: FontWeight.w700)),
          ),
          if (_lead.value != null) ...[
            const SizedBox(height: 10),
            Text(U.money(_lead.value!), style: const TextStyle(color: C.primary, fontSize: 22, fontWeight: FontWeight.w700)),
            const Text('Pipeline Value', style: TextStyle(color: C.textMuted, fontSize: 11)),
          ],
        ],
      ),
    );
  }

  Widget _stageSelector() {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Move to Stage', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 10),
          Row(
            children: K.crmStages.map((stage) {
              final sel = _lead.stage == stage;
              final color = switch (stage) {
                'New' => C.info,
                'Contacted' => C.warning,
                'Qualified' => C.purple,
                'Converted' => C.success,
                'Lost' => C.error,
                _ => C.textMuted,
              };
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    setState(() => _lead = _lead.copyWith(stage: stage));
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Moved to $stage'),
                      backgroundColor: C.bgCard,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ));
                  },
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: sel ? color.withValues(alpha: 0.15) : C.glassWhite,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: sel ? color.withValues(alpha: 0.5) : C.glassBorder),
                    ),
                    child: Column(
                      children: [
                        Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                        const SizedBox(height: 4),
                        Text(stage, style: TextStyle(color: sel ? color : C.textMuted, fontSize: 8, fontWeight: sel ? FontWeight.w700 : FontWeight.w400)),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _quickActions() {
    return Row(
      children: [
        Expanded(child: _actionBtn(Icons.phone_rounded, 'Call', C.success, () {})),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn(Icons.message_rounded, 'WhatsApp', C.whatsapp, () {})),
        const SizedBox(width: 8),
        Expanded(child: _actionBtn(Icons.note_add_rounded, 'Note', C.blue, () {})),
      ],
    );
  }

  Widget _actionBtn(IconData icon, String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Container(
              width: 38, height: 38,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _details() {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details', style: TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 12),
          _detailRow(Icons.campaign_rounded, 'Campaign', _lead.campaign),
          _detailRow(Icons.source_rounded, 'Source', _lead.source),
          if (_lead.product != null) _detailRow(Icons.shopping_bag_outlined, 'Product', _lead.product!),
          _detailRow(Icons.calendar_today_rounded, 'Created', U.dateTime(_lead.createdAt)),
          _detailRow(Icons.update_rounded, 'Updated', U.ago(_lead.updatedAt)),
          if (_lead.notes != null) _detailRow(Icons.notes_rounded, 'Notes', _lead.notes!),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, color: C.textMuted, size: 15),
          const SizedBox(width: 10),
          SizedBox(width: 70, child: Text(label, style: const TextStyle(color: C.textMuted, fontSize: 11))),
          Expanded(child: Text(value, style: const TextStyle(color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _activityTimeline() {
    if (_lead.activities.isEmpty) return const SizedBox.shrink();

    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Activity', style: TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ..._lead.activities.asMap().entries.map((e) {
            final a = e.value;
            final isLast = e.key == _lead.activities.length - 1;
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Text(a.icon, style: const TextStyle(fontSize: 16)),
                    if (!isLast)
                      Container(width: 1, height: 30, margin: const EdgeInsets.symmetric(vertical: 4), color: C.glassBorder),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.description, style: const TextStyle(color: C.textPrimary, fontSize: 12)),
                      const SizedBox(height: 2),
                      Text(U.ago(a.timestamp), style: const TextStyle(color: C.textMuted, fontSize: 10)),
                      if (!isLast) const SizedBox(height: 14),
                    ],
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    );
  }
}