import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_function.dart';
import 'package:village_sim/buildings/building_renderer.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/buildings/craft.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/founding_choice.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/building_panel.dart';
import 'package:village_sim/ui/command_bar.dart';

void main() {
  test('her kafile zorunlu kuruluş zincirini kaynak beklemeden kurar', () {
    const fixedPath = [
      BuildingType.lumberCamp,
      BuildingType.well,
      BuildingType.woodenHouse,
    ];
    for (final choice in [...FoundingChoice.all, FoundingChoice.fallback]) {
      final tentCapacity =
          kBuildingFunctions[BuildingType.tent]!.housingCapacity;
      final tentCount = (choice.people / tentCapacity).ceil();
      final neededWood =
          tentCount * kBuildingMeta[BuildingType.tent]!.cost.wood +
          fixedPath.fold<int>(
            0,
            (sum, type) => sum + kBuildingMeta[type]!.cost.wood,
          );
      final neededStone = fixedPath.fold<int>(
        0,
        (sum, type) => sum + kBuildingMeta[type]!.cost.stone,
      );
      expect(
        choice.wood,
        greaterThanOrEqualTo(neededWood),
        reason: '${choice.id} kuyudan sonra ilk ev için odun bekletir',
      );
      expect(
        choice.stone,
        greaterThanOrEqualTo(neededStone),
        reason: '${choice.id} kuyudan sonra ilk ev için taş bekletir',
      );
    }
  });

  test('çadır iki kişi barındırır', () {
    expect(kBuildingFunctions[BuildingType.tent]!.housingCapacity, 2);
  });

  test('kurucu meslek bilgileri ve üç uzman hakkı tüm iş kollarını açar', () {
    const foundingCrafts = {
      Craft.farming,
      Craft.husbandry,
      Craft.milling,
      Craft.faith,
    };
    final professionCrafts = Craft.all
        .where((craft) => !Craft.structural.contains(craft))
        .toSet();

    for (final choice in [...FoundingChoice.all, FoundingChoice.fallback]) {
      final carried = craftsCarriedBy(choice.roster.map((member) => member.$1));
      expect(carried, containsAll(foundingCrafts), reason: choice.id);
      expect(
        {...carried, ...kGuaranteedSpecialistCrafts},
        containsAll(professionCrafts),
        reason: '${choice.id} uzmanlığa erişemiyor',
      );
    }
  });

  testWidgets('bilinmeyen binalar katalogda gerekçesiyle görünür', (
    tester,
  ) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BuildingPanel(
            stockpile: ResourceBundle(wood: 999, stone: 999),
            selected: null,
            hasFirepit: true,
            category: BuildCategory.konut,
            isUnlocked: (type) => type == BuildingType.tent,
            onSelect: (_) {
              selected = true;
              return true;
            },
          ),
        ),
      ),
    );

    expect(find.text('Köy Evi'), findsOneWidget);
    expect(find.text('Marangozluk gerekli'), findsOneWidget);
    expect(find.text('KİLİTLİ'), findsWidgets);

    await tester.tap(find.text('Köy Evi'));
    await tester.pump();
    expect(selected, isFalse, reason: 'kilitli kart seçim üretmemeli');
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

    // Masaüstünde katalog haritayı sürekli kaplamaz; sol alttaki inşa
    // kapısından yukarı açılır.
    expect(find.text('Çadır'), findsNothing);
    expect(find.byKey(const ValueKey('desktop_build_catalog')), findsNothing);
    await tester.tap(find.text('İNŞA'));
    await tester.pumpAndSettle();
    expect(find.text('Çadır'), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop_build_catalog')), findsOneWidget);
    final catalogPanel = find.ancestor(
      of: find.text('Çadır'),
      matching: find.byType(AppPanel),
    );
    expect(tester.getSize(catalogPanel), const Size(184, 166));
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

  testWidgets(
    'masaüstü katalog seçimle kapanır, reddedilen seçimde açık kalır',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      var accepted = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: CommandBar(
                showCivicGates: false,
                buildSegment: BuildingPanel(
                  stockpile: ResourceBundle(),
                  selected: null,
                  hasFirepit: true,
                  onlyType: BuildingType.tent,
                  onSelect: (_) => accepted,
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
      await tester.tap(find.text('Çadır'));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop_build_catalog')),
        findsOneWidget,
      );

      accepted = true;
      await tester.tap(find.text('Çadır'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('desktop_build_catalog')), findsNothing);
      expect(find.text('Çadır'), findsNothing);
    },
  );

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
    expect(
      BuildingRenderer.thumbnails[type]!.width,
      greaterThanOrEqualTo(256),
      reason: 'Katalog büyük kartta düşük çözünürlüklü thumbnail büyütmemeli',
    );
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
    expect(tester.getSize(card), const Size(164, 148));
    expect(tester.takeException(), isNull);
  });

  testWidgets('istisna kart durumları etiketlenir, normal kart sade kalır', (
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
    expect(find.byKey(const ValueKey('building_state_tent')), findsNothing);
    expect(find.text('HAZIR'), findsNothing);
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
    expect(longLabel.maxLines, 2);
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
    expect(find.byKey(const ValueKey('building_state_townhall')), findsNothing);
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

  testWidgets('seçili ama yetersiz kart iki durumu da metinle gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: BuildingPanel(
              stockpile: ResourceBundle(),
              selected: BuildingType.manor,
              hasFirepit: true,
              onlyType: BuildingType.manor,
              onSelect: (_) => false,
            ),
          ),
        ),
      ),
    );

    final state = find.byKey(const ValueKey('building_state_manor'));
    expect(
      find.descendant(of: state, matching: find.text('SEÇİLİ')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: state, matching: find.text('EKSİK')),
      findsOneWidget,
    );
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
                buildSegment: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(
                      key: ValueKey('production_category_rail_budget'),
                      height: 54,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 14),
                          child: Text('KONUT'),
                        ),
                      ),
                    ),
                    const Divider(height: 1, thickness: 1),
                    Expanded(
                      child: BuildingPanel(
                        stockpile: stock,
                        selected: BuildingType.stoneHouseGreen,
                        hasFirepit: true,
                        category: BuildCategory.konut,
                        onSelect: (_) => true,
                      ),
                    ),
                  ],
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
      final tentRect = tester.getRect(
        find.byKey(const ValueKey('building_tile_tent')),
      );
      final houseRect = tester.getRect(
        find.byKey(const ValueKey('building_tile_woodenHouse')),
      );
      expect(tentRect.height, 104);
      expect(tentRect.width, greaterThan(300));
      expect(houseRect.top, tentRect.top);
      expect(houseRect.left, greaterThan(tentRect.right));

      final manor = find.byKey(const ValueKey('building_tile_manor'));
      await tester.scrollUntilVisible(
        manor,
        100,
        scrollable: find.descendant(
          of: find.byType(GridView),
          matching: find.byType(Scrollable),
        ),
      );
      final manorMeta = kBuildingMeta[BuildingType.manor]!;
      for (final (_, amount) in manorMeta.cost.entries) {
        expect(
          find.descendant(of: manor, matching: find.text('$amount')),
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
    expect(tester.getSize(find.byType(AppPanel)), const Size(184, 166));
    expect(tester.takeException(), isNull);

    await pumpPanel(embedded: true);
    expect(find.byType(AppPanel), findsNothing);
    expect(tester.getSize(find.byType(BuildingPanel)).height, 164);
    expect(tester.takeException(), isNull);
  });
}
