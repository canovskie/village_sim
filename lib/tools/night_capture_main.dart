// GECE KARESİ — ışıklandırma katmanının "önce/sonra" kanıtı.
//
// game_painter'ın gece pass'i KİLİTLİ ([[feedback-lighting-locked]]): perf
// için dokunulacaksa görüntünün DEĞİŞMEDİĞİ gösterilmeli. Bu harness aynı
// köyü, aynı saatte, aynı kadrajda çeker → iki PNG piksel piksel
// karşılaştırılabilir.
//
// Determinizm şartları (üçü de gerekli, biri eksikse kareler kıyaslanamaz):
//   • sabit tohumlu referans köy       → aynı bina/ışık yerleşimi
//   • kCaptureTimeOfDay ile donmuş saat → aynı karanlık + aynı ışık şiddeti
//   • sabit zoom                        → aynı kadraj
//
// Çalıştır:  OUT=/tmp/night_before.png flutter run -d macos -t lib/tools/night_capture_main.dart
// Çıktı:     $OUT (varsayılan /tmp/village_night.png)
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;
  // Gece 0.92 — dev konsolun 'night' değeriyle aynı. Karanlık tam oturmuş,
  // bütün ışık katmanları (cutout + warm wash + halo) devrede.
  kCaptureTimeOfDay = 0.92;
  kCaptureZoom = 0.85;

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      // Referans köy: sabit tohum → iki koşuda birebir aynı yerleşim.
      child: const VillageScene(referenceVillage: true, slotId: 'nightshot'),
    ),
  ));

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  // Meşaleler yansın, köylüler yerleşsin.
  await Future<void>.delayed(const Duration(seconds: 4));
  await _capture(Platform.environment['OUT'] ?? '/tmp/village_night.png');
  exit(0);
}

Future<void> _capture(String path) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes');
    return;
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
