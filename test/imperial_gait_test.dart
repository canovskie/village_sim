import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/entities/imperial_soldier.dart';
import 'package:village_sim/entities/worker_entity.dart';
import 'package:village_sim/rendering/character_renderer.dart';

ImperialSoldier soldier({bool commander = false}) => ImperialSoldier(
  startCol: 10,
  startRow: 10,
  commander: commander,
  backOffset: 0,
  sideOffset: 0,
  seed: 7,
);
Future<Uint8List> frame(ImperialSoldier s) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(90, 160);
  CharacterRenderer.draw(
    canvas,
    s.type,
    visual: s.visual,
    costume: s.costume,
    commander: s.commander,
    walkPhase: s.walkPhase,
    moveIntensity: s.moveIntensity,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(180, 190);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  picture.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    WorkerEntity.pathContext = null;
  });
  for (final commander in [false, true]) {
    test(
      'marching ${commander ? "commander" : "soldier"} advances actual leg pixels',
      () async {
        final s = soldier(commander: commander);
        for (var i = 0; i < 15; i++) {
          s.stepTo(1 / 60, 20, 10);
        }
        final beforePhase = s.walkPhase;
        final before = await frame(s);
        for (var i = 0; i < 15; i++) {
          s.stepTo(1 / 60, 20, 10);
        }
        expect(s.walkPhase, isNot(beforePhase));
        final after = await frame(s);
        var changed = 0;
        for (var y = 132; y < 163; y++) {
          for (var x = 65; x < 115; x++) {
            final index = (y * 180 + x) * 4;
            if (before[index] != after[index] ||
                before[index + 3] != after[index + 3]) {
              changed++;
            }
          }
        }
        expect(
          changed,
          greaterThan(35),
          reason: 'legs must change, not only the spear or cape',
        );
      },
    );
  }
  test('standing soldiers do not march in place', () {
    final s = soldier();
    for (var i = 0; i < 120; i++) {
      s.stepTo(1 / 60, 10, 10);
    }
    expect(s.walkPhase, 0);
    expect(s.moveIntensity, 0);
  });
  test('gait is distance-driven at slow and fast marching speeds', () {
    final slow = soldier(), fast = soldier();
    for (var i = 0; i < 20; i++) {
      slow.stepTo(1 / 60, 20, 10, speedMul: .5);
      fast.stepTo(1 / 60, 20, 10, speedMul: 1.8);
    }
    expect(fast.gridX, greaterThan(slow.gridX));
    expect(fast.walkPhase, closeTo((fast.gridX - 10) * 5.5, .0001));
    expect(slow.walkPhase, closeTo((slow.gridX - 10) * 5.5, .0001));
  });
  test('externally simulated combat movement also advances steps', () {
    final s = soldier();
    s.gridX += .1;
    s.animateExternalMotion(.1, 10, 10);
    expect(s.walkPhase, closeTo(.55, .0001));
    s.gridX += .2;
    s.animateExternalMotion(.1, 10.1, 10, stepping: false);
    expect(
      s.walkPhase,
      closeTo(.55, .0001),
      reason: 'knockback is a slide, not a walking step',
    );
  });
}
