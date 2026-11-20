import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_service.dart';
import 'models/optik_models.dart';
import 'screens/operational_screens.dart';
import 'assets/optik_brand_assets.dart';


void main() {
  runApp(const OptikLenteraApp());
}

const Color cream = Color(0xFFFAF7F0);
const Color gold = Color(0xFFC5A46D);
const Color darkGold = Color(0xFF8B6B3F);
const Color pink = Color(0xFFEADBD8);
const Color ink = Color(0xFF24221E);

class OptikLenteraApp extends StatelessWidget {
  const OptikLenteraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OPTIK LENTERA',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: cream,
        colorScheme: ColorScheme.fromSeed(
          seedColor: gold,
          surface: cream,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(),
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: darkGold,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: false,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFFFFFCF8),
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: gold.withValues(alpha: .28)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: gold.withValues(alpha: .28)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: darkGold, width: 1.5),
          ),
          labelStyle: const TextStyle(color: Color(0xFF82766A), fontSize: 13),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: darkGold,
            foregroundColor: Colors.white,
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            textStyle: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: darkGold,
            minimumSize: const Size(46, 46),
            side: BorderSide(color: gold.withValues(alpha: .55)),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: ink,
          indicatorColor: gold.withValues(alpha: .22),
          height: 72,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 9.5,
            letterSpacing: .1,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? gold : const Color(0xFFB7AEA1),
          )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? gold : const Color(0xFFB7AEA1),
          )),
        ),
        snackBarTheme: SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: ink,
          contentTextStyle: const TextStyle(color: Colors.white, fontSize: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
      home: const MainScreen(),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _PagePalette {
  final Color accent;
  final Color background;
  const _PagePalette(this.accent, this.background);
}

_PagePalette _paletteFor(int index) {
  switch (index) {
    case 1:
      return const _PagePalette(Color(0xFF914F5B), Color(0xFFFBF5F4)); // Burgundy
    case 2:
      return const _PagePalette(Color(0xFF5D7967), Color(0xFFF4F7F2)); // Sage
    case 3:
      return const _PagePalette(Color(0xFFAD7180), Color(0xFFFAF4F5)); // Dusty rose
    case 4:
      return const _PagePalette(Color(0xFF3F7774), Color(0xFFF2F7F6)); // Deep teal
    case 5:
    case 6:
      return const _PagePalette(Color(0xFF8B6B3F), Color(0xFFFAF7F0)); // Ivory gold
    case 7:
      return const _PagePalette(Color(0xFF3F7774), Color(0xFFF2F7F6)); // Deep teal
    default:
      return const _PagePalette(Color(0xFF8B6B3F), Color(0xFFFAF7F0)); // Champagne
  }
}

class _MainScreenState extends State<MainScreen> {
  int selectedIndex = 0;
  final List<Customer> customers = [];
  final List<OptikOrder> orders = [];
  final List<OptikPayment> payments = [];
  bool _loadingLocalData = true;
  bool _localDataReady = false;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
  }

  Future<void> _loadLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final customerData = jsonDecode(prefs.getString('ol_customers') ?? '[]') as List<dynamic>;
      final orderData = jsonDecode(prefs.getString('ol_orders') ?? '[]') as List<dynamic>;
      final paymentData = jsonDecode(prefs.getString('ol_payments') ?? '[]') as List<dynamic>;
      customers.addAll(customerData.map((item) => Customer.fromJson(Map<String, dynamic>.from(item as Map))));
      orders.addAll(orderData.map((item) => OptikOrder.fromJson(Map<String, dynamic>.from(item as Map))));
      payments.addAll(paymentData.map((item) => OptikPayment.fromJson(Map<String, dynamic>.from(item as Map))));
    } catch (_) {
      // Data sesi tetap bisa dipakai bila cache versi lama tidak bisa dibaca.
    }
    if (!mounted) return;
    setState(() {
      _localDataReady = true;
      _loadingLocalData = false;
    });
  }

  Future<void> _saveLocalData() async {
    if (!_localDataReady) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ol_customers', jsonEncode(customers.map((item) => item.toJson()).toList()));
    await prefs.setString('ol_orders', jsonEncode(orders.map((item) => item.toJson()).toList()));
    await prefs.setString('ol_payments', jsonEncode(payments.map((item) => item.toJson()).toList()));
  }

  void _addCustomer(Customer value) {
    setState(() => customers.add(value));
    _saveLocalData();
  }

  void _addOrder(OptikOrder value) {
    setState(() => orders.add(value));
    _saveLocalData();
    _syncOrderToServer(value);
  }

  Future<void> _syncOrderToServer(OptikOrder value) async {
    if (!ApiService.isConfigured) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pesanan tersimpan lokal. Token API belum dipasang untuk sinkronisasi.')),
      );
      return;
    }
    try {
      final result = await ApiService.createOrder(value);
      final invoice = result['invoiceNumber']?.toString() ?? '';
      if (invoice.isEmpty) throw StateError('Backend tidak mengembalikan nomor invoice.');
      final index = orders.indexWhere((item) => item.invoiceNumber == value.invoiceNumber);
      if (index >= 0) {
        setState(() => orders[index] = orders[index].copyWith(invoiceNumber: invoice));
        await _saveLocalData();
      }
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan tersinkron ke Google Sheets: $invoice')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pesanan tetap tersimpan lokal; sinkronisasi gagal: $error')),
      );
    }
  }

  void _addPayment(OptikPayment value) {
    setState(() => payments.add(value));
    _saveLocalData();
    _syncPaymentToServer(value);
  }

  Future<void> _syncPaymentToServer(OptikPayment value) async {
    if (!ApiService.isConfigured) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pembayaran tersimpan lokal. Token API belum dipasang untuk sinkronisasi.')),
      );
      return;
    }
    try {
      final result = await ApiService.createPayment(value);
      final receipt = result['receiptNumber']?.toString() ?? '';
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(receipt.isEmpty ? 'Pembayaran tersinkron ke Google Sheets.' : 'Pembayaran tersinkron: kuitansi $receipt')),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Pembayaran tetap tersimpan lokal; sinkronisasi gagal: $error')),
      );
    }
  }

  final List<String> navigation = [
    'Beranda',
    'Transaksi',
    'Pelanggan',
    'Lainnya',
    'Pembayaran',
    'Dokumen',
  ];

  Future<void> _showMoreMenu() async {
    final destination = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (sheetContext) => Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
        decoration: const BoxDecoration(
          color: Color(0xFFFFFCF8),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(color: gold.withValues(alpha: .45), borderRadius: BorderRadius.circular(8)),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Menu lainnya', style: TextStyle(color: ink, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Pilih layanan yang ingin dibuka.', style: TextStyle(color: Colors.black54, fontSize: 12)),
              const SizedBox(height: 16),
              _MoreMenuTile(
                icon: Icons.payments_outlined,
                title: 'Pembayaran',
                subtitle: 'Catat pembayaran dan pelunasan',
                onTap: () => Navigator.pop(sheetContext, 4),
              ),
              const SizedBox(height: 9),
              _MoreMenuTile(
                icon: Icons.description_outlined,
                title: 'Invoice & Dokumen',
                subtitle: 'Lihat, cetak, dan bagikan dokumen',
                onTap: () => Navigator.pop(sheetContext, 5),
              ),
              const SizedBox(height: 9),
              _MoreMenuTile(
                icon: Icons.insights_outlined,
                title: 'Laporan',
                subtitle: 'Ringkasan transaksi dan salin data CSV',
                onTap: () => Navigator.pop(sheetContext, 6),
              ),
              const SizedBox(height: 9),
              _MoreMenuTile(
                icon: Icons.local_shipping_outlined,
                title: 'Status Pesanan',
                subtitle: 'Pantau pesanan dan status pembayaran',
                onTap: () => Navigator.pop(sheetContext, 7),
              ),
            ],
          ),
        ),
      ),
    );
    if (destination != null && mounted) {
      setState(() => selectedIndex = destination);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pagePalette = _paletteFor(selectedIndex);
    final baseTheme = Theme.of(context);
    return Theme(
      data: baseTheme.copyWith(
        colorScheme: baseTheme.colorScheme.copyWith(
          primary: pagePalette.accent,
          secondary: pagePalette.accent,
        ),
        scaffoldBackgroundColor: pagePalette.background,
        inputDecorationTheme: baseTheme.inputDecorationTheme.copyWith(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: pagePalette.accent, width: 1.6),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: pagePalette.accent.withValues(alpha: .24)),
          ),
        ),
        navigationBarTheme: baseTheme.navigationBarTheme.copyWith(
          indicatorColor: pagePalette.accent.withValues(alpha: .23),
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 9.5,
            letterSpacing: .1,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? pagePalette.accent : const Color(0xFFB7AEA1),
          )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? gold : const Color(0xFFB7AEA1),
          )),
        ),
      ),
      child: Scaffold(
      backgroundColor: pagePalette.background,
      appBar: AppBar(
        backgroundColor: pagePalette.background,
        foregroundColor: pagePalette.accent,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            const _OptikLogo(size: 42),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('OPTIK LENTERA', style: TextStyle(color: pagePalette.accent, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                Text('Sistem Manajemen Optik', style: TextStyle(color: Colors.black54, fontSize: 10)),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: pagePalette.accent.withValues(alpha: .13),
              child: Icon(Icons.person_outline, color: pagePalette.accent),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingLocalData
            ? const Center(child: CircularProgressIndicator(color: darkGold))
            : switch (selectedIndex) {
          0 => DashboardContent(
            onOpenModule: (index) => setState(() => selectedIndex = index),
            orderCount: orders.length,
            paymentTotal: payments.fold<int>(0, (sum, item) => sum + item.amount),
          ),
          1 => TransactionScreen(customers: customers, orders: orders, onAdd: _addOrder),
          2 => CustomerScreen(customers: customers, onAdd: _addCustomer),
          3 => WhatsAppCenterScreen(customers: customers, orders: orders, payments: payments),
          4 => PaymentEntryScreen(payments: payments, orders: orders, onAdd: _addPayment),
          5 => InvoiceReceiptScreen(orders: orders, payments: payments),
          6 => ReportsScreen(customers: customers, orders: orders, payments: payments),
          7 => OrderStatusScreen(orders: orders, payments: payments),
          _ => OtherContent(title: navigation[selectedIndex]),
        },
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: ink,
          border: Border(top: BorderSide(color: gold.withValues(alpha: .34))),
          boxShadow: [
            BoxShadow(color: ink.withValues(alpha: .045), blurRadius: 16, offset: const Offset(0, -5)),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: pagePalette.accent.withValues(alpha: .22),
          selectedIndex: selectedIndex >= 4 ? 4 : selectedIndex,
          onDestinationSelected: (index) {
            if (index == 4) {
              _showMoreMenu();
            } else {
              setState(() => selectedIndex = index);
            }
          },
          destinations: [
            NavigationDestination(
              icon: const Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: pagePalette.accent),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: pagePalette.accent),
              label: 'Transaksi',
            ),
            NavigationDestination(
              icon: const Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded, color: pagePalette.accent),
              label: 'Pelanggan',
            ),
            NavigationDestination(
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: pagePalette.accent),
              label: 'WhatsApp',
            ),
            NavigationDestination(
              icon: Icon(selectedIndex >= 4 ? Icons.grid_view_rounded : Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded, color: pagePalette.accent),
              label: 'Lainnya',
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class ReportsScreen extends StatelessWidget {
  final List<Customer> customers;
  final List<OptikOrder> orders;
  final List<OptikPayment> payments;
  const ReportsScreen({super.key, required this.customers, required this.orders, required this.payments});

  int _later(OptikOrder order) => payments
      .where((p) => order.invoiceNumber.isNotEmpty && p.invoiceNumber == order.invoiceNumber)
      .fold<int>(0, (sum, p) => sum + p.amount);

  String _money(int value) {
    final digits = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return 'Rp ' + out.toString();
  }

  String _cell(Object? value) => '"' + (value?.toString() ?? '').replaceAll('"', '""') + '"';

  Future<void> _copyCsv(BuildContext context) async {
    final rows = <List<Object?>>[
      ['Jenis', 'Invoice', 'Tanggal', 'Pelanggan', 'Telepon', 'Total', 'DP', 'Pembayaran lanjutan', 'Sisa', 'Metode', 'Catatan', 'Alamat'],
    ];
    for (final customer in customers) {
      rows.add(['Pelanggan', '', '', customer.name, customer.phone, '', '', '', '', '', '', customer.address]);
    }
    for (final order in orders) {
      final later = _later(order);
      rows.add([
        'Pesanan', order.invoiceNumber, order.orderDate?.toIso8601String() ?? '',
        order.customer.name, order.customer.phone, order.total, order.initialPayment,
        later, (order.total - order.initialPayment - later).clamp(0, 1 << 31).toInt(),
        order.initialPaymentMethod, order.note, '',
      ]);
    }
    for (final payment in payments) {
      rows.add([
        'Pembayaran', payment.invoiceNumber, payment.paymentDate.toIso8601String(),
        '', '', '', '', payment.amount, '', payment.method, payment.note, '',
      ]);
    }
    final csv = '\uFEFF' + rows.map((row) => row.map(_cell).join(',')).join('\n');
    await Clipboard.setData(ClipboardData(text: csv));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('CSV disalin. Tempelkan ke Excel atau Google Sheets.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final sales = orders.fold<int>(0, (sum, order) => sum + order.total);
    final down = orders.fold<int>(0, (sum, order) => sum + order.initialPayment);
    final later = payments.fold<int>(0, (sum, payment) => sum + payment.amount);
    final balance = orders.fold<int>(0, (sum, order) =>
        sum + (order.total - order.initialPayment - _later(order)).clamp(0, 1 << 31).toInt());

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        _ReportHeader(title: 'Laporan Operasional', subtitle: 'Ringkasan data yang tersimpan di perangkat ini.', icon: Icons.insights_outlined),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2, shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.65,
          children: [
            _ReportMetric(title: 'Pelanggan', value: customers.length.toString(), icon: Icons.people_outline, accent: accent),
            _ReportMetric(title: 'Pesanan', value: orders.length.toString(), icon: Icons.shopping_bag_outlined, accent: accent),
            _ReportMetric(title: 'Nilai pesanan', value: _money(sales), icon: Icons.receipt_long_outlined, accent: accent),
            _ReportMetric(title: 'Uang diterima', value: _money(down + later), icon: Icons.payments_outlined, accent: accent),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(17), border: Border.all(color: accent.withValues(alpha: .18))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Ringkasan tagihan', style: TextStyle(color: accent, fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            _ReportLine(label: 'Nilai pesanan', value: _money(sales)),
            _ReportLine(label: 'Pembayaran awal', value: _money(down)),
            _ReportLine(label: 'Pembayaran lanjutan', value: _money(later)),
            const Divider(height: 18),
            _ReportLine(label: 'Sisa tagihan', value: _money(balance), strong: true),
          ]),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: customers.isEmpty && orders.isEmpty && payments.isEmpty ? null : () => _copyCsv(context),
          icon: const Icon(Icons.content_copy_outlined),
          label: const Text('Salin laporan CSV'),
        ),
        const SizedBox(height: 6),
        const Text('CSV berisi rincian pesanan dan pembayaran. Sumbernya adalah penyimpanan lokal aplikasi, bukan penarikan langsung dari Google Sheets.', style: TextStyle(color: Colors.black54, fontSize: 11, height: 1.4)),
        const SizedBox(height: 18),
        Text('Rincian pesanan', style: TextStyle(color: accent, fontWeight: FontWeight.w800, fontSize: 15)),
        const SizedBox(height: 8),
        if (orders.isEmpty)
          const _ReportEmpty(message: 'Belum ada pesanan tersimpan.')
        else
          ...orders.reversed.map((order) {
            final paid = order.initialPayment + _later(order);
            final due = (order.total - paid).clamp(0, 1 << 31).toInt();
            return Card(
              color: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14), side: BorderSide(color: accent.withValues(alpha: .14))),
              child: ListTile(
                title: Text(order.customer.name, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                subtitle: Text((order.invoiceNumber.isEmpty ? 'Tanpa nomor invoice' : order.invoiceNumber) + ' • ' + _money(order.total)),
                trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                  Text(_money(due), style: TextStyle(color: due == 0 ? Colors.green.shade700 : accent, fontWeight: FontWeight.w800, fontSize: 11)),
                  Text(due == 0 ? 'Lunas' : 'Sisa', style: const TextStyle(color: Colors.black54, fontSize: 10)),
                ]),
              ),
            );
          }),
      ],
    );
  }
}

