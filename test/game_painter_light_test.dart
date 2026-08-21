import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/systems/lighting_system.dart';
import 'package:village_sim/systems/road_system.dart';

void main() {
  test('büyük fiziksel viewport efekt bütçesini otomatik düşürüyor', () {
    expect(useReducedEffectsForViewport(const Size(1280, 800), 1), isFalse);
    expect(
      useReducedEffectsForViewport(const Size(1512, 982), 2),
      isTrue,
      reason: 'Retina fullscreen tam çözünürlüklü katmanlara girmemeli',
    );
    expect(
      useReducedEffectsForViewport(const Size(1920, 1080), 1),
      isTrue,
      reason: '1080p fullscreen da otomatik korunmalı',
    );
    expect(
      useReducedEffectsForViewport(const Size(3840, 2160), 1),
      isTrue,
      reason: '4K fullscreen otomatik korunmalı',
    );
    expect(
      useReducedEffectsForViewport(const Size(430, 932), 3),
      isFalse,
      reason: 'telefon yalnız yüksek DPR yüzünden masaüstü yoluna girmemeli',
    );
  });

  testWidgets('night light sprite renders and repaints without exceptions', (
    tester,
  ) async {
    Widget frame(double time, Color warm) => MaterialApp(
      home: Center(
        child: SizedBox(
          width: 640,
          height: 400,
          child: CustomPaint(
            painter: VillageGamePainter(
              villagers: const [],
              buildings: const [],
              pendingOrders: const [],
              roadSystem: RoadSystem(),
              camera: Offset.zero,
              time: time,
              dayLight: 0,
              overlayTop: const Color(0xCC081020),
              overlayBottom: const Color(0xDD030712),
              lightSources: [
                LightSource(
                  gx: 20,
                  gy: 20,
                  radius: 4,
                  intensity: 0.8,
                  warm: warm,
                ),
              ],
            ),
          ),
        ),
      ),
    );

    await tester.pumpWidget(frame(1, const Color(0xFFFF9540)));
    expect(tester.takeException(), isNull);

    // Exercise the cached sprite with a different tint/intensity frame.
    await tester.pumpWidget(frame(2, const Color(0xFFFFCE60)));
    expect(tester.takeException(), isNull);
  });
}
