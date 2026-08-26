// KAYIT GİDİŞ-DÖNÜŞÜ — "kaydedilen köy yeniden açılıyor mu?"
//
// Projede save/load'ın uçtan uca koştuğu HİÇBİR test yoktu: kayda yeni bir alan
// eklendiğinde yalnız `flutter analyze` bakıyordu, o da JSON'un içini görmez.
// Buradaki iddia tek cümle: **referans köy kaydedilip JSON'a yazılabilir ve o
// JSON'dan geri yüklenebilir.**
//
// Gerçek yolun aynısı kullanılır: captureWorld() → jsonEncode → jsonDecode →
// yeni bir sahneye `initialWorld` olarak verilir (restoreWorld).

import 'dart:convert';

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
      const EventChannel('xyz.luan/audioplayers.global/events'),
      null,
    );

    kProbeOn = false;
    kProbeNoEvents = true;
    kProbeNoImperial = true;
    kProbeCollapseArmed = false;
    kProbeReckoningArmed = false;
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  tearDown(() {
    kProbeNoEvents = false;
    kProbeNoImperial = false;
    kCaptureMode = false;
  });

  Future<void> bootReference(WidgetTester tester) async {
    kCaptureMode = true;
    kCaptureSceneReady = false;
    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VillageScene(referenceVillage: true, slotId: 'saveRoundtrip'),
        ),
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
      reason: 'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı',
    );
  }

  testWidgets('kaydedilen köy JSON\'dan geri yüklenir', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    kProbeOn = true; // telemetri _tickProbe içinde yaşar
    await bootReference(tester);

    kProbeSaveError = 'koşmadı';
    kProbeSaveRoundtrip = true;
    for (var i = 0; i < 40 && kProbeSaveRoundtrip; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }

    expect(
      kProbeSaveError,
      '',
      reason: 'kaydedilen köy geri yüklenemedi — oyun kaydı açarken çöker',
    );
    expect(
      tester.takeException(),
      isNull,
      reason: 'yükleme sırasında istisna atıldı',
    );

    // Porter zincirinin item/callback/anchor parçaları geçicidir ve kayda
    // yazılmaz. Eski ya da taşıma anında alınmış bir kayıt yalnız enum state'i
    // geri getirirse köylü boş elle hayalet taşıyıcı olarak (0,0)'a yürür.
    final baseline = kProbeWorldJson;

    // Görsel tasarım bina türünden bağımsız kalıcıdır: aynı ahşap ev kiremitli
    // olarak kaydedilip yeniden açıldığında seçimi kaybolmamalı.
    final designedWorld = Map<String, dynamic>.from(
      jsonDecode(baseline) as Map<String, dynamic>,
    );
    final designedHouse = (designedWorld['buildings'] as List)
        .cast<Map>()
        .firstWhere((b) => b['type'] == 'woodenHouse');
    designedHouse['design'] = 'terracotta';
    kProbeSaveError = 'koşmadı';
    kProbeRestoreJson = jsonEncode(designedWorld);
    for (var i = 0; i < 40 && kProbeRestoreJson.isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kProbeSaveError, '', reason: 'bina tasarımı kaydı açılamadı');
    kProbeSaveRoundtrip = true;
    for (var i = 0; i < 40 && kProbeSaveRoundtrip; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final recapturedDesignWorld = Map<String, dynamic>.from(
      jsonDecode(kProbeWorldJson) as Map<String, dynamic>,
    );
    final recapturedHouse = (recapturedDesignWorld['buildings'] as List)
        .cast<Map>()
        .firstWhere((b) => b['type'] == 'woodenHouse');
    expect(recapturedHouse['design'], 'terracotta');

    // Kuruluş hastalığı yeniden yüklenince sıradan/riskli hastalığa dönüşmesin;
    // çadır gecesinin günü ve tek-seferlik akış bayrağı da korunmalı.
    final illnessWorld = Map<String, dynamic>.from(
      jsonDecode(baseline) as Map<String, dynamic>,
    );
    illnessWorld['foundingTentsReadyDay'] = 2;
    illnessWorld['foundingTentIllnessTriggered'] = true;
    illnessWorld['foundingFirstNightFastForwarded'] = true;
    illnessWorld['specialistOffersClaimed'] = 2;
    (illnessWorld['knownCrafts'] as List).removeWhere(
      (craft) => craft == 'mining' || craft == 'fishing' || craft == 'trade',
    );
    final tutorialPatient = Map<String, dynamic>.from(
      (illnessWorld['villagers'] as List).first as Map,
    );
    tutorialPatient['sickDays'] = 2.0;
    tutorialPatient['tutorialIllness'] = true;
    (illnessWorld['villagers'] as List)[0] = tutorialPatient;
    kProbeSaveError = 'koşmadı';
    kProbeRestoreJson = jsonEncode(illnessWorld);
    for (var i = 0; i < 40 && kProbeRestoreJson.isNotEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kProbeSaveError, '', reason: 'öğretici hastalık kaydı açılamadı');
    kProbeSaveRoundtrip = true;
    for (var i = 0; i < 40 && kProbeSaveRoundtrip; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    final recapturedIllness = Map<String, dynamic>.from(
      jsonDecode(kProbeWorldJson) as Map<String, dynamic>,
    );
    expect(recapturedIllness['foundingTentsReadyDay'], 2);
    expect(recapturedIllness['foundingTentIllnessTriggered'], isTrue);
    expect(recapturedIllness['foundingFirstNightFastForwarded'], isTrue);
    expect(recapturedIllness['specialistOffersClaimed'], 2);
    final recapturedPatient = Map<String, dynamic>.from(
      (recapturedIllness['villagers'] as List).first as Map,
    );
    expect(recapturedPatient['sickDays'], greaterThan(0));
    expect(recapturedPatient['tutorialIllness'], isTrue);

    for (final transient in const ['walkingToPickup', 'carrying']) {
      final world = Map<String, dynamic>.from(
        jsonDecode(baseline) as Map<String, dynamic>,
      );
      final villager = Map<String, dynamic>.from(
        (world['villagers'] as List).first as Map,
      );
      villager['state'] = transient;
      villager['targetCol'] = -25.0;
      villager['targetRow'] = -25.0;
      (world['villagers'] as List)[0] = villager;

      kProbeSaveError = 'koşmadı';
      kProbeRestoreJson = jsonEncode(world);
      for (var i = 0; i < 40 && kProbeRestoreJson.isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(kProbeSaveError, '', reason: '$transient kayıt açılamadı');

      kProbeSaveRoundtrip = true;
      for (var i = 0; i < 40 && kProbeSaveRoundtrip; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final recaptured = Map<String, dynamic>.from(
        jsonDecode(kProbeWorldJson) as Map<String, dynamic>,
      );
      final restored = Map<String, dynamic>.from(
        (recaptured['villagers'] as List).first as Map,
      );
      // Restore idle'a normalize eder; probe yeniden snapshot alana kadar doğal
      // rutin yeni, güvenli bir hareket başlatabilir. Kalıcı sözleşme porter
      // enum'unun ve bozuk eski hedefin geri gelmemesidir.
      expect(
        restored['state'],
        isNot(anyOf('walkingToPickup', 'carrying')),
        reason: '$transient porter state yeniden canlandı',
      );
      expect(restored['targetCol'], isNot(-25.0));
      expect(restored['targetRow'], isNot(-25.0));
    }
    kProbeOn = false;
  });

  // ── ESKİ KAYIT ────────────────────────────────────────────────────────────
  //
  // Asıl tehlike burada: oyuncunun elindeki kayıt ÖNCEKİ sürümle yazıldı ve
  // bu sürümde eklenen alanları (mühür günü, günce satırının türü) İÇERMİYOR.
  // Yeni bir alan eklerken kolay unutulan şey budur — kendi yazdığın kaydı
  // açmak her zaman çalışır, oyuncununkini açmak çalışmayabilir.

  testWidgets('önceki sürümle yazılmış kayıt açılır (alanlar eksik)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    kProbeOn = true;
    await bootReference(tester);

    // 1) Bu sürümün kaydını al.
    kProbeSaveRoundtrip = true;
    for (var i = 0; i < 40 && kProbeSaveRoundtrip; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kProbeWorldJson, isNotEmpty, reason: 'kayıt alınamadı');

    // 2) Sürümü GERİYE al: bu turda eklenen alanları sök.
    final world = Map<String, dynamic>.from(
      jsonDecode(kProbeWorldJson) as Map<String, dynamic>,
    );
    (world['policies'] as Map).remove('sealedOn'); // mühür günü yoktu
    world.remove('landmarks'); // harita ilgi noktaları henüz yoktu
    world.remove('foundingTentsReadyDay');
    world.remove('foundingTentIllnessTriggered');
    world.remove('foundingFirstNightFastForwarded');
    world.remove('specialistOffersClaimed');
    for (final v in world['villagers'] as List) {
      (v as Map).remove('tutorialIllness');
    }
    for (final b in world['buildings'] as List) {
      (b as Map).remove('design'); // görsel tasarımlar henüz yoktu
    }
    final log = world['storyLog'] as List;
    for (final e in log) {
      (e as Map).remove('k'); // günce satırının türü yoktu
    }
    // Daha da eskisi: günce DÜZ STRING listesiydi (migrasyon dalı).
    final ancient = Map<String, dynamic>.from(world);
    ancient['storyLog'] = [for (final e in log) (e as Map)['text']];

    // 3) İkisini de aç.
    for (final (label, w) in [('önceki sürüm', world), ('en eski', ancient)]) {
      kProbeSaveError = 'koşmadı';
      kProbeRestoreJson = jsonEncode(w);
      for (var i = 0; i < 40 && kProbeRestoreJson.isNotEmpty; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(
        kProbeSaveError,
        '',
        reason: '$label kayıt açılamadı — oyuncunun elindeki kayıt çöker',
      );
      expect(tester.takeException(), isNull, reason: '$label: istisna atıldı');
    }
    kProbeOn = false;
  });
}
