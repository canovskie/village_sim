import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/building_specialization.dart';
import 'package:village_sim/systems/building_system.dart';
import 'package:village_sim/ui/building_info_panel.dart';

void main() {
  testWidgets('geç dönem bina paneli gerçek uzmanlığını okutur',
      (tester) async {
    const stats = VillageStats(
      stockCapacity: 120,
      morale: 0.55,
      carrierSpeedMultiplier: 1.0,
    );

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

    final bathhouse = BuildingEntity(
      type: BuildingType.bathhouse,
      col: 0,
      row: 0,
    )
      ..isActive = true
      ..serviceTimer = kBathhouseFuelSeconds;
    await show(bathhouse);
    expect(find.text('Bakım veriyor'), findsOneWidget);
    expect(find.text('+100%'), findsOneWidget);

    final monument = BuildingEntity(
      type: BuildingType.monument,
      col: 0,
      row: 0,
    )..inscription = 'Açık Pazar · Demirhan Hanesi · 42. gün';
    await show(monument);
    expect(find.text(monument.inscription), findsOneWidget);

    await show(BuildingEntity(
      type: BuildingType.belltower,
      col: 0,
      row: 0,
    ));
    expect(find.text('+60%'), findsOneWidget);
    expect(find.text('1'), findsWidgets);

    await show(BuildingEntity(
      type: BuildingType.caravanserai,
      col: 0,
      row: 0,
    ));
    expect(find.text('%35 daha sık'), findsOneWidget);
    expect(find.text('%55 daha uzun'), findsOneWidget);
  });
}
