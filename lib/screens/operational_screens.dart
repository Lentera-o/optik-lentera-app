import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pdf_service.dart';
import '../models/optik_models.dart';
import '../services/api_service.dart';
import '../services/sheets_read_service.dart';

const _gold = Color(0xFFB99555);
const _darkGold = Color(0xFF80612F);
const _ink = Color(0xFF39342F);

class CustomerScreen extends StatefulWidget {
  final List<Customer> customers;
  final ValueChanged<Customer> onAdd;
  const CustomerScreen({super.key, required this.customers, required this.onAdd});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  final name = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();

  @override
  void dispose() { name.dispose(); phone.dispose(); address.dispose(); super.dispose(); }

  void save() {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama pelanggan wajib diisi.')));
      return;
    }
    widget.onAdd(Customer(name: name.text.trim(), phone: phone.text.trim(), address: address.text.trim()));
    name.clear(); phone.clear(); address.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelanggan ditambahkan untuk sesi ini.')));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const _Intro('Data Pelanggan', 'Catat identitas dan kontak pelanggan.', Icons.people_outline),
    const SizedBox(height: 16),
    _Panel(child: Column(children: [
      _field(name, 'Nama pelanggan *'),
      _field(phone, 'Nomor WhatsApp / telepon', type: TextInputType.phone),
      _field(address, 'Alamat'),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _darkGold),
        onPressed: save, icon: const Icon(Icons.person_add_alt_1), label: const Text('Tambah pelanggan'),
      )),
    ])),
    const SizedBox(height: 18),
    Text('Daftar pelanggan: ${widget.customers.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
    if (widget.customers.isEmpty)
      const _Empty('Belum ada pelanggan di sesi ini.')
    else
      ...widget.customers.reversed.map((c) => Card(color: Colors.white, child: ListTile(
        leading: const Icon(Icons.person_outline, color: _darkGold),
        title: Text(c.name),
        subtitle: Text([c.phone, c.address].where((v) => v.isNotEmpty).join(' • ')),
      ))),
    const _LocalNote(),
  ]);
}

class TransactionScreen extends StatefulWidget {
  final List<Customer> customers;
  final List<OptikOrder> orders;
  final ValueChanged<OptikOrder> onAdd;
  const TransactionScreen({super.key, required this.customers, required this.orders, required this.onAdd});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final customer = TextEditingController();
  final phone = TextEditingController();
  final address = TextEditingController();
  final doctor = TextEditingController();
  final lensType = TextEditingController();
  final rxNote = TextEditingController();
  final frameDescription = TextEditingController();
  final frame = TextEditingController();
  final lensDescription = TextEditingController();
  final lens = TextEditingController();
  final otherPrice = TextEditingController();
  final otherDescription = TextEditingController();
  final dp = TextEditingController();
  final invoiceNote = TextEditingController();
  final odSph = TextEditingController();
  final odCyl = TextEditingController();
  final odAxis = TextEditingController();
  final odAdd = TextEditingController();
  final odPd = TextEditingController();
  final osSph = TextEditingController();
  final osCyl = TextEditingController();
  final osAxis = TextEditingController();
  final osAdd = TextEditingController();
  final osPd = TextEditingController();
  String method = 'Tunai';
  int? selectedCustomerIndex;

  void selectSavedCustomer(int? index) {
    setState(() {
      selectedCustomerIndex = index;
      if (index != null && index >= 0 && index < widget.customers.length) {
        final selected = widget.customers[index];
        customer.text = selected.name;
        phone.text = selected.phone;
        address.text = selected.address;
      }
    });
  }

  bool submitting = false;

  int amount(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    for (final c in [customer, phone, address, doctor, lensType, rxNote, frameDescription, frame, lensDescription, lens, otherPrice, otherDescription, dp, invoiceNote, odSph, odCyl, odAxis, odAdd, odPd, osSph, osCyl, osAxis, osAdd, osPd]) { c.dispose(); }
    super.dispose();
  }

