// Ana menüyü BİRDEN ÇOK cihaz ölçüsünde arka arkaya çeken harness.
// "Her ekranda kaydırmasız sığıyor mu?" sorusunun görsel kanıtı.
//
// Çalıştır:  flutter run -d macos -t lib/tools/menu_sizes_capture_main.dart
// Çıktı:     /tmp/menu_<ad>.png
import 'dart:io';

import 'package:flutter/material.dart';

import '../ui/app_ui.dart';
import '../ui/main_menu_screen.dart';
import '../ui/mobile_ui.dart';
import 'capture_support.dart';

final GlobalKey _boundaryKey = GlobalKey();

class _Device {
  final String name;
  final Size size;
  final EdgeInsets safe;
  const _Device(this.name, this.size, [this.safe = EdgeInsets.zero]);
}

const _devices = <_Device>[
  _Device('phone_small', Size(667, 375)),
  _Device(
    'phone_15',
    Size(852, 393),
    EdgeInsets.only(left: 59, right: 59, bottom: 21),
  ),
  _Device(
    'phone_max',
    Size(932, 430),
    EdgeInsets.only(left: 59, right: 59, bottom: 21),
  ),
  _Device('ipad', Size(1180, 820), EdgeInsets.only(bottom: 20)),
  _Device('tablet_android', Size(1280, 800)),
  _Device('ipad_mini', Size(1024, 768)),
];

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppUi.captureStatic = true;
  // macOS'ta tablet TAKLİT ediliyor — gerçek cihazdaki dokunma yerleşimini
  // görebilmek için zorla (bkz. useTouchUi).
  debugForceTouchUi = true;
  MainMenuScreen.debugSavesOverride = true;

  for (final d in _devices) {
    runApp(_frame(d));
    await settleFrames(1400);
    await captureBoundary(_boundaryKey, '/tmp/menu_${d.name}.png', pixelRatio: 1.5);
  }

  // Kayıt YOKKEN (ilk açılış) tek kartlı hâl.
  MainMenuScreen.debugSavesOverride = false;
  for (final d in _devices.where(
    (d) => d.name == 'phone_15' || d.name == 'ipad',
  )) {
    runApp(_frame(d));
    await settleFrames(1400);
    await captureBoundary(_boundaryKey, '/tmp/menu_${d.name}_nosave.png', pixelRatio: 1.5);
  }
  exit(0);
}

Widget _frame(_Device d) => MaterialApp(
  debugShowCheckedModeBanner: false,
  home: ColoredBox(
    color: const Color(0xFF0B0C0E),
    child: Center(
      child: FittedBox(
        fit: BoxFit.contain,
        child: SizedBox(
          width: d.size.width,
          height: d.size.height,
          child: MediaQuery(
            data: MediaQueryData(
              size: d.size,
              devicePixelRatio: 2.0,
              padding: d.safe,
              viewPadding: d.safe,
            ),
            child: RepaintBoundary(
              key: _boundaryKey,
              child: const MainMenuScreen(
                onNewGame: _noop,
                onContinue: _noopMeta,
                onReferenceVillage: _noop,
              ),
            ),
          ),
        ),
      ),
    ),
  ),
);

void _noop() {}
void _noopMeta(Object _) {}



