import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../core/constants.dart';
import '../core/utils.dart';
import '../data/mock_data.dart';
import '../models/campaign.dart';
import '../widgets/glass_card.dart';
import '../widgets/campaign_tile.dart';
import '../widgets/search_filter.dart';
import '../widgets/buttons.dart';
import '../widgets/loading.dart';
import 'campaign_detail_screen.dart';
import 'create_campaign_screen.dart';

class CampaignsScreen extends StatefulWidget {
  const CampaignsScreen({super.key});
  @override
  State<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends State<CampaignsScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  String _search = '';
  String _statusFilter = 'All';
  String _objectiveFilter = 'All';
  String _sortBy = 'roas'; // roas, spend, cpa, name

  final _statusOptions = ['All', 'Active', 'Paused', 'Learning'];
  final _objectiveOptions = ['All', ...K.objectives.values];
  final _sortOptions = {'roas': 'ROAS', 'spend': 'Spend', 'cpa': 'CPA', 'name': 'Name'};

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); super.dispose(); }

  List<Campaign> get _filtered {
    var list = MockData.campaigns.toList();

    // Search
    if (_search.isNotEmpty) {
      list = list.where((c) => c.name.toLowerCase().contains(_search.toLowerCase())).toList();
    }

    // Status filter
    if (_statusFilter != 'All') {
      list = list.where((c) => c.status.toUpperCase() == _statusFilter.toUpperCase()).toList();
    }

    // Objective filter
    if (_objectiveFilter != 'All') {
      list = list.where((c) => K.objectives[c.objective] == _objectiveFilter).toList();
    }

    // Sort
    switch (_sortBy) {
      case 'roas':
        list.sort((a, b) => b.roas.compareTo(a.roas));
      case 'spend':
        list.sort((a, b) => b.spend.compareTo(a.spend));
      case 'cpa':
        list.sort((a, b) => a.cpa.compareTo(b.cpa));
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
    }

    return list;
  }

  int get _filterCount {
    int c = 0;
    if (_statusFilter != 'All') c++;
    if (_objectiveFilter != 'All') c++;
    return c;
  }

  @override
  Widget build(BuildContext context) {
    final campaigns = _filtered;

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          // ANIMATED BG
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.5 - _bgC.value * 0.4, -0.6 + _bgC.value * 0.3),
                  radius: 1.5,
                  colors: [C.blue.withValues(alpha: 0.05), C.primary.withValues(alpha: 0.03), C.bgDeep],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // HEADER
                _header(),
                // SUMMARY BAR
                _summaryBar(campaigns),
                // SEARCH + FILTER
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: GlassSearch(
                    hint: 'Search campaigns...',
                    onChanged: (v) => setState(() => _search = v),
                    onFilter: _showFilterSheet,
                    filterCount: _filterCount,
                  ),
                ),
                // FILTER CHIPS + SORT
                _filterRow(),
                // CAMPAIGNS LIST
                Expanded(
                  child: campaigns.isEmpty
                      ? const EmptyState(
                          icon: Icons.campaign_outlined,
                          title: 'No campaigns found',
                          subtitle: 'Try adjusting your filters',
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                          physics: const BouncingScrollPhysics(),
                          itemCount: campaigns.length,
                          itemBuilder: (_, i) {
                            final c = campaigns[i];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: CampaignTile(
                                name: c.name,
                                status: c.status,
                                platform: c.platform,
                                spend: c.spend,
                                roas: c.roas,
                                cpa: c.cpa,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => CampaignDetailScreen(campaign: c)),
                                ),
                              ),
                            );
                          },
                        ),
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
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Campaigns', style: TextStyle(color: C.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                Text('Manage your Meta ad campaigns', style: TextStyle(color: C.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          OutlineBtn(
            label: 'Create',
            icon: Icons.add_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const CreateCampaignScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryBar(List<Campaign> campaigns) {
    final active = campaigns.where((c) => c.isActive).length;
    final totalSpend = campaigns.fold(0.0, (s, c) => s + c.spend);
    final totalRevenue = campaigns.fold(0.0, (s, c) => s + c.revenue);
    final avgRoas = totalSpend > 0 ? totalRevenue / totalSpend : 0.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 16,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _summaryItem('Active', '$active', C.success),
            Container(width: 1, height: 28, color: C.glassBorder),
            _summaryItem('Spend', U.money(totalSpend), C.blue),
            Container(width: 1, height: 28, color: C.glassBorder),
            _summaryItem('Revenue', U.money(totalRevenue), C.primary),
            Container(width: 1, height: 28, color: C.glassBorder),
            _summaryItem('Avg ROAS', U.roas(avgRoas), avgRoas >= 4 ? C.success : C.warning),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(color: C.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _filterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          // STATUS CHIPS
          Expanded(
            child: SizedBox(
              height: 32,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: _statusOptions.map((s) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: FilterChip2(
                      label: s,
                      selected: _statusFilter == s,
                      onTap: () => setState(() => _statusFilter = s),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
          // SORT
          GestureDetector(
            onTap: _showSortSheet,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: C.glassWhite,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: C.glassBorder),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.sort_rounded, color: C.primary, size: 14),
                  const SizedBox(width: 4),
                  Text(_sortOptions[_sortBy]!, style: const TextStyle(color: C.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSortSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: Glass.blur,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.bgCard, C.bgDeep]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: C.glassBorder),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                const Text('Sort By', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                const SizedBox(height: 16),
                ..._sortOptions.entries.map((e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        _sortBy == e.key ? Icons.radio_button_checked : Icons.radio_button_off,
                        color: _sortBy == e.key ? C.primary : C.textMuted,
                        size: 20,
                      ),
                      title: Text(e.value, style: TextStyle(color: _sortBy == e.key ? C.primary : C.textPrimary, fontSize: 14)),
                      onTap: () {
                        setState(() => _sortBy = e.key);
                        Navigator.pop(context);
                      },
                    )),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterSheet() {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: Glass.blur,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [C.bgCard, C.bgDeep]),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: C.glassBorder),
            ),
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(2)))),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Filters', style: TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() { _statusFilter = 'All'; _objectiveFilter = 'All'; });
                        Navigator.pop(context);
                      },
                      child: const Text('Reset', style: TextStyle(color: C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text('Objective', style: TextStyle(color: C.textSecondary, fontSize: 12, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _objectiveOptions.map((o) => FilterChip2(
                        label: o,
                        selected: _objectiveFilter == o,
                        onTap: () => setState(() { _objectiveFilter = o; Navigator.pop(context); }),
                      )).toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}