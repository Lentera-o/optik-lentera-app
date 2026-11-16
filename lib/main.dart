import 'package:flutter/material.dart';

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

  final List<String> navigation = [
    'Beranda',
    'Transaksi',
    'Pelanggan',
    'Lainnya',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: cream,
        elevation: 0,
        titleSpacing: 20,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'OPTIK LENTERA',
              style: TextStyle(
                color: darkGold,
                fontSize: 19,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),
            Text(
              'Sistem Manajemen Optik',
              style: TextStyle(color: Colors.black54, fontSize: 11),
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
        child: selectedIndex == 0
            ? const DashboardContent()
            : OtherContent(title: navigation[selectedIndex]),
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
        ],
      ),
    );
  }
}

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

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
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Selamat Datang', style: TextStyle(color: ink, fontSize: 14)),
                SizedBox(height: 5),
                Text(
                  'OPTIK LENTERA',
                  style: TextStyle(
                    color: darkGold,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Kemewahan dalam Pelayanan, Kesederhanaan dalam Biaya.',
                  style: TextStyle(color: ink, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Ringkasan Hari Ini',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: ink),
          ),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(
                child: _SummaryCard(
                  title: 'Pesanan',
                  value: '—',
                  icon: Icons.shopping_bag_outlined,
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: _SummaryCard(
                  title: 'Pembayaran',
                  value: '—',
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
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${module.title} akan diaktifkan pada tahap berikutnya.',
                      ),
                    ),
                  );
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
