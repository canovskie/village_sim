import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';

void main() {
  test('çadır, NPC siluetini eğimli yüzeyinin üstüne bindirmez', () {
    expect(kBuildingMeta[BuildingType.tent]!.showOccludedActors, isFalse);
  });

  test('duvarlı binalar arkadaki NPC siluetini göstermeye devam eder', () {
    expect(kBuildingMeta[BuildingType.woodenHouse]!.showOccludedActors, isTrue);
  });
}
