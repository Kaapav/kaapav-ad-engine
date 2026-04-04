import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ═══════════════════════════════════════════════════════════
  // INITIALIZATION
  // ═══════════════════════════════════════════════════════════
  Future<void> init() async {
    if (_initialized) return;

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    const settings = InitializationSettings(android: androidSettings, iOS: iosSettings);

    await _local.initialize(
      settings,
      onDidReceiveNotificationResponse: _onNotificationTap,
    );

    // Create notification channels
    if (Platform.isAndroid) {
      await _createChannels();
    }

    _initialized = true;
  }

  Future<void> _createChannels() async {
    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return;

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'kaapav_alerts', 'Campaign Alerts',
      description: 'Budget alerts, ROAS changes, campaign status',
      importance: Importance.high,
      enableVibration: true,
      playSound: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'kaapav_autopilot', 'AutoPilot Actions',
      description: 'Automated rule triggers and actions',
      importance: Importance.high,
      enableVibration: true,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'kaapav_leads', 'New Leads',
      description: 'Notifications for new leads',
      importance: Importance.defaultImportance,
    ));

    await android.createNotificationChannel(const AndroidNotificationChannel(
      'kaapav_reports', 'Daily Reports',
      description: 'Daily performance summaries',
      importance: Importance.low,
    ));
  }

  // ═══════════════════════════════════════════════════════════
  // SHOW NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  Future<void> showAlert({
    required String title,
    required String body,
    String? payload,
  }) async {
    await _show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: title,
      body: body,
      channelId: 'kaapav_alerts',
      channelName: 'Campaign Alerts',
      payload: payload,
      color: const Color(0xFF00E5CC),
    );
  }

  Future<void> showAutoPilotAction({
    required String title,
    required String body,
    String? ruleId,
    String? campaignId,
  }) async {
    await _show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🤖 $title',
      body: body,
      channelId: 'kaapav_autopilot',
      channelName: 'AutoPilot Actions',
      payload: jsonEncode({'rule_id': ruleId, 'campaign_id': campaignId}),
      color: const Color(0xFF7B2FFF),
    );
  }

  Future<void> showNewLead({
    required String leadName,
    required String campaign,
    String? leadId,
  }) async {
    await _show(
      id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title: '🎯 New Lead: $leadName',
      body: 'From $campaign',
      channelId: 'kaapav_leads',
      channelName: 'New Leads',
      payload: jsonEncode({'lead_id': leadId}),
      color: const Color(0xFF00B0FF),
    );
  }

  Future<void> showDailyReport({
    required double spend,
    required double revenue,
    required double roas,
    required int leads,
  }) async {
    await _show(
      id: 99999,
      title: '📊 Daily Report — Kaapav',
      body: 'Spend: ₹${spend.toStringAsFixed(0)} • Revenue: ₹${revenue.toStringAsFixed(0)} • ROAS: ${roas.toStringAsFixed(1)}x • Leads: $leads',
      channelId: 'kaapav_reports',
      channelName: 'Daily Reports',
      color: const Color(0xFF00E676),
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SCHEDULE
  // ═══════════════════════════════════════════════════════════
  Future<void> scheduleDailyReport({required int hour, required int minute}) async {
    // Schedule a daily notification at specific time
    await _local.periodicallyShow(
      88888,
      '📊 Daily Report Ready',
      'Tap to view your Kaapav Ad Engine performance summary',
      RepeatInterval.daily,
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'kaapav_reports', 'Daily Reports',
          importance: Importance.low,
          priority: Priority.low,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  // ═══════════════════════════════════════════════════════════
  // CANCEL
  // ═══════════════════════════════════════════════════════════
  Future<void> cancelAll() async => _local.cancelAll();
  Future<void> cancel(int id) async => _local.cancel(id);

  // ═══════════════════════════════════════════════════════════
  // INTERNAL
  // ═══════════════════════════════════════════════════════════
  Future<void> _show({
    required int id,
    required String title,
    required String body,
    required String channelId,
    required String channelName,
    String? payload,
    Color? color,
  }) async {
    await _local.show(
      id, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          channelId, channelName,
          importance: Importance.high,
          priority: Priority.high,
          color: color,
          icon: '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(body),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: payload,
    );
  }

  void _onNotificationTap(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null) return;
    // Route to appropriate screen based on payload
    // This would use GoRouter or Navigator in production
  }
}