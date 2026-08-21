import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/ui/mobile_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final channel in const [
      'plugins.flutter.io/shared_preferences',
      'plugins.flutter.io/path_provider',
    ]) {
      messenger.setMockMethodCallHandler(MethodChannel(channel), (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        if (call.method == 'getApplicationDocumentsDirectory') {
          return '/tmp';
        }
        return null;
      });
    }
    kCaptureMode = true;
    kCaptureSceneReady = false;
    debugForceTouchUi = true;
  });

  tearDown(() {
    kCaptureMode = false;
    kCaptureSceneReady = false;
    debugForceTouchUi = false;
  });

  testWidgets('mobil geri hareketi doğrudan çıkmaz, onay katmanını yönetir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(896, 414);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    var exited = false;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(
          home: VillageScene(
            referenceVillage: true,
            slotId: 'mobileBack',
            onExitToMenu: () => exited = true,
          ),
        ),
      );
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 25));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue, reason: 'referans köy kurulamadı');

    // Tam ekran inşa modu kendi geri katmanıdır; sistem geri hareketi
    // katalogu kapatır, oyuncuyu çıkış onayına sıçratmaz.
    await tester.tap(find.text('İNŞA'));
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('mobile_build_catalog')), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.byKey(const ValueKey('mobile_build_catalog')), findsNothing);
    expect(find.text('Ana menüye dön'), findsNothing);

    // Sonraki geri hareketi çıkış yapmaz; geri alınabilir onayı açar.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Ana menüye dön'), findsOneWidget);
    expect(exited, isFalse);

    // Onay açıkken geri hareketi, mobil kullanıcı beklentisindeki gibi yalnız
    // en üst katmanı kapatır.
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Ana menüye dön'), findsNothing);
    expect(exited, isFalse);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
