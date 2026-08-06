// Yaşayan köy yakalama harness'ı — showcase köyü (binalar + sürü + meslekler +
// köylüler) kurar, birkaç saniye simülasyon aksın ki köylüler dağılıp işe
// koyulsun, sonra RepaintBoundary.toImage ile PNG'ye çeker. Tanıtım sunumu için
// "yaşayan köy" money-shot'ı. Pencere-capture DEĞİL → macOS izni gerekmez.
//
// Çalıştır:  flutter run -d macos -t lib/tools/living_capture_main.dart
// Çıktı:     /tmp/village_living.png
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import 'capture_support.dart';

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
  await captureBoundary(_boundaryKey, '/tmp/village_living.png', pixelRatio: 1.5);
  exit(0);
}

