import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/systems/labor/building_specialization.dart';
import 'package:village_sim/systems/labor/building_system.dart';
import 'package:village_sim/ui/core/app_ui.dart';
import 'package:village_sim/ui/hud/building_info_panel.dart';

void main() {
  testWidgets('geç dönem bina paneli gerçek uzmanlığını okutur', (
    tester,
  ) async {
    const stats = VillageStats(morale: 0.55, carrierSpeedMultiplier: 1.0);

    Future<void> show(BuildingEntity building) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SizedBox(
              width: 326,
              height: 700,
              child: BuildingInfoPanel(
                building: building,
                residents: const [],
                stockpile: ResourceBundle(wood: 20),
                stats: stats,
                population: 8,
                populationCap: 12,
                guardCount: 1,
                onClose: () {},
                onSell: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    }

    final bathhouse =
        BuildingEntity(type: BuildingType.bathhouse, col: 0, row: 0)
          ..isActive = true
          ..serviceTimer = kBathhouseFuelSeconds;
    await show(bathhouse);
    expect(find.byKey(const ValueKey('building_showcase')), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('building_showcase'))).height,
      96,
    );
    expect(find.text('Bakım veriyor'), findsOneWidget);
    expect(find.text('+100%'), findsOneWidget);

    final monument = BuildingEntity(type: BuildingType.monument, col: 0, row: 0)
      ..inscription = 'Açık Pazar · Demirhan Hanesi · 42. gün';
    await show(monument);
    expect(find.text(monument.inscription), findsOneWidget);

    await show(BuildingEntity(type: BuildingType.belltower, col: 0, row: 0));
    expect(find.text('+60%'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await show(BuildingEntity(type: BuildingType.caravanserai, col: 0, row: 0));
    expect(find.text('%35 daha sık'), findsOneWidget);
    expect(find.text('%15 daha uzun'), findsOneWidget);

    await show(BuildingEntity(type: BuildingType.warehouse, col: 0, row: 0));
    expect(find.text('Sınırsız'), findsOneWidget);
    expect(find.text('5 yük'), findsOneWidget);
  });

  testWidgets('kapasiteyi aşan ev olumlu değil tehlike olarak görünür', (
    tester,
  ) async {
    const stats = VillageStats(morale: 0.55, carrierSpeedMultiplier: 1.0);
    final residents = [
      for (var i = 0; i < 3; i++)
        VillagerEntity(
          type: VillagerType.farmer,
          name: 'Sakin $i',
          male: i.isEven,
          startCol: i.toDouble(),
          startRow: 0,
        ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 326,
            height: 700,
            child: BuildingInfoPanel(
              building: BuildingEntity(
                type: BuildingType.woodenHouse,
                col: 0,
                row: 0,
              ),
              residents: residents,
              stockpile: ResourceBundle(wood: 20),
              stats: stats,
              population: 3,
              populationCap: 2,
              onClose: () {},
              onSell: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final bar = tester.widget<AppStatBar>(
      find.byKey(const ValueKey('building_occupancy_bar')),
    );
    expect(bar.trailing, '3/2');
    expect(bar.color, AppUi.rust);
    expect(tester.takeException(), isNull);
  });
}
