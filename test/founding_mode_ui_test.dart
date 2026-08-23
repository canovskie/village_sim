import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_renderer.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/founding_choice.dart';
import 'package:village_sim/ui/app_ui.dart';
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
            onSelect: (_) => true,
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
    final stock = ResourceBundle(wood: 99);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: CommandBar(
              buildSegment: BuildingPanel(
                stockpile: stock,
                selected: null,
                hasFirepit: true,
                onlyType: BuildingType.tent,
                onSelect: (_) => true,
              ),
              showCivicGates: false,
              onDefter: () {},
              onDivan: () {},
              onRoster: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Çadır'), findsOneWidget);
    expect(tester.getSize(find.byType(AppPanel)).width, 136);
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
                  onSelect: (_) {
                    selected++;
                    return true;
                  },
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
      expect(find.textContaining('seç'), findsOneWidget);

      await tester.tap(find.text('Çadır'));
      await tester.pumpAndSettle();
      expect(selected, 1);
      expect(find.text('Çadır'), findsNothing);
    },
  );

  testWidgets('mobilde kaynağı eksik yapı katalogu kapatmaz', (tester) async {
    tester.view.physicalSize = const Size(896, 414);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stock = ResourceBundle();
    var attempts = 0;

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
                onSelect: (_) {
                  attempts++;
                  return false;
                },
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
    expect(find.text('EKSİK'), findsOneWidget);

    await tester.tap(find.text('Çadır'));
    await tester.pumpAndSettle();
    expect(attempts, 1);
    expect(find.byKey(const ValueKey('mobile_build_catalog')), findsOneWidget);
  });

  testWidgets('masaüstü kart görseli ve BuildingMeta verisini birlikte taşır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(BuildingRenderer.loadAll);
    final stock = ResourceBundle(
      wood: 99,
      stone: 99,
      iron: 99,
      food: 99,
      gold: 99,
    );
    const type = BuildingType.townhall;
    final meta = kBuildingMeta[type]!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: BuildingPanel(
              stockpile: stock,
              selected: type,
              hasFirepit: true,
              onlyType: type,
              onSelect: (_) => true,
            ),
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('building_tile_townhall'));
    expect(card, findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text(meta.label)),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: card,
        matching: find.text('${meta.cols}×${meta.rows}'),
      ),
      findsOneWidget,
    );
    for (final (_, amount) in meta.cost.entries) {
      expect(
        find.descendant(of: card, matching: find.text('$amount')),
        findsOneWidget,
      );
    }
    expect(
      find.descendant(of: card, matching: find.byType(CustomPaint)),
      findsOneWidget,
    );
    expect(tester.getSize(card), const Size(116, 108));
    expect(tester.takeException(), isNull);
  });

  testWidgets('kart durumları renk dışında görünür etiketlerle ayrışır', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stock = ResourceBundle(wood: 18, stone: 4);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: BuildingPanel(
              stockpile: stock,
              selected: BuildingType.woodenHouse,
              hasFirepit: true,
              category: BuildCategory.konut,
              onSelect: (_) => true,
            ),
          ),
        ),
      ),
    );

    expect(
      find.descendant(
        of: find.byKey(const ValueKey('building_state_woodenHouse')),
        matching: find.text('SEÇİLİ'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('building_state_tent')),
        matching: find.text('HAZIR'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('building_state_stoneHouseGreen')),
        matching: find.text('EKSİK'),
      ),
      findsOneWidget,
    );

    final longLabel = tester.widget<Text>(
      find.text(kBuildingMeta[BuildingType.stoneHouseGreen]!.label),
    );
    expect(longLabel.maxLines, 1);
    expect(longLabel.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets('maliyeti bypass eden sahne kartta da inşa edilebilir görünür', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const type = BuildingType.townhall;
    final meta = kBuildingMeta[type]!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: BuildingPanel(
              stockpile: ResourceBundle(),
              selected: null,
              hasFirepit: true,
              onlyType: type,
              bypassCosts: true,
              onSelect: (_) => true,
            ),
          ),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('building_tile_townhall'));
    expect(
      find.descendant(of: card, matching: find.text('HAZIR')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('EKSİK')),
      findsNothing,
    );
    for (final (_, amount) in meta.cost.entries) {
      final amountText = tester.widget<Text>(
        find.descendant(of: card, matching: find.text('$amount')).first,
      );
      expect(amountText.style?.color, AppUi.textMid);
    }
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(896, 414), const Size(760, 360)]) {
    testWidgets('mobil kalabalık katalog $size alanında taşmaz', (
      tester,
    ) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final stock = ResourceBundle(
        wood: 99,
        stone: 99,
        iron: 99,
        coal: 99,
        food: 99,
        honey: 99,
        reed: 99,
        gold: 99,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CommandBar(
                showCivicGates: false,
                buildSegment: BuildingPanel(
                  stockpile: stock,
                  selected: BuildingType.stoneHouseGreen,
                  hasFirepit: true,
                  onSelect: (_) => true,
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
      expect(
        tester.getRect(find.byKey(const ValueKey('mobile_build_catalog'))),
        Rect.fromLTWH(0, 0, size.width, size.height),
      );
      expect(
        find.text(kBuildingMeta[BuildingType.stoneHouseGreen]!.label),
        findsOneWidget,
      );

      final townhall = find.byKey(const ValueKey('building_tile_townhall'));
      await tester.scrollUntilVisible(
        townhall,
        100,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      final townhallMeta = kBuildingMeta[BuildingType.townhall]!;
      for (final (_, amount) in townhallMeta.cost.entries) {
        expect(
          find.descendant(of: townhall, matching: find.text('$amount')),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('embedded ve standalone masaüstü yüzey sözleşmesini korur', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final stock = ResourceBundle(wood: 99);

    Future<void> pumpPanel({required bool embedded}) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: BuildingPanel(
              stockpile: stock,
              selected: null,
              hasFirepit: true,
              onlyType: BuildingType.tent,
              embedded: embedded,
              onSelect: (_) => true,
            ),
          ),
        ),
      ),
    );

    await pumpPanel(embedded: false);
    expect(find.byType(AppPanel), findsOneWidget);
    expect(tester.getSize(find.byType(AppPanel)), const Size(136, 126));
    expect(tester.takeException(), isNull);

    await pumpPanel(embedded: true);
    expect(find.byType(AppPanel), findsNothing);
    expect(tester.getSize(find.byType(BuildingPanel)).height, 124);
    expect(tester.takeException(), isNull);
  });
}
