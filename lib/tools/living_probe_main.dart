// YAŞAYAN KÖY PROVASI — hızlandırılmış simülasyonu çalıştırıp köyün DAVRANIŞINI
// stdout'a akıtan harness. "Tek tek NPC izleyemem" sorununun cevabı: köyün dört
// fazının (Faz 0 yasa→hâl, Faz 1 akıl/niyet, Faz 2 algı/hafıza/dedikodu/ihbar,
// Faz 3 eylem/nesne) uçtan uca çalıştığı bir köylüye bakmadan, akan raporla
// görülür.
//
// Çalıştır:
//   flutter run -d macos -t lib/tools/living_probe_main.dart
//
// Ne yapar:
//   • Referans köyü kurar (sabit tohum → her koşu aynı zemin).
//   • Simülasyonu ~20× hızlandırır.
//   • Her yarım oyun günü köyün davranış özetini basar.
//   • Birkaç günde bir suç tetikler → tanık/dedikodu/ihbar zincirini gözlet.
//   • ~12 oyun günü sonra kısa bir DEĞERLENDİRME basıp çıkar.
//
// Pencere-capture DEĞİL — macOS izni gerekmez, tamamen stdout.

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../main.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Açılış sinematiğini atla, sahne doğrudan aksın; prova telemetrisini aç.
  kCaptureMode = true;
  kProbeOn = true;
  kMindTelemetryOn = true;

  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: _ProbeHost(),
  ));
}

/// Referans köyü kuran ve simülasyonu hızlandıran host. Sahnenin kendi ticker'ı
/// simülasyonu sürer; biz yalnız hız boost'unu ayarlar ve stdout'a rapor
/// pompalarız (raporu sahne yazar, biz sıra numarası değişince basarız).
class _ProbeHost extends StatefulWidget {
  const _ProbeHost();
  @override
  State<_ProbeHost> createState() => _ProbeHostState();
}

class _ProbeHostState extends State<_ProbeHost> {
  int _lastSeq = -1;
  int _reports = 0;
  Timer? _poll;
  bool _crimeArmed = false;

  @override
  void initState() {
    super.initState();
    _poll = Timer.periodic(const Duration(milliseconds: 120), (_) => _pump());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  void _pump() {
    // Yeni rapor geldiyse bas.
    if (kProbeReportSeq != _lastSeq && kProbeReport.isNotEmpty) {
      _lastSeq = kProbeReportSeq;
      _reports++;
      stdout.writeln(kProbeReport);

      // İkinci rapordan itibaren üç raporda bir suç tetikle — köy oturduktan
      // sonra tanık zinciri gözlensin.
      if (_reports >= 2 && _reports % 3 == 0 && !_crimeArmed) {
        _crimeArmed = true;
        kProbeTriggerCrime = true;
        stdout.writeln('  ↪ [prova] suç tetiklendi — tanık/dedikodu/ihbar '
            'zincirini izle');
      } else {
        _crimeArmed = false;
      }

      // ~12 oyun günü = 24 rapor sonra değerlendirip çık.
      if (_reports >= 24) {
        _verdict();
        exit(0);
      }
    }
  }

  void _verdict() {
    stdout.writeln('');
    stdout.writeln('═══ DEĞERLENDİRME ═══');
    stdout.writeln('Kat edilen toplam yol: '
        '${kMindDistance.toStringAsFixed(0)} tile '
        '(0 ise köy DONMUŞ)');
    stdout.writeln('Farklı niyet sayısı: $kMindDistinctIntents '
        '(1 ise herkes aynı şeyi yapıyor — kötü)');
    stdout.writeln('En eski niyet yaşı: '
        '${kMindOldestIntent.toStringAsFixed(0)} sn '
        '(çok büyükse bir niyet kilitlenmiş)');
    stdout.writeln('Beklenen: yol > 0, niyet > 1, kilitlenme yok.');
  }

  @override
  Widget build(BuildContext context) {
    // Sahneyi kur — kendi ticker'ı simülasyonu sürer. Görünmez tutmaya gerek
    // yok; asıl çıktı stdout.
    return const _SpeedBoostScene();
  }
}

/// Referans köyü kuran + hızlandıran sahne sarmalayıcı.
class _SpeedBoostScene extends StatefulWidget {
  const _SpeedBoostScene();
  @override
  State<_SpeedBoostScene> createState() => _SpeedBoostSceneState();
}

class _SpeedBoostSceneState extends State<_SpeedBoostScene> {
  @override
  void initState() {
    super.initState();
    // Sahne kurulduktan sonra hız boost'unu yükselt (referans köy asset'leri
    // yüklenip kurulum bitince devreye girsin diye kısa gecikme).
    Future.delayed(const Duration(seconds: 2), _boost);
  }

  void _boost() {
    kDevSpeedBoostOverride = 20.0;
  }

  @override
  Widget build(BuildContext context) {
    return const VillageScene(
      referenceVillage: true,
      slotId: 'probe',
      slotName: 'Prova',
    );
  }
}
