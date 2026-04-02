import 'package:dio/dio.dart';
import '../core/constants.dart';

class SheetsService {
  late final Dio _dio;
  String spreadsheetId = '';
  String accessToken = '';

  SheetsService() {
    _dio = Dio(BaseOptions(
      baseUrl: K.sheetsBase,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void configure({required String sheetId, required String token}) {
    spreadsheetId = sheetId;
    accessToken = token;
  }

  Map<String, String> get _headers => {'Authorization': 'Bearer $accessToken'};

  // ═══════════════════════════════════════════════════════════
  // READ DATA
  // ═══════════════════════════════════════════════════════════
  Future<List<List<dynamic>>> readRange(String range) async {
    final res = await _dio.get(
      '/$spreadsheetId/values/$range',
      options: Options(headers: _headers),
      queryParameters: {'valueRenderOption': 'UNFORMATTED_VALUE'},
    );
    final values = res.data['values'] as List?;
    if (values == null) return [];
    return values.map((row) => (row as List).toList()).toList();
  }

  // ═══════════════════════════════════════════════════════════
  // WRITE DATA
  // ═══════════════════════════════════════════════════════════
  Future<void> writeRange(String range, List<List<dynamic>> values) async {
    await _dio.put(
      '/$spreadsheetId/values/$range',
      options: Options(headers: _headers),
      queryParameters: {'valueInputOption': 'USER_ENTERED'},
      data: {'values': values},
    );
  }

  Future<void> appendRow(String sheet, List<dynamic> row) async {
    await _dio.post(
      '/$spreadsheetId/values/$sheet!A:Z:append',
      options: Options(headers: _headers),
      queryParameters: {'valueInputOption': 'USER_ENTERED', 'insertDataOption': 'INSERT_ROWS'},
      data: {'values': [row]},
    );
  }

  // ═══════════════════════════════════════════════════════════
  // SYNC CAMPAIGNS TO SHEET
  // ═══════════════════════════════════════════════════════════
  Future<void> syncCampaigns(List<Map<String, dynamic>> campaigns) async {
    final header = [
      'Campaign ID', 'Name', 'Status', 'Platform', 'Objective',
      'Spend', 'Revenue', 'ROAS', 'CPA', 'CTR',
      'Impressions', 'Clicks', 'Conversions', 'Updated',
    ];

    final rows = campaigns.map((c) => [
      c['id'], c['name'], c['status'], c['platform'], c['objective'],
      c['spend'], c['revenue'], c['roas'], c['cpa'], c['ctr'],
      c['impressions'], c['clicks'], c['conversions'], c['updated_at'],
    ]).toList();

    await writeRange('Campaigns!A1', [header, ...rows]);
  }

  // ═══════════════════════════════════════════════════════════
  // SYNC LEADS TO SHEET
  // ═══════════════════════════════════════════════════════════
  Future<void> syncLeads(List<Map<String, dynamic>> leads) async {
    final header = [
      'Lead ID', 'Name', 'Phone', 'Email', 'Campaign',
      'Stage', 'Source', 'Product', 'Value', 'Created', 'Updated',
    ];

    final rows = leads.map((l) => [
      l['id'], l['name'], l['phone'], l['email'] ?? '',
      l['campaign'], l['stage'], l['source'],
      l['product'] ?? '', l['value'] ?? '', l['created_at'], l['updated_at'],
    ]).toList();

    await writeRange('Leads!A1', [header, ...rows]);
  }

  // ═══════════════════════════════════════════════════════════
  // SYNC DAILY INSIGHTS
  // ═══════════════════════════════════════════════════════════
  Future<void> appendDailyInsight(Map<String, dynamic> insight) async {
    await appendRow('Daily Insights', [
      insight['date'],
      insight['spend'],
      insight['revenue'],
      insight['roas'],
      insight['cpa'],
      insight['impressions'],
      insight['clicks'],
      insight['conversions'],
      insight['leads'],
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // SYNC AUTOMATION LOG
  // ═══════════════════════════════════════════════════════════
  Future<void> logAutomation(Map<String, dynamic> entry) async {
    await appendRow('Automation Log', [
      entry['timestamp'],
      entry['rule_name'],
      entry['campaign'],
      entry['action'],
      entry['old_value'],
      entry['new_value'],
      entry['result'],
    ]);
  }

  // ═══════════════════════════════════════════════════════════
  // CREATE SHEETS STRUCTURE
  // ═══════════════════════════════════════════════════════════
  Future<void> initializeSheets() async {
    final sheets = ['Campaigns', 'Leads', 'Daily Insights', 'Automation Log'];
    final requests = sheets.map((name) => {
      'addSheet': {
        'properties': {'title': name},
      },
    }).toList();

    try {
      await _dio.post(
        '/$spreadsheetId:batchUpdate',
        options: Options(headers: _headers),
        data: {'requests': requests},
      );
    } catch (_) {
      // Sheets may already exist — ignore
    }
  }
}