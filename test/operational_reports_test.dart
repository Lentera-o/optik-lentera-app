import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:optik_lentera/main.dart';
import 'package:optik_lentera/models/optik_models.dart';

void main() {
  final customer = Customer(
    name: 'Pelanggan Uji',
    phone: '081234567890',
    address: 'Tangerang',
  );
  final order = OptikOrder(
    invoiceNumber: 'INV-TEST-001',
    customer: customer,
    frame: const OrderItem(price: 60000),
    lens: const OrderItem(price: 40000),
    initialPayment: 40000,
    initialPaymentMethod: 'Tunai',
  );
  final payment = OptikPayment(
    invoiceNumber: 'INV-TEST-001',
    paymentDate: DateTime(2026, 11, 18),
    amount: 20000,
    method: 'Transfer',
  );

  testWidgets('laporan menghitung pembayaran dan sisa tagihan', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: ReportsScreen(
        customers: [customer],
        orders: [order],
        payments: [payment],
      ),
    ));

    expect(find.text('Laporan Operasional'), findsOneWidget);
    expect(find.text('Pelanggan Uji'), findsOneWidget);
    expect(find.text('Rp 100.000'), findsWidgets);
    expect(find.text('Rp 40.000'), findsWidgets);
    expect(find.text('Rp 20.000'), findsOneWidget);
    expect(find.text('Salin laporan CSV'), findsOneWidget);
  });

  testWidgets('status pesanan menampilkan sisa pembayaran', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: OrderStatusScreen(
        orders: [order],
        payments: [payment],
      ),
    ));

    expect(find.text('Status Pesanan'), findsOneWidget);
    expect(find.text('Pelanggan Uji'), findsOneWidget);
    expect(find.textContaining('Sisa Rp 40.000'), findsOneWidget);
    expect(find.text('BELUM LUNAS'), findsOneWidget);
    expect(find.textContaining('belum menyimpan tahapan produksi'), findsOneWidget);
  });

  testWidgets('laporan dan status menampilkan keadaan kosong', (tester) async {
    tester.view.physicalSize = const Size(1200, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
      home: ReportsScreen(customers: [], orders: [], payments: []),
    ));
    expect(find.text('Belum ada pesanan tersimpan.'), findsOneWidget);

    await tester.pumpWidget(const MaterialApp(
      home: OrderStatusScreen(orders: [], payments: []),
    ));
    expect(find.text('Belum ada pesanan untuk dipantau.'), findsOneWidget);
  });
}
