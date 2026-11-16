import 'package:flutter/material.dart';
import '../models/optik_models.dart';

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
  final List<OptikOrder> orders;
  final ValueChanged<OptikOrder> onAdd;
  const TransactionScreen({super.key, required this.orders, required this.onAdd});
  @override
  State<TransactionScreen> createState() => _TransactionScreenState();
}

class _TransactionScreenState extends State<TransactionScreen> {
  final customer = TextEditingController();
  final frame = TextEditingController();
  final lens = TextEditingController();
  final dp = TextEditingController();
  final odSph = TextEditingController();
  final odCyl = TextEditingController();
  final odAxis = TextEditingController();
  final osSph = TextEditingController();
  final osCyl = TextEditingController();
  final osAxis = TextEditingController();
  String method = 'Tunai';

  int amount(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    for (final c in [customer, frame, lens, dp, odSph, odCyl, odAxis, osSph, osCyl, osAxis]) { c.dispose(); }
    super.dispose();
  }

  void save() {
    final total = amount(frame) + amount(lens);
    if (customer.text.trim().isEmpty || total <= 0 || amount(dp) > total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Periksa nama pelanggan, harga, dan nominal DP.')));
      return;
    }
    widget.onAdd(OptikOrder(
      invoiceNumber: 'DRAFT-' + DateTime.now().millisecondsSinceEpoch.toString(),
      orderDate: DateTime.now(),
      customer: Customer(name: customer.text.trim()),
      prescription: EyePrescription(
        odSph: odSph.text, odCyl: odCyl.text, odAxis: odAxis.text,
        osSph: osSph.text, osCyl: osCyl.text, osAxis: osAxis.text,
      ),
      frame: OrderItem(description: 'Frame', price: amount(frame)),
      lens: OrderItem(description: 'Lensa', price: amount(lens)),
      initialPayment: amount(dp),
      initialPaymentMethod: method,
    ));
    for (final c in [customer, frame, lens, dp, odSph, odCyl, odAxis, osSph, osCyl, osAxis]) { c.clear(); }
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft pesanan disimpan sementara.')));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const _Intro('Pemesanan & Pemeriksaan', 'Input pesanan dan resep mata OD/OS.', Icons.receipt_long_outlined),
    const SizedBox(height: 16),
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _field(customer, 'Nama pelanggan *'),
      const Text('Resep OD — mata kanan', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
      Row(children: [
        Expanded(child: _field(odSph, 'SPH')), const SizedBox(width: 6),
        Expanded(child: _field(odCyl, 'CYL')), const SizedBox(width: 6),
        Expanded(child: _field(odAxis, 'AXIS')),
      ]),
      const Text('Resep OS — mata kiri', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
      Row(children: [
        Expanded(child: _field(osSph, 'SPH')), const SizedBox(width: 6),
        Expanded(child: _field(osCyl, 'CYL')), const SizedBox(width: 6),
        Expanded(child: _field(osAxis, 'AXIS')),
      ]),
      _field(frame, 'Harga frame (Rp)', type: TextInputType.number),
      _field(lens, 'Harga lensa (Rp)', type: TextInputType.number),
      _field(dp, 'Uang muka / DP (Rp)', type: TextInputType.number),
      DropdownButtonFormField<String>(
        value: method,
        decoration: const InputDecoration(labelText: 'Metode DP', border: OutlineInputBorder()),
        items: const ['Tunai', 'Transfer', 'QRIS', 'Debit/Kredit'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => method = v ?? 'Tunai'),
      ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _darkGold),
        onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Simpan draft pesanan'),
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
  Widget build(BuildContext context) => Row(children: [
    Icon(icon, color: _darkGold, size: 30), const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(color: _darkGold, fontWeight: FontWeight.bold, fontSize: 19)),
      Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 12)),
    ])),
  ]);
}

class _Panel extends StatelessWidget {
  final Widget child;
  const _Panel({required this.child});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: _gold.withValues(alpha: .3))),
    child: child,
  );
}

Widget _field(TextEditingController c, String label, {TextInputType? type}) => Padding(
  padding: const EdgeInsets.only(bottom: 10),
  child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder(), isDense: true)),
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
    child: Text('Data ini masih sementara di memori aplikasi dan belum dikirim ke Google Sheets. Sinkronisasi menunggu pencocokan kontrak API Apps Script yang aktif.', style: TextStyle(fontSize: 11, color: Colors.black54)),
  );
}


class PaymentEntryScreen extends StatefulWidget {
  final List<OptikPayment> payments;
  final ValueChanged<OptikPayment> onAdd;
  const PaymentEntryScreen({super.key, required this.payments, required this.onAdd});
  @override
  State<PaymentEntryScreen> createState() => _PaymentEntryScreenState();
}

class _PaymentEntryScreenState extends State<PaymentEntryScreen> {
  final invoice = TextEditingController();
  final nominal = TextEditingController();
  String method = 'Tunai';

  @override
  void dispose() { invoice.dispose(); nominal.dispose(); super.dispose(); }

