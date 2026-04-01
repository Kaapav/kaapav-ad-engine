import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../config/theme.dart';
import '../providers/auth_provider.dart';
import '../widgets/common/animated_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _ctrl = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final token = _ctrl.text.trim();
    if (token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Enter your token'),
        backgroundColor: KaapavColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final ok = await ref.read(authProvider.notifier).login(token);
    if (ok && mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    return Scaffold(
      backgroundColor: KaapavColors.dark950,
      body: AnimatedBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: KaapavColors.dark800.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: KaapavColors.dark700.withOpacity(0.5)),
                  boxShadow: [
                    BoxShadow(color: KaapavColors.kaapav500.withOpacity(0.05), blurRadius: 40, offset: const Offset(0, 20)),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Logo
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [KaapavColors.kaapav500, KaapavColors.kaapav700]),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(color: KaapavColors.kaapav500.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
                        ],
                      ),
                      child: const Icon(LucideIcons.sparkles, color: Colors.white, size: 32),
                    ),
                    const SizedBox(height: 20),
                    const Text('KAAPAV', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: 2)),
                    const SizedBox(height: 4),
                    const Text('Ad Engine Dashboard', style: TextStyle(fontSize: 14, color: KaapavColors.dark400)),
                    const SizedBox(height: 28),

                    // Feature banner
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: KaapavColors.dark800.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: KaapavColors.dark700.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          const Icon(LucideIcons.zap, size: 18, color: KaapavColors.kaapav400),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Meta Ads - ROAS Optimizer - Auto-scaling - Analytics',
                              style: TextStyle(fontSize: 11, color: KaapavColors.dark300),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Token input
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Ad Engine Secret Token', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: KaapavColors.dark300)),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _ctrl,
                          obscureText: !_show,
                          style: const TextStyle(fontSize: 14, color: Colors.white),
                          decoration: InputDecoration(
                            hintText: 'Enter your AD_ENGINE_SECRET',
                            suffixIcon: IconButton(
                              icon: Icon(_show ? LucideIcons.eyeOff : LucideIcons.eye, size: 18, color: KaapavColors.dark400),
                              onPressed: () => setState(() => _show = !_show),
                            ),
                          ),
                          onSubmitted: (_) => _login(),
                        ),
                        const SizedBox(height: 6),
                        const Text('Same token in wrangler.toml secrets', style: TextStyle(fontSize: 11, color: KaapavColors.dark500)),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Error
                    if (auth.error != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: KaapavColors.error.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: KaapavColors.error.withOpacity(0.2)),
                        ),
                        child: Text(auth.error!, style: const TextStyle(fontSize: 13, color: KaapavColors.error)),
                      ),

                    // Login button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: auth.isLoading ? null : _login,
                        child: auth.isLoading
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Enter Dashboard'),
                                  SizedBox(width: 8),
                                  Icon(LucideIcons.arrowRight, size: 18),
                                ],
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('Powered by Cloudflare Workers', style: TextStyle(fontSize: 10, color: KaapavColors.dark600), textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}