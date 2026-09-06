import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/smoke_renderer.dart';
import 'package:village_sim/world/animal_entity.dart';
import 'package:village_sim/world/bird_flock.dart';

VillagerEntity _villager() => VillagerEntity(
  type: VillagerType.farmer,
  name: 'İzci',
  male: true,
  startCol: 2,
  startRow: 2,
  ageDays: kAdultStartDay + 1,
  visualSeed: 41,
  personalitySeed: 41,
);

Future<Uint8List> _renderSmoke({required double windDrift}) async {
  const size = ui.Size(120, 100);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  SmokeRenderer.draw(
    canvas,
    60,
    80,
    1.8,
    1.25,
    17,
    tint: const Color(0xFFB8AEA0),
    windDrift: windDrift,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return data!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('çamur ayak izi mesafeyle doğar, sınırlanır ve kısa sürede silinir', () {
    final v = _villager()..moveIntensity = 1;
    v.tickMudFootprints(0.1, muddy: true);

    for (var i = 1; i <= 24; i++) {
      v.renderX = 2 + i * 0.24;
      v.tickMudFootprints(0.1, muddy: true);
    }

    expect(v.mudFootprints, isNotEmpty);
    expect(v.mudFootprints.length, lessThanOrEqualTo(14));
    expect(
      v.mudFootprints.map((e) => e.leftFoot).toSet(),
      containsAll(<bool>{true, false}),
    );

    v.moveIntensity = 0;
    v.tickMudFootprints(MudFootprintTrace.lifetime + 0.1, muddy: false);
    expect(v.mudFootprints, isEmpty);
  });

  test('fırtına yaklaşınca hayvan bağlı olduğu ahırın önüne yaklaşır', () {
    final animal = AnimalEntity(
      kind: AnimalKind.cow,
      barnCol: 3,
      barnRow: 4,
      startCol: 11,
      startRow: 11,
    );
    final rng = Random(8);
    const targetX = 4.5;
    const targetY = 6.35;
    final before = sqrt(
      pow(animal.gridX - targetX, 2) + pow(animal.gridY - targetY, 2),
    );

    for (var i = 0; i < 80; i++) {
      animal.update(0.1, rng, seekStormShelter: true);
    }

    final after = sqrt(
      pow(animal.gridX - targetX, 2) + pow(animal.gridY - targetY, 2),
    );
    expect(animal.stormSheltering, isTrue);
    expect(after, lessThan(before * 0.55));
  });

  test('şafak kuşları verilen çatı noktasından küçük grup olarak doğar', () {
    final flock = BirdFlock.spawnFromRoof(Random(12), roofX: 7.5, roofY: 9.0);

    expect(flock.leadX, 7.5);
    expect(flock.leadY, 9.0);
    expect(flock.birds.length, 4);
    expect(flock.altitude, lessThan(50));
  });

  test('sert rüzgâr aynı baca dumanını görünür biçimde yana yatırır', () async {
    await SmokeRenderer.loadAll();
    final upright = await _renderSmoke(windDrift: 0);
    final windy = await _renderSmoke(windDrift: 0.58);

    expect(windy, isNot(orderedEquals(upright)));
  });
}
