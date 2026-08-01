// Ana menüyü BİRDEN ÇOK cihaz ölçüsünde arka arkaya çeken harness.
// "Her ekranda kaydırmasız sığıyor mu?" sorusunun görsel kanıtı.
//
// Çalıştır:  flutter run -d macos -t lib/tools/menu_sizes_capture_main.dart
// Çıktı:     /tmp/menu_<ad>.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../ui/app_ui.dart';
import '../ui/mobile_ui.dart';
import '../ui/main_menu_screen.dart';

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
    await _settle(1400);
    await _capture('/tmp/menu_${d.name}.png');
  }

  // Kayıt YOKKEN (ilk açılış) tek kartlı hâl.
  MainMenuScreen.debugSavesOverride = false;
  for (final d in _devices.where(
    (d) => d.name == 'phone_15' || d.name == 'ipad',
  )) {
    runApp(_frame(d));
    await _settle(1400);
    await _capture('/tmp/menu_${d.name}_nosave.png');
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

final Stopwatch _clock = Stopwatch()..start();

Future<void> _settle(int ms) async {
  final steps = (ms / 16).ceil();
  for (int i = 0; i < steps; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 16));
    final b = WidgetsBinding.instance;
    if (b.schedulerPhase == SchedulerPhase.idle) {
      b.handleBeginFrame(_clock.elapsed);
      b.handleDrawFrame();
    }
  }
}

Future<void> _capture(String path) async {
  final ctx = _boundaryKey.currentContext;
  if (ctx == null) {
    stdout.writeln('CAPTURE_FAIL: $path (no context)');
    return;
  }
  final boundary = ctx.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.5);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  await File(path).writeAsBytes(bytes.buffer.asUint8List());
  stdout.writeln('CAPTURED: $path');
}