  void save() {
    final value = int.tryParse(nominal.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    if (invoice.text.trim().isEmpty || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor invoice dan nominal pembayaran wajib diisi.')));
      return;
    }
    widget.onAdd(OptikPayment(invoiceNumber: invoice.text.trim(), paymentDate: DateTime.now(), amount: value, method: method));
    invoice.clear(); nominal.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pembayaran dicatat sementara pada sesi ini.')));
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const _Intro('Pembayaran', 'Catat pembayaran lanjutan sesuai nomor invoice.', Icons.payments_outlined),
    const SizedBox(height: 16),
    _Panel(child: Column(children: [
      _field(invoice, 'Nomor invoice *'),
      _field(nominal, 'Nominal pembayaran (Rp) *', type: TextInputType.number),
      DropdownButtonFormField<String>(
        value: method,
        decoration: const InputDecoration(labelText: 'Metode pembayaran', border: OutlineInputBorder()),
        items: const ['Tunai', 'Transfer', 'QRIS', 'Debit/Kredit'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
        onChanged: (v) => setState(() => method = v ?? 'Tunai'),
      ),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity, child: FilledButton.icon(
        style: FilledButton.styleFrom(backgroundColor: _darkGold),
        onPressed: save, icon: const Icon(Icons.save_outlined), label: const Text('Catat pembayaran'),
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


class InvoiceReceiptScreen extends StatelessWidget {
  final List<OptikOrder> orders;
  final List<OptikPayment> payments;
  const InvoiceReceiptScreen({super.key, required this.orders, required this.payments});

  String _rupiah(int value) => 'Rp ' + value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (match) => '.',
  );

  String _date(DateTime? value) {
    if (value == null) return '-';
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d/$m/${value.year}';
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(18),
    children: [
      const _Intro('Invoice & Kuitansi', 'Pratinjau dokumen berdasarkan draft transaksi dan pembayaran sesi ini.', Icons.description_outlined),
      const SizedBox(height: 16),
      if (orders.isEmpty)
        const _Empty('Belum ada draft pesanan. Buat pesanan terlebih dahulu untuk melihat invoice.')
      else
        ...orders.reversed.map((order) {
          final related = payments.where((p) => p.invoiceNumber == order.invoiceNumber).toList();
          final paidLater = related.fold<int>(0, (sum, p) => sum + p.amount);
          final paid = order.initialPayment + paidLater;
          final remaining = order.total - paid;
          return Card(
            color: Colors.white,
            margin: const EdgeInsets.only(bottom: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: _gold.withValues(alpha: .35)),
            ),
            child: ExpansionTile(
              leading: const Icon(Icons.receipt_long_outlined, color: _darkGold),
              title: Text(order.customer.name, style: const TextStyle(fontWeight: FontWeight.bold, color: _ink)),
              subtitle: Text('${order.invoiceNumber} • ${_date(order.orderDate)}'),
              childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8F7),
                    border: Border.all(color: _gold.withValues(alpha: .35)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Center(child: Text('OPTIK LENTERA', style: TextStyle(color: _darkGold, fontWeight: FontWeight.w800, letterSpacing: 1.2, fontSize: 18))),
                      const Center(child: Text('INVOICE • PRATINJAU', style: TextStyle(color: _ink, fontWeight: FontWeight.bold))),
                      const Divider(height: 22, color: _gold),
                      _docLine('Nomor invoice', order.invoiceNumber),
                      _docLine('Tanggal', _date(order.orderDate)),
                      _docLine('Pelanggan', order.customer.name),
                      _docLine('Telepon', order.customer.phone.isEmpty ? '-' : order.customer.phone),
                      const Divider(height: 20),
                      const Text('RESEP KACAMATA', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
                      _docLine('OD (kanan)', 'SPH ${order.prescription.odSph} • CYL ${order.prescription.odCyl} • AXIS ${order.prescription.odAxis}'),
                      _docLine('OS (kiri)', 'SPH ${order.prescription.osSph} • CYL ${order.prescription.osCyl} • AXIS ${order.prescription.osAxis}'),
                      const Divider(height: 20),
                      _docLine('Frame', _rupiah(order.frame.price)),
                      _docLine('Lensa', _rupiah(order.lens.price)),
                      _docLine('Lain-lain', _rupiah(order.other.price)),
                      _docLine('TOTAL', _rupiah(order.total), strong: true),
                      _docLine('DP awal', _rupiah(order.initialPayment)),
                      _docLine('Total dibayar', _rupiah(paid)),
                      _docLine('Sisa tagihan', _rupiah(remaining < 0 ? 0 : remaining), strong: true),
                      const SizedBox(height: 8),
                      const Text('KUITANSI PEMBAYARAN', style: TextStyle(color: _darkGold, fontWeight: FontWeight.bold)),
                      if (order.initialPayment > 0)
                        _docLine('DP awal • ${order.initialPaymentMethod}', _rupiah(order.initialPayment)),
                      ...related.map((p) => _docLine('${_date(p.paymentDate)} • ${p.method}', _rupiah(p.amount))),
                      if (order.initialPayment == 0 && related.isEmpty)
                        const Text('Belum ada pembayaran tercatat.', style: TextStyle(color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                const Text('Ini pratinjau data sesi aplikasi, bukan PDF resmi yang tersimpan di Drive.', style: TextStyle(color: Colors.black54, fontSize: 11)),
              ],
            ),
          );
        }),
      const _LocalNote(),
    ],
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
