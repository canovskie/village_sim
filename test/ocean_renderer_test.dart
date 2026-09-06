import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/ocean_renderer.dart';

void main() {
  test(
    'gökyüzü yansıması denizin üstünde ayrı bir gök katmanı oluşturmaz',
    () async {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(120, 80);

      // Aşırı kırmızı bir ortam tonu kullanmak, rengin gökyüzü katmanı olarak
      // çizilmesiyle yalnız suya hafifçe yansıması arasındaki farkı görünür kılar.
      OceanRenderer.draw(
        canvas,
        size,
        dayLight: 1,
        skyMid: const Color(0xFFFF0000),
        reducedEffects: true,
      );

      final picture = recorder.endRecording();
      final image = await picture.toImage(
        size.width.toInt(),
        size.height.toInt(),
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      expect(bytes, isNotNull);

      final offset = (4 * size.width.toInt() + size.width.toInt() ~/ 2) * 4;
      final red = bytes!.getUint8(offset);
      final green = bytes.getUint8(offset + 1);
      final blue = bytes.getUint8(offset + 2);

      expect(
        green,
        greaterThan(red),
        reason: 'üst kenar hâlâ teal deniz olmalı',
      );
      expect(blue, greaterThan(green), reason: 'mavi su paleti korunmalı');

      image.dispose();
      picture.dispose();
    },
  );
}
