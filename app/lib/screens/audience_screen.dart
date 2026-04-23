import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme.dart';
import '../core/utils.dart';
import '../models/audience_score.dart';
import '../models/creative_match.dart';
import '../models/buyer_quality.dart';
import '../providers/intelligence_provider.dart';
import '../widgets/audience_score_tile.dart';
import '../widgets/buyer_quality_tile.dart';
import '../widgets/buttons.dart';
import '../widgets/common.dart';
import '../widgets/empty_state.dart';
import '../widgets/glass_card.dart';
import '../widgets/matrix_heatmap.dart';
import '../widgets/score_badge.dart';

class AudienceScreen extends ConsumerStatefulWidget {
  const AudienceScreen({super.key});

  @override
  ConsumerState<AudienceScreen> createState() =>
      _AudienceScreenState();
}

class _AudienceScreenState extends ConsumerState<AudienceScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  // 0 = Audiences, 1 = Creative Matrix, 2 = Buyers
  int _tab = 0;

  // Audience filter
  String _audienceFilter = 'all'; // all / hot / scalable / watch / kill

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
      vsync:    this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _bgC.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(audienceScoresProvider(const AudienceQuery()));
    ref.invalidate(creativeMatchesProvider(const CreativeQuery()));
    ref.invalidate(buyerQualityProvider(const BuyerQuery()));
    ref.invalidate(intelligenceSummaryProvider);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content:         Text('✅ Intelligence refreshed'),
        backgroundColor: C.success,
        duration:        Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final audienceAsync = ref.watch(
      audienceScoresProvider(const AudienceQuery()),
    );
    final creativeAsync = ref.watch(
      creativeMatchesProvider(const CreativeQuery()),
    );
    final buyerAsync = ref.watch(
      buyerQualityProvider(const BuyerQuery()),
    );
    final summaryAsync = ref.watch(intelligenceSummaryProvider);

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          // Animated BG
          AnimatedBuilder(
            animation: _bgC,
            builder:   (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(
                    -0.3 + _bgC.value * 0.4,
                    -0.7 + _bgC.value * 0.3,
                  ),
                  radius: 1.5,
                  colors: [
                    C.purple.withValues(alpha: 0.06),
                    C.primary.withValues(alpha: 0.04),
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
                _header(summaryAsync),
                _tabBar(),
                const SizedBox(height: 6),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh:       _refresh,
                    color:           C.primary,
                    backgroundColor: C.bgCard,
                    child: _body(
                      audienceAsync: audienceAsync,
                      creativeAsync: creativeAsync,
                      buyerAsync:    buyerAsync,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // HEADER
  // ══════════════════════════════════════════════════════════════

  Widget _header(AsyncValue<dynamic> summaryAsync) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Intelligence',
                  style: TextStyle(
                    color:      C.textPrimary,
                    fontSize:   22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'Audiences • Creative Matrix • Buyers',
                  style: TextStyle(
                    color:    C.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const LiveDot(),
          const SizedBox(width: 8),
          GlassIconBtn(
            icon:  Icons.refresh_rounded,
            onTap: () async {
              HapticFeedback.lightImpact();
              await _refresh();
            },
          ),
          const SizedBox(width: 8),
          GlassIconBtn(
            icon:  Icons.auto_awesome_rounded,
            badge: false,
            onTap: () async {
              HapticFeedback.mediumImpact();
              await ref
                  .read(intelligenceActionsProvider)
                  .recompute();
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content:         Text('✅ Recompute triggered'),
                  backgroundColor: C.success,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB BAR
  // ══════════════════════════════════════════════════════════════

  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:        C.bgCard,
                borderRadius: BorderRadius.circular(12),
                border:       Border.all(color: C.glassBorder),
              ),
              child: Row(
                children: [
                  _tab2(0, Icons.people_alt_rounded,         'Audiences'),
                  _tab2(1, Icons.grid_view_rounded,          'Creative Matrix'),
                  _tab2(2, Icons.workspace_premium_rounded,  'Buyers'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tab2(int index, IconData icon, String label) {
    final sel = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _tab = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical:   9,
          ),
          decoration: BoxDecoration(
            gradient:     sel ? C.primaryGrad : null,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: sel ? Colors.black : C.textMuted,
                size:  14,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color:      sel ? Colors.black : C.textMuted,
                    fontSize:   10,
                    fontWeight: sel
                        ? FontWeight.w900
                        : FontWeight.w400,
                  ),
                  maxLines:  1,
                  overflow:  TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BODY ROUTER
  // ══════════════════════════════════════════════════════════════

  Widget _body({
    required AsyncValue<List<AudienceScore>> audienceAsync,
    required AsyncValue<List<CreativeMatch>> creativeAsync,
    required AsyncValue<List<BuyerQuality>> buyerAsync,
  }) {
    switch (_tab) {
      case 0:
        return _audienceTab(audienceAsync);
      case 1:
        return _creativeMatrixTab(creativeAsync);
      case 2:
        return _buyersTab(buyerAsync);
      default:
        return _audienceTab(audienceAsync);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 0: AUDIENCES
  // ══════════════════════════════════════════════════════════════

  Widget _audienceTab(
    AsyncValue<List<AudienceScore>> audienceAsync,
  ) {
    return audienceAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: C.primary),
      ),
      error: (e, _) => _errorState(
        'Failed to load audience scores',
        e.toString(),
        () => ref.invalidate(audienceScoresProvider(const AudienceQuery())),
      ),
      data: (audiences) {
        if (audiences.isEmpty) {
          return EmptyState(
            icon:        Icons.people_alt_outlined,
            title:       'No audience scores yet',
            subtitle:    'Run intelligence recompute to generate scores',
            actionLabel: 'Recompute',
            onAction:    () async {
              await ref.read(intelligenceActionsProvider).recompute();
            },
          );
        }

        // Filter
        final filtered = _audienceFilter == 'all'
            ? audiences
            : audiences
                .where((a) => a.status == _audienceFilter)
                .toList();

        // Stats
        final hot       = audiences.where((a) => a.isHot).length;
        final scalable  = audiences.where((a) => a.isScalable).length;
        final watch     = audiences.where((a) => a.isWatch).length;
        final kill      = audiences.where((a) => a.isKill).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Summary bar
            _audienceSummaryBar(
              hot:      hot,
              scalable: scalable,
              watch:    watch,
              kill:     kill,
            ),
            const SizedBox(height: 10),

            // Filter chips
            _audienceFilterRow(),
            const SizedBox(height: 10),

            // Audience tiles
            if (filtered.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No audiences match this filter',
                    style: TextStyle(
                      color:    C.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              )
            else
              ...filtered.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AudienceScoreTile(audience: a),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _audienceSummaryBar({
    required int hot,
    required int scalable,
    required int watch,
    required int kill,
  }) {
    return GlassCard(
      radius:  16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _summItem('Hot',      '$hot',      C.success),
          _vDivider(),
          _summItem('Scalable', '$scalable', C.primary),
          _vDivider(),
          _summItem('Watch',    '$watch',    C.warning),
          _vDivider(),
          _summItem('Kill',     '$kill',     C.error),
        ],
      ),
    );
  }

  Widget _summItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color:      color,
            fontSize:   18,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            color:    C.textMuted,
            fontSize: 10,
          ),
        ),
      ],
    );
  }

  Widget _vDivider() =>
      Container(width: 1, height: 28, color: C.glassBorder);

  Widget _audienceFilterRow() {
    final filters = [
      ('all', 'All', C.textSecondary),
      ('hot', 'Hot 🔥', C.success),
      ('scalable', 'Scalable', C.primary),
      ('watch', 'Watch', C.warning),
      ('kill', 'Kill', C.error),
    ];

    return SizedBox(
      height: 34,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: filters.map((f) {
          final sel = _audienceFilter == f.$1;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _audienceFilter = f.$1);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical:   7,
                ),
                decoration: BoxDecoration(
                  color: sel
                      ? f.$3.withValues(alpha: 0.15)
                      : C.glassWhite,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel
                        ? f.$3.withValues(alpha: 0.4)
                        : C.glassBorder,
                  ),
                ),
                child: Text(
                  f.$2,
                  style: TextStyle(
                    color: sel ? f.$3 : C.textSecondary,
                    fontSize:   11,
                    fontWeight: sel
                        ? FontWeight.w900
                        : FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 1: CREATIVE MATRIX
  // ══════════════════════════════════════════════════════════════

  Widget _creativeMatrixTab(
    AsyncValue<List<CreativeMatch>> creativeAsync,
  ) {
    return creativeAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: C.primary),
      ),
      error: (e, _) => _errorState(
        'Failed to load creative matrix',
        e.toString(),
        () => ref.invalidate(
          creativeMatchesProvider(const CreativeQuery()),
        ),
      ),
      data: (creatives) {
        if (creatives.isEmpty) {
          return EmptyState(
            icon:        Icons.grid_view_outlined,
            title:       'No creative scores yet',
            subtitle:    'Run intelligence recompute to generate the matrix',
            actionLabel: 'Recompute',
            onAction:    () async {
              await ref.read(intelligenceActionsProvider).recompute();
            },
          );
        }

        // Sorted: winners first
        final sorted = [...creatives]
          ..sort((a, b) => b.matchScore.compareTo(a.matchScore));

        final winners  = sorted.where((c) => c.isWinner).length;
        final testMore = sorted.where((c) => c.isTestMore).length;
        final weak     = sorted.where((c) => c.isWeak).length;
        final stop     = sorted.where((c) => c.isStop).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Creative summary bar
            GlassCard(
              radius:  16,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical:   12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summItem('Winner',   '$winners',  C.success),
                  _vDivider(),
                  _summItem('Test',     '$testMore', C.primary),
                  _vDivider(),
                  _summItem('Weak',     '$weak',     C.warning),
                  _vDivider(),
                  _summItem('Stop',     '$stop',     C.error),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Heatmap section
            GlassCard(
              radius:  18,
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.grid_view_rounded,
                        color: C.primary,
                        size:  16,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Audience × Creative Heatmap',
                        style: TextStyle(
                          color:      C.textPrimary,
                          fontSize:   13,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  MatrixHeatmap(matches: sorted),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Individual creative tiles
            const SectionHeader(title: 'All Creatives'),
            const SizedBox(height: 10),
            ...sorted.map(
              (c) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _creativeMatchTile(c),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _creativeMatchTile(CreativeMatch c) {
    final statusColor = c.isWinner
        ? C.success
        : c.isTestMore
            ? C.primary
            : c.isWeak
                ? C.warning
                : C.error;

    final statusLabel = c.isWinner
        ? 'WINNER'
        : c.isTestMore
            ? 'TEST MORE'
            : c.isWeak
                ? 'WEAK'
                : 'STOP';

    return GlassCard(
      radius:  18,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Match score badge
          ScoreBadge(score: c.matchScore, size: 52),
          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + status
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        c.creativeName,
                        style: const TextStyle(
                          color:      C.textPrimary,
                          fontSize:   13,
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical:   4,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: statusColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        statusLabel,
                        style: TextStyle(
                          color:      statusColor,
                          fontSize:   9,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Metrics
                Row(
                  children: [
                    _miniChip(
                      'ROAS',
                      U.roas(c.roas),
                      c.roas >= 4 ? C.success : C.textMuted,
                    ),
                    const SizedBox(width: 8),
                    _miniChip(
                      'CTR',
                      U.pct(c.ctr),
                      c.ctr >= 3 ? C.success : C.textMuted,
                    ),
                    const SizedBox(width: 8),
                    _miniChip(
                      'Fatigue',
                      c.fatigueScore.toStringAsFixed(0),
                      c.fatigueScore >= 50 ? C.warning : C.textMuted,
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Fatigue score bar
                ScoreBar(score: 100 - c.fatigueScore),

                // Top reason
                if (c.reasons.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    c.reasons.first,
                    style: TextStyle(
                      color:     statusColor.withValues(alpha: 0.85),
                      fontSize:  10,
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color:        C.glassWhite,
        borderRadius: BorderRadius.circular(6),
        border:       Border.all(color: C.glassBorder),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              color:      color,
              fontSize:   10,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              color:    C.textMuted,
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // TAB 2: BUYERS
  // ══════════════════════════════════════════════════════════════

  Widget _buyersTab(AsyncValue<List<BuyerQuality>> buyerAsync) {
    return buyerAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: C.primary),
      ),
      error: (e, _) => _errorState(
        'Failed to load buyer quality',
        e.toString(),
        () => ref.invalidate(
          buyerQualityProvider(const BuyerQuery()),
        ),
      ),
      data: (buyers) {
        if (buyers.isEmpty) {
          return EmptyState(
            icon:        Icons.workspace_premium_outlined,
            title:       'No buyer scores yet',
            subtitle:    'Buyer quality is computed from CRM lead data',
            actionLabel: 'Recompute',
            onAction:    () async {
              await ref.read(intelligenceActionsProvider).recompute();
            },
          );
        }

        final sorted = [...buyers]
          ..sort(
            (a, b) =>
                b.buyerQualityScore.compareTo(a.buyerQualityScore),
          );

        final platinum = buyers.where((b) => b.isPlatinum).length;
        final gold     = buyers.where((b) => b.isGold).length;
        final silver   = buyers.where((b) => b.isSilver).length;
        final risk     = buyers.where((b) => b.isRisk).length;
        final seeds    = buyers.where((b) => b.isSeedEligible).length;

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 110),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            // Tier summary
            GlassCard(
              radius:  16,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical:   12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _summItem('Platinum', '$platinum', C.primary),
                  _vDivider(),
                  _summItem('Gold',     '$gold',     C.gold),
                  _vDivider(),
                  _summItem('Silver',   '$silver',   C.textSecondary),
                  _vDivider(),
                  _summItem('Risk',     '$risk',     C.error),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Seed candidates banner
            if (seeds > 0) ...[
              GlassCard(
                radius:    16,
                turquoise: true,
                padding:   const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient:     C.primaryGrad,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.grain_rounded,
                        color: Colors.black,
                        size:  18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$seeds Lookalike Seed Candidate(s)',
                            style: const TextStyle(
                              color:      C.textPrimary,
                              fontSize:   13,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Gold/Platinum buyers with zero refunds. '
                            'Push to Meta for 1% LAL.',
                            style: const TextStyle(
                              color:    C.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    OutlineBtn(
                      label: 'Push',
                      icon:  Icons.upload_rounded,
                      color: C.primary,
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              '🔄 Platinum Seed Sync coming in Phase 4',
                            ),
                            backgroundColor: C.bgCard,
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Buyer tiles
            SectionHeader(title: 'All Buyers (${buyers.length})'),
            const SizedBox(height: 10),
            ...sorted.map(
              (b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: BuyerQualityTile(buyer: b),
              ),
            ),
          ],
        );
      },
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SHARED ERROR STATE
  // ══════════════════════════════════════════════════════════════

  Widget _errorState(
    String title,
    String message,
    VoidCallback onRetry,
  ) {
    return ListView(
      physics:  const AlwaysScrollableScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.all(24),
          child: GlassCard(
            radius:  18,
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: C.error,
                  size:  28,
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: const TextStyle(
                    color:      C.textPrimary,
                    fontSize:   16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color:    C.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                OutlineBtn(
                  label: 'Retry',
                  icon:  Icons.refresh_rounded,
                  onTap: onRetry,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}