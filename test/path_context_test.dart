import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/path_context.dart';
import 'package:village_sim/systems/road_system.dart';
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
}
