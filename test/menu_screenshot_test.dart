import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/ui/main_menu_screen.dart';

// Gerçek fontlarla ana menüyü render edip PNG'ye basar — görsel doğrulama için.
// Çalıştır: flutter test test/menu_screenshot_test.dart
void main() {
  testWidgets('main menu screenshot', (tester) async {
    TestWidgetsFlutterBinding.ensureInitialized();

    for (final entry in {
      'Cinzel': ['assets/fonts/Cinzel-VF.ttf'],
      'Spectral': [
        'assets/fonts/Spectral-Regular.ttf',
        'assets/fonts/Spectral-Medium.ttf',
        'assets/fonts/Spectral-SemiBold.ttf',
        'assets/fonts/Spectral-Bold.ttf',
      ],
    }.entries) {
      final loader = FontLoader(entry.key);
      for (final path in entry.value) {
        loader.addFont(rootBundle.load(path));
      }
      await loader.load();
    }

    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    final key = GlobalKey();
    await tester.pumpWidget(
      RepaintBoundary(
        key: key,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: MainMenuScreen(onNewGame: () {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump(const Duration(milliseconds: 16));

    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('test/menu_screenshot.png');
    await file.writeAsBytes(bytes!.buffer.asUint8List());
    // ignore: avoid_print
    print('WROTE ${file.absolute.path}');
  });
}
