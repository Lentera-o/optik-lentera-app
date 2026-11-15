import 'package:flutter_test/flutter_test.dart';

import 'package:optik_lentera/main.dart';

void main() {
  testWidgets('OPTIK LENTERA dashboard tampil', (WidgetTester tester) async {
    await tester.pumpWidget(const OptikLenteraApp());

    expect(find.text('OPTIK LENTERA'), findsWidgets);
    expect(find.text('Menu Operasional'), findsOneWidget);
    expect(find.text('Data Pelanggan'), findsOneWidget);
  });
}
