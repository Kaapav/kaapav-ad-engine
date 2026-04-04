//lib/screens/sheets_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../core/utils.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

class SheetsScreen extends ConsumerStatefulWidget {
  const SheetsScreen({super.key});

  @override
  ConsumerState<SheetsScreen> createState() => _SheetsScreenState();
}

class _SheetsScreenState extends ConsumerState<SheetsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgC;
  final _sheetIdCtrl = TextEditingController();
  final _tokenCtrl = TextEditingController();

  bool _connected = false;
  bool _loading = false;
  bool _syncing = false;
  String _syncStatus = 'idle'; // idle, syncing, success, error
  DateTime? _lastSync;

  // Sync toggles
  bool _syncCampaigns = true;
  bool _syncLeads = true;
  bool _syncDailyInsights = true;
  bool _syncAutomationLog = true;
  bool _autoSync = false;
  String _autoSyncInterval = '6h';

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
    _sheetIdCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (_sheetIdCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Spreadsheet ID is required'),
          backgroundColor: C.error,
        ),
      );
      return;
    }
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _connected = true;
      _loading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ Google Sheets connected'),
          backgroundColor: C.success,
        ),
      );
    }
  }

  Future<void> _syncNow() async {
    setState(() {
      _syncing = true;
      _syncStatus = 'syncing';
    });

    // Simulate syncing each sheet
    for (int i = 0; i < 4; i++) {
      await Future.delayed(const Duration(milliseconds: 800));
    }

    setState(() {
      _syncing = false;
      _syncStatus = 'success';
      _lastSync = DateTime.now();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✅ All sheets synced successfully'),
          backgroundColor: C.success,
        ),
      );
    }

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _syncStatus = 'idle');
    });
  }

  Future<void> _initializeSheets() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() => _loading = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('📊 Sheet tabs created: Campaigns, Leads, Daily Insights, Automation Log'),
          backgroundColor: C.success,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: C.textPrimary, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Google Sheets',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        actions: [
          if (_connected)
            IconButton(
              icon: Icon(Icons.refresh_rounded, color: C.primary),
              onPressed: _syncing ? null : _syncNow,
            ),
        ],
      ),
      body: AnimatedBuilder(
        animation: _bgC,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.3, -0.5 + _bgC.value * 0.3),
                radius: 1.8,
                colors: [
                  C.success.withValues(alpha: 0.05 * _bgC.value),
                  C.bgDeep,
                  C.bg,
                ],
              ),
            ),
            child: child,
          );
        },
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 10),
                _statusCard(),
                const SizedBox(height: 24),
                if (!_connected) ...[
                  _connectForm(),
                ] else ...[
                  _syncOverview(),
                  const SizedBox(height: 20),
                  _sheetTabs(),
                  const SizedBox(height: 20),
                  _syncSettings(),
                  const SizedBox(height: 20),
                  _autoSyncCard(),
                  const SizedBox(height: 20),
                  _actionsSection(),
                ],
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusCard() {
    return GlassCard(
      turquoise: _connected,
      glow: _connected,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: (_connected ? C.success : C.textMuted)
                  .withValues(alpha: 0.15),
            ),
            child: Icon(
              Icons.table_chart_rounded,
              color: _connected ? C.success : C.textMuted,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connected ? 'Sheets Connected' : 'Not Connected',
                  style: TextStyle(
                      color: C.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  _connected
                      ? 'Last sync: ${_lastSync != null ? U.ago(_lastSync!) : 'Never'}'
                      : 'Connect your Google Spreadsheet',
                  style: TextStyle(color: C.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_syncing)
            SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation(C.primary),
              ),
            )
          else
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _connected ? C.success : C.textMuted,
                boxShadow: _connected
                    ? [
                        BoxShadow(
                          color: C.success.withValues(alpha: 0.5),
                          blurRadius: 8,
                        ),
                      ]
                    : [],
              ),
            ),
        ],
      ),
    );
  }

  Widget _connectForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Connect Spreadsheet',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 16),
        GlassInput(
          label: 'Spreadsheet ID',
          hint: 'e.g. 1BxiMVs0XRA5nFMdKvBdBZjgmUUqptlbs74OgVE2upms',
          controller: _sheetIdCtrl,
          prefixIcon: Icons.link_rounded,
        ),
        const SizedBox(height: 14),
        GlassInput(
          label: 'Service Account Token (Optional)',
          hint: 'OAuth2 token or API key',
          controller: _tokenCtrl,
          obscure: true,
          prefixIcon: Icons.key_rounded,
        ),
        const SizedBox(height: 20),
        // Help
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('How to find your Spreadsheet ID',
                  style: TextStyle(
                      color: C.primary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              _helpStep('1', 'Open your Google Spreadsheet'),
              _helpStep('2', 'Look at the URL in your browser'),
              _helpStep(
                  '3', 'Copy the long ID between /d/ and /edit'),
              _helpStep('4', 'Make sure the sheet is shared with your service account'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        PrimaryBtn(
          label: 'Connect Spreadsheet',
          icon: Icons.link_rounded,
          onTap: _loading ? null : _connect,
          loading: _loading,
        ),
      ],
    );
  }

  Widget _helpStep(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: C.glassTurq,
            ),
            child: Center(
              child: Text(num,
                  style: TextStyle(
                      color: C.primary,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(color: C.textSecondary, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _syncOverview() {
    final sheets = [
      {'name': 'Campaigns', 'rows': 8, 'icon': Icons.campaign_rounded, 'color': C.primary},
      {'name': 'Leads', 'rows': 12, 'icon': Icons.people_alt_rounded, 'color': C.info},
      {'name': 'Daily Insights', 'rows': 30, 'icon': Icons.insights_rounded, 'color': C.purple},
      {'name': 'Automation Log', 'rows': 6, 'icon': Icons.auto_awesome, 'color': C.gold},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Synced Sheets',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.6,
          ),
          itemCount: sheets.length,
          itemBuilder: (context, i) {
            final s = sheets[i];
            return GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(s['icon'] as IconData,
                      color: s['color'] as Color, size: 22),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['name'] as String,
                          style: TextStyle(
                              color: C.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      const SizedBox(height: 2),
                      Text('${s['rows']} rows',
                          style: TextStyle(
                              color: C.textSecondary, fontSize: 11)),
                    ],
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _sheetTabs() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data to Sync',
              style: TextStyle(
                  color: C.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          _syncToggle('Campaigns', 'Campaign performance data',
              _syncCampaigns, (v) => setState(() => _syncCampaigns = v)),
          _syncToggle('Leads', 'CRM leads & pipeline stages',
              _syncLeads, (v) => setState(() => _syncLeads = v)),
          _syncToggle('Daily Insights', 'Daily spend, revenue, ROAS',
              _syncDailyInsights,
              (v) => setState(() => _syncDailyInsights = v)),
          _syncToggle('Automation Log', 'Rule triggers & actions',
              _syncAutomationLog,
              (v) => setState(() => _syncAutomationLog = v)),
        ],
      ),
    );
  }

  Widget _syncToggle(
      String title, String subtitle, bool value, ValueChanged<bool> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: C.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style:
                        TextStyle(color: C.textSecondary, fontSize: 11)),
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

  Widget _syncSettings() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Sync Now',
                  style: TextStyle(
                      color: C.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              if (_syncStatus == 'success')
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: C.success.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('✓ Synced',
                      style: TextStyle(
                          color: C.success,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 14),
          PrimaryBtn(
            label: _syncing ? 'Syncing...' : 'Sync All Data',
            icon: Icons.sync_rounded,
            onTap: _syncing ? null : _syncNow,
            loading: _syncing,
          ),
        ],
      ),
    );
  }

  Widget _autoSyncCard() {
    final intervals = ['1h', '3h', '6h', '12h', '24h'];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Auto Sync',
                  style: TextStyle(
                      color: C.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600)),
              Switch(
                value: _autoSync,
                onChanged: (v) => setState(() => _autoSync = v),
                activeTrackColor: C.primary,
                inactiveThumbColor: C.textMuted,
                inactiveTrackColor: C.bgLight,
              ),
            ],
          ),
          if (_autoSync) ...[
            const SizedBox(height: 10),
            Text('Sync Interval',
                style: TextStyle(color: C.textSecondary, fontSize: 12)),
            const SizedBox(height: 8),
            Row(
              children: intervals.map((iv) {
                final selected = _autoSyncInterval == iv;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () =>
                        setState(() => _autoSyncInterval = iv),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected
                            ? C.primary.withValues(alpha: 0.15)
                            : C.glassWhite,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: selected
                              ? C.primary.withValues(alpha: 0.5)
                              : C.glassBorder,
                        ),
                      ),
                      child: Text(iv,
                          style: TextStyle(
                              color: selected ? C.primary : C.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _actionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Actions',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        GlassCard(
          child: Column(
            children: [
              _actionTile(Icons.table_chart_rounded, 'Initialize Sheet Tabs',
                  'Create Campaigns, Leads, Insights, Log tabs', C.primary,
                  onTap: _initializeSheets),
              Divider(color: C.glassBorder, height: 20),
              _actionTile(Icons.download_rounded, 'Export All Data',
                  'Download complete spreadsheet as CSV', C.info),
              Divider(color: C.glassBorder, height: 20),
              _actionTile(Icons.delete_sweep_rounded, 'Clear Sheet Data',
                  'Remove all synced data from sheets', C.error),
              Divider(color: C.glassBorder, height: 20),
              _actionTile(Icons.open_in_new_rounded, 'Open in Browser',
                  'View spreadsheet in Google Sheets', C.success),
            ],
          ),
        ),
      ],
    );
  }

  Widget _actionTile(
      IconData icon, String title, String subtitle, Color color,
      {VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap ??
          () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('$title — coming soon'),
                backgroundColor: C.bgCard,
              ),
            );
          },
      borderRadius: BorderRadius.circular(12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: TextStyle(
                        color: C.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500)),
                Text(subtitle,
                    style:
                        TextStyle(color: C.textSecondary, fontSize: 11)),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: C.textMuted, size: 20),
        ],
      ),
    );
  }
}