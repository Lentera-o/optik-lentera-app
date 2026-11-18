import 'dart:convert';

import 'package:flutter/material.dart';
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
const Color gold = Color(0xFFB99555);
const Color darkGold = Color(0xFF80612F);
const Color pink = Color(0xFFE9C9CC);
const Color ink = Color(0xFF39342F);

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
          backgroundColor: const Color(0xFFFFFCF8),
          indicatorColor: pink.withValues(alpha: .52),
          height: 70,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
            fontSize: 9.5,
            letterSpacing: .1,
            fontWeight: states.contains(WidgetState.selected) ? FontWeight.w800 : FontWeight.w500,
            color: states.contains(WidgetState.selected) ? darkGold : const Color(0xFF8A8177),
          )),
          iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
            size: 21,
            color: states.contains(WidgetState.selected) ? darkGold : const Color(0xFF9A9186),
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        titleSpacing: 20,
        title: Row(
          children: [
            const _OptikLogo(size: 42),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('OPTIK LENTERA', style: TextStyle(color: darkGold, fontSize: 17, fontWeight: FontWeight.bold, letterSpacing: 1.1)),
                Text('Sistem Manajemen Optik', style: TextStyle(color: Colors.black54, fontSize: 10)),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: () {},
            icon: const Icon(Icons.notifications_none),
            color: darkGold,
          ),
          const Padding(
            padding: EdgeInsets.only(right: 16),
            child: CircleAvatar(
              radius: 18,
              backgroundColor: pink,
              child: Icon(Icons.person_outline, color: darkGold),
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
          _ => OtherContent(title: navigation[selectedIndex]),
        },
      ),
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFFCF8),
          border: Border(top: BorderSide(color: gold.withValues(alpha: .16))),
          boxShadow: [
            BoxShadow(color: ink.withValues(alpha: .045), blurRadius: 16, offset: const Offset(0, -5)),
          ],
        ),
        child: NavigationBar(
          backgroundColor: Colors.transparent,
          indicatorColor: pink.withValues(alpha: .45),
          selectedIndex: selectedIndex >= 4 ? 4 : selectedIndex,
          onDestinationSelected: (index) {
            if (index == 4) {
              _showMoreMenu();
            } else {
              setState(() => selectedIndex = index);
            }
          },
          destinations: [
            const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded, color: darkGold),
              label: 'Beranda',
            ),
            const NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded, color: darkGold),
              label: 'Transaksi',
            ),
            const NavigationDestination(
              icon: Icon(Icons.people_outline_rounded),
              selectedIcon: Icon(Icons.people_rounded, color: darkGold),
              label: 'Pelanggan',
            ),
            const NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon: Icon(Icons.chat_bubble_rounded, color: darkGold),
              label: 'WhatsApp',
            ),
            NavigationDestination(
              icon: Icon(selectedIndex >= 4 ? Icons.grid_view_rounded : Icons.grid_view_outlined),
              selectedIcon: const Icon(Icons.grid_view_rounded, color: darkGold),
              label: 'Lainnya',
            ),
          ],
        ),
      ),
    );
  }
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
                color: const Color(0xFFF7E8EA),
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
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title sedang disiapkan.')),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3E8D6),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Text(
                        'PUSAT KENDALI OPERASIONAL',
                        style: TextStyle(color: darkGold, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 1.05),
                      ),
                    ),
                    const SizedBox(height: 11),
                    const Text('Selamat datang,', style: TextStyle(color: ink, fontSize: 23, fontWeight: FontWeight.w800, height: 1.1)),
                    const SizedBox(height: 4),
                    const Text('Apa yang ingin dikerjakan hari ini?', style: TextStyle(color: Color(0xFF81766B), fontSize: 11.5)),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const _OptikLogo(size: 62),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(20, 20, 18, 18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF594323), Color(0xFF80612F), Color(0xFFC19B5C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
              boxShadow: [
                BoxShadow(color: darkGold.withValues(alpha: .20), blurRadius: 22, offset: const Offset(0, 10)),
              ],
            ),
            child: Stack(
              children: [
                Positioned(
                  right: -18,
                  top: -22,
                  child: Icon(Icons.remove_red_eye_outlined, size: 142, color: Colors.white.withValues(alpha: .075)),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: .14),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(color: Colors.white.withValues(alpha: .20)),
                      ),
                      child: const Text('OPTIK LENTERA', style: TextStyle(color: Colors.white, fontSize: 9, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      'Jernih Melihat,\nNyaman Melangkah.',
                      style: GoogleFonts.dmSerifDisplay(fontSize: 28, height: 1.12, color: Colors.white, letterSpacing: .1),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kelola pelayanan dan transaksi optik dalam satu tempat.',
                      style: TextStyle(color: Colors.white.withValues(alpha: .82), fontSize: 11, height: 1.45),
                    ),
                    const SizedBox(height: 17),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF8EE),
                        foregroundColor: const Color(0xFF72552B),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: () => onOpenModule(1),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Buat transaksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan aktivitas', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
                  SizedBox(height: 3),
                  Text('Catatan yang tersimpan di perangkat ini', style: TextStyle(fontSize: 10, color: Color(0xFF8A8177))),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                decoration: BoxDecoration(color: const Color(0xFFF5EBDD), borderRadius: BorderRadius.circular(20)),
                child: const Text('SESI INI', style: TextStyle(fontSize: 8, letterSpacing: .9, fontWeight: FontWeight.w800, color: darkGold)),
              ),
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
              const SizedBox(width: 11),
              Expanded(child: _DashboardMetric(
                title: 'Pembayaran sesi',
                value: 'Rp $paymentTotal',
                icon: Icons.payments_outlined,
                tint: const Color(0xFFF7E8EA),
                compact: true,
              )),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Akses cepat', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 3),
          const Text('Buka pekerjaan yang paling sering digunakan.', style: TextStyle(fontSize: 10, color: Color(0xFF8A8177))),
          const SizedBox(height: 12),
          Row(
            children: [
              _QuickAction(title: 'Pelanggan', subtitle: 'Data & kontak', icon: Icons.people_alt_outlined, color: const Color(0xFF80612F), onTap: () => onOpenModule(2)),
              const SizedBox(width: 9),
              _QuickAction(title: 'WhatsApp', subtitle: 'Hubungi pelanggan', icon: Icons.chat_bubble_outline, color: const Color(0xFF43866A), onTap: () => onOpenModule(3)),
              const SizedBox(width: 9),
              _QuickAction(title: 'Pembayaran', subtitle: 'Catat pelunasan', icon: Icons.account_balance_wallet_outlined, color: const Color(0xFFAD7180), onTap: () => onOpenModule(4)),
            ],
          ),
          const SizedBox(height: 24),
          const Text('Semua layanan', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: ink)),
          const SizedBox(height: 3),
          const Text('Pilih modul untuk melanjutkan pekerjaan.', style: TextStyle(fontSize: 10, color: Color(0xFF8A8177))),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.58,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              return _ServiceTile(title: module.title, icon: module.icon, onTap: () => openModule(module.title));
            },
          ),
          const SizedBox(height: 18),
          const BackendStatusCard(),
          const SizedBox(height: 14),
          Center(
            child: Text(
              'OPTIK LENTERA  •  MELAYANI DENGAN HATI',
              style: TextStyle(color: darkGold.withValues(alpha: .72), fontSize: 8.5, letterSpacing: 1, fontWeight: FontWeight.w700),
            ),
          ),
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
