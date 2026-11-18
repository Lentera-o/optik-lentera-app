import 'package:flutter_test/flutter_test.dart';
import 'package:optik_lentera/services/api_service.dart';
import 'package:optik_lentera/services/sheets_read_service.dart';

void main() {
  test('uses the verified OPTIK LENTERA operational spreadsheet ID', () {
    expect(SheetsReadService.spreadsheetId,
        '1umMSjgI7T124eT8vaEHQRNsXSmDr2snJM6kEBs-6xz0');
  });

  group('ApiResponse', () {
    test('HTTP success with Apps Script ok true is successful', () {
      const response = ApiResponse(
        statusCode: 200,
        rawBody: '{"ok":true,"invoice":"INV-TEST"}',
        data: {'ok': true, 'invoice': 'INV-TEST'},
      );

      expect(response.isSuccessful, isTrue);
      expect(response.errorMessage, isNull);
    });

    test('HTTP 200 with Apps Script ok false is an application failure', () {
      const response = ApiResponse(
        statusCode: 200,
        rawBody: '{"ok":false,"error":"Invoice sudah lunas."}',
        data: {'ok': false, 'error': 'Invoice sudah lunas.'},
      );

      expect(response.isSuccessful, isFalse);
      expect(response.errorMessage, 'Invoice sudah lunas.');
    });

    test('HTTP error is unsuccessful even without an API error payload', () {
      const response = ApiResponse(
        statusCode: 503,
        rawBody: 'Service unavailable',
        data: 'Service unavailable',
      );

      expect(response.isSuccessful, isFalse);
      expect(response.errorMessage, isNull);
    });
  });
}