class OrderStatusScreen extends StatelessWidget {
  final List<OptikOrder> orders;
  final List<OptikPayment> payments;
  const OrderStatusScreen({super.key, required this.orders, required this.payments});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
      children: [
        _ReportHeader(title: 'Status Pesanan', subtitle: 'Pantau pesanan dan posisi tagihannya.', icon: Icons.local_shipping_outlined),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(color: accent.withValues(alpha: .08), borderRadius: BorderRadius.circular(14), border: Border.all(color: accent.withValues(alpha: .18))),
          child: const Text('Catatan: data saat ini belum menyimpan tahapan produksi seperti diproses atau siap diambil. Label berikut hanya menunjukkan status pembayaran.', style: TextStyle(color: ink, fontSize: 11, height: 1.45)),
        ),
        const SizedBox(height: 14),
        if (orders.isEmpty)
          const _ReportEmpty(message: 'Belum ada pesanan untuk dipantau.')
        else
          ...orders.reversed.map((order) {
            final paidLater = payments.where((p) => order.invoiceNumber.isNotEmpty && p.invoiceNumber == order.invoiceNumber).fold<int>(0, (sum, p) => sum + p.amount);
            final due = (order.total - order.initialPayment - paidLater).clamp(0, 1 << 31).toInt();
            final settled = due == 0;
            final statusColor = settled ? Colors.green.shade700 : accent;
            return Card(
              color: Colors.white, elevation: 0, margin: const EdgeInsets.only(bottom: 9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15), side: BorderSide(color: statusColor.withValues(alpha: .20))),
              child: ListTile(
                leading: CircleAvatar(backgroundColor: statusColor.withValues(alpha: .10), child: Icon(Icons.shopping_bag_outlined, color: statusColor)),
                title: Text(order.customer.name, style: const TextStyle(fontWeight: FontWeight.w800, color: ink)),
                subtitle: Text((order.invoiceNumber.isEmpty ? 'Tanpa nomor invoice' : order.invoiceNumber) + '\nTotal ' + _money(order.total) + ' • Sisa ' + _money(due)),
                isThreeLine: true,
                trailing: Text(settled ? 'LUNAS' : 'BELUM LUNAS', style: TextStyle(color: statusColor, fontSize: 9, fontWeight: FontWeight.w900)),
              ),
            );
          }),
      ],
    );
  }

  String _money(int value) {
    final digits = value.toString();
    final out = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) out.write('.');
      out.write(digits[i]);
    }
    return 'Rp ' + out.toString();
  }
}

