import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/ui/world_tag.dart';

void main() {
  testWidgets('NPC hover künyesi tek ve çift tık ipucunu gösterir', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Stack(
          children: [
            WorldTag(
              anchor: Offset(200, 180),
              title: 'Veli',
              line2: 'çiftçi',
              line3: 'tarlada · keyfi iyi',
              hint: 'Tek tık: sor · çift tık: kimlik',
              opacity: 1,
            ),
          ],
        ),
      ),
    );

    expect(find.text('Tek tık: sor · çift tık: kimlik'), findsOneWidget);
  });

  testWidgets('ipucu verilmezse bina künyesine fazladan satır eklenmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Stack(
          children: [
            WorldTag(
              anchor: Offset(200, 180),
              title: 'Ambar',
              line2: 'depolama',
              line3: '',
              opacity: 1,
            ),
          ],
        ),
      ),
    );

    expect(find.textContaining('Tek tık'), findsNothing);
  });
}
