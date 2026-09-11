@Tags(['probe'])
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/rendering/game_painter.dart';

void main() {
  testWidgets(
    'canlı köy yürüyüşü painter tarafından okunan yüzey izleri üretir',
    (tester) async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      for (final channel in [
        'xyz.luan/audioplayers',
        'xyz.luan/audioplayers.global',
        'plugins.flutter.io/shared_preferences',
        'plugins.flutter.io/path_provider',
      ]) {
        messenger.setMockMethodCallHandler(
          MethodChannel(channel),
          (call) async => call.method == 'getAll' ? <String, Object>{} : null,
        );
      }
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1;
      kCaptureMode = true;
      kProbeOn = true;
      kCaptureSceneReady = false;
      kCaptureTimeOfDay = 0.45;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        kCaptureMode = false;
        kProbeOn = false;
        kCaptureTimeOfDay = -1;
      });
      await tester.runAsync(() async {
        await tester.pumpWidget(
          const MaterialApp(home: VillageScene(referenceVillage: true)),
        );
        for (int i = 0; i < 200 && !kCaptureSceneReady; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 50));
        }
      });
      expect(kCaptureSceneReady, isTrue);
      bool seen = false;
      for (int i = 0; i < 180 && !seen; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        final painter = tester
            .widgetList<CustomPaint>(find.byType(CustomPaint))
            .map((w) => w.painter)
            .whereType<VillageGamePainter>()
            .single;
        seen = painter.villagers.any((v) => v.footstepTrail.steps.isNotEmpty);
      }
      expect(
        seen,
        isTrue,
        reason: 'post-motion zinciri yüzey izlerini beslemiyor',
      );
      await tester.pumpWidget(const SizedBox());
    },
  );
}
