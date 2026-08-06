// İNŞAAT ŞEFFAFLIĞI + YOL ÖNİZLEMESİ doğrulama harness'ı.
//
// Üç kare yan yana çizer:
//   1. ÖNCESİ  — hiçbir hedef yok; öndeki bina arkasındaki şantiyeyi yutuyor.
//   2. SONRASI — aynı sahne, ama şantiye "reveal" hedefi → öndeki bina saydam.
//   3. YOL     — binanın arkasından geçen yol önizlemesi + öndeki bina saydam.
//
// Çalıştır:  flutter run -d macos -t lib/tools/reveal_capture_main.dart
// Çıktı:     /tmp/reveal.png
import 'dart:io';

import 'package:flutter/material.dart';

import '../buildings/building_entity.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../core/constants.dart';
import '../entities/build_order.dart';
import '../entities/road_order.dart';
import '../rendering/game_painter.dart';
import '../rendering/tile_renderer.dart';
import '../systems/road_route.dart';
import '../systems/road_system.dart';
import '../world/road_surface.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

// Sahne: ön planda büyük bir bina, onun ARKASINDA (kuzeybatısında) bir şantiye.
// İzometride "arka" = daha küçük (col,row) → ekranda yukarıda, önündeki bina
// tarafından örtülür.
const int _frontCol = 12, _frontRow = 12;
const int _backCol = 10, _backRow = 10;

BuildingEntity _front() =>
    BuildingEntity(type: BuildingType.townhall, col: _frontCol, row: _frontRow);

BuildOrder _backSite() =>
    BuildOrder(type: BuildingType.woodenHouse, col: _backCol, row: _backRow);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Bina/zemin PNG'leri yüklenmezse prosedürel "?" kutusu çizilir → örtme
  // testi anlamsızlaşır.
  await Future.wait([BuildingRenderer.loadAll(), TileRenderer.loadAll()]);
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: RepaintBoundary(
      key: _boundaryKey,
      child: const Scaffold(
        backgroundColor: Color(0xFF2A2E27),
        body: Row(
          children: [
            _Cell(title: 'ÖNCESİ — hedef yok', reveal: false, road: false),
            _Cell(title: 'SONRASI — şantiye hedefi', reveal: true, road: false),
            _Cell(title: 'YOL ÖNİZLEME', reveal: true, road: true),
          ],
        ),
      ),
    ),
  ));
  await Future<void>.delayed(const Duration(milliseconds: 800));
  await captureBoundary(_boundaryKey, '/tmp/reveal.png', pixelRatio: 2.0);
  exit(0);
}

/// Kamerayı sahnenin (12,12) civarına ortalar — gridToScreen'in ox/oy
/// tanımından geriye çözülür (bkz. core/constants.dart).
Offset _camera(BoxConstraints c) => Offset(
      0,
      c.maxHeight * 0.5 - c.maxHeight * 0.28 - 25 * kTileH / 2,
    );

class _Cell extends StatelessWidget {
  final String title;
  final bool reveal;
  final bool road;
  const _Cell({required this.title, required this.reveal, required this.road});

  @override
  Widget build(BuildContext context) {
    // Yolu binanın ARKASINDAN geçir (aynı bantta), böylece örtülme testi gerçek.
    final route = road ? roadRoute((6, 10), (13, 10)) : const <(int, int)>[];
    final preview = [for (final t in route) (t, true)];
    // Binanın ARKASINDAN geçen, yapımı süren yol emirleri — asıl örtülen şey
    // bunlar (önizleme zaten sahnenin üstünde çizilir).
    final orders = [
      for (final t in route)
        RoadOrder(col: t.$1, row: t.$2, surface: RoadSurface.stone)
          ..progress = 0.6,
    ];

    final targets = <(int, int)>{};
    if (reveal) {
      for (int c = _backCol; c < _backCol + 2; c++) {
        for (int r = _backRow; r < _backRow + 2; r++) {
          targets.add((c, r));
        }
      }
      for (final t in route) {
        targets.add(t);
      }
    }

    return Expanded(
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            color: const Color(0xFF14170F),
            child: Text(title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: Color(0xFFE8DCC0),
                    fontSize: 13,
                    fontWeight: FontWeight.bold)),
          ),
          Expanded(
            // CustomPaint varsayılan olarak KIRPMAZ — üç hücre birbirinin
            // üstüne çizerdi (yalnız sonuncusu görünürdü).
            child: ClipRect(
              child: LayoutBuilder(builder: (_, constraints) => CustomPaint(
              size: Size.infinite,
              painter: VillageGamePainter(
                villagers: const [],
                buildings: [_front()],
                pendingOrders: [_backSite()..progress = 0.45],
                roadSystem: RoadSystem(),
                pendingRoadOrders: road ? orders : const [],
                camera: _camera(constraints),
                roadPreview: preview,
                roadPreviewSurface: road ? RoadSurface.stone : null,
                roadPreviewVersion: road ? 1 : 0,
                revealTiles: targets,
                time: 4.0,
              ),
            )),
            ),
          ),
        ],
      ),
    );
  }
}

