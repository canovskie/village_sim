import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/npc_visual.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/rendering/character_renderer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<Uint8List> render(NpcWardrobe wardrobe) async {
    const width = 180;
    const height = 180;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..translate(width / 2, height - 18)
      ..scale(1.25, 1.25);
    CharacterRenderer.draw(
      canvas,
      VillagerType.farmer,
      visual: NpcVisual.fromSeed(41, forceMale: true),
      wardrobe: wardrobe,
    );
    final image = await recorder.endRecording().toImage(width, height);
    final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  test('iki Divan sonucu farklı ve görünür kıyafet siluetleri çizer', () async {
    final flowing = await render(NpcWardrobe.flowing);
    final traditional = await render(NpcWardrobe.traditional);
    var visible = 0;
    var different = 0;
    for (var i = 0; i < flowing.length; i += 4) {
      if (flowing[i + 3] > 0) visible++;
      if (flowing[i] != traditional[i] ||
          flowing[i + 1] != traditional[i + 1] ||
          flowing[i + 2] != traditional[i + 2] ||
          flowing[i + 3] != traditional[i + 3]) {
        different++;
      }
    }
    expect(visible, greaterThan(500));
    expect(
      different,
      greaterThan(300),
      reason: 'iki karar aynı sprite varyantına düşmemeli',
    );
  });
}
