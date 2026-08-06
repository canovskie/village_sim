// Ana menü (MainMenuScreen) şafak sahnesi önizleme yakalama harness'ı.
// Menüyü render eder, animasyonlar otursun diye bekler, RepaintBoundary.toImage
// ile PNG'ye çeker. Tüm oyunu başlatmadan atmosferi görsel doğrulamak için.
//
// MOBIL=1 ile telefon (yatay, çentikli) çerçevesinde çeker — menü orada
// kaydırmasız 2 sütuna açılır, onu gözle doğrulamak için.
//
// Çalıştır:  flutter run -d macos -t lib/tools/menu_capture_main.dart
//            MOBIL=1 flutter run -d macos -t lib/tools/menu_capture_main.dart
// Çıktı:     /tmp/main_menu.png · /tmp/main_menu_mobile.png
import 'dart:io';
import 'package:flutter/material.dart';

import '../ui/app_ui.dart';
import '../ui/main_menu_screen.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

/// iPhone 15 yatay — mantıksal ölçü + çentik güvenli alanı.
const _phone = Size(852, 393);
const _phoneSafe = EdgeInsets.only(left: 59, right: 59, bottom: 21);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Pencere arka planda kalırsa vsync gelmez → giriş animasyonları 0'da donar
  // ve UI karede görünmez. Harness'te animasyonlar son karesiyle çizilir.
  AppUi.captureStatic = true;

  final mobile = Platform.environment['MOBIL'] == '1';

  const menu = MainMenuScreen(
    onNewGame: _noop,
    onContinue: _noopMeta,
    onReferenceVillage: _noop,
  );

  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    home: mobile
        ? ColoredBox(
            color: const Color(0xFF0B0C0E),
            child: Center(
              // FittedBox: pencere ne olursa olsun çerçeve TAM mantıksal
              // ölçüsünde layout olur (mobile_capture ile aynı hile).
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _phone.width,
                  height: _phone.height,
                  child: MediaQuery(
                    data: const MediaQueryData(
                      size: _phone,
                      devicePixelRatio: 3.0,
                      padding: _phoneSafe,
                      viewPadding: _phoneSafe,
                    ),
                    child: RepaintBoundary(key: _boundaryKey, child: menu),
                  ),
                ),
              ),
            ),
          )
        : RepaintBoundary(key: _boundaryKey, child: menu),
  ));

  await settleFrames(2600);
  await captureBoundary(_boundaryKey, mobile ? '/tmp/main_menu_mobile.png' : '/tmp/main_menu.png', pixelRatio: 2.0);
  exit(0);
}

void _noop() {}
void _noopMeta(Object _) {}



