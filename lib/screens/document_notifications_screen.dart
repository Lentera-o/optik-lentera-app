import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/api_service.dart';

const Color _noticeGold = Color(0xFF80612F);
const Color _noticeCream = Color(0xFFFAF7F0);
const Color _noticeInk = Color(0xFF39342F);
const Color _noticePink = Color(0xFFF7E8EA);

class DocumentNotice {
  final String id;
  final String type;
  final String number;
  final String customer;
  final String date;
  final String url;

  const DocumentNotice({
    required this.id,
    required this.type,
    required this.number,
    required this.customer,
    required this.date,
    required this.url,
  });
}

class DocumentNotificationsScreen extends StatefulWidget {
  const DocumentNotificationsScreen({super.key});

  @override
  State<DocumentNotificationsScreen> createState() => _DocumentNotificationsScreenState();
}

class _DocumentNotificationsScreenState extends State<DocumentNotificationsScreen> {
  static const _readKey = 'ol_document_notice_read_ids';
  final Set<String> _readIds = {};
  List<DocumentNotice> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String _first(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim() ?? '';
      if (value.isNotEmpty && value.toLowerCase() != 'null') return value;
    }
    return '';
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      _readIds
        ..clear()
        ..addAll(prefs.getStringList(_readKey) ?? const <String>[]);
      final tables = await Future.wait([
        ApiService.readTable('DATA_PESANAN'),
        ApiService.readTable('DATA_PEMBAYARAN'),
      ]);
      final items = <DocumentNotice>[];
      for (final row in tables[0]) {
        final number = _first(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice', 'Invoice']);
        if (number.isEmpty) continue;
        final url = _first(row, ['Link Invoice PDF', 'PDF Invoice', 'Link PDF Invoice']);
        items.add(DocumentNotice(
          id: 'invoice:$number',
          type: 'Invoice',
          number: number,
          customer: _first(row, ['Nama pelanggan', 'Nama Pelanggan', 'Nama']),
          date: _first(row, ['Tanggal', 'Tanggal Pesanan', 'Cap waktu', 'Timestamp']),
          url: url,
        ));
      }
      for (final row in tables[1]) {
        final number = _first(row, ['No Kuitansi', 'Nomor Kuitansi', 'Nomor kuitansi']);
        if (number.isEmpty) continue;
        final url = _first(row, ['PDF Kuitansi', 'Link PDF Kuitansi', 'Link Kuitansi', 'Link Kuitansi PDF']);
        items.add(DocumentNotice(
          id: 'receipt:$number',
          type: 'Kuitansi',
          number: number,
          customer: _first(row, ['Nama', 'Nama Pelanggan', 'Nama pelanggan']),
          date: _first(row, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran', 'Waktu', 'Timestamp']),
          url: url,
        ));
      }
      items.sort((a, b) => b.id.compareTo(a.id));
      if (!mounted) return;
      setState(() { _items = items; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _markRead(DocumentNotice item) async {
    _readIds.add(item.id);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_readKey, _readIds.toList());
    if (mounted) setState(() {});
  }

  Future<void> _open(DocumentNotice item) async {
    await _markRead(item);
    final uri = Uri.tryParse(item.url);
    if (uri == null || !uri.hasScheme || !(uri.scheme == 'https' || uri.scheme == 'http')) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan PDF belum tersedia di Google Sheets.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PDF tidak dapat dibuka. Periksa koneksi internet.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final unread = _items.where((item) => !_readIds.contains(item.id)).length;
    return Scaffold(
      backgroundColor: _noticeCream,
      appBar: AppBar(
        backgroundColor: _noticeCream,
        foregroundColor: _noticeGold,
        title: const Text('Notifikasi Dokumen', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(
            tooltip: 'Periksa dokumen terbaru',
            onPressed: _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _noticeGold))
          : _error != null
              ? _errorView()
              : _items.isEmpty
                  ? _emptyView()
                  : RefreshIndicator(
                      color: _noticeGold,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFF80612F), Color(0xFFB99555)],
                              ),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Row(children: [
                              const Icon(Icons.notifications_active_outlined, color: Colors.white, size: 28),
                              const SizedBox(width: 12),
                              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text('Dokumen pesanan & pembayaran', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                                const SizedBox(height: 3),
                                Text('$unread belum dibaca • ${_items.length} dokumen tercatat', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                              ])),
                            ]),
                          ),
                          const SizedBox(height: 14),
                          for (final item in _items) _noticeCard(item),
                        ],
                      ),
                    ),
    );
  }

  Widget _noticeCard(DocumentNotice item) {
    final isRead = _readIds.contains(item.id);
    final isInvoice = item.type == 'Invoice';
    return Card(
      color: Colors.white,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(17),
        side: BorderSide(color: isRead ? _noticeGold.withValues(alpha: .14) : _noticeGold.withValues(alpha: .38)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(color: _noticePink, borderRadius: BorderRadius.circular(13)),
            child: Icon(isInvoice ? Icons.receipt_long_outlined : Icons.payments_outlined, color: _noticeGold),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(item.type, style: const TextStyle(color: _noticeInk, fontWeight: FontWeight.w800))),
              if (!isRead) Container(width: 8, height: 8, decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle)),
            ]),
            const SizedBox(height: 3),
            Text(item.number, style: const TextStyle(color: _noticeGold, fontWeight: FontWeight.w700, fontSize: 12)),
            if (item.customer.isNotEmpty) Text(item.customer, style: const TextStyle(color: _noticeInk, fontSize: 12)),
            if (item.date.isNotEmpty) Text(item.date, style: const TextStyle(color: Colors.black54, fontSize: 10)),
            const SizedBox(height: 9),
            OutlinedButton.icon(
              onPressed: () => _open(item),
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 17),
              label: Text(item.url.isEmpty ? 'PDF belum tersedia' : 'Periksa PDF'),
              style: OutlinedButton.styleFrom(
                foregroundColor: _noticeGold,
                minimumSize: const Size(0, 36),
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
          ])),
        ]),
      ),
    );
  }

  Widget _errorView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.cloud_off_outlined, color: _noticeGold, size: 42),
        const SizedBox(height: 12),
        const Text('Notifikasi belum dapat dimuat', style: TextStyle(color: _noticeInk, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54, fontSize: 12)),
        const SizedBox(height: 14),
        FilledButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
      ]),
    ),
  );

  Widget _emptyView() => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(mainAxisSize: MainAxisSize.min, children: const [
        Icon(Icons.notifications_none_rounded, color: _noticeGold, size: 54),
        SizedBox(height: 12),
        Text('Belum ada dokumen', style: TextStyle(color: _noticeInk, fontWeight: FontWeight.w800, fontSize: 16)),
        SizedBox(height: 6),
        Text('Invoice dan kuitansi dari Google Sheets akan muncul di sini.', textAlign: TextAlign.center, style: TextStyle(color: Colors.black54, fontSize: 12)),
      ]),
    ),
  );
}
