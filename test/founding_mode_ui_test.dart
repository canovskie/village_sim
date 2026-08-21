import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/founding_choice.dart';
import 'package:village_sim/ui/building_panel.dart';
import 'package:village_sim/ui/command_bar.dart';

void main() {
  test('her kafile kuruluş zincirini tamamlayacak odunla gelir', () {
    final needed =
        kBuildingMeta[BuildingType.tent]!.cost.wood +
        kBuildingMeta[BuildingType.lumberCamp]!.cost.wood;
    for (final choice in [...FoundingChoice.all, FoundingChoice.fallback]) {
      expect(
        choice.wood,
        greaterThanOrEqualTo(needed),
        reason: '${choice.id} çadır + oduncu kulübesi zincirinde kilitlenir',
      );
    }
  });

  testWidgets('kuruluş katalogu yalnız sıradaki yapıyı gösterir', (
    tester,
  ) async {
    final stock = ResourceBundle()..wood = 99;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuildingPanel(
            stockpile: stock,
            selected: null,
            hasFirepit: true,
            onlyType: BuildingType.tent,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Çadır'), findsOneWidget);
    expect(find.text('Köy Evi'), findsNothing);
    expect(find.text('Oduncu Kulübesi'), findsNothing);
  });

  testWidgets('kuruluşta derin yönetim kapıları gösterilmez', (tester) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CommandBar(
              buildSegment: const Text('ATEŞ YERİ'),
              showCivicGates: false,
              onDefter: () {},
              onDivan: () {},
              onRoster: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('ATEŞ YERİ'), findsOneWidget);
    expect(find.text('DEFTER'), findsNothing);
    expect(find.text('DİVAN'), findsNothing);
    expect(find.text('NÜFUS'), findsNothing);
  });

  testWidgets(
    'mobil inşa katalogu tam ekran açılır ve seçimden sonra kapanır',
    (tester) async {
      tester.view.physicalSize = const Size(896, 414);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stock = ResourceBundle()..wood = 99;
      var selected = 0;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CommandBar(
                showCivicGates: false,
                buildSegment: BuildingPanel(
                  stockpile: stock,
                  selected: null,
                  hasFirepit: true,
                  onlyType: BuildingType.tent,
                  onSelect: (_) => selected++,
                ),
                onDefter: () {},
                onDivan: () {},
                onRoster: () {},
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('İNŞA'));
      await tester.pumpAndSettle();
      final rect = tester.getRect(
        find.byKey(const ValueKey('mobile_build_catalog')),
      );
      expect(rect, const Rect.fromLTWH(0, 0, 896, 414));
      expect(find.text('Bir yapı veya araç seç'), findsOneWidget);

      await tester.tap(find.text('Çadır'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.text('Çadır'), findsNothing);
    },
  );
}
