import 'dart:convert';
import 'dart:io';

import '../app_config.dart';
import 'package:url_launcher/url_launcher.dart';

/// Hasil mentah dari Google Apps Script.
class ApiResponse {
  final int statusCode;
  final String rawBody;
  final dynamic data;

  const ApiResponse({
    required this.statusCode,
    required this.rawBody,
    required this.data,
  });

  /// Apps Script ContentService can return an application-level failure as
  /// JSON with HTTP 200. Treat an explicit {ok:false} as a failed request.
  bool get isSuccessful {
    if (statusCode < 200 || statusCode >= 300) return false;
    if (data is Map && data['ok'] == false) return false;
    return true;
  }

  String? get errorMessage {
    if (data is Map && data['error'] != null) {
      return data['error'].toString();
    }
    return null;
  }
}

class ApiService {
  ApiService._();

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = AppConfig.apiTimeout;

  static Future<ApiResponse> get({
    Map<String, String> query = const {},
  }) async {
    final uri = Uri.parse(AppConfig.appsScriptUrl).replace(
      queryParameters: query.isEmpty ? null : query,
    );
    return _send('GET', uri);
  }

  /// Sends a transaction to Apps Script and safely follows its ContentService
  /// redirect. Apps Script may return JSON from script.googleusercontent.com
  /// after the POST has been processed; the redirect is fetched with GET so
  /// the transaction body is never replayed.
  static Future<ApiResponse> postTransaction({
    required String action,
    required String requestId,
    required Map<String, dynamic> data,
  }) async {
    if (action != 'createOrder' && action != 'createPayment') {
      throw ArgumentError.value(action, 'action', 'Unsupported transaction action');
    }
    if (AppConfig.appApiKey.isEmpty || requestId.isEmpty) {
      throw ArgumentError('App access key and stable request ID are required.');
    }

    final uri = Uri.parse(AppConfig.appsScriptUrl);
    final request = await _client.postUrl(uri).timeout(AppConfig.apiTimeout);
    request.followRedirects = false;
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode({
      'action': action,
      'requestId': requestId,
      'apiKey': AppConfig.appApiKey,
      'data': data,
    }));

    final response = await request.close().timeout(AppConfig.apiTimeout);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.trim().isEmpty) {
        throw const HttpException('Apps Script mengembalikan redirect tanpa alamat tujuan.');
      }
      final target = uri.resolve(location);
      if (target.scheme != 'https' ||
          (target.host != 'script.googleusercontent.com' &&
           target.host != 'script.google.com')) {
        throw const HttpException('Tujuan redirect Apps Script tidak tepercaya.');
      }
      // Do not replay the POST: Apps Script may already have written the row.
      final redirected = await _client.getUrl(target).timeout(AppConfig.apiTimeout);
      redirected.followRedirects = true;
      redirected.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final redirectedResponse = await redirected.close().timeout(AppConfig.apiTimeout);
      return _readResponse(redirectedResponse);
    }
    return _readResponse(response);
  }

  /// App-key-protected, read-only request to the Apps Script API.
  /// This endpoint is separate from transaction writes and never replays a POST.
  static Future<ApiResponse> postAuthorizedRead({
    required String action,
    required Map<String, dynamic> data,
  }) {
    if (action != 'readTable') {
      throw ArgumentError('Only readTable is allowed for this method.');
    }
    return _postAuthorizedAction(action: action, data: data);
  }

  static Future<ApiResponse> updateOrderStatus({
    required String invoice,
    required String status,
  }) => _postAuthorizedAction(
    action: 'updateOrderStatus',
    data: {'invoice': invoice, 'status': status},
  );

  static Future<ApiResponse> _postAuthorizedAction({
    required String action,
    required Map<String, dynamic> data,
  }) async {
    if (!['readTable', 'updateOrderStatus'].contains(action) || AppConfig.appApiKey.isEmpty) {
      throw ArgumentError('App access key and an allowed action are required.');
    }
    final uri = Uri.parse(AppConfig.appsScriptUrl);
    final request = await _client.postUrl(uri).timeout(AppConfig.apiTimeout);
    request.followRedirects = false;
    request.headers
      ..contentType = ContentType.json
      ..set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode({'action': action, 'apiKey': AppConfig.appApiKey, 'data': data}));
    final response = await request.close().timeout(AppConfig.apiTimeout);
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain<void>();
      if (location == null || location.trim().isEmpty) {
        throw const HttpException('Apps Script mengembalikan redirect tanpa alamat tujuan.');
      }
      final target = uri.resolve(location);
      if (target.scheme != 'https' ||
          (target.host != 'script.googleusercontent.com' && target.host != 'script.google.com')) {
        throw const HttpException('Tujuan redirect Apps Script tidak tepercaya.');
      }
      final redirected = await _client.getUrl(target).timeout(AppConfig.apiTimeout);
      redirected.followRedirects = true;
      redirected.headers.set(HttpHeaders.acceptHeader, 'application/json');
      return _readResponse(await redirected.close().timeout(AppConfig.apiTimeout));
    }
    return _readResponse(response);
  }

  static Future<ApiResponse> createOrder({
    required String requestId,
    required Map<String, dynamic> data,
  }) => postTransaction(
    action: 'createOrder',
    requestId: requestId,
    data: data,
  );

  static Future<ApiResponse> createPayment({
    required String requestId,
    required Map<String, dynamic> data,
  }) => postTransaction(
    action: 'createPayment',
    requestId: requestId,
    data: data,
  );

  static Future<ApiResponse> post(Map<String, dynamic> payload) async {
    final uri = Uri.parse(AppConfig.appsScriptUrl);
    final request = await _client.postUrl(uri).timeout(AppConfig.apiTimeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.write(jsonEncode(payload));
    final response = await request.close().timeout(AppConfig.apiTimeout);
    return _readResponse(response);
  }

  /// Membuka Google Form resmi dengan jawaban yang sudah diisi.
  /// Petugas wajib memeriksa data dan menekan Kirim secara manual.
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
    try {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      return false;
    }
  }

  static const String orderFormId =
      '1FAIpQLSfp5DYAtg8ENTmW4_jOVpwVL7ZUzi2v5KDb8VtKp-zoZY0rQA';
  static const String paymentFormId =
      '1FAIpQLScckA6mmAbrektSRO1-9rRE9ObwRErwmb5LLTo5ZTq24DEbEQ';

  /// Membuka formulir pesanan; tidak mengirim transaksi dari aplikasi.
  static Future<bool> openOrderForm(Map<String, String> answers) =>
      openPrefilledForm(formId: orderFormId, answers: answers);

  /// Membuka formulir pembayaran; tidak mengirim transaksi dari aplikasi.
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
