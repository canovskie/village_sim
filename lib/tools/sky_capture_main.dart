// HUD gök şeridi (güneş↔ay kovalamacası) önizleme harness'ı — günün 4 vaktinde
// tam HUD şeridini üst üste çizer, PNG'ye çeker.
//
// Çalıştır:  flutter run -d macos -t lib/tools/sky_capture_main.dart
// Çıktı:     /tmp/sky_track.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../core/resources.dart';
import '../world/season.dart';
import '../ui/hud.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const Scaffold(body: _Rows()),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 800));
  await _capture('/tmp/sky_track.png');
  exit(0);
}

class _Rows extends StatelessWidget {
  const _Rows();

  @override
  Widget build(BuildContext context) {
    // (timeOfDay, dayLight, etiket)
    const cases = <(double, double, String)>[
      (0.00, 0.0, 'gece yarısı 00:00 — ay dipte'),
      (0.25, 0.3, 'şafak 06:00 — güneş sol ufukta'),
      (0.375, 0.8, 'kuşluk 09:00'),
      (0.50, 1.0, 'öğle 12:00 — güneş tepede'),
      (0.75, 0.2, 'akşam 18:00 — güneş batıyor, ay doğuyor'),
    ];
    return FittedBox(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (t, light, label) in cases)
            Container(
              height: 110,
              width: 1440, // gerçek oyun penceresi genişliği — çakışma testi

              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(const Color(0xFF14203A), const Color(0xFF7FB3D6), light)!,
                    Color.lerp(const Color(0xFF1D2A20), const Color(0xFFA8C48A), light)!,
                  ],
                ),
              ),
              child: Stack(children: [
                _hud(t, light),
                Positioned(
                  bottom: 4,
                  left: 10,
                  child: Text(label,
                      style: const TextStyle(color: Colors.white70, fontSize: 11)),
                ),
              ]),
            ),
        ],
      ),
    );
  }

  Widget _hud(double t, double light) => GameHUD(
        stockpile: ResourceBundle(wood: 40, stone: 22, food: 61, iron: 5, coal: 3),
        woodInTransit: 2,
        stoneInTransit: 0,
        ironInTransit: 0,
        coalInTransit: 0,
        foodInTransit: 1,
        villagerCount: 6,
        farmerCount: 3,
        woodcutterCount: 2,
        minerCount: 1,
        fisherCount: 1,
        builderCount: 2,
        busyBuilders: 1,
        timeOfDay: t,
        rainIntensity: 0,
        dayLight: light,
        dayCount: 12,
        season: Season.summer,
        buildingCount: 9,
        pendingOrderCount: 1,
        morale: 0.62,
        lowWater: false,
        starving: false,
        fullPulse: 0.5,
        godMode: false,
        onNewMap: () {},
        onToggleGod: () {},
        onTriggerEvent: () {},
        timeScale: 1,
        onCycleSpeed: () {},
        onToggleDev: () {},
        muted: false,
        onToggleMute: () {},
      );
}

Future<void> _capture(String path) async {
  final boundary = _boundaryKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  await File(path).writeAsBytes(bytes!.buffer.asUint8List());
  stdout.writeln('saved $path');
}