  Future<void> save() async {
    if (submitting) return;
    final total = amount(frame) + amount(lens) + amount(otherPrice);
    if (customer.text.trim().isEmpty || total <= 0 || amount(dp) > total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Periksa nama pelanggan, harga, dan nominal DP.')));
      return;
    }
    setState(() => submitting = true);
    final opened = await ApiService.openOrderForm({
      '1324477027': customer.text,
      '539015243': phone.text,
      '1777754745': address.text,
      '542463507': doctor.text,
      '1271316087': odSph.text,
      '1616866281': odCyl.text,
      '1784427947': odAxis.text,
      '1558365892': odAdd.text,
      '940199491': odPd.text,
      '480078014': osSph.text,
      '66061879': osCyl.text,
      '493870905': osAxis.text,
      '42654846': osAdd.text,
      '950234578': osPd.text,
      '684419252': lensType.text,
      '1481958730': rxNote.text,
      '686343109': frameDescription.text,
      '1727076794': amount(frame).toString(),
      '1326678958': lensDescription.text,
      '97131819': amount(lens).toString(),
      '2101353430': otherDescription.text,
      '1643782415': amount(otherPrice).toString(),
      '1449005528': amount(dp).toString(),
      '1188539863': invoiceNote.text,
      '1492024415': method,
    });
    if (!mounted) return;
    setState(() => submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? 'Pesanan berhasil dikirim ke sistem resmi. Nomor invoice akan dibuat oleh Apps Script.'
          : 'Pesanan belum terkonfirmasi terkirim. Periksa koneksi dan coba lagi.'),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const _Intro('Pemesanan & Pemeriksaan', 'Input pesanan dan resep mata OD/OS.', Icons.receipt_long_outlined),
    const SizedBox(height: 16),
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (widget.customers.isNotEmpty) ...[
        DropdownButtonFormField<int>(
          value: selectedCustomerIndex,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Pilih pelanggan tersimpan',
            helperText: 'Pilih data yang sudah dicatat agar tidak mengetik ulang.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: List.generate(widget.customers.length, (index) {
            final item = widget.customers[index];
            return DropdownMenuItem<int>(
              value: index,
              child: Text(item.name, overflow: TextOverflow.ellipsis),
            );
          }),
          onChanged: selectSavedCustomer,
        ),
        const SizedBox(height: 12),
      ] else
        const Text('Belum ada pelanggan tersimpan. Isi data pelanggan secara manual atau tambahkan melalui menu Pelanggan.'),
      _field(customer, 'Nama pelanggan *'),
      _field(phone, 'Nomor WhatsApp / telepon', type: TextInputType.phone),
      _field(address, 'Alamat pelanggan'),
      _field(doctor, 'Dokter / optometris'),
      const Text('Resep OD — mata kanan', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
      Row(children: [
        Expanded(child: _field(odSph, 'SPH')), const SizedBox(width: 6),
        Expanded(child: _field(odCyl, 'CYL')), const SizedBox(width: 6),
        Expanded(child: _field(odAxis, 'AXIS')),
      ]),
      Row(children: [Expanded(child: _field(odAdd, 'ADD')), const SizedBox(width: 6), Expanded(child: _field(odPd, 'PD'))]),
      const Text('Resep OS — mata kiri', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
      Row(children: [
        Expanded(child: _field(osSph, 'SPH')), const SizedBox(width: 6),
        Expanded(child: _field(osCyl, 'CYL')), const SizedBox(width: 6),
        Expanded(child: _field(osAxis, 'AXIS')),
      ]),
      Row(children: [Expanded(child: _field(osAdd, 'ADD')), const SizedBox(width: 6), Expanded(child: _field(osPd, 'PD'))]),
      _field(lensType, 'Jenis lensa'),
      _field(rxNote, 'Catatan resep'),
      const SizedBox(height: 6),
      const Text('Rincian pesanan', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
      _field(frameDescription, 'Frame - merek / model / warna'),
      _field(frame, 'Harga frame (Rp)', type: TextInputType.number),
      _field(lensDescription, 'Lensa - jenis / ukuran / coating'),
      _field(lens, 'Harga lensa (Rp)', type: TextInputType.number),
      _field(otherDescription, 'Keterangan biaya lain-lain'),
      _field(otherPrice, 'Harga lain-lain (Rp)', type: TextInputType.number),
      _field(dp, 'Uang muka / DP (Rp)', type: TextInputType.number),
      _field(invoiceNote, 'Catatan tambahan untuk invoice'),
      DropdownButtonFormField<String>(
        value: method,
        decoration: InputDecoration(labelText: 'Metode DP', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
        items: const ['Tunai', 'Transfer', 'QRIS', 'Debit/kartu', 'Lainnya'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => method = v ?? 'Tunai'),
      ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _darkGold),
        onPressed: submitting ? null : save, icon: const Icon(Icons.save_outlined), label: Text(submitting ? 'Mengirim pesanan…' : 'Simpan Pesanan'),
      )),
    ])),
    const SizedBox(height: 18),
    Text('Draft pesanan: ${widget.orders.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
    ...widget.orders.reversed.map((o) => Card(color: Colors.white, child: ListTile(
      leading: const Icon(Icons.shopping_bag_outlined, color: _darkGold),
      title: Text(o.customer.name),
      subtitle: Text(o.invoiceNumber + ' • Total Rp ' + o.total.toString() + ' • Sisa Rp ' + o.remaining.toString()),
    ))),
    const _LocalNote(),
  ]);
}

