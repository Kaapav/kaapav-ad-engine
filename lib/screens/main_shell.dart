import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../widgets/glass_nav.dart';
import 'dashboard_screen.dart';
import 'campaigns_screen.dart';
import 'crm_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _tab = 0;

  Widget _placeholder(String title, IconData icon) => Scaffold(
        backgroundColor: C.bgDeep,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: C.primary.withValues(alpha: 0.3), size: 48),
              const SizedBox(height: 12),
              Text(title, style: const TextStyle(color: C.textSecondary, fontSize: 16)),
              const Text('Coming in Part 3', style: TextStyle(color: C.textMuted, fontSize: 12)),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: C.bgDeep,
      extendBody: true,
      body: IndexedStack(
        index: _tab,
        children: [
          const DashboardScreen(),
          const CampaignsScreen(),       // ✅ WIRED
          const CrmScreen(),              // ✅ WIRED
          _placeholder('AutoPilot', Icons.auto_awesome_rounded),
          _placeholder('More', Icons.menu_rounded),
        ],
      ),
      bottomNavigationBar: GlassNav(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}