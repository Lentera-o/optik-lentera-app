import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pdf_service.dart';
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

  int amount(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void dispose() {
    for (final c in [customer, phone, address, doctor, lensType, rxNote, frameDescription, frame, lensDescription, lens, otherPrice, otherDescription, dp, odSph, odCyl, odAxis, odAdd, odPd, osSph, osCyl, osAxis, osAdd, osPd]) { c.dispose(); }
    super.dispose();
  }

  void save() {
    final total = amount(frame) + amount(lens) + amount(otherPrice);
    if (customer.text.trim().isEmpty || total <= 0 || amount(dp) > total) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Periksa nama pelanggan, harga, dan nominal DP.')));
      return;
    }
    widget.onAdd(OptikOrder(
      invoiceNumber: 'DRAFT-' + DateTime.now().microsecondsSinceEpoch.toString(),
      orderDate: DateTime.now(),
      customer: Customer(name: customer.text.trim(), phone: phone.text.trim(), address: address.text.trim()),
      prescription: EyePrescription(
        doctor: doctor.text.trim(), lensType: lensType.text.trim(), note: rxNote.text.trim(),
        odSph: odSph.text, odCyl: odCyl.text, odAxis: odAxis.text, odAdd: odAdd.text, odPd: odPd.text,
        osSph: osSph.text, osCyl: osCyl.text, osAxis: osAxis.text, osAdd: osAdd.text, osPd: osPd.text,
      ),
      frame: OrderItem(description: frameDescription.text.trim(), price: amount(frame)),
      lens: OrderItem(description: lensDescription.text.trim(), price: amount(lens)),
      other: OrderItem(description: otherDescription.text.trim(), price: amount(otherPrice)),
      initialPayment: amount(dp),
      initialPaymentMethod: method,
    ));
    for (final c in [customer, phone, address, doctor, lensType, rxNote, frameDescription, frame, lensDescription, lens, otherPrice, otherDescription, dp, odSph, odCyl, odAxis, odAdd, odPd, osSph, osCyl, osAxis, osAdd, osPd]) { c.clear(); }
    setState(() { selectedCustomerIndex = null; });
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Draft pesanan disimpan sementara.')));
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
      _field(lensType, 'Jenis / model lensa'),
      _field(rxNote, 'Catatan resep'),
      _field(frameDescription, 'Frame - merek / model / warna'),
      _field(frame, 'Harga frame (Rp)', type: TextInputType.number),
      _field(lensDescription, 'Lensa - jenis / ukuran / coating'),
      _field(lens, 'Harga lensa (Rp)', type: TextInputType.number),
      _field(otherDescription, 'Keterangan biaya lain-lain'),
      _field(otherPrice, 'Harga lain-lain (Rp)', type: TextInputType.number),
      _field(dp, 'Uang muka / DP (Rp)', type: TextInputType.number),
      DropdownButtonFormField<String>(
        value: method,
        decoration: InputDecoration(labelText: 'Metode DP', border: OutlineInputBorder(borderRadius: BorderRadius.circular(14))),
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
    child: Text('Data ini masih sementara di memori aplikasi dan belum dikirim ke Google Sheets. Sinkronisasi menunggu pencocokan kontrak API Apps Script yang aktif.', style: TextStyle(fontSize: 11, color: Colors.black54)),
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
    final matches = widget.orders.where((o) => o.invoiceNumber == invoice.text.trim());
    if (matches.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice tidak ditemukan pada daftar pesanan sesi ini.')));
      return;
    }
    final order = matches.first;
    final alreadyPaid = order.initialPayment + widget.payments
        .where((p) => p.invoiceNumber == order.invoiceNumber)
        .fold<int>(0, (sum, p) => sum + p.amount);
    final balance = order.total - alreadyPaid;
    if (balance <= 0 || value > balance) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(balance <= 0 ? 'Invoice sudah lunas.' : 'Pembayaran melebihi sisa tagihan Rp $balance.')));
      return;
    }
    widget.onAdd(OptikPayment(
      invoiceNumber: invoice.text.trim(),
      paymentDate: DateTime.now(),
      amount: value,
      method: method,
      requestId: 'PAY-' + DateTime.now().microsecondsSinceEpoch.toString(),
    ));
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
        decoration: InputDecoration(labelText: 'Metode pembayaran', border: OutlineInputBorder()),
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

  // Normalisasi nomor Indonesia untuk tautan WhatsApp.
  // Mendukung +62..., 62..., 08..., 8..., dan awalan internasional 0062...
  String _phoneForWhatsApp(String raw) {
    var digits = raw.trim().replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.startsWith('0062')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '62' + digits.substring(1);
    } else if (digits.startsWith('8')) {
      digits = '62' + digits;
    }
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
          const Text('Pesan tidak dikirim otomatis. WhatsApp akan dibuka agar petugas memeriksa lalu menekan tombol Kirim sendiri.', style: TextStyle(fontSize: 11, color: Colors.black54)),
        ])),
      ],
    );
  }
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
          final receiptPayments = <OptikPayment>[
            if (order.initialPayment > 0)
              OptikPayment(invoiceNumber: order.invoiceNumber, paymentDate: order.orderDate ?? DateTime.now(), amount: order.initialPayment, method: order.initialPaymentMethod, note: 'DP awal'),
            ...related,
          ];
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
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(backgroundColor: _darkGold),
                    onPressed: () => OptikPdfService.invoice(order, paid: paid, remaining: remaining < 0 ? 0 : remaining),
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Cetak / Bagikan Invoice PDF'),
                  ),
                ),
                const SizedBox(height: 6),
                if (receiptPayments.isNotEmpty)
                  ...receiptPayments.asMap().entries.map((entry) {
                    final payment = entry.value;
                    final receiptNo = _receiptNumber(payment.paymentDate, entry.key + 1);
                    final paidAtReceipt = receiptPayments.take(entry.key + 1).fold<int>(0, (sum, item) => sum + item.amount);
                    final balanceAtReceipt = order.total - paidAtReceipt;
                    return Padding(
                      padding: const EdgeInsets.only(top: 5),
                      child: OutlinedButton.icon(
                        onPressed: () => OptikPdfService.receipt(order, payment, receiptNumber: receiptNo, paid: paidAtReceipt, remaining: balanceAtReceipt < 0 ? 0 : balanceAtReceipt),
                        icon: const Icon(Icons.receipt_long_outlined),
                        label: Text('Cetak / Bagikan Kuitansi $receiptNo'),
                      ),
                    );
                  }),
                const SizedBox(height: 8),
                const Text('PDF ini dibuat dari draft sesi aplikasi. Untuk dokumen resmi tersimpan di Drive dan sinkronisasi database, transaksi tetap harus masuk melalui backend aktif.', style: TextStyle(color: Colors.black54, fontSize: 11)),
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

String _receiptNumber(DateTime date, int sequence) {
  return 'KL-DRAFT-${date.millisecondsSinceEpoch}-${sequence.toString().padLeft(3, '0')}';
}
