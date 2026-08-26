// DOĞAL KURULUŞ TESTER'I
//
// Ana menüyü ve oyuncunun kayıtlarını atlayıp rastgele taze bir köy açar.
// Capture/god-mode/sabit saat/otomatik seçim KULLANMAZ: intro, halka yürüyüşü,
// ateş yerleştirme, saz yatakları, ilk gece, çadır ve ilk odun zinciri gerçek
// oyunun kendi state machine'iyle işler. Sol üstteki panel yalnız state okur.
//
// Çalıştır:
//   flutter run -d macos -t lib/tools/founding_tester_main.dart
//   flutter run --release -d <iphone-id> -t lib/tools/founding_tester_main.dart

import 'package:flutter/material.dart';

import '../main.dart' as game;
import '../systems/platform_adapt.dart';
import '../ui/settings_model.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await PlatformAdapt.applyMobileChrome();
  await SettingsModel.instance.load();

  // Bu ikili tester'ın ana sözleşmesi: görünür teşhis AÇIK, simülasyona
  // müdahale eden capture kapısı KAPALI.
  game.kFoundingTesterMode = true;
  game.kCaptureMode = false;

  runApp(const _FoundingTesterApp());
}

class _FoundingTesterApp extends StatefulWidget {
  const _FoundingTesterApp();

  @override
  State<_FoundingTesterApp> createState() => _FoundingTesterAppState();
}

class _FoundingTesterAppState extends State<_FoundingTesterApp> {
  var _run = 0;

  void _restart() => setState(() => _run++);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Luw · Doğal Kuruluş Tester',
    debugShowCheckedModeBanner: false,
    home: game.VillageScene(
      key: ValueKey(_run),
      // Boş slot tester koşusunun normal kayıt listesini kirletmesini önler.
      // Her yeniden kurulum yeni Random/world generator örneği alır.
      slotId: '',
      slotName: 'Doğal Kuruluş Tester',
      onRestartRun: _restart,
      onExitToMenu: _restart,
    ),
  );
}
