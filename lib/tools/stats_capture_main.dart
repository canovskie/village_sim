// Nüfus Defteri (VillagerStatsPanel) önizleme yakalama harness'ı — paneli mock
// köylü/hane verisiyle render eder ve RepaintBoundary.toImage ile PNG'ye çeker.
// Tüm oyunu çalıştırmadan layout'u (taşma/boyut/renk) görsel doğrulamak için.
//
// Çalıştır:  flutter run -d macos -t lib/tools/stats_capture_main.dart
// Çıktı:     /tmp/stats_panel.png
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../systems/estate_system.dart';
import '../systems/house_system.dart';
import '../ui/villager_stats_panel.dart';

final GlobalKey _boundaryKey = GlobalKey();

VillagerEntity _mk(String name, String surname, VillagerType type,
    {double wealth = 40, double morale = 0.6, bool fav = false, double age = 4}) {
  final v = VillagerEntity(
    type: type,
    name: name,
    surname: surname,
    male: name.hashCode.isEven,
    startCol: 0,
    startRow: 0,
    ageDays: age,
  );
  v.wealth = wealth;
  v.morale = morale;
  v.isFavorite = fav;
  return v;
}

int _tierFor(double w) => w > 120
    ? 4
    : w > 80
        ? 3
        : w > 45
            ? 2
            : w > 20
                ? 1
                : 0;
String _labelFor(int t) => switch (t) {
      4 => 'Konak',
      3 => 'Taş Ev',
      2 => 'Ahşap Ev',
      1 => 'Çadır',
      _ => 'Evsiz',
    };

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const surnames = ['Demirhan', 'Aksoy', 'Yıldız', 'Karaca', 'Şahin', 'Kaya', 'Doğan'];
  const names = ['Ayşe', 'Kemal', 'Zeynep', 'Veli', 'Hatice', 'Murat', 'Elif',
    'Osman', 'Leyla', 'Can', 'Deniz', 'Emre', 'Selin', 'Baran', 'Nur', 'Kaan'];
  final types = VillagerType.values;
  final villagers = [
    for (int i = 0; i < 40; i++)
      _mk(names[i % names.length], surnames[i % surnames.length],
          types[i % types.length],
          wealth: (i * 37 % 160).toDouble(),
          morale: (i * 13 % 100) / 100.0,
          fav: i % 7 == 0),
  ];

  final rows = [
    for (final v in villagers)
      () {
        final t = _tierFor(v.wealth);
        return VillagerStatRow(v, _labelFor(t), t);
      }(),
  ];

  final houses = <HouseSnapshot>[
    const HouseSnapshot(
        surname: 'Demirhan',
        label: 'Demirhan Hanesi',
        mood: 0.78,
        swayShare: 0.44,
        ascendant: true,
        members: 4,
        tier: EstateMoodTier.content),
    const HouseSnapshot(
        surname: 'Aksoy',
        label: 'Aksoy Hanesi',
        mood: 0.36,
        swayShare: 0.19,
        ascendant: false,
        members: 2,
        tier: EstateMoodTier.uneasy),
    const HouseSnapshot(
        surname: 'Yıldız',
        label: 'Yıldız Hanesi',
        mood: 0.6,
        swayShare: 0.22,
        ascendant: false,
        members: 2,
        tier: EstateMoodTier.neutral),
    const HouseSnapshot(
        surname: 'Karaca',
        label: 'Karaca Hanesi',
        mood: 0.3,
        swayShare: 0.15,
        ascendant: false,
        members: 2,
        tier: EstateMoodTier.sullen),
  ];

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: Scaffold(
        backgroundColor: const Color(0xFF14171B),
        body: Stack(
          children: [
            VillagerStatsPanel(
              rows: rows,
              houses: houses,
              onClose: () {},
              onSelect: (_) {},
              initialTab: int.tryParse(
                      Platform.environment['STATS_TAB'] ?? '0') ??
                  0,
            ),
          ],
        ),
      ),
    ),
  ));

  // Reveal + bar animasyonları + portre layout'u otursun (çok köylüde ilk kare
  // yavaş → geç yakala).
  final tab = Platform.environment['STATS_TAB'] ?? '0';
  await Future<void>.delayed(const Duration(milliseconds: 2200));
  await _capture('/tmp/stats_panel_$tab.png');
  exit(0);
}

Future<void> _capture(String path) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: no context');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 2.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) {
    stdout.writeln('CAPTURE_FAIL: no bytes');
    return;
  }
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
