import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../core/env_config.dart';
import '../services/meta_auth.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

// Optional FCM registration (kept because your existing file already uses it)
import '../services/fcm_service.dart';
import '../services/local_storage.dart';

class ConnectMetaScreen extends StatefulWidget {
  const ConnectMetaScreen({super.key});

  @override
  State<ConnectMetaScreen> createState() => _ConnectMetaScreenState();
}

class _ConnectMetaScreenState extends State<ConnectMetaScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  late final AnimationController _successC;

  final _workerApiKeyCtrl = TextEditingController();

  bool _loading = false;
  bool _connected = false;

  bool _workerOnline = false;
  bool _checkingWorker = true;

  String? _errorMessage;
  _ConnectionResult? _connectionResult;

  final _auth = MetaAuth();
  final _dio = Dio();

  @override
  void initState() {
    super.initState();

    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);

    _successC = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _hydrateFromStorage();
    _checkWorkerStatus();
    _autoLoginIfPossible();
  }

  @override
  void dispose() {
    _bgC.dispose();
    _successC.dispose();
    _workerApiKeyCtrl.dispose();
    _dio.close(force: true);
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Helpers (no raw JSON to UI)
  // ─────────────────────────────────────────────

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      try {
        return Map<String, dynamic>.from(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String _extractErrorMessage(
    dynamic value, {
    String fallback = 'Something went wrong',
  }) {
    if (value == null) return fallback;

    if (value is String) {
      final text = value.trim();
      return text.isNotEmpty ? text : fallback;
    }

    final map = _asMap(value);
    if (map == null) return fallback;

    final error = map['error'];
    if (error is String && error.trim().isNotEmpty) {
      return error;
    }

    final errorMap = _asMap(error);
    final errorMsg = errorMap?['message']?.toString();
    if (errorMsg != null && errorMsg.trim().isNotEmpty) {
      return errorMsg;
    }

    final message = map['message']?.toString();
    if (message != null && message.trim().isNotEmpty) {
      return message;
    }

    return fallback;
  }

  Future<void> _hydrateFromStorage() async {
    try {
      final apiKey = await _auth.getApiKey();
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        _workerApiKeyCtrl.text = apiKey.trim();
      }
    } catch (_) {}
  }

  Future<void> _checkWorkerStatus() async {
    if (!mounted) return;
    setState(() => _checkingWorker = true);

    try {
      final response = await _dio.get(
        EnvConfig.healthUrl,
        options: Options(
          validateStatus: (status) => status != null && status < 500,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );

      final status = response.statusCode ?? 0;
      final ok = status >= 200 && status < 300;

      if (!mounted) return;
      setState(() {
        _workerOnline = ok;
        _checkingWorker = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _workerOnline = false;
        _checkingWorker = false;
      });
    }
  }

  Future<void> _registerFcmIfPossible() async {
    // Kept exactly in the style of your current code:
    try {
      final fcmToken = LocalStorageService.getSetting<String>('fcm_token');
      if (fcmToken == null || fcmToken.trim().isEmpty) return;
      await FCMService().registerDevice(fcmToken.trim());
    } catch (e) {
      debugPrint('⚠️ FCM registration skipped: $e');
    }
  }

  /// If API key exists, silently verify by calling /auth/login to refresh session.
  Future<void> _autoLoginIfPossible() async {
    try {
      final apiKey = await _auth.getApiKey();
      if (apiKey == null || apiKey.trim().isEmpty) return;

      final ok = await _verifyWorkerConnection(apiKey.trim());
      if (!ok || !mounted) return;

      // Mark onboarded and go to dashboard
      await _auth.setOnboarded();
      if (!mounted) return;
      context.go('/dashboard');
    } catch (_) {
      // no UI needed; user can connect manually
    }
  }

  Future<bool> _verifyWorkerConnection(String apiKey) async {
    try {
      final response = await _dio.post(
        EnvConfig.authLoginUrl,
        data: {'api_key': apiKey},
        options: Options(validateStatus: (s) => s != null && s < 500),
      );

      final map = _asMap(response.data);
      if (map == null || map['success'] != true) return false;

      final dataMap = _asMap(map['data']);
      final sessionToken = dataMap?['token']?.toString();
      if (sessionToken == null || sessionToken.trim().isEmpty) return false;

      await _auth.saveSessionToken(sessionToken.trim());
      return true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // Connect
  // ─────────────────────────────────────────────

  Future<void> _connect() async {
    HapticFeedback.mediumImpact();

    if (!mounted) return;
    setState(() {
      _loading = true;
      _errorMessage = null;
      _connectionResult = null;
    });

    try {
      await _connectViaWorker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      HapticFeedback.heavyImpact();
    }
  }

  Future<void> _connectViaWorker() async {
    final apiKey = _workerApiKeyCtrl.text.trim();
    if (apiKey.isEmpty) {
      throw Exception('Please enter API Secret Key');
    }

    try {
      final authResponse = await _dio.post(
        EnvConfig.authLoginUrl,
        data: {'api_key': apiKey},
        options: Options(validateStatus: (status) => status != null && status < 500),
      );

      final map = _asMap(authResponse.data);
      if (map == null) {
        throw Exception(
          _extractErrorMessage(
            authResponse.data,
            fallback: 'Invalid response format from Worker',
          ),
        );
      }

      if (map['success'] != true) {
        throw Exception(_extractErrorMessage(map, fallback: 'Invalid API Key'));
      }

      final dataMap = _asMap(map['data']);
      final sessionToken = dataMap?['token']?.toString();

      if (sessionToken == null || sessionToken.trim().isEmpty) {
        throw Exception('Worker did not return a valid session token');
      }

      // Save Worker auth
      await _auth.saveApiKey(apiKey);
      await _auth.saveSessionToken(sessionToken.trim());
      await _auth.setOnboarded();

      // Optional: clear legacy direct meta fields to enforce Worker-first
      // (uses your MetaAuth API; safe even if empty)
      try {
        await _auth.saveToken('');
        await _auth.saveAccountId('');
        await _auth.savePixelId('');
      } catch (_) {}

      await _registerFcmIfPossible();

      if (!mounted) return;

      setState(() {
        _connected = true;
        _loading = false;
        _connectionResult = _ConnectionResult(workerUrl: EnvConfig.workerBaseUrl);
      });

      _successC.forward();
      HapticFeedback.heavyImpact();

      await Future.delayed(const Duration(milliseconds: 900));
      if (!mounted) return;

      context.go('/dashboard');
    } on DioException catch (e) {
      final responseMessage = _extractErrorMessage(
        e.response?.data,
        fallback: e.message ?? 'Network error',
      );

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Worker connection timeout');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot reach Worker');
      } else {
        throw Exception(responseMessage);
      }
    }
  }

  bool _canConnect() {
    if (_connected) return true;
    return _workerApiKeyCtrl.text.trim().isNotEmpty && !_loading;
  }

  // ─────────────────────────────────────────────
  // UI
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
                    0.2 - _bgC.value * 0.4,
                    -0.5 + _bgC.value * 0.3,
                  ),
                  radius: 1.5,
                  colors: [
                    C.primary.withValues(alpha: 0.08),
                    C.primary.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),
          SafeArea(
            child: _checkingWorker
                ? _buildCheckingWorker()
                : SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        _buildHeader(),
                        const SizedBox(height: 24),

                        if (!_workerOnline) _buildWorkerOfflineBanner(),
                        if (_errorMessage != null) _buildErrorBanner(),
                        if (_connected && _connectionResult != null) _buildSuccessBanner(),

                        if (!_connected) ...[
                          _buildWorkerForm(),
                          const SizedBox(height: 24),
                        ],

                        PrimaryBtn(
                          label: _connected ? 'Open Dashboard' : 'Connect & Launch',
                          icon: _connected ? Icons.dashboard_rounded : Icons.link_rounded,
                          loading: _loading,
                          onTap: _canConnect()
                              ? (_connected ? () => context.go('/dashboard') : _connect)
                              : null,
                        ),

                        const SizedBox(height: 20),
                        _buildHelpSection(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckingWorker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: AlwaysStoppedAnimation<Color>(C.primary),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Checking Worker status...',
            style: TextStyle(color: C.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          OutlineBtn(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            onTap: _checkWorkerStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Center(
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              gradient: C.primaryGrad,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: C.primary.withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(Icons.cloud_rounded, color: Colors.white, size: 40),
          ),
          const SizedBox(height: 20),
          const Text(
            'Connect to Kaapav Ad Engine',
            style: TextStyle(
              color: C.textPrimary,
              fontSize: 24,
              fontWeight: FontWeight.w700,
              height: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Worker-first secure authentication (Meta tokens stay on server)',
            style: TextStyle(color: C.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildWorkerOfflineBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.warning.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.warning.withValues(alpha: 0.30)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: C.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Worker appears offline:\n${EnvConfig.workerBaseUrl}',
              style: const TextStyle(color: C.textSecondary, fontSize: 11),
            ),
          ),
          OutlineBtn(
            label: 'Retry',
            icon: Icons.refresh_rounded,
            color: C.warning,
            onTap: _checkWorkerStatus,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.error.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.error.withValues(alpha: 0.30)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline_rounded, color: C.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: C.textSecondary, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.0).animate(
        CurvedAnimation(parent: _successC, curve: Curves.elasticOut),
      ),
      child: GlassCard(
        margin: const EdgeInsets.only(bottom: 20),
        turquoise: true,
        glow: true,
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    gradient: C.successGrad,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Connected Successfully',
                        style: TextStyle(
                          color: C.success,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Authenticated via Worker',
                        style: TextStyle(color: C.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.glassWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: C.glassBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, color: C.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _connectionResult!.workerUrl,
                      style: const TextStyle(
                        color: C.textPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerForm() {
    return Column(
      children: [
        GlassInput(
          label: 'API Secret Key',
          hint: 'Enter API_SECRET_KEY',
          controller: _workerApiKeyCtrl,
          prefixIcon: Icons.vpn_key_rounded,
          obscure: true,
          onChanged: (_) => setState(() => _errorMessage = null),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: C.glassWhite,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: C.glassBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Worker',
                style: TextStyle(
                  color: C.primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              _configRow('URL', EnvConfig.workerBaseUrl),
              _configRow('Status', _workerOnline ? 'Online ✓' : 'Offline'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _configRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Text(
            '$label:',
            style: const TextStyle(
              color: C.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: C.textSecondary, fontSize: 11),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHelpSection() {
    return GlassCard(
      padding: const EdgeInsets.all(16),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: C.primary, size: 18),
              SizedBox(width: 10),
              Text(
                'How to connect',
                style: TextStyle(
                  color: C.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 12),
          Text(
            '1) Get API_SECRET_KEY from admin\n'
            '2) Enter it here\n'
            '3) Tap Connect\n\n'
            'Meta tokens remain on Worker (secure).',
            style: TextStyle(
              color: C.textSecondary,
              fontSize: 12,
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }
}

class _ConnectionResult {
  final String workerUrl;

  _ConnectionResult({required this.workerUrl});
}