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
          3 => WhatsAppCenterScreen(customers: customers, orders: orders),
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
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat, color: darkGold),
            label: 'WhatsApp',
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(7),
                          decoration: BoxDecoration(color: Colors.white.withValues(alpha: .18), borderRadius: BorderRadius.circular(12)),
                          child: const Icon(Icons.auto_awesome, color: Colors.white, size: 17),
                        ),
                        const SizedBox(width: 9),
                        const Text('OPTIK LENTERA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 2)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    const Text('Jernih Melihat,\nNyaman Melangkah.',
                      style: TextStyle(color: Colors.white, fontSize: 25, height: 1.18, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('Kelola pelayanan dan operasional optik dalam satu tempat.',
                      style: TextStyle(color: Colors.white.withValues(alpha: .88), fontSize: 12, height: 1.45)),
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
