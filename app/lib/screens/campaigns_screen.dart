import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../models/campaign.dart';
import '../providers/app_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/campaign_tile.dart';
import '../widgets/glass_card.dart';
import '../widgets/search_filter.dart';
import '../widgets/empty_state.dart';

class CampaignsScreen extends ConsumerStatefulWidget {
  const CampaignsScreen({super.key});

  @override
  ConsumerState<CampaignsScreen> createState() => _CampaignsScreenState();
}

class _CampaignsScreenState extends ConsumerState<CampaignsScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  String _search = '';
  String _statusFilter = 'All';
  String _objectiveFilter = 'All';
  String _sortBy = 'roas';

  final _statusOptions = ['All', 'Active', 'Paused', 'Learning'];
  final _objectiveOptions = ['All', ...K.objectives.values];
  final _sortOptions = <String, String>{
    'roas': 'ROAS',
    'spend': 'Spend',
    'cpa': 'CPA',
    'name': 'Name',
  };

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

  bool _statusMatch(Campaign c) {
    switch (_statusFilter) {
      case 'Active':
        return c.isActive;
      case 'Paused':
        return c.isPaused;
      case 'Learning':
        return c.isLearning ||
            c.status.toLowerCase().contains('learning') ||
            c.status.toLowerCase().contains('in_process');
      default:
        return true;
    }
  }

  List<Campaign> _applyFilters(List<Campaign> source) {
    var list = source.toList();

    if (_search.isNotEmpty) {
      final q = _search.toLowerCase().trim();
      list = list.where((c) => c.name.toLowerCase().contains(q)).toList();
    }

    if (_statusFilter != 'All') {
      list = list.where(_statusMatch).toList();
    }

    if (_objectiveFilter != 'All') {
      list = list.where((c) => K.objectives[c.objective] == _objectiveFilter).toList();
    }

    switch (_sortBy) {
      case 'roas':
        list.sort((a, b) => b.roas.compareTo(a.roas));
        break;
      case 'spend':
        list.sort((a, b) => b.spend.compareTo(a.spend));
        break;
      case 'cpa':
        list.sort((a, b) => a.cpa.compareTo(b.cpa));
        break;
      case 'name':
        list.sort((a, b) => a.name.compareTo(b.name));
        break;
    }

    return list;
  }

  int get _filterCount {
    int c = 0;
    if (_statusFilter != 'All') c++;
    if (_objectiveFilter != 'All') c++;
    return c;
  }

  Future<void> _refresh() async {
    await ref.read(campaignsProvider.notifier).refresh();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Campaigns refreshed'),
        backgroundColor: C.success,
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final campaignsAsync = ref.watch(campaignsProvider);

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
                    0.5 - _bgC.value * 0.4,
                    -0.6 + _bgC.value * 0.3,
                  ),
                  radius: 1.5,
                  colors: [
                    C.blue.withValues(alpha: 0.05),
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
                campaignsAsync.when(
                  loading: () => const Expanded(
                    child: Center(
                      child: CircularProgressIndicator(color: C.primary),
                    ),
                  ),
                  error: (error, _) => Expanded(child: _errorState(error.toString())),
                  data: (allCampaigns) {
                    final campaigns = _applyFilters(allCampaigns);

                    return Expanded(
                      child: Column(
                        children: [
                          _summaryBar(campaigns),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                            child: GlassSearch(
                              hint: 'Search campaigns...',
                              onChanged: (v) => setState(() => _search = v),
                              onFilter: _showFilterSheet,
                              filterCount: _filterCount,
                            ),
                          ),
                          _filterRow(),
                          Expanded(
                            child: campaigns.isEmpty
                                ? const EmptyState(
                                    icon: Icons.campaign_outlined,
                                    title: 'No campaigns found',
                                    subtitle: 'Try adjusting your filters',
                                  )
                                : RefreshIndicator(
                                    onRefresh: _refresh,
                                    color: C.primary,
                                    backgroundColor: C.bgCard,
                                    child: ListView.builder(
                                      padding: const EdgeInsets.fromLTRB(16, 6, 16, 100),
                                      physics: const AlwaysScrollableScrollPhysics(),
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
                                            onTap: () => context.push(
                                              '/campaign-detail',
                                              extra: c,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
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
              Text(
                'Campaigns',
                style: TextStyle(
                  color: C.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
              ),
              Text(
                'Worker-synced Meta campaigns',
                style: TextStyle(
                  color: C.textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        OutlineBtn(
          label: 'Create',
          icon: Icons.add_rounded,
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/campaigns/create');
          },
        ),
      ],
    ),
  );
}

  Widget _summaryBar(List<Campaign> campaigns) {
    final active = campaigns.where((c) => c.isActive).length;
    final totalSpend = campaigns.fold<double>(0, (s, c) => s + c.spend);
    final totalRevenue = campaigns.fold<double>(0, (s, c) => s + c.revenue);
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
            _summaryItem(
              'Avg ROAS',
              U.roas(avgRoas),
              avgRoas >= 4 ? C.success : C.warning,
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color: C.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _filterRow() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
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
                  Text(
                    _sortOptions[_sortBy]!,
                    style: const TextStyle(
                      color: C.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                  'Sort By',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                ..._sortOptions.entries.map(
                  (e) => ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      _sortBy == e.key
                          ? Icons.radio_button_checked
                          : Icons.radio_button_off,
                      color: _sortBy == e.key ? C.primary : C.textMuted,
                      size: 20,
                    ),
                    title: Text(
                      e.value,
                      style: TextStyle(
                        color: _sortBy == e.key ? C.primary : C.textPrimary,
                        fontSize: 14,
                      ),
                    ),
                    onTap: () {
                      setState(() => _sortBy = e.key);
                      Navigator.pop(context);
                    },
                  ),
                ),
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
                Row(
                  children: [
                    const Text(
                      'Filters',
                      style: TextStyle(
                        color: C.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _statusFilter = 'All';
                          _objectiveFilter = 'All';
                        });
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Reset',
                        style: TextStyle(
                          color: C.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Objective',
                  style: TextStyle(
                    color: C.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _objectiveOptions
                      .map(
                        (o) => FilterChip2(
                          label: o,
                          selected: _objectiveFilter == o,
                          onTap: () {
                            setState(() => _objectiveFilter = o);
                            Navigator.pop(context);
                          },
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
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
              const Icon(Icons.wifi_off_rounded, color: C.error, size: 28),
              const SizedBox(height: 12),
              const Text(
                'Unable to load campaigns',
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
                onTap: () => ref.read(campaignsProvider.notifier).load(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}