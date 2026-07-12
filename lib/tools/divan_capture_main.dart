// Divan/Meclis önizleme harness'ı — yeniden tasarlanan Divan panelini + kalıcı
// Divan mührünü mock veriyle render edip PNG'ye çeker (tüm oyunu açmadan
// görsel iterasyon).
//
// Çalıştır:  flutter run -d macos -t lib/tools/divan_capture_main.dart
// Çıktı:     /tmp/divan.png   (DIVAN_READY=0 → meclis cooldown hâli)
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../systems/estate_system.dart';
import '../systems/house_system.dart';
import '../systems/petition_system.dart';
import '../ui/app_ui.dart';
import '../ui/divan_panel.dart';

final GlobalKey _key = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ready = (Platform.environment['DIVAN_READY'] ?? '1') != '0';

  const agenda = <DivanMatter>[
    DivanMatter(
      icon: '🥖',
      title: 'Ambar inceliyor',
      sub: 'Erzak azalıyor — köy bölüşüm kararı istemeden tedbir al.',
      pressure: 0.72,
      tone: PetitionTone.ominous,
      pending: true,
      graceProgress: 0.42,
    ),
    DivanMatter(
      icon: '🩸',
      title: 'Kan davası köyü zehirliyor',
      sub: 'İki aile arasında kan dökülüyor — sulh kararı yaklaşıyor.',
      pressure: 0.9,
      tone: PetitionTone.ominous,
      conveneId: 'feud',
    ),
    DivanMatter(
      icon: '⌂',
      title: 'Aksoy Hanesi küskün',
      sub: 'Gönülleri alınmazsa ısrarla gündeme gelecekler.',
      pressure: 0.55,
      tone: PetitionTone.solemn,
      conveneId: 'estate:Aksoy',
    ),
  ];

  const houses = <HouseSnapshot>[
    HouseSnapshot(
        surname: 'Demirhan',
        label: 'Demirhan Hanesi',
        mood: 0.78,
        swayShare: 0.44,
        ascendant: true,
        members: 6,
        tier: EstateMoodTier.content),
    HouseSnapshot(
        surname: 'Aksoy',
        label: 'Aksoy Hanesi',
        mood: 0.34,
        swayShare: 0.19,
        ascendant: false,
        members: 4,
        tier: EstateMoodTier.sullen),
    HouseSnapshot(
        surname: 'Yıldız',
        label: 'Yıldız Hanesi',
        mood: 0.60,
        swayShare: 0.22,
        ascendant: false,
        members: 3,
        tier: EstateMoodTier.neutral),
    HouseSnapshot(
        surname: 'Karaca',
        label: 'Karaca Hanesi',
        mood: 0.48,
        swayShare: 0.15,
        ascendant: false,
        members: 2,
        tier: EstateMoodTier.uneasy),
  ];

  final laws = <DivanFact>[
    const DivanFact('👨‍👩‍👧', 'Aile teşviki', AppUi.info),
    const DivanFact('🕯️', 'Kutsal gün', AppUi.info),
  ];
  final marks = <DivanFact>[
    const DivanFact('🌾', 'Tarlalara iyi bakıldı', AppUi.sage),
    const DivanFact('🤝', 'Komşuyla anlaşma', AppUi.sage),
  ];

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2A20), // sahne yerine sakin zemin
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Kalıcı mühür — oyundaki yeriyle aynı (sol üst).
            Positioned(
              left: 14,
              top: 92,
              child: DivanSeal(
                onTap: () {},
                agendaCount: agenda.length,
                pendingPetition: true,
                councilReady: ready,
              ),
            ),
            DivanPanel(
              identity: 'Demirhan Hanesi',
              identityBonus: '★ Bereketli Köy — tarlalar %15 gürbüz büyür',
              morale: 0.63,
              population: 24,
              food: 41,
              gold: 18,
              agenda: agenda,
              houses: houses,
              laws: laws,
              marks: marks,
              legacy: 0.09,
              onOpenPetition: () {},
              onConvene: (_) {},
              councilReady: ready,
              onClose: () {},
            ),
          ],
        ),
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 1600));
  await _capture('/tmp/divan${ready ? '' : '_cooldown'}.png');
  exit(0);
}

Future<void> _capture(String path) async {
  final ctx = _key.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL');
    return;
  }
  final b = ctx.findRenderObject() as RenderRepaintBoundary;
  final img = await b.toImage(pixelRatio: 2.0);
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
