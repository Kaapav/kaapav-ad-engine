import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/lead.dart';
import '../providers/app_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';
import '../widgets/lead_tile.dart';
import '../widgets/search_filter.dart';
import '../widgets/empty_state.dart';
import '../widgets/inputs.dart';
import 'lead_detail_screen.dart';

class CrmScreen extends ConsumerStatefulWidget {
  const CrmScreen({super.key});

  @override
  ConsumerState<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends ConsumerState<CrmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  String _search = '';
  String _stageFilter = 'All';
  int _viewMode = 0; // 0=Pipeline, 1=List

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
  }

  List<Lead> _applyFilters(List<Lead> source) {
    var list = source.toList();

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase().trim();
      list = list.where((l) {
        final campaign = l.campaign.toLowerCase();
        final phone = l.phone;
        final name = l.name.toLowerCase();
        return name.contains(q) || phone.contains(_search) || campaign.contains(q);
      }).toList();
    }

    if (_stageFilter != 'All') {
      list = list.where((l) => l.stage == _stageFilter).toList();
    }

    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Map<String, int> _pipelineCounts(List<Lead> leads) {
    final map = <String, int>{};
    for (final stage in K.crmStages) {
      map[stage] = 0;
    }
    for (final lead in leads) {
      map[lead.stage] = (map[lead.stage] ?? 0) + 1;
    }
    return map;
  }

  double _pipelineValue(List<Lead> leads) {
    return leads.fold<double>(0, (sum, l) => sum + (l.value ?? 0));
  }

  Color _stageColor(String stage) => switch (stage) {
        'New' => C.info,
        'Contacted' => C.warning,
        'Qualified' => C.purple,
        'Converted' => C.success,
        'Lost' => C.error,
        _ => C.textMuted,
      };

  bool _isCancelledMessage(String message) {
    final m = message.toLowerCase();
    return m.contains('request cancelled') ||
        m.contains('request canceled') ||
        m.contains('cancelled') ||
        m.contains('canceled');
  }

  Future<void> _refresh() async {
    await ref.read(leadsProvider.notifier).refresh();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ CRM refreshed'),
        backgroundColor: C.success,
        duration: Duration(seconds: 1),
      ),
    );
  }

  Future<void> _showAddLeadSheet() async {
    HapticFeedback.mediumImpact();

    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final campaignCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    String stage = 'New';

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: Glass.blur,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [C.bgCard, C.bgDeep]),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: C.glassBorder),
              ),
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                20 + MediaQuery.of(ctx).viewInsets.bottom,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: C.glassBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Add Lead',
                      style: TextStyle(
                        color: C.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Creates lead in Worker (D1) and enters CRM pipeline',
                      style: TextStyle(color: C.textSecondary, fontSize: 12),
                    ),
                    const SizedBox(height: 16),

                    GlassInput(
                      label: 'Name',
                      hint: 'Customer name',
                      controller: nameCtrl,
                      prefixIcon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 12),
                    GlassInput(
                      label: 'Phone',
                      hint: '+91XXXXXXXXXX',
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      prefixIcon: Icons.call_rounded,
                    ),
                    const SizedBox(height: 12),
                    GlassInput(
                      label: 'Campaign (optional)',
                      hint: 'Campaign name',
                      controller: campaignCtrl,
                      prefixIcon: Icons.campaign_rounded,
                    ),
                    const SizedBox(height: 12),
                    GlassInput(
                      label: 'Notes (optional)',
                      hint: 'Any context',
                      controller: notesCtrl,
                      prefixIcon: Icons.notes_rounded,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 14),

                    const Text(
                      'Stage',
                      style: TextStyle(color: C.textMuted, fontSize: 11),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: K.crmStages.map((s) {
                        final sel = stage == s;
                        
                        return FilterChip2(
                          label: s,
                          selected: sel,
                          onTap: () => setSheetState(() => stage = s),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 18),
                    PrimaryBtn(
                      label: 'Create Lead',
                      icon: Icons.check_rounded,
                      onTap: () async {
                        final name = nameCtrl.text.trim();
                        final phone = phoneCtrl.text.trim();

                        if (name.isEmpty || phone.isEmpty) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Name and phone are required'),
                              backgroundColor: C.error,
                            ),
                          );
                          return;
                        }

                        try {
                          final api = ref.read(workerApiProvider);

                          await api.createLead(
                            name: name,
                            phone: phone,
                            email: null,
                            campaign: campaignCtrl.text.trim().isEmpty
                                ? null
                                : campaignCtrl.text.trim(),
                            campaignId: null,
                            stage: stage,
                            source: 'Manual',
                            product: null,
                            value: 0,
                            notes: notesCtrl.text.trim().isEmpty
                                ? null
                                : notesCtrl.text.trim(),
                          );

                          if (!ctx.mounted) return;
                          Navigator.pop(ctx);

                          ref.invalidate(leadsProvider);

                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('✅ Lead created'),
                              backgroundColor: C.success,
                            ),
                          );
                        } catch (_) {
                          if (!ctx.mounted) return;
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: Text('Failed to create lead'),
                              backgroundColor: C.error,
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final leadsAsync = ref.watch(leadsProvider);

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    0.4 - _bgC.value * 0.5,
                    -0.7 + _bgC.value * 0.2,
                  ),
                  radius: 1.5,
                  colors: [
                    C.purple.withValues(alpha: 0.05),
                    C.primary.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: leadsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: C.primary),
              ),
              error: (error, _) {
                final message = error.toString();
                if (_isCancelledMessage(message)) {
                  return const Center(
                    child: CircularProgressIndicator(color: C.primary),
                  );
                }
                return _errorState(message);
              },
              data: (allLeads) {
                final leads = _applyFilters(allLeads);
                final pipeline = _pipelineCounts(allLeads);
                final pipelineValue = _pipelineValue(allLeads);

                return Column(
                  children: [
                    _header(allLeads.length, pipelineValue),
                    _pipelineSummary(pipeline),
                    _viewToggle(leads.length),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                      child: GlassSearch(
                        hint: 'Search leads...',
                        onChanged: (v) => setState(() => _search = v),
                      ),
                    ),
                    _stageChips(),
                    Expanded(
                      child: leads.isEmpty
                          ? const EmptyState(
                              icon: Icons.people_outline,
                              title: 'No leads found',
                              subtitle: 'Try adjusting your filters',
                            )
                          : _viewMode == 0
                              ? _pipelineView(leads)
                              : _listView(leads),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(int totalLeads, double pipelineValue) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'CRM',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  '$totalLeads leads • ${U.money(pipelineValue)} pipeline',
                  style: const TextStyle(color: C.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          OutlineBtn(
            label: 'Add Lead',
            icon: Icons.person_add_rounded,
            onTap: _showAddLeadSheet,
          ),
        ],
      ),
    );
  }

  Widget _pipelineSummary(Map<String, int> pipeline) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: K.crmStages.map((stage) {
            final count = pipeline[stage] ?? 0;
            final color = _stageColor(stage);
            return Expanded(
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '$count',
                        style: TextStyle(
                          color: color,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    stage,
                    style: const TextStyle(
                      color: C.textMuted,
                      fontSize: 9,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _viewToggle(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
              color: C.bgCard,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: C.glassBorder),
            ),
            child: Row(
              children: [
                _toggleBtn(0, Icons.view_column_rounded, 'Pipeline'),
                _toggleBtn(1, Icons.list_rounded, 'List'),
              ],
            ),
          ),
          const Spacer(),
          Text(
            '$count leads',
            style: const TextStyle(color: C.textMuted, fontSize: 11),
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          gradient: sel ? C.primaryGrad : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(icon, color: sel ? Colors.black : C.textMuted, size: 14),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: sel ? Colors.black : C.textMuted,
                fontSize: 11,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stageChips() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 32,
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: ['All', ...K.crmStages].map((s) {
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip2(
                label: s,
                selected: _stageFilter == s,
                onTap: () => setState(() => _stageFilter = s),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _pipelineView(List<Lead> filteredLeads) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: K.crmStages.map((stage) {
          final stageLeads = filteredLeads.where((l) => l.stage == stage).toList();
          final color = _stageColor(stage);

          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GlassCard(
                  radius: 12,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        stage,
                        style: TextStyle(
                          color: color,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${stageLeads.length}',
                          style: TextStyle(
                            color: color,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                ...stageLeads.map((l) => Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: _pipelineCard(l, color),
                    )),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _pipelineCard(Lead lead, Color color) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: lead)),
      ),
      child: GlassCard(
        radius: 14,
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Center(
                    child: Text(
                      lead.name.isNotEmpty ? lead.name[0] : '?',
                      style: TextStyle(
                        color: color,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lead.name,
                        style: const TextStyle(
                          color: C.textPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        lead.phone,
                        style: const TextStyle(color: C.textMuted, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.campaign_rounded, color: C.textMuted, size: 11),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    lead.campaign,
                    style: const TextStyle(color: C.textMuted, fontSize: 10),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (lead.product != null && lead.product!.isNotEmpty) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined, color: C.textMuted, size: 11),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      lead.product!,
                      style: const TextStyle(color: C.textSecondary, fontSize: 10),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (lead.value != null)
                  Text(
                    U.money(lead.value!),
                    style: TextStyle(
                      color: color,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  )
                else
                  const SizedBox.shrink(),
                Text(
                  U.ago(lead.updatedAt),
                  style: const TextStyle(color: C.textMuted, fontSize: 10),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _listView(List<Lead> leads) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: C.primary,
      backgroundColor: C.bgCard,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: leads.length,
        itemBuilder: (_, i) {
          final l = leads[i];
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: LeadTile(
              name: l.name,
              phone: l.phone,
              campaign: l.campaign,
              stage: l.stage,
              date: l.updatedAt,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => LeadDetailScreen(lead: l)),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _errorState(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: GlassCard(
          radius: 18,
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.people_alt_outlined, color: C.error, size: 28),
              const SizedBox(height: 12),
              const Text(
                'Unable to load CRM data',
                style: TextStyle(
                  color: C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: C.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 14),
              OutlineBtn(
                label: 'Retry',
                icon: Icons.refresh_rounded,
                onTap: () => ref.read(leadsProvider.notifier).load(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}