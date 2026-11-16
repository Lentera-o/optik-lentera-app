import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hasil mentah dari Google Apps Script.
/// Parsing payload bisnis dilakukan setelah kontrak endpoint diverifikasi.
class ApiResponse {
  final int statusCode;
  final String rawBody;
  final dynamic data;

  const ApiResponse({
    required this.statusCode,
    required this.rawBody,
    required this.data,
  });

  bool get isSuccessful => statusCode >= 200 && statusCode < 300;
}

class ApiService {
  ApiService._();

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = AppConfig.apiTimeout;

  /// Memanggil doGet Apps Script. Parameter [query] diteruskan sebagai query
  /// string tanpa mengasumsikan nama action tertentu.
  static Future<ApiResponse> get({
    Map<String, String> query = const {},
  }) async {
    final uri = Uri.parse(AppConfig.appsScriptUrl).replace(
      queryParameters: query.isEmpty ? null : query,
    );
    return _send('GET', uri);
  }

  /// Mengirim JSON ke doPost Apps Script. Bentuk payload diserahkan pemanggil
  /// agar sesuai kontrak backend yang sudah ada.
  static Future<ApiResponse> post(Map<String, dynamic> payload) async {
    final uri = Uri.parse(AppConfig.appsScriptUrl);
    final request = await _client
        .postUrl(uri)
        .timeout(AppConfig.apiTimeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode(payload));

    final response = await request.close().timeout(AppConfig.apiTimeout);
    return _readResponse(response);
  }


  /// Membuka Google Form resmi dengan jawaban transaksi yang sudah diisi.
  /// Petugas tetap meninjau dan menekan Kirim di Google Form; trigger Form
  /// yang sudah ada tetap menjadi satu-satunya pemroses transaksi resmi.
  static Future<bool> openPrefilledForm({
    required String formId,
    required Map<String, String> answers,
  }) async {
    final query = <String, String>{'usp': 'pp_url'};
    for (final entry in answers.entries) {
      if (entry.value.trim().isNotEmpty) {
        query['entry.${entry.key}'] = entry.value.trim();
      }
    }
    final uri = Uri.https(
      'docs.google.com',
      '/forms/d/e/$formId/viewform',
      query,
    );
    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  static const String orderFormId =
      '1FAIpQLSfp5DYAtg8ENTmW4_jOVpwVL7ZUzi2v5KDb8VtKp-zoZY0rQA';
  static const String paymentFormId =
      '1FAIpQLScckA6mmAbrektSRO1-9rRE9ObwRErwmb5LLTo5ZTq24DEbEQ';

  static Future<bool> openOrderForm(Map<String, String> answers) =>
      openPrefilledForm(formId: orderFormId, answers: answers);

  static Future<bool> openPaymentForm(Map<String, String> answers) =>
      openPrefilledForm(formId: paymentFormId, answers: answers);

  static Future<ApiResponse> _send(String method, Uri uri) async {
    final request = await _client.openUrl(method, uri)
        .timeout(AppConfig.apiTimeout);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(AppConfig.apiTimeout);
    return _readResponse(response);
  }

  static Future<ApiResponse> _readResponse(HttpClientResponse response) async {
    final body = await utf8.decoder.bind(response).join();
    dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      decoded = body;
    }
    return ApiResponse(
      statusCode: response.statusCode,
      rawBody: body,
      data: decoded,
    );
  }
}
