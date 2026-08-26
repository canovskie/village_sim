// Aynı bina türünün görsel tasarım havuzunu tek karede karşılaştırır.
//
// Çalıştır:
//   flutter run -d macos -t lib/tools/building_design_capture_main.dart
// Çıktı:
//   /tmp/building_designs.png
import 'dart:io';

import 'package:flutter/material.dart';

import '../buildings/building_design.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../ui/app_ui.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await BuildingRenderer.loadAll();
  AppUi.captureStatic = true;
  runApp(const _DesignCaptureApp());
  await settleFrames(900);
  await captureBoundary(
    _boundaryKey,
    '/tmp/building_designs.png',
    pixelRatio: 2,
  );
  exit(0);
}

class _DesignCaptureApp extends StatelessWidget {
  const _DesignCaptureApp();

  @override
  Widget build(BuildContext context) {
    final designs = buildingDesignsFor(BuildingType.woodenHouse);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: RepaintBoundary(
        key: _boundaryKey,
        child: ColoredBox(
          color: const Color(0xFF0C1010),
          child: Center(
            child: SizedBox(
              width: 760,
              height: 560,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 22),
                  Text(
                    'AHŞAP EV · TASARIM HAVUZU',
                    textAlign: TextAlign.center,
                    style: AppUi.title.copyWith(color: AppUi.gold),
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: GridView.builder(
                      physics: const NeverScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 1.45,
                          ),
                      itemCount: designs.length,
                      itemBuilder: (_, i) => _DesignCard(design: designs[i]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesignCard extends StatelessWidget {
  final BuildingDesign design;
  const _DesignCard({required this.design});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF1C2222), Color(0xFF101414)],
        ),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: CustomPaint(painter: _BuildingDesignPainter(design))),
          Container(height: 1, color: AppUi.line),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              design.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: AppUi.label.copyWith(color: AppUi.textMid),
            ),
          ),
        ],
      ),
    );
  }
}

class _BuildingDesignPainter extends CustomPainter {
  final BuildingDesign design;
  const _BuildingDesignPainter(this.design);

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final frontY = size.height - 8;
    // Kart yüksekliği genişliğinden kısa; gerçek oyundaki footprint ölçeğini
    // burada birebir kullanırsak çatı bir üst kartın başlığına taşar. Dört
    // silueti aynı rahat çerçevede karşılaştıracak kadar küçült.
    final halfW = size.width * 0.27;
    BuildingRenderer.draw(
      canvas,
      BuildingType.woodenHouse,
      Offset(cx, frontY - 54),
      Offset(cx - halfW, frontY - 27),
      Offset(cx + halfW, frontY - 27),
      Offset(cx, frontY),
      design: design,
      dayLight: 1,
      perfMode: true,
    );
  }

  @override
  bool shouldRepaint(covariant _BuildingDesignPainter oldDelegate) =>
      oldDelegate.design != design;
}
