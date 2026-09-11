import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/crime_system.dart';

void main() {
  test('fail bilinmiyorsa İzle suç mahallini seçer', () {
    final target = crimeWatchTarget(
      culpritKnown: false,
      culpritAvailable: true,
      culpritX: 9,
      culpritY: 10,
      sceneX: 3,
      sceneY: 4,
    );
    expect(target, (x: 3, y: 4));
  });

  test('fail biliniyor ve dünyadaysa İzle faili seçer', () {
    final target = crimeWatchTarget(
      culpritKnown: true,
      culpritAvailable: true,
      culpritX: 9,
      culpritY: 10,
      sceneX: 3,
      sceneY: 4,
    );
    expect(target, (x: 9, y: 10));
  });

  test('bilinen fail dünyadan çıktıysa İzle olay yerine düşer', () {
    final target = crimeWatchTarget(
      culpritKnown: true,
      culpritAvailable: false,
      culpritX: 9,
      culpritY: 10,
      sceneX: 3,
      sceneY: 4,
    );
    expect(target, (x: 3, y: 4));
  });
}
