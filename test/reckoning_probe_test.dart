// HESAPLAŞMA PROVASI — gerçek sahnede.
//
// Saf kurallar reckoning_test'te. Buradaki soru başka ve daha önemli: koşu
// GERÇEKTEN bitiyor mu? Bir oyunun sonu, kodda var olup sahnede hiç
// tetiklenmeyen bir şey olabilir — ve o hatayı hiçbir birim testi görmez.
// Kapanışı olmayan bir oyun, kapanışı bozuk olan oyundan daha kötüdür:
// oyuncu bitmeyen bir şeyin içinde kalır ve bunu bir hata olarak değil
// "oyun burada bitiyormuş galiba" diye yaşar.
//
// Kanıtlanan üç şey:
//   1. Berat yılı İLAN ediliyor (haber verilmeden biten koşu yok).
//   2. Hesaplaşma yılında karar VERİLİYOR ve kapanış ekranı ÇİZİLİYOR.
//   3. Ekran karara göre değişiyor (üç sonuç da sahnede üretilebiliyor).

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/village_year.dart';

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

    kProbeReckoningArmed = false;
    kProbeJumpToDay = 0;
    kProbeYear = 0;
    kProbeReckoningHeralded = false;
    kProbeVerdict = '';
    kProbeStanding = 0;
    kProbeNoEvents = false;
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
        home: VillageScene(referenceVillage: true, slotId: 'reckoning'),
      ));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
            'bu testin hesaplaşmayla ilgisi YOK.');
  }

  Future<void> shutdown(WidgetTester tester) async {
    kProbeReckoningArmed = false;
    kProbeJumpToDay = 0;
    kProbeNoEvents = false;
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

  /// İlan/hesaplaşma yılının ilk günü.
  int firstDayOf(int year) => (year - 1) * kDaysPerYear + 1;

  testWidgets('genç köy hesaplaşma duymaz — takvim erken konuşmaz',
      (tester) async {
    await boot(tester);
    kProbeReckoningArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 10);

    expect(kProbeYear, lessThan(kReckoningHeraldYear),
        reason: 'referans köy zaten ilan yılında başlıyorsa bu test bir şey '
            'ölçmüyor demektir');
    expect(kProbeReckoningHeralded, isFalse,
        reason: 'berat yılı vakti gelmeden ilan edildi — takvim anlamsızlaşır');
    expect(kProbeVerdict, isEmpty);
    await shutdown(tester);
  });

  testWidgets('berat yılı İLAN ediliyor — koşu habersiz bitmez',
      (tester) async {
    await boot(tester);
    kProbeReckoningArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 3);

    kProbeJumpToDay = firstDayOf(kReckoningHeraldYear);
    await run(tester, 12);

    expect(kProbeYear, kReckoningHeraldYear);
    expect(kProbeReckoningHeralded, isTrue,
        reason: 'ilan yılına girildi ama köy haber almadı — hesaplaşma '
            'bir yıl sonra sürpriz olarak gelirdi '
            '(sim donduysa: "$kProbePause")');
    // İLAN KARAR DEĞİLDİR: bu yıl boyunca oyun sürmeli.
    expect(kProbeVerdict, isEmpty,
        reason: 'ilan yılında karar verildi — hazırlık penceresi yok oldu');
    await shutdown(tester);
  });

  testWidgets('hesaplaşma yılında karar veriliyor ve kapanış ekranı çiziliyor',
      (tester) async {
    await boot(tester);
    kProbeReckoningArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 3);

    kProbeJumpToDay = firstDayOf(kReckoningYear);
    var judged = false;
    for (var i = 0; i < 8 && !judged; i++) {
      await run(tester, 10);
      judged = kProbeVerdict.isNotEmpty;
    }

    expect(judged, isTrue,
        reason: 'altıncı yıl geldi ama hiçbir karar verilmedi — koşunun sonu '
            'kodda var, sahnede yok (sim donduysa: "$kProbePause")');
    expect(['sancak', 'berat', 'ilhak'], contains(kProbeVerdict));

    // Kapanış ekranı GERÇEKTEN çizilmeli. Karar verip ekranı açmamak,
    // oyuncuyu donmuş bir köyde bırakmak demektir.
    await tester.pump();
    await tester.pump();
    final expectedTitle = switch (kProbeVerdict) {
      'sancak' => 'SANCAK DİKİLDİ',
      'berat' => 'BERAT VERİLDİ',
      _ => 'KÖY İLHAK EDİLDİ',
    };
    expect(find.text(expectedTitle), findsOneWidget,
        reason: 'karar "$kProbeVerdict" verildi ama kapanış ekranı çizilmedi');
    // Karne de orada olmalı: oyuncu sonucu değil GEREKÇEYİ okumalı.
    expect(find.text('DEFTERDE NE YAZIYORDU'), findsOneWidget,
        reason: 'kapanış ekranı gerekçesiz — oyuncu neyi kaçırdığını öğrenemez');
    await shutdown(tester);
  });

  testWidgets('oturmuş köy ilhak edilmez — ölçü köyün gerçek hâlini okur',
      (tester) async {
    await boot(tester);
    kProbeReckoningArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;
    await run(tester, 6);

    // Referans köy oturmuş bir köydür (bkz. scene_reference_village): haneleri
    // yerinde, tüzüğü işleyen. Böyle bir köy ilhak ediliyorsa ölçü köyün
    // hâlini değil başka bir şeyi okuyor demektir.
    expect(kProbeStanding, greaterThan(0.0),
        reason: 'güç ölçüsü sıfır okundu — girdiler sahneye bağlanmamış');

    kProbeJumpToDay = firstDayOf(kReckoningYear);
    for (var i = 0; i < 8 && kProbeVerdict.isEmpty; i++) {
      await run(tester, 10);
    }
    expect(kProbeVerdict, isNot('ilhak'),
        reason: 'oturmuş referans köy ilhak edildi (güç '
            '${kProbeStanding.toStringAsFixed(2)}) — eşikler ya da girdiler '
            'köyün gerçek hâlini yansıtmıyor');

    // DENGE BEKÇİSİ: referans köy ORTALAMA bir köydür, en iyi köy değil.
    // Sancak alıyorsa üst sonuç bedava demektir; oyuncunun altı yılda
    // kazanacağı bir şey kalmaz. (Ölçülen değer 0.61; eşik 0.72.)
    expect(kProbeVerdict, 'berat',
        reason: 'ortalama bir köy "$kProbeVerdict" aldı (güç '
            '${kProbeStanding.toStringAsFixed(2)}). Sancak ortalamanın '
            'belirgin ÜSTÜNDE olmalı, yoksa üst sonuç bedavadır.');
    await shutdown(tester);
  });
}
