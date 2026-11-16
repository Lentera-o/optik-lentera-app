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



  /// Mengirim jawaban langsung ke endpoint Google Forms agar petugas tidak
  /// perlu berpindah ke browser. Form tetap menjadi sumber resmi trigger lama.
  static Future<bool> submitForm({
    required String formId,
    required Map<String, String> answers,
  }) async {
    try {
      final formUri = Uri.https(
        'docs.google.com',
        '/forms/d/e/$formId/viewform',
      );
      final formRequest = await _client.getUrl(formUri).timeout(AppConfig.apiTimeout);
      formRequest.headers.set(HttpHeaders.acceptHeader, 'text/html');
      final formResponse = await formRequest.close().timeout(AppConfig.apiTimeout);
      final formHtml = await utf8.decoder.bind(formResponse).join();
      if (formResponse.statusCode < 200 || formResponse.statusCode >= 400) {
        return false;
      }

      final fbzxMatch = RegExp(r'name="fbzx"[^>]*value="([^"]+)"')
          .firstMatch(formHtml) ??
          RegExp(r'value="([^"]+)"[^>]*name="fbzx"').firstMatch(formHtml);
      if (fbzxMatch == null) return false;

      final fields = <String, String>{
        'fvv': '1',
        'draftResponse': '[]',
        'pageHistory': '0',
        'fbzx': fbzxMatch.group(1)!,
      };
      for (final entry in answers.entries) {
        if (entry.value.trim().isNotEmpty) {
          fields['entry.${entry.key}'] = entry.value.trim();
        }
      }

      final submitUri = Uri.https(
        'docs.google.com',
        '/forms/d/e/$formId/formResponse',
      );
      final request = await _client.postUrl(submitUri).timeout(AppConfig.apiTimeout);
      request.headers.contentType = ContentType(
        'application',
        'x-www-form-urlencoded',
        charset: 'utf-8',
      );
      request.headers.set(HttpHeaders.acceptHeader, 'text/html');
      request.headers.set(HttpHeaders.refererHeader, formUri.toString());
      request.write(Uri(queryParameters: fields).query);
      final response = await request.close().timeout(AppConfig.apiTimeout);
      final body = (await utf8.decoder.bind(response).join()).toLowerCase();
      if (response.statusCode < 200 || response.statusCode >= 400) {
        return false;
      }
      return body.contains('response has been recorded') ||
          body.contains('jawaban anda telah direkam') ||
          body.contains('tanggapan anda telah direkam') ||
          body.contains('your response has been recorded') ||
          body.contains('terima kasih');
    } catch (_) {
      return false;
    }
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
      submitForm(formId: orderFormId, answers: answers);

  static Future<bool> openPaymentForm(Map<String, String> answers) =>
      submitForm(formId: paymentFormId, answers: answers);

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
