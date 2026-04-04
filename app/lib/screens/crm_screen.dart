import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../data/mock_data.dart';
import '../models/lead.dart';
import '../widgets/glass_card.dart';
import '../widgets/lead_tile.dart';
import '../widgets/search_filter.dart';
import '../widgets/buttons.dart';
import '../widgets/loading.dart';
import 'lead_detail_screen.dart';

class CrmScreen extends StatefulWidget {
  const CrmScreen({super.key});
  @override
  State<CrmScreen> createState() => _CrmScreenState();
}

class _CrmScreenState extends State<CrmScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  String _search = '';
  String _stageFilter = 'All';
  int _viewMode = 0; // 0=Pipeline, 1=List

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
  }

  List<Lead> get _filtered {
    var list = MockData.leads.toList();
    if (_search.isNotEmpty) {
      list = list
          .where((l) =>
              l.name.toLowerCase().contains(_search.toLowerCase()) ||
              l.phone.contains(_search) ||
              l.campaign
                  .toLowerCase()
                  .contains(_search.toLowerCase()))
          .toList();
    }
    if (_stageFilter != 'All') {
      list = list.where((l) => l.stage == _stageFilter).toList();
    }
    list.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list;
  }

  Color _stageColor(String stage) => switch (stage) {
        'New' => C.info,
        'Contacted' => C.warning,
        'Qualified' => C.purple,
        'Converted' => C.success,
        'Lost' => C.error,
        _ => C.textMuted,
      };

  @override
  Widget build(BuildContext context) {
    final leads = _filtered;
    final pipeline = MockData.pipelineCounts;

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
                      -0.7 + _bgC.value * 0.2),
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
            child: Column(
              children: [
                _header(),
                _pipelineSummary(pipeline),
                _viewToggle(),
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
                          subtitle: 'Try adjusting your filters')
                      : _viewMode == 0
                          ? _pipelineView()
                          : _listView(leads),
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
                const Text('CRM',
                    style: TextStyle(
                        color: C.textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.w700)),
                Text(
                    '${MockData.leads.length} leads • ${U.money(MockData.pipelineValue)} pipeline',
                    style: const TextStyle(
                        color: C.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          OutlineBtn(
              label: 'Add Lead',
              icon: Icons.person_add_rounded,
              onTap: () {}),
        ],
      ),
    );
  }

  Widget _pipelineSummary(Map<String, int> pipeline) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 16,
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
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
                        shape: BoxShape.circle),
                    child: Center(
                        child: Text('$count',
                            style: TextStyle(
                                color: color,
                                fontSize: 14,
                                fontWeight: FontWeight.w700))),
                  ),
                  const SizedBox(height: 4),
                  Text(stage,
                      style: const TextStyle(
                          color: C.textMuted,
                          fontSize: 9,
                          fontWeight: FontWeight.w500)),
                ],
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _viewToggle() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Container(
            decoration: BoxDecoration(
                color: C.bgCard,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: C.glassBorder)),
            child: Row(
              children: [
                _toggleBtn(0, Icons.view_column_rounded, 'Pipeline'),
                _toggleBtn(1, Icons.list_rounded, 'List'),
              ],
            ),
          ),
          const Spacer(),
          Text('${_filtered.length} leads',
              style: const TextStyle(
                  color: C.textMuted, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _toggleBtn(int index, IconData icon, String label) {
    final sel = _viewMode == index;
    return GestureDetector(
      onTap: () => setState(() => _viewMode = index),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
            gradient: sel ? C.primaryGrad : null,
            borderRadius: BorderRadius.circular(8)),
        child: Row(
          children: [
            Icon(icon,
                color: sel ? Colors.black : C.textMuted, size: 14),
            const SizedBox(width: 4),
            Text(label,
                style: TextStyle(
                    color: sel ? Colors.black : C.textMuted,
                    fontSize: 11,
                    fontWeight:
                        sel ? FontWeight.w700 : FontWeight.w400)),
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
                  onTap: () =>
                      setState(() => _stageFilter = s)),
            );
          }).toList(),
        ),
      ),
    );
  }

  // ═══ PIPELINE VIEW ═══
  Widget _pipelineView() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: K.crmStages.map((stage) {
          final stageLeads = MockData.leads
              .where((l) => l.stage == stage)
              .toList();
          final color = _stageColor(stage);
          return Container(
            width: 260,
            margin: const EdgeInsets.only(right: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // COLUMN HEADER
                GlassCard(
                  radius: 12,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  child: Row(
                    children: [
                      Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle)),
                      const SizedBox(width: 8),
                      Text(stage,
                          style: TextStyle(
                              color: color,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color:
                                color.withValues(alpha: 0.12),
                            borderRadius:
                                BorderRadius.circular(8)),
                        child: Text('${stageLeads.length}',
                            style: TextStyle(
                                color: color,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                // LEADS IN COLUMN
                Expanded(
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    children: stageLeads.map((l) {
                      return Padding(
                        padding:
                            const EdgeInsets.only(bottom: 6),
                        child: _pipelineCard(l, color),
                      );
                    }).toList(),
                  ),
                ),
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
          MaterialPageRoute(
              builder: (_) => LeadDetailScreen(lead: lead))),
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
                      borderRadius: BorderRadius.circular(9)),
                  child: Center(
                      child: Text(lead.name[0],
                          style: TextStyle(
                              color: color,
                              fontSize: 14,
                              fontWeight: FontWeight.w700))),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(lead.name,
                          style: const TextStyle(
                              color: C.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      Text(lead.phone,
                          style: const TextStyle(
                              color: C.textMuted,
                              fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.campaign_rounded,
                    color: C.textMuted, size: 11),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(lead.campaign,
                        style: const TextStyle(
                            color: C.textMuted, fontSize: 10),
                        overflow: TextOverflow.ellipsis)),
              ],
            ),
            if (lead.product != null) ...[
              const SizedBox(height: 3),
              Row(
                children: [
                  const Icon(Icons.shopping_bag_outlined,
                      color: C.textMuted, size: 11),
                  const SizedBox(width: 4),
                  Text(lead.product!,
                      style: const TextStyle(
                          color: C.textSecondary,
                          fontSize: 10)),
                ],
              ),
            ],
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment:
                  MainAxisAlignment.spaceBetween,
              children: [
                if (lead.value != null)
                  Text(U.money(lead.value!),
                      style: TextStyle(
                          color: color,
                          fontSize: 12,
                          fontWeight: FontWeight.w700)),
                Text(U.ago(lead.updatedAt),
                    style: const TextStyle(
                        color: C.textMuted, fontSize: 10)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ═══ LIST VIEW ═══
  Widget _listView(List<Lead> leads) {
    return RefreshIndicator(
      onRefresh: () async {
        await Future.delayed(const Duration(seconds: 2));
        if (mounted) setState(() {});
      },
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
                  MaterialPageRoute(
                      builder: (_) =>
                          LeadDetailScreen(lead: l))),
            ),
          );
        },
      ),
    );
  }
}