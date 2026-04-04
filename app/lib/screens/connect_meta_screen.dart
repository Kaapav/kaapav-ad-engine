// lib/screens/connect_meta_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:dio/dio.dart';
import '../core/theme.dart';
import '../core/env_config.dart';
import '../services/meta_auth.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';
import 'main_shell.dart';
import '../services/fcm_service.dart';
import '../services/local_storage.dart';

/// 🔥 GOAT Connect Screen — Meta + Worker Dual Auth
/// Supports both Direct Meta mode and Worker proxy mode
/// Auto-detects Worker availability, validates credentials, shows real connection status
class ConnectMetaScreen extends StatefulWidget {
  const ConnectMetaScreen({super.key});
  
  @override
  State<ConnectMetaScreen> createState() => _ConnectMetaScreenState();
}

class _ConnectMetaScreenState extends State<ConnectMetaScreen> 
    with SingleTickerProviderStateMixin {
  
  // ══════════════════════════════════════════════════════════════
  // Controllers & State
  // ══════════════════════════════════════════════════════════════
  
  late final AnimationController _bgC;
  late final AnimationController _successC;
  
  // Connection Mode
  ConnectionMode _mode = ConnectionMode.worker; // Default to Worker
  
  // Worker Mode Controllers
  final _workerApiKeyCtrl = TextEditingController();
  
  // Direct Meta Mode Controllers
  final _metaTokenCtrl = TextEditingController();
  final _metaAccountCtrl = TextEditingController();
  final _metaPixelCtrl = TextEditingController();
  
  // State
  bool _loading = false;
  bool _connected = false;
  bool _workerOnline = false;
  bool _checkingWorker = true;
  String? _errorMessage;
  ConnectionResult? _connectionResult;
  
  final _auth = MetaAuth();
  final _dio = Dio();
  
  // ══════════════════════════════════════════════════════════════
  // Lifecycle
  // ══════════════════════════════════════════════════════════════
  
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
    
    _checkExistingConnection();
    _checkWorkerStatus();
  }
  
  @override
  void dispose() {
    _bgC.dispose();
    _successC.dispose();
    _workerApiKeyCtrl.dispose();
    _metaTokenCtrl.dispose();
    _metaAccountCtrl.dispose();
    _metaPixelCtrl.dispose();
    _dio.close();
    super.dispose();
  }
  
  // ══════════════════════════════════════════════════════════════
  // Initialization Checks
  // ══════════════════════════════════════════════════════════════
  
  /// Check if user already has valid credentials
  Future<void> _checkExistingConnection() async {
    try {
      // Check Worker credentials first
      final hasWorkerKey = await _auth.hasApiKey();
      if (hasWorkerKey) {
        final valid = await _verifyWorkerConnection();
        if (valid && mounted) {
          _navigateToDashboard();
          return;
        }
      }
      
      // Check Meta credentials
      final hasMetaConfig = await _auth.hasValidConfig();
      if (hasMetaConfig && mounted) {
        final token = await _auth.getToken();
        final accountId = await _auth.getAccountId();
        
        if (token != null && accountId != null) {
          setState(() {
            _mode = ConnectionMode.directMeta;
            _metaTokenCtrl.text = token;
            _metaAccountCtrl.text = accountId;
          });
          
          final pixelId = await _auth.getPixelId();
          if (pixelId != null) _metaPixelCtrl.text = pixelId;
        }
      }
    } catch (e) {
      debugPrint('Check existing connection error: $e');
    }
  }
  
  /// Check if Worker is online and reachable
  Future<void> _checkWorkerStatus() async {
    setState(() => _checkingWorker = true);
    
    try {
      final response = await _dio.get(
        EnvConfig.healthUrl,
        options: Options(
          validateStatus: (status) => status! < 500,
          receiveTimeout: const Duration(seconds: 5),
          sendTimeout: const Duration(seconds: 5),
        ),
      );
      
      if (response.data['success'] == true) {
        setState(() {
          _workerOnline = true;
          _checkingWorker = false;
          _mode = ConnectionMode.worker; // Default to Worker if available
        });
      } else {
        _setWorkerOffline();
      }
    } catch (e) {
      _setWorkerOffline();
    }
  }
  
  void _setWorkerOffline() {
    setState(() {
      _workerOnline = false;
      _checkingWorker = false;
      _mode = ConnectionMode.directMeta; // Fall back to Direct Meta
    });
  }
  
  // ══════════════════════════════════════════════════════════════
  // Connection Logic
  // ══════════════════════════════════════════════════════════════
  
  Future<void> _connect() async {
    HapticFeedback.mediumImpact();
    
    setState(() {
      _loading = true;
      _errorMessage = null;
      _connectionResult = null;
    });
    
    try {
      if (_mode == ConnectionMode.worker) {
        await _connectViaWorker();
      } else {
        await _connectDirectMeta();
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
      HapticFeedback.heavyImpact();
    }
  }
  
  /// Worker-based authentication
  Future<void> _connectViaWorker() async {
    final apiKey = _workerApiKeyCtrl.text.trim();
    
    if (apiKey.isEmpty) {
      throw Exception('Please enter API Secret Key');
    }
    
    try {
      // Step 1: Authenticate with Worker
      final authResponse = await _dio.post(
        EnvConfig.authLoginUrl,
        data: {'api_key': apiKey},
        options: Options(
          validateStatus: (status) => status! < 500,
        ),
      );
      
      if (authResponse.data['success'] != true) {
        throw Exception(authResponse.data['error'] ?? 'Invalid API Key');
      }
      
      final sessionToken = authResponse.data['data']['token'];
      
      // Step 2: Test Worker endpoints
      final campaignsResponse = await _dio.get(
        EnvConfig.campaignsUrl,
        queryParameters: {'limit': 1},
        options: Options(
          headers: {'X-API-Key': apiKey},
          validateStatus: (status) => status! < 500,
        ),
      );
      
      if (campaignsResponse.data['success'] != true) {
        throw Exception('Worker API test failed: ${campaignsResponse.data['error']}');
      }
      
      // Step 3: Save credentials
      await _auth.saveApiKey(apiKey);
      await _auth.saveSessionToken(sessionToken);
      await _auth.setOnboarded();
      
      // Step 4: Set success state
      setState(() {
        _connected = true;
        _loading = false;
        _connectionResult = ConnectionResult(
          mode: ConnectionMode.worker,
          workerUrl: EnvConfig.workerBaseUrl,
          metaAccountId: null,
          campaignCount: campaignsResponse.data['meta']?['total'],
        );
      });
      
      _successC.forward();
      HapticFeedback.heavyImpact();
      
      // Auto-navigate after 1.5s
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _navigateToDashboard();
      
    } on DioException catch (e) {
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw Exception('Worker connection timeout. Please check your internet.');
      } else if (e.type == DioExceptionType.connectionError) {
        throw Exception('Cannot reach Worker. Check URL or internet connection.');
      } else {
        throw Exception('Network error: ${e.message}');
      }
    }
  }
  
  /// Direct Meta API authentication
  Future<void> _connectDirectMeta() async {
    final token = _metaTokenCtrl.text.trim();
    final accountId = _metaAccountCtrl.text.trim();
    final pixelId = _metaPixelCtrl.text.trim();
    
    if (token.isEmpty) throw Exception('Please enter Access Token');
    if (accountId.isEmpty) throw Exception('Please enter Ad Account ID');
    
    try {
      // Step 1: Test Meta token validity
      final metaUrl = 'https://graph.facebook.com/v21.0/me?access_token=$token';
      final meResponse = await _dio.get(
        metaUrl,
        options: Options(validateStatus: (status) => status! < 500),
      );
      
      if (meResponse.data['error'] != null) {
        throw Exception('Invalid Meta token: ${meResponse.data['error']['message']}');
      }
      
      // Step 2: Test account access
      final accId = accountId.startsWith('act_') ? accountId : 'act_$accountId';
      final accountUrl = 'https://graph.facebook.com/v21.0/$accId?access_token=$token&fields=name,account_status';
      
      final accountResponse = await _dio.get(
        accountUrl,
        options: Options(validateStatus: (status) => status! < 500),
      );
      
      if (accountResponse.data['error'] != null) {
        throw Exception('Cannot access Ad Account: ${accountResponse.data['error']['message']}');
      }
      
      final accountName = accountResponse.data['name'] ?? 'Unknown';
      final accountStatus = accountResponse.data['account_status'];
      
      if (accountStatus != 1) {
        throw Exception('Ad Account is disabled or restricted');
      }
      
      // Step 3: Optionally test Pixel
      if (pixelId.isNotEmpty) {
        final pixelUrl = 'https://graph.facebook.com/v21.0/$pixelId?access_token=$token&fields=name';
        final pixelResponse = await _dio.get(
          pixelUrl,
          options: Options(validateStatus: (status) => status! < 500),
        );
        
        if (pixelResponse.data['error'] != null) {
          // Don't fail connection if pixel is invalid, just warn
          debugPrint('Pixel validation warning: ${pixelResponse.data['error']['message']}');
        }
      }
      
      // Step 4: Save credentials
      await _auth.saveToken(token);
      await _auth.saveAccountId(accountId);
      if (pixelId.isNotEmpty) await _auth.savePixelId(pixelId);
      await _auth.setOnboarded();
      
      // Step 5: Set success state
      setState(() {
        _connected = true;
        _loading = false;
        _connectionResult = ConnectionResult(
          mode: ConnectionMode.directMeta,
          workerUrl: null,
          metaAccountId: accountId,
          metaAccountName: accountName,
          metaPixelId: pixelId.isNotEmpty ? pixelId : null,
        );
      });
      
      _successC.forward();
      HapticFeedback.heavyImpact();
      
      // Auto-navigate after 1.5s
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) _navigateToDashboard();
      
    } on DioException catch (e) {
      if (e.response?.statusCode == 190) {
        throw Exception('Access token expired. Please generate a new one.');
      } else if (e.response?.statusCode == 403) {
        throw Exception('Permission denied. Check token permissions.');
      } else {
        throw Exception('Meta API error: ${e.message}');
      }
    }
  }
  
  /// Verify existing Worker connection
  Future<bool> _verifyWorkerConnection() async {
    try {
      final apiKey = await _auth.getApiKey();
      if (apiKey == null) return false;
      
      final response = await _dio.post(
        EnvConfig.authLoginUrl,
        data: {'api_key': apiKey},
        options: Options(validateStatus: (status) => status! < 500),
      );
      
      if (response.data['success'] == true) {
        final token = response.data['data']['token'];
        await _auth.saveSessionToken(token);
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
  
  // ══════════════════════════════════════════════════════════════
  // Navigation
  // ══════════════════════════════════════════════════════════════
  
  void _navigateToDashboard() {
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.95, end: 1.0).animate(
                CurvedAnimation(parent: animation, curve: Curves.easeOutCubic),
              ),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }
  
  // ══════════════════════════════════════════════════════════════
  // UI Build
  // ══════════════════════════════════════════════════════════════
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          // Animated Background
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
                    _mode == ConnectionMode.worker
                        ? C.primary.withValues(alpha: 0.08)
                        : C.facebook.withValues(alpha: 0.06),
                    C.primary.withValues(alpha: 0.03),
                    C.bgDeep,
                  ],
                ),
              ),
            ),
          ),
          
          // Content
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
                        
                        // Header
                        _buildHeader(),
                        const SizedBox(height: 32),
                        
                        // Worker Status Banner
                        if (!_workerOnline)
                          _buildWorkerOfflineBanner(),
                        
                        // Connection Mode Toggle
                        if (_workerOnline)
                          _buildModeToggle(),
                        
                        const SizedBox(height: 24),
                        
                        // Error Message
                        if (_errorMessage != null)
                          _buildErrorBanner(),
                        
                        // Success Message
                        if (_connected && _connectionResult != null)
                          _buildSuccessBanner(),
                        
                        // Input Forms
                        if (!_connected) ...[
                          if (_mode == ConnectionMode.worker)
                            _buildWorkerForm()
                          else
                            _buildMetaForm(),
                        ],
                        
                        const SizedBox(height: 24),
                        
                        // Connect Button
                        PrimaryBtn(
                          label: _connected 
                              ? 'Launch Dashboard 🚀' 
                              : (_mode == ConnectionMode.worker 
                                  ? 'Connect to Worker' 
                                  : 'Connect & Verify'),
                          icon: _connected 
                              ? Icons.dashboard_rounded 
                              : Icons.link_rounded,
                          loading: _loading,
                          onTap: _canConnect() 
                              ? (_connected ? _navigateToDashboard : _connect) 
                              : null,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Skip Button
                        if (!_connected)
                          Center(
                            child: TextButton(
                              onPressed: _navigateToDashboard,
                              child: const Text(
                                'Skip — Use demo data',
                                style: TextStyle(
                                  color: C.textMuted,
                                  fontSize: 12,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 32),
                        
                        // Help Section
                        if (!_connected)
                          _buildHelpSection(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  // ══════════════════════════════════════════════════════════════
  // UI Components
  // ══════════════════════════════════════════════════════════════
  
  Widget _buildCheckingWorker() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
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
            style: TextStyle(
              color: C.textSecondary,
              fontSize: 14,
            ),
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
              gradient: _mode == ConnectionMode.worker
                  ? C.primaryGrad
                  : LinearGradient(
                      colors: [C.facebook, C.facebook.withValues(alpha: 0.7)],
                    ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: (_mode == ConnectionMode.worker ? C.primary : C.facebook)
                      .withValues(alpha: 0.3),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(
              _mode == ConnectionMode.worker
                  ? Icons.cloud_rounded
                  : Icons.facebook_rounded,
              color: Colors.white,
              size: 40,
            ),
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
          Text(
            _mode == ConnectionMode.worker
                ? 'Secure server-side authentication'
                : 'Direct Meta Business API connection',
            style: const TextStyle(
              color: C.textSecondary,
              fontSize: 13,
            ),
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
        color: C.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: C.warning, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Worker Offline',
                  style: TextStyle(
                    color: C.warning,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Using Direct Meta mode. Worker unavailable at:\n${EnvConfig.workerBaseUrl}',
                  style: TextStyle(
                    color: C.textSecondary,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeToggle() {
    return GlassCard(
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildModeButton(
              mode: ConnectionMode.worker,
              icon: Icons.cloud_rounded,
              label: 'Worker',
              subtitle: 'Recommended',
              isSelected: _mode == ConnectionMode.worker,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _buildModeButton(
              mode: ConnectionMode.directMeta,
              icon: Icons.facebook_rounded,
              label: 'Direct Meta',
              subtitle: 'Advanced',
              isSelected: _mode == ConnectionMode.directMeta,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildModeButton({
    required ConnectionMode mode,
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
  }) {
    return GestureDetector(
      onTap: () {
        if (!_loading && !_connected) {
          setState(() {
            _mode = mode;
            _errorMessage = null;
          });
          HapticFeedback.selectionClick();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? (mode == ConnectionMode.worker ? C.primaryGrad : C.bgGrad)
              : null,
          color: isSelected ? null : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? (mode == ConnectionMode.worker
                    ? C.primary
                    : C.facebook)
                : C.glassBorder,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? Colors.white : C.textSecondary,
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : C.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              subtitle,
              style: TextStyle(
                color: isSelected
                    ? Colors.white.withValues(alpha: 0.7)
                    : C.textMuted,
                fontSize: 10,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildErrorBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: C.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: C.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline_rounded, color: C.error, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Connection Failed',
                  style: TextStyle(
                    color: C.error,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: C.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
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
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Connected Successfully! ✨',
                        style: TextStyle(
                          color: C.success,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _connectionResult!.mode == ConnectionMode.worker
                            ? 'Authenticated via Worker'
                            : 'Direct Meta API connection',
                        style: const TextStyle(
                          color: C.textSecondary,
                          fontSize: 12,
                        ),
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
              child: Column(
                children: [
                  if (_connectionResult!.mode == ConnectionMode.worker) ...[
                    _buildInfoRow(
                      'Worker URL',
                      _connectionResult!.workerUrl!,
                    ),
                    if (_connectionResult!.campaignCount != null)
                      _buildInfoRow(
                        'Campaigns',
                        '${_connectionResult!.campaignCount}',
                      ),
                  ] else ...[
                    _buildInfoRow(
                      'Account',
                      _connectionResult!.metaAccountName ?? 
                          _connectionResult!.metaAccountId!,
                    ),
                    if (_connectionResult!.metaPixelId != null)
                      _buildInfoRow(
                        'Pixel',
                        _connectionResult!.metaPixelId!,
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: C.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(
                color: C.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWorkerForm() {
    return Column(
      children: [
        GlassInput(
          label: 'API Secret Key',
          hint: 'Enter your Worker API key',
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
              Row(
                children: [
                  Icon(Icons.info_outline_rounded, 
                    color: C.primary, size: 16),
                  const SizedBox(width: 8),
                  const Text(
                    'Worker Configuration',
                    style: TextStyle(
                      color: C.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _buildConfigRow('URL', EnvConfig.workerBaseUrl),
              _buildConfigRow('Status', 
                _workerOnline ? 'Online ✓' : 'Checking...'),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildMetaForm() {
    return Column(
      children: [
        GlassInput(
          label: 'Access Token',
          hint: 'Paste your Meta access token',
          controller: _metaTokenCtrl,
          prefixIcon: Icons.key_rounded,
          obscure: true,
          onChanged: (_) => setState(() => _errorMessage = null),
        ),
        const SizedBox(height: 14),
        GlassInput(
          label: 'Ad Account ID',
          hint: 'e.g. 123456789',
          controller: _metaAccountCtrl,
          prefixIcon: Icons.account_box_rounded,
          keyboardType: TextInputType.number,
          onChanged: (_) => setState(() => _errorMessage = null),
        ),
        const SizedBox(height: 14),
        GlassInput(
          label: 'Pixel ID (Optional)',
          hint: 'e.g. 987654321',
          controller: _metaPixelCtrl,
          prefixIcon: Icons.data_object_rounded,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }
  
  Widget _buildConfigRow(String label, String value) {
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
              style: TextStyle(
                color: C.textSecondary,
                fontSize: 10,
                fontFamily: value.startsWith('http') ? 'monospace' : null,
              ),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.help_outline_rounded, color: C.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                _mode == ConnectionMode.worker
                    ? 'How to get API Key?'
                    : 'Where to find these?',
                style: const TextStyle(
                  color: C.primary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          
          if (_mode == ConnectionMode.worker) ...[
            _buildHelpStep('1', 'Contact your admin',
                'Get the API_SECRET_KEY from system administrator'),
            _buildHelpStep('2', 'Paste it above',
                'Enter the key in the API Secret Key field'),
            _buildHelpStep('3', 'Connect',
                'Tap Connect to Worker button to authenticate'),
          ] else ...[
            _buildHelpStep('1', 'Meta Business Suite',
                'Go to Meta Business Suite → Settings'),
            _buildHelpStep('2', 'System User',
                'Create System User with ads_management permission'),
            _buildHelpStep('3', 'Ad Account',
                'Copy Ad Account ID from Ad Account Settings'),
            _buildHelpStep('4', 'Pixel (Optional)',
                'Find Pixel ID in Events Manager'),
          ],
        ],
      ),
    );
  }
  
  Widget _buildHelpStep(String num, String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(
              gradient: C.primaryGrad,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                num,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: C.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: const TextStyle(
                    color: C.textSecondary,
                    fontSize: 11,
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
  // Validation
  // ══════════════════════════════════════════════════════════════
  
  bool _canConnect() {
    if (_connected) return true;
    
    if (_mode == ConnectionMode.worker) {
      return _workerApiKeyCtrl.text.trim().isNotEmpty;
    } else {
      return _metaTokenCtrl.text.trim().isNotEmpty &&
             _metaAccountCtrl.text.trim().isNotEmpty;
    }
  }
}

// ══════════════════════════════════════════════════════════════
// Data Models
// ══════════════════════════════════════════════════════════════

enum ConnectionMode {
  worker,
  directMeta,
}

class ConnectionResult {
  final ConnectionMode mode;
  final String? workerUrl;
  final String? metaAccountId;
  final String? metaAccountName;
  final String? metaPixelId;
  final int? campaignCount;
  
  ConnectionResult({
    required this.mode,
    this.workerUrl,
    this.metaAccountId,
    this.metaAccountName,
    this.metaPixelId,
    this.campaignCount,
  });
}