import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/systems/world/road_system.dart';

Future<Uint8List> _render(BuildingEntity building) async {
  const size = ui.Size(480, 320);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  VillageGamePainter(
    villagers: const [],
    buildings: [building],
    pendingOrders: const [],
    roadSystem: RoadSystem(),
    camera: ui.Offset.zero,
    time: 1.25,
    dayLight: 1,
    perfMode: true,
  ).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final type in const [
    BuildingType.mineBuilding,
    BuildingType.lumberCamp,
    BuildingType.fisherCabin,
    BuildingType.barn,
  ]) {
    test(
      '${type.name} yalnız çalışırken hareketli üretim izi gösterir',
      () async {
        final building = BuildingEntity(type: type, col: 3, row: 4);
        final idle = await _render(building);

        building.isActive = true;
        final active = await _render(building);

        expect(active, isNot(orderedEquals(idle)));
      },
    );
  }
}
