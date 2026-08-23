import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/decor_renderer.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/systems/road_system.dart';
import 'package:village_sim/world/decor_entity.dart';

void main() {
  DecorEntity decorAt(int col, int row) => DecorEntity(
    col: col,
    row: row,
    kind: DecorKind.daisy,
    variant: 0,
    jitterX: 0,
    jitterY: 0,
    swaySeed: 3,
  );

  VillageGamePainter painter({
    required List<DecorEntity> decor,
    required int decorVersion,
    required RoadSystem roadSystem,
  }) => VillageGamePainter(
    villagers: const [],
    buildings: const [],
    pendingOrders: const [],
    roadSystem: roadSystem,
    camera: ui.Offset.zero,
    decor: decor,
    decorVersion: decorVersion,
    time: 0.25,
    perfMode: true,
  );

  test('decorVersion yerinde liste degisimini repaint eder', () {
    final roadSystem = RoadSystem();
    final decor = <DecorEntity>[decorAt(0, 0)];
    final before = painter(
      decor: decor,
      decorVersion: 41,
      roadSystem: roadSystem,
    );

    decor[0] = decorAt(4, 0);
    final after = painter(
      decor: decor,
      decorVersion: 42,
      roadSystem: roadSystem,
    );

    expect(
      after.shouldRepaint(before),
      isTrue,
      reason:
          'Liste kimligi ve uzunlugu ayni olsa da yeni decor kareye girmeli',
    );
  });

  testWidgets(
    'ayni uzunluktaki yeni ve yerinde mutate edilen listeler decor cacheini yeniler',
    (tester) async {
      final frames = await tester.runAsync(() async {
        await DecorRenderer.loadAll();
        final roadSystem = RoadSystem();

        final initialDecor = <DecorEntity>[decorAt(0, 0)];
        final initial = await render(
          painter(
            decor: initialDecor,
            decorVersion: 701,
            roadSystem: roadSystem,
          ),
        );

        final replacementDecor = <DecorEntity>[decorAt(4, 0)];
        final replaced = await render(
          painter(
            decor: replacementDecor,
            decorVersion: 701,
            roadSystem: roadSystem,
          ),
        );

        replacementDecor[0] = decorAt(4, 4);
        final mutated = await render(
          painter(
            decor: replacementDecor,
            decorVersion: 702,
            roadSystem: roadSystem,
          ),
        );

        return (initial, replaced, mutated);
      });

      expect(frames, isNotNull);
      final (initial, replaced, mutated) = frames!;
      expect(
        differingPixels(initial, replaced),
        greaterThan(20),
        reason: 'Ayni uzunluktaki yeni listenin decor konumu rendera yansimali',
      );
      expect(
        differingPixels(replaced, mutated),
        greaterThan(20),
        reason: 'Yerinde mutasyondan sonra decorVersion bucketi yenilemeli',
      );
    },
  );
}

Future<Uint8List> render(VillageGamePainter painter) async {
  const size = ui.Size(512, 320);
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  painter.paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  if (data == null) throw StateError('Painter kare verisi uretmedi');
  return Uint8List.fromList(data.buffer.asUint8List());
}

int differingPixels(Uint8List a, Uint8List b) {
  if (a.length != b.length) return a.length > b.length ? a.length : b.length;
  var count = 0;
  for (var i = 0; i < a.length; i += 4) {
    if (a[i] != b[i] ||
        a[i + 1] != b[i + 1] ||
        a[i + 2] != b[i + 2] ||
        a[i + 3] != b[i + 3]) {
      count++;
    }
  }
  return count;
}
