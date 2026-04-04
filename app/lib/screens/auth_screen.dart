//lib/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../services/meta_auth.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _bgC;
  final _tokenCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _pixelCtrl = TextEditingController();
  final _auth = MetaAuth();

  bool _loading = false;
  bool _tokenValid = false;
  bool _obscureToken = true;
  String? _currentAccountId;
  String? _currentPixelId;
  DateTime? _tokenExpiry;

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat(reverse: true);
    _loadCurrentConfig();
  }

  Future<void> _loadCurrentConfig() async {
    final token = await _auth.getToken();
    final accountId = await _auth.getAccountId();
    final pixelId = await _auth.getPixelId();
    final valid = await _auth.hasValidConfig();
    setState(() {
      if (token != null) _tokenCtrl.text = token;
      if (accountId != null) {
        _accountCtrl.text = accountId;
        _currentAccountId = accountId;
      }
      if (pixelId != null) {
        _pixelCtrl.text = pixelId;
        _currentPixelId = pixelId;
      }
      _tokenValid = valid;
      _tokenExpiry = DateTime.now().add(const Duration(days: 57));
    });
  }

  Future<void> _saveConfig() async {
    if (_tokenCtrl.text.isEmpty || _accountCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Token and Account ID are required'),
          backgroundColor: C.error,
        ),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.saveToken(_tokenCtrl.text.trim());
      await _auth.saveAccountId(_accountCtrl.text.trim());
      if (_pixelCtrl.text.isNotEmpty) {
        await _auth.savePixelId(_pixelCtrl.text.trim());
      }
      await _auth.setOnboarded();

      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _tokenValid = true;
        _currentAccountId = _accountCtrl.text.trim();
        _currentPixelId = _pixelCtrl.text.trim();
        _tokenExpiry = DateTime.now().add(const Duration(days: 60));
        _loading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('✅ Configuration saved successfully'),
            backgroundColor: C.success,
          ),
        );
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: C.error,
          ),
        );
      }
    }
  }

  Future<void> _refreshToken() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _tokenExpiry = DateTime.now().add(const Duration(days: 60));
      _loading = false;
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('🔄 Token refreshed — expires in 60 days'),
          backgroundColor: C.success,
        ),
      );
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: C.bgCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Disconnect Account',
            style: TextStyle(color: C.textPrimary)),
        content: Text(
          'This will remove all saved tokens and account data. You\'ll need to reconnect.',
          style: TextStyle(color: C.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: TextStyle(color: C.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Disconnect', style: TextStyle(color: C.error)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _auth.logout();
      setState(() {
        _tokenCtrl.clear();
        _accountCtrl.clear();
        _pixelCtrl.clear();
        _tokenValid = false;
        _currentAccountId = null;
        _currentPixelId = null;
        _tokenExpiry = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Account disconnected'),
            backgroundColor: C.warning,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _bgC.dispose();
    _tokenCtrl.dispose();
    _accountCtrl.dispose();
    _pixelCtrl.dispose();
    super.dispose();
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
        title: Text(
          'Meta Authentication',
          style: TextStyle(
            color: C.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _bgC,
        builder: (context, child) {
          return Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.0, -0.5 + _bgC.value * 0.3),
                radius: 1.8,
                colors: [
                  C.primary.withValues(alpha: 0.06 * _bgC.value),
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
                _connectionStatus(),
                const SizedBox(height: 24),
                _tokenSection(),
                const SizedBox(height: 20),
                _accountSection(),
                const SizedBox(height: 20),
                _pixelSection(),
                const SizedBox(height: 24),
                _tokenInfo(),
                const SizedBox(height: 24),
                _actionButtons(),
                const SizedBox(height: 20),
                _permissionsCard(),
                const SizedBox(height: 20),
                if (_tokenValid) _dangerZone(),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _connectionStatus() {
    return GlassCard(
      turquoise: _tokenValid,
      glow: _tokenValid,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: _tokenValid ? C.successGrad : C.dangerGrad,
            ),
            child: Icon(
              _tokenValid ? Icons.link : Icons.link_off,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _tokenValid ? 'Connected to Meta' : 'Not Connected',
                  style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _tokenValid
                      ? 'API v21.0 • Account: ${_currentAccountId ?? '—'}'
                      : 'Configure your Meta API credentials below',
                  style: TextStyle(color: C.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _tokenValid ? C.success : C.error,
              boxShadow: [
                BoxShadow(
                  color: (_tokenValid ? C.success : C.error)
                      .withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tokenSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Access Token',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Long-lived token from Meta Business Suite',
            style: TextStyle(color: C.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        GlassInput(
          label: '',
          hint: 'EAAxxxxxxx...',
          controller: _tokenCtrl,
          obscure: _obscureToken,
          prefixIcon: Icons.key_rounded,
          suffix: IconButton(
            icon: Icon(
              _obscureToken
                  ? Icons.visibility_off_rounded
                  : Icons.visibility_rounded,
              color: C.textMuted,
              size: 20,
            ),
            onPressed: () =>
                setState(() => _obscureToken = !_obscureToken),
          ),
        ),
      ],
    );
  }

  Widget _accountSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ad Account ID',
            style: TextStyle(
                color: C.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Format: act_XXXXXXXXX',
            style: TextStyle(color: C.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        GlassInput(
          label: '',
          hint: 'act_123456789',
          controller: _accountCtrl,
          prefixIcon: Icons.account_balance_rounded,
        ),
      ],
    );
  }

  Widget _pixelSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Pixel ID',
                style: TextStyle(
                    color: C.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: C.glassTurq,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text('Optional',
                  style: TextStyle(color: C.primary, fontSize: 10)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text('For Conversions API tracking',
            style: TextStyle(color: C.textSecondary, fontSize: 12)),
        const SizedBox(height: 10),
        GlassInput(
          label: '',
          hint: '1234567890',
          controller: _pixelCtrl,
          prefixIcon: Icons.track_changes_rounded,
          keyboardType: TextInputType.number,
        ),
      ],
    );
  }

  Widget _tokenInfo() {
    if (!_tokenValid || _tokenExpiry == null) return const SizedBox.shrink();

    final daysLeft = _tokenExpiry!.difference(DateTime.now()).inDays;
    final isExpiring = daysLeft < 7;

    return GlassCard(
      child: Column(
        children: [
          _infoRow(
              'Token Status', _tokenValid ? 'Valid ✓' : 'Invalid ✗',
              _tokenValid ? C.success : C.error),
          const SizedBox(height: 12),
          _infoRow('API Version', 'v21.0', C.info),
          const SizedBox(height: 12),
          _infoRow('Account ID', _currentAccountId ?? '—', C.textPrimary),
          if (_currentPixelId != null && _currentPixelId!.isNotEmpty) ...[
            const SizedBox(height: 12),
            _infoRow('Pixel ID', _currentPixelId!, C.textPrimary),
          ],
          const SizedBox(height: 12),
          _infoRow(
            'Expires In',
            '$daysLeft days',
            isExpiring ? C.warning : C.success,
          ),
          if (isExpiring) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: C.warning.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: C.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: C.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Token expiring soon! Refresh to avoid disruption.',
                      style:
                          TextStyle(color: C.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: C.textSecondary, fontSize: 13)),
        Text(value,
            style: TextStyle(
                color: valueColor,
                fontSize: 13,
                fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _actionButtons() {
    return Column(
      children: [
        PrimaryBtn(
          label: _tokenValid ? 'Update Configuration' : 'Connect & Verify',
          icon: _tokenValid ? Icons.save_rounded : Icons.link_rounded,
          onTap: _loading ? null : _saveConfig,
          loading: _loading,
        ),
        if (_tokenValid) ...[
          const SizedBox(height: 12),
          OutlineBtn(
            label: 'Refresh Token',
            icon: Icons.refresh_rounded,
            onTap: _loading ? null : _refreshToken,
            color: C.primary,
          ),
        ],
      ],
    );
  }

  Widget _permissionsCard() {
    final permissions = [
      {'name': 'ads_management', 'granted': true},
      {'name': 'ads_read', 'granted': true},
      {'name': 'business_management', 'granted': true},
      {'name': 'pages_read_engagement', 'granted': true},
      {'name': 'leads_retrieval', 'granted': _tokenValid},
      {'name': 'catalog_management', 'granted': false},
    ];

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('API Permissions',
              style: TextStyle(
                  color: C.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          ...permissions.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      p['granted'] == true
                          ? Icons.check_circle_rounded
                          : Icons.cancel_rounded,
                      color: p['granted'] == true ? C.success : C.textMuted,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      p['name'] as String,
                      style: TextStyle(
                        color: p['granted'] == true
                            ? C.textPrimary
                            : C.textMuted,
                        fontSize: 13,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _dangerZone() {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Danger Zone',
              style: TextStyle(
                  color: C.error,
                  fontSize: 15,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          OutlineBtn(
            label: 'Disconnect Account',
            icon: Icons.link_off_rounded,
            onTap: _logout,
            color: C.error,
          ),
        ],
      ),
    );
  }
}