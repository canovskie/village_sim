// Yaşayan köy yakalama harness'ı — showcase köyü (binalar + sürü + meslekler +
// köylüler) kurar, birkaç saniye simülasyon aksın ki köylüler dağılıp işe
// koyulsun, sonra RepaintBoundary.toImage ile PNG'ye çeker. Tanıtım sunumu için
// "yaşayan köy" money-shot'ı. Pencere-capture DEĞİL → macOS izni gerekmez.
//
// Çalıştır:  flutter run -d macos -t lib/tools/living_capture_main.dart
// Çıktı:     /tmp/village_living.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import '../main.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;      // açılış sinematiğini atla
  kCaptureShowcase = true;  // dolu köy: binalar, depo, ağıl, sürü, muhafız, meslekler
  kCaptureZoom = 0.62;      // köyün bütünü kadraja girsin (asset hazır olunca çeker)
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(),
    ),
  ));

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  // Köylüler evlerinden çıkıp işe/dağılsın diye birkaç saniye sim aksın.
  await Future<void>.delayed(const Duration(seconds: 6));
  await _capture();
  exit(0);
}

Future<void> _capture() async {
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
  const path = '/tmp/village_living.png';
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
