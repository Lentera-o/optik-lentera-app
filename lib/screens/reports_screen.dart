import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cross_file/cross_file.dart';
import 'package:share_plus/share_plus.dart';
import '../services/sheets_read_service.dart';

const _gold = Color(0xFFB99555);
const _dark = Color(0xFF80612F);
const _ink = Color(0xFF39342F);

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});
  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  List<Map<String, String>> orders = [];
  List<Map<String, String>> payments = [];
  bool loading = true;
  bool monthly = false;
  String? error;
  DateTime selected = DateTime.now();

  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  String cell(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      for (final e in row.entries) {
        if (norm(e.key) == norm(alias) && e.value.trim().isNotEmpty) return e.value.trim();
      }
    }
    return '';
  }
  int money(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  DateTime? parseDate(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final iso = DateTime.tryParse(s);
    if (iso != null) return DateTime(iso.year, iso.month, iso.day);
    final m = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(s);
    if (m == null) return null;
    final a = int.parse(m.group(1)!);
    final b = int.parse(m.group(2)!);
    var y = int.parse(m.group(3)!);
    if (y < 100) y += 2000;
    // The sheet's Indonesian date convention is day/month/year.
    return DateTime(y, b, a);
  }
  DateTime? rowDate(Map<String, String> row, bool payment) {
    final aliases = payment
      ? ['Tanggal Bayar', 'Tanggal Pembayaran', 'Tanggal', 'Timestamp', 'Cap waktu']
      : ['Tanggal Pesanan', 'Tanggal Order', 'Tanggal', 'Timestamp', 'Cap waktu'];
    for (final a in aliases) {
      final d = parseDate(cell(row, [a]));
      if (d != null) return d;
    }
    return null;
  }
  Future<void> load() async {
    setState(() { loading = true; error = null; });
    try {
      final data = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      if (!mounted) return;
      setState(() { orders = data[0]; payments = data[1]; loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { error = e.toString(); loading = false; });
    }
  }
  bool inPeriod(DateTime? d) => d != null && d.year == selected.year &&
    d.month == selected.month && (monthly || d.day == selected.day);
  int orderTotal(Map<String, String> r) => money(cell(r, ['Total', 'Total Harga', 'Total Tagihan']));
  int paymentAmount(Map<String, String> r) => money(cell(r, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Nominal', 'Total Bayar']));
  int balance(Map<String, String> r) {
    final explicit = cell(r, ['Sisa Tagihan', 'Sisa']);
    if (explicit.isNotEmpty) return money(explicit);
    return (orderTotal(r) - money(cell(r, ['Total Dibayar', 'Total Dibayar Kumulatif']))).clamp(0, orderTotal(r));
  }
  String rp(int n) => 'Rp ${n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.')}';
  String label() => monthly
    ? '${selected.month.toString().padLeft(2, '0')}/${selected.year}'
    : '${selected.day.toString().padLeft(2, '0')}/${selected.month.toString().padLeft(2, '0')}/${selected.year}';

  String _csvValue(String value) {
    var safe = value.replaceAll('\r', ' ').replaceAll('\n', ' ');
    if (RegExp(r'^\s*[=+@]').hasMatch(safe) ||
        RegExp(r'^\s*-[0-9]').hasMatch(safe)) {
      safe = "'$safe";
    }
    return '"' + safe.replaceAll('"', '""') + '"';
  }

  Future<void> exportReport(List<Map<String, String>> periodOrders,
      List<Map<String, String>> periodPayments) async {
    if (periodOrders.isEmpty && periodPayments.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada data pada periode ini untuk diekspor.')),
      );
      return;
    }
    try {
      final orderHeaders = <String>{};
      final paymentHeaders = <String>{};
      for (final row in periodOrders) { orderHeaders.addAll(row.keys); }
      for (final row in periodPayments) { paymentHeaders.addAll(row.keys); }
      final headers = <String>['Jenis Data', ...orderHeaders, ...paymentHeaders.where((h) => !orderHeaders.contains(h))];
      final lines = <String>[headers.map(_csvValue).join(',')];
      void appendRow(String type, Map<String, String> row) {
        lines.add([
          _csvValue(type),
          ...headers.skip(1).map((header) => _csvValue(row[header] ?? '')),
        ].join(','));
      }
      for (final row in periodOrders) { appendRow('PESANAN', row); }
      for (final row in periodPayments) { appendRow('PEMBAYARAN', row); }

      final summary = [
        'LAPORAN OPTIK LENTERA',
        'Periode,' + label(),
        'Jumlah Order,' + periodOrders.length.toString(),
        'Nilai Penjualan,' + salesFor(periodOrders),
        'Jumlah Pembayaran,' + periodPayments.length.toString(),
        'Uang Masuk,' + receivedFor(periodPayments),
        '',
        ...lines,
      ].join('\r\n');
      final bytes = <int>[0xEF, 0xBB, 0xBF, ...utf8.encode(summary)];
      final mode = monthly ? 'Bulanan' : 'Harian';
      final safeLabel = label().replaceAll('/', '-');
      final fileName = 'Laporan_Optik_Lentera_' + mode + '_' + safeLabel + '.csv';
      await SharePlus.instance.share(ShareParams(
        files: [XFile.fromData(bytes, mimeType: 'text/csv', name: fileName)],
        fileNameOverrides: [fileName],
        subject: 'Laporan Optik Lentera $mode $safeLabel',
        text: 'Ekspor laporan Optik Lentera periode $safeLabel.',
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ekspor laporan gagal: $e')),
      );
    }
  }

  String salesFor(List<Map<String, String>> rows) =>
      rows.fold<int>(0, (sum, row) => sum + orderTotal(row)).toString();
  String receivedFor(List<Map<String, String>> rows) =>
      rows.fold<int>(0, (sum, row) => sum + paymentAmount(row)).toString();

  Future<void> pickDate() async {
    final d = await showDatePicker(context: context, initialDate: selected,
      firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null && mounted) setState(() => selected = d);
  }
  Widget metric(String title, String value, IconData icon) => Expanded(
    child: Container(padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _gold.withValues(alpha: .22))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: _dark), const SizedBox(height: 8),
        FittedBox(alignment: Alignment.centerLeft, child: Text(value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _ink))),
        Text(title, style: const TextStyle(fontSize: 10, color: Colors.black54)),
      ])));
  @override
  void initState() { super.initState(); load(); }

  @override
  Widget build(BuildContext context) {
    final periodOrders = orders.where((r) =>
      cell(r, ['No Invoice', 'Nomor Invoice', 'Invoice']).isNotEmpty &&
      inPeriod(rowDate(r, false))).toList();
    final periodPayments = payments.where((r) => inPeriod(rowDate(r, true))).toList();
    final sales = periodOrders.fold<int>(0, (s, r) => s + orderTotal(r));
    final received = periodPayments.fold<int>(0, (s, r) => s + paymentAmount(r));
    final balanceTotal = periodOrders.fold<int>(0, (s, r) => s + balance(r));
    final daily = <DateTime, List<Map<String, String>>>{};
    if (monthly) {
      for (final r in periodOrders) {
        final d = rowDate(r, false);
        if (d != null) daily.putIfAbsent(d, () => []).add(r);
      }
    }
    final days = daily.keys.toList()..sort();

    return RefreshIndicator(onRefresh: load, child: ListView(padding: const EdgeInsets.all(18), children: [
      Container(padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xFFFFFCF7), Color(0xFFF8EEF0)]),
          borderRadius: BorderRadius.circular(18), border: Border.all(color: _gold.withValues(alpha: .2))),
        child: const Row(children: [
          Icon(Icons.insights_rounded, color: _dark, size: 30), SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('LAPORAN OPERASIONAL', style: TextStyle(color: _dark, fontWeight: FontWeight.w800)),
            Text('Rekap resmi dari Google Sheets', style: TextStyle(color: Colors.black54, fontSize: 10)),
          ])),
        ])),
      const SizedBox(height: 14),
      SegmentedButton<bool>(segments: const [
        ButtonSegment(value: false, label: Text('Harian'), icon: Icon(Icons.today_outlined)),
        ButtonSegment(value: true, label: Text('Bulanan'), icon: Icon(Icons.calendar_month_outlined)),
      ], selected: {monthly}, onSelectionChanged: (v) => setState(() => monthly = v.first)),
      const SizedBox(height: 8),
      OutlinedButton.icon(onPressed: pickDate, icon: const Icon(Icons.calendar_today), label: Text(label())),
      if (loading) const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()))
      else if (error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
        const Text('Laporan belum dapat dimuat.'), Text(error!, style: const TextStyle(color: Colors.deepOrange, fontSize: 11)),
        TextButton.icon(onPressed: load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
      ])))
      else ...[
        const SizedBox(height: 8),
        Text('Ringkasan ${monthly ? 'bulan' : 'tanggal'} ${label()}',
          style: const TextStyle(fontWeight: FontWeight.w800, color: _ink)),
        const SizedBox(height: 9),
        Row(children: [metric('Jumlah order', '${periodOrders.length}', Icons.shopping_bag_outlined),
          const SizedBox(width: 9), metric('Uang masuk', rp(received), Icons.payments_outlined)]),
        const SizedBox(height: 12),
        SizedBox(width: double.infinity, child: FilledButton.icon(
          onPressed: () => exportReport(periodOrders, periodPayments),
          icon: const Icon(Icons.download_rounded),
          label: const Text('Unduh / Ekspor Data Laporan (CSV)'),
          style: FilledButton.styleFrom(backgroundColor: _dark, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14)),
        )),
        const SizedBox(height: 9),
        Row(children: [metric('Nilai penjualan', rp(sales), Icons.point_of_sale_outlined),
          const SizedBox(width: 9), metric('Sisa tagihan order', rp(balanceTotal), Icons.account_balance_wallet_outlined)]),
        if (monthly) ...[
          const SizedBox(height: 18),
          const Text('REKAP ORDER PER HARI', style: TextStyle(fontWeight: FontWeight.w800, color: _dark, fontSize: 12)),
          if (days.isEmpty) const Text('Belum ada order pada bulan ini.')
          else ...days.map((d) {
            final rows = daily[d]!;
            return Card(color: Colors.white, child: ListTile(dense: true,
              title: Text('${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}'),
              subtitle: Text('${rows.length} order'),
              trailing: Text(rp(rows.fold<int>(0, (s, r) => s + orderTotal(r))),
                style: const TextStyle(fontWeight: FontWeight.w700, color: _dark))));
          }),
        ],
        const SizedBox(height: 18),
        const Text('RINCIAN ORDER', style: TextStyle(fontWeight: FontWeight.w800, color: _dark, fontSize: 12)),
        if (periodOrders.isEmpty) const Text('Tidak ada order pada periode ini.')
        else ...periodOrders.map((r) => Card(color: Colors.white, child: ListTile(
          leading: const Icon(Icons.receipt_long_outlined, color: _dark),
          title: Text(cell(r, ['Nama Pelanggan', 'Nama', 'Pelanggan'])),
          subtitle: Text(cell(r, ['No Invoice', 'Nomor Invoice', 'Invoice'])),
          trailing: Text(rp(orderTotal(r)), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ))),
        const SizedBox(height: 18),
        const Text('PEMBAYARAN MASUK', style: TextStyle(fontWeight: FontWeight.w800, color: _dark, fontSize: 12)),
        if (periodPayments.isEmpty) const Text('Tidak ada pembayaran pada periode ini.')
        else ...periodPayments.map((r) => Card(color: Colors.white, child: ListTile(
          leading: const Icon(Icons.payments_outlined, color: _dark),
          title: Text(cell(r, ['No Invoice', 'Nomor Invoice', 'Invoice']).isEmpty ? 'Pembayaran' : cell(r, ['No Invoice', 'Nomor Invoice', 'Invoice'])),
          subtitle: Text(cell(r, ['Metode', 'Metode Pembayaran'])),
          trailing: Text(rp(paymentAmount(r)), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
        ))),
        const SizedBox(height: 12),
        const Text('Tarik layar ke bawah atau tekan sinkronisasi untuk mengambil data terbaru.',
          style: TextStyle(fontSize: 10, color: Colors.black54)),
        Align(alignment: Alignment.centerRight, child: TextButton.icon(
          onPressed: load, icon: const Icon(Icons.sync), label: const Text('Sinkronkan'))),
      ],
    ]));
  }
}
