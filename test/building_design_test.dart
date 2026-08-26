import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_design.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_renderer.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/entities/build_order.dart';

void main() {
  test('ahşap ev tasarımları karışık ama tekrar üretilebilir seçilir', () {
    final first = List.generate(
      32,
      (i) => automaticBuildingDesign(BuildingType.woodenHouse, i),
    );
    final second = List.generate(
      32,
      (i) => automaticBuildingDesign(BuildingType.woodenHouse, i),
    );

    expect(second, first, reason: 'Aynı sıra her açılışta aynı evi üretmeli.');
    expect(
      first.toSet(),
      containsAll(buildingDesignsFor(BuildingType.woodenHouse)),
    );
    for (var i = 1; i < first.length; i++) {
      expect(
        first[i],
        isNot(first[i - 1]),
        reason: 'Ardışık iki kurulum aynı tasarıma düşmemeli.',
      );
    }
  });

  test('varyantı olmayan bina güvenle orijinale döner', () {
    final building = BuildingEntity(
      type: BuildingType.well,
      col: 4,
      row: 8,
      design: BuildingDesign.terracotta,
    );
    final order = BuildOrder(
      type: BuildingType.well,
      col: 4,
      row: 8,
      design: BuildingDesign.terracotta,
    );

    expect(building.design, BuildingDesign.original);
    expect(order.design, BuildingDesign.original);
  });

  test('tasarım döngüsü yalnız desteklenen görünüşler arasında kalır', () {
    expect(
      nextBuildingDesign(BuildingType.woodenHouse, BuildingDesign.original),
      BuildingDesign.terracotta,
    );
    expect(
      nextBuildingDesign(BuildingType.woodenHouse, BuildingDesign.terracotta),
      BuildingDesign.garden,
    );
    expect(
      nextBuildingDesign(BuildingType.woodenHouse, BuildingDesign.garden),
      BuildingDesign.artisan,
    );
    expect(
      nextBuildingDesign(BuildingType.woodenHouse, BuildingDesign.artisan),
      BuildingDesign.original,
    );
  });

  testWidgets('ahşap ev tasarım havuzunun bütün sprite’ları yüklenir', (
    tester,
  ) async {
    await tester.runAsync(BuildingRenderer.loadAll);
    for (final design in buildingDesignsFor(BuildingType.woodenHouse)) {
      expect(
        BuildingRenderer.thumbnailFor(BuildingType.woodenHouse, design),
        isNotNull,
        reason: '${design.name} tasarım asset’i yüklenemedi.',
      );
    }
  });
}
