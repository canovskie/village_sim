// Logo karşılaştırma harness'ı — telefondaki UYGULAMA SİMGESİ ile oyunun
// içindeki [GameLogo]'yu yan yana çeker. "Her yerdeki logo simgeyle aynı mı?"
// sorusunu gözle cevaplamak için; menü/loading/Hakkında/sinematik boyları
// gerçek çağrı yerlerinden alınmıştır.
//
// Çalıştır:  flutter run -d macos -t lib/tools/logo_capture_main.dart
// Çıktı:     /tmp/logo_compare.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../ui/app_ui.dart';

final GlobalKey _boundaryKey = GlobalKey();

/// iOS uygulama simgesinin 1024'lük hâli — pubspec asset'i değil, diskten
/// okunur (harness yalnız masaüstünde koşar).
const _iconPath =
    'ios/Runner/Assets.xcassets/AppIcon.appiconset/Icon-App-1024x1024@1x.png';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppUi.captureStatic = true;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: ColoredBox(
        color: AppUi.surface0,
        child: Padding(
          padding: const EdgeInsets.all(28),
          // Wrap (Row değil): hücre sayısı değişince kare taşmasın.
          child: Wrap(
            spacing: 22,
            runSpacing: 18,
            children: [
              _cell(
                'TELEFON SİMGESİ',
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: Image.file(File(_iconPath), width: 112, height: 112),
                ),
              ),
              // Menüdeki madalyonun birebir kopyası (main_menu_screen).
              _cell(
                'MENÜ · 74',
                Container(
                  width: 94,
                  height: 94,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [
                        Color(0x52FFD89D),
                        Color(0x14E49139),
                        Color(0x00E49139),
                      ],
                      stops: [0.0, 0.58, 1.0],
                    ),
                    border: Border.all(color: const Color(0x33F7E8CF)),
                  ),
                  child: const GameLogo(size: 74),
                ),
              ),
              _cell('HAKKINDA · 60 + hale',
                  const GameLogo(size: 60, glow: true)),
              _cell('LOADING · 40 (nabız 1.0)', const GameLogo(size: 40)),
              _cell('LOADING · 40 (nabız 0.4)',
                  const GameLogo(size: 40, warmth: 0.4)),
              _cell('SİNEMATİK · 24', const GameLogo(size: 24)),
            ],
          ),
        ),
      ),
    ),
  ));

  await _settle(1600);
  await _capture('/tmp/logo_compare.png');
  exit(0);
}

Widget _cell(String label, Widget child) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: 118, child: Center(child: child)),
        const SizedBox(height: 10),
        SizedBox(
          width: 118,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppUi.label.copyWith(fontSize: 9, letterSpacing: 1.0),
          ),
        ),
      ],
    );

final Stopwatch _clock = Stopwatch()..start();

/// Kareyi ELDE zorlar — macOS'ta pencere ön planda değilken motor kare üretmez
/// (bkz. menu_capture_main'deki aynı reçete).
Future<void> _settle(int ms) async {
  final steps = (ms / 16).ceil();
  for (int i = 0; i < steps; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final b = WidgetsBinding.instance;
    if (b.schedulerPhase == SchedulerPhase.idle) {
      b.handleBeginFrame(_clock.elapsed);
      b.handleDrawFrame();
    }
  }
}

Future<void> _capture(String path) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes');
    return;
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
