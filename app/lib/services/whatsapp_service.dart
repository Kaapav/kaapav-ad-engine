import 'package:dio/dio.dart';

class WhatsAppService {
  late final Dio _dio;
  String phoneNumberId = '';
  String accessToken = '';

  static const _baseUrl = 'https://graph.facebook.com/v21.0';

  WhatsAppService() {
    _dio = Dio(BaseOptions(
      baseUrl: _baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
    ));
  }

  void configure({required String phoneId, required String token}) {
    phoneNumberId = phoneId;
    accessToken = token;
  }

  // ═══════════════════════════════════════════════════════════
  // SEND TEXT MESSAGE
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendText({
    required String to,
    required String message,
  }) async {
    final res = await _dio.post(
      '/$phoneNumberId/messages',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      data: {
        'messaging_product': 'whatsapp',
        'to': _cleanPhone(to),
        'type': 'text',
        'text': {'body': message},
      },
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // SEND TEMPLATE MESSAGE
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendTemplate({
    required String to,
    required String templateName,
    String languageCode = 'en',
    List<Map<String, dynamic>>? headerParams,
    List<Map<String, dynamic>>? bodyParams,
    List<Map<String, dynamic>>? buttonParams,
  }) async {
    final components = <Map<String, dynamic>>[];
    if (headerParams != null) {
      components.add({'type': 'header', 'parameters': headerParams});
    }
    if (bodyParams != null) {
      components.add({'type': 'body', 'parameters': bodyParams});
    }
    if (buttonParams != null) {
      for (var i = 0; i < buttonParams.length; i++) {
        components.add({'type': 'button', 'sub_type': 'quick_reply', 'index': '$i', 'parameters': [buttonParams[i]]});
      }
    }

    final res = await _dio.post(
      '/$phoneNumberId/messages',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      data: {
        'messaging_product': 'whatsapp',
        'to': _cleanPhone(to),
        'type': 'template',
        'template': {
          'name': templateName,
          'language': {'code': languageCode},
          if (components.isNotEmpty) 'components': components,
        },
      },
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // SEND CATALOG MESSAGE
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendCatalog({
    required String to,
    required String bodyText,
    String? headerText,
    String? footerText,
  }) async {
    final res = await _dio.post(
      '/$phoneNumberId/messages',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      data: {
        'messaging_product': 'whatsapp',
        'to': _cleanPhone(to),
        'type': 'interactive',
        'interactive': {
          'type': 'catalog_message',
          'body': {'text': bodyText},
          if (headerText != null) 'header': {'type': 'text', 'text': headerText},
          if (footerText != null) 'footer': {'text': footerText},
          'action': {'name': 'catalog_message'},
        },
      },
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // SEND IMAGE
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendImage({
    required String to,
    required String imageUrl,
    String? caption,
  }) async {
    final res = await _dio.post(
      '/$phoneNumberId/messages',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      data: {
        'messaging_product': 'whatsapp',
        'to': _cleanPhone(to),
        'type': 'image',
        'image': {
          'link': imageUrl,
          if (caption != null) 'caption': caption,
        },
      },
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // SEND INTERACTIVE BUTTONS
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendButtons({
    required String to,
    required String bodyText,
    required List<Map<String, String>> buttons, // [{id, title}]
    String? headerText,
    String? footerText,
  }) async {
    final res = await _dio.post(
      '/$phoneNumberId/messages',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      data: {
        'messaging_product': 'whatsapp',
        'to': _cleanPhone(to),
        'type': 'interactive',
        'interactive': {
          'type': 'button',
          'body': {'text': bodyText},
          if (headerText != null) 'header': {'type': 'text', 'text': headerText},
          if (footerText != null) 'footer': {'text': footerText},
          'action': {
            'buttons': buttons.map((b) => {
              'type': 'reply',
              'reply': {'id': b['id'], 'title': b['title']},
            }).toList(),
          },
        },
      },
    );
    return res.data;
  }

  // ═══════════════════════════════════════════════════════════
  // SEND ORDER CONFIRMATION (for Kaapav)
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendOrderConfirmation({
    required String to,
    required String orderId,
    required String productName,
    required double amount,
    String? trackingUrl,
  }) async {
    final body = '🎉 Order Confirmed!\n\n'
        '📦 Order: #$orderId\n'
        '💎 Product: $productName\n'
        '💰 Amount: ₹${amount.toStringAsFixed(0)}\n\n'
        '${trackingUrl != null ? "🔗 Track: $trackingUrl\n\n" : ""}'
        'Thank you for shopping with Kaapav! ✨';

    return sendText(to: to, message: body);
  }

  // ═══════════════════════════════════════════════════════════
  // SEND LEAD FOLLOW-UP (for CRM)
  // ═══════════════════════════════════════════════════════════
  Future<Map<String, dynamic>> sendLeadFollowUp({
    required String to,
    required String customerName,
    required String productInterest,
  }) async {
    final body = 'Hi $customerName! 👋\n\n'
        'Thank you for your interest in our $productInterest.\n\n'
        'We have some beautiful pieces that might interest you. '
        'Would you like to see our latest collection?\n\n'
        '✨ Kaapav Fashion Jewellery';

    return sendText(to: to, message: body);
  }

  // ═══════════════════════════════════════════════════════════
  // BULK SEND (rate limited)
  // ═══════════════════════════════════════════════════════════
  Future<List<Map<String, dynamic>>> bulkSend({
    required List<String> recipients,
    required String templateName,
    String languageCode = 'en',
    List<Map<String, dynamic>>? bodyParams,
    Duration delayBetween = const Duration(milliseconds: 500),
  }) async {
    final results = <Map<String, dynamic>>[];
    for (final to in recipients) {
      try {
        final res = await sendTemplate(
          to: to,
          templateName: templateName,
          languageCode: languageCode,
          bodyParams: bodyParams,
        );
        results.add({'to': to, 'status': 'sent', 'response': res});
      } catch (e) {
        results.add({'to': to, 'status': 'failed', 'error': e.toString()});
      }
      await Future.delayed(delayBetween);
    }
    return results;
  }

  String _cleanPhone(String phone) {
    return phone.replaceAll(RegExp(r'[^\d+]'), '').replaceAll('+', '');
  }
}