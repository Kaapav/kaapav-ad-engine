//lib/screens/connect_meta_screen.dart
	import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../services/meta_auth.dart';
import '../widgets/glass_card.dart';
import '../widgets/buttons.dart';
import '../widgets/inputs.dart';
import 'main_shell.dart';

class ConnectMetaScreen extends StatefulWidget {
  const ConnectMetaScreen({super.key});
  @override
  State<ConnectMetaScreen> createState() => _ConnectMetaScreenState();
}

class _ConnectMetaScreenState extends State<ConnectMetaScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _bgC;
  final _tokenCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _pixelCtrl = TextEditingController();
  bool _loading = false;
  bool _connected = false;
  final _auth = MetaAuth();

  @override
  void initState() {
    super.initState();
    _bgC = AnimationController(vsync: this, duration: const Duration(seconds: 8))..repeat(reverse: true);
  }

  @override
  void dispose() { _bgC.dispose(); _tokenCtrl.dispose(); _accountCtrl.dispose(); _pixelCtrl.dispose(); super.dispose(); }

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
                  center: Alignment(0.2 - _bgC.value * 0.4, -0.5 + _bgC.value * 0.3),
                  radius: 1.5,
                  colors: [C.facebook.withValues(alpha: 0.06), C.primary.withValues(alpha: 0.03), C.bgDeep],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // HEADER
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 70, height: 70,
                          decoration: BoxDecoration(color: C.facebook.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(22), border: Border.all(color: C.facebook.withValues(alpha: 0.3))),
                          child: const Icon(Icons.facebook_rounded, color: C.facebook, size: 36),
                        ),
                        const SizedBox(height: 16),
                        const Text('Connect Meta', style: TextStyle(color: C.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        const Text('Enter your Meta Business API credentials', style: TextStyle(color: C.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // TOKEN INPUT
                  GlassInput(
                    label: 'Access Token',
                    hint: 'Paste your Meta access token',
                    controller: _tokenCtrl,
                    prefixIcon: Icons.key_rounded,
                    maxLines: 1,
                    obscure: true,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // ACCOUNT ID
                  GlassInput(
                    label: 'Ad Account ID',
                    hint: 'e.g. 123456789',
                    controller: _accountCtrl,
                    prefixIcon: Icons.account_box_rounded,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 14),

                  // PIXEL ID
                  GlassInput(
                    label: 'Pixel ID (Optional)',
                    hint: 'e.g. 987654321',
                    controller: _pixelCtrl,
                    prefixIcon: Icons.data_object_rounded,
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 10),

                  // HELP
                  GlassCard(
                    radius: 14,
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.help_outline_rounded, color: C.primary.withValues(alpha: 0.7), size: 16),
                            const SizedBox(width: 8),
                            const Text('Where to find these?', style: TextStyle(color: C.primary, fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _helpRow('1.', 'Go to Meta Business Suite → Settings'),
                        _helpRow('2.', 'Create a System User token with ads_management permission'),
                        _helpRow('3.', 'Copy Ad Account ID from Ad Account Settings'),
                        _helpRow('4.', 'Find Pixel ID in Events Manager'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SUCCESS
                  if (_connected) ...[
                    GlassCard(
                      radius: 16,
                      turquoise: true,
                      glow: true,
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Container(
                            width: 40, height: 40,
                            decoration: BoxDecoration(gradient: C.successGrad, shape: BoxShape.circle),
                            child: const Icon(Icons.check_rounded, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Connected Successfully! ✨', style: TextStyle(color: C.success, fontSize: 14, fontWeight: FontWeight.w700)),
                                Text('Your Meta account is ready', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // CONNECT BUTTON
                  PrimaryBtn(
                    label: _connected ? 'Launch Dashboard 🚀' : 'Connect & Verify',
                    icon: _connected ? Icons.dashboard_rounded : Icons.link_rounded,
                    loading: _loading,
                    onTap: _tokenCtrl.text.isNotEmpty && _accountCtrl.text.isNotEmpty
                        ? () => _connected ? _goToDashboard() : _connect()
                        : null,
                  ),
                  const SizedBox(height: 14),

                  // SKIP FOR NOW
                  Center(
                    child: GestureDetector(
                      onTap: _goToDashboard,
                      child: const Text('Skip — Use demo data', style: TextStyle(color: C.textMuted, fontSize: 12, decoration: TextDecoration.underline)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _helpRow(String num, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(num, style: TextStyle(color: C.primary.withValues(alpha: 0.6), fontSize: 11, fontWeight: FontWeight.w700)),
          const SizedBox(width: 6),
          Expanded(child: Text(text, style: const TextStyle(color: C.textSecondary, fontSize: 11))),
        ],
      ),
    );
  }

  Future<void> _connect() async {
    setState(() => _loading = true);
    try {
      await _auth.saveToken(_tokenCtrl.text.trim());
      await _auth.saveAccountId(_accountCtrl.text.trim());
      if (_pixelCtrl.text.isNotEmpty) await _auth.savePixelId(_pixelCtrl.text.trim());
      await _auth.setOnboarded();

      // Simulate verification
      await Future.delayed(const Duration(seconds: 2));

      setState(() { _loading = false; _connected = true; });
      HapticFeedback.heavyImpact();
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Connection failed: $e'),
          backgroundColor: C.error,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ));
      }
    }
  }

  void _goToDashboard() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const MainShell(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}