import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/onboarding_screen.dart';
import '../screens/connect_meta_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/campaigns_screen.dart';
import '../screens/campaign_detail_screen.dart';
import '../screens/create_campaign_screen.dart';
import '../screens/crm_screen.dart';
import '../screens/lead_detail_screen.dart';
import '../screens/autopilot_screen.dart';
import '../screens/more_screen.dart';
import '../screens/analytics_screen.dart';
import '../screens/notifications_screen.dart';
import '../models/campaign.dart';
import '../models/lead.dart';

class AppRouter {
  static final _rootKey = GlobalKey<NavigatorState>();

  static final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: '/splash',
    routes: [
      // ═══ STANDALONE ROUTES ═══
      GoRoute(
        path: '/splash',
        builder: (_, __) => const SplashScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/connect',
        builder: (_, __) => const ConnectMetaScreen(),
      ),

      // ═══ MAIN SHELL (5 tabs) ═══
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShellGo(shell: navigationShell);
        },
        branches: [
          // Tab 0: Dashboard
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/dashboard',
              builder: (_, __) => const DashboardScreen(),
            ),
          ]),
          // Tab 1: Campaigns
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/campaigns',
              builder: (_, __) => const CampaignsScreen(),
              routes: [
                GoRoute(
                  path: 'create',
                  builder: (_, __) => const CreateCampaignScreen(),
                ),
              ],
            ),
          ]),
          // Tab 2: CRM
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/crm',
              builder: (_, __) => const CrmScreen(),
            ),
          ]),
          // Tab 3: AutoPilot
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/autopilot',
              builder: (_, __) => const AutoPilotScreen(),
            ),
          ]),
          // Tab 4: More
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/more',
              builder: (_, __) => const MoreScreen(),
              routes: [
                GoRoute(
                  path: 'analytics',
                  builder: (_, __) => const AnalyticsScreen(),
                ),
                GoRoute(
                  path: 'notifications',
                  builder: (_, __) => const NotificationsScreen(),
                ),
              ],
            ),
          ]),
        ],
      ),

      // ═══ DETAIL ROUTES (full screen) ═══
      GoRoute(
        path: '/campaign-detail',
        builder: (_, state) {
          final campaign = state.extra as Campaign;
          return CampaignDetailScreen(campaign: campaign);
        },
      ),
      GoRoute(
        path: '/lead-detail',
        builder: (_, state) {
          final lead = state.extra as Lead;
          return LeadDetailScreen(lead: lead);
        },
      ),
    ],
  );
}

// ═══ SHELL WRAPPER FOR GO_ROUTER ═══
class MainShellGo extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MainShellGo({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF020B14),
      extendBody: true,
      body: shell,
      bottomNavigationBar: _GlassNavGo(
        currentIndex: shell.currentIndex,
        onTap: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}

class _GlassNavGo extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  const _GlassNavGo({required this.currentIndex, required this.onTap});

  static const _items = [
    (Icons.grid_view_rounded, 'Dashboard'),
    (Icons.campaign_rounded, 'Campaigns'),
    (Icons.people_alt_rounded, 'CRM'),
    (Icons.auto_awesome_rounded, 'AutoPilot'),
    (Icons.menu_rounded, 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            height: 68,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  const Color(0xFF00E5CC).withValues(alpha: 0.1),
                  const Color(0xFF00E5CC).withValues(alpha: 0.03),
                ],
              ),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: const Color(0xFF00E5CC).withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(_items.length, (i) {
                final active = i == currentIndex;
                return GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(_items[i].$1, color: active ? const Color(0xFF00E5CC) : const Color(0xFF4A6A85), size: active ? 24 : 22),
                      const SizedBox(height: 2),
                      Text(_items[i].$2, style: TextStyle(fontSize: active ? 10 : 9, fontWeight: active ? FontWeight.w700 : FontWeight.w400, color: active ? const Color(0xFF00E5CC) : const Color(0xFF4A6A85))),
                    ],
                  ),
                );
              }),
            ),
          ),
        ),
      ),
    );
  }
}