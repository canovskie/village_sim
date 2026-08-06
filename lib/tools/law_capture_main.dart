// Kanunname önizleme harness'ı — yasa defterini ve MÜHÜR RİTÜELİNİ mock veriyle
// render edip PNG'ye çeker (tüm oyunu açmadan görsel iterasyon).
//
// Çalıştır:  flutter run -d macos -t lib/tools/law_capture_main.dart
// Çıktı:     /tmp/law_<mod>.png
//
//   LAW_MODE=ritual  (varsayılan) → mühür ritüeli: dört zümre masada
//   LAW_MODE=book                 → defter, DAVA kolları görünür yerden
//
//   LAW_ID=<ferman id>  → ritüelde hangi ferman (varsayılan: nizam.watch)
//   LAW_PATH=nizam      → book modunda girilmiş dava kolu (öbürü kapanır)
import 'dart:io';

import 'package:flutter/material.dart';

import '../systems/law_book.dart';
import '../ui/app_ui.dart';
import '../ui/law_book_panel.dart';
import 'capture_support.dart';
import 'law_demo_ctx.dart';

final GlobalKey _key = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final env = Platform.environment;
  final mode = env['LAW_MODE'] ?? 'ritual';
  final law = LawBook.byId(env['LAW_ID'] ?? 'nizam.watch') ?? kLawBook.first;

  // Defter durumu env'den (LAW_SEALED=a,b,c). Boş = bomboş yeni köy.
  final rawSealed = env['LAW_SEALED'];
  final sealed = rawSealed != null
      ? rawSealed.split(',').map((s) => s.trim()).where((s) => s.isNotEmpty).toSet()
      : <String>{
          'neighborliness',
          'winterFodder',
          'sharedHarvest',
          'nizam.watch',
        };

  // Köyün hâli — dünya kapıları buradan okunur. Taban: her kapıyı açan olgun
  // köy (yoksa defter neredeyse boş çıkar); nüfus/gün env ile ezilebilir —
  // LAW_POP=5 LAW_DAY=2 vererek ağır hükümlerin KİLİTLİ hâli de yakalanır.
  final ctx = LawContext(
    population: int.tryParse(env['LAW_POP'] ?? '') ?? kDemoLawContext.population,
    dayCount: int.tryParse(env['LAW_DAY'] ?? '') ?? kDemoLawContext.dayCount,
    villageMorale: kDemoLawContext.villageMorale,
    households: kDemoLawContext.households,
    children: kDemoLawContext.children,
    elders: kDemoLawContext.elders,
    farmTiles: kDemoLawContext.farmTiles,
    animals: kDemoLawContext.animals,
    deaths: kDemoLawContext.deaths,
    crimesSeen: kDemoLawContext.crimesSeen,
    knownCrafts: kDemoLawContext.knownCrafts,
    buildings: kDemoLawContext.buildings,
  );
  // Köyün sesi — mühürlenmemiş, ucuz/geçim bir yasa (spotlight testi).
  final spot = env['LAW_SPOT'] ?? 'irrigation';

  final Widget body = mode == 'book'
      ? Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: AppGildedFrame(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: LawBookView(
                    sealed: sealed,
                    ctx: ctx,
                    spotlightId: spot,
                    inkDrySec: 0,
                    inkDryTotalSec: 240,
                    onOpenLaw: (_) {},
                  ),
                ),
              ),
            ),
          ),
        )
      : LawSealRitual(
          law: law,
          onSeal: () {},
          onDismiss: () {},
        );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        backgroundColor: const Color(0xFF1A2A20),
        body: Stack(fit: StackFit.expand, children: [body]),
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 1600));
  await captureBoundary(_key, '/tmp/law_$mode.png', pixelRatio: 2.0);
  exit(0);
}