class _ReportHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _ReportHeader({required this.title, required this.subtitle, required this.icon});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(gradient: LinearGradient(colors: [Colors.white, accent.withValues(alpha: .09)]), borderRadius: BorderRadius.circular(18), border: Border.all(color: accent.withValues(alpha: .20))),
      child: Row(children: [
        Container(width: 46, height: 46, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)), child: Icon(icon, color: accent, size: 24)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(color: accent, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
        ])),
      ]),
    );
  }
}

class _ReportMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color accent;
  const _ReportMetric({required this.title, required this.value, required this.icon, required this.accent});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: accent.withValues(alpha: .16))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: accent, size: 19),
      const Spacer(),
      FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(value, style: const TextStyle(color: ink, fontSize: 16, fontWeight: FontWeight.w900))),
      Text(title, style: const TextStyle(color: Colors.black54, fontSize: 10)),
    ]),
  );
}

class _ReportLine extends StatelessWidget {
  final String label;
  final String value;
  final bool strong;
  const _ReportLine({required this.label, required this.value, this.strong = false});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: TextStyle(color: ink, fontSize: 12, fontWeight: strong ? FontWeight.w800 : FontWeight.normal))),
      Text(value, style: TextStyle(color: ink, fontSize: 12, fontWeight: strong ? FontWeight.w900 : FontWeight.w600)),
    ]),
  );
}

