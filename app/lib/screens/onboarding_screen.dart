import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import 'connect_meta_screen.dart';
import '../widgets/buttons.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  final _pages = const [
    _OnboardingPage(
      icon: Icons.auto_awesome,
      gradient: C.primaryGrad,
      title: 'AI-Powered\nAd Management',
      subtitle: 'Manage all your Meta ad campaigns from one beautiful dashboard. Get real-time ROAS, CPA, and revenue insights.',
      feature1: 'Real-time campaign monitoring',
      feature2: 'Smart budget optimization',
      feature3: 'AI-driven insights & recommendations',
    ),
    _OnboardingPage(
      icon: Icons.people_alt_rounded,
      gradient: LinearGradient(colors: [C.purple, C.blue]),
      title: 'Smart CRM\nPipeline',
      subtitle: 'Track every lead from first click to conversion. WhatsApp integration, automated follow-ups, pipeline management.',
      feature1: 'Kanban pipeline view',
      feature2: 'WhatsApp follow-up automation',
      feature3: 'Lead scoring & conversion tracking',
    ),
    _OnboardingPage(
      icon: Icons.bolt_rounded,
      gradient: LinearGradient(colors: [C.gold, Color(0xFFFF6B35)]),
      title: 'AutoPilot\nRules Engine',
      subtitle: 'Set intelligent rules to automatically scale winners, pause losers, and optimize budgets while you sleep.',
      feature1: 'Auto-scale high ROAS campaigns',
      feature2: 'Kill underperforming ads instantly',
      feature3: 'Budget & frequency guardrails',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      body: Stack(
        children: [
          // ANIMATED GRADIENT BACKGROUND
          AnimatedContainer(
            duration: const Duration(milliseconds: 500),
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: const Alignment(0, -0.3),
                radius: 1.5,
                colors: [
                  _page == 0
                      ? C.primary.withValues(alpha: 0.08)
                      : _page == 1
                          ? C.purple.withValues(alpha: 0.08)
                          : C.gold.withValues(alpha: 0.08),
                  C.bgDeep,
                ],
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // SKIP
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(9)),
                            child: const Icon(Icons.auto_awesome, color: Colors.black, size: 16),
                          ),
                          const SizedBox(width: 8),
                          const Text('Kaapav', style: TextStyle(color: C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                        ],
                      ),
                      if (_page < 2)
                        GestureDetector(
                          onTap: () => _goToConnect(),
                          child: const Text('Skip', style: TextStyle(color: C.textMuted, fontSize: 13)),
                        ),
                    ],
                  ),
                ),

                // PAGES
                Expanded(
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: _pages.length,
                    onPageChanged: (i) => setState(() => _page = i),
                    itemBuilder: (_, i) => _buildPage(_pages[i]),
                  ),
                ),

                // DOTS + BUTTON
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  child: Column(
                    children: [
                      // DOTS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(3, (i) {
                          final active = i == _page;
                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            width: active ? 28 : 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              gradient: active ? C.primaryGrad : null,
                              color: active ? null : C.glassBorder,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          );
                        }),
                      ),
                      const SizedBox(height: 24),
                      PrimaryBtn(
                        label: _page == 2 ? 'Get Started 🚀' : 'Continue',
                        icon: _page == 2 ? Icons.arrow_forward_rounded : null,
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (_page < 2) {
                            _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                          } else {
                            _goToConnect();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPage(_OnboardingPage page) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // ICON
          Container(
            width: 90, height: 90,
            decoration: BoxDecoration(
              gradient: page.gradient,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: (page.gradient as LinearGradient).colors.first.withValues(alpha: 0.4), blurRadius: 30, spreadRadius: 4)],
            ),
            child: Icon(page.icon, color: Colors.black, size: 44),
          ),
          const SizedBox(height: 36),

          // TITLE
          Text(page.title, style: const TextStyle(color: C.textPrimary, fontSize: 28, fontWeight: FontWeight.w700, height: 1.2, letterSpacing: -0.5), textAlign: TextAlign.center),
          const SizedBox(height: 14),

          // SUBTITLE
          Text(page.subtitle, style: const TextStyle(color: C.textSecondary, fontSize: 14, height: 1.5), textAlign: TextAlign.center),
          const SizedBox(height: 28),

          // FEATURES
          _featureRow(page.feature1),
          const SizedBox(height: 10),
          _featureRow(page.feature2),
          const SizedBox(height: 10),
          _featureRow(page.feature3),
        ],
      ),
    );
  }

  Widget _featureRow(String text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 20, height: 20,
          decoration: BoxDecoration(gradient: C.primaryGrad, shape: BoxShape.circle),
          child: const Icon(Icons.check_rounded, color: Colors.black, size: 12),
        ),
        const SizedBox(width: 10),
        Text(text, style: const TextStyle(color: C.textPrimary, fontSize: 13, fontWeight: FontWeight.w500)),
      ],
    );
  }

  void _goToConnect() {
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const ConnectMetaScreen(),
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}

class _OnboardingPage {
  final IconData icon;
  final Gradient gradient;
  final String title;
  final String subtitle;
  final String feature1;
  final String feature2;
  final String feature3;

  const _OnboardingPage({
    required this.icon,
    required this.gradient,
    required this.title,
    required this.subtitle,
    required this.feature1,
    required this.feature2,
    required this.feature3,
  });
}