class _Intro extends StatelessWidget {
  final String title, subtitle;
  final IconData icon;
  const _Intro(this.title, this.subtitle, this.icon);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [Color(0xFFFFFCF7), Color(0xFFF8EEF0)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(19),
      border: Border.all(color: _gold.withValues(alpha: .20)),
    ),
    child: Row(children: [
      Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [BoxShadow(color: _gold.withValues(alpha: .10), blurRadius: 10, offset: const Offset(0, 3))],
        ),
        child: Icon(icon, color: _darkGold, size: 25),
      ),
      const SizedBox(width: 13),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(color: _darkGold, fontWeight: FontWeight.w800, fontSize: 18, letterSpacing: .1)),
        const SizedBox(height: 3),
        Text(subtitle, style: const TextStyle(color: Color(0xFF81766E), fontSize: 11, height: 1.35)),
      ])),
    ]),
  );
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(17),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: _gold.withValues(alpha: .20)),
      boxShadow: [BoxShadow(color: _ink.withValues(alpha: .035), blurRadius: 16, offset: const Offset(0, 5))],
    ),
    child: child,
  );
}

Widget _field(TextEditingController c, String label, {TextInputType? type}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, isDense: true)),
);

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(16), child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black54)));
}

class _LocalNote extends StatelessWidget {
  const _LocalNote();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(top: 14, bottom: 12),
    child: Text('Data transaksi dikirim langsung dari aplikasi ke Google Forms resmi; trigger Apps Script tetap memprosesnya. Invoice dan kuitansi resmi dibaca dari Google Sheets.', style: TextStyle(fontSize: 11, color: Colors.black54)),
  );
}


