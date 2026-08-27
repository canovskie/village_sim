// OLAY VİNYETİ PROVASI — 9 sahnenin hepsi gerçekten oynuyor mu?
//
// Vinyet sisteminin (bkz. lib/scene/scene_vignette.dart) iki ölümcül kör
// noktası var ve ikisi de gözle FARK EDİLMEZ:
//
//   1. SESSİZ SUSMA — kadro bulunamaz, sahne hiç kurulmaz. Ekranda hiçbir hata
//      yoktur; olay yine banner olarak geçer, oyuncu bir şey kaçırdığını bile
//      bilmez. Geliştirme sırasında GERÇEKTEN olan buydu: 18 kişilik referans
//      köyde akşamüstü uygun aday sayısı SIFIRDI (11 kişi ateş başında oturmuş,
//      6'sı iş döngüsünde). İki kademeli kadro seçimi bu ölçümden doğdu.
//   2. KİLİTLİ KADRO — roller `IntentPriority.ceremony` ile dayatılır ve o
//      önceliği hakemin hiçbir güvenlik ağı düşürmez. Salıverme unutulursa
//      köylü ÖMÜR BOYU o rolde donar. Köy görünürde dönmeye devam eder;
//      yalnız birkaç kişi bir daha hiç iş yapmaz.
//
// Test ikisini de arar. Harness deseni living_probe_test ile aynı (önce
// runAsync ile köyü kur, sonra fake-clock pump).
//
// TUZAK: köy kurulduktan sonra sim UZUN SÜRE duraklı kalabilir (açılış
// sinematiği / zorlanmış dilekçe → dt=0). Sabit sayıda pump ile "olay vurdu mu"
// diye bakmak bu yüzden güvenilmez; her bekleyiş KOŞULA bakar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/event_system.dart';

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
      const EventChannel('xyz.luan/audioplayers.global/events'),
      null,
    );
    kProbeOn = false;
    kForcedEventId = '';
    kProbeTriggerEvent = false;
    kProbeVignetteId = '';
    kProbeVignetteCast = 0;
    kProbeChoiceWaiting = '';
    kProbeChoiceTimeouts = 0;
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kMindTelemetryOn = true;
    kProbeVignetteId = '';
    kProbeVignetteCast = 0;
    kProbeChoiceWaiting = '';
    kProbeChoiceTimeouts = 0;
    // ŞART: global — önceki testten true kalırsa sahne hazır olmadan tick
    // denenir (bkz. living_probe_test'teki aynı tuzak).
    kCaptureSceneReady = false;

    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VillageScene(referenceVillage: true, slotId: 'vignette'),
        ),
      );
      // Tam süitte birkaç ağır living-probe aynı anda asset açıyor. Sekiz
      // saniyelik eski duvar-saati bütçesi sahne daha tick almadan flake
      // üretiyordu; koşul yine aynı, yalnız yoğun CI için nefes payı geniş.
      for (var i = 0; i < 600 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
  }

  Future<void> shutdown(WidgetTester tester) async {
    kDevSpeedBoostOverride = 0;
    kForcedEventId = '';
    kProbeTriggerEvent = false;
    kProbeChoiceWaiting = '';
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> run(WidgetTester tester, int steps) async {
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  /// [ok] doğru olana kadar pump et (azami [maxSteps]). Sim duraklıysa pump
  /// boşa gider — bu yüzden pay bol tutulur. Dönüş: koşul tuttu mu.
  Future<bool> waitUntil(
    WidgetTester tester,
    bool Function() ok, {
    int maxSteps = 4000,
  }) async {
    for (var i = 0; i < maxSteps; i++) {
      if (ok()) return true;
      await tester.pump(const Duration(milliseconds: 16));
    }
    return ok();
  }

  /// Olayı zorla ve sahnelenmesini bekle. Karar gerektiren olayda (veba,
  /// canavar, yangın) KAPIDA KUYRUK işler: modal kendiliğinden AÇILMAZ, olay
  /// HUD'daki KARAR mührüne iner ve sim akmaya devam eder. Test oyuncu gibi
  /// davranır: mühre tıklar, İLK şıkkı seçer — vinyet karar anında kurulur.
  /// (Zaman aşımına bırakılsa pasif şık oynardı; bu testin ölçtüğü koreografi
  /// aktif şıkkınki.)
  Future<void> fireEvent(WidgetTester tester, EventOutcome e) async {
    kForcedEventId = e.id;
    kProbeTriggerEvent = true;
    if (e.needsChoice) {
      // 1) Olay omen'i bitirip kuyruğa düşsün (mühür ancak o zaman çizilir).
      final queued = await waitUntil(tester, () => kProbeChoiceWaiting == e.id);
      expect(queued, isTrue, reason: '${e.id} karar kuyruğuna hiç ulaşmadı');
      await tester.pump();
      // 2) Mühre tıkla → modal açılır.
      final seal = find.text('KARAR');
      expect(seal, findsOneWidget, reason: '${e.id} KARAR mührünü açmadı');
      await tester.tap(seal);
      await tester.pump();
      // 3) İlk şıkkı seç.
      final label = e.choices!.first.label;
      final choice = find.text(label);
      expect(
        choice,
        findsOneWidget,
        reason: '${e.id} ilk karar seçeneğini göstermedi',
      );
      await tester.tap(choice);
      await tester.pump();
    }
    final staged = await waitUntil(tester, () => kProbeVignetteId == e.id);
    expect(staged, isTrue, reason: '${e.id} NPC sahnesini hiç kurmadı');
  }

  testWidgets('her rastgele olay dünyada bir NPC sahnesi kurar', (
    tester,
  ) async {
    await boot(tester);
    expect(kCaptureSceneReady, isTrue, reason: 'referans köy kurulamadı');
    kDevSpeedBoostOverride = 6.0;

    var choiceSeen = false;
    for (final e in EventSystem.events) {
      // Ağır kararların arasında gerçek oyunda kısa bir sakinleşme süresi var.
      // İkinci ve sonraki ağır kararı art arda zorlamak yerine temiz köyde
      // aynı gerçek kuyruk/modal yolunu oynat. Otomatik olaylar aynı sahnede
      // kalır; gereksiz dokuz ayrı asset kurulumu tam süiti boğmaz.
      if (e.needsChoice && choiceSeen) {
        await shutdown(tester);
        await boot(tester);
        expect(
          kCaptureSceneReady,
          isTrue,
          reason: '${e.id} için referans köy yeniden kurulamadı',
        );
        kDevSpeedBoostOverride = 6.0;
      }
      choiceSeen |= e.needsChoice;
      kProbeVignetteId = '';
      kProbeVignetteCast = 0;
      await fireEvent(tester, e);
      expect(
        kProbeVignetteCast,
        greaterThan(0),
        reason: '${e.id} NPC kadrosu bulamadı',
      );
      final closed = await waitUntil(tester, () => kProbeVignetteId.isEmpty);
      expect(closed, isTrue, reason: '${e.id} NPC sahnesi kapanmadı');
    }
    await shutdown(tester);
  });

  testWidgets('vinyet kadrosu salıverilir — hiçbir köylü rolde donmaz', (
    tester,
  ) async {
    await boot(tester);
    kDevSpeedBoostOverride = 6.0;

    // En uzun koreografi yangındır (iki turlu kova zinciri) — kilitlenme riski
    // en yüksek sahne odur.
    final fire = EventSystem.events.firstWhere(
      (e) => e.id == EventIds.houseFire,
    );
    await fireEvent(tester, fire);
    expect(
      kProbeVignetteCast,
      greaterThan(0),
      reason: 'yangın sahnesi hiç kurulmadı — kadro bulunamıyor',
    );

    // Vinyet ömrü 30 sn; ondan sonra kadro koşulsuz salıverilmeli.
    final closed = await waitUntil(tester, () => kProbeVignetteId.isEmpty);
    expect(closed, isTrue, reason: 'vinyet sahnesi hiç kapanmadı');
    // Salıverme telemetri turunda okunur — birkaç kare pay bırak.
    await run(tester, 60);
    expect(
      kProbeCeremonyLocked,
      0,
      reason:
          '$kProbeCeremonyLocked köylü ceremony niyetinde DONDU — '
          '_releaseVignette çalışmıyor (bkz. scene_vignette tuzağı)',
    );

    // Köy salıverilenlerle birlikte yeniden hareket etmeli.
    final before = kMindDistance;
    final moved = await waitUntil(
      tester,
      () => kMindDistance > before,
      maxSteps: 1500,
    );
    expect(moved, isTrue, reason: 'sahne bitti ama köy kımıldamıyor');
    await shutdown(tester);
  });
}
