// ORTA OYUN DERSLERİ PROVASI — gerçek sahnede.
//
// Katalog sözleşmesi village_lessons_test'te. Buradaki soru başka: ders
// GERÇEKTEN ekrana geliyor mu? Ders penceresi bilerek dar (sinematik, modal,
// Defter, olay banner'ı, kuruluş öğreticisi — hepsi önde) ve bu tür bir kapı
// listesinin en sık görülen sonucu, kapının hiç açılmamasıdır. Öğretmeyen bir
// öğretici, olmayan bir öğreticiden daha kötüdür: yazılmıştır, bakımı yapılır,
// kimse okumaz.

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

    kProbeLessonsArmed = false;
    kProbeLessonsShown = 0;
    kProbeLastLesson = '';
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

    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'lessons'),
      ));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy kurulamadı — bu testin derslerle ilgisi YOK.');
  }

  Future<void> shutdown(WidgetTester tester) async {
    kProbeLessonsArmed = false;
    kProbeNoEvents = false;
    kDevSpeedBoostOverride = 0;
    await tester.pumpWidget(const SizedBox());
  }

  Future<void> run(WidgetTester tester, double seconds) async {
    const stepMs = 16;
    for (var i = 0; i < (seconds * 1000 / stepMs).round(); i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
    }
  }

  testWidgets('ders GERÇEKTEN açılıyor ve kart ekrana çiziliyor',
      (tester) async {
    await boot(tester);
    kProbeLessonsArmed = true;
    kProbeNoEvents = true; // olay banner'ı aynı yeri kullanıyor
    kDevSpeedBoostOverride = 24.0;

    var shown = false;
    for (var i = 0; i < 8 && !shown; i++) {
      await run(tester, 10);
      shown = kProbeLessonsShown > 0;
    }

    expect(shown, isTrue,
        reason: 'oturmuş bir köyde tek bir ders bile açılmadı — ders '
            'penceresi hiçbir zaman açılmıyor demektir '
            '(sim donduysa: "$kProbePause")');

    await tester.pump();
    expect(find.text('KÖYÜN ÂDETİ'), findsOneWidget,
        reason: 'ders "$kProbeLastLesson" tetiklendi ama kart çizilmedi');
    // Kartın asıl işi: ne yapılacağını söylemek.
    expect(find.text('NE YAPABİLİRSİN'), findsOneWidget,
        reason: 'ders kartında eylem bölümü çizilmedi — kart bir tabelaya '
            'dönmüş');
    await shutdown(tester);
  });

  testWidgets('ders bir kez açılır, kapatılınca geri gelmez', (tester) async {
    await boot(tester);
    kProbeLessonsArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;

    for (var i = 0; i < 8 && kProbeLessonsShown == 0; i++) {
      await run(tester, 10);
    }
    expect(kProbeLessonsShown, greaterThan(0));
    final first = kProbeLastLesson;

    // Kapat.
    await tester.pump();
    await tester.tap(find.text('Anladım'));
    await tester.pump();
    expect(find.text('KÖYÜN ÂDETİ'), findsNothing,
        reason: 'kart kapanmadı');

    // Koşuya devam. Aynı ders bir daha AÇILMAMALI — ama koşulları hâlâ
    // sağlanıyor, yani tekrar açılmaması gerçek bir iddia.
    //
    // Kontrol koşullu bir skip DEĞİL: ikinci bir dersin tetiklenip
    // tetiklenmediği köyün o anki hâline bağlı ve bunu teste şart koşarsak
    // test bazen hiçbir şey ölçmez. Her koşuda geçerli olan iddia şu —
    // ekranda kart varsa o kart BAŞKA bir ders olmalı.
    await run(tester, 20);
    final cardUp = find.text('KÖYÜN ÂDETİ').evaluate().isNotEmpty;
    if (cardUp) {
      expect(kProbeLastLesson, isNot(first),
          reason: 'kapatılan ders "$first" yeniden açıldı — "bir kez" kuralı '
              'çalışmıyor, öğretici dırdıra döner');
    } else {
      expect(kProbeLastLesson, first,
          reason: 'ekranda kart yok ama son ders değişmiş: bir ders açılıp '
              'kendiliğinden kaybolmuş (ders okunmadan kaybolmamalı)');
    }
    await shutdown(tester);
  });

  testWidgets('dersler ÜST ÜSTE yığılmaz — aralarında nefes payı var',
      (tester) async {
    await boot(tester);
    kProbeLessonsArmed = true;
    kProbeNoEvents = true;
    kDevSpeedBoostOverride = 24.0;

    // Oturmuş köyde birden çok ders koşulu aynı anda sağlanır. Hepsi arka
    // arkaya patlarsa oyuncu hiçbirini okumaz.
    await run(tester, 25);
    expect(find.text('KÖYÜN ÂDETİ').evaluate().length, lessThanOrEqualTo(1),
        reason: 'aynı anda birden çok ders kartı çizildi');
    await shutdown(tester);
  });
}
