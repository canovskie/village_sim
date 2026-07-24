import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:village_sim/dev/animation_room.dart';

/// Animasyon odasının KENDİSİNİ yakalar — oda çiziliyor mu, sekmeler duruyor mu,
/// oynatıcı sahneyi kuruyor mu, karakter sekmesi figürü basıyor mu.
///
///   flutter run -d macos -t lib/tools/anim_room_probe_main.dart
///
/// Odanın ilk sürümü BOMBOŞ çıkmıştı (AppTabs içeriğe sınırsız yükseklik verir,
/// Expanded/ListView sıfıra çöker) — bu probe onun gibi yerleşim çökmelerini
/// yakalamak için var, FlutterError.onError dahil.
final GlobalKey _boundary = GlobalKey();
final GlobalKey<_RootState> _root = GlobalKey<_RootState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterError.onError = (d) {
    stdout.writeln('FLUTTER_ERROR: ${d.exception}');
    stdout.writeln(
        '  STACK: ${d.stack.toString().split('\n').take(4).join(' | ')}');
  };

  runApp(MaterialApp(debugShowCheckedModeBanner: false, home: _Root(key: _root)));

  final dir = Directory('preview/cutscene')..createSync(recursive: true);
  await _settle(3500);
  await _grab('${dir.path}/room_scenes.png');
  _root.currentState!.showTab(1);
  await _settle(1800);
  await _grab('${dir.path}/room_character.png');
  stdout.writeln('ROOM_DONE');
  exit(0);
}

class _Root extends StatefulWidget {
  const _Root({super.key});
  @override
  State<_Root> createState() => _RootState();
}

class _RootState extends State<_Root> {
  int _tab = 0;

  /// Sekme değiştirmek için odayı SIFIRDAN kurar — AppTabs'in `initial`'ı
  /// yalnız state kurulurken okunur, widget güncellemesiyle değişmez.
  void showTab(int i) => setState(() => _tab = i);

  @override
  Widget build(BuildContext context) => Center(
        child: FittedBox(
          child: SizedBox(
            width: 1180,
            height: 700,
            child: MediaQuery(
              data: const MediaQueryData(
                  size: Size(1180, 700), devicePixelRatio: 1),
              child: RepaintBoundary(
                key: _boundary,
                child:
                    AnimationRoomScreen(key: ValueKey(_tab), initialTab: _tab),
              ),
            ),
          ),
        ),
      );
}

final Stopwatch _clock = Stopwatch()..start();
int _frames = 0;

/// Gerçek süre bekler; motor kare üretmiyorsa (pencere arkada) elle pompalar.
Future<void> _settle(int ms) async {
  WidgetsBinding.instance.addTimingsCallback((_) => _frames++);
  final target = _clock.elapsed + Duration(milliseconds: ms);
  while (_clock.elapsed < target) {
    final before = _frames;
    await Future<void>.delayed(const Duration(milliseconds: 24));
    if (_frames == before) {
      final b = WidgetsBinding.instance;
      if (b.schedulerPhase == SchedulerPhase.idle) {
        b.handleBeginFrame(_clock.elapsed);
        b.handleDrawFrame();
      }
    }
  }
}

Future<void> _grab(String path) async {
  final ctx = _boundary.currentContext;
  if (ctx == null) {
    stdout.writeln('NO_CONTEXT: $path');
    return;
  }
  final r = ctx.findRenderObject() as RenderRepaintBoundary;
  final img = await r.toImage(pixelRatio: 1.0);
  final data = await img.toByteData(format: ui.ImageByteFormat.png);
  img.dispose();
  if (data != null) File(path).writeAsBytesSync(data.buffer.asUint8List());
}
