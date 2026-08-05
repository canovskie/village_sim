// HIZLI ana menü önizlemesi — native derleme YOK.
//
// `flutter run -d macos -t lib/tools/menu_capture_main.dart` her kare için tam
// bir macOS derlemesi demek (dakikalar). Bu dosya aynı kareyi test koşucusunda
// üretir (saniyeler), çünkü widget testi native uygulama derlemez.
//
// Çalıştır:  flutter test test/menu_preview_dump.dart
// Çıktı:     /tmp/menu_fast.png
//
// UYARI: yazılım rasterleştirici; blur/gradyan gerçek GPU karesinden ÇOK az
// farklı çıkabilir. Kompozisyon/renk/ölçek incelemek için birebir yeterli,
// son onayı yine menu_capture_main ile al.
//
// Dosya adı kasten `_test.dart` ile bitmiyor: normal `flutter test` taramasına
// takılmasın, sadece elle çağrılsın.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/ui/app_ui.dart';
import 'package:village_sim/ui/main_menu_screen.dart';

/// Masaüstü kadraj + telefon (yatay) kadraj.
const _shots = <String, Size>{
  '/tmp/menu_fast.png': Size(1792, 1120),
  '/tmp/menu_fast_mobile.png': Size(852, 393),
};

void main() {
  testWidgets('ana menü önizleme karesi', (tester) async {
    AppUi.captureStatic = true;
    MainMenuScreen.debugSavesOverride = true;

    final key = GlobalKey();

    for (final entry in _shots.entries) {
      tester.view.physicalSize = entry.value * 2.0;
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          home: RepaintBoundary(
            key: key,
            child: MainMenuScreen(
              onNewGame: () {},
              onContinue: (_) {},
              onReferenceVillage: () {},
            ),
          ),
        ),
      );

      // Giriş animasyonları otursun (captureStatic zaten son kareyi çizer).
      await tester.pump(const Duration(milliseconds: 600));
      await tester.pump(const Duration(milliseconds: 600));

      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      late final ui.Image image;
      await tester.runAsync(() async {
        image = await boundary.toImage(pixelRatio: 1.0);
      });
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      File(entry.key).writeAsBytesSync(bytes!.buffer.asUint8List());
      // ignore: avoid_print
      print('DUMPED: ${entry.key}');
    }
  });
}
