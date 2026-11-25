import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../app_config.dart';
import '../models/optik_models.dart';

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

  static bool get isConfigured => AppConfig.apiConfigured;

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
    if (!AppConfig.apiConfigured) {
      throw StateError('Token API belum dikonfigurasi.');
    }
    final uri = Uri.parse(AppConfig.appsScriptUrl);
    final request = await _client
        .postUrl(uri)
        .timeout(AppConfig.apiTimeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    // Apps Script ContentService may return a 302 to a one-time
    // script.googleusercontent.com URL. Handle it explicitly: dart:io
    // automatically follows GET/HEAD redirects, not ordinary POST redirects.
    request.followRedirects = false;
    request.write(jsonEncode({...payload, 'token': AppConfig.apiToken}));

    final response = await request.close().timeout(AppConfig.apiTimeout);
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain();
      if (location == null || location.isEmpty) {
        throw StateError('Backend mengirim redirect tanpa alamat tujuan.');
      }
      final redirectedUri = uri.resolve(location);
      final redirectedRequest = await _client
          .getUrl(redirectedUri)
          .timeout(AppConfig.apiTimeout);
      redirectedRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final redirectedResponse =
          await redirectedRequest.close().timeout(AppConfig.apiTimeout);
      return _readResponse(redirectedResponse);
    }
    return _readResponse(response);
  }


  /// Membaca tabel operasional melalui action readTable pada Apps Script.
  /// Menggunakan kontrak app-key API yang sudah ada; tidak mengubah alur transaksi.
  static Future<List<Map<String, dynamic>>> readTable(String sheetName) async {
    if (!AppConfig.apiConfigured) {
      throw StateError('Token API belum dikonfigurasi.');
    }
    final uri = Uri.parse(AppConfig.appsScriptUrl);
    final request = await _client.postUrl(uri).timeout(AppConfig.apiTimeout);
    request.headers.contentType = ContentType.json;
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.followRedirects = false;
    request.write(jsonEncode({
      'action': 'readTable',
      'apiKey': AppConfig.apiToken,
      'data': {'sheetName': sheetName},
    }));
    var response = await request.close().timeout(AppConfig.apiTimeout);
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain();
      if (location == null || location.isEmpty) {
        throw StateError('Backend mengirim redirect tanpa alamat tujuan.');
      }
      final redirected = await _client.getUrl(uri.resolve(location))
          .timeout(AppConfig.apiTimeout);
      redirected.headers.set(HttpHeaders.acceptHeader, 'application/json');
      response = await redirected.close().timeout(AppConfig.apiTimeout);
    }
    final result = await _readResponse(response);
    if (!result.isSuccessful || result.data is! Map || result.data['ok'] != true) {
      final message = result.data is Map
          ? result.data['error']?.toString() ?? 'Gagal membaca data Google Sheets.'
          : 'Respons pembacaan data bukan JSON yang dikenali.';
      throw StateError(message);
    }
    final rows = result.data['rows'];
    if (rows is! List) return <Map<String, dynamic>>[];
    return rows
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  static Future<Map<String, dynamic>> createOrder(OptikOrder order) async {
    final response = await post({
      'action': 'createOrder',
      'requestId': order.invoiceNumber,
      'order': {
        'orderDate': order.orderDate?.toIso8601String(),
        'name': order.customer.name,
        'phone': order.customer.phone,
        'address': order.customer.address,
        'doctor': order.prescription.doctor,
        'odSph': order.prescription.odSph,
        'odCyl': order.prescription.odCyl,
        'odAxis': order.prescription.odAxis,
        'odAdd': order.prescription.odAdd,
        'odPd': order.prescription.odPd,
        'osSph': order.prescription.osSph,
        'osCyl': order.prescription.osCyl,
        'osAxis': order.prescription.osAxis,
        'osAdd': order.prescription.osAdd,
        'osPd': order.prescription.osPd,
        'lensType': order.prescription.lensType,
        'rxNote': order.prescription.note,
        'frameDesc': order.frame.description,
        'framePrice': order.frame.price,
        'lensDesc': order.lens.description,
        'lensPrice': order.lens.price,
        'otherDesc': order.other.description,
        'otherPrice': order.other.price,
        'initialPayment': order.initialPayment,
        'initialPaymentMethod': order.initialPaymentMethod,
        'note': order.note,
      },
    });
    return _requireSuccess(response);
  }

  static Future<Map<String, dynamic>> createPayment(OptikPayment payment) async {
    final response = await post({
      'action': 'createPayment',
      'requestId': payment.requestId,
      'payment': {
        'invoiceNumber': payment.invoiceNumber,
        'paymentDate': payment.paymentDate.toIso8601String(),
        'amount': payment.amount,
        'method': payment.method,
        'note': payment.note,
      },
    });
    return _requireSuccess(response);
  }

  static Map<String, dynamic> _requireSuccess(ApiResponse response) {
    if (!response.isSuccessful || response.data is! Map || response.data['ok'] != true) {
      final message = response.data is Map
          ? response.data['message']?.toString() ?? 'Respons backend tidak valid.'
          : 'Respons backend bukan JSON yang dikenali.';
      throw StateError(message);
    }
    return Map<String, dynamic>.from(response.data as Map);
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
