import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Fast, read-only access to the published OPTIK LENTERA spreadsheet.
/// Uses short-lived cache + in-flight request sharing to avoid duplicate downloads.
class SheetsReadService {
  SheetsReadService._();

  static const String spreadsheetId =
      '1umMSjgI7T124eT8vaEHqrNsXSmDr2snJM6kEBs-6xz0';
  static const Duration timeout = Duration(seconds: 18);
  static const Duration cacheTtl = Duration(seconds: 10);

  static final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..idleTimeout = const Duration(seconds: 30)
    ..maxConnectionsPerHost = 6
    ..autoUncompress = true;

  static final Map<String, _CachedTable> _cache = {};
  static final Map<String, Future<List<Map<String, String>>>> _inFlight = {};

  /// Reads a worksheet. Normal screen reads reuse fresh data for 10 seconds.
  /// Set [forceRefresh] for transaction verification and explicit refresh actions.
  static Future<List<Map<String, String>>> readTable(
    String worksheetName, {
    bool forceRefresh = false,
  }) async {
    final key = worksheetName.trim();
    if (key.isEmpty) throw ArgumentError.value(worksheetName, 'worksheetName');

    final cached = _cache[key];
    if (!forceRefresh && cached != null &&
        DateTime.now().difference(cached.savedAt) < cacheTtl) {
      return cached.rows;
    }

    // Normal reads may share an in-flight request. An explicit refresh must
    // wait for an older request to finish, then fetch again so it cannot return
    // a snapshot that started before a newly submitted transaction.
    final pending = _inFlight[key];
    if (pending != null) {
      if (!forceRefresh) return pending;
      try { await pending; } catch (_) { /* Start a clean retry below. */ }
      // The old request may still be registered for one microtask after it
      // completes. Reuse only a genuinely newer request, never that old one.
      final current = _inFlight[key];
      if (current != null && !identical(current, pending)) return current;
    }

    final future = _downloadTable(key, cacheBust: forceRefresh);
    _inFlight[key] = future;
    try {
      final rows = await future;
      _cache[key] = _CachedTable(DateTime.now(), rows);
      return rows;
    } finally {
      if (identical(_inFlight[key], future)) _inFlight.remove(key);
    }
  }

  static Future<List<Map<String, String>>> _downloadTable(
    String worksheetName, {
    bool cacheBust = false,
  }) async {
    final query = <String, String>{
      'tqx': 'out:csv',
      'sheet': worksheetName,
    };
    // A unique URL prevents intermediary caches from serving the pre-submit CSV.
    if (cacheBust) {
      query['_refresh'] = DateTime.now().microsecondsSinceEpoch.toString();
    }
    final uri = Uri.https(
      'docs.google.com',
      '/spreadsheets/d/$spreadsheetId/gviz/tq',
      query,
    );

    final request = await _client.getUrl(uri).timeout(timeout);
    request.headers
      ..set(HttpHeaders.acceptHeader, 'text/csv,text/plain')
      ..set(HttpHeaders.acceptEncodingHeader, 'gzip')
      ..set(HttpHeaders.cacheControlHeader, 'no-cache, no-store, max-age=0')
      ..set(HttpHeaders.pragmaHeader, 'no-cache');
    final response = await request.close().timeout(timeout);
    final body = await utf8.decoder.bind(response).join().timeout(timeout);

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
        .map((value) => value.replaceFirst(RegExp(r'^\uFEFF'), '').trim())
        .toList(growable: false);
    if (headers.every((header) => header.isEmpty)) {
      throw const FormatException('Baris judul kolom spreadsheet kosong.');
    }

    final records = rows.skip(1)
        .where((row) => row.any((value) => value.trim().isNotEmpty))
        .map((row) {
          final record = <String, String>{};
          for (var i = 0; i < headers.length; i++) {
            final key = headers[i];
            if (key.isNotEmpty) {
              record[key] = i < row.length ? row[i].trim() : '';
            }
          }
          return Map<String, String>.unmodifiable(record);
        }).toList(growable: false);

    return List<Map<String, String>>.unmodifiable(records);
  }

  /// Clear cached rows after an explicit user refresh if required.
  static void clearCache([String? worksheetName]) {
    if (worksheetName == null) {
      _cache.clear();
    } else {
      _cache.remove(worksheetName.trim());
    }
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
      } else if (char == '\n' || char == '\r') {
        if (char == '\r' && i + 1 < input.length && input[i + 1] == '\n') {
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

class _CachedTable {
  const _CachedTable(this.savedAt, this.rows);
  final DateTime savedAt;
  final List<Map<String, String>> rows;
}
