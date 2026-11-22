import 'dart:async';

import 'api_service.dart';

/// Read-only access to OPTIK LENTERA operational tables using the app API key.
class SheetsReadService {
  SheetsReadService._();

  static const String spreadsheetId =
      '1umMSjgI7T124eT8vaEHQRNsXSmDr2snJM6kEBs-6xz0';
  static const Duration cacheTtl = Duration(seconds: 10);

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
    if (worksheetName != 'DATA_PESANAN' && worksheetName != 'DATA_PEMBAYARAN' && worksheetName != 'DATA_PEMERIKSAAN') {
      throw ArgumentError.value(worksheetName, 'worksheetName', 'Tab tidak diizinkan');
    }
    final response = await ApiService.postAuthorizedRead(
      action: 'readTable',
      data: {'sheetName': worksheetName},
    );
    if (!response.isSuccessful) {
      throw StateError(response.errorMessage ?? 'Gagal membaca data resmi OPTIK LENTERA.');
    }
    final payload = response.data;
    if (payload is! Map || payload['rows'] is! List) {
      throw const FormatException('Respons pembacaan Apps Script tidak sesuai format.');
    }
    final records = (payload['rows'] as List).map((item) {
      if (item is! Map) throw const FormatException('Baris spreadsheet tidak valid.');
      return Map<String, String>.unmodifiable(
        item.map((key, value) => MapEntry(key.toString(), value?.toString() ?? '')),
      );
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


}

class _CachedTable {
  const _CachedTable(this.savedAt, this.rows);
  final DateTime savedAt;
  final List<Map<String, String>> rows;
}
