import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:optik_lentera/main.dart';

void main() {
  testWidgets('OPTIK LENTERA dashboard tampil', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const MaterialApp(home: MainScreen()));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));

    expect(find.text('OPTIK LENTERA'), findsWidgets);
    expect(find.text('Semua layanan'), findsOneWidget);
    expect(find.text('Akses cepat'), findsOneWidget);
  });
}
