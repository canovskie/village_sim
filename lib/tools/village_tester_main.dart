// CANLI KÖY TESTER
//
// Hazır/showcase köy kurmaz. Ana menüyü ve kalıcı kayıtları atlayıp normal,
// rastgele bir kuruluş başlatır; sağ üstteki küçük panel yalnız aynı koşunun
// saatini, havasını, hızını ve hedefli davranış tetiklerini kontrol eder.
//
// Çalıştır:
//   flutter run -d macos -t lib/tools/village_tester_main.dart
//   flutter run --release -d <iphone-id> -t lib/tools/village_tester_main.dart

import 'package:flutter/material.dart';

import '../main.dart' as game;
import '../systems/platform/platform_adapt.dart';
import '../ui/core/settings_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformAdapt.applyMobileChrome();
  await SettingsModel.instance.load();

  game.kVillageTesterMode = true;
  game.kFoundingTesterMode = false;
  game.kCaptureMode = false;

  runApp(const VillageTesterApp());
}

class VillageTesterApp extends StatefulWidget {
  const VillageTesterApp({super.key});

  @override
  State<VillageTesterApp> createState() => _VillageTesterAppState();
}

class _VillageTesterAppState extends State<VillageTesterApp> {
  var _run = 0;

  void _restart() => setState(() => _run++);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Luw · Canlı Köy Tester',
    debugShowCheckedModeBanner: false,
    home: game.VillageScene(
      key: ValueKey(_run),
      slotId: '',
      slotName: 'Canlı Köy Tester',
      onRestartRun: _restart,
      onExitToMenu: _restart,
    ),
  );
}
