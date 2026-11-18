import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../models/optik_models.dart';

/// Pengiriman langsung ke Google Forms resmi OPTIK LENTERA.
/// Respons HTTP hanya menandakan endpoint menerima request; status transaksi
/// tetap harus diverifikasi dari DATA_PESANAN / DATA_PEMBAYARAN.
class GoogleFormsService {
  GoogleFormsService._();

  static const String _orderFormId =
      '1FAIpQLSfp5DYAtg8ENTmW4_jOVpwVL7ZUzi2v5KDb8VtKp-zoZY0rQA';
  static const String _paymentFormId =
      '1FAIpQLScckA6mmAbrektSRO1-9rRE9ObwRErwmb5LLTo5ZTq24DEbEQ';

  static const Duration _timeout = Duration(seconds: 30);
  static final HttpClient _client = HttpClient()
    ..connectionTimeout = _timeout;

  static Future<void> submitOrder(OptikOrder order) async {
    final p = order.prescription;
    final fields = <String, String>{
      'entry.1324477027': order.customer.name,
      'entry.539015243': order.customer.phone,
      'entry.1777754745': order.customer.address,
      'entry.542463507': p.doctor,
      'entry.1271316087': p.odSph,
      'entry.1616866281': p.odCyl,
      'entry.1784427947': p.odAxis,
      'entry.1558365892': p.odAdd,
      'entry.940199491': p.odPd,
      'entry.480078014': p.osSph,
      'entry.66061879': p.osCyl,
      'entry.493870905': p.osAxis,
      'entry.42654846': p.osAdd,
      'entry.950234578': p.osPd,
      'entry.684419252': p.lensType,
      'entry.1481958730': p.note,
      'entry.686343109': order.frame.description,
      'entry.1727076794': order.frame.price.toString(),
      'entry.1326678958': order.lens.description,
      'entry.97131819': order.lens.price.toString(),
      'entry.2101353430': order.other.description,
      'entry.1643782415': order.other.price.toString(),
      'entry.1449005528': order.initialPayment.toString(),
      'entry.1188539863': order.note,
      'entry.1492024415': order.initialPaymentMethod,
    };
    await _submit(_orderFormId, fields);
  }

  static Future<void> submitPayment(OptikPayment payment) async {
    final date = payment.paymentDate;
    final dateValue =
        '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
    final fields = <String, String>{
      'entry.1667531169': payment.invoiceNumber,
      'entry.266758159': dateValue,
      'entry.448728880': payment.amount.toString(),
      'entry.1530690867': payment.method,
      'entry.1651033565': payment.category,
      'entry.284716454': payment.note,
    };
    await _submit(_paymentFormId, fields);
  }

  static Future<void> _submit(
    String formId,
    Map<String, String> fields,
  ) async {
    final uri = Uri.parse(
      'https://docs.google.com/forms/d/e/$formId/formResponse',
    );
    final request = await _client.postUrl(uri).timeout(_timeout);
    request.followRedirects = false;
    request.headers.contentType =
        ContentType('application', 'x-www-form-urlencoded', charset: 'utf-8');
    request.headers.set(HttpHeaders.acceptHeader, 'text/html');
    request.write(fields.entries
        .map((entry) =>
            '${Uri.encodeQueryComponent(entry.key)}=${Uri.encodeQueryComponent(entry.value)}')
        .join('&'));

    var response = await request.close().timeout(_timeout);
    if (response.isRedirect) {
      final location = response.headers.value(HttpHeaders.locationHeader);
      await response.drain();
      if (location == null || location.isEmpty) {
        throw const HttpException(
          'Google Forms mengirim redirect tanpa alamat tujuan.',
        );
      }
      final redirected = await _client
          .getUrl(uri.resolve(location))
          .timeout(_timeout);
      response = await redirected.close().timeout(_timeout);
    }
    final body = await utf8.decoder.bind(response).join();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Google Forms merespons HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    // Google Forms dapat mengembalikan halaman HTML untuk jawaban diterima.
    // Jangan menganggap ini sebagai verifikasi baris spreadsheet.
    if (body.toLowerCase().contains('could not be submitted') ||
        body.toLowerCase().contains('tidak dapat dikirim')) {
      throw const HttpException('Google Forms menolak pengiriman jawaban.');
    }
  }
}
