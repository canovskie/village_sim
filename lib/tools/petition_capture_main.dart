// Dilekçe modalı önizleme harness'ı — yeni birinci-ağızdan metinleri GERÇEK
// modalda, gerçek fontlarla render edip PNG'ye çeker (taşma/uzunluk kontrolü).
//
// Çalıştır:  flutter run -d macos -t lib/tools/petition_capture_main.dart
// Çıktı:     /tmp/petitions.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../systems/estate_system.dart';
import '../systems/petition_system.dart';
import '../text/voice.dart';
import '../ui/petition_modal.dart';
import '../world/season.dart';

final GlobalKey _key = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(key: _key, child: const _Wall()),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 2200));
  final b = _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 1.2);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  await File('/tmp/petitions.png').writeAsBytes(bytes!.buffer.asUint8List());
  stdout.writeln('saved /tmp/petitions.png');
  exit(0);
}

/// En uzun gövdeli 3 dilekçeyi yan yana — taşarsa burada görünür.
class _Wall extends StatelessWidget {
  const _Wall();

  @override
  Widget build(BuildContext context) {
    const ctx = VoiceCtx(
      seed: 5,
      name: 'İlyas',
      other: 'Ayşe',
      profession: 'Demirci',
      house: 'Karaoğlan',
      estate: 'Emekçiler',
      village: 'Bahçeköy',
      season: Season.winter,
      day: 41,
    );
    // Yargı yer tutucularını (suçlu/suç) dolduran bağlam.
    const verdictCtx = VoiceCtx(
      seed: 5,
      name: 'İlyas',
      village: 'Bahçeköy',
      season: Season.winter,
      day: 41,
      extra: {'suçlu': 'Süleyman', 'suç': 'iftira', 'hal': 'son anda önlendi', 'sabıka': 'İlk kez.'},
    );
    // Yargı (5 seçenek: kürek dahil) + 2 seçenekli bir dilekçe + en uzun gövde.
    // Yatay kart şeridinin hem az hem çok seçenekte nasıl durduğunu gösterir.
    final verdict = PetitionSystem.byId('crimeVerdict');
    final picked = <Petition>[
      if (verdict != null)
        verdict.withExtraOption(const PetitionOption(
          label: 'Kürek cezasına yolla',
          detail: '{suçlu} zindana atılır, taş ocağında çalıştırılır. Köy taş '
              'kazanır; bir el de eksilmez.',
          resolutionPool: ['⛓ {suçlu} taş ocağına koşuldu.'],
          moraleAmount: 0.02,
          moraleDays: 3,
          fx: PetitionFx.crimeLabor,
          estateMood: [(Estate.laborers, 0.06), (Estate.faithful, -0.08)],
        )).spoken(verdictCtx),
      ...(PetitionSystem.allForTest.map((p) => p.spoken(ctx)).toList()
            ..sort((a, b) => b.options.length.compareTo(a.options.length)))
          .where((p) => p.id != 'crimeVerdict')
          .take(2),
    ];

    // PET_ONE=<index> → tek modalı geniş+üstten hizalı göster (kart detayı için).
    final oneStr = const String.fromEnvironment('PET_ONE', defaultValue: '');
    final one = int.tryParse(oneStr);
    if (one != null && one < picked.length) {
      return Scaffold(
        backgroundColor: const Color(0xFF14171C),
        body: Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 560,
            height: 900,
            child: PetitionModal(
              petition: picked[one],
              state: (morale: 0.41, population: 5, food: 0, gold: 0),
              onChoose: (_) {},
              onDismiss: () {},
            ),
          ),
        ),
      );
    }
    return Scaffold(
      backgroundColor: const Color(0xFF14171C),
      body: Row(
        children: [
          for (final p in picked)
            Expanded(
              // SizedBox ŞART: PetitionModal AppReveal kullanır; sınırsız
              // yükseklikte (SizedBox'sız) opacity 0'da takılıp görünmez kalır.
              child: SizedBox(
                height: 900,
                child: PetitionModal(
                  petition: p,
                  state: (morale: 0.41, population: 5, food: 0, gold: 0),
                  onChoose: (_) {},
                  onDismiss: () {},
                ),
              ),
            ),
        ],
      ),
    );
  }
}
