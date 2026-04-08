import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/env_config.dart';
import '../core/theme.dart';
import '../models/app_settings.dart';
import '../models/intelligence_summary.dart';
import '../providers/app_providers.dart';
import '../providers/intelligence_provider.dart';
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

  DateTime? _lastOpsActionAt;

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

  // ───────────────────────────
  // Worker helpers
  // ───────────────────────────

  Dio _workerDio() {
    return Dio(
      BaseOptions(
        baseUrl: EnvConfig.workerBaseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 25),
      ),
    );
  }

  Future<Map<String, String>> _workerHeaders() async {
    final auth = ref.read(metaAuthProvider);
    final apiKey = await auth.getApiKey();
    final session = await auth.getSessionToken();

    // Worker supports either header
    if (apiKey != null && apiKey.trim().isNotEmpty) {
      return {'X-API-Key': apiKey.trim()};
    }
    if (session != null && session.trim().isNotEmpty) {
      return {'Authorization': 'Bearer ${session.trim()}'};
    }
    return {};
  }

  void _snack(String msg, {bool ok = true, Duration? duration}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: ok ? C.success : C.error,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }

  Future<_CallResult> _callWorker({
    required String method,
    required String path,
    Object? data,
    bool requiresAuth = true,
  }) async {
    final dio = _workerDio();
    final sw = Stopwatch()..start();

    final headers = requiresAuth ? await _workerHeaders() : <String, String>{};
    if (requiresAuth && headers.isEmpty) {
      return _CallResult(
        ok: false,
        ms: 0,
        message: 'Not connected. Please connect first.',
        data: null,
      );
    }

    try {
      Response res;
      final opts = Options(headers: headers);

      if (method.toUpperCase() == 'GET') {
        res = await dio.get(path, options: opts);
      } else if (method.toUpperCase() == 'POST') {
        res = await dio.post(path, data: data, options: opts);
      } else {
        res = await dio.request(path, data: data, options: opts.copyWith(method: method));
      }

      sw.stop();

      final body = res.data;
      final success = body is Map && body['success'] == true;

      return _CallResult(
        ok: success,
        ms: sw.elapsedMilliseconds,
        message: success ? 'OK' : _bestErrorMessage(body) ?? 'Request failed',
        data: body,
      );
    } catch (e) {
      sw.stop();
      return _CallResult(
        ok: false,
        ms: sw.elapsedMilliseconds,
        message: _prettyDioError(e),
        data: null,
      );
    }
  }

  String _prettyDioError(Object e) {
    if (e is DioException) {
      final r = e.response?.data;
      final m = _bestErrorMessage(r);
      if (m != null) return m;
      return e.message ?? 'Network error';
    }
    return 'Unexpected error';
  }

  String? _bestErrorMessage(dynamic body) {
    if (body is Map) {
      final err = body['error'];
      if (err is String && err.trim().isNotEmpty) return err.trim();
      final msg = body['message'];
      if (msg is String && msg.trim().isNotEmpty) return msg.trim();
    }
    return null;
  }

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _snack('Invalid URL', ok: false);
      return;
    }
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) _snack('Unable to open URL', ok: false);
  }

  // ───────────────────────────
  // Build
  // ───────────────────────────

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final connectionAsync = ref.watch(connectionStatusProvider);
    final unreadCountAsync = ref.watch(notificationsCountProvider);
    final intelAsync = ref.watch(intelligenceSummaryProvider);

    final unread = unreadCountAsync.valueOrNull ?? 0;

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
                  radius: 1.6,
                  colors: [
                    C.primary.withValues(alpha: 0.045),
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
                SliverToBoxAdapter(
                  child: _header(unread),
                ),
                SliverToBoxAdapter(child: _accountCard()),

                SliverToBoxAdapter(
                  child: _opsOverviewStrip(
                    connectionAsync: connectionAsync,
                    intelAsync: intelAsync,
                    unreadAlerts: unread,
                  ),
                ),

                SliverToBoxAdapter(
                  child: connectionAsync.when(
                    loading: () => _connectionLoadingCard(),
                    error: (_, __) => _connectionFallbackCard(),
                    data: (status) => _connectionCard(status),
                  ),
                ),

                SliverToBoxAdapter(
                  child: _primaryActionsRow(
                    connectionAsync: connectionAsync,
                    intelAsync: intelAsync,
                  ),
                ),

                SliverToBoxAdapter(child: _quickLinks()),

                SliverToBoxAdapter(child: _opsSection()),
                SliverToBoxAdapter(child: _integrationsSection()),
                SliverToBoxAdapter(child: _syncSection()),
                SliverToBoxAdapter(child: _exportAndShareSection()),

                SliverToBoxAdapter(child: _notificationSettings(settings)),
                SliverToBoxAdapter(child: _autopilotSettings(settings)),
                SliverToBoxAdapter(child: _generalSettings(settings)),

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

  // ───────────────────────────
  // Header / Account
  // ───────────────────────────

  Widget _header(int unread) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Operations Console',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Worker • Intelligence • Integrations',
                  style: TextStyle(color: C.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          GlassIconBtn(
            icon: Icons.bug_report_rounded,
            badge: false,
            onTap: _openDiagnostics,
          ),
          const SizedBox(width: 10),
          GlassIconBtn(
            icon: Icons.notifications_rounded,
            badge: unread > 0,
            badgeCount: unread.toString(),
            onTap: () => context.push('/more/notifications'),
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
                    color: C.primary.withValues(alpha: 0.35),
                    blurRadius: 14,
                  ),
                ],
              ),
              child: const Center(
                child: Text(
                  'K',
                  style: TextStyle(
                    color: Colors.black,
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
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
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'ROAS Intelligence Engine',
                    style: TextStyle(color: C.textSecondary, fontSize: 12),
                  ),
                  SizedBox(height: 6),
                  Row(children: [_PlanBadge()]),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.textMuted, size: 22),
          ],
        ),
      ),
    );
  }

  Widget _opsOverviewStrip({
    required AsyncValue<Map<String, dynamic>> connectionAsync,
    required AsyncValue<IntelligenceSummary> intelAsync,
    required int unreadAlerts,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        radius: 18,
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: connectionAsync.when(
                loading: () => _stripPill('Worker', '...', C.textMuted, Icons.hub_rounded),
                error: (_, __) => _stripPill('Worker', 'Error', C.error, Icons.cloud_off_rounded),
                data: (m) {
                  final s = _ConnVM.fromMap(m);
                  final c = (s.connected && s.workerOnline && s.workerReady)
                      ? C.success
                      : (s.workerOnline ? C.warning : C.error);
                  final t = (s.connected && s.workerOnline && s.workerReady)
                      ? 'Ready'
                      : (s.workerOnline ? 'Online' : 'Offline');
                  return _stripPill('Worker', t, c, Icons.hub_rounded);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: intelAsync.when(
                loading: () => _stripPill('Recs', '...', C.textMuted, Icons.bolt_rounded),
                error: (_, __) => _stripPill('Recs', '—', C.textMuted, Icons.bolt_rounded),
                data: (i) => _stripPill(
                  'Recs',
                  '${i.openRecommendations}',
                  i.openRecommendations > 0 ? C.warning : C.success,
                  Icons.bolt_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: intelAsync.when(
                loading: () => _stripPill('Fatigue', '...', C.textMuted, Icons.repeat_rounded),
                error: (_, __) => _stripPill('Fatigue', '—', C.textMuted, Icons.repeat_rounded),
                data: (i) => _stripPill(
                  'Fatigue',
                  '${i.fatigueAlerts}',
                  i.fatigueAlerts > 0 ? C.warning : C.textSecondary,
                  Icons.repeat_rounded,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _stripPill(
                'Alerts',
                '$unreadAlerts',
                unreadAlerts > 0 ? C.gold : C.textSecondary,
                Icons.notifications_active_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stripPill(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: C.glassWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: C.glassBorder),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: C.textMuted, fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            value,
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }

  Widget _connectionLoadingCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 14),
          child: Center(child: CircularProgressIndicator(color: C.primary)),
        ),
      ),
    );
  }

  Widget _connectionFallbackCard() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Worker Connection', Icons.link_rounded),
            const SizedBox(height: 12),
            const Text(
              'Unable to load connection status.',
              style: TextStyle(color: C.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlineBtn(
                    label: 'Retry',
                    icon: Icons.refresh_rounded,
                    color: C.primary,
                    onTap: () => ref.invalidate(connectionStatusProvider),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlineBtn(
                    label: 'Connect',
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

  Widget _connectionCard(Map<String, dynamic> raw) {
    final s = _ConnVM.fromMap(raw);

    final subtitle = s.connected
        ? (s.mode == 'worker'
            ? 'Connected via Worker (recommended)'
            : 'Connected via Direct Meta (legacy)')
        : 'Not connected • Setup required';

    final statusColor = (s.connected && s.workerOnline && s.workerReady)
        ? C.success
        : (s.workerOnline ? C.warning : C.error);

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
                    color: C.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: C.primary.withValues(alpha: 0.18)),
                  ),
                  child: const Icon(Icons.hub_rounded, color: C.primary, size: 18),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Worker Connection',
                        style: TextStyle(
                          color: C.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      Text(subtitle, style: TextStyle(color: statusColor, fontSize: 11)),
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
                        color: statusColor.withValues(alpha: 0.55),
                        blurRadius: 8,
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
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: C.glassBorder),
              ),
              child: Column(
                children: [
                  _infoRow('Worker URL', EnvConfig.workerBaseUrl),
                  const SizedBox(height: 6),
                  _infoRow('Worker Online', s.workerOnline ? 'Yes' : 'No'),
                  const SizedBox(height: 6),
                  _infoRow('Worker Ready', s.workerReady ? 'Ready' : 'Not Ready'),
                  const SizedBox(height: 6),
                  _infoRow('API Key', s.hasApiKey ? 'Configured' : 'Missing'),
                  const SizedBox(height: 6),
                  _infoRow('Session', s.hasSessionToken ? 'Active' : 'Inactive'),
                  const SizedBox(height: 6),
                  _infoRow('Meta (Worker)', s.hasMetaAuth ? 'Configured' : 'Missing'),
                  const SizedBox(height: 6),
                  _infoRow('Account ID', (s.accountId?.isNotEmpty ?? false) ? s.accountId! : '—'),
                  const SizedBox(height: 6),
                  _infoRow('Pixel ID', (s.pixelId?.isNotEmpty ?? false) ? s.pixelId! : '—'),
                ],
              ),
            ),

            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlineBtn(
                    label: 'Refresh',
                    icon: Icons.refresh_rounded,
                    color: C.primary,
                    onTap: () {
                      ref.invalidate(connectionStatusProvider);
                      _snack('✅ Status refreshed');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlineBtn(
                    label: s.connected ? 'Reconnect' : 'Connect',
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
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: const TextStyle(color: C.textMuted, fontSize: 12))),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: C.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────
  // Primary actions row (new)
  // ───────────────────────────

  Widget _primaryActionsRow({
    required AsyncValue<Map<String, dynamic>> connectionAsync,
    required AsyncValue<IntelligenceSummary> intelAsync,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          Expanded(
            child: _bigAction(
              icon: Icons.auto_awesome_rounded,
              title: 'Recompute',
              subtitle: 'Worker intelligence',
              color: C.primary,
              onTap: () async {
                HapticFeedback.lightImpact();
                final r = await _callWorker(method: 'POST', path: '/api/intelligence/recompute');
                _lastOpsActionAt = DateTime.now();
                _snack(
                  r.ok ? '✅ Recompute triggered (${r.ms}ms)' : '❌ ${r.message}',
                  ok: r.ok,
                );
                ref.invalidate(intelligenceSummaryProvider);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _bigAction(
              icon: Icons.health_and_safety_rounded,
              title: 'Health',
              subtitle: 'Ping /health',
              color: C.success,
              onTap: () async {
                HapticFeedback.lightImpact();
                final r = await _callWorker(method: 'GET', path: '/health', requiresAuth: false);
                _lastOpsActionAt = DateTime.now();
                _snack(r.ok ? '✅ Worker healthy (${r.ms}ms)' : '⚠️ ${r.message}', ok: r.ok);
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _bigAction(
              icon: Icons.bolt_rounded,
              title: 'AutoPilot',
              subtitle: 'Decisions queue',
              color: C.warning,
              onTap: () => context.go('/autopilot'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bigAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      radius: 18,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      color: C.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                      color: C.textSecondary,
                      fontSize: 10.5,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────
  // Quick links
  // ───────────────────────────

  Widget _quickLinks() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          _quickLink(Icons.insights_rounded, 'Analytics', C.purple, () => context.push('/more/analytics')),
          const SizedBox(width: 10),
          _quickLink(Icons.notifications_rounded, 'Alerts', C.gold, () => context.push('/more/notifications')),
          const SizedBox(width: 10),
          _quickLink(Icons.table_chart_rounded, 'Sheets', C.success, () => context.push('/more/sheets')),
          const SizedBox(width: 10),
          _quickLink(Icons.people_alt_rounded, 'CRM', C.blue, () => context.go('/crm')),
        ],
      ),
    );
  }

  Widget _quickLink(IconData icon, String label, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
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
                  border: Border.all(color: color.withValues(alpha: 0.18)),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  color: C.textSecondary,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────
  // Ops / Integrations / Sync / Export
  // ───────────────────────────

  Widget _opsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Operations', Icons.terminal_rounded),
            const SizedBox(height: 14),
            _menuItem(
              Icons.info_outline_rounded,
              'Worker Info (GET /)',
              C.primary,
              () async {
                final r = await _callWorker(method: 'GET', path: '/', requiresAuth: false);
                if (!r.ok) {
                  _snack('❌ ${r.message}', ok: false);
                  return;
                }
                _showJsonSheet('Worker Info', r.data);
              },
            ),
            _menuItem(
              Icons.health_and_safety_rounded,
              'Health Check (GET /health)',
              C.success,
              () async {
                final r = await _callWorker(method: 'GET', path: '/health', requiresAuth: false);
                _snack(r.ok ? '✅ Healthy (${r.ms}ms)' : '❌ ${r.message}', ok: r.ok);
              },
            ),
            _menuItem(
              Icons.public_rounded,
              'Open Worker URL',
              C.blue,
              () => _openUrl(EnvConfig.workerBaseUrl),
            ),
            _menuItem(
              Icons.public_rounded,
              'Open Health URL',
              C.info,
              () => _openUrl('${EnvConfig.workerBaseUrl}/health'),
            ),
            _menuItem(
              Icons.copy_rounded,
              'Copy Worker URL',
              C.primary,
              () async {
                await Clipboard.setData(const ClipboardData(text: EnvConfig.workerBaseUrl));
                _snack('✅ Copied Worker URL');
              },
            ),
            _menuItem(
              Icons.auto_awesome_rounded,
              'Recompute Intelligence (Worker)',
              C.blue,
              () async {
                final r = await _callWorker(method: 'POST', path: '/api/intelligence/recompute');
                _lastOpsActionAt = DateTime.now();
                _snack(r.ok ? '✅ Recompute triggered (${r.ms}ms)' : '❌ ${r.message}', ok: r.ok);
                ref.invalidate(intelligenceSummaryProvider);
              },
            ),
            _menuItem(
              Icons.bolt_rounded,
              'Optimization Recommendations',
              C.warning,
              () => context.go('/autopilot'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _integrationsSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Integrations', Icons.hub_rounded),
            const SizedBox(height: 14),
            _menuItem(
              Icons.chat_bubble_rounded,
              'WhatsApp Bridge Stats',
              C.whatsapp,
              () async {
                final r = await _callWorker(method: 'GET', path: '/api/bridge/stats');
                if (!r.ok) {
                  _snack('❌ ${r.message}', ok: false);
                  return;
                }
                _showJsonSheet('WhatsApp Bridge Stats', r.data);
              },
            ),
            _menuItem(
              Icons.notifications_active_rounded,
              'FCM Device Registration',
              C.info,
              () {
                _snack(
                  'Wire next: POST /api/notifications/register-device (send FCM token)',
                  ok: true,
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _syncSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Sync & Reporting', Icons.cloud_upload_rounded),
            const SizedBox(height: 14),
            _menuItem(
              Icons.table_chart_rounded,
              'Open Sheets Dashboard',
              C.success,
              () => context.push('/more/sheets'),
            ),
            _menuItem(
              Icons.sync_rounded,
              'Trigger Campaigns → Sheets Sync',
              C.primary,
              () async {
                final r = await _callWorker(method: 'POST', path: '/api/sheets/sync-campaigns');
                _snack(r.ok ? '✅ Campaign sync triggered (${r.ms}ms)' : '❌ ${r.message}', ok: r.ok);
              },
            ),
            _menuItem(
              Icons.sync_alt_rounded,
              'Trigger Leads → Sheets Sync',
              C.blue,
              () async {
                final r = await _callWorker(method: 'POST', path: '/api/sheets/sync-leads');
                _snack(r.ok ? '✅ Lead sync triggered (${r.ms}ms)' : '❌ ${r.message}', ok: r.ok);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _exportAndShareSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Export & Share', Icons.ios_share_rounded),
            const SizedBox(height: 14),
            _menuItem(
              Icons.summarize_rounded,
              'Share Worker URL',
              C.purple,
              () async {
                await Clipboard.setData(const ClipboardData(text: EnvConfig.workerBaseUrl));
                _snack('✅ Copied Worker URL (share in WhatsApp/email)');
              },
            ),
            _menuItem(
              Icons.file_download_rounded,
              'Export (Coming soon)',
              C.textSecondary,
              () => _snack('Export: PDF/CSV will be added next', ok: true),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────
  // Settings
  // ───────────────────────────

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
              'Get notified about campaigns, leads & decisions',
              settings.pushNotifications,
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(pushNotifications: v),
                  ),
            ),
            _settingToggle(
              'Budget Alerts',
              'Alert when spend nears daily limit',
              settings.budgetAlerts,
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(budgetAlerts: v),
                  ),
            ),
            _settingToggle(
              'Daily Report',
              'Daily performance summary (via Worker cron)',
              settings.dailyReport,
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(dailyReport: v),
                  ),
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
              'Increase budget for winners',
              settings.autoScale,
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(autoScale: v),
                  ),
            ),
            _settingToggle(
              'Auto Kill',
              'Pause inefficient campaigns',
              settings.autoKill,
              (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(autoKill: v),
                  ),
            ),
            const SizedBox(height: 10),
            _thresholdSlider(
              label: 'ROAS Threshold',
              valueLabel: '${settings.roasThreshold.toStringAsFixed(1)}x',
              color: C.primary,
              value: settings.roasThreshold,
              min: 0.5,
              max: 5.0,
              divisions: 18,
              onChanged: (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(roasThreshold: v),
                  ),
            ),
            const SizedBox(height: 10),
            _thresholdSlider(
              label: 'CPA Threshold',
              valueLabel: '₹${settings.cpaThreshold.toInt()}',
              color: C.warning,
              value: settings.cpaThreshold,
              min: 50,
              max: 500,
              divisions: 18,
              onChanged: (v) => ref.read(settingsProvider.notifier).update(
                    (s) => s.copyWith(cpaThreshold: v),
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _thresholdSlider({
    required String label,
    required String valueLabel,
    required Color color,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 13))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                valueLabel,
                style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          divisions: divisions,
          activeColor: color,
          inactiveColor: C.glassBorder,
          onChanged: onChanged,
        ),
      ],
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
                    (s) => s.copyWith(refreshInterval: v ?? s.refreshInterval),
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
        Text(label, style: const TextStyle(color: C.textPrimary, fontSize: 13)),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: C.glassWhite,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: C.glassBorder),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: options.contains(currentValue) ? currentValue : options.first,
              items: options
                  .map(
                    (o) => DropdownMenuItem(
                      value: o,
                      child: Text(o, style: const TextStyle(color: C.textPrimary, fontSize: 12)),
                    ),
                  )
                  .toList(),
              onChanged: onChanged,
              dropdownColor: C.bgCard,
              isDense: true,
              icon: const Icon(Icons.expand_more_rounded, color: C.textMuted, size: 16),
            ),
          ),
        ),
      ],
    );
  }

  // ───────────────────────────
  // About
  // ───────────────────────────

  Widget _aboutSection() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('About', Icons.info_rounded),
            const SizedBox(height: 14),
            _menuItem(Icons.verified_rounded, 'Kaapav Ad Engine', C.primary, () {}),
            _menuItem(Icons.hub_rounded, 'Worker-first ROAS Intelligence', C.blue, () {}),
            _menuItem(Icons.policy_rounded, 'Privacy & Terms (Coming soon)', C.textSecondary, () {
              _snack('Add Privacy/Terms links when ready', ok: true);
            }),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────
  // Maintenance / Danger zone
  // ───────────────────────────

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
                  'Maintenance',
                  style: TextStyle(
                    color: C.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _menuItem(
              Icons.cached_rounded,
              'Clear App Cache (UI)',
              C.warning,
              () => _showConfirm(
                'Clear Cache',
                'This clears image cache and refreshes providers. Worker data remains unchanged.',
                () {
                  PaintingBinding.instance.imageCache.clear();
                  PaintingBinding.instance.imageCache.clearLiveImages();

                  ref.invalidate(campaignsProvider);
                  ref.invalidate(leadsProvider);
                  ref.invalidate(rulesProvider);
                  ref.invalidate(activityLogProvider);
                  ref.invalidate(connectionStatusProvider);
                  ref.invalidate(intelligenceSummaryProvider);

                  _snack('✅ Cache cleared');
                },
              ),
            ),
            _menuItem(
              Icons.restart_alt_rounded,
              'Reset All Settings',
              C.error,
              () => _showConfirm(
                'Reset Settings',
                'This resets settings to defaults.',
                () {
                  ref.read(settingsProvider.notifier).reset();
                  _snack('✅ Settings reset');
                },
              ),
            ),
            _menuItem(
              Icons.logout_rounded,
              'Disconnect & Logout',
              C.error,
              () => _showConfirm(
                'Disconnect & Logout',
                'This removes saved keys/tokens. You will need to reconnect.',
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

  // ───────────────────────────
  // Diagnostics (new, real)
  // ───────────────────────────

  Future<void> _openDiagnostics() async {
    final conn = ref.read(connectionStatusProvider).valueOrNull;
    final intel = ref.read(intelligenceSummaryProvider).valueOrNull;
    final unread = ref.read(notificationsCountProvider).valueOrNull ?? 0;

    final diag = <String, dynamic>{
      'workerBaseUrl': EnvConfig.workerBaseUrl,
      'unreadAlerts': unread,
      'lastOpsActionAt': _lastOpsActionAt?.toIso8601String(),
      'connectionStatus': conn,
      'intelligenceSummary': intel == null
          ? null
          : {
              'avgAudienceScore': intel.avgAudienceScore,
              'avgCreativeMatchScore': intel.avgCreativeMatchScore,
              'topBuyerCount': intel.topBuyerCount,
              'fatigueAlerts': intel.fatigueAlerts,
              'openRecommendations': intel.openRecommendations,
              'lastComputedAt': intel.lastComputedAt?.toIso8601String(),
            },
    };

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: GlassCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    Icon(Icons.bug_report_rounded, color: C.textPrimary, size: 18),
                    SizedBox(width: 10),
                    Text(
                      'Diagnostics',
                      style: TextStyle(color: C.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _diagBtn(
                  icon: Icons.copy_rounded,
                  label: 'Copy diagnostics JSON',
                  color: C.primary,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: const JsonEncoder.withIndent('  ').convert(diag)));
                    if (!mounted) return;
                    Navigator.pop(context);
                    _snack('✅ Copied diagnostics');
                  },
                ),
                const SizedBox(height: 10),
                _diagBtn(
                  icon: Icons.timer_rounded,
                  label: 'Latency test (GET /health)',
                  color: C.success,
                  onTap: () async {
                    final r = await _callWorker(method: 'GET', path: '/health', requiresAuth: false);
                    if (!mounted) return;
                    Navigator.pop(context);
                    _snack(r.ok ? '✅ ${r.ms}ms (healthy)' : '❌ ${r.message}', ok: r.ok);
                  },
                ),
                const SizedBox(height: 10),
                _diagBtn(
                  icon: Icons.visibility_rounded,
                  label: 'View raw connection JSON',
                  color: C.blue,
                  onTap: () {
                    Navigator.pop(context);
                    _showJsonSheet('Connection Status (raw)', conn);
                  },
                ),
                const SizedBox(height: 14),
                OutlineBtn(
                  label: 'Close',
                  icon: Icons.check_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _diagBtn({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GlassCard(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: C.textPrimary, fontSize: 12, fontWeight: FontWeight.w800),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: C.textMuted, size: 18),
        ],
      ),
    );
  }

  void _showJsonSheet(String title, dynamic jsonData) {
    final pretty = const JsonEncoder.withIndent('  ').convert(jsonData ?? {'info': 'null'});
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          top: false,
          child: GlassCard(
            radius: 22,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 42, height: 4, decoration: BoxDecoration(color: C.glassBorder, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(color: C.textPrimary, fontWeight: FontWeight.w900, fontSize: 14),
                      ),
                    ),
                    GlassIconBtn(
                      icon: Icons.copy_rounded,
                      badge: false,
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: pretty));
                        _snack('✅ Copied');
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.55),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: C.bgCard,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: C.glassBorder),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      pretty,
                      style: const TextStyle(
                        color: C.textSecondary,
                        fontSize: 11,
                        height: 1.25,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                OutlineBtn(label: 'Close', icon: Icons.check_rounded, onTap: () => Navigator.pop(context)),
              ],
            ),
          ),
        );
      },
    );
  }

  // ───────────────────────────
  // UI helpers
  // ───────────────────────────

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
            fontWeight: FontWeight.w900,
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
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(color: C.textMuted, fontSize: 11)),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: (v) {
              HapticFeedback.selectionClick();
              onChanged(v);
            },
            activeTrackColor: C.primary,
            inactiveThumbColor: C.textMuted,
            inactiveTrackColor: C.bgLight,
          ),
        ],
      ),
    );
  }

  Widget _menuItem(IconData icon, String title, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        onTap();
      },
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color.withValues(alpha: 0.18)),
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
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: C.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  void _showConfirm(String title, String message, VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: C.textPrimary)),
        content: Text(message, style: const TextStyle(color: C.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              onConfirm();
            },
            child: const Text('Confirm', style: TextStyle(color: C.error)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────
// Small view-model
// ───────────────────────────

class _ConnVM {
  final bool connected;
  final String mode;

  final bool workerOnline;
  final bool workerReady;

  final bool hasApiKey;
  final bool hasSessionToken;
  final bool hasMetaAuth;

  final String? accountId;
  final String? pixelId;

  const _ConnVM({
    required this.connected,
    required this.mode,
    required this.workerOnline,
    required this.workerReady,
    required this.hasApiKey,
    required this.hasSessionToken,
    required this.hasMetaAuth,
    required this.accountId,
    required this.pixelId,
  });

  static _ConnVM fromMap(Map<String, dynamic> m) {
    return _ConnVM(
      connected: m['connected'] == true,
      mode: (m['mode']?.toString() ?? 'none').toLowerCase(),
      workerOnline: m['workerOnline'] == true,
      workerReady: m['workerReady'] == true,
      hasApiKey: m['hasApiKey'] == true,
      hasSessionToken: m['hasSessionToken'] == true,
      hasMetaAuth: m['hasMetaAuth'] == true,
      accountId: m['accountId']?.toString(),
      pixelId: m['pixelId']?.toString(),
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
          Icon(Icons.workspace_premium_rounded, color: Colors.black, size: 12),
          SizedBox(width: 4),
          Text(
            'Pro Ops • Active',
            style: TextStyle(
              color: Colors.black,
              fontSize: 10,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CallResult {
  final bool ok;
  final int ms;
  final String message;
  final dynamic data;

  const _CallResult({
    required this.ok,
    required this.ms,
    required this.message,
    required this.data,
  });
}