import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/pdf_service.dart';
import '../models/optik_models.dart';
import '../services/api_service.dart';
import '../services/google_auth_service.dart';
import '../services/sheets_read_service.dart';
import '../services/whatsapp_phone_service.dart';

const _gold = Color(0xFFB99555);
const _darkGold = Color(0xFF80612F);
const _ink = Color(0xFF39342F);

String _newTransactionRequestId() =>
    '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}';

class CustomerScreen extends StatefulWidget {
  final List<Customer> customers;
  final ValueChanged<Customer> onAdd;
  const CustomerScreen({super.key, required this.customers, required this.onAdd});
  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}
class _CustomerScreenState extends State<CustomerScreen> {
  final name = TextEditingController(), phone = TextEditingController(), address = TextEditingController(), search = TextEditingController();
  List<Map<String, String>> orders = [], payments = [];
  bool loading = true;
  String? error;
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  String cell(Map<String, String> row, List<String> aliases) {
    // Exact column names take priority; then accept harmless word-order and
    // punctuation variations used by the existing DATA_PESANAN sheet.
    for (final alias in aliases) {
      for (final entry in row.entries) {
        if (norm(entry.key) == norm(alias) && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    for (final alias in aliases) {
      final tokens = RegExp(r'[a-z0-9]+').allMatches(alias.toLowerCase())
          .map((match) => match.group(0)!)
          .where((token) => token.length > 1)
          .toList();
      if (tokens.length < 2) continue;
      for (final entry in row.entries) {
        final header = norm(entry.key);
        if (entry.value.trim().isNotEmpty && tokens.every(header.contains)) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }
  String phoneKey(String s) {
    // Use the same parser as WhatsApp links so +62, 08, bare 8, and
    // spreadsheet cells containing labels/links group under one customer.
    final normalized = extractWhatsAppPhone(s);
    if (normalized.isEmpty) return '';
    return normalized.startsWith('62')
        ? normalized.substring(2)
        : normalized;
  }
  int money(String s) => int.tryParse(s.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;
  String rupiah(String s) => 'Rp ' + money(s).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
  Future<void> loadHistory() async {
    if (mounted) setState(() { loading = true; error = null; });
    try {
      final data = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      if (!mounted) return;
      setState(() {
        orders = data[0].where((r) =>
          cell(r, [
            'No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice',
            'Nomor Tagihan', 'No Tagihan', 'No Faktur', 'Nomor Faktur',
            'Kode Invoice', 'Invoice ID', 'ID Invoice',
          ]).isNotEmpty &&
          cell(r, [
            'Nama', 'Nama Pelanggan', 'Pelanggan', 'Nama Customer',
            'Nama Konsumen', 'Nama Pemesan', 'Nama Lengkap', 'Nama Pasien',
            'Nama Klien', 'Nama Penerima',
          ]).isNotEmpty
        ).toList();
        payments = data[1].where((r) => r.values.any((v) => v.trim().isNotEmpty)).toList();
        loading = false;
      });
    } catch (e) { if (!mounted) return; setState(() { error = e.toString(); loading = false; }); }
  }
  String _invoiceKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  bool paymentFor(Map<String,String> p, String invoice) {
    final wanted = _invoiceKey(invoice);
    if (wanted.isEmpty) return false;
    final paymentInvoice = cell(p, [
      'No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice',
      'Nomor Tagihan', 'No Tagihan', 'No Faktur', 'Nomor Faktur',
      'Kode Invoice', 'Invoice ID', 'ID Invoice',
    ]);
    // Never match against arbitrary cell values: a payment note, amount, or
    // customer field can coincidentally equal an invoice string.
    return paymentInvoice.isNotEmpty &&
        _invoiceKey(paymentInvoice) == wanted;
  }
  String documentUrl(Map<String,String> row, List<String> aliases) {
    final candidates = <String>[cell(row, aliases), ...row.entries.where((e) => RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive:false).hasMatch(e.key)).map((e)=>e.value), ...row.values];
    for (final c in candidates) {
      final m = RegExp(r'https?://[^\s<>" ]+', caseSensitive:false).firstMatch(c.trim());
      if (m != null) {
        final raw = m.group(0)!.replaceFirst(RegExp(r'[.,;)]+$'), '');
        final uri = Uri.tryParse(raw);
        if (uri != null && (uri.host == 'drive.google.com' || uri.host.endsWith('.google.com'))) return uri.toString();
      }
    }
    return '';
  }
  Future<void> openDocument(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Dokumen tidak dapat dibuka.')));
  }
  void save() {
    if (name.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nama pelanggan wajib diisi.'))); return; }
    widget.onAdd(Customer(name:name.text.trim(), phone:phone.text.trim(), address:address.text.trim()));
    name.clear(); phone.clear(); address.clear();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pelanggan ditambahkan untuk sesi ini.')));
  }
  @override
  void initState() { super.initState(); loadHistory(); }
  @override
  void dispose() { name.dispose(); phone.dispose(); address.dispose(); search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final groups = <String,List<Map<String,String>>>{}, names = <String,String>{}, phones = <String,String>{};
    for (final r in orders) {
      final n = cell(r,[
        'Nama', 'Nama Pelanggan', 'Pelanggan', 'Nama Customer',
        'Nama Konsumen', 'Nama Pemesan', 'Nama Lengkap', 'Nama Pasien',
        'Nama Klien', 'Nama Penerima',
      ]);
      final p = cell(r,[
        'No WhatsApp', 'Nomor WhatsApp', 'No. WhatsApp', 'No WA',
        'Nomor WA', 'WhatsApp', 'Kontak WhatsApp', 'Nomor WhatsApp Pelanggan',
        'No Telepon', 'Nomor Telepon', 'Telepon', 'No HP', 'Nomor HP',
        'No. HP', 'Handphone', 'HP', 'No HP/WA', 'Nomor HP/WA',
        'HP/WA', 'Phone', 'Mobile', 'Nomor Kontak', 'Kontak Pelanggan',
      ]);
      final pk = phoneKey(p);
      final key = pk.isNotEmpty ? 'p:' + pk : 'n:' + n.toLowerCase().trim();
      groups.putIfAbsent(key,()=>[]).add(r); names[key]=n; phones[key]=p;
    }
    final q = search.text.trim().toLowerCase();
    final keys = groups.keys.where((k)=>q.isEmpty || (names[k]??'').toLowerCase().contains(q) || (phones[k]??'').contains(q) || groups[k]!.any((r)=>cell(r,['No Invoice','Nomor Invoice']).toLowerCase().contains(q))).toList()
      ..sort((a,b)=>(names[a]??'').compareTo(names[b]??''));
    return RefreshIndicator(onRefresh:loadHistory, child:ListView(padding:const EdgeInsets.all(18), children:[
      const _Intro('Data & Riwayat Pelanggan','Profil pelanggan dan seluruh transaksi resmi.',Icons.people_outline),
      const SizedBox(height:16),
      _Panel(child:Column(children:[
        _field(name,'Nama pelanggan *'), _field(phone,'Nomor WhatsApp / telepon',type:TextInputType.phone), _field(address,'Alamat'),
        SizedBox(width:double.infinity,child:FilledButton.icon(style:FilledButton.styleFrom(backgroundColor:_darkGold),onPressed:save,icon:const Icon(Icons.person_add_alt_1),label:const Text('Tambah pelanggan'))),
      ])),
      const SizedBox(height:18),
      Text('RIWAYAT TRANSAKSI RESMI · ${orders.length} invoice',style:const TextStyle(fontWeight:FontWeight.bold,color:_ink)),
      const SizedBox(height:8),
      TextField(controller:search,onChanged:(_)=>setState((){}),decoration:InputDecoration(hintText:'Cari nama, nomor WhatsApp, atau invoice',prefixIcon:const Icon(Icons.search),suffixIcon:search.text.isEmpty?null:IconButton(onPressed:(){search.clear();setState((){});},icon:const Icon(Icons.close)))),
      const SizedBox(height:10),
      if(loading) const Padding(padding:EdgeInsets.all(28),child:Center(child:CircularProgressIndicator()))
      else if(error!=null) _Panel(child:Column(children:[const Text('Riwayat pelanggan belum dapat dimuat.'),Text(error!,style:const TextStyle(fontSize:11,color:Colors.deepOrange)),TextButton.icon(onPressed:loadHistory,icon:const Icon(Icons.refresh),label:const Text('Coba lagi'))]))
      else if(keys.isEmpty) const _Empty('Belum ada riwayat transaksi yang cocok.')
      else ...keys.map((key){
        final customerOrders=groups[key]!;
        final paymentCount=payments.where((p)=>customerOrders.any((o)=>paymentFor(p,cell(o,['No Invoice','Nomor Invoice','Invoice'])))).length;
        return Card(color:Colors.white,child:ExpansionTile(
          leading:const CircleAvatar(backgroundColor:Color(0xFFF8EEF0),child:Icon(Icons.person_outline,color:_darkGold)),
          title:Text(names[key]??'Pelanggan',style:const TextStyle(fontWeight:FontWeight.w800,color:_ink)),
          subtitle:Text('${phones[key]??'-'} · ${customerOrders.length} invoice · ${paymentCount} pembayaran'),
          childrenPadding:const EdgeInsets.fromLTRB(14,0,14,14),
          children:customerOrders.map((o){
            final invoice=cell(o,['No Invoice','Nomor Invoice','Invoice']);
            final related=payments.where((p)=>paymentFor(p,invoice)).toList();
            final pdf=documentUrl(o,['Link Invoice PDF','PDF Invoice','Link PDF Invoice','Invoice PDF','URL Invoice PDF']);
            return Container(width:double.infinity,margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:const Color(0xFFFFFCF8),borderRadius:BorderRadius.circular(12),border:Border.all(color:_gold.withValues(alpha:.2))),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
              Text(invoice,style:const TextStyle(fontWeight:FontWeight.w800,color:_darkGold)),
              Text('Tanggal: ${cell(o,['Tanggal','Tanggal Pesanan','Tanggal Order','Timestamp'])}'),
              Text('Total: ${rupiah(cell(o,['Total','Total Harga','Total Tagihan']))}'),
              Text('Dibayar: ${rupiah(cell(o,['Total Dibayar','Total Dibayar Kumulatif']))} · Sisa: ${rupiah(cell(o,['Sisa Tagihan','Sisa']))}'),
              if(pdf.isNotEmpty) Align(alignment:Alignment.centerLeft,child:TextButton.icon(onPressed:()=>openDocument(pdf),icon:const Icon(Icons.picture_as_pdf_outlined),label:const Text('Buka invoice PDF'))),
              const Divider(height:14),
              const Text('RIWAYAT PEMBAYARAN / KUITANSI',style:TextStyle(fontSize:11,fontWeight:FontWeight.w800,color:_darkGold)),
              if(related.isEmpty) const Text('Belum ada pembayaran tercatat.',style:TextStyle(fontSize:11,color:Colors.black54))
              else ...related.map((p){
                final amount=cell(p,['Jumlah Bayar','Jumlah Pembayaran','Nominal Pembayaran','Nominal']);
                final receipt=documentUrl(p,['PDF Kuitansi','Link PDF Kuitansi','Link Kuitansi','Link Kuitansi PDF','Kuitansi PDF','URL Kuitansi PDF']);
                return ListTile(dense:true,contentPadding:EdgeInsets.zero,leading:const Icon(Icons.payments_outlined,color:_darkGold),title:Text(rupiah(amount),style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${cell(p,['Tanggal Bayar','Tanggal Pembayaran','Tanggal','Timestamp'])} · ${cell(p,['Metode','Metode Pembayaran'])}'),trailing:receipt.isEmpty?null:IconButton(tooltip:'Buka kuitansi PDF',onPressed:()=>openDocument(receipt),icon:const Icon(Icons.picture_as_pdf_outlined,color:_darkGold)));
              }),
            ]));
          }).toList(),
        ));
      }),
      const SizedBox(height:18),
      Text('Pelanggan tersimpan di aplikasi: ${widget.customers.length}',style:const TextStyle(fontWeight:FontWeight.bold,color:_ink)),
      if(widget.customers.isEmpty) const _Empty('Belum ada profil pelanggan yang ditambahkan melalui aplikasi.')
      else ...widget.customers.reversed.map((c)=>Card(color:Colors.white,child:ListTile(leading:const Icon(Icons.person_outline,color:_darkGold),title:Text(c.name),subtitle:Text([c.phone,c.address].where((v)=>v.isNotEmpty).join(' • '))))),
      const _LocalNote(),
    ]));
  }
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
  List<Map<String, String>> _officialOrderHistory = [];
  bool _historyLoading = false;
  String? _historyError;
  String? _selectedHistoryInvoice;

  String _headerKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _historyCell(Map<String, String> row, List<String> aliases) {
    // Prefer exact header matches so similarly named fields (e.g. Frame and
    // Harga Frame) never get mixed up.
    for (final alias in aliases) {
      final wanted = _headerKey(alias);
      for (final entry in row.entries) {
        if (_headerKey(entry.key) == wanted && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }

    // Then tolerate harmless header variations and word order, e.g.
    // "SPH OD (Mata Kanan)" or "Nomor WhatsApp Pelanggan".
    for (final alias in aliases) {
      final tokens = RegExp(r'[a-z0-9]+')
          .allMatches(alias.toLowerCase())
          .map((match) => match.group(0)!)
          .where((token) => token.length > 1)
          .toList();
      if (tokens.length < 2) continue;
      for (final entry in row.entries) {
        final header = _headerKey(entry.key);
        if (entry.value.trim().isNotEmpty &&
            tokens.every(header.contains)) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  String _historyPhone(Map<String, String> row) {
    final raw = _historyCell(row, [
      'No WhatsApp', 'Nomor WhatsApp', 'No. WhatsApp',
      'No WA', 'Nomor WA', 'No WA Pelanggan', 'Nomor WA Pelanggan',
      'WhatsApp', 'Kontak WhatsApp', 'Nomor WhatsApp Pelanggan',
      'No Telepon', 'Nomor Telepon', 'Telepon', 'No HP',
      'Nomor HP', 'No. HP', 'Handphone', 'HP',
      'No HP/WA', 'Nomor HP/WA', 'HP/WA', 'Phone', 'Mobile',
      'Nomor Kontak', 'Kontak Pelanggan',
    ]);
    if (raw.isEmpty) {
      // Some sheet headers use a descriptive label not covered above.
      for (final entry in row.entries) {
        final header = _headerKey(entry.key);
        final isPhoneColumn = header.contains('whatsapp') ||
            header.contains('nomorwa') || header.contains('notelepon') ||
            header.contains('nomortelepon') || header.contains('handphone') ||
            header == 'hp' || header == 'nohp' || header == 'phone' ||
            header == 'mobile' || header.contains('nomorhp');
        if (isPhoneColumn && entry.value.trim().isNotEmpty) {
          return _displayHistoryPhone(entry.value.trim());
        }
      }
      return '';
    }
    return _displayHistoryPhone(raw);
  }

  String _displayHistoryPhone(String raw) {
    final normalized = normalizeWhatsAppPhone(raw);
    // Show Indonesian numbers in familiar local form in the editable field.
    if (normalized.startsWith('62') && normalized.length > 2) {
      return '0' + normalized.substring(2);
    }
    return raw;
  }

  Future<void> _loadOfficialOrderHistory() async {
    if (mounted) setState(() => _historyLoading = true);
    try {
      final rows = await SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true);
      if (!mounted) return;
      setState(() {
        _officialOrderHistory = rows.where((row) =>
          _historyCell(row, [
            'No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice',
            'Nomor Tagihan', 'No Tagihan', 'No Faktur', 'Nomor Faktur',
            'Kode Invoice', 'Invoice ID', 'ID Invoice',
          ]).isNotEmpty &&
          _historyCell(row, [
            'Nama', 'Nama Pelanggan', 'Pelanggan', 'Nama Customer',
            'Nama Konsumen', 'Nama Pemesan', 'Nama Lengkap', 'Nama Pasien',
            'Nama Klien', 'Nama Penerima',
          ]).isNotEmpty
        ).toList();
        _historyLoading = false;
        _historyError = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _historyLoading = false; _historyError = e.toString(); });
    }
  }

  void _prefillFromOfficialOrder(String? invoice) {
    if (invoice == null) return;
    Map<String, String>? row;
    for (final candidate in _officialOrderHistory) {
      if (_historyCell(candidate, ['No Invoice', 'Nomor Invoice', 'Invoice']) == invoice) {
        row = candidate;
        break;
      }
    }
    if (row == null) return;
    final selectedRow = row;
    setState(() {
      _selectedHistoryInvoice = invoice;
      customer.text = _historyCell(selectedRow, ['Nama', 'Nama Pelanggan', 'Pelanggan', 'Nama Customer', 'Nama Konsumen']);
      phone.text = _historyPhone(selectedRow);
      address.text = _historyCell(selectedRow, ['Alamat', 'Alamat Pelanggan', 'Alamat Customer', 'Alamat Konsumen']);
      doctor.text = _historyCell(selectedRow, ['Dokter', 'Nama Dokter', 'Dokter / Optometris', 'Optometris', 'Pemeriksa', 'Nama Pemeriksa']);
      odSph.text = _historyCell(selectedRow, ['OD SPH', 'SPH OD', 'Mata Kanan SPH', 'SPH Kanan', 'SPH Mata Kanan', 'Sphere OD', 'OD Sphere']);
      odCyl.text = _historyCell(selectedRow, ['OD CYL', 'CYL OD', 'Mata Kanan CYL', 'CYL Kanan', 'CYL Mata Kanan', 'Cylinder OD', 'OD Cylinder']);
      odAxis.text = _historyCell(selectedRow, ['OD AXIS', 'AXIS OD', 'Mata Kanan AXIS', 'AXIS Kanan', 'AXIS Mata Kanan', 'Axis Kanan']);
      odAdd.text = _historyCell(selectedRow, ['OD ADD', 'ADD OD', 'Mata Kanan ADD', 'ADD Kanan', 'ADD Mata Kanan']);
      odPd.text = _historyCell(selectedRow, ['OD PD', 'PD OD', 'PD Kanan', 'PD Mata Kanan', 'Pupil Distance Kanan']);
      osSph.text = _historyCell(selectedRow, ['OS SPH', 'SPH OS', 'Mata Kiri SPH', 'SPH Kiri', 'SPH Mata Kiri', 'Sphere OS', 'OS Sphere']);
      osCyl.text = _historyCell(selectedRow, ['OS CYL', 'CYL OS', 'Mata Kiri CYL', 'CYL Kiri', 'CYL Mata Kiri', 'Cylinder OS', 'OS Cylinder']);
      osAxis.text = _historyCell(selectedRow, ['OS AXIS', 'AXIS OS', 'Mata Kiri AXIS', 'AXIS Kiri', 'AXIS Mata Kiri']);
      osAdd.text = _historyCell(selectedRow, ['OS ADD', 'ADD OS', 'Mata Kiri ADD', 'ADD Kiri', 'ADD Mata Kiri']);
      osPd.text = _historyCell(selectedRow, ['OS PD', 'PD OS', 'PD Kiri', 'PD Mata Kiri', 'Pupil Distance Kiri']);
      lensType.text = _historyCell(selectedRow, ['Jenis Lensa', 'Tipe Lensa', 'Model Lensa', 'Lensa']);
      rxNote.text = _historyCell(selectedRow, ['Catatan Resep', 'Keterangan Resep', 'Catatan Pemeriksaan', 'Catatan Optik', 'Catatan Resep Mata']);
      frameDescription.text = _historyCell(selectedRow, ['Deskripsi Frame', 'Model Frame', 'Merek Frame', 'Detail Frame', 'Nama Frame', 'Frame']);
      frame.text = _historyCell(selectedRow, ['Harga Frame', 'Harga Bingkai', 'Biaya Frame', 'Nominal Frame']);
      lensDescription.text = _historyCell(selectedRow, ['Deskripsi Lensa', 'Detail Lensa', 'Keterangan Lensa', 'Spesifikasi Lensa']);
      lens.text = _historyCell(selectedRow, ['Harga Lensa', 'Biaya Lensa', 'Nominal Lensa']);
      otherDescription.text = _historyCell(selectedRow, ['Keterangan Lain', 'Deskripsi Lain', 'Rincian Lain', 'Biaya Lain']);
      otherPrice.text = _historyCell(selectedRow, ['Harga Lain', 'Harga Lainnya', 'Biaya Lainnya', 'Nominal Lain', 'Nominal Biaya Lain']);
      invoiceNote.text = _historyCell(selectedRow, ['Catatan Invoice', 'Catatan Pesanan', 'Catatan Tambahan', 'Keterangan']);
      // DP intentionally stays empty: repeat orders must not inherit a previous invoice payment.
      dp.clear();
      selectedCustomerIndex = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Data pelanggan dan rincian dari $invoice dimuat. Periksa dan sesuaikan sebelum membuat pesanan baru.')),
    );
  }

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
  String? _pendingOrderRequestId;
  String? _pendingOrderPayload;
  DateTime? _pendingOrderDate;

  int amount(TextEditingController c) => int.tryParse(c.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadOfficialOrderHistory();
  }

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
    try {
      final idToken = await GoogleAuthService.instance.requireIdToken();
      final orderDate = _pendingOrderDate ??= DateTime.now();
      final orderPayload = <String, dynamic>{
          'orderDate': orderDate.toIso8601String(),
          'name': customer.text.trim(),
          'phone': phone.text.trim(),
          'address': address.text.trim(),
          'doctor': doctor.text.trim(),
          'odSph': odSph.text.trim(),
          'odCyl': odCyl.text.trim(),
          'odAxis': odAxis.text.trim(),
          'odAdd': odAdd.text.trim(),
          'odPd': odPd.text.trim(),
          'osSph': osSph.text.trim(),
          'osCyl': osCyl.text.trim(),
          'osAxis': osAxis.text.trim(),
          'osAdd': osAdd.text.trim(),
          'osPd': osPd.text.trim(),
          'lensType': lensType.text.trim(),
          'rxNote': rxNote.text.trim(),
          'frameDescription': frameDescription.text.trim(),
          'framePrice': amount(frame),
          'lensDescription': lensDescription.text.trim(),
          'lensPrice': amount(lens),
          'otherDescription': otherDescription.text.trim(),
          'otherPrice': amount(otherPrice),
          'initialPayment': amount(dp),
          'initialPaymentMethod': method,
          'note': invoiceNote.text.trim(),
        };
      final orderFingerprint = jsonEncode(orderPayload);
      if (_pendingOrderPayload != orderFingerprint) {
        _pendingOrderPayload = orderFingerprint;
        _pendingOrderRequestId = _newTransactionRequestId();
      }
      final response = await ApiService.createOrder(
        idToken: idToken,
        requestId: _pendingOrderRequestId!,
        data: orderPayload,
      );
      if (!response.isSuccessful) {
        throw Exception(response.errorMessage ?? 'Pesanan gagal disimpan ke server.');
      }
      final result = response.data;
      final invoiceNumber = result is Map ? (result['invoice']?.toString() ?? '') : '';
      if (invoiceNumber.isEmpty) {
        throw Exception('Server menerima respons tanpa nomor invoice. Periksa DATA_PESANAN sebelum mengulang transaksi.');
      }
      _pendingOrderRequestId = null;
      _pendingOrderPayload = null;
      _pendingOrderDate = null;
      widget.onAdd(OptikOrder(
        invoiceNumber: invoiceNumber,
        orderDate: orderDate,
        customer: Customer(name: customer.text.trim(), phone: phone.text.trim(), address: address.text.trim()),
        prescription: EyePrescription(
          doctor: doctor.text.trim(), odSph: odSph.text.trim(), odCyl: odCyl.text.trim(),
          odAxis: odAxis.text.trim(), odAdd: odAdd.text.trim(), odPd: odPd.text.trim(),
          osSph: osSph.text.trim(), osCyl: osCyl.text.trim(), osAxis: osAxis.text.trim(),
          osAdd: osAdd.text.trim(), osPd: osPd.text.trim(), lensType: lensType.text.trim(),
          note: rxNote.text.trim(),
        ),
        frame: OrderItem(description: frameDescription.text.trim(), price: amount(frame)),
        lens: OrderItem(description: lensDescription.text.trim(), price: amount(lens)),
        other: OrderItem(description: otherDescription.text.trim(), price: amount(otherPrice)),
        initialPayment: amount(dp),
        initialPaymentMethod: method,
        note: invoiceNote.text.trim(),
      ));
      await _loadOfficialOrderHistory();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pesanan berhasil tersimpan. Invoice $invoiceNumber sudah diproses oleh sistem.'),
        duration: const Duration(seconds: 6),
      ));
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pesanan belum berhasil dikonfirmasi: ${error.toString().replaceFirst('Exception: ', '')}'),
        duration: const Duration(seconds: 8),
      ));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.all(18), children: [
    const _Intro('Pemesanan & Pemeriksaan', 'Input pesanan dan resep mata OD/OS.', Icons.receipt_long_outlined),
    const SizedBox(height: 16),
    _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Text('ULANG PESANAN / AMBIL DATA LAMA', style: TextStyle(color: _darkGold, fontWeight: FontWeight.w800, fontSize: 12))),
        IconButton(tooltip: 'Muat ulang data pesanan', onPressed: _historyLoading ? null : _loadOfficialOrderHistory, icon: const Icon(Icons.refresh)),
      ]),
      if (_historyLoading) const LinearProgressIndicator()
      else if (_historyError != null) Text('Data pesanan lama belum dapat dimuat: $_historyError', style: const TextStyle(color: Colors.deepOrange, fontSize: 11))
      else if (_officialOrderHistory.isEmpty) const Text('Belum ada rincian pesanan resmi yang tersedia untuk dipilih.', style: TextStyle(fontSize: 11, color: Colors.black54))
      else DropdownButtonFormField<String>(
        value: _selectedHistoryInvoice,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: 'Pilih invoice / pesanan terdahulu',
          helperText: 'Nama, kontak, resep, dan rincian barang akan diambil dari pesanan tersebut.',
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
        ),
        items: _officialOrderHistory.reversed.map((row) {
          final number = _historyCell(row, ['No Invoice', 'Nomor Invoice', 'Invoice']);
          final person = _historyCell(row, ['Nama', 'Nama Pelanggan', 'Pelanggan']);
          final date = _historyCell(row, ['Tanggal', 'Tanggal Pesanan', 'Tanggal Order', 'Timestamp']);
          return DropdownMenuItem<String>(value: number, child: Text('$number · $person · $date', overflow: TextOverflow.ellipsis));
        }).toList(),
        onChanged: _prefillFromOfficialOrder,
      ),
      const SizedBox(height: 12),
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
    child: Text('Transaksi dikirim langsung dari aplikasi ke Apps Script setelah sesi Google diverifikasi. Invoice dan kuitansi resmi tetap diproses oleh sistem yang sudah ada.', style: TextStyle(fontSize: 11, color: Colors.black54)),
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
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final alias in aliases) {
      final target = normalize(alias);
      for (final entry in row.entries) {
        if (normalize(entry.key) == target && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    // Match reordered/descriptive headings without requiring an exact label.
    for (final alias in aliases) {
      final tokens = RegExp(r'[a-z0-9]+').allMatches(alias.toLowerCase())
          .map((match) => match.group(0)!)
          .where((token) => token.length > 1)
          .toList();
      if (tokens.length < 2) continue;
      for (final entry in row.entries) {
        if (entry.value.trim().isNotEmpty &&
            tokens.every(normalize(entry.key).contains)) {
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
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      final rows = tables[0];
      final paymentRows = tables[1];
      final mappedPayments = paymentRows.map((row) => <String, String>{
        'invoice': _cell(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']),
        'receipt': _cell(row, ['No Kuitansi', 'Nomor Kuitansi', 'Nomor kuitansi', 'No. Kuitansi', 'No Kwitansi', 'Nomor Kwitansi', 'Nomor Bukti', 'No Bukti']),
        'date': _cell(row, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran']),
        'amount': _cell(row, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Jumlah pembayaran', 'Nominal', 'Nominal Pembayaran', 'Total Bayar']),
        'method': _cell(row, ['Metode', 'Metode Pembayaran', 'Metode pembayaran']),
        'note': _cell(row, ['Catatan', 'Keterangan Pembayaran', 'Catatan Pembayaran']),
      }).where((item) => item['invoice']!.isNotEmpty).toList();
      final mapped = <Map<String, String>>[];
      for (final row in rows) {
        final number = _cell(row, [
          'No Invoice', 'Nomor Invoice', 'Nomor invoice', 'No. Invoice',
          'Invoice Number', 'Nomor Tagihan', 'No Tagihan', 'No Faktur',
          'Nomor Faktur', 'Kode Invoice', 'Invoice ID', 'ID Invoice',
        ]);
        if (number.isEmpty) continue;
        final name = _cell(row, [
          'Nama', 'Nama Pelanggan', 'Nama pelanggan', 'Pelanggan',
          'Nama Customer', 'Customer', 'Nama Konsumen', 'Nama Pemesan',
          'Nama Lengkap', 'Nama Pasien', 'Nama Klien', 'Nama Penerima',
        ]);
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
  String? _pendingPaymentRequestId;
  String? _pendingPaymentPayload;

  Future<void> save() async {
    if (submitting) return;
    final value = int.tryParse(nominal.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final selected = selectedOfficialOrder;
    if (invoice.text.trim().isEmpty || value <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nomor invoice dan nominal pembayaran wajib diisi.')));
      return;
    }
    if (selected == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih invoice resmi yang masih terdaftar. Muat ulang daftar invoice bila perlu.')));
      return;
    }
    final remaining = _money(selected['remaining'] ?? '');
    if (remaining <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invoice ini sudah lunas. Tidak dapat menerima pembayaran tambahan.')));
      return;
    }
    if (value > remaining) {
      final formatted = remaining.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Pembayaran melebihi sisa tagihan Rp $formatted.')));
      return;
    }
    final date = '${paymentDate.year.toString().padLeft(4, '0')}-${paymentDate.month.toString().padLeft(2, '0')}-${paymentDate.day.toString().padLeft(2, '0')}';

    setState(() => submitting = true);
    try {
      final idToken = await GoogleAuthService.instance.requireIdToken();
      final paymentPayload = <String, dynamic>{
        'invoice': invoice.text.trim(),
        'paymentDate': date,
        'amount': value,
        'method': method,
        'category': category,
        'note': paymentNote.text.trim(),
      };
      final paymentFingerprint = jsonEncode(paymentPayload);
      if (_pendingPaymentPayload != paymentFingerprint) {
        _pendingPaymentPayload = paymentFingerprint;
        _pendingPaymentRequestId = _newTransactionRequestId();
      }
      final response = await ApiService.createPayment(
        idToken: idToken,
        requestId: _pendingPaymentRequestId!,
        data: paymentPayload,
      );
      if (!response.isSuccessful) {
        throw Exception(response.errorMessage ?? 'Pembayaran gagal disimpan ke server.');
      }
      final result = response.data;
      final receipt = result is Map ? (result['receipt']?.toString() ?? '') : '';
      _pendingPaymentRequestId = null;
      _pendingPaymentPayload = null;
      widget.onAdd(OptikPayment(
        invoiceNumber: invoice.text.trim(),
        paymentDate: paymentDate,
        amount: value,
        method: method,
        category: category,
        note: paymentNote.text.trim(),
      ));
      await _loadOfficialInvoices();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(receipt.isEmpty
            ? 'Pembayaran berhasil dicatat untuk invoice ${invoice.text.trim()}.'
            : 'Pembayaran berhasil dicatat. Kuitansi $receipt sedang diproses.'),
        duration: const Duration(seconds: 6),
      ));
      nominal.clear();
      paymentNote.clear();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Pembayaran belum berhasil dikonfirmasi: ${error.toString().replaceFirst('Exception: ', '')}'),
        duration: const Duration(seconds: 8),
      ));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
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

class _WhatsAppCenterScreenState extends State<WhatsAppCenterScreen> with WidgetsBindingObserver {
  Customer? selectedCustomer;
  String? selectedInvoice;
  String template = 'Konfirmasi pesanan';
  final message = TextEditingController();
  List<Map<String, String>> officialOrders = [];
  List<Map<String, String>> officialPayments = [];
  // Keep customer objects stable between rebuilds: DropdownButton matches values by ==.
  List<Customer> officialCustomers = [];
  late final List<Customer> _orderCustomers;
  bool loadingOfficialData = false;
  bool _refreshRequested = false;
  String? syncError;
  Timer? _syncTimer;
  DateTime? _lastSyncedAt;
  List<String> _sourceOrderHeaders = [];
  List<String> _latestOrderSamples = [];
  String? _lastNewestCustomerKey;
  String? _lastNewestInvoice;

  String _cell(Map<String, String> row, List<String> aliases) {
    String normalize(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    // Exact aliases always win, preventing similarly named fields from mixing.
    for (final alias in aliases) {
      final target = normalize(alias);
      for (final entry in row.entries) {
        if (normalize(entry.key) == target && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    // Accept harmless variations in actual spreadsheet column headings.
    for (final alias in aliases) {
      final tokens = RegExp(r'[a-z0-9]+').allMatches(alias.toLowerCase())
          .map((match) => match.group(0)!)
          .where((token) => token.length > 1)
          .toList();
      if (tokens.length < 2) continue;
      for (final entry in row.entries) {
        final header = normalize(entry.key);
        if (entry.value.trim().isNotEmpty && tokens.every(header.contains)) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  String _customerNameFromRow(Map<String, String> row) => _cell(row, [
    'Nama', 'Nama Pelanggan', 'Nama pelanggan', 'Pelanggan',
    'Nama Customer', 'Customer', 'Nama Konsumen', 'Nama Pemesan',
    'Nama Lengkap', 'Nama Pasien', 'Nama Klien', 'Nama Penerima',
  ]);

  String _invoiceNumber(Map<String, String> row) => _cell(row, [
    'No Invoice', 'Nomor Invoice', 'Nomor invoice', 'No. Invoice',
    'Invoice Number', 'Nomor Tagihan', 'No Tagihan', 'Invoice',
    'No Faktur', 'Nomor Faktur', 'Kode Invoice', 'Invoice ID', 'ID Invoice',
    'No Nota', 'Nomor Nota', 'No Transaksi', 'Nomor Transaksi',
    'No Order', 'Nomor Order', 'Order Number', 'Order ID', 'ID Pesanan',
    'Nomor Pesanan', 'Kode Pesanan',
  ]);

  String _phoneFromRow(Map<String, String> row) {
    int score(String header) {
      final key = header.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
      if (key.isEmpty ||
          key.contains('status') ||
          key.contains('aktif') ||
          key.contains('verifikasi') ||
          key.contains('kirim') ||
          key.contains('catatan') ||
          key.contains('izin')) return 0;

      if (key.contains('whatsapp') || key.contains('kontakwa')) return 130;
      if (key == 'wa' || key.contains('nomorwa') || key.contains('nowa') ||
          (key.startsWith('wa') &&
           (key.contains('pelanggan') || key.contains('customer') ||
            key.contains('kontak') || key.contains('hp') ||
            key.contains('telepon')))) return 125;
      if (key.contains('hpwa') || key.contains('wa pelanggan')) return 120;
      if (key.contains('handphone') || key.contains('nomorhp') ||
          key.contains('nomorponsel') || key.contains('cellphone') ||
          key == 'hp' || key == 'nohp') return 110;
      if (key.contains('telepon') || key.contains('nomortelp') ||
          key.contains('notelp') || key == 'telp') return 100;
      if (key == 'phone' || key.contains('phonepelanggan') ||
          key.contains('customerphone') || key.contains('mobile') ||
          key.contains('contactnumber') || key.contains('nomorkontak') ||
          key == 'contact' || key == 'kontak') return 95;
      return 0;
    }

    final candidates = row.entries
        .where((entry) => entry.value.trim().isNotEmpty && score(entry.key) > 0)
        .toList()
      ..sort((a, b) => score(b.key).compareTo(score(a.key)));

    // Prefer the most explicit WhatsApp column, but skip values such as
    // "Aktif", "Ya", or status text instead of returning the first match.
    for (final entry in candidates) {
      final phone = extractWhatsAppPhone(entry.value);
      if (phone.isNotEmpty) return phone;
    }
    return '';
  }

  int _money(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;

  String _rupiah(int value) => 'Rp ' + value.toString().replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

  bool _paymentBelongsToInvoice(Map<String, String> payment, String invoice) {
    final linkedInvoice = _invoiceNumber(payment);
    if (linkedInvoice.isNotEmpty) return linkedInvoice == invoice;
    // Some response sheets use a different heading; exact cell matching is a safe fallback.
    return payment.values.any((value) => value.trim() == invoice);
  }

  String _documentUrl(Map<String, String> row, List<String> aliases) {
    final values = <String>[
      _cell(row, aliases),
      ...row.entries.where((e) => RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive: false).hasMatch(e.key)).map((e) => e.value),
      ...row.values,
    ];
    for (final value in values) {
      final match = RegExp(r'https?://[^\s<>"]+', caseSensitive: false).firstMatch(value.trim());
      if (match != null) {
        final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;)]+$'), '');
        final uri = Uri.tryParse(raw);
        if (uri != null && (uri.host == 'drive.google.com' || uri.host.endsWith('.google.com'))) return uri.toString();
      }
      final id = value.trim();
      if (RegExp(r'^[A-Za-z0-9_-]{25,}$').hasMatch(id) &&
          RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive: false).hasMatch(aliases.join(' '))) {
        return 'https://drive.google.com/file/d/' + id + '/view';
      }
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _orderCustomers = widget.orders.map((order) => order.customer).toList();
    _loadOfficialData();
    // Keep the WhatsApp picker current while this screen is open. The Google
    // Forms/Sheets workflow may receive orders from another device at any time.
    _syncTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) _loadOfficialData(silent: true);
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _loadOfficialData(silent: true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _syncTimer?.cancel();
    message.dispose();
    super.dispose();
  }

  String _customerKey(Customer customer) {
    final phone = _canonicalPhone(customer.phone);
    return phone.isNotEmpty ? 'phone:$phone' : 'name:${customer.name.trim().toLowerCase()}';
  }

  List<Customer> get _customerOptions {
    final unique = <String, Customer>{};
    // Official Sheet records are authoritative and supply customers absent from local app data.
    for (final customer in officialCustomers) {
      unique.putIfAbsent(_customerKey(customer), () => customer);
    }
    for (final customer in widget.customers) {
      unique.putIfAbsent(_customerKey(customer), () => customer);
    }
    for (final customer in _orderCustomers) {
      unique.putIfAbsent(_customerKey(customer), () => customer);
    }
    final result = unique.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }

  Future<void> _loadOfficialData({bool silent = false}) async {
    if (loadingOfficialData) {
      // Never drop a manual, timer, or app-resume refresh while a fetch is active.
      _refreshRequested = true;
      return;
    }
    String rowSignature(Map<String, String>? row) =>
        row == null ? '' : row.entries.map((e) => e.key + '=' + e.value).join('|');
    String rowsSignature(List<Map<String, String>> rows) =>
        rows.map(rowSignature).join('||');
    final previousInvoice = selectedInvoice;
    final previousCustomer = selectedCustomer == null
        ? ''
        : selectedCustomer!.name + '|' + selectedCustomer!.phone + '|' + selectedCustomer!.address;
    final previousOrder = rowSignature(selectedOfficialOrder);
    final previousPayments = rowsSignature(selectedOfficialPayments);
    final previousCustomerKey =
        selectedCustomer == null ? null : _customerKey(selectedCustomer!);

    if (mounted && !silent) {
      setState(() { loadingOfficialData = true; syncError = null; });
    } else {
      loadingOfficialData = true;
      if (silent) syncError = null;
    }

    // Read the two official tabs independently. A temporary failure in the
    // payment tab must never discard freshly fetched order rows (and vice versa).
    List<Map<String, String>>? fetchedOrders;
    List<Map<String, String>>? fetchedPayments;
    Object? orderError;
    Object? paymentError;

    Future<void> loadOrders() async {
      try {
        fetchedOrders = await SheetsReadService.readTable(
          'DATA_PESANAN',
          forceRefresh: true,
        );
      } catch (error) {
        orderError = error;
      }
    }

    Future<void> loadPayments() async {
      try {
        fetchedPayments = await SheetsReadService.readTable(
          'DATA_PEMBAYARAN',
          forceRefresh: true,
        );
      } catch (error) {
        paymentError = error;
      }
    }

    // Fetch both tabs concurrently, but catch each failure independently.
    await Future.wait([loadOrders(), loadPayments()]);

    if (!mounted) return;

    setState(() {
      if (fetchedOrders != null) {
        final orders = fetchedOrders!.where((row) =>
          row.values.any((value) => value.trim().isNotEmpty)
        ).toList();
        officialOrders = orders;
        _sourceOrderHeaders = orders.isEmpty ? [] : orders.first.keys.toList();
        _latestOrderSamples = orders.reversed.take(5).map((row) {
          final name = _customerNameFromRow(row);
          final invoice = _invoiceNumber(row);
          final phone = _phoneFromRow(row);
          final date = _cell(row, [
            'Tanggal', 'Tanggal Pesanan', 'Tanggal Order', 'Timestamp', 'Cap waktu',
          ]);
          return [
            invoice.isEmpty ? '(invoice tidak terbaca)' : invoice,
            name.isEmpty ? '(nama tidak terbaca)' : name,
            phone.isEmpty ? '(nomor tidak terbaca)' : phone,
            date,
          ].where((value) => value.isNotEmpty).join(' • ');
        }).toList();

        final sheetCustomersByKey = <String, Customer>{};
        for (final row in orders) {
          final name = _customerNameFromRow(row);
          if (name.isEmpty) continue;
          final customer = Customer(
            name: name,
            phone: _phoneFromRow(row),
            address: _cell(row, [
              'Alamat', 'Alamat Pelanggan', 'Alamat Customer', 'Alamat Konsumen',
            ]),
          );
          final phone = _canonicalPhone(customer.phone);
          final key = phone.isNotEmpty
              ? 'phone:' + phone
              : 'name:' + name.trim().toLowerCase();
          sheetCustomersByKey.putIfAbsent(key, () => customer);
        }
        officialCustomers = sheetCustomersByKey.values.toList();

        if (previousCustomerKey != null) {
          for (final option in _customerOptions) {
            if (_customerKey(option) == previousCustomerKey) {
              selectedCustomer = option;
              break;
            }
          }
        }
      }

      if (fetchedPayments != null) {
        officialPayments = fetchedPayments!.where((row) =>
          row.values.any((value) => value.trim().isNotEmpty)
        ).toList();
      }

      loadingOfficialData = false;
      final errors = <String>[];
      if (orderError != null) errors.add('DATA_PESANAN: ' + orderError.toString());
      if (paymentError != null) errors.add('DATA_PEMBAYARAN: ' + paymentError.toString());
      syncError = errors.isEmpty ? null : errors.join(' • ');

      if (fetchedOrders != null && selectedCustomer != null) {
        final customerKey = _customerKey(selectedCustomer!);
        final matches = _ordersForCustomer(selectedCustomer, officialOrders);
        final newestInvoice = matches.isEmpty ? null : _invoiceNumber(matches.first);
        final stillValid = matches.any((row) => _invoiceNumber(row) == selectedInvoice);
        final wasFollowingNewest = selectedInvoice == null ||
            (customerKey == _lastNewestCustomerKey &&
             selectedInvoice == _lastNewestInvoice);
        if (!stillValid || wasFollowingNewest) {
          selectedInvoice = newestInvoice;
        }
        _lastNewestCustomerKey = customerKey;
        _lastNewestInvoice = newestInvoice;
      }

      if (fetchedOrders != null || fetchedPayments != null) {
        _lastSyncedAt = DateTime.now();
      }

      final currentCustomer = selectedCustomer == null
          ? ''
          : selectedCustomer!.name + '|' + selectedCustomer!.phone + '|' + selectedCustomer!.address;
      final messageSourceChanged = previousInvoice != selectedInvoice ||
          previousCustomer != currentCustomer ||
          previousOrder != rowSignature(selectedOfficialOrder) ||
          previousPayments != rowsSignature(selectedOfficialPayments);
      // Keep a staff-edited draft unless its selected official source changed.
      if (messageSourceChanged) _buildMessage();
    });

    // Coalesce refresh requests received during this fetch into one newer read.
    if (_refreshRequested && mounted) {
      _refreshRequested = false;
      await _loadOfficialData(silent: true);
    }
  }

  Map<String, String>? get selectedOfficialOrder {
    for (final row in officialOrders) {
      if (_invoiceNumber(row) == selectedInvoice) return row;
    }
    return null;
  }

  List<Map<String, String>> get selectedOfficialPayments {
    final rows = officialPayments.where((row) =>
      _paymentBelongsToInvoice(row, selectedInvoice ?? '')
    ).toList();
    rows.sort((a, b) => _dateValue(_cell(b, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran']))
        .compareTo(_dateValue(_cell(a, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran']))));
    return rows;
  }

  DateTime _dateValue(String raw) {
    final value = raw.trim();
    final iso = DateTime.tryParse(value);
    if (iso != null) return iso;
    final match = RegExp(r'^(\d{1,2})[/-](\d{1,2})[/-](\d{2,4})').firstMatch(value);
    if (match != null) {
      final day = int.tryParse(match.group(1) ?? '') ?? 1;
      final month = int.tryParse(match.group(2) ?? '') ?? 1;
      var year = int.tryParse(match.group(3) ?? '') ?? 2000;
      if (year < 100) year += 2000;
      return DateTime(year, month, day);
    }
    return DateTime(2000);
  }

  String _canonicalPhone(String value) =>
      normalizeWhatsAppPhone(value);

  String _orderDetailText(Map<String, String>? order) {
    if (order == null) return '';
    final lines = <String>[];

    void add(String label, List<String> aliases, {bool money = false}) {
      final value = _cell(order, aliases);
      if (value.isEmpty) return;
      lines.add(label + ': ' + (money ? _rupiah(_money(value)) : value));
    }

    add('Tanggal pesanan', ['Tanggal', 'Tanggal Pesanan', 'Tanggal Order', 'Timestamp', 'Cap waktu']);
    add('Pemeriksa', ['Dokter', 'Nama Dokter', 'Dokter / Optometris', 'Optometris', 'Pemeriksa', 'Nama Pemeriksa']);
    add('Frame', ['Deskripsi Frame', 'Model Frame', 'Merek Frame', 'Detail Frame', 'Nama Frame', 'Frame']);
    add('Harga frame', ['Harga Frame', 'Harga Bingkai', 'Biaya Frame', 'Nominal Frame'], money: true);
    add('Lensa', ['Deskripsi Lensa', 'Detail Lensa', 'Keterangan Lensa', 'Spesifikasi Lensa', 'Jenis Lensa', 'Tipe Lensa', 'Model Lensa']);
    add('Harga lensa', ['Harga Lensa', 'Biaya Lensa', 'Nominal Lensa'], money: true);
    add('Tambahan', ['Keterangan Lain', 'Deskripsi Lain', 'Rincian Lain', 'Biaya Lain']);
    add('Harga tambahan', ['Harga Lain', 'Harga Lainnya', 'Biaya Lainnya', 'Nominal Lain', 'Nominal Biaya Lain'], money: true);

    String rxValue(List<String> aliases) => _cell(order, aliases);
    final odFields = <String, List<String>>{
      'SPH': ['OD SPH', 'SPH OD', 'Mata Kanan SPH', 'SPH Kanan', 'SPH Mata Kanan', 'Sphere OD', 'OD Sphere'],
      'CYL': ['OD CYL', 'CYL OD', 'Mata Kanan CYL', 'CYL Kanan', 'CYL Mata Kanan', 'Cylinder OD', 'OD Cylinder'],
      'AXIS': ['OD AXIS', 'AXIS OD', 'Mata Kanan AXIS', 'AXIS Kanan', 'AXIS Mata Kanan', 'Axis Kanan'],
      'ADD': ['OD ADD', 'ADD OD', 'Mata Kanan ADD', 'ADD Kanan', 'ADD Mata Kanan'],
      'PD': ['OD PD', 'PD OD', 'PD Kanan', 'PD Mata Kanan', 'Pupil Distance Kanan'],
    };
    final osFields = <String, List<String>>{
      'SPH': ['OS SPH', 'SPH OS', 'Mata Kiri SPH', 'SPH Kiri', 'SPH Mata Kiri', 'Sphere OS', 'OS Sphere'],
      'CYL': ['OS CYL', 'CYL OS', 'Mata Kiri CYL', 'CYL Kiri', 'CYL Mata Kiri', 'Cylinder OS', 'OS Cylinder'],
      'AXIS': ['OS AXIS', 'AXIS OS', 'Mata Kiri AXIS', 'AXIS Kiri', 'AXIS Mata Kiri'],
      'ADD': ['OS ADD', 'ADD OS', 'Mata Kiri ADD', 'ADD Kiri', 'ADD Mata Kiri'],
      'PD': ['OS PD', 'PD OS', 'PD Kiri', 'PD Mata Kiri', 'Pupil Distance Kiri'],
    };
    String eyeText(Map<String, List<String>> fields) {
      final values = <String>[];
      for (final entry in fields.entries) {
        final value = rxValue(entry.value);
        if (value.isNotEmpty) values.add(entry.key + ' ' + value);
      }
      return values.join(' • ');
    }

    final od = eyeText(odFields);
    final os = eyeText(osFields);
    if (od.isNotEmpty) lines.add('Resep OD: ' + od);
    if (os.isNotEmpty) lines.add('Resep OS: ' + os);
    add('Catatan resep', ['Catatan Resep', 'Keterangan Resep', 'Catatan Pemeriksaan', 'Catatan Optik', 'Catatan Resep Mata']);
    add('Catatan pesanan', ['Catatan Invoice', 'Catatan Pesanan', 'Catatan Tambahan', 'Keterangan']);

    return lines.isEmpty ? '' : '\n\nDetail pesanan:\n' + lines.join('\n');
  }

  List<Map<String, String>> _ordersForCustomer(
    Customer? customer,
    List<Map<String, String>> source,
  ) {
    if (customer == null) return [];
    final customerPhone = _canonicalPhone(customer.phone);
    final eligible = source.where((row) => _invoiceNumber(row).isNotEmpty).toList();

    // First use the same canonical phone identity as the order history.
    final phoneMatches = customerPhone.isEmpty
        ? <Map<String, String>>[]
        : eligible.where((row) =>
            _canonicalPhone(_phoneFromRow(row)) == customerPhone
        ).toList();

    // If the phone on an older order changed, keep the customer connected to
    // their official order history by name only when that name does not point
    // to multiple different phone identities. This avoids mixing two people
    // with the same name while still handling a customer's updated phone.
    List<Map<String, String>> matches = phoneMatches;
    if (matches.isEmpty) {
      final nameKey = customer.name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
      final nameMatches = eligible.where((row) =>
        _customerNameFromRow(row).trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ') == nameKey
      ).toList();
      final distinctPhones = nameMatches
          .map((row) => _canonicalPhone(_phoneFromRow(row)))
          .where((phone) => phone.isNotEmpty)
          .toSet();
      if (distinctPhones.length <= 1) {
        matches = nameMatches;
      }
    }
    // Pilih transaksi terbaru lebih dahulu agar invoice/kuitansi tidak tertukar
    // ketika pelanggan mempunyai beberapa transaksi dalam waktu berdekatan.
    matches.sort((a, b) {
      final dateA = _dateValue(_cell(a, ['Tanggal', 'Tanggal Pesanan', 'Tanggal Order', 'Timestamp']));
      final dateB = _dateValue(_cell(b, ['Tanggal', 'Tanggal Pesanan', 'Tanggal Order', 'Timestamp']));
      final byDate = dateB.compareTo(dateA);
      if (byDate != 0) return byDate;
      // If date cells are blank or use an unrecognized format, the newest
      // appended Google Sheets row is the best available chronology signal.
      return source.indexOf(b).compareTo(source.indexOf(a));
    });
    return matches;
  }

  List<Map<String, String>> get customerOrders =>
      _ordersForCustomer(selectedCustomer, officialOrders);

  void _chooseCustomer(Customer? customer) {
    setState(() {
      selectedCustomer = customer;
      final matches = customerOrders;
      selectedInvoice = matches.isEmpty ? null : _invoiceNumber(matches.first);
      _lastNewestCustomerKey = customer == null ? null : _customerKey(customer);
      _lastNewestInvoice = selectedInvoice;
      _buildMessage();
    });
  }

  void _buildMessage() {
    final customer = selectedCustomer;
    final order = selectedOfficialOrder;
    if (customer == null) { message.text = ''; return; }
    final invoice = order == null ? '-' : _invoiceNumber(order);
    final totalAmount = order == null ? 0 : _money(_cell(order, ['Total', 'Total Harga', 'Total Tagihan']));
    final payments = selectedOfficialPayments;
    final paymentSum = payments.fold<int>(0, (sum, row) =>
      sum + _money(_cell(row, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Nominal Pembayaran', 'Nominal Bayar', 'Nominal', 'Total Bayar'])));
    final paidValue = order == null ? 0 : (_cell(order, ['Total Dibayar', 'Total Dibayar Kumulatif']).isNotEmpty
        ? _money(_cell(order, ['Total Dibayar', 'Total Dibayar Kumulatif'])) : paymentSum);
    final remainingValue = order == null ? 0 : (totalAmount - paidValue).clamp(0, totalAmount);
    final total = order == null ? '-' : _rupiah(totalAmount);
    final paid = order == null ? '-' : _rupiah(paidValue);
    final balance = order == null ? '-' : _rupiah(remainingValue);
    final invoicePdf = order == null ? '' : _documentUrl(order, [
      'Link Invoice PDF', 'PDF Invoice', 'Link PDF Invoice', 'Invoice PDF', 'URL Invoice PDF',
    ]);
    final latestPayment = payments.isEmpty ? null : payments.first;
    final receiptPdf = latestPayment == null ? '' : _documentUrl(latestPayment, [
      'PDF Kuitansi', 'Link PDF Kuitansi', 'Link Kuitansi', 'Link Kuitansi PDF', 'Kuitansi PDF',
    ]);
    final documentLinks = (invoicePdf.isEmpty ? '' : '\nPDF Invoice: ' + invoicePdf) +
        (receiptPdf.isEmpty ? '' : '\nPDF Kuitansi: ' + receiptPdf);
    final orderDetails = _orderDetailText(order);
    if (template == 'Pesanan siap diambil') {
      message.text = 'Halo ' + customer.name + ' 👋\nKami dari OPTIK LENTERA ingin menginformasikan bahwa pesanan kacamata Anda sudah siap diambil.\nNomor invoice: ' + invoice + orderDetails + documentLinks + '\nSilakan datang pada jam operasional kami. Terima kasih 🙏';
    } else if (template == 'Pengingat pembayaran') {
      final paymentText = latestPayment == null ? '' : '\nPembayaran terakhir: ' +
        _rupiah(_money(_cell(latestPayment, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Nominal Pembayaran', 'Nominal Bayar', 'Nominal', 'Total Bayar']))) +
        ' (' + _cell(latestPayment, ['Metode', 'Metode Pembayaran']) + ')';
      message.text = 'Halo ' + customer.name + ' 👋\nKami dari OPTIK LENTERA mengingatkan bahwa masih terdapat sisa pembayaran pesanan Anda.\nNomor invoice: ' + invoice + '\nTotal tagihan: ' + total + '\nTotal sudah dibayar: ' + paid + '\nSisa tagihan: ' + balance + paymentText + orderDetails + documentLinks + '\nJika sudah melakukan pembayaran, mohon abaikan pesan ini. Terima kasih 🙏';
    } else if (template == 'Tindak lanjut pelanggan') {
      message.text = 'Halo ' + customer.name + ' 👋\nApa kabar? Kami dari OPTIK LENTERA ingin menanyakan apakah kacamata Anda nyaman digunakan. Jika ada yang perlu disesuaikan, silakan hubungi kami. Terima kasih 🙏' + orderDetails + documentLinks;
    } else {
      message.text = 'Halo ' + customer.name + ' 👋\nTerima kasih telah mempercayakan kebutuhan kacamata Anda kepada OPTIK LENTERA.\n' +
        (order == null ? 'Nomor invoice belum ditemukan pada data resmi.' : 'Nomor invoice: ' + invoice + '\nTotal pesanan: ' + total + '\nTotal dibayar: ' + paid + '\nSisa tagihan: ' + balance) +
        orderDetails + documentLinks + '\nJika ada pertanyaan, silakan balas pesan ini. Terima kasih 🙏';
    }
  }

  String _phoneForWhatsApp(String raw) => extractWhatsAppPhone(raw);

  String get _selectedWhatsAppPhone {
    final row = selectedOfficialOrder;
    final fromInvoice = row == null ? '' : _phoneForWhatsApp(_phoneFromRow(row));
    return fromInvoice.isNotEmpty
        ? fromInvoice
        : _phoneForWhatsApp(selectedCustomer?.phone ?? '');
  }

  Future<void> _openWhatsApp() async {
    final customer = selectedCustomer;
    if (customer == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Pilih pelanggan terlebih dahulu.')));
      return;
    }
    final phone = _selectedWhatsAppPhone;
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Nomor WhatsApp belum terbaca dari data pelanggan. Periksa kolom No WA / WhatsApp / HP di DATA_PESANAN.'),
      ));
      return;
    }
    if (!isValidWhatsAppPhone(phone)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Nomor WhatsApp yang terbaca (' + phone + ') belum valid. Periksa kembali angka pada data pelanggan.'),
      ));
      return;
    }
    // Prefer WhatsApp's native URI so Android opens the installed app
    // instead of treating a successful browser launch as a WhatsApp handoff.
    // If the app is unavailable, fall back to the official universal links.
    final links = <Uri>[
      Uri(
        scheme: 'whatsapp',
        host: 'send',
        queryParameters: {'phone': phone, 'text': message.text},
      ),
      Uri.https('wa.me', '/' + phone, {'text': message.text}),
      Uri.https('api.whatsapp.com', '/send', {
        'phone': phone,
        'text': message.text,
      }),
    ];
    Object? lastError;
    for (final uri in links) {
      try {
        final opened = await launchUrl(
          uri,
          mode: LaunchMode.externalApplication,
        );
        if (opened) return;
      } catch (error) {
        lastError = error;
      }
    }
    if (mounted) {
      final detail = lastError == null ? '' : ' (' + lastError.toString() + ')';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('WhatsApp gagal dibuka untuk nomor ' + phone + detail),
        duration: const Duration(seconds: 8),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final customerOptions = _customerOptions;
    // A sheet can contain repeated invoice rows; DropdownButton requires unique values.
    final uniqueInvoices = <String, Map<String, String>>{};
    for (final row in customerOrders) {
      final number = _invoiceNumber(row);
      if (number.isNotEmpty) uniqueInvoices.putIfAbsent(number, () => row);
    }
    final invoiceOptions = uniqueInvoices.values.toList();
    final invoiceIsValid = invoiceOptions.any((row) =>
      _invoiceNumber(row) == selectedInvoice);
    return ListView(
      padding: const EdgeInsets.all(18),
      children: [
        const _Intro('WhatsApp Semi-Otomatis', 'Pilih pelanggan dan template. Nomor invoice dan dokumen resmi disinkronkan dari Google Sheets.', Icons.chat_outlined),
        const SizedBox(height: 16),
        _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          DropdownButtonFormField<Customer>(
            value: customerOptions.contains(selectedCustomer) ? selectedCustomer : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Pilih pelanggan', border: OutlineInputBorder()),
            items: customerOptions.map((c) => DropdownMenuItem(value: c, child: Text(c.name + ' • ' + c.phone, overflow: TextOverflow.ellipsis))).toList(),
            onChanged: customerOptions.isEmpty ? null : _chooseCustomer,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: invoiceIsValid ? selectedInvoice : null,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Pilih invoice (opsional)',
              helperText: loadingOfficialData ? 'Mengambil nomor invoice resmi…' : (syncError == null ? 'Diambil dari DATA_PESANAN' : 'Sinkronisasi gagal; tekan muat ulang'),
              border: const OutlineInputBorder(),
            ),
            items: invoiceOptions.map((row) {
              final number = _invoiceNumber(row);
              final name = _customerNameFromRow(row);
              return DropdownMenuItem<String>(value: number, child: Text(number + (name.isEmpty ? '' : ' • ' + name), overflow: TextOverflow.ellipsis));
            }).toList(),
            onChanged: (value) => setState(() { selectedInvoice = value; _buildMessage(); }),
          ),
          if (loadingOfficialData) const LinearProgressIndicator(),
          if (!loadingOfficialData)
            Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                  officialOrders.length.toString() + ' baris pesanan terbaca • ' +
                  officialOrders.where((row) => _invoiceNumber(row).isNotEmpty).length.toString() +
                  ' invoice • ' +
                  officialOrders.where((row) => _phoneFromRow(row).isNotEmpty).length.toString() +
                  ' nomor WA valid • ' + officialPayments.length.toString() +
                  ' pembayaran • ' + customerOptions.length.toString() + ' pelanggan',
                  style: const TextStyle(fontSize: 10, color: Colors.black54),
                ),
                if (_lastSyncedAt != null)
                  Text('Terakhir disinkronkan: ' +
                    _lastSyncedAt!.day.toString().padLeft(2, '0') + '/' +
                    _lastSyncedAt!.month.toString().padLeft(2, '0') + ' ' +
                    _lastSyncedAt!.hour.toString().padLeft(2, '0') + ':' +
                    _lastSyncedAt!.minute.toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 9, color: Colors.black45)),
                if (_sourceOrderHeaders.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 5),
                    child: Text(
                      'Kolom sumber: ' + _sourceOrderHeaders.join(' | '),
                      style: const TextStyle(fontSize: 9, color: Colors.black45),
                    ),
                  ),
                if (_latestOrderSamples.isNotEmpty)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    childrenPadding: EdgeInsets.zero,
                    title: const Text('Periksa 5 baris paling akhir dari Sheets',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                    children: _latestOrderSamples.map((sample) => Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(sample,
                          style: const TextStyle(fontSize: 10, color: Colors.black54)),
                      ),
                    )).toList(),
                  ),
                if (selectedCustomer != null)
                  Text(
                    'Nomor yang akan dibuka: ' +
                    (_selectedWhatsAppPhone.isEmpty ? 'belum terbaca' : _selectedWhatsAppPhone),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _ink),
                  ),
              ]),
            ),
          if (syncError != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Peringatan sinkronisasi: ' + syncError! +
                '\nBaris yang gagal diambil dapat masih menampilkan data dari sinkronisasi sebelumnya.',
                style: const TextStyle(fontSize: 10, color: Colors.redAccent),
              ),
            ),
            TextButton.icon(
              onPressed: loadingOfficialData ? null : _loadOfficialData,
              icon: const Icon(Icons.refresh),
              label: const Text('Coba ambil ulang data resmi'),
            ),
          ],
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: template,
            decoration: const InputDecoration(labelText: 'Template pesan', border: OutlineInputBorder()),
            items: const ['Konfirmasi pesanan', 'Pesanan siap diambil', 'Pengingat pembayaran', 'Tindak lanjut pelanggan'].map((v) => DropdownMenuItem(value: v, child: Text(v))).toList(),
            onChanged: (value) => setState(() { template = value ?? 'Konfirmasi pesanan'; _buildMessage(); }),
          ),
          const SizedBox(height: 12),
          TextField(controller: message, minLines: 6, maxLines: 14,
            decoration: const InputDecoration(labelText: 'Pesan (bisa diedit sebelum dikirim)', alignLabelWithHint: true, border: OutlineInputBorder())),
          const SizedBox(height: 14),
          SizedBox(width: double.infinity, child: FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFF168C54), padding: const EdgeInsets.symmetric(vertical: 14)),
            onPressed: _openWhatsApp, icon: const Icon(Icons.chat), label: const Text('Buka WhatsApp & Tinjau Pesan'))),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: loadingOfficialData ? null : _loadOfficialData,
            icon: const Icon(Icons.sync),
            label: const Text('Perbarui data pesanan & pembayaran terbaru'),
          ),
          const SizedBox(height: 8),
          const Text('PDF resmi tidak dibuat oleh aplikasi. Tautan yang tersedia diambil dari catatan resmi Google Sheets/Drive.', style: TextStyle(fontSize: 11, color: Colors.black54)),
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
    String normalize(String value) =>
        value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final alias in aliases) {
      final target = normalize(alias);
      for (final entry in row.entries) {
        if (normalize(entry.key) == target && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  bool _paymentBelongsToInvoice(Map<String, String> payment, String invoice) {
    final linkedInvoice = _cell(payment, [
      'No Invoice', 'Nomor Invoice', 'Nomor invoice', 'No. Invoice',
      'Invoice', 'Invoice Number', 'Nomor Tagihan',
    ]);
    if (linkedInvoice.isNotEmpty) return linkedInvoice == invoice;
    return payment.values.any((value) => value.trim() == invoice);
  }

  String _documentUrl(Map<String, String> row, List<String> aliases) {
    final candidates = <String>[
      _cell(row, aliases),
      ...row.entries
          .where((entry) =>
              RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive: false)
                  .hasMatch(entry.key))
          .map((entry) => entry.value),
      ...row.values,
    ];
    final urlPattern = RegExp(r'https?://[^\s<>"]+', caseSensitive: false);
    for (final candidate in candidates) {
      final matches = urlPattern.allMatches(candidate.trim());
      for (final match in matches) {
        final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;)]+$'), '');
        final uri = Uri.tryParse(raw);
        if (uri != null &&
            (uri.host.toLowerCase() == 'drive.google.com' ||
             uri.host.toLowerCase().endsWith('.google.com')) &&
            (uri.path.contains('/file/') || uri.path.contains('/document/') ||
             uri.queryParameters.containsKey('id'))) {
          return uri.toString();
        }
      }
      final value = candidate.trim();
      if (RegExp(r'^[A-Za-z0-9_-]{25,}$').hasMatch(value) &&
          RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive: false)
              .hasMatch(aliases.join(' '))) {
        return 'https://drive.google.com/file/d/$value/view';
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
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      if (!mounted) return;
      setState(() {
        orders = tables[0].where((row) =>
          _cell(row, ['No Invoice', 'Nomor Invoice', 'Nomor invoice']).isNotEmpty
        ).toList();
        // Keep rows even when the form uses a different invoice column heading.
        payments = tables[1].where((row) =>
          row.values.any((value) => value.trim().isNotEmpty)
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
              _paymentBelongsToInvoice(payment, invoice)
            ).toList();
            final invoicePdf = _documentUrl(order, [
              'Link Invoice PDF', 'PDF Invoice', 'Link PDF Invoice',
              'Invoice PDF', 'URL Invoice PDF', 'URL PDF Invoice',
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
                      final receiptPdf = _documentUrl(payment, [
                        'PDF Kuitansi', 'Link PDF Kuitansi', 'Link Kuitansi', 'Link Kuitansi PDF',
                        'Kuitansi PDF', 'URL Kuitansi PDF', 'URL PDF Kuitansi',
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


class _DocumentNotice {
  final String id, type, title, detail, url;
  const _DocumentNotice({required this.id, required this.type, required this.title, required this.detail, required this.url});
}

class DocumentNotificationsScreen extends StatefulWidget {
  const DocumentNotificationsScreen({super.key});
  @override
  State<DocumentNotificationsScreen> createState() => _DocumentNotificationsScreenState();
}

class _DocumentNotificationsScreenState extends State<DocumentNotificationsScreen> {
  List<_DocumentNotice> _notices = [];
  Map<String, String> _statuses = {};
  bool _loading = true;
  String? _error;

  String _key(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  String _cell(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final target = _key(alias);
      for (final entry in row.entries) {
        if (_key(entry.key) == target && entry.value.trim().isNotEmpty) return entry.value.trim();
      }
    }
    return '';
  }

  String _url(Map<String, String> row, List<String> aliases) {
    final candidates = <String>[
      _cell(row, aliases),
      ...row.entries.where((e) => RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive: false).hasMatch(e.key)).map((e) => e.value),
    ];
    final pattern = RegExp(r'https?://[^\s<>"\x27]+', caseSensitive: false);
    for (final candidate in candidates) {
      for (final match in pattern.allMatches(candidate.trim())) {
        final raw = match.group(0)!.replaceFirst(RegExp(r'[.,;)]+$'), '');
        final uri = Uri.tryParse(raw);
        if (uri != null && uri.scheme == 'https' &&
            (uri.host == 'drive.google.com' || uri.host.endsWith('.google.com')) &&
            (uri.path.contains('/file/') || uri.path.contains('/document/') || uri.queryParameters.containsKey('id'))) {
          return uri.toString();
        }
      }
    }
    return '';
  }

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('ol_document_notice_status') ?? '{}');
      final statuses = decoded is Map
          ? decoded.map((key, value) => MapEntry(key.toString(), value.toString()))
          : <String, String>{};
      final tables = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      final notices = <_DocumentNotice>[];
      for (final order in tables[0]) {
        final invoice = _cell(order, ['No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice', 'Nomor Tagihan']);
        if (invoice.isEmpty) continue;
        final url = _url(order, ['Link Invoice PDF', 'PDF Invoice', 'Link PDF Invoice', 'Invoice PDF', 'URL Invoice PDF']);
        if (url.isEmpty) continue;
        final name = _cell(order, ['Nama', 'Nama Pelanggan', 'Nama pelanggan']);
        notices.add(_DocumentNotice(id: 'invoice:' + invoice, type: 'Invoice',
          title: name.isEmpty ? invoice : name, detail: invoice, url: url));
      }
      for (final payment in tables[1]) {
        final receipt = _cell(payment, ['No Kuitansi', 'Nomor Kuitansi', 'Nomor kuitansi']);
        final invoice = _cell(payment, ['No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice']);
        final url = _url(payment, ['PDF Kuitansi', 'Link PDF Kuitansi', 'Link Kuitansi', 'Link Kuitansi PDF', 'Kuitansi PDF', 'URL Kuitansi PDF']);
        if (url.isEmpty) continue;
        final id = receipt.isNotEmpty ? receipt : invoice + '_' + _cell(payment, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran']) + '_' + _cell(payment, ['Jumlah Bayar', 'Jumlah Pembayaran']);
        if (id.replaceAll('_', '').isEmpty) continue;
        notices.add(_DocumentNotice(id: 'receipt:' + id, type: 'Kuitansi',
          title: receipt.isEmpty ? (invoice.isEmpty ? 'Kuitansi pembayaran' : invoice) : receipt,
          detail: invoice.isEmpty ? 'Dokumen pembayaran resmi' : 'Invoice ' + invoice, url: url));
      }
      if (!mounted) return;
      setState(() { _notices = notices; _statuses = statuses; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _error = error.toString(); _loading = false; });
    }
  }

  Future<void> _setStatus(_DocumentNotice notice, String status) async {
    final next = Map<String, String>.from(_statuses)..[notice.id] = status;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ol_document_notice_status', jsonEncode(next));
    if (mounted) setState(() => _statuses = next);
  }

  Future<void> _open(_DocumentNotice notice) async {
    final uri = Uri.tryParse(notice.url);
    var opened = false;
    try {
      opened = uri != null &&
          await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened) await _setStatus(notice, 'review');
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(opened
      ? 'Tautan dibuka. Periksa PDF; tandai terkirim hanya setelah WhatsApp benar-benar dikirim.'
      : 'Tautan gagal dibuka. Dokumen perlu diperiksa.')));
  }

  @override
  Widget build(BuildContext context) {
    final pending = _notices.where((n) => _statuses[n.id] != 'sent').length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(padding: const EdgeInsets.all(18), children: [
        const _Intro('Notifikasi Dokumen', 'Pengingat dari tautan PDF resmi pada Google Sheets. Pengiriman WhatsApp tetap manual.', Icons.notifications_active_outlined),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: Text(pending.toString() + ' dokumen perlu ditindaklanjuti', style: const TextStyle(color: _darkGold, fontWeight: FontWeight.w700))),
          IconButton(onPressed: _loading ? null : _load, tooltip: 'Segarkan', icon: const Icon(Icons.sync)),
        ]),
        if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator()))
        else if (_error != null) _Panel(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Data notifikasi belum dapat dibaca.'),
          Text(_error!, style: const TextStyle(fontSize: 11, color: Colors.deepOrange)),
          TextButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Coba lagi')),
        ]))
        else if (_notices.isEmpty) const _Empty('Belum ada tautan PDF invoice atau kuitansi resmi pada data yang terbaca.')
        else ..._notices.map((notice) {
          final status = _statuses[notice.id] ?? 'ready';
          final sent = status == 'sent';
          final review = status == 'review';
          return Card(color: Colors.white, margin: const EdgeInsets.only(bottom: 10), child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(notice.type == 'Invoice' ? Icons.receipt_long_outlined : Icons.payments_outlined, color: _darkGold),
                const SizedBox(width: 9),
                Expanded(child: Text(notice.type + ' • ' + notice.title, style: const TextStyle(fontWeight: FontWeight.bold, color: _ink))),
                Text(sent ? 'Terkirim' : review ? 'Perlu cek' : 'Siap ditinjau',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: sent ? Colors.green : review ? Colors.deepOrange : _darkGold)),
              ]),
              const SizedBox(height: 5),
              Text(notice.detail, style: const TextStyle(fontSize: 11, color: Colors.black54)),
              const SizedBox(height: 9),
              Wrap(spacing: 8, runSpacing: 4, children: [
                OutlinedButton.icon(onPressed: () => _open(notice), icon: const Icon(Icons.picture_as_pdf_outlined), label: const Text('Periksa PDF')),
                if (!sent) TextButton.icon(onPressed: () => _setStatus(notice, 'sent'),
                  icon: const Icon(Icons.check_circle_outline), label: const Text('Tandai terkirim'))
                else TextButton.icon(onPressed: () => _setStatus(notice, 'ready'),
                  icon: const Icon(Icons.undo), label: const Text('Batalkan status')),
              ]),
              if (!sent) const Text('Status terkirim hanya dicatat setelah petugas mengirim sendiri melalui WhatsApp.',
                style: TextStyle(fontSize: 10, color: Colors.black45)),
            ]),
          ));
        }),
      ]),
    );
  }
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

