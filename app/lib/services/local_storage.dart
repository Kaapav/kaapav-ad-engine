import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';

class LocalStorageService {
  static const _campaignsBox = 'campaigns_cache';
  static const _leadsBox = 'leads_cache';
  static const _insightsBox = 'insights_cache';
  static const _settingsBox = 'app_settings';
  static const _notificationsBox = 'notifications';
  static const _rulesBox = 'automation_rules';

  static bool _initialized = false;

  // ═══════════════════════════════════════════════════════════
  // INIT
  // ═══════════════════════════════════════════════════════════
  static Future<void> init() async {
    if (_initialized) return;
    final dir = await getApplicationDocumentsDirectory();
    await Hive.initFlutter(dir.path);
    await Future.wait([
      Hive.openBox(_campaignsBox),
      Hive.openBox(_leadsBox),
      Hive.openBox(_insightsBox),
      Hive.openBox(_settingsBox),
      Hive.openBox(_notificationsBox),
      Hive.openBox(_rulesBox),
    ]);
    _initialized = true;
  }

  // ═══════════════════════════════════════════════════════════
  // CAMPAIGNS
  // ═══════════════════════════════════════════════════════════
  static Future<void> cacheCampaigns(List<Map<String, dynamic>> data) async {
    final box = Hive.box(_campaignsBox);
    await box.put('data', jsonEncode(data));
    await box.put('timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static List<Map<String, dynamic>>? getCachedCampaigns({Duration maxAge = const Duration(minutes: 15)}) {
    final box = Hive.box(_campaignsBox);
    final ts = box.get('timestamp') as int?;
    if (ts == null) return null;

    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > maxAge) return null;

    final raw = box.get('data') as String?;
    if (raw == null) return null;

    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════════
  // LEADS
  // ═══════════════════════════════════════════════════════════
  static Future<void> cacheLeads(List<Map<String, dynamic>> data) async {
    final box = Hive.box(_leadsBox);
    await box.put('data', jsonEncode(data));
    await box.put('timestamp', DateTime.now().millisecondsSinceEpoch);
  }

  static List<Map<String, dynamic>>? getCachedLeads({Duration maxAge = const Duration(minutes: 10)}) {
    final box = Hive.box(_leadsBox);
    final ts = box.get('timestamp') as int?;
    if (ts == null) return null;

    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > maxAge) return null;

    final raw = box.get('data') as String?;
    if (raw == null) return null;

    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════════
  // INSIGHTS
  // ═══════════════════════════════════════════════════════════
  static Future<void> cacheInsights(String key, Map<String, dynamic> data) async {
    final box = Hive.box(_insightsBox);
    await box.put(key, jsonEncode(data));
    await box.put('${key}_ts', DateTime.now().millisecondsSinceEpoch);
  }

  static Map<String, dynamic>? getCachedInsights(String key, {Duration maxAge = const Duration(minutes: 30)}) {
    final box = Hive.box(_insightsBox);
    final ts = box.get('${key}_ts') as int?;
    if (ts == null) return null;

    final age = DateTime.now().difference(DateTime.fromMillisecondsSinceEpoch(ts));
    if (age > maxAge) return null;

    final raw = box.get(key) as String?;
    if (raw == null) return null;

    return jsonDecode(raw) as Map<String, dynamic>;
  }

  // ═══════════════════════════════════════════════════════════
  // NOTIFICATIONS
  // ═══════════════════════════════════════════════════════════
  static Future<void> saveNotification(Map<String, dynamic> notification) async {
    final box = Hive.box(_notificationsBox);
    final list = getNotifications();
    list.insert(0, notification);
    // Keep only last 100
    if (list.length > 100) list.removeRange(100, list.length);
    await box.put('list', jsonEncode(list));
  }

  static List<Map<String, dynamic>> getNotifications() {
    final box = Hive.box(_notificationsBox);
    final raw = box.get('list') as String?;
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  static Future<void> markAllRead() async {
    final box = Hive.box(_notificationsBox);
    final list = getNotifications();
    for (var n in list) {
      n['read'] = true;
    }
    await box.put('list', jsonEncode(list));
  }

  static int get unreadCount {
    return getNotifications().where((n) => n['read'] != true).length;
  }

  // ═══════════════════════════════════════════════════════════
  // SETTINGS
  // ═══════════════════════════════════════════════════════════
  static Future<void> saveSetting(String key, dynamic value) async {
    final box = Hive.box(_settingsBox);
    await box.put(key, value);
  }

  static T? getSetting<T>(String key, {T? defaultValue}) {
    final box = Hive.box(_settingsBox);
    return box.get(key, defaultValue: defaultValue) as T?;
  }

  // ═══════════════════════════════════════════════════════════
  // RULES
  // ═══════════════════════════════════════════════════════════
  static Future<void> cacheRules(List<Map<String, dynamic>> rules) async {
    final box = Hive.box(_rulesBox);
    await box.put('data', jsonEncode(rules));
  }

  static List<Map<String, dynamic>>? getCachedRules() {
    final box = Hive.box(_rulesBox);
    final raw = box.get('data') as String?;
    if (raw == null) return null;
    final list = jsonDecode(raw) as List;
    return list.cast<Map<String, dynamic>>();
  }

  // ═══════════════════════════════════════════════════════════
  // CLEAR
  // ═══════════════════════════════════════════════════════════
  static Future<void> clearAll() async {
    await Future.wait([
      Hive.box(_campaignsBox).clear(),
      Hive.box(_leadsBox).clear(),
      Hive.box(_insightsBox).clear(),
      Hive.box(_notificationsBox).clear(),
      Hive.box(_rulesBox).clear(),
    ]);
  }

  static Future<void> clearCache() async {
    await Future.wait([
      Hive.box(_campaignsBox).clear(),
      Hive.box(_leadsBox).clear(),
      Hive.box(_insightsBox).clear(),
    ]);
  }
}