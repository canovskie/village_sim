// KAYBETME EŞİĞİ PROVASI — gerçek sahnede.
//
// Saf kurallar village_collapse_test'te. Burada asıl soru: köy GERÇEKTEN
// dağılıyor mu, ayrılık GERÇEKTEN oluyor mu, ve en önemlisi — kayıp haber
// verilerek mi geliyor? Bir game-over'ın en pahalı hatası sessiz gelmesidir.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/village_collapse.dart';

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

    kProbeCollapseArmed = false;
    kProbeNoEvents = false;
    kProbeForceSchism = false;
    kProbeSchismHouse = '';
    kProbeDrainVillage = false;
    kProbeVitality = '';
    kProbeCollapseDaysLeft = -1;
    kProbeCollapsed = false;
    kProbeHousesLeft = 0;
    kProbeAdults = 0;
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  Future<void> boot(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kCaptureSceneReady = false;

    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'collapse'),
      ));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
            'bu testin kaybetme eşiğiyle ilgisi YOK.');
  }

  Future<void> shutdown(WidgetTester tester) async {
    kProbeCollapseArmed = false;
    kProbeNoEvents = false;
    kProbeSchismHouse = '';
    kProbeDrainVillage = false;
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

  testWidgets('sağlıklı köy kendiliğinden dağılmaz', (tester) async {
    await boot(tester);
    kProbeCollapseArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 30);

    expect(kProbeCollapsed, isFalse,
        reason: 'oturmuş köy kendiliğinden dağılıyorsa eşikler yanlış — '
            'kayıp bir kaza değil, bir sonuç olmalı');
    expect(kProbeVitality, VillageVitality.healthy.name);
    await shutdown(tester);
  });

  testWidgets('kopmuş hane köyü terk eder (ayrılık)', (tester) async {
    await boot(tester);
    kProbeCollapseArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 5);

    kProbeForceSchism = true;
    // Sayaç eşiğin %80'ine kuruldu; kalan süre için koştur.
    var left = false;
    for (var i = 0; i < 6 && !left; i++) {
      await run(tester, 15);
      left = kProbeHousesLeft > 0;
    }
    expect(left, isTrue,
        reason: 'kopuşta kalan hane köyü terk etmedi — ayrılık kolu ölü '
            '(sim donduysa: "$kProbePause")');
    await shutdown(tester);
  });

  testWidgets('köy dağılır: geri sayım GÖRÜNÜR, sonra defter kapanır',
      (tester) async {
    await boot(tester);
    kProbeCollapseArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 5);

    // Köyü kritik banda indir.
    kProbeDrainVillage = true;
    await run(tester, 8);

    // ÖNCE UYARI: geri sayım görünür olmalı — sessiz ölüm yok.
    expect(kProbeVitality, VillageVitality.failing.name,
        reason: 'köy kritik banda indi ama evre değişmedi '
            '(yetişkin: $kProbeAdults, eşik: $kFailingAdults)');
    expect(kProbeCollapseDaysLeft, greaterThan(0),
        reason: 'geri sayım görünmüyor — oyuncu uyarılmadan kaybediyor');
    expect(kProbeCollapsed, isFalse,
        reason: 'köy uyarı vermeden dağılmamalı');

    // SONRA DAĞILMA: süre dolunca defter kapanır.
    var dead = false;
    for (var i = 0; i < 6 && !dead; i++) {
      await run(tester, 15);
      dead = kProbeCollapsed;
    }
    expect(dead, isTrue,
        reason: 'geri sayım doldu ama köy dağılmadı '
            '(sim donduysa: "$kProbePause")');

    // Mezar taşı ekranı gerçekten çizilmeli.
    await tester.pump();
    expect(find.text('KÖY DAĞILDI'), findsOneWidget,
        reason: 'köy dağıldı ama kapanış ekranı çizilmedi');
    await shutdown(tester);
  });
}
