// KÖY KENDİ AÇLIĞINA BAKAR — mikro kontrolün geri dönmediğinin nöbetçisi.
//
// Toplayıcı ve aşçı kadrosu uzun süre YALNIZ elle veriliyordu: otomatik hedef
// sıfırdı ve kuruluşun üç görevi oyuncudan tek tek köylüye iş vermesini
// istiyordu. Niyet "oyuncunun ilk kararı"ydı; oyundaki karşılığı her seferlik
// bir angarya oldu — oyuncu atamazsa köy aç kalıyordu.
//
// Bu test o kararın kodda değil DAVRANIŞTA durduğunu doğrular: taze bir köy
// kurulur, kimseye elle iş verilmez, sim akıtılır. Köy kendi eliyle sepeti
// almalı. Biri `_foragerTarget`ı yeniden sıfıra çekerse ya da kadroyu tekrar
// oyuncunun sırtına yıkarsa burası düşer.
//
// Harness deseni living_probe_test'ten: önce runAsync ile sahneyi kur
// (kCaptureSceneReady), sonra fake-clock pump. İkisi aynı anda olmaz.

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
    kFlowDebug = '';
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  /// `toplayıcı=3/2` gibi bir alanın PAYINI oku (atanmış el sayısı).
  /// Alan yoksa -1 → çağıran "teşhis satırı hiç kurulmamış" diyebilsin.
  int assignedOf(String field) {
    final m = RegExp('$field=(\\d+)/(\\d+)').firstMatch(kFlowDebug);
    return m == null ? -1 : int.parse(m.group(1)!);
  }

  int targetOf(String field) {
    final m = RegExp('$field=(\\d+)/(\\d+)').firstMatch(kFlowDebug);
    return m == null ? -1 : int.parse(m.group(2)!);
  }

  int foodOf() {
    final m = RegExp(r'yiyecek=(\d+)').firstMatch(kFlowDebug);
    return m == null ? -1 : int.parse(m.group(1)!);
  }

  testWidgets('kimseye elle iş verilmeden köy sepeti kendi eline alır',
      (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true; // açılış sinematiğini atla + kFlowDebug'ı doldur
    kCaptureSceneReady = false;

    var waitedMs = 0;
    await tester.runAsync(() async {
      // TAZE köy — referans köy değil: kuruluşun ilk dakikası tam olarak
      // burada, elde tek bina yokken sınanmalı.
      await tester.pumpWidget(const MaterialApp(home: VillageScene()));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue,
        reason: 'köy ${waitedMs ~/ 1000} sn içinde kurulamadı — bu testin '
            'kadro davranışıyla ilgisi yok, sahne hiç ayağa kalkmadı');

    // Teşhis satırı akış TARAMASINDA kurulur (0.5 sn sim) — sahne hazır olmak
    // yetmez, ticker'ın fake clock'la birkaç kez dönmesi gerekir.
    for (var i = 0; i < 120 && kFlowDebug.isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(kFlowDebug, isNotEmpty,
        reason: 'akış taraması hiç koşmadı — tick zinciri kurulmamış');

    // Kafile yiyecekle gelir: köy TOK başlar ve bu doğrudur — tok köyün
    // çalıya el yollaması israf olurdu (bkz. kForageComfort).
    expect(targetOf('toplayıcı'), 0,
        reason: 'köy dolu ambarla açılışta çalı yoluyor');

    // Bir günden biraz fazla sim: 5 ağız × 8 yiyecek/gün, ambar ~24 →
    // açlık kaçınılmaz. Hız çarpanı olmadan bu test dakikalar sürerdi.
    kDevSpeedBoostOverride = 16.0;
    var sawForager = false;
    for (var i = 0; i < 1800 && !sawForager; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      if (assignedOf('toplayıcı') > 0) sawForager = true;
    }

    expect(sawForager, isTrue,
        reason: 'köy acıktı ama kimse sepeti almadı — otomatik kadro yeniden '
            'kapatılmış olabilir (scene_jobs `_foragerTarget`). '
            'Son teşhis: $kFlowDebug');
    expect(foodOf(), greaterThan(0),
        reason: 'ambar tamamen boşaldı: kadro açıldı ama iş dönmüyor. '
            'Son teşhis: $kFlowDebug');

    kDevSpeedBoostOverride = 0;
    await tester.pumpWidget(const SizedBox());
  });
}