class PaymentEntryScreen extends StatefulWidget {
  final List<OptikPayment> payments;
  final List<OptikOrder> orders;
  final ValueChanged<OptikPayment> onAdd;
  const PaymentEntryScreen({super.key, required this.payments, required this.orders, required this.onAdd});
  @override
  State<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends State<PaymentEntryScreen> {
  final invoice = TextEditingController();
  List<Map<String, String>> officialInvoices = [];
  List<Map<String, String>> officialPayments = [];
  bool loadingInvoices = false;
  String? invoiceSyncError;

  String _cell(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      for (final entry in row.entries) {
        if (entry.key.trim().toLowerCase() == alias.toLowerCase() &&
            entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  int _money(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadOfficialInvoices();
  }

  Future<void> _loadOfficialInvoices() async {
    if (mounted) setState(() {
      loadingInvoices = true;
      invoiceSyncError = null;
    });
    try {
      final tables = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN'),
        SheetsReadService.readTable('DATA_PEMBAYARAN'),
      ]);
      final rows = tables[0];
      final paymentRows = tables[1];
      final mappedPayments = paymentRows.map((row) => <String, String>{
        'invoice': _cell(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']),
        'receipt': _cell(row, ['No Kuitansi', 'Nomor Kuitansi', 'Nomor kuitansi']),
        'date': _cell(row, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran']),
        'amount': _cell(row, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Jumlah pembayaran']),
        'method': _cell(row, ['Metode', 'Metode Pembayaran', 'Metode pembayaran']),
        'note': _cell(row, ['Catatan', 'Keterangan Pembayaran', 'Catatan Pembayaran']),
      }).where((item) => item['invoice']!.isNotEmpty).toList();
      final mapped = <Map<String, String>>[];
      for (final row in rows) {
        final number = _cell(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']);
        if (number.isEmpty) continue;
        final name = _cell(row, ['Nama', 'Nama Pelanggan', 'Nama pelanggan']);
        final totalText = _cell(row, ['Total', 'Total Harga', 'Total Tagihan', 'Total harga']);
        final paidText = _cell(row, ['Total Dibayar', 'Total dibayar', 'Total Dibayar Kumulatif']);
        final remainingText = _cell(row, ['Sisa', 'Sisa Tagihan', 'Sisa tagihan']);
        final total = _money(totalText);
        final paid = _money(paidText);
        final remaining = remainingText.isNotEmpty
            ? _money(remainingText)
            : (total > 0 ? (total - paid).clamp(0, total) : 0);
        mapped.add({
          'invoice': number,
          'name': name,
          'total': total.toString(),
          'paid': paid.toString(),
          'remaining': remaining.toString(),
          'status': _cell(row, ['Status', 'Status Pembayaran']),
        });
      }
      mapped.sort((a, b) => b['invoice']!.compareTo(a['invoice']!));
      if (!mounted) return;
      setState(() {
        officialInvoices = mapped;
        officialPayments = mappedPayments;
        loadingInvoices = false;
        if (invoice.text.trim().isNotEmpty &&
            !mapped.any((item) => item['invoice'] == invoice.text.trim())) {
          invoice.clear();
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loadingInvoices = false;
        invoiceSyncError = error.toString();
      });
    }
  }
  final nominal = TextEditingController();
  final paymentNote = TextEditingController();
  DateTime paymentDate = DateTime.now();
  String method = 'Tunai';
  String category = 'DP tambahan';

  @override
  void dispose() { invoice.dispose(); nominal.dispose(); paymentNote.dispose(); super.dispose(); }

  Map<String, String>? get selectedOfficialOrder {
    for (final item in officialInvoices) {
      if (item['invoice'] == invoice.text.trim()) return item;
    }
    return null;
  }

  List<Map<String, String>> get selectedOfficialPayments =>
      officialPayments.where((item) => item['invoice'] == invoice.text.trim()).toList()
        ..sort((a, b) => (b['date'] ?? '').compareTo(a['date'] ?? ''));

  Future<void> choosePaymentDate() async {
    final picked = await showDatePicker(context: context, initialDate: paymentDate, firstDate: DateTime(2000), lastDate: DateTime(2100));
    if (picked != null && mounted) setState(() => paymentDate = picked);
  }

  bool submitting = false;

  Future<void> save() async {
    if (submitting) return;
    final value = int.tryParse(nominal.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (invoice.text.trim().isEmpty || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor invoice dan nominal pembayaran wajib diisi.')));
      return;
    }
    final date = '${paymentDate.year.toString().padLeft(4, '0')}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';
    setState(() => submitting = true);
    final opened = await ApiService.openPaymentForm({
      '1667531169': invoice.text,
      '266758159': date,
      '448728880': value.toString(),
      '1530690867': method,
      '1651033565': category,
      '284716454': paymentNote.text,
    });
    if (!mounted) return;
    setState(() => submitting = false);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(opened
          ? 'Pembayaran berhasil dikirim ke sistem resmi. Apps Script akan memvalidasi sisa tagihan.'
          : 'Pembayaran belum terkonfirmasi terkirim. Periksa koneksi dan coba lagi.'),
      duration: const Duration(seconds: 6),
    ));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const _Intro('Pembayaran', 'Catat pembayaran lanjutan sesuai nomor invoice.', Icons.payments_outlined),
    const SizedBox(height: 16),
    _Panel(child: Column(children: [
      if (officialInvoices.isNotEmpty)
        DropdownButtonFormField<String>(
          value: officialInvoices.any((item) => item['invoice'] == invoice.text)
              ? invoice.text
              : null,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: 'Pilih nomor invoice resmi *',
            helperText: 'Daftar diambil langsung dari DATA_PESANAN.',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
          ),
          items: officialInvoices.map((item) {
            final remaining = _money(item['remaining'] ?? '');
            final title = item['invoice']!;
            final customerName = item['name'] ?? '';
            return DropdownMenuItem<String>(
              value: title,
              child: Text(
                customerName.isEmpty
                    ? title
                    : '$title • $customerName • Sisa Rp $remaining',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) setState(() => invoice.text = value);
          },
        )
      else
        _field(invoice, 'Nomor invoice *'),
      if (loadingInvoices)
        const Padding(
          padding: EdgeInsets.only(bottom: 10),
          child: LinearProgressIndicator(minHeight: 2),
        ),
      if (invoiceSyncError != null)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(children: [
            Expanded(
              child: Text(
                'Daftar invoice belum tersinkron: $invoiceSyncError',
                style: const TextStyle(fontSize: 11, color: Colors.deepOrange),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang invoice',
              onPressed: _loadOfficialInvoices,
              icon: const Icon(Icons.refresh),
            ),
          ]),
        )
      else if (officialInvoices.isEmpty && !loadingInvoices)
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _loadOfficialInvoices,
            icon: const Icon(Icons.refresh),
            label: const Text('Muat ulang daftar invoice'),
          ),
        ),
      if (selectedOfficialOrder != null)
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFCF7),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _gold.withValues(alpha: .25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                selectedOfficialOrder!['name'] ?? '',
                style: const TextStyle(fontWeight: FontWeight.w800, color: _ink),
              ),
              const SizedBox(height: 5),
              Text('Total: Rp ${selectedOfficialOrder!['total']}'),
              Text('Sudah dibayar: Rp ${selectedOfficialOrder!['paid']}'),
              Text(
                'Sisa tagihan: Rp ${selectedOfficialOrder!['remaining']}',
                style: const TextStyle(fontWeight: FontWeight.w800, color: _darkGold),
              ),
              if ((selectedOfficialOrder!['status'] ?? '').isNotEmpty)
                Text('Status: ${selectedOfficialOrder!['status']}'),
              if (selectedOfficialPayments.isNotEmpty) ...[
                const Divider(height: 18),
                const Text('Riwayat kuitansi resmi', style: TextStyle(fontWeight: FontWeight.w700)),
                ...selectedOfficialPayments.take(5).map((item) => Padding(
                  padding: const EdgeInsets.only(top: 5),
                  child: Text(
                    '${item['date']} • ${item['receipt']} • Rp ${item['amount']} • ${item['method']}',
                    style: const TextStyle(fontSize: 11, color: Colors.black87),
                  ),
                )),
              ],
            ],
          ),
        ),
      ListTile(contentPadding: EdgeInsets.zero, title: const Text('Tanggal pembayaran'), subtitle: Text(paymentDate.toString().split(' ').first), trailing: const Icon(Icons.calendar_month_outlined, color: _darkGold), onTap: choosePaymentDate),
      _field(nominal, 'Nominal pembayaran (Rp) *', type: TextInputType.number),
      DropdownButtonFormField<String>(
        value: method,
        decoration: InputDecoration(labelText: 'Metode pembayaran', border: OutlineInputBorder()),
        items: const ['Tunai', 'Transfer', 'QRIS', 'Debit/kartu', 'Lainnya'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => method = v ?? 'Tunai'),
      ),
      DropdownButtonFormField<String>(value: category, decoration: InputDecoration(labelText: 'Keterangan pembayaran', border: OutlineInputBorder()), items: const ['DP tambahan', 'Cicilan', 'Pelunasan', 'Lainnya'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(), onChanged: (v) => setState(() => category = v ?? 'DP tambahan')),
      _field(paymentNote, 'Catatan pembayaran'),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _darkGold),
        onPressed: submitting ? null : save, icon: const Icon(Icons.save_outlined), label: Text(submitting ? 'Mengirim pembayaran…' : 'Simpan Pembayaran'),
      )),
    ])),
    const SizedBox(height: 18),
    Text('Pembayaran sesi ini: ${widget.payments.length}', style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
    ...widget.payments.reversed.map((p) => Card(color: Colors.white, child: ListTile(
      leading: const Icon(Icons.payments_outlined, color: _darkGold),
      title: Text('Rp ' + p.amount.toString()),
      subtitle: Text(p.invoiceNumber + ' • ' + p.method),
    ))),
    const _LocalNote(),
  ]);
}



