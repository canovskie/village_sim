// KURULUŞUN İLK DAKİKASI — yönlendirme gerçekten yol gösteriyor mu?
//
// Taze bir köy kurar (kurucu kadro + hiçbir bina yok), birkaç saniye sim
// akıtır ve kareyi PNG'ye çeker. Bakılacak şey: oyuncu ekrana ilk baktığında
// NE YAPACAĞINI anlıyor mu — sağdaki tek görev kartı ile bir kerelik rehber
// aynı hedefe mi bakıyor; kalıcı tekrar eden panel var mı.
//
// Çalıştır:  OUT=/tmp/onboard.png flutter run -d macos -t lib/tools/onboarding_capture_main.dart
import 'dart:io';
import 'package:flutter/material.dart';
import '../main.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  kCaptureMode = true; // açılış sinematiğini atla
  // Sabah: ilk adım gündüz okunmalı (gece işareti ayrı bir sınav).
  kCaptureTimeOfDay = 0.35;
  kCaptureZoom = 0.95; // kurucular ve çevresi kadraja girsin

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const VillageScene(), // taze köy — kuruluş baştan
    ),
  ));

  var waited = 0;
  while (!kCaptureSceneReady && waited < 400) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    waited++;
  }
  // Akış taraması (0.5 sn) birkaç kez dönsün ki adım + rehber otursun.
  // 8 sn: kuruluş açılışı SIRALI — önce kurucunun repliği (~5 sn), sonra
  // öğretici spot. 4 sn'de kare çekmek spotu hiç görmeden "yok" demekti.
  await Future<void>.delayed(const Duration(seconds: 8));
  // TEŞHİS: kare çekilmeden önce akışın nabzını bas. Rehber bazen
  // yoksa tek soru bu — tarama koştu mu, koştuysa ne buldu?
  stdout.writeln('FLOW: $kFlowDebug');
  await captureBoundary(_boundaryKey, Platform.environment['OUT'] ?? '/tmp/onboard.png', pixelRatio: 1.5);
  exit(0);
}
