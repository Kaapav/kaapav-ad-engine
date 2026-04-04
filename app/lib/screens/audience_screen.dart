import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';
import '../widgets/search_filter.dart';

class _Audience {
  final String id;
  final String name;
  final String type; // custom, lookalike, saved
  final int size;
  final String source;
  final String status; // ready, processing, too_small
  final DateTime createdAt;
  final bool active;

  _Audience({
    required this.id,
    required this.name,
    required this.type,
    required this.size,
    required this.source,
    required this.status,
    required this.createdAt,
    this.active = true,
  });
}

class AudienceScreen extends ConsumerStatefulWidget {
  const AudienceScreen({super.key});

  @override
  ConsumerState<AudienceScreen> createState() => _AudienceScreenState();
}

class _AudienceScreenState extends ConsumerState<AudienceScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgC;
  String _search = '';
  String _typeFilter = 'All';

  final _audiences = <_Audience>[
    _Audience(
      id: 'aud001',
      name: 'Website Purchasers 180D',
      type: 'custom',
      size: 14200,
      source: 'Pixel',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 30)),
    ),
    _Audience(
      id: 'aud002',
      name: 'LAL 1% — All Purchasers',
      type: 'lookalike',
      size: 2800000,
      source: 'Website Purchasers 180D',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 25)),
    ),
    _Audience(
      id: 'aud003',
      name: 'Engaged Shoppers — Jewellery',
      type: 'saved',
      size: 890000,
      source: 'Interest Targeting',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 45)),
    ),
    _Audience(
      id: 'aud004',
      name: 'LAL 2% — Add to Cart',
      type: 'lookalike',
      size: 5600000,
      source: 'Add to Cart 90D',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 15)),
    ),
    _Audience(
      id: 'aud005',
      name: 'IG Engagers 90D',
      type: 'custom',
      size: 42500,
      source: 'Instagram Page',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 20)),
    ),
    _Audience(
      id: 'aud006',
      name: 'Video Viewers 75%',
      type: 'custom',
      size: 8900,
      source: 'Video Engagement',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 10)),
    ),
    _Audience(
      id: 'aud007',
      name: 'Bridal Interest — Women 25-40',
      type: 'saved',
      size: 1200000,
      source: 'Interest + Demo Targeting',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 60)),
    ),
    _Audience(
      id: 'aud008',
      name: 'LAL 1% — High Value Buyers',
      type: 'lookalike',
      size: 2900000,
      source: 'Purchase Value > ₹5K',
      status: 'processing',
      createdAt: DateTime.now().subtract(const Duration(hours: 6)),
    ),
    _Audience(
      id: 'aud009',
      name: 'FB Page Engaged 30D',
      type: 'custom',
      size: 3200,
      source: 'Facebook Page',
      status: 'too_small',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      active: false,
    ),
    _Audience(
      id: 'aud010',
      name: 'WhatsApp Contacts',
      type: 'custom',
      size: 5800,
      source: 'Customer List',
      status: 'ready',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
  ];

  List<_Audience> get _filtered {
    var list = _audiences.where((a) {
      final matchSearch = a.name.toLowerCase().contains(_search.toLowerCase()) ||
          a.source.toLowerCase().contains(_search.toLowerCase());
      final matchType =
          _typeFilter == 'All' || a.type == _typeFilter.toLowerCase();
      return matchSearch && matchType;
    }).toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

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

  Color _typeColor(String type) {
    switch (type) {
      case 'custom':
        return C.info;
      case 'lookalike':
        return C.purple;
      case 'saved':
        return C.gold;
      default:
        return C.textMuted;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'custom':
        return Icons.people_alt_rounded;
      case 'lookalike':
        return Icons.hub_rounded;
      case 'saved':
        return Icons.bookmark_rounded;
      default:
        return Icons.group_rounded;
    }
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'ready':
        return 'Ready';
      case 'processing':
        return 'Processing';
      case 'too_small':
        return 'Too Small';
      default:
        return status;
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'ready':
        return C.success;
      case 'processing':
        return C.learning;
      case 'too_small':
        return C.error;
      default:
        return C.textMuted;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filtered;
    final customCount =
        _audiences.where((a) => a.type == 'custom').length;
    final lalCount =
        _audiences.where((a) => a.type == 'lookalike').length;
    final savedCount =
        _audiences.where((a) => a.type == 'saved').length;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: C.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Audiences',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        actions: [
          IconButton(
            icon: Icon(Icons.add_rounded, color: C.primary),
            onPressed: _showCreateAudience,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgC,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(-0.3, -0.5 + _bgC.value * 0.3),
                radius: 1.8,
                colors: [
                  C.purple.withValues(alpha: 0.05 * _bgC.value),
                  C.bgDeep,
                  C.bg,
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: Column(
            children: [
              // Summary
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                child: _summary(customCount, lalCount, savedCount),
              ),

              // Search + Filters
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: GlassSearch(
                  hint: 'Search audiences...',
                  onChanged: (v) => setState(() => _search = v),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: ['All', 'Custom', 'Lookalike', 'Saved']
                      .map((t) => Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip2(
                              label: t,
                              selected: _typeFilter == t,
                              onTap: () =>
                                  setState(() => _typeFilter = t),
                            ),
                          ))
                      .toList(),
                ),
              ),
              const SizedBox(height: 12),

              // List
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.group_off_rounded,
                                color: C.textMuted, size: 48),
                            const SizedBox(height: 12),
                            Text('No audiences found',
                                style: TextStyle(
                                    color: C.textSecondary, fontSize: 14)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        itemCount: filtered.length,
                        itemBuilder: (ctx, i) =>
                            _audienceTile(filtered[i]),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _summary(int custom, int lal, int saved) {
    return Row(
      children: [
        _summaryChip('Custom', custom, C.info),
        const SizedBox(width: 10),
        _summaryChip('Lookalike', lal, C.purple),
        const SizedBox(width: 10),
        _summaryChip('Saved', saved, C.gold),
      ],
    );
  }

  Widget _summaryChip(String label, int count, Color color) {
    return Expanded(
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: color,
                boxShadow: [
                  BoxShadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(color: C.textSecondary, fontSize: 11)),
            ),
            Text('$count',
                style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }

  Widget _audienceTile(_Audience a) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GlassCard(
        onTap: () => _showAudienceDetail(a),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _typeColor(a.type).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(_typeIcon(a.type),
                      color: _typeColor(a.type), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.name,
                          style: TextStyle(
                              color: C.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 3),
                      Text(a.source,
                          style: TextStyle(
                              color: C.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: _statusColor(a.status)
                            .withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(_statusLabel(a.status),
                          style: TextStyle(
                              color: _statusColor(a.status),
                              fontSize: 10,
                              fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(height: 4),
                    Text(U.ago(a.createdAt),
                        style:
                            TextStyle(color: C.textMuted, fontSize: 10)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _audienceStat('Size', U.num(a.size.toDouble())),
                Container(
                  width: 1,
                  height: 20,
                  color: C.glassBorder,
                  margin: const EdgeInsets.symmetric(horizontal: 14),
                ),
                _audienceStat('Type', a.type[0].toUpperCase() + a.type.substring(1)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: _typeColor(a.type).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: _typeColor(a.type).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    a.type.toUpperCase(),
                    style: TextStyle(
                        color: _typeColor(a.type),
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _audienceStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(color: C.textMuted, fontSize: 10)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  void _showAudienceDetail(_Audience a) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [C.bgCard, C.bgDeep],
              ),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(color: C.glassBorder),
            ),
            padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: _typeColor(a.type).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(_typeIcon(a.type),
                          color: _typeColor(a.type), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(a.name,
                              style: TextStyle(
                                  color: C.textPrimary,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _typeColor(a.type)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  a.type.toUpperCase(),
                                  style: TextStyle(
                                      color: _typeColor(a.type),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _statusColor(a.status)
                                      .withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  _statusLabel(a.status),
                                  style: TextStyle(
                                      color: _statusColor(a.status),
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                _detailRow('Audience Size', U.num(a.size.toDouble())),
                _detailRow('Source', a.source),
                _detailRow('Created', U.dateFull(a.createdAt)),
                _detailRow('Status', _statusLabel(a.status)),
                _detailRow('ID', a.id),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlineBtn(
                        label: 'Use in Campaign',
                        icon: Icons.campaign_rounded,
                        color: C.primary,
                        onTap: () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  'Audience "${a.name}" ready to use'),
                              backgroundColor: C.success,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlineBtn(
                        label: 'Create Lookalike',
                        icon: Icons.hub_rounded,
                        color: C.purple,
                        onTap: () => Navigator.pop(ctx),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlineBtn(
                  label: 'Delete Audience',
                  icon: Icons.delete_outline_rounded,
                  color: C.error,
                  onTap: () => Navigator.pop(ctx),
                ),
                const SizedBox(height: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: C.textSecondary, fontSize: 13)),
          Text(value,
              style: TextStyle(
                  color: C.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  void _showCreateAudience() {
    final nameCtrl = TextEditingController();
    String selectedType = 'custom';
    String selectedSource = 'Pixel';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => ClipRRect(
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(24)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [C.bgCard, C.bgDeep],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                border: Border.all(color: C.glassBorder),
              ),
              padding: EdgeInsets.fromLTRB(
                  24, 24, 24, MediaQuery.of(ctx).viewInsets.bottom + 24),
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
                  const SizedBox(height: 20),
                  Text('Create Audience',
                      style: TextStyle(
                          color: C.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 20),
                  GlassInput(
                    label: 'Audience Name',
                    hint: 'e.g. Website Buyers 90D',
                    controller: nameCtrl,
                    prefixIcon: Icons.group_add_rounded,
                  ),
                  const SizedBox(height: 16),
                  Text('Type',
                      style: TextStyle(
                          color: C.textSecondary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500)),
                  const SizedBox(height: 10),
                  Row(
                    children: ['custom', 'lookalike', 'saved'].map((t) {
                      final sel = selectedType == t;
                      return Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(
                              right: t != 'saved' ? 8 : 0),
                          child: GestureDetector(
                            onTap: () =>
                                setSheetState(() => selectedType = t),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12),
                              decoration: BoxDecoration(
                                color: sel
                                    ? _typeColor(t)
                                        .withValues(alpha: 0.15)
                                    : C.glassWhite,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: sel
                                      ? _typeColor(t)
                                          .withValues(alpha: 0.5)
                                      : C.glassBorder,
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(_typeIcon(t),
                                      color: sel
                                          ? _typeColor(t)
                                          : C.textMuted,
                                      size: 22),
                                  const SizedBox(height: 6),
                                  Text(
                                    t[0].toUpperCase() + t.substring(1),
                                    style: TextStyle(
                                        color: sel
                                            ? _typeColor(t)
                                            : C.textSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
// Source Selector (manual chips instead of GlassDropdown)
Text('Source',
    style: TextStyle(
        color: C.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w500)),
const SizedBox(height: 8),
Wrap(
  spacing: 8,
  runSpacing: 8,
  children: [
    'Pixel',
    'Customer List',
    'Instagram Page',
    'Facebook Page',
    'Video Engagement',
    'App Activity',
  ].map((s) {
    final sel = selectedSource == s;
    return GestureDetector(
      onTap: () => setSheetState(() => selectedSource = s),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: sel
              ? C.primary.withValues(alpha: 0.15)
              : C.glassWhite,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: sel
                ? C.primary.withValues(alpha: 0.5)
                : C.glassBorder,
          ),
        ),
        child: Text(s,
            style: TextStyle(
                color: sel ? C.primary : C.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      ),
    );
  }).toList(),
),
                  const SizedBox(height: 24),
                  PrimaryBtn(
                    label: 'Create Audience',
                    icon: Icons.add_rounded,
                    onTap: () {
                      if (nameCtrl.text.isNotEmpty) {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                                '✅ Audience "${nameCtrl.text}" created'),
                            backgroundColor: C.success,
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
    );
  }
}