class WhatsAppCenterScreen extends StatefulWidget {
  final List<Customer> customers;
  final List<OptikOrder> orders;
  final List<OptikPayment> payments;
  const WhatsAppCenterScreen({super.key, required this.customers, required this.orders, required this.payments});
  @override
  State<WhatsAppCenterScreen> createState() => _WhatsAppCenterScreenState();
}

class _WhatsAppCenterScreenState extends State<WhatsAppCenterScreen> {
  Customer? selectedCustomer;
  OptikOrder? selectedOrder;
  String template = 'Konfirmasi pesanan';
  final message = TextEditingController();

  @override
  void dispose() { message.dispose(); super.dispose(); }

  String _rupiah(int value) => 'Rp ' + value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  String _phoneForWhatsApp(String raw) {
    var digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0')) digits = '62' + digits.substring(1);
    if (digits.startsWith('8')) digits = '62' + digits;
    return digits;
  }

  void _chooseCustomer(Customer? customer) {
    setState(() {
      selectedCustomer = customer;
      selectedOrder = null;
      for (final order in widget.orders) {
        if (order.customer.phone == customer?.phone) { selectedOrder = order; break; }
      }
      _buildMessage();
    });
  }

  void _buildMessage() {
    final customer = selectedCustomer;
    final order = selectedOrder;
    if (customer == null) { message.text = ''; return; }
    final name = customer.name;
    final invoice = order?.invoiceNumber ?? '-';
    final orderPayments = order == null
        ? <OptikPayment>[]
        : (widget.payments.where((p) => p.invoiceNumber == order.invoiceNumber).toList()
          ..sort((a, b) => b.paymentDate.compareTo(a.paymentDate)));
    final paid = order == null
        ? 0
        : order.initialPayment + orderPayments.fold<int>(0, (sum, p) => sum + p.amount);
    final remainingAmount = order == null ? 0 : (order.total - paid).clamp(0, order.total);
    final total = order == null ? '-' : _rupiah(order.total);
    final paidText = order == null ? '-' : _rupiah(paid);
    final balance = order == null ? '-' : _rupiah(remainingAmount);
    final lastPayment = orderPayments.isEmpty ? null : orderPayments.first;
    if (template == 'Pesanan siap diambil') {
      message.text = 'Halo ' + name + ' 👋\nKami dari OPTIK LENTERA ingin menginformasikan bahwa pesanan kacamata Anda sudah siap diambil.\nNomor invoice: ' + invoice + '\nSilakan datang pada jam operasional kami. Terima kasih 🙏';
    } else if (template == 'Pengingat pembayaran') {
      message.text = 'Halo ' + name + ' 👋\nKami dari OPTIK LENTERA mengingatkan bahwa masih terdapat sisa pembayaran pesanan Anda.\nNomor invoice: ' + invoice + '\nTotal tagihan: ' + total + '\nTotal sudah dibayar: ' + paidText + '\nSisa tagihan: ' + balance + '\n' + (lastPayment == null ? '' : 'Pembayaran terakhir: ' + _rupiah(lastPayment.amount) + ' (' + lastPayment.method + ') pada ' + OptikPdfService.date(lastPayment.paymentDate) + '\n') + 'Jika sudah melakukan pembayaran, mohon abaikan pesan ini. Terima kasih 🙏';
    } else if (template == 'Tindak lanjut pelanggan') {
      message.text = 'Halo ' + name + ' 👋\nApa kabar? Kami dari OPTIK LENTERA ingin menanyakan apakah kacamata Anda nyaman digunakan. Jika ada yang perlu disesuaikan, silakan hubungi kami. Terima kasih 🙏';
    } else {
      message.text = 'Halo ' + name + ' 👋\nTerima kasih telah mempercayakan kebutuhan kacamata Anda kepada OPTIK LENTERA.\n' + (order == null ? '' : 'Nomor invoice: ' + invoice + '\nTotal pesanan: ' + total + '\nTotal dibayar: ' + paidText + '\nSisa tagihan: ' + balance + '\n') + 'Jika ada pertanyaan, silakan balas pesan ini. Terima kasih 🙏';
    }
  }


