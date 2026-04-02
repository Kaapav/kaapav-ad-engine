
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/theme.dart';
import '../widgets/search_filter.dart';
import '../core/utils.dart';
import '../widgets/glass_card.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  String _filter = 'All';

  final _notifications = [
    _NotifItem(type: 'rule', title: 'Scale Winners triggered', body: 'Navratri Sale budget increased 20% → ₹4,200/day', time: DateTime.now().subtract(const Duration(minutes: 15)), read: false),
    _NotifItem(type: 'lead', title: 'New Lead: Sonal Thakkar', body: 'From Diwali Early Bird Offer • Instagram', time: DateTime.now().subtract(const Duration(minutes: 20)), read: false),
    _NotifItem(type: 'alert', title: 'Budget Alert', body: 'Navratri Sale spent 92% of daily budget', time: DateTime.now().subtract(const Duration(hours: 1)), read: false),
    _NotifItem(type: 'lead', title: 'New Lead: Ritu Singh', body: 'From WhatsApp Catalog Push • WhatsApp', time: DateTime.now().subtract(const Duration(hours: 1, minutes: 30)), read: true),
    _NotifItem(type: 'rule', title: 'CPA Guardian triggered', body: 'Lookalike campaign budget reduced 30%', time: DateTime.now().subtract(const Duration(hours: 3)), read: true),
    _NotifItem(type: 'alert', title: 'Creative Fatigue Warning', body: 'Reels Gold Plated Set — frequency 3.8x (32 days old)', time: DateTime.now().subtract(const Duration(hours: 6)), read: true),
    _NotifItem(type: 'report', title: 'Daily Report Ready', body: 'Spend ₹12.4K • Revenue ₹58.2K • ROAS 4.7x • 47 leads', time: DateTime.now().subtract(const Duration(hours: 15)), read: true),
    _NotifItem(type: 'rule', title: 'Kill Low ROAS triggered', body: 'Test Campaign paused — ROAS 1.2x for 3 days', time: DateTime.now().subtract(const Duration(days: 1)), read: true),
    _NotifItem(type: 'lead', title: 'Lead Converted: Anjali Patel', body: 'Placed order ₹3,200 — Gold Plated Set', time: DateTime.now().subtract(const Duration(days: 1, hours: 3)), read: true),
    _NotifItem(type: 'alert', title: 'Low Delivery Warning', body: 'WhatsApp Catalog spent only 55% of daily budget', time: DateTime.now().subtract(const Duration(days: 2)), read: true),
    _NotifItem(type: 'report', title: 'Weekly Report', body: 'This week: ₹68.4K spend • ₹3.12L revenue • ROAS 4.6x', time: DateTime.now().subtract(const Duration(days: 3)), read: true),
  ];

  List<_NotifItem> get _filtered {
    if (_filter == 'All') return _notifications;
    return _notifications.where((n) => n.type == _filter.toLowerCase()).toList();
  }

  int get _unreadCount => _notifications.where((n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      backgroundColor: C.bgDeep,
      body: SafeArea(
        child: Column(
          children: [
            // HEADER
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(width: 38, height: 38, decoration: Glass.card(radius: 12), child: const Icon(Icons.arrow_back_ios_new_rounded, color: C.textPrimary, size: 16)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('Notifications', style: TextStyle(color: C.textPrimary, fontSize: 20, fontWeight: FontWeight.w700)),
                            if (_unreadCount > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                                decoration: BoxDecoration(gradient: C.primaryGrad, borderRadius: BorderRadius.circular(8)),
                                child: Text('$_unreadCount new', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ],
                        ),
                        const Text('Campaign alerts & updates', style: TextStyle(color: C.textSecondary, fontSize: 11)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      setState(() { for (var n in _notifications) { n.read = true; } });
                      HapticFeedback.lightImpact();
                    },
                    child: const Text('Mark all read', style: TextStyle(color: C.primary, fontSize: 11, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),

            // FILTER CHIPS
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SizedBox(
                height: 32,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: ['All', 'Alert', 'Rule', 'Lead', 'Report'].map((f) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: FilterChip2(label: f, selected: _filter == f, onTap: () => setState(() => _filter = f)),
                    );
                  }).toList(),
                ),
              ),
            ),

            // LIST
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                physics: const BouncingScrollPhysics(),
                itemCount: items.length,
                itemBuilder: (_, i) => _notifCard(items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifCard(_NotifItem n) {
    final color = switch (n.type) {
      'alert' => C.warning,
      'rule' => C.purple,
      'lead' => C.info,
      'report' => C.success,
      _ => C.textMuted,
    };
    final icon = switch (n.type) {
      'alert' => Icons.warning_amber_rounded,
      'rule' => Icons.bolt_rounded,
      'lead' => Icons.person_add_rounded,
      'report' => Icons.bar_chart_rounded,
      _ => Icons.notifications_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () { setState(() => n.read = true); HapticFeedback.lightImpact(); },
        child: GlassCard(
          radius: 16,
          turquoise: !n.read,
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(11), border: Border.all(color: color.withValues(alpha: 0.2))),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Text(n.title, style: TextStyle(color: n.read ? C.textSecondary : C.textPrimary, fontSize: 12, fontWeight: n.read ? FontWeight.w500 : FontWeight.w600))),
                        if (!n.read)
                          Container(width: 7, height: 7, decoration: BoxDecoration(gradient: C.primaryGrad, shape: BoxShape.circle)),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(n.body, style: const TextStyle(color: C.textMuted, fontSize: 11)),
                    const SizedBox(height: 4),
                    Text(U.ago(n.time), style: TextStyle(color: color.withValues(alpha: 0.7), fontSize: 10)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotifItem {
  final String type;
  final String title;
  final String body;
  final DateTime time;
  bool read;

  _NotifItem({required this.type, required this.title, required this.body, required this.time, this.read = false});
}