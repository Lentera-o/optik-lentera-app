import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'services/api_service.dart';
import 'services/sheets_read_service.dart';
import 'models/optik_models.dart';
import 'screens/operational_screens.dart';
import 'screens/reports_screen.dart';
import 'assets/optik_brand_assets.dart';


void main() {
  runApp(const OptikLenteraApp());
}

const Color cream = Color(0xFFFBF8F2);
const Color gold = Color(0xFFC5A66F);
const Color darkGold = Color(0xFF8A6B3F);
const Color pink = Color(0xFFEAD9D8);
const Color ink = Color(0xFF292722);

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
  int _unreadDocumentCount = 0;

  @override
  void initState() {
    super.initState();
    _loadLocalData();
    _refreshDocumentNotificationCount();
  }

  String _noticeKey(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');

  String _noticeCell(Map<String, String> row, List<String> aliases) {
    for (final alias in aliases) {
      final wanted = _noticeKey(alias);
      for (final entry in row.entries) {
        if (_noticeKey(entry.key) == wanted && entry.value.trim().isNotEmpty) {
          return entry.value.trim();
        }
      }
    }
    return '';
  }

  bool _hasOfficialPdf(Map<String, String> row, List<String> aliases) {
    final candidates = <String>[
      _noticeCell(row, aliases),
      ...row.entries
          .where((entry) => RegExp(r'pdf|invoice|kuitansi|kwitansi', caseSensitive: false).hasMatch(entry.key))
          .map((entry) => entry.value),
    ];
    final pattern = RegExp(r'https?://[^\s<>"\x27]+', caseSensitive: false);
    for (final candidate in candidates) {
      for (final match in pattern.allMatches(candidate.trim())) {
        final uri = Uri.tryParse(match.group(0)!.replaceFirst(RegExp(r'[.,;)]+$'), ''));
        if (uri != null && uri.scheme == 'https' &&
            (uri.host == 'drive.google.com' || uri.host.endsWith('.google.com')) &&
            (uri.path.contains('/file/') || uri.path.contains('/document/') ||
             uri.queryParameters.containsKey('id'))) {
          return true;
        }
      }
    }
    return false;
  }

  Future<void> _refreshDocumentNotificationCount() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final decoded = jsonDecode(prefs.getString('ol_document_notice_read_ids') ?? '[]');
      final readIds = decoded is List ? decoded.map((item) => item.toString()).toSet() : <String>{};
      final tables = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      final ids = <String>{};
      for (final row in tables[0]) {
        final invoice = _noticeCell(row, ['No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice', 'Nomor Tagihan']);
        if (invoice.isNotEmpty && _hasOfficialPdf(row, [
          'Link Invoice PDF', 'PDF Invoice', 'Link PDF Invoice', 'Invoice PDF', 'URL Invoice PDF',
        ])) {
          ids.add('invoice:' + invoice);
        }
      }
      for (final row in tables[1]) {
        final receipt = _noticeCell(row, ['No Kuitansi', 'Nomor Kuitansi', 'Nomor kuitansi']);
        final invoice = _noticeCell(row, ['No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice']);
        final date = _noticeCell(row, ['Tanggal', 'Tanggal Bayar', 'Tanggal Pembayaran']);
        final amount = _noticeCell(row, ['Jumlah Bayar', 'Jumlah Pembayaran']);
        if (_hasOfficialPdf(row, [
          'PDF Kuitansi', 'Link PDF Kuitansi', 'Link Kuitansi', 'Link Kuitansi PDF',
          'Kuitansi PDF', 'URL Kuitansi PDF',
        ])) {
          final id = receipt.isNotEmpty ? receipt : invoice + '_' + date + '_' + amount;
          if (id.replaceAll('_', '').isNotEmpty) ids.add('receipt:' + id);
        }
      }
      if (!mounted) return;
      setState(() => _unreadDocumentCount = ids.where((id) => !readIds.contains(id)).length);
    } catch (_) {
      // Badge tidak mengganggu dashboard bila Sheets sedang tidak tersedia.
    }
  }

  void _openDocumentNotifications() {
    setState(() => selectedIndex = 7);
    _refreshDocumentNotificationCount();
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
    _refreshDocumentNotificationCount();
  }

  void _addPayment(OptikPayment value) {
    setState(() => payments.add(value));
    _saveLocalData();
    _refreshDocumentNotificationCount();
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
                icon: Icons.insights_outlined,
                title: 'Laporan Harian & Bulanan',
                subtitle: 'Rekap order, omzet, pembayaran, dan tagihan',
                onTap: () => Navigator.pop(sheetContext, 6),
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
            onPressed: _openDocumentNotifications,
            tooltip: _unreadDocumentCount > 0
                ? 'Notifikasi dokumen: $_unreadDocumentCount belum dibaca'
                : 'Notifikasi dokumen',
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.notifications_none, size: 25),
                if (_unreadDocumentCount > 0)
                  Positioned(
                    right: -5,
                    top: -5,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE53935),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: cream, width: 1.5),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        _unreadDocumentCount > 9 ? '9+' : '$_unreadDocumentCount',
                        style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
              ],
            ),
            color: darkGold,
          ),
        ],
      ),
      body: SafeArea(
        child: _loadingLocalData
            ? const Center(child: CircularProgressIndicator(color: darkGold))
            : switch (selectedIndex) {
          0 => DashboardContent(
            onOpenModule: (index) => setState(() => selectedIndex = index),
          ),
          1 => TransactionScreen(customers: customers, orders: orders, onAdd: _addOrder),
          2 => CustomerScreen(customers: customers, onAdd: _addCustomer),
          3 => WhatsAppCenterScreen(customers: customers, orders: orders, payments: payments),
          4 => PaymentEntryScreen(payments: payments, orders: orders, onAdd: _addPayment),
          5 => const InvoiceReceiptScreen(),
          6 => const ReportsScreen(),
          7 => DocumentNotificationsScreen(onRead: _refreshDocumentNotificationCount),
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

class DashboardContent extends StatefulWidget {
  final ValueChanged<int> onOpenModule;
  const DashboardContent({super.key, required this.onOpenModule});

  @override
  State<DashboardContent> createState() => _DashboardContentState();
}

class _DashboardContentState extends State<DashboardContent> {
  List<Map<String, String>> _officialOrders = [];
  List<Map<String, String>> _officialPayments = [];
  bool _summaryLoading = true;
  String? _summaryError;
  DateTime? _lastSyncedAt;

  String _cell(Map<String, String> row, List<String> aliases) {
    String key(String value) => value.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    for (final alias in aliases) {
      final target = key(alias);
      for (final entry in row.entries) {
        if (key(entry.key) == target && entry.value.trim().isNotEmpty) return entry.value.trim();
      }
    }
    for (final alias in aliases) {
      final tokens = RegExp(r'[a-z0-9]+').allMatches(alias.toLowerCase())
          .map((match) => match.group(0)!).where((token) => token.length > 1).toList();
      if (tokens.length < 2) continue;
      for (final entry in row.entries) {
        final header = key(entry.key);
        if (entry.value.trim().isNotEmpty && tokens.every(header.contains)) return entry.value.trim();
      }
    }
    return '';
  }

  int _money(String value) =>
      int.tryParse(value.replaceAll(RegExp(r'[^0-9-]'), '')) ?? 0;

  @override
  void initState() {
    super.initState();
    _loadOfficialSummary();
  }

  Future<void> _loadOfficialSummary() async {
    if (mounted) setState(() { _summaryLoading = true; _summaryError = null; });
    try {
      final tables = await Future.wait([
        SheetsReadService.readTable('DATA_PESANAN', forceRefresh: true),
        SheetsReadService.readTable('DATA_PEMBAYARAN', forceRefresh: true),
      ]);
      final officialOrders = tables[0].where((row) => _cell(row, [
        'No Invoice', 'Nomor Invoice', 'No. Invoice', 'Invoice',
        'Nomor Tagihan', 'No Tagihan', 'No Faktur', 'Nomor Faktur',
        'Kode Invoice', 'Invoice ID', 'ID Invoice', 'No Nota', 'Nomor Nota',
        'No Transaksi', 'Nomor Transaksi',
      ]).isNotEmpty).toList();
      final officialPayments = tables[1].where((row) =>
        row.values.any((value) => value.trim().isNotEmpty)).toList();
      if (!mounted) return;
      setState(() {
        _officialOrders = officialOrders;
        _officialPayments = officialPayments;
        _summaryLoading = false;
        _lastSyncedAt = DateTime.now();
      });
    } catch (error) {
      if (!mounted) return;
      setState(() { _summaryLoading = false; _summaryError = error.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderCount = _officialOrders.length;
    final paymentTotal = _officialPayments.fold<int>(0, (sum, row) =>
      sum + _money(_cell(row, ['Jumlah Bayar', 'Jumlah Pembayaran', 'Nominal Pembayaran', 'Nominal', 'Total Bayar'])));
    final countText = _summaryLoading ? '…' : orderCount.toString();
    final paymentText = _summaryLoading ? '…' : 'Rp ' + paymentTotal.toString();
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
        widget.onOpenModule(2);
      } else if (title == 'Pemesanan' || title == 'Pemeriksaan Mata') {
        widget.onOpenModule(1);
      } else if (title == 'Pembayaran') {
        widget.onOpenModule(4);
      } else if (title == 'Invoice & Kuitansi') {
        widget.onOpenModule(5);
      } else if (title == 'WhatsApp Semi-Otomatis') {
        widget.onOpenModule(3);
      } else if (title == 'Laporan') {
        widget.onOpenModule(6);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$title sedang disiapkan.')),
        );
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 26),
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
                    const Text('Selamat datang,', style: TextStyle(color: ink, fontSize: 25, fontWeight: FontWeight.w800, height: 1.1, letterSpacing: -.45)),
                    const SizedBox(height: 4),
                    const Text('Apa yang ingin dikerjakan hari ini?', style: TextStyle(color: Color(0xFF81766B), fontSize: 11.5)),
                  ],
                ),
              ),
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
                  right: -20,
                  top: -18,
                  child: Icon(Icons.remove_red_eye_outlined, size: 126, color: Colors.white.withValues(alpha: .045)),
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
                      child: const Text('LAYANAN OPTIK TERPADU', style: TextStyle(color: Colors.white, fontSize: 9, letterSpacing: 1.35, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(height: 13),
                    Text(
                      'Jelas Lihatnya,\nJelas Rezekinya.',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 23,
                        height: 1.24,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -.65,
                      ),
                    ),
                    const SizedBox(height: 9),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 285),
                      child: Text(
                        'Kelola pelayanan dan transaksi optik dalam satu tempat.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: .84),
                          fontSize: 11,
                          height: 1.55,
                          letterSpacing: .05,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFFFF8EE),
                        foregroundColor: darkGold,
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
                      ),
                      onPressed: () => widget.onOpenModule(1),
                      icon: const Icon(Icons.add_rounded, size: 18),
                      label: const Text('Buat transaksi', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11)),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          const _LenteraTodayCard(),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Ringkasan aktivitas', style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w800, color: ink)),
                  SizedBox(height: 3),
                  Text('Rekap resmi dari Google Sheets', style: TextStyle(fontSize: 10, color: Color(0xFF8A8177))),
                ],
              ),
              Row(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(color: const Color(0xFFF5EBDD), borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    _summaryLoading ? 'MENYINKRONKAN' : (_summaryError == null ? 'DATA RESMI' : 'GAGAL SINKRON'),
                    style: TextStyle(fontSize: 8, letterSpacing: .5, fontWeight: FontWeight.w800,
                      color: _summaryError == null ? darkGold : Colors.red.shade700),
                  ),
                ),
                IconButton(
                  tooltip: 'Perbarui total transaksi resmi',
                  visualDensity: VisualDensity.compact,
                  onPressed: _summaryLoading ? null : _loadOfficialSummary,
                  icon: const Icon(Icons.sync, size: 17, color: darkGold),
                ),
              ]),
            ],
          ),
          if (_summaryError != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Data total transaksi belum tersinkron: ' + _summaryError!,
                style: const TextStyle(fontSize: 10, color: Colors.deepOrange)),
            ),
          if (_lastSyncedAt != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('Terakhir diperbarui: ' +
                _lastSyncedAt!.day.toString().padLeft(2, '0') + '/' +
                _lastSyncedAt!.month.toString().padLeft(2, '0') + ' ' +
                _lastSyncedAt!.hour.toString().padLeft(2, '0') + ':' +
                _lastSyncedAt!.minute.toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 9, color: Colors.black45)),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _DashboardMetric(
                title: 'Total transaksi resmi',
                value: countText,
                icon: Icons.shopping_bag_outlined,
                tint: const Color(0xFFF5E9D6),
              )),
              const SizedBox(width: 11),
              Expanded(child: _DashboardMetric(
                title: 'Total pembayaran resmi',
                value: paymentText,
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
              _QuickAction(title: 'Pelanggan', subtitle: 'Data & kontak', icon: Icons.people_alt_outlined, color: darkGold, onTap: () => widget.onOpenModule(2)),
              const SizedBox(width: 9),
              _QuickAction(title: 'WhatsApp', subtitle: 'Hubungi pelanggan', icon: Icons.chat_bubble_outline, color: const Color(0xFF43866A), onTap: () => widget.onOpenModule(3)),
              const SizedBox(width: 9),
              _QuickAction(title: 'Pembayaran', subtitle: 'Catat pelunasan', icon: Icons.account_balance_wallet_outlined, color: const Color(0xFFAD7180), onTap: () => widget.onOpenModule(4)),
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

class _LenteraTodayCard extends StatelessWidget {
  const _LenteraTodayCard();

  static const List<String> _motivations = [
    'Jelas Lihatnya, Jelas Rezekinya. Layani dengan hati, bertumbuh bersama.',
    'Kerja yang teliti hari ini membangun kepercayaan untuk esok hari.',
    'Setiap pelanggan adalah kesempatan untuk memberi manfaat.',
    'Disiplin dalam proses, jujur dalam pelayanan, ikhlas dalam usaha.',
    'Tim yang saling mendukung akan tumbuh lebih kuat.',
    'Jangan berhenti belajar; kemampuan baik lahir dari kebiasaan baik.',
    'Keberhasilan dimulai dari niat baik dan tindakan yang konsisten.',
  ];

  static const List<String> _serviceTips = [
    'Sambut pelanggan dengan ramah, lalu dengarkan kebutuhannya sebelum menawarkan produk.',
    'Jelaskan pilihan produk dengan bahasa sederhana, jujur, dan tanpa memaksa.',
    'Ulangi kebutuhan pelanggan untuk memastikan tidak ada informasi yang terlewat.',
    'Jika belum yakin dengan jawaban, sampaikan dengan jujur dan minta bantuan rekan yang kompeten.',
    'Periksa kembali detail pesanan bersama pelanggan sebelum transaksi disimpan.',
    'Tanggapi keluhan dengan tenang: dengarkan, pahami, lalu jelaskan langkah penyelesaiannya.',
    'Akhiri pelayanan dengan memastikan pelanggan memahami cara penggunaan dan perawatan produk.',
  ];

  static const List<String> _opticalInsights = [
    'Ukuran lensa harus mengikuti resep pemeriksaan yang valid; jangan menebak ukuran mata pelanggan.',
    'Lensa single vision memiliki satu area koreksi utama, sedangkan lensa progresif dirancang untuk beberapa jarak pandang.',
    'Ukuran frame yang sesuai membantu kenyamanan dan posisi lensa di depan mata.',
    'Jarak pupil (PD) merupakan salah satu data penting dalam penempatan pusat optik lensa.',
    'Lapisan lensa memiliki fungsi berbeda; jelaskan manfaat dan batasannya secara akurat.',
    'Bersihkan lensa dengan cairan yang sesuai dan kain microfiber agar permukaan tidak mudah tergores.',
    'Keluhan penglihatan atau perubahan resep perlu diarahkan ke pemeriksaan oleh tenaga profesional yang berwenang.',
  ];

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dayIndex = today.difference(DateTime(today.year, 1, 1)).inDays % _motivations.length;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFCF8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: gold.withValues(alpha: .24)),
        boxShadow: [
          BoxShadow(color: ink.withValues(alpha: .035), blurRadius: 12, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5EBDD),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.wb_sunny_outlined, color: darkGold, size: 20),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('LENTERA HARI INI', style: TextStyle(color: darkGold, fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: .8)),
                    SizedBox(height: 2),
                    Text('Motivasi, pelayanan, dan wawasan optik', style: TextStyle(color: Color(0xFF8A8177), fontSize: 10)),
                  ],
                ),
              ),
              const Icon(Icons.auto_awesome_outlined, color: gold, size: 19),
            ],
          ),
          const SizedBox(height: 14),
          _LearningItem(label: 'MOTIVASI', icon: Icons.favorite_border_rounded, text: _motivations[dayIndex], prominent: true),
          const SizedBox(height: 10),
          _LearningItem(label: 'TIPS PELAYANAN', icon: Icons.handshake_outlined, text: _serviceTips[dayIndex]),
          const SizedBox(height: 10),
          _LearningItem(label: 'WAWASAN OPTIK', icon: Icons.visibility_outlined, text: _opticalInsights[dayIndex]),
        ],
      ),
    );
  }
}

class _LearningItem extends StatelessWidget {
  final String label;
  final IconData icon;
  final String text;
  final bool prominent;

  const _LearningItem({
    required this.label,
    required this.icon,
    required this.text,
    this.prominent = false,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(11),
    decoration: BoxDecoration(
      color: const Color(0xFFFAF7F0),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: darkGold, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(color: darkGold, fontSize: prominent ? 10 : 9, fontWeight: FontWeight.w800, letterSpacing: .8)),
              const SizedBox(height: 5),
              Text(text, style: TextStyle(color: ink, fontSize: prominent ? 13 : 11, height: 1.45, fontWeight: prominent ? FontWeight.w600 : FontWeight.normal)),
            ],
          ),
        ),
      ],
    ),
  );
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
