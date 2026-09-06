import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/vehicle_renderer.dart';

void main() {
  test('kervan grid hareketinden dört ekran yönünü ayırır', () {
    expect(
      VehicleRenderer.directionForGridVelocity(1, 0),
      CartDirection.southEast,
    );
    expect(
      VehicleRenderer.directionForGridVelocity(0, 1),
      CartDirection.southWest,
    );
    expect(
      VehicleRenderer.directionForGridVelocity(0, -1),
      CartDirection.northEast,
    );
    expect(
      VehicleRenderer.directionForGridVelocity(-1, 0),
      CartDirection.northWest,
    );
  });

  test('kervan yürüyüş fazı dört nal ritminde sarar', () {
    expect(VehicleRenderer.horseCartWalkFrame(0), 0);
    expect(VehicleRenderer.horseCartWalkFrame(pi / 2), 1);
    expect(VehicleRenderer.horseCartWalkFrame(pi), 2);
    expect(VehicleRenderer.horseCartWalkFrame(3 * pi / 2), 3);
    expect(VehicleRenderer.horseCartWalkFrame(2 * pi), 0);
    expect(VehicleRenderer.horseCartWalkFrame(-pi / 2), 3);
  });
}
