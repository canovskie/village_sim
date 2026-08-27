// KAPIDA KUYRUK PROVASI — gerçek sahnede.
//
// Bu turda oyunun iki büyük kesintisi söküldü: karar isteyen olay modalı ve
// mühleti dolan dilekçenin zorunlu huzuru artık simi DONDURMUYOR. Yerine
// kuyruk geldi: HUD'da mühür bekler, mühlet erir, dolarsa olay pasif
// seçeneğini kendi yaşar; dilekçe ise kapıda beklemeye geçer (bedel gün
// başına işler, karar yine oyuncunun).
//
// Provanın ölçtüğü üç şey:
//   1. Olay kuyruğa GİRİYOR mu (mühür görünüyor mu) — "kod var ama hiç
//      tetiklenmiyor" sınıfının ta kendisi.
//   2. Kuyruk beklerken sim AKIYOR mu — zaman aşımı sayacının artması akışın
//      kanıtıdır: donuk simde dt gelmez, mühlet hiç erimez.
//   3. Dilekçe mühleti dolunca donma yerine kapıda-bekleme eskalasyonu
//      tetikleniyor mu.
//
// TUZAK: prova harness'ı (kProbeOn) bekleyen kararı/gecikmiş dilekçeyi her
// tick bastırır (başka provaların köyü donmasın diye). Bu dosya tam da o
// bekleyişi ölçtüğü için kProbeChoiceQueueArmed / kProbePetitionQueueArmed
// ile muafiyetten çıkar — kProbeImperialArmed deseninin kuyruk karşılığı.
//
// Kurulum deseni decision_trace_probe_test ile birebir aynı.

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
    // Kapanış/kesinti sistemlerinin GLOBAL bayrakları — başka bir prova
    // koşusundan sızarsa bu köy dağılır ve sim donar (bkz. CLAUDE.md).
    kProbeCollapseArmed = false;
    kProbeForceSchism = false;
    kProbeSchismHouse = '';
    kProbeDrainVillage = false;
    kProbeCollapsed = false;
    kProbeHouseWithhold = false;
    kProbeHouseAppease = false;
    kProbeReckoningArmed = false;
    kProbeLessonsArmed = false;
    kProbeNoImperial = false;
    kProbeDecideNow = false;
    kProbeNoEvents = false;
    kProbeTriggerEvent = false;
    kForcedEventId = '';
    kProbeChoiceQueueArmed = false;
    kProbeChoiceWaiting = '';
    kProbeChoiceTimeouts = 0;
    kProbePetitionQueueArmed = false;
    kProbePetitionOverdueSeen = false;
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  Future<void> boot(WidgetTester tester, String slot) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kCaptureSceneReady = false;
    kProbeOn = true;
    // Vergi heyetinin pazarlık modali simi hâlâ dondurur (bilerek — nadir,
    // meşru kesinti); ölçtüğümüz şey kuyruk, heyet değil.
    kProbeNoImperial = true;

    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        MaterialApp(home: VillageScene(referenceVillage: true, slotId: slot)),
      );
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();
    expect(
      kCaptureSceneReady,
      isTrue,
      reason:
          'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
          'bu bulgunun kuyrukla ilgisi YOK, sahne hiç ayağa kalkmadı.',
    );
  }

  Future<void> shutdown(WidgetTester tester) async {
    kProbeOn = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
    kProbeChoiceQueueArmed = false;
    kProbePetitionQueueArmed = false;
    kProbeTriggerEvent = false;
    kForcedEventId = '';
    kDevSpeedBoostOverride = 0;
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> run(WidgetTester tester, double seconds) async {
    const stepMs = 16;
    final steps = (seconds * 1000 / stepMs).round();
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
    }
  }

  testWidgets('karar olayı simi dondurmadan kuyruğa girer ve mühlet dolunca '
      'köy kendi yoluna gider', (tester) async {
    await boot(tester, 'decisionQueue');
    kProbeChoiceQueueArmed = true;
    kDevSpeedBoostOverride = 24.0;

    // Belirli bir olayı zorla mayala: yangın (major → mühlet günün %20'si).
    kForcedEventId = EventIds.houseFire;
    kProbeTriggerEvent = true;

    // 1) Olay omen'ini bitirip KUYRUĞA düşene kadar koştur.
    for (var i = 0; i < 30 && kProbeChoiceWaiting.isEmpty; i++) {
      await run(tester, 1);
    }
    expect(
      kProbeChoiceWaiting,
      EventIds.houseFire,
      reason: kProbePause.isNotEmpty
          ? 'sim donuk ("$kProbePause") — olay kuyruğa hiç düşemedi'
          : 'olay vurdu ama kuyruğa girmedi — vuruş yolu hâlâ modal '
                'bekliyor ya da bastırma muafiyeti (kProbeChoiceQueueArmed) '
                'delik',
    );

    // Kuyruk beklerken sim DONMAMALI — kesintisiz akışın ilk yarısı.
    expect(
      kProbePause,
      isEmpty,
      reason:
          'karar kuyruğu simi dondurdu ("$kProbePause") — kapıda '
          'kuyruğun bütün amacı buydu',
    );

    // 2) Mühür ekranda: oyuncunun kararı kaybolmadı, bekliyor.
    await tester.pump();
    expect(
      find.text('KARAR'),
      findsOneWidget,
      reason:
          'olay kuyrukta ama HUD karar mührü yok — oyuncuya görünmeyen '
          'kuyruk, sessizce dolan mühlet demektir (kayıp haber verilir '
          'kuralı delinir)',
    );

    // Bundan sonra rastgele olaylar sussun: zaman aşımı asserti kuyruğun
    // BOŞALDIĞINI da ölçüyor; peşinden gelen ikinci bir olay onu kirletirdi.
    kProbeNoEvents = true;

    // 3) Hiçbir tuşa basmadan bekle: mühlet dolmalı ve köy pasif seçeneği
    // kendi yaşamalı. Sayaç ancak sim AKARSA artar — donuk simde mühlet
    // erimez; bu yüzden tek başına akışın da kanıtıdır.
    for (var i = 0; i < 30 && kProbeChoiceTimeouts == 0; i++) {
      await run(tester, 1);
    }
    expect(
      kProbeChoiceTimeouts,
      greaterThan(0),
      reason:
          'mühlet hiç dolmadı — ya sim aslında donuk ya da '
          '_tickChoiceDeadline hiç çağrılmıyor (bekleyen: '
          '"$kProbeChoiceWaiting")',
    );
    expect(
      kProbeChoiceWaiting,
      isEmpty,
      reason:
          'zaman aşımı koştu ama kuyruk boşalmadı — olay hem çözülmüş '
          'hem bekliyor görünür (mühür yalan söyler)',
    );

    // 4) Mühür de indi: çözülen kararın rozeti ekranda kalmamalı.
    await tester.pump();
    expect(
      find.text('KARAR'),
      findsNothing,
      reason: 'karar çözüldü ama mühür hâlâ ekranda',
    );

    await shutdown(tester);
  });

  testWidgets('mühleti dolan dilekçe donmaz: kapıda beklemeye geçer', (
    tester,
  ) async {
    await boot(tester, 'decisionQueuePetition');
    kProbePetitionQueueArmed = true;
    // Olaylar sussun — ölçülen şey dilekçe eskalasyonu.
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;

    // İlk dilekçe ~1 oyun günü sonra gelir, mühleti ~2 gün: 3+ oyun günü
    // kimse karar vermeden akarsa eskalasyon tetiklenmeli. 24x hızda bu
    // ~30-40 gerçek sn eder; cömert bekle.
    for (var i = 0; i < 70 && !kProbePetitionOverdueSeen; i++) {
      await run(tester, 1);
    }
    expect(
      kProbePetitionOverdueSeen,
      isTrue,
      reason: kProbePause.isNotEmpty
          ? 'sim donuk ("$kProbePause") — dilekçe mühleti hiç eriyemedi'
          : 'mühlet doldu ama kapıda-bekleme eskalasyonu hiç tetiklenmedi '
                '(bekleyen dilekçe: "$kProbePendingPetition") — bekletmenin '
                'bedeli kağıt üstünde kaldı',
    );

    // Donma YOK — eski zorunlu huzurun tek mirası koyu scrim'di, donması değil.
    expect(
      kProbePause,
      isEmpty,
      reason: 'dilekçe eskalasyonu simi dondurdu ("$kProbePause")',
    );

    // Mühür kalıcı-kızarık durumda ve bedeli söylüyor.
    await tester.pump();
    expect(
      find.textContaining('kapıda bekliyor'),
      findsOneWidget,
      reason:
          'gecikmiş dilekçenin mührü bedel uyarısını göstermiyor — '
          'rampa görünmezse kayıp sessizleşir',
    );

    await shutdown(tester);
  });

  // ── Zaman aşımı sözleşmesi (saf — sahne gerekmez) ─────────────────────────
  //
  // Kural: karar olaylarında PASİF seçenek ("kendi haline bırak") listenin
  // SONUNDA durur; mühlet dolunca köy onu yaşar. Müdahale (şifacı/muhafız/
  // kova zinciri) asla kendiliğinden yaşanmaz. Yeni karar olayı eklerken
  // pasif şıkkı sona koy ve id'sini buradaki listeye ekle.

  test('zaman aşımı sözleşmesi: her karar olayının pasif seçeneği sonda', () {
    const passiveIds = {
      'rationWater',
      'endure',
      'hide',
      'waitStorm',
      'letBurn',
      'hearOneSong',
      'quickTrade',
      'harvestFeast',
      'letAccordStand',
    };
    final choiceEvents = EventSystem.events
        .where((e) => e.needsChoice)
        .toList();
    expect(
      choiceEvents,
      isNotEmpty,
      reason:
          'katalogda tek bir karar olayı bile yok — sözleşmenin '
          'bekçilediği şey ortadan kalkmış',
    );
    for (final e in choiceEvents) {
      final t = e.timeoutChoice;
      expect(t, isNotNull);
      expect(
        t!.id,
        e.choices!.last.id,
        reason: '${e.id}: timeoutChoice son seçenek değil',
      );
      expect(
        passiveIds.contains(t.id),
        isTrue,
        reason:
            '${e.id}: mühlet dolunca köy "${t.label}" (${t.id}) '
            'seçeneğini kendi yaşayacak — bu pasif şık gibi durmuyor. '
            'Pasifse id\'sini passiveIds listesine ekle; değilse şık '
            'sırasını düzelt (pasif SONA).',
      );
    }
  });
}
