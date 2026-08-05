// ÇADIR & OCAK — mekanik gerçek sahnede koşuyor mu?
//
// Saf testler (cold_tent_test) yalnız matematiği doğrular: yarıçap, eşik,
// moral sırası. Ama bu mekaniğin sessizce ölü kalmasının bir sürü yolu var —
// mevsim bağlanmamış, `_tickShelter` tick zincirine takılmamış, çadırın merkezi
// yanlış okunmuş, ateş referansı boş kalmış. Hepsi "0 üşüyen köylü" olarak
// görünür ve hiçbir birim testi bunu yakalamaz.
//
// Bu yüzden burada gerçek sahne kurulur, kışa kadar hızlandırılır ve sahnenin
// KENDİ saydığı üşüyen sayısına bakılır (kProbeColdTents). Referans köyün iki
// çadırından biri ocağın soğuk bandındadır — kış gelince orada oturan köylünün
// üşümesi gerekir.
//
// TUZAK (bkz. living_probe_test): asset yüklemesi gerçek async, ticker fake
// clock ister. Önce runAsync ile kur, sonra pump ile sür.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    final m = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    for (final ch in const [
      'xyz.luan/audioplayers',
      'xyz.luan/audioplayers.global',
      'plugins.flutter.io/shared_preferences',
      'plugins.flutter.io/path_provider',
    ]) {
      m.setMockMethodCallHandler(MethodChannel(ch), (call) async {
        if (call.method == 'getAll') return <String, Object>{};
        return null;
      });
    }
    m.setMockStreamHandler(
        const EventChannel('xyz.luan/audioplayers.global/events'), null);
    kProbeOn = false;
    kCaptureMode = false;
    kDevSpeedBoostOverride = 0;
    kProbeColdTents = 0;
    kProbeColdRouses = 0;
  });

  testWidgets('kış gelince ocaktan uzak çadır köylüsünü üşütür', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kCaptureSceneReady = false;

    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'coldtent'),
      ));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
            'bu testin çadır mekaniğiyle ilgisi YOK: sahne ayağa kalkmadı.');

    // Referans köy yazda başlar (gün 24); kış birkaç gün ötede. Bulunca çık.
    kDevSpeedBoostOverride = 40.0;
    for (var i = 0; i < 1600 && kProbeColdTents == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(kProbeColdTents, greaterThan(0),
        reason: 'kış geldi ama hiçbir köylü üşümedi — çadır↔ocak mesafesi '
            'sahneye bağlanmamış olabilir (mevsim / _tickShelter / ocak '
            'referansı).');

    kDevSpeedBoostOverride = 0;
    await tester.pumpWidget(const SizedBox());
  });
}
