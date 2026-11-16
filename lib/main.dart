import 'dart:convert';

import 'package:flutter/material.dart';
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
        fontFamily: 'Roboto',
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
  }

  void _addPayment(OptikPayment value) {
    setState(() => payments.add(value));
    _saveLocalData();
  }

  final List<String> navigation = [
    'Beranda',
    'Transaksi',
    'Pelanggan',
    'Lainnya',
    'Pembayaran',
    'Dokumen',
  ];

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
          1 => TransactionScreen(orders: orders, onAdd: _addOrder),
          2 => CustomerScreen(customers: customers, onAdd: _addCustomer),
          3 => OtherContent(title: navigation[selectedIndex]),
          4 => PaymentEntryScreen(payments: payments, orders: orders, onAdd: _addPayment),
          5 => InvoiceReceiptScreen(orders: orders, payments: payments),
          _ => OtherContent(title: navigation[selectedIndex]),
        },
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: Colors.white,
        indicatorColor: pink.withValues(alpha: 0.45),
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          setState(() => selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard, color: darkGold),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long, color: darkGold),
            label: 'Transaksi',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people, color: darkGold),
            label: 'Pelanggan',
          ),
          NavigationDestination(
            icon: Icon(Icons.grid_view_outlined),
            selectedIcon: Icon(Icons.grid_view, color: darkGold),
            label: 'Lainnya',
          ),
          NavigationDestination(
            icon: Icon(Icons.payments_outlined),
            selectedIcon: Icon(Icons.payments, color: darkGold),
            label: 'Bayar',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description, color: darkGold),
            label: 'Dokumen',
          ),
        ],
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  final ValueChanged<int> onOpenModule;
  final int orderCount;
  final int paymentTotal;
  const DashboardContent({super.key, required this.onOpenModule, required this.orderCount, required this.paymentTotal});

  @override
  Widget build(BuildContext context) {
    final modules = [
      _ModuleData('Data Pelanggan', Icons.people_outline),
      _ModuleData('Pemeriksaan Mata', Icons.remove_red_eye_outlined),
      _ModuleData('Pemesanan', Icons.shopping_bag_outlined),
      _ModuleData('Pembayaran', Icons.payments_outlined),
      _ModuleData('Invoice & Kuitansi', Icons.receipt_long_outlined),
      _ModuleData('Status Pesanan', Icons.local_shipping_outlined),
      _ModuleData('Laporan', Icons.bar_chart_outlined),
      _ModuleData('Pengaturan', Icons.settings_outlined),
    ];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFF0E4CF), Color(0xFFF6E9E8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: gold.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const _OptikLogo(size: 88),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('SELAMAT DATANG', style: TextStyle(color: ink, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.3)),
                      SizedBox(height: 6),
                      Text('OPTIK LENTERA', style: TextStyle(color: darkGold, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                      SizedBox(height: 7),
                      Text('Kemewahan dalam Pelayanan, Kesederhanaan dalam Biaya.', style: TextStyle(color: ink, fontSize: 11, height: 1.35)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const BackendStatusCard(),
          const SizedBox(height: 24),
          const Text(
            'Ringkasan Hari Ini',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ink),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Draft Pesanan',
                  value: orderCount.toString(),
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Pembayaran Sesi',
                  value: 'Rp ' + paymentTotal.toString(),
                  icon: Icons.payments_outlined,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          const Text(
            'Menu Operasional',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ink),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: modules.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.55,
            ),
            itemBuilder: (context, index) {
              final module = modules[index];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (module.title == 'Data Pelanggan') {
                    onOpenModule(2);
                  } else if (module.title == 'Pemesanan' || module.title == 'Pemeriksaan Mata') {
                    onOpenModule(1);
                  } else if (module.title == 'Pembayaran') {
                    onOpenModule(4);
                  } else if (module.title == 'Invoice & Kuitansi') {
                    onOpenModule(5);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${module.title} sedang disiapkan.')),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: gold.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(module.icon, color: darkGold, size: 27),
                      const SizedBox(height: 9),
                      Text(
                        module.title,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
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
