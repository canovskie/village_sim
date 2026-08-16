// EŞİK PROVASI — kazanılan direniş GERÇEKTEN sahneleniyor mu?
//
// Bu testin varlık sebebi bir yalandı: kronik yıllardır "köy tırpanla, baltayla
// eşiğe dizildi" yazıyordu ama dizilen kimse yoktu. Direnişin KAYBI sahnede
// oynuyordu (askerler merkeze dalar, kurbanlar düşer), KAZANCI ise bildirim
// satırıydı. Birim testi bunu göremez: `imperialDefensePreview` doğru sayıyı
// üretiyordu, eksik olan sayı değil GÖVDEYDİ.
//
// Üç şeyi arıyoruz ve üçü de ancak gerçek sahnede görülür:
//   1. Direniş modal'ındaki savunma düğmesi EKRANDA VE BASILABİLİR mi.
//   2. Basınca eşik vinyeti kuruluyor ve kadro buluyor mu ("sessiz susma").
//   3. Sahne kapanınca kadro salıveriliyor mu — vinyet rolleri
//      `IntentPriority.ceremony` ile dayatılır ve salıverilmezse köylü ÖMÜR BOYU
//      donar (bkz. scene_vignette sınıf başlığındaki tuzak).
//
// Harness deseni event_vignette_test ile aynı: runAsync ile köyü kur, sonra
// koşula bakan pump'lar. Sabit sayıda pump güvenilmez — heyet yürürken sim
// akar, modal açıkken DURUR.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/imperial.dart';

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
    kProbeImperialArmed = false;
    kProbeSummonImperial = false;
    kProbeForceResistWin = false;
    kProbeNoImperial = false;
    kProbeVignetteId = '';
    kProbeVignetteCast = 0;
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kProbeOn = true; // _tickProbe koşsun: heyet çağrısı oradan geçiyor
    kMindTelemetryOn = true;
    // ŞART: global — önceki testten true kalırsa sahne hazır olmadan tick
    // denenir (bkz. living_probe_test'teki aynı tuzak).
    kCaptureSceneReady = false;

    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'threshold'),
      ));
      for (var i = 0; i < 160 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
  }

  Future<bool> waitUntil(WidgetTester tester, bool Function() ok,
      {int maxSteps = 4000}) async {
    for (var i = 0; i < maxSteps; i++) {
      if (ok()) return true;
      await tester.pump(const Duration(milliseconds: 16));
    }
    return ok();
  }

  Future<void> shutdown(WidgetTester tester) async {
    kDevSpeedBoostOverride = 0;
    kProbeForceResistWin = false;
    kProbeImperialArmed = false;
    kProbeOn = false;
    await tester.pumpWidget(const SizedBox());
  }

  testWidgets('kazanılan direniş eşikte bir hat kurar ve hattı salıverir',
      (tester) async {
    await boot(tester);
    expect(kCaptureSceneReady, isTrue, reason: 'referans köy kurulamadı');

    // Heyet harita kenarından yürüyor — hızlandırmadan bu yürüyüş dakikalar
    // sürer. Aralık gün uzunluğunun böleni olmasın diye 24 değil 22 (bkz.
    // CLAUDE.md §4 "ölçüm aralığı" tuzağı).
    kDevSpeedBoostOverride = 22;
    // Muafiyet kalksın: prova köyünde pazarlık modalı normalde her tick
    // siliniyor (bkz. kProbeImperialArmed) — düğmeye basacak olan BU test.
    kProbeImperialArmed = true;
    kProbeForceResistWin = true;
    kProbeSummonImperial = true;

    // Pazarlık açılınca sim durur — telemetri bunu 'imparatorluk' diye yazar.
    final parley = await waitUntil(tester, () => kProbePause == 'imparatorluk');
    expect(parley, isTrue,
        reason: 'heyet eşiğe hiç varmadı (pazarlık açılmadı) — '
            'pause=$kProbePause çağrı-tüketildi=${!kProbeSummonImperial}');

    // 1. Savunma düğmesi ekranda mı? Direniş şansı 0 ise düğme HİÇ çizilmez —
    // o durumda sahne de kurulamaz, testin geri kalanı anlamsızdır.
    final resistBtn = find.textContaining('Savunmayı seç');
    expect(resistBtn, findsOneWidget,
        reason: 'referans köyde savunma seçeneği çizilmedi — direniş şansı 0');

    await tester.tap(resistBtn);
    await tester.pump();

    // 2. Sahne kuruldu mu? Telemetri `_imperialResist` içinde SENKRON yazılır,
    // yani tıklamadan hemen sonra okunur.
    expect(kProbeVignetteId, kThresholdVignetteId,
        reason: 'direniş kazanıldı ama eşik sahnesi hiç kurulmadı');
    expect(kProbeVignetteCast, greaterThan(1),
        reason: 'hat tek kişilik — kadro bulunamıyor (bkz. _castNear yarıçapı)');

    // 3. Kapanış: ömür dolunca ya da kadro işini bitirince salıverilmeli.
    final closed = await waitUntil(tester, () => kProbeVignetteId.isEmpty);
    expect(closed, isTrue, reason: 'eşik sahnesi hiç kapanmadı');
    // Salıverme telemetri turunda okunur — birkaç kare pay bırak.
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kProbeCeremonyLocked, 0,
        reason: '$kProbeCeremonyLocked köylü ceremony niyetinde DONDU — '
            'eşik kadrosu salıverilmiyor');

    await shutdown(tester);
  });
}
