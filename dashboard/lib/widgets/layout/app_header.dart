import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../providers/ui_provider.dart';
import 'responsive_builder.dart';

class AppHeader extends ConsumerStatefulWidget {
  final VoidCallback? onMenuTap;
  const AppHeader({super.key, this.onMenuTap});

  @override
  ConsumerState<AppHeader> createState() => _AppHeaderState();
}

class _AppHeaderState extends ConsumerState<AppHeader> {
  bool _searchOpen = false;
  bool _dateOpen = false;
  final _searchCtrl = TextEditingController();
  OverlayEntry? _overlay;

  @override
  void dispose() { _searchCtrl.dispose(); _removeOverlay(); super.dispose(); }

  void _removeOverlay() { _overlay?.remove(); _overlay = null; _dateOpen = false; }

  void _toggleDate() {
    if (_dateOpen) { _removeOverlay(); setState(() {}); return; }
    final o = Overlay.of(context);
    _overlay = OverlayEntry(builder: (ctx) => Stack(children: [
      Positioned.fill(child: GestureDetector(onTap: () { _removeOverlay(); setState(() {}); }, child: Container(color: Colors.transparent))),
      Positioned(right: 16, top: 60, child: Material(color: Colors.transparent, child: Container(
        width: 200, padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: KaapavColors.dark800, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KaapavColors.dark700.withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]),
        child: Column(mainAxisSize: MainAxisSize.min, children: AppConstants.datePresets.map((p) {
          final sel = ref.read(dateRangeProvider) == p.value;
          return GestureDetector(
            onTap: () { ref.read(dateRangeProvider.notifier).state = p.value; _removeOverlay(); setState(() {}); },
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(color: sel ? KaapavColors.kaapav600.withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(10)),
              child: Text(p.label, style: TextStyle(fontSize: 13, fontWeight: sel ? FontWeight.w600 : FontWeight.w400, color: sel ? KaapavColors.kaapav400 : KaapavColors.dark300))),
          );
        }).toList()),
      ))),
    ]));
    o.insert(_overlay!);
    _dateOpen = true;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final dateRange = ref.watch(dateRangeProvider);
    final isMobile = ResponsiveBuilder.isMobile(context);
    final preset = AppConstants.datePresets.firstWhere((p) => p.value == dateRange, orElse: () => AppConstants.datePresets[2]);

    return Container(height: 64,
      decoration: BoxDecoration(color: KaapavColors.dark950.withOpacity(0.8),
        border: Border(bottom: BorderSide(color: KaapavColors.dark700.withOpacity(0.5)))),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(children: [
        if (isMobile) IconButton(onPressed: widget.onMenuTap, icon: const Icon(LucideIcons.menu, size: 22), color: KaapavColors.dark400),
        Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(color: KaapavColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: KaapavColors.success.withOpacity(0.2))),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Container(width: 6, height: 6, decoration: BoxDecoration(color: KaapavColors.success, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: KaapavColors.success.withOpacity(0.5), blurRadius: 6)])),
            const SizedBox(width: 6),
            const Text('Live', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: KaapavColors.success)),
          ])),
        const Spacer(),
        if (_searchOpen)
          SizedBox(width: isMobile ? 160 : 240, height: 38, child: TextField(controller: _searchCtrl, autofocus: true,
            style: const TextStyle(fontSize: 13, color: Colors.white),
            decoration: InputDecoration(hintText: 'Search...', contentPadding: EdgeInsets.zero,
              prefixIcon: const Icon(LucideIcons.search, size: 16, color: KaapavColors.dark400),
              suffixIcon: IconButton(icon: const Icon(LucideIcons.x, size: 14),
                onPressed: () { _searchCtrl.clear(); setState(() => _searchOpen = false); }))))
        else
          IconButton(onPressed: () => setState(() => _searchOpen = true), icon: const Icon(LucideIcons.search, size: 20, color: KaapavColors.dark400)),
        const SizedBox(width: 4),
        GestureDetector(onTap: _toggleDate, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: KaapavColors.dark800, borderRadius: BorderRadius.circular(12), border: Border.all(color: KaapavColors.dark700)),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(LucideIcons.calendar, size: 14, color: KaapavColors.dark400),
            if (!isMobile) ...[const SizedBox(width: 8), Text(preset.label, style: const TextStyle(fontSize: 13, color: KaapavColors.dark200, fontWeight: FontWeight.w500))],
          ]))),
        const SizedBox(width: 4),
        IconButton(onPressed: () {}, icon: const Icon(LucideIcons.refreshCw, size: 20, color: KaapavColors.dark400)),
        Stack(children: [
          IconButton(onPressed: () {}, icon: const Icon(LucideIcons.bell, size: 20, color: KaapavColors.dark400)),
          Positioned(right: 8, top: 8, child: Container(width: 8, height: 8,
            decoration: BoxDecoration(color: KaapavColors.kaapav500, shape: BoxShape.circle, border: Border.all(color: KaapavColors.dark950, width: 1.5)))),
        ]),
        const SizedBox(width: 8),
        Container(width: 34, height: 34, decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [KaapavColors.kaapav500, KaapavColors.kaapav700]),
          borderRadius: BorderRadius.circular(10)),
          child: const Center(child: Text('K', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14)))),
      ]));
  }
}
