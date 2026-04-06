import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../providers/app_providers.dart';
import '../widgets/buttons.dart';
import '../widgets/glass_card.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;

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

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);

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
                    -0.3 + _bgC.value * 0.4,
                    -0.6 + _bgC.value * 0.3,
                  ),
                  radius: 1.5,
                  colors: [
                    C.primary.withValues(alpha: 0.04),
                    C.blue.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            bottom: false,
            child: CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Settings & More',
                          style: TextStyle(
                            color: C.textPrimary,
                            fontSize: 22,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Manage your app preferences',
                          style: TextStyle(
                            color: C.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(child: _accountCard()),
                SliverToBoxAdapter(
                  child: connectionAsync.when(
                    loading: () => _connectionLoadingCard(),
                    error: (_, __) => _metaConnectionFallbackCard(),
                    data: (status) => _metaConnectionCard(status),
                  ),
                ),
                SliverToBoxAdapter(child: _quickLinks()),
                SliverToBoxAdapter(child: _notificationSettings(settings)),
                SliverToBoxAdapter(child: _autopilotSettings(settings)),
                SliverToBoxAdapter(child: _generalSettings(settings)),
                SliverToBoxAdapter(child: _exportSection()),
                SliverToBoxAdapter(child: _aboutSection()),
                SliverToBoxAdapter(child: _dangerZone()),
                const SliverToBoxAdapter(child: SizedBox(height: 120)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _accountCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: GlassCard(
        turquoise: true,
        glow: true,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                gradient: C.primaryGrad,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: C.primary.withValues(alpha: 0.4),
                    blurRadius: 12,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Kaapav Fashion Jewellery',
                    style: TextStyle(
                      color: C.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'kaapav@business.com',
                    style: TextStyle(
                      color: C.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(
                    children: [
                      _PlanBadge(),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: C.textMuted,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }

  Widget _connectionLoadingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(
            child: CircularProgressIndicator(color: C.primary),
          ),
        ),
      ),
    );
  }

  Widget _metaConnectionFallbackCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Connection Status', Icons.link_rounded),
            const SizedBox(height: 12),
            const Text(
              'Unable to load connection status',
              style: TextStyle(
                color: C.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _metaConnectionCard(Map<String, dynamic> status) {
    final connected = status['connected'] == true;
    final mode = status['mode']?.toString() ?? 'none';

    final workerOnline = status['workerOnline'] == true;
    final workerReady = status['workerReady'] == true;
    final hasApiKey = status['hasApiKey'] == true;
    final hasSession = status['hasSessionToken'] == true;
    final hasMetaAuth = status['hasMetaAuth'] == true;

    final accountId = status['accountId']?.toString();
    final pixelId = status['pixelId']?.toString();

    final subtitle = connected
        ? mode == 'worker'
            ? 'Connected via Worker'
            : 'Connected via Direct Meta'
        : 'Not connected • Setup required';

    final statusColor = connected ? C.success : C.warning;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: C.facebook.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.link_rounded,
                    color: C.facebook,
                    size: 18,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Backend & Meta Connection',
                        style: TextStyle(
                          color: C.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withValues(alpha: 0.5),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.glassWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.glassBorder),
              ),
              child: Column(
                children: [
                  _infoRow('Worker Online', workerOnline ? 'Yes' : 'No'),
                  const SizedBox(height: 6),
                  _infoRow('Worker Ready', workerReady ? 'Ready' : 'Not Ready'),
                  const SizedBox(height: 6),
                  _infoRow('API Key', hasApiKey ? 'Configured' : 'Missing'),
                  const SizedBox(height: 6),
                  _infoRow('Session', hasSession ? 'Active' : 'Inactive'),
                  const SizedBox(height: 6),
                  _infoRow('Meta Config', hasMetaAuth ? 'Configured' : 'Missing'),
                  const SizedBox(height: 6),
                  _infoRow(
                    'Account ID',
                    accountId?.isNotEmpty == true ? accountId! : '—',
                  ),
                  const SizedBox(height: 6),
                  _infoRow(
                    'Pixel ID',
                    pixelId?.isNotEmpty == true ? pixelId! : '—',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlineBtn(
                    label: 'Refresh Status',
                    icon: Icons.refresh_rounded,
                    color: C.primary,
                    onTap: () {
                      ref.invalidate(connectionStatusProvider);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('🔄 Connection status refreshed'),
                          backgroundColor: C.success,
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlineBtn(
                    label: connected ? 'Reconnect' : 'Connect',
                    icon: Icons.link_rounded,
                    color: C.blue,
                    onTap: () => context.go('/connect'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: C.textMuted,
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: C.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _quickLinks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _quickLink(Icons.insights_rounded, 'Analytics', C.purple, () {
            context.push('/more/analytics');
          }),
          const SizedBox(width: 10),
          _quickLink(Icons.notifications_rounded, 'Notifications', C.gold, () {
            context.push('/more/notifications');
          }),
          const SizedBox(width: 10),
          _quickLink(Icons.table_chart_rounded, 'Sheets', C.success, () {
            context.push('/more/sheets');
          }),
          const SizedBox(width: 10),
          _quickLink(Icons.group_rounded, 'Audiences', C.blue, () {
            context.push('/more/audiences');
          }),
        ],
      ),
    );
  }

  Widget _quickLink(
    IconData icon,
    String label,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: GlassCard(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: C.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _notificationSettings(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Notifications', Icons.notifications_rounded),
            const SizedBox(height: 14),
            _settingToggle(
              'Push Notifications',
              'Get notified about campaign changes',
              settings.pushNotifications,
              (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(pushNotifications: v)),
            ),
            _settingToggle(
              'Budget Alerts',
              'Alert when spend nears daily limit',
              settings.budgetAlerts,
              (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(budgetAlerts: v)),
            ),
            _settingToggle(
              'Daily Report',
              'Receive daily performance summary',
              settings.dailyReport,
              (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(dailyReport: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _autopilotSettings(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('AutoPilot', Icons.auto_awesome),
            const SizedBox(height: 14),
            _settingToggle(
              'Auto Scale',
              'Automatically increase budget for winners',
              settings.autoScale,
              (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(autoScale: v)),
            ),
            _settingToggle(
              'Auto Kill',
              'Automatically pause low performers',
              settings.autoKill,
              (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(autoKill: v)),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ROAS Threshold',
                  style: TextStyle(color: C.textPrimary, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: C.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${settings.roasThreshold.toStringAsFixed(1)}x',
                    style: const TextStyle(
                      color: C.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.roasThreshold,
              min: 0.5,
              max: 5.0,
              divisions: 18,
              activeColor: C.primary,
              inactiveColor: C.glassBorder,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(roasThreshold: v)),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'CPA Threshold',
                  style: TextStyle(color: C.textPrimary, fontSize: 13),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: C.warning.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '₹${settings.cpaThreshold.toInt()}',
                    style: const TextStyle(
                      color: C.warning,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            Slider(
              value: settings.cpaThreshold,
              min: 50,
              max: 500,
              divisions: 18,
              activeColor: C.warning,
              inactiveColor: C.glassBorder,
              onChanged: (v) => ref
                  .read(settingsProvider.notifier)
                  .update((s) => s.copyWith(cpaThreshold: v)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _generalSettings(AppSettings settings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('General', Icons.settings_rounded),
            const SizedBox(height: 14),
            _settingDropdown(
              'Refresh Interval',
              settings.refreshInterval,
              ['5 min', '10 min', '15 min', '30 min', '1 hour'],
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(
                      refreshInterval: v ?? s.refreshInterval,
                    ),
                  ),
            ),
            const SizedBox(height: 12),
            _settingDropdown(
              'Currency',
              settings.currency,
              ['₹ INR', '\$ USD', '€ EUR', '£ GBP'],
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(currency: v ?? s.currency),
                  ),
            ),
            const SizedBox(height: 12),
            _settingDropdown(
              'Date Format',
              settings.dateFormat,
              ['DD MMM YYYY', 'MMM DD, YYYY', 'YYYY-MM-DD'],
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(dateFormat: v ?? s.dateFormat),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _settingDropdown(
    String label,
    String currentValue,
    List<String> options,
    ValueChanged<String?> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: C.textPrimary, fontSize: 13),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: C.glassWhite,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: C.glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(currentValue)
                  ? currentValue
                  : options.first,
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(
                        o,
                        style: const TextStyle(
                          color: C.textPrimary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              dropdownColor: C.bgCard,
              isDense: true,
              icon: const Icon(
                Icons.expand_more_rounded,
                color: C.textMuted,
                size: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _exportSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Export & Sync', Icons.cloud_upload_rounded),
            const SizedBox(height: 14),
            _menuItem(
              Icons.table_chart_rounded,
              'Google Sheets Sync',
              C.success,
              () => context.push('/more/sheets'),
            ),
            _menuItem(
              Icons.picture_as_pdf_rounded,
              'Export PDF Report',
              C.error,
              () => _showComingSoon('PDF Export'),
            ),
            _menuItem(
              Icons.file_download_rounded,
              'Export CSV Data',
              C.blue,
              () => _showComingSoon('CSV Export'),
            ),
            _menuItem(
              Icons.share_rounded,
              'Share Dashboard',
              C.purple,
              () => _showComingSoon('Share'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _aboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('About', Icons.info_rounded),
            const SizedBox(height: 14),
            _menuItem(
              Icons.info_outline_rounded,
              'Version 1.0.0',
              C.textSecondary,
              () {},
            ),
            _menuItem(
              Icons.privacy_tip_rounded,
              'Privacy Policy',
              C.info,
              () {},
            ),
            _menuItem(
              Icons.description_rounded,
              'Terms of Service',
              C.warning,
              () {},
            ),
            _menuItem(
              Icons.help_outline_rounded,
              'Help & Support',
              C.primary,
              () {},
            ),
            _menuItem(
              Icons.star_rounded,
              'Rate the App',
              C.gold,
              () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _dangerZone() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_rounded, color: C.error, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Danger Zone',
                  style: TextStyle(
                    color: C.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _menuItem(
              Icons.cached_rounded,
              'Clear Cache',
              C.warning,
              () => _showConfirm(
                'Clear Cache',
                'This will remove all cached data. Fresh data will be fetched on next load.',
                () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Cache cleared'),
                      backgroundColor: C.success,
                    ),
                  );
                },
              ),
            ),
            _menuItem(
              Icons.restart_alt_rounded,
              'Reset All Settings',
              C.error,
              () => _showConfirm(
                'Reset Settings',
                'This will reset all settings to defaults. Your data will not be affected.',
                () {
                  ref.read(settingsProvider.notifier).reset();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ Settings reset'),
                      backgroundColor: C.success,
                    ),
                  );
                },
              ),
            ),
            _menuItem(
              Icons.logout_rounded,
              'Disconnect & Logout',
              C.error,
              () => _showConfirm(
                'Disconnect & Logout',
                'This will remove all saved tokens and account data. You\'ll need to reconnect.',
                () async {
                  final auth = ref.read(metaAuthProvider);
                  await auth.logout();

                  if (!mounted) return;

                  ref.invalidate(connectionStatusProvider);

                  context.go('/connect');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: C.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            color: C.textPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _settingToggle(
    String title,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: C.textMuted,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeTrackColor: C.primary,
            inactiveThumbColor: C.textMuted,
            inactiveTrackColor: C.bgLight,
          ),
        ],
      ),
    );
  }

  Widget _menuItem(
    IconData icon,
    String title,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: C.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: C.textMuted,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature — coming soon'),
        backgroundColor: C.bgCard,
      ),
    );
  }

  void _showConfirm(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(color: C.textPrimary),
        ),
        content: Text(
          message,
          style: const TextStyle(color: C.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: C.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: Text(
              title.contains('Logout') ? 'Logout' : 'Confirm',
              style: const TextStyle(color: C.error),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlanBadge extends StatelessWidget {
  const _PlanBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        gradient: C.primaryGrad,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.workspace_premium_rounded,
            color: Colors.black,
            size: 12,
          ),
          SizedBox(width: 4),
          Text(
            'Pro Plan • Active',
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}