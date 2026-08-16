// GÖVDE DİLİ PROVASI — selam gerçekten KOLDA mı oynuyor?
//
// Projede baş üstü emoji yasak ve sebebi şu: baloncuk olayın kendisini değil
// ADINI gösterir. El sallayan adam selam verir; başında 👋 duran adam "selam"
// yazısı taşır. Selam (👋), hikâye anlatımı (📖) ve göktaşı (🌠) baloncuktan
// çıkarılıp gövdeye taşındı — sırasıyla CharGesture.wave, CharGesture.tell ve
// NpcEmotion.wonder postürü.
//
// Bu göç iki yönden sessizce bozulabilir ve ikisi de birim testiyle görülmez:
//
//   1. JEST HİÇ TETİKLENMEZ — `waveTime` yazılır ama okunmaz, ya da selam
//      döngüsünün kapısı kapanır. Ekranda hata yoktur; köylüler sadece sessizce
//      yan yana geçer. Baloncuk kalkmış olduğu için ARTIK BİR ŞEY DE GÖRÜNMEZ:
//      eski hâlde en azından bir emoji vardı.
//   2. BORÇ GERİ GELİR — biri kolay yoldan gidip başın üstüne yeniden emoji
//      koyar (bir sonraki özellik için "geçici" olarak).
//
// Test ikisini de arar. Telemetri YAPIŞKAN: jest 1,6 saniye sürüyor, sabit
// aralıklı bir örnekleme onu ıskalayabilirdi.

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
    kProbeWaveSeen = false;
    kProbeBannedBubble = '';
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  testWidgets('komşuluk selamı gövdede oynar — baş üstünde ikon kalmadı',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kProbeOn = true;
    kCaptureSceneReady = false;

    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'gesture'),
      ));
      for (var i = 0; i < 160 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue, reason: 'referans köy kurulamadı');

    // Selam yoklaması 1,2 sim-sn'de bir ve her yoklamada şans zarı var; köyün
    // sokakta birbirine denk gelmesi de gerekiyor. 17 böleni olmayan bir sayı
    // (gün uzunluğunun bölenleri hep aynı saati örnekler).
    // Üst sınır cömert ama sonsuz değil: geçen koşuda selam birkaç yüz karede
    // düşüyor. Burada her pump tam sahneyi çiziyor, o yüzden BAŞARISIZLIK
    // pahalı — sınırı 1200'de tutmak testi dakikalarca koşturmaktan korur.
    kDevSpeedBoostOverride = 17;
    for (var i = 0; i < 1200 && !kProbeWaveSeen; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(kProbeWaveSeen, isTrue,
        reason: 'hiçbir köylü el sallamadı — selam jesti hiç tetiklenmiyor '
            '(waveTime yazılıyor ama okunmuyor olabilir)');
    expect(kProbeBannedBubble, '',
        reason: 'baş üstünde yasaklı ikon göründü: $kProbeBannedBubble — '
            'gövde diline taşınan bir anlatım baloncuğa geri döndü');

    kDevSpeedBoostOverride = 0;
    kProbeOn = false;
    await tester.pumpWidget(const SizedBox());
  });
}