class _ReportEmpty extends StatelessWidget {
  final String message;
  const _ReportEmpty({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15)),
    child: Center(child: Text(message, style: const TextStyle(color: Colors.black54, fontSize: 12))),
  );
}

class _MoreMenuTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _MoreMenuTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: gold.withValues(alpha: .18)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFF3E9D9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, color: darkGold, size: 21),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: ink, fontSize: 13, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: const TextStyle(color: Colors.black54, fontSize: 11)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: gold),
          ],
        ),
      ),
    ),
  );
}

class DashboardContent extends StatelessWidget {
  final ValueChanged<int> onOpenModule;
  final int orderCount;
  final int paymentTotal;
  const DashboardContent({super.key, required this.onOpenModule, required this.orderCount, required this.paymentTotal});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleData('Data Pelanggan', Icons.people_alt_outlined),
      _ModuleData('Pemeriksaan Mata', Icons.visibility_outlined),
      _ModuleData('Pemesanan', Icons.shopping_bag_outlined),
      _ModuleData('Pembayaran', Icons.account_balance_wallet_outlined),
      _ModuleData('Invoice & Kuitansi', Icons.receipt_long_outlined),
      _ModuleData('Status Pesanan', Icons.local_shipping_outlined),
      _ModuleData('Laporan', Icons.insights_outlined),
      _ModuleData('Pengaturan', Icons.tune_outlined),
      _ModuleData('WhatsApp Semi-Otomatis', Icons.chat_bubble_outline),
    ];

    void openModule(String title) {
      if (title == 'Data Pelanggan') {
        onOpenModule(2);
      } else if (title == 'Pemesanan' || title == 'Pemeriksaan Mata') {
        onOpenModule(1);
      } else if (title == 'Pembayaran') {
        onOpenModule(4);
      } else if (title == 'Invoice & Kuitansi') {
        onOpenModule(5);
      } else if (title == 'WhatsApp Semi-Otomatis') {
        onOpenModule(3);
      } else if (title == 'Laporan') {
        onOpenModule(6);
      } else if (title == 'Status Pesanan') {
        onOpenModule(7);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('\$title sedang disiapkan.')),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('PUSAT KENDALI OPERASIONAL',
                      style: TextStyle(color: darkGold, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.5)),
                    const SizedBox(height: 5),
                    const Text('Selamat datang,',
                      style: TextStyle(color: ink, fontSize: 22, fontWeight: FontWeight.w700)),
                    const Text('apa yang ingin dikerjakan hari ini?',
                      style: TextStyle(color: Colors.black54, fontSize: 12)),
                  ],
                ),
              ),
              const _OptikLogo(size: 58),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF80612F), Color(0xFFB99555), Color(0xFFD6B985)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              boxShadow: [BoxShadow(color: darkGold.withValues(alpha: .20), blurRadius: 18, offset: const Offset(0, 8))],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -12, top: -15,
                  child: Icon(Icons.visibility_outlined, size: 132, color: Colors.white.withValues(alpha: .09)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                                        Text('Jernih Melihat,\nNyaman Melangkah.',
                      style: GoogleFonts.dmSerifDisplay(fontSize: 27, height: 1.16, color: Colors.white, letterSpacing: .1)),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF8EE),
                        foregroundColor: darkGold,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: () => onOpenModule(1),
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: const Text('Buat transaksi', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Ringkasan aktivitas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
              Text('DATA SESI INI', style: TextStyle(fontSize: 9, letterSpacing: 1, fontWeight: FontWeight.w700, color: darkGold)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DashboardMetric(
                title: 'Pesanan tersimpan',
                value: orderCount.toString(),
                icon: Icons.shopping_bag_outlined,
                tint: const Color(0xFFF5E9D6),
              )),
              const SizedBox(width: 12),
              Expanded(child: _DashboardMetric(
                title: 'Pembayaran sesi',
                value: 'Rp \$paymentTotal',
                icon: Icons.payments_outlined,
                tint: const Color(0xFFF7E8EA),
                compact: true,
              )),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Akses cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickAction(title: 'Pelanggan', subtitle: 'Data & kontak', icon: Icons.people_alt_outlined, color: const Color(0xFF80612F), onTap: () => onOpenModule(2)),
              const SizedBox(width: 10),
              _QuickAction(title: 'WhatsApp', subtitle: 'Hubungi pelanggan', icon: Icons.chat_bubble_outline, color: const Color(0xFF43866A), onTap: () => onOpenModule(3)),
              const SizedBox(width: 10),
              _QuickAction(title: 'Pembayaran', subtitle: 'Catat pelunasan', icon: Icons.account_balance_wallet_outlined, color: const Color(0xFFAD7180), onTap: () => onOpenModule(4)),
            ],
          ),
          const SizedBox(height: 22),
          const Text('Semua layanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 4),
          const Text('Pilih modul untuk melanjutkan pekerjaan.', style: TextStyle(fontSize: 11, color: Colors.black54)),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 11, mainAxisSpacing: 11, childAspectRatio: 1.72,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              return _ServiceTile(title: module.title, icon: module.icon, onTap: () => openModule(module.title));
            },
          ),
          const SizedBox(height: 18),
          const BackendStatusCard(),
          const SizedBox(height: 12),
          Center(child: Text('OPTIK LENTERA  •  MELAYANI DENGAN HATI',
            style: TextStyle(color: darkGold.withValues(alpha: .75), fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color tint;
  final bool compact;
  const _DashboardMetric({required this.title, required this.value, required this.icon, required this.tint, this.compact = false});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: gold.withValues(alpha: .16)),
      boxShadow: [BoxShadow(color: ink.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4))],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 36, height: 36,
          decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(12)),
          child: Icon(icon, color: darkGold, size: 19)),
        const SizedBox(height: 13),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: Text(value, style: TextStyle(color: ink, fontSize: compact ? 17 : 25, fontWeight: FontWeight.w800))),
        const SizedBox(height: 3),
        Text(title, style: const TextStyle(color: Colors.black54, fontSize: 10)),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction({required this.title, required this.subtitle, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 7),
          child: Column(
            children: [
              Icon(icon, color: color, size: 23),
              const SizedBox(height: 7),
              Text(title, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.black45, fontSize: 8)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ServiceTile extends StatelessWidget {
  final String title;
  final IconData icon;
  final VoidCallback onTap;
  const _ServiceTile({required this.title, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    borderRadius: BorderRadius.circular(17),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(17),
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: gold.withValues(alpha: .18)),
          boxShadow: [BoxShadow(color: ink.withValues(alpha: .025), blurRadius: 9, offset: const Offset(0, 3))],
        ),
        child: Row(
          children: [
            Container(width: 37, height: 37,
              decoration: BoxDecoration(color: const Color(0xFFFAF3E9), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: darkGold, size: 20)),
            const SizedBox(width: 9),
            Expanded(child: Text(title, style: const TextStyle(color: ink, fontSize: 10, fontWeight: FontWeight.w700))),
            const Icon(Icons.chevron_right, color: gold, size: 17),
          ],
        ),
      ),
    ),
  );
}

