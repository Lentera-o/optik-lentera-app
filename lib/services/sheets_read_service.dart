import 'dart:convert';
import 'dart:io';

/// Read-only access to the published OPTIK LENTERA spreadsheet.
/// This service never writes to Sheets or calls Apps Script triggers.
class SheetsReadService {
  SheetsReadService._();

  static const String spreadsheetId =
      '1umMSjgI7T124eT8vaEHqrNsXSmDr2snJM6kEBs-6xz0';
  static const Duration timeout = Duration(seconds: 25);

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = timeout;

  /// Reads a named worksheet as CSV and maps each data row to its header.
  /// The worksheet names are the existing final tabs; no tab is created,
  /// renamed, or modified by this request.
  static Future<List<Map<String, String>>> readTable(
    String worksheetName,
  ) async {
    final uri = Uri.https(
      'docs.google.com',
      '/spreadsheets/d/$spreadsheetId/gviz/tq',
      <String, String>{
        'tqx': 'out:csv',
        'sheet': worksheetName,
      },
    );

    final request = await _client.getUrl(uri).timeout(timeout);
    request.headers.set(HttpHeaders.acceptHeader, 'text/csv,text/plain');
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join();

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpException(
        'Google Sheets mengembalikan HTTP ${response.statusCode}.',
        uri: uri,
      );
    }
    if (body.trim().isEmpty || body.trimLeft().startsWith('<!DOCTYPE html')) {
      throw const FormatException(
        'Spreadsheet tidak mengembalikan CSV. Periksa akses Viewer publik.',
      );
    }

    final rows = _parseCsv(body);
    if (rows.isEmpty) return const [];

    final headers = rows.first
        .map((value) => value.replaceFirst(RegExp(r'^\\uFEFF'), '').trim())
        .toList(growable: false);
    if (headers.every((header) => header.isEmpty)) {
      throw const FormatException('Baris judul kolom spreadsheet kosong.');
    }

    return rows.skip(1).where((row) => row.any((v) => v.trim().isNotEmpty)).map(
      (row) {
        final record = <String, String>{};
        for (var i = 0; i < headers.length; i++) {
          final key = headers[i];
          if (key.isNotEmpty) record[key] = i < row.length ? row[i].trim() : '';
        }
        return record;
      },
    ).toList(growable: false);
  }

  /// Small RFC-4180-compatible CSV reader (quoted commas, quotes and newlines).
  static List<List<String>> _parseCsv(String input) {
    final result = <List<String>>[];
    var row = <String>[];
    final field = StringBuffer();
    var quoted = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];
      if (quoted) {
        if (char == '"') {
          if (i + 1 < input.length && input[i + 1] == '"') {
            field.write('"');
            i++;
          } else {
            quoted = false;
          }
        } else {
          field.write(char);
        }
      } else if (char == '"' && field.isEmpty) {
        quoted = true;
      } else if (char == ',') {
        row.add(field.toString());
        field.clear();
      } else if (char == '\\n' || char == '\\r') {
        if (char == '\\r' && i + 1 < input.length && input[i + 1] == '\\n') {
          i++;
        }
        row.add(field.toString());
        field.clear();
        result.add(row);
        row = <String>[];
      } else {
        field.write(char);
      }
    }

    if (field.isNotEmpty || row.isNotEmpty) {
      row.add(field.toString());
      result.add(row);
    }
    return result;
  }
}
