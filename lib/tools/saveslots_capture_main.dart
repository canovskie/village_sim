// Kayıtlı Köyler paneli önizleme harness'ı — sahte slot listesiyle render edip
// PNG'ye çeker (gerçek kayıtlara DOKUNMAZ; panelin `loader` dikişi kullanılır).
//
// Çalıştır:  flutter run -d macos -t lib/tools/saveslots_capture_main.dart
// SLOTS=0 → boş durum ekranı.
import 'dart:io';
import 'package:flutter/material.dart';

import '../save/save_manager.dart';
import '../ui/save_slots_screen.dart';
import 'capture_support.dart';

final GlobalKey _key = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError =
      (d) => stdout.writeln('FLUTTER_ERROR: ${d.exceptionAsString()}');

  final empty = (Platform.environment['SLOTS'] ?? '3') == '0';
  final now = DateTime.now();
  final fake = <SaveSlotMeta>[
    SaveSlotMeta(
        id: '1',
        name: 'Bahçeköy',
        savedAt: now.subtract(const Duration(minutes: 4)),
        day: 41,
        population: 24,
        identity: 'Demirhan Hanesi'),
    SaveSlotMeta(
        id: '2',
        name: 'Yeşilpınar',
        savedAt: now.subtract(const Duration(hours: 6)),
        day: 12,
        population: 9,
        identity: 'Dengeli Köy'),
    SaveSlotMeta(
        id: '3',
        name: 'Taşocağı',
        savedAt: now.subtract(const Duration(days: 3)),
        day: 77,
        population: 38,
        identity: 'Aksoy Hanesi'),
  ];

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        // Ana menünün şafak sahnesinin yerine sıcak bir zemin (panel scrim'inin
        // arkadan sahneyi geçirdiğini görmek için).
        backgroundColor: const Color(0xFF3C2A46),
        body: Stack(
          fit: StackFit.expand,
          children: [
            SaveSlotsPanel(
              onClose: () {},
              onContinue: (_) {},
              loader: () async => empty ? <SaveSlotMeta>[] : fake,
            ),
          ],
        ),
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 1600));
  await captureBoundary(_key, '/tmp/saveslots${empty ? '_empty' : ''}.png', pixelRatio: 2.0);
  exit(0);
}