class BackendStatusCard extends StatefulWidget {
  const BackendStatusCard({super.key});

  @override
  State<BackendStatusCard> createState() => _BackendStatusCardState();
}

class _BackendStatusCardState extends State<BackendStatusCard> {
  late Future<ApiResponse> _check;

  @override
  void initState() {
    super.initState();
    _check = ApiService.get();
  }

  void _retry() {
    setState(() => _check = ApiService.get());
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: FutureBuilder<ApiResponse>(
        future: _check,
        builder: (context, snapshot) {
          final waiting = snapshot.connectionState == ConnectionState.waiting;
          final reachable = snapshot.hasData && snapshot.data!.isSuccessful;
          final failed = snapshot.hasError ||
              (snapshot.hasData && !snapshot.data!.isSuccessful);
          final color = waiting
              ? darkGold
              : reachable
                  ? Colors.green.shade700
                  : Colors.red.shade700;
          final heading = waiting
              ? 'MEMERIKSA BACKEND...'
              : reachable
                  ? 'ENDPOINT BACKEND TERJANGKAU'
                  : 'BACKEND BELUM TERJANGKAU';
          final detail = waiting
              ? 'Menghubungi Google Apps Script...'
              : reachable
                  ? 'Web App merespons. Ini belum membuktikan API transaksi aktif; format endpoint transaksi tetap perlu diverifikasi.'
                  : 'Koneksi gagal atau Web App tidak merespons. Periksa deployment dan jaringan, lalu coba lagi.';
          return Row(
            children: [
              Icon(
                waiting
                    ? Icons.sync
                    : reachable
                        ? Icons.cloud_done_outlined
                        : Icons.cloud_off_outlined,
                color: color,
                size: 25,
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      heading,
                      style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      detail,
                      style: const TextStyle(color: ink, fontSize: 11),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Periksa ulang',
                onPressed: waiting ? null : _retry,
                icon: Icon(Icons.refresh, color: failed ? color : darkGold),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: gold.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: darkGold, size: 23),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.bold,
              color: ink,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        ],
      ),
    );
  }
}

class _ModuleData {
  final String title;
  final IconData icon;

  const _ModuleData(this.title, this.icon);
}

class OtherContent extends StatelessWidget {
  final String title;

  const OtherContent({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 22,
          color: darkGold,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}


class _OptikLogo extends StatelessWidget {
  final double size;
  const _OptikLogo({required this.size});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(size * 0.18),
    child: Container(
      width: size,
      height: size,
      color: Colors.white,
      padding: EdgeInsets.all(size * 0.035),
      child: Image.memory(
        base64Decode(optikLogoBase64),
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => Icon(Icons.visibility_outlined, color: darkGold, size: size * 0.65),
      ),
    ),
  );
}
