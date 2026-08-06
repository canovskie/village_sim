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
import 'package:flutter/material.dart';
import '../main.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true;
  // Gece 0.92 — dev konsolun 'night' değeriyle aynı. Karanlık tam oturmuş,
  // bütün ışık katmanları (cutout + warm wash + halo) devrede.
  // Vakit ve zoom dışarıdan ayarlanabilir: aynı harness hem gece ışık
  // karşılaştırması hem de gündüz "geniş plan" (ufuk/su yüzeyi) incelemesi
  // için kullanılır.
  kCaptureTimeOfDay =
      double.tryParse(Platform.environment['TOD'] ?? '') ?? 0.92;
  kCaptureZoom = double.tryParse(Platform.environment['ZOOM'] ?? '') ?? 0.85;

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
  await captureBoundary(_boundaryKey, Platform.environment['OUT'] ?? '/tmp/village_night.png', pixelRatio: 1.5);
  exit(0);
}

