// HANE KARŞILIĞI PROVASI — gerçek sahnede.
//
// Saf merdiven (house_stance_test) ve motor (house_stash_test) ayrı ayrı
// doğrulandı. Bu dosya asıl soruyu sorar: KÖYDE gerçekten oluyor mu?
// "Yapıldı ama canlı görülmedi" en pahalı hata türü — merdivenin dört kolu
// (emek/ürün/nikâh/masa) canlı simde döndüğü DAVRANIŞTAN doğrulanır.
//
// Kurulum deseni living_probe_test ile birebir aynı (asset yüklemesi runAsync,
// ticker fake-clock; ikisi aynı anda olmaz).

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
    // KAYBETME EŞİĞİ bayraklarını da sıfırla — bunlar GLOBAL. collapse_probe
    // koşusundan sızan `kProbeCollapseArmed`/`kProbeDrainVillage` bu köyü
    // dağıtıyor, sim donuyor ve test ambarın akmamasını hane karşılığının
    // hatası sanıyordu. (Tek başına geçip süitte düşmesinin sebebi buydu.)
    kProbeCollapseArmed = false;
    kProbeForceSchism = false;
    kProbeSchismHouse = '';
    kProbeDrainVillage = false;
    kProbeCollapsed = false;
    kProbeHousesLeft = 0;
    kProbeHouseWithhold = false;
    kProbeHouseAppease = false;
    kProbeHouseName = '';
    kProbeHousesWithholding = 0;
    kProbeHouseStash = 0;
    kProbeHouseReleased = 0;
    kProbeHouseIdled = 0;
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
    // Prova köyünde olay/heyet yok: ölçtüğümüz şey hane karşılığı, dış karar
    // akışları değil.
    kProbeNoEvents = true;
    kProbeNoImperial = true;

    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(
        const MaterialApp(
          home: VillageScene(referenceVillage: true, slotId: 'houseStance'),
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
      reason:
          'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
          'bu testin hane karşılığıyla ilgisi YOK, sahne hiç ayağa kalkmadı.',
    );
  }

  Future<void> shutdown(WidgetTester tester) async {
    kProbeHouseWithhold = false;
    kProbeHouseAppease = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
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

  testWidgets('küstürülen hane GERÇEKTEN elini çeker ve ürününü saklar', (
    tester,
  ) async {
    await boot(tester);
    kDevSpeedBoostOverride = 14.0;

    // Sakin köy: kimse bir şey esirgemiyor olmalı.
    await run(tester, 4);
    expect(
      kProbeHousesWithholding,
      0,
      reason:
          'oturmuş referans köyde esirgeyen hane olmamalı — merdiven '
          'kendiliğinden tırmanıyorsa eşikler çok alçak',
    );

    // En nüfuzlu haneyi küstür.
    kProbeHouseWithhold = true;
    await run(tester, 8);

    expect(kProbeHouseName, isNotEmpty, reason: 'küstürülecek hane bulunamadı');
    expect(
      kProbeHousesWithholding,
      greaterThan(0),
      reason:
          'hane küstürüldü ama hiçbir şey esirgemiyor — merdiven '
          'canlı simde dönmüyor',
    );
    expect(
      kProbeHouseIdled,
      greaterThan(0),
      reason: 'EMEK kolu ölü: hane elini çekti ama kimse işten çekilmedi',
    );

    // Ürün kolu: saklanan yiyecek zamanla birikmeli.
    await run(tester, 25);
    expect(
      kProbeHouseStash,
      greaterThan(0),
      reason:
          'ÜRÜN kolu ölü: esirgeyen hane hiçbir şey saklamadı '
          '(yiyecek girişleri _deliverFoodFrom üzerinden geçmiyor olabilir)',
    );

    await shutdown(tester);
  });

  testWidgets('gönlü alınan hane işine ve ambarına geri döner', (tester) async {
    await boot(tester);
    kDevSpeedBoostOverride = 14.0;

    kProbeHouseWithhold = true;
    await run(tester, 25);
    final stashed = kProbeHouseStash;
    expect(
      kProbeHousesWithholding,
      greaterThan(0),
      reason: 'ön koşul kurulamadı — hane esirgemeye başlamadı',
    );

    // Hüküm: gönlünü al (dilekçenin "Gönüllerini al" seçeneğiyle aynı yol).
    kProbeHouseAppease = true;
    await run(tester, 10);

    expect(
      kProbeHousesWithholding,
      0,
      reason:
          'gönlü alınan hane hâlâ esirgiyor — hüküm merdivenden en az '
          'iki basamak indirmeli, yoksa karar anlamsız olur',
    );
    expect(
      kProbeHouseIdled,
      0,
      reason: 'hane razı oldu ama üyeleri hâlâ işe çıkmıyor',
    );

    // Ambar geri akar (kademeli — bir çırpıda değil).
    //
    // Anlık stash fotoğrafı yeterli değil: 14× hızda 20 gerçek saniye yaklaşık
    // 4,7 oyun günü eder. Hane ürünü geri verip çok sonra yeniden küserse stash
    // tekrar büyüyebilir. Tek doğruluk kaynağı köy ambarına gerçekten dönen
    // kümülatif miktardır.
    if (stashed > 0) {
      var drained = false;
      for (var i = 0; i < 8 && !drained; i++) {
        await run(tester, 20);
        drained = kProbeHouseReleased > 0;
      }
      expect(
        drained,
        isTrue,
        reason: kProbePause.isNotEmpty
            ? 'sim donuk ("$kProbePause") — dünya ilerlemedi, bu bulgunun '
                  'hane karşılığıyla ilgisi yok'
            : 'razı hane ambarını açmadı (saklı $stashed → '
                  '$kProbeHouseStash, dönen $kProbeHouseReleased) — '
                  'barışın karşılığı görünmüyor',
      );
    }

    await shutdown(tester);
  });
}