  Future<void> _openWhatsApp() async {
    final customer = selectedCustomer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih pelanggan terlebih dahulu.')));
      return;
    }
    final phone = _phoneForWhatsApp(customer.phone);
    if (phone.length < 10 || phone.length > 15) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor WhatsApp pelanggan tidak valid. Periksa nomor pada data pelanggan.')));
      return;
    }
    final uri = Uri.https('wa.me', '/' + phone, {'text': message.text});
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('WhatsApp tidak dapat dibuka pada perangkat ini.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerOptions = <Customer>{...widget.customers, ...widget.orders.map((o) => o.customer)}.toList();
    final orderOptions = widget.orders.where((o) => selectedCustomer == null || o.customer.phone == selectedCustomer!.phone).toList();
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _Intro('WhatsApp Semi-Otomatis', 'Pilih pelanggan dan template. Chat dibuka dengan pesan siap ditinjau dan dikirim oleh petugas.', Icons.chat_outlined),
        const SizedBox(height: 16),
        _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<Customer>(
            value: customerOptions.contains(selectedCustomer) ? selectedCustomer : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Pilih pelanggan', border: OutlineInputBorder()),
            items: customerOptions.map((c) => DropdownMenuItem(value: c, child: Text(c.name + ' • ' + c.phone, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: _chooseCustomer,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<OptikOrder>(
            value: orderOptions.contains(selectedOrder) ? selectedOrder : null,
            isExpanded: true,
            decoration: InputDecoration(labelText: 'Pilih invoice (opsional)', border: OutlineInputBorder()),
            items: orderOptions.map((o) => DropdownMenuItem(value: o, child: Text(o.invoiceNumber + ' • ' + o.customer.name, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: (value) => setState(() { selectedOrder = value; _buildMessage(); }),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: template,
            decoration: InputDecoration(labelText: 'Template pesan', border: OutlineInputBorder()),
            items: const ['Konfirmasi pesanan', 'Pesanan siap diambil', 'Pengingat pembayaran', 'Tindak lanjut pelanggan'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (value) => setState(() { template = value ?? 'Konfirmasi pesanan'; _buildMessage(); }),
          ),
          const SizedBox(height: 12),
          TextField(controller: message, minLines: 6, maxLines: 10,
            decoration: InputDecoration(labelText: 'Pesan (bisa diedit sebelum dikirim)', alignLabelWithHint: true, border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF168C54), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _openWhatsApp, icon: const Icon(Icons.chat), label: const Text('Buka WhatsApp & Tinjau Pesan'))),
          const SizedBox(height: 8),
          SizedBox(width: double.infinity, child: OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('PDF resmi menunggu sinkronisasi Apps Script'),
          )),
          const SizedBox(height: 8),
          const Text('PDF resmi tidak dibuat oleh aplikasi. Dokumen akan dibagikan dari tautan Drive Apps Script setelah integrasi transaksi tersedia.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 8),
          const Text('Pesan tidak dikirim otomatis. WhatsApp akan dibuka agar petugas memeriksa pesan lalu menekan tombol Kirim sendiri.', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
      ],
    );
  }
}

class InvoiceReceiptScreen extends StatefulWidget {
  const InvoiceReceiptScreen({super.key});

  @override
  State<InvoiceReceiptScreen> createState() => _InvoiceReceiptScreenState();
}

class _InvoiceReceiptScreenState extends State<InvoiceReceiptScreen> {
  List<Map<String, String>> orders = [];
  List<Map<String, String>> payments = [];
  bool loading = true;
  String? loadError;

  String _cell(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      for (final entry in row.entries) {
        if (entry.key.trim().toLowerCase() == alias.toLowerCase() &&
            entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  int _money(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;

  String _rupiah(String value) {
    final amount = _money(value);
    return 'Rp ' + amount.toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (match) => '.',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadOfficialDocuments();
  }

  Future<void> _loadOfficialDocuments() async {
    if (mounted) setState(() {
      loading = true;
      loadError = null;
    });
    try {
      final tables = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN'),
        SheetsReadService.readTable('DATA_PEMBAYARAN'),
      ]);
      if (!mounted) return;
      setState(() {
        orders = tables[0].where((row) =>
          _cell(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']).isNotEmpty
        ).toList();
        payments = tables[1].where((row) =>
          _cell(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']).isNotEmpty
        ).toList();
        loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        loading = false;
        loadError = error.toString();
      });
    }
  }

  Future<void> _openDocument(String url) async {
    final uri = Uri.tryParse(url.trim());
    if (uri == null || !uri.hasScheme ||
        (uri.scheme != 'https' && uri.scheme != 'http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tautan dokumen resmi belum tersedia.')),
      );
      return;
    }
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Dokumen tidak dapat dibuka.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) => RefreshIndicator(
    onRefresh: _loadOfficialDocuments,
    child: ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _Intro(
          'Invoice & Kuitansi Resmi',
          'Data dibaca langsung dari DATA_PESANAN dan DATA_PEMBAYARAN.',
          Icons.description_outlined,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                '${orders.length} invoice • ${payments.length} pembayaran',
                style: const TextStyle(
                  color: _darkGold,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Sinkronkan ulang',
              onPressed: loading ? null : _loadOfficialDocuments,
              icon: const Icon(Icons.sync),
            ),
          ],
        ),
        if (loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 30),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (loadError != null)
          _Panel(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Data resmi belum dapat dibaca.',
                style: TextStyle(fontWeight: FontWeight.bold, color: _ink),
              ),
              const SizedBox(height: 6),
              Text(loadError!, style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
              TextButton.icon(
                onPressed: _loadOfficialDocuments,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba lagi'),
              ),
            ],
          ))
        else if (orders.isEmpty)
          const _Empty('Belum ada invoice resmi yang dapat ditampilkan.')
        else
          ...orders.map((order) {
            final invoice = _cell(order, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']);
            final relatedPayments = payments.where((payment) =>
              _cell(payment, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']) == invoice
            ).toList();
            final invoicePdf = _cell(order, [
              'Link Invoice PDF', 'PDF Invoice', 'Link PDF Invoice',
            ]);
            final name = _cell(order, ['Nama', 'Nama Pelanggan', 'Nama pelanggan']);
            final total = _cell(order, ['Total', 'Total Harga', 'Total Tagihan', 'Total harga']);
            final paid = _cell(order, ['Total Dibayar', 'Total dibayar', 'Total Dibayar Kumulatif']);
            final remaining = _cell(order, ['Sisa', 'Sisa Tagihan', 'Sisa tagihan']);
            return Card(
              color: Colors.white,
              margin: const EdgeInsets.only(bottom: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _gold.withValues(alpha: .30)),
              ),
              child: ExpansionTile(
                leading: const Icon(Icons.receipt_long_outlined, color: _darkGold),
                title: Text(name.isEmpty ? invoice : name,
                  style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
                subtitle: Text(invoice),
                childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                children: [
                  _docLine('Tanggal', _cell(order, ['Tanggal', 'Tanggal Pesanan', 'Tanggal Order', 'Timestamp', 'Cap waktu'])),
                  _docLine('Total', _rupiah(total), strong: true),
                  _docLine('Dibayar', _rupiah(paid)),
                  _docLine('Sisa tagihan', _rupiah(remaining), strong: true),
                  _docLine('Status', _cell(order, ['Status', 'Status Pembayaran'])),
                  const Divider(),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text('RIWAYAT KUITANSI RESMI',
                      style: const TextStyle(color: _darkGold, fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                  if (relatedPayments.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text('Belum ada pembayaran tercatat.', style: TextStyle(fontSize: 11, color: Colors.black54)),
                      ),
                    )
                  else
                    ...relatedPayments.map((payment) {
                      final receiptPdf = _cell(payment, [
                        'PDF Kuitansi', 'Link PDF Kuitansi', 'Link Kuitansi', 'Link Kuitansi PDF',
                      ]);
                      return Column(
                        children: [
                          _docLine('No. kuitansi', _cell(payment, ['No Kuitansi', 'Nomor Kuitansi', 'Nomor kuitansi'])),
                          _docLine('Tanggal bayar', _cell(payment, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran'])),
                          _docLine('Jumlah', _rupiah(_cell(payment, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Jumlah pembayaran']))),
                          _docLine('Metode', _cell(payment, ['Metode', 'Metode Pembayaran', 'Metode pembayaran'])),
                          if (receiptPdf.isNotEmpty)
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton.icon(
                                onPressed: () => _openDocument(receiptPdf),
                                icon: const Icon(Icons.picture_as_pdf_outlined),
                                label: const Text('Buka kuitansi PDF resmi'),
                              ),
                            ),
                          const Divider(),
                        ],
                      );
                    }),
                  if (invoicePdf.isNotEmpty)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(backgroundColor: _darkGold),
                        onPressed: () => _openDocument(invoicePdf),
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        label: const Text('Buka invoice PDF resmi'),
                      ),
                    )
                  else
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Tautan invoice PDF belum tersedia pada baris ini.',
                        style: TextStyle(fontSize: 11, color: Colors.black54)),
                    ),
                ],
              ),
            );
          }),
      ],
    ),
  );
}

Widget _docLine(String label, String value, {bool strong = false}) => Padding(
  padding: const EdgeInsets.symmetric(vertical: 3),
  child: Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(width: 112, child: Text(label, style: TextStyle(fontSize: 11, fontWeight: strong ? FontWeight.bold : FontWeight.normal, color: _ink))),
      const Text(': ', style: TextStyle(fontSize: 11)),
      Expanded(child: Text(value, textAlign: TextAlign.right, style: TextStyle(fontSize: 11, fontWeight: strong ? FontWeight.bold : FontWeight.normal, color: strong ? _darkGold : _ink))),
    ],
  ),
);

