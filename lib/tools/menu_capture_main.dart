// Ana menü (MainMenuScreen) şafak sahnesi önizleme yakalama harness'ı.
// Menüyü render eder, animasyonlar otursun diye bekler, RepaintBoundary.toImage
// ile PNG'ye çeker. Tüm oyunu başlatmadan atmosferi görsel doğrulamak için.
//
// Çalıştır:  flutter run -d macos -t lib/tools/menu_capture_main.dart
// Çıktı:     /tmp/main_menu.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../ui/main_menu_screen.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: MainMenuScreen(
        onNewGame: () {},
        onContinue: (_) {},
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 2600));
  await _capture('/tmp/main_menu.png');
  exit(0);
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
