// Smoke test do app educacional. Garante que a HomeScreen abre com seus
// tres cards (NFC, biometria, deteccao facial) sem disparar nenhuma chamada
// de hardware.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_nfc_biometria_educacional/main.dart';

void main() {
  testWidgets('HomeScreen exibe os tres cards de funcionalidades',
      (WidgetTester tester) async {
    await tester.pumpWidget(const EducationalSecurityApp());
    await tester.pump();

    expect(find.text('1. Leitura NFC'), findsOneWidget);
    expect(find.text('2. Biometria local'), findsOneWidget);
    expect(find.text('3. Deteccao facial didatica'), findsOneWidget);

    expect(find.byType(FilledButton), findsNWidgets(3));
  });
}
