import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_config.dart';

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
