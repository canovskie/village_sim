// Politik pusula önizleme harness'ı — kadranı DÖRT farklı köy hâlinde + mühür
// ritüelindeki "ibre nereye kayacak" önizlemesiyle render edip PNG'ye çeker.
//
// Çalıştır:  flutter run -d macos -t lib/tools/compass_capture_main.dart
// Çıktı:     /tmp/compass.png
import 'dart:io';
import 'package:flutter/material.dart';

import '../ui/app_ui.dart';
import '../ui/law_compass_view.dart';
import 'capture_support.dart';

final GlobalKey _key = GlobalKey();

/// Dört tipik defter — pusulanın her köşesini bir kez görelim.
const _cases = <(String, Set<String>)>[
  ('Yeni köy (defter ince)', {'neighborliness'}),
  (
    'İmececi çiftçi köyü',
    {'sharedHarvest', 'winterFodder', 'irrigation', 'eldersExemptFromFood'}
  ),
  (
    'Açık pazar kasabası',
    {'hospitality', 'freeRange', 'apprenticeship', 'nizam.registry'}
  ),
  (
    'Dinî mutlakiyet',
    {'dergah.oneFaith', 'dergah.penance', 'nizam.registry', 'nizam.sole'}
  ),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Görsel hata (border assert vb.) sessizce yutulmasın — panel "çizilmedi"
  // hatalarının çoğu burada yakalanır.
  FlutterError.onError = (d) => stdout.writeln('FLUTTER_ERROR: ${d.exception}');

  // Pencere tek ekrana sığmıyor (kaydırma capture'a girmez) — iki sayfa:
  // COMPASS_PAGE=0 ilk iki köy, 1 son iki köy + ritüel önizlemeleri.
  final page = int.tryParse(Platform.environment['COMPASS_PAGE'] ?? '0') ?? 0;
  final cases = page == 0 ? _cases.take(2) : _cases.skip(2);

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _key,
      child: Scaffold(
        backgroundColor: AppUi.surface1,
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final (label, sealed) in cases) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(label.toUpperCase(),
                          style: AppUi.label.copyWith(
                              fontSize: 8,
                              color: AppUi.textLo,
                              letterSpacing: 1.4)),
                    ),
                    LawCompassCard(sealed: sealed, totalLaws: 30),
                    const SizedBox(height: 16),
                  ],
                  if (page != 0) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('RİTÜEL ÖNİZLEMESİ (kimlik değiştiren mühür)',
                          style: AppUi.label.copyWith(
                              fontSize: 8,
                              color: AppUi.textLo,
                              letterSpacing: 1.4)),
                    ),
                    const LawCompassNudge(
                      sealed: {'sharedHarvest', 'winterFodder', 'irrigation'},
                      lawId: 'nizam.sole',
                    ),
                    const SizedBox(height: 12),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text('RİTÜEL ÖNİZLEMESİ (kimlik değiştirmeyen)',
                          style: AppUi.label.copyWith(
                              fontSize: 8,
                              color: AppUi.textLo,
                              letterSpacing: 1.4)),
                    ),
                    const LawCompassNudge(
                      sealed: {'sharedHarvest', 'winterFodder'},
                      lawId: 'dergah.lodge',
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  ));

  await Future<void>.delayed(const Duration(milliseconds: 1400));
  await captureBoundary(_key, '/tmp/compass_p$page.png', pixelRatio: 2.0);
  exit(0);
}

