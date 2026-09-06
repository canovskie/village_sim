import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/npc/path_context.dart';
import 'package:village_sim/systems/world/road_system.dart';
import 'package:village_sim/world/road_surface.dart';
import 'package:village_sim/world/road_tile.dart';

void main() {
  test('yumuşak yüzey geçilir ama normal zeminden pahalıdır', () {
    final context = PathContext(roadSystem: RoadSystem(), softTiles: {(4, 5)});

    expect(context.blocked(4, 5), isFalse);
    expect(context.costAt(4, 5), greaterThan(context.costAt(3, 5)));
  });

  test('yol, yumuşak yüzey maliyetini bastırır', () {
    final roads = RoadSystem()
      ..add(RoadTile(col: 4, row: 5, surface: RoadSurface.dirt));
    final context = PathContext(roadSystem: roads, softTiles: {(4, 5)});

    expect(context.costAt(4, 5), lessThan(1));
  });

  test('görünmez yaya şeridi çimden ucuz, gerçek yoldan pahalıdır', () {
    final roads = RoadSystem()
      ..add(RoadTile(col: 3, row: 5, surface: RoadSurface.dirt));
    final context = PathContext(roadSystem: roads, pedestrianTiles: {(4, 5)});

    expect(context.costAt(4, 5), lessThan(context.costAt(5, 5)));
    expect(context.costAt(4, 5), greaterThan(context.costAt(3, 5)));
    expect(context.isPreferredTransit(4, 5), isTrue);
  });
}
