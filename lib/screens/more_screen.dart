import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../providers/app_providers.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});
  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          AnimatedBuilder(
            animation: _bgC,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment(0.3 - _bgC.value * 0.5, -0.5 + _bgC.value * 0.3),
                  radius: 1.5,
                  colors: [C.primary.withValues(alpha: 0.04), C.blue.withValues(alpha: 0.03), C.bgDeep],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(child: _header()),
                SliverToBoxAdapter(child: _accountCard()),
                SliverToBoxAdapter(child: _metaConnectionCard()),
                SliverToBoxAdapter(child: _notificationSettings(settings)),
                SliverToBoxAdapter(child: _autopilotSettings(settings)),
                SliverToBoxAdapter(child: _generalSettings(settings)),
                SliverToBoxAdapter(child: _exportSection()),
                SliverToBoxAdapter(child: _aboutSection()),
                SliverToBoxAdapter(child: _dangerZone()),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    return const Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings', style: TextStyle(color: C.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          Text('Configure your Kaapav Ad Engine', style: TextStyle(color: C.textSecondary, fontSize: 12)),
        ],
      ),
    );
  }

  // ═══ ACCOUNT CARD ═══
  Widget _accountCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        radius: 20,
        turquoise: true,
        glow: true,
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: C.primary.withValues(alpha: 0.3), blurRadius: 12)]),
              child: const Center(child: Text('K', style: TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.w800))),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kaapav Fashion Jewellery', style: TextStyle(color: C.textPrimary, fontSize: 15, fontWeight: FontWeight.w700)),
                  SizedBox(height: 2),
                  Text('kaapav.jewellery@business.com', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                  SizedBox(height: 2),
                  Text('Pro Plan • Active', style: TextStyle(color: C.success, fontSize: 11, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            GlassIconBtn(icon: Icons.edit_rounded, onTap: () {}),
          ],
        ),
      ),
    );
  }

  // ═══ META CONNECTION ═══
  Widget _metaConnectionCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(color: C.facebook.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.facebook_rounded, color: C.facebook, size: 20),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Meta Business Account', style: TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                      Text('Connected • Token valid', style: TextStyle(color: C.success, fontSize: 11)),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: C.success.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(6)),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, color: C.success, size: 12),
                      SizedBox(width: 4),
                      Text('Active', style: TextStyle(color: C.success, fontSize: 10, fontWeight: FontWeight.w700)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _connectionRow('Ad Account', 'act_123456789', C.blue),
            _connectionRow('Pixel ID', '987654321', C.purple),
            _connectionRow('API Version', 'v21.0', C.primary),
            _connectionRow('Token Expires', '58 days', C.warning),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: OutlineBtn(label: 'Refresh Token', icon: Icons.refresh_rounded, onTap: () {})),
                const SizedBox(width: 8),
                Expanded(child: OutlineBtn(label: 'Reconnect', icon: Icons.link_rounded, color: C.facebook, onTap: () {})),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: C.textMuted, fontSize: 11))),
          Text(value, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ═══ NOTIFICATION SETTINGS ═══
  Widget _notificationSettings(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Notifications', Icons.notifications_outlined),
            const SizedBox(height: 12),
            _toggle('Push Notifications', 'Campaign alerts & updates', settings.pushNotifications, (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(pushNotifications: v));
            }),
            _toggle('Budget Alerts', 'When campaigns approach daily limit', settings.budgetAlerts, (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(budgetAlerts: v));
            }),
            _toggle('Daily Report', 'Receive daily performance summary at 9 AM', settings.dailyReport, (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(dailyReport: v));
            }),
          ],
        ),
      ),
    );
  }

  // ═══ AUTOPILOT SETTINGS ═══
  Widget _autopilotSettings(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('AutoPilot Defaults', Icons.auto_awesome_rounded),
            const SizedBox(height: 12),
            _toggle('Auto-Scale Winners', 'Automatically increase budget for high ROAS campaigns', settings.autoScale, (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoScale: v));
            }),
            _toggle('Auto-Kill Losers', 'Pause campaigns below ROAS threshold', settings.autoKill, (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(autoKill: v));
            }),
            const SizedBox(height: 10),
            _sliderSetting(
              'Min ROAS Threshold',
              '${settings.roasThreshold.toStringAsFixed(1)}x',
              settings.roasThreshold, 0.5, 5.0, 9,
              (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(roasThreshold: v)),
            ),
            _sliderSetting(
              'Max CPA Threshold',
              '₹${settings.cpaThreshold.toStringAsFixed(0)}',
              settings.cpaThreshold, 50, 500, 9,
              (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(cpaThreshold: v)),
            ),
          ],
        ),
      ),
    );
  }

  // ═══ GENERAL SETTINGS ═══
  Widget _generalSettings(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('General', Icons.settings_outlined),
            const SizedBox(height: 12),
            _dropdownSetting('Refresh Interval', settings.refreshInterval, ['5 min', '15 min', '30 min', '1 hour'], (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(refreshInterval: v));
            }),
            const SizedBox(height: 8),
            _dropdownSetting('Currency', settings.currency, ['₹', '\$', '€', '£'], (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(currency: v));
            }),
            const SizedBox(height: 8),
            _dropdownSetting('Date Format', settings.dateFormat, ['dd MMM yyyy', 'MM/dd/yyyy', 'yyyy-MM-dd'], (v) {
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(dateFormat: v));
            }),
          ],
        ),
      ),
    );
  }

  // ═══ EXPORT ═══
  Widget _exportSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('Export & Reports', Icons.file_download_outlined),
            const SizedBox(height: 12),
            _menuItem(Icons.table_chart_rounded, 'Export to Google Sheets', 'Sync campaign data to spreadsheet', C.success, () {}),
            _menuItem(Icons.picture_as_pdf_rounded, 'Download PDF Report', 'Generate full performance report', C.error, () {}),
            _menuItem(Icons.file_copy_rounded, 'Export CSV', 'Raw data export for analysis', C.blue, () {}),
            _menuItem(Icons.share_rounded, 'Share Report', 'Send via WhatsApp or email', C.whatsapp, () {}),
          ],
        ),
      ),
    );
  }

  // ═══ ABOUT ═══
  Widget _aboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionLabel('About', Icons.info_outline_rounded),
            const SizedBox(height: 12),
            _menuItem(Icons.code_rounded, 'Version', '1.0.0 (Build 1)', C.primary, () {}),
            _menuItem(Icons.description_outlined, 'Privacy Policy', null, C.textSecondary, () {}),
            _menuItem(Icons.gavel_rounded, 'Terms of Service', null, C.textSecondary, () {}),
            _menuItem(Icons.help_outline_rounded, 'Help & Support', null, C.blue, () {}),
            _menuItem(Icons.star_outline_rounded, 'Rate App', null, C.gold, () {}),
          ],
        ),
      ),
    );
  }

  // ═══ DANGER ZONE ═══
  Widget _dangerZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(color: C.error.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.warning_amber_rounded, color: C.error, size: 16),
                ),
                const SizedBox(width: 10),
                const Text('Danger Zone', style: TextStyle(color: C.error, fontSize: 14, fontWeight: FontWeight.w700)),
              ],
            ),
            const SizedBox(height: 14),
            _menuItem(Icons.delete_sweep_rounded, 'Clear Cache', 'Remove all cached data', C.warning, () {
              _showConfirm('Clear Cache?', 'All cached data will be removed.', () {});
            }),
            _menuItem(Icons.logout_rounded, 'Disconnect Meta Account', 'Remove Meta API connection', C.error, () {
              _showConfirm('Disconnect?', 'This will remove your Meta API connection.', () {});
            }),
            _menuItem(Icons.delete_forever_rounded, 'Delete All Data', 'Permanently delete all app data', C.error, () {
              _showConfirm('Delete All Data?', 'This action cannot be undone. All leads, rules, and settings will be lost.', () {});
            }),
          ],
        ),
      ),
    );
  }

  // ═══ HELPER WIDGETS ═══
  Widget _sectionLabel(String label, IconData icon) {
    return Row(
      children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(color: C.primary.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
          child: Icon(icon, color: C.primary, size: 16),
        ),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _toggle(String label, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 13)),
                Text(subtitle, style: const TextStyle(color: C.textMuted, fontSize: 10)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) { HapticFeedback.lightImpact(); onChanged(v); },
            activeTrackColor: C.primary,
          ),
        ],
      ),
    );
  }

  Widget _sliderSetting(String label, String valueStr, double value, double min, double max, int divisions, ValueChanged<double> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 12)),
              Text(valueStr, style: const TextStyle(color: C.primary, fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          Slider(
            value: value, min: min, max: max, divisions: divisions,
            activeColor: C.primary,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  Widget _dropdownSetting(String label, String value, List<String> options, ValueChanged<String> onChanged) {
    return Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 13))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(color: C.glassWhite, borderRadius: BorderRadius.circular(8), border: Border.all(color: C.glassBorder)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              dropdownColor: C.bgCard,
              iconEnabledColor: C.primary,
              style: const TextStyle(color: C.textPrimary, fontSize: 12, fontFamily: 'Sora'),
              items: options.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
              onChanged: (v) { if (v != null) onChanged(v); },
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuItem(IconData icon, String label, String? subtitle, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: () { HapticFeedback.lightImpact(); onTap(); },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 13)),
                  if (subtitle != null) Text(subtitle, style: const TextStyle(color: C.textMuted, fontSize: 10)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: C.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showConfirm(String title, String message, VoidCallback onConfirm) {
    showDialog(
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
                    child: const Icon(Icons.warning_amber_rounded, color: C.error, size: 24),
                  ),
                  const SizedBox(height: 14),
                  Text(title, style: const TextStyle(color: C.textPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  Text(message, style: const TextStyle(color: C.textMuted, fontSize: 12), textAlign: TextAlign.center),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(child: OutlineBtn(label: 'Cancel', onTap: () => Navigator.pop(context))),
                      const SizedBox(width: 10),
                      Expanded(
                        child: GestureDetector(
                          onTap: () { Navigator.pop(context); onConfirm(); },
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(gradient: C.dangerGrad, borderRadius: BorderRadius.circular(12)),
                            alignment: Alignment.center,
                            child: const Text('Confirm', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
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
    );
  }
}