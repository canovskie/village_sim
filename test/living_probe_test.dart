// YAŞAYAN KÖY PROVASI — testte.
//
// "Tek tek NPC izleyemem" sorununun CI'da kalıcı cevabı. Gerçek sahneyi kurar,
// hızlandırılmış simüle eder ve köyün dört fazının uçtan uca çalıştığını
// DAVRANIŞTAN doğrular — bir köylüye bakmadan.
//
// TUZAK (Faz 1'de saatler kaybettiren): asset yüklemesi GERÇEK async ister
// (rootBundle → codec), ticker ise FAKE-clock pump ister. İkisi aynı anda
// olmaz. Çözüm: önce runAsync ile köyü kur (kCaptureSceneReady'i bekle), SONRA
// pump(dt) ile ticker'ı sür. Ses eklentisi (audioplayers) testte yok →
// kanalları mock'la, yoksa MissingPluginException gürültü yapar.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/crime_system.dart';

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

    // Prova global'lerini sıfırla — testler arası sızıntı olmasın.
    kProbeOn = false;
    kProbeTriggerCrime = false;
    kCaptureCrimeKind = null;
    kProbeForceBirth = false;
    kProbeBirths = 0;
    kProbeTheftTaken = 0;
    kProbeLootRecovered = 0;
    kProbePlantLoot = false;
    kProbeLootCount = 0;
    kProbeLootTotal = 0;
    kProbeReport = '';
    kProbeReportSeq = 0;
    kDevSpeedBoostOverride = 0;
    kCaptureMode = false;
  });

  /// Sahneyi kur, asset'lerin yüklenip referans köyün dikilmesini bekle
  /// (runAsync), sonra fake-clock'a dön. Dönüşte sahne hazır ve ticker çalışıyor.
  Future<void> boot(WidgetTester tester) async {
    // HUD test penceresine sığmıyor (overflow assert = gürültü). Yüzeyi
    // büyüt — davranış testinin çizim taşmasıyla işi yok.
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    kCaptureMode = true;
    kProbeOn = false;
    kMindTelemetryOn = true;
    kMindDistance = 0;
    kMindDistinctIntents = 0;
    kMindOldestIntent = 0;
    kProbeTriggerCrime = false;
    kDevSpeedBoostOverride = 0;
    // ŞART: kCaptureSceneReady bir GLOBAL — önceki testten true kalırsa
    // aşağıdaki bekleme döngüsü hemen çıkar ve YENİ sahne hazır olmadan tick
    // denenir (0 rapor). Her boot'ta sıfırla.
    kCaptureSceneReady = false;

    // TUZAK — BU DOSYANIN TEK FLAKY KAYNAĞIYDI (2026-07-31):
    // kurulum süresi DUVAR SAATİNE bağlı (asset decode + referans köyün
    // dikilmesi), ama beklemenin bütçesi 8 sn sabitti. Tam süit paralel
    // koştuğunda (ya da makine meşgulken) kurulum bu bütçeye sığmıyor, döngü
    // SESSİZCE çıkıyor ve test BOŞ bir sahneyi pump'lıyordu: köylü yok →
    // suç kurulamıyor → "fail binaya hiç girmedi" / "çuvalla çıkmadı" gibi
    // suçla hiç ilgisi olmayan yerlerden düşüyordu. Tek başına koşunca hep
    // geçmesinin sebebi de buydu.
    // İki kapı: bütçe cömert (60 sn) + çıkış GÜRÜLTÜLÜ (aşağıdaki expect).
    // Kurulum gerçekten kilitlenirse test yine düşer, ama doğru cümleyle.
    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'probe'),
      ));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();

    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
            'asset yükleme ya da kurulum takıldı. Bu testin sim davranışıyla '
            'ilgisi YOK: sahne hiç ayağa kalkmadı.');
  }

  /// Sahneyi kapat — State.dispose (ticker + timer iptali). HER testin sonunda
  /// çağrılmalı, yoksa canlı sahnenin timer'ları sonraki teste sızıp
  /// `!timersPending` düşürür (test kirlenmesi).
  Future<void> shutdown(WidgetTester tester) async {
    kProbeOn = false;
    kDevSpeedBoostOverride = 0;
    await tester.pumpWidget(const SizedBox());
  }

  /// Fake-clock ile [seconds] wall-clock kadar tick sür. Sahne dt'yi hız
  /// çarpanıyla ölçekler; boost yüksek → az pump'la çok sim zamanı.
  Future<void> run(WidgetTester tester, double seconds) async {
    const stepMs = 16;
    final steps = (seconds * 1000 / stepMs).round();
    for (var i = 0; i < steps; i++) {
      await tester.pump(const Duration(milliseconds: stepMs));
    }
  }

  testWidgets('köy kurulur ve sim döner (temel canlılık)', (tester) async {
    await boot(tester);
    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy kurulamadı — asset/kurulum takıldı');

    kDevSpeedBoostOverride = 12.0; // hızlandır
    await run(tester, 12);

    // NOT: `takeException isNull` BİLEREK yok. Test ortamında PNG asset'leri
    // bundle'da değil (renderer'lar sessizce atlar) — bu köyün DAVRANIŞINI
    // etkilemez, yalnız çizimi. Test davranışı doğrular, çizimi değil.
    //
    // Donmuş köy de pırıl pırıl çizilir; tek dürüst kanıt kat edilen yol.
    expect(kMindDistance, greaterThan(3.0),
        reason: 'köy yol kat etmedi — hakem kilitlenmiş olabilir');
    expect(kMindDistinctIntents, greaterThan(1),
        reason: 'herkes tek niyette toplandı');
    await shutdown(tester);
  });

  testWidgets('niyet kilitlenmez — uzun koşuda en eski niyet makul kalır',
      (tester) async {
    await boot(tester);
    kDevSpeedBoostOverride = 16.0;
    await run(tester, 20);
    // Güvenlik ağı niyetleri günün çeyreğinde düşürür; "ölümsüz" bir niyet
    // olmamalı — bolca pay bırakıyoruz.
    expect(kMindOldestIntent, lessThan(400.0),
        reason: 'bir niyet ${kMindOldestIntent.toStringAsFixed(0)} sn '
            'değişmedi — kilitlenme');
    await shutdown(tester);
  });

  // İZLEME TESTİ — bu test bir şeyi "geçmez/kalmaz" için değil, köyün
  // DAVRANIŞINI GÖZLEMEK için. Çalıştır:
  //   flutter test test/living_probe_test.dart --name izle
  // Köyün birkaç günlük davranış raporunu + tetiklenmiş bir suçun tanık
  // zincirini stdout'a basar. Sayıların oturup oturmadığını buradan okursun.
  testWidgets('izle: köyün davranış raporu', (tester) async {
    await boot(tester);
    kProbeOn = true;
    kDevSpeedBoostOverride = 28.0; // yoğun rapor için hızlı

    var lastSeq = -1;
    var reports = 0;
    // 50ms adım × 28× → pump başına ~1.4 sim-sn; ~1800 pump ≈ 2500 sim-sn ≈
    // 10 oyun günü. Rapor aralığı 0.43 gün → ~23 rapor ve örnek noktası her
    // turda kayar, yani döküm günün TÜM saatlerini tarar (bkz. scene_probe
    // `_kProbeInterval` — yarım günlük eski aralık hep aynı iki saate düşüyordu).
    for (var i = 0; i < 1800; i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (kProbeReportSeq != lastSeq && kProbeReport.isNotEmpty) {
        lastSeq = kProbeReportSeq;
        reports++;
        // ignore: avoid_print
        print(kProbeReport);
        // Köy oturduktan sonra her rapor bir suç dener → tanık/dedikodu/ihbar
        // zincirinin biriktiğini SAYAÇ satırında izle.
        if (reports >= 2) {
          kProbeTriggerCrime = true;
          // Suçların YARISINI hırsızlığa zorla. Rastgele seçimde 10 tür
          // içinden nadiren çıkıyor ve Faz 4'ün sahnesi (gir → çuval → göm)
          // dökümde hiç görünmüyordu — "yazıldı ama kimse görmedi" hâli.
          // Diğer yarısı rastgele kalsın ki döküm tek suça daralmasın.
          kCaptureCrimeKind = reports.isEven ? CrimeKind.theft : null;
          // ignore: avoid_print
          print('  ↪ [suç denendi — SAYAÇ satırında tanıklık/ihbar birikmeli]');
        }
      }
    }

    // ignore: avoid_print
    print('\n═══ ÖZET ═══ kat edilen yol '
        '${kMindDistance.toStringAsFixed(0)} tile · '
        '$reports rapor · farklı niyet(son) $kMindDistinctIntents');

    await shutdown(tester);

    expect(reports, greaterThan(6),
        reason: 'köy yeterince rapor üretmedi — sim çok yavaş ya da donuk');
  });

  // DOĞUM YOLU — bu testin var olma sebebi bir kör nokta.
  //
  // Referans köyde boş yatak yok → 34 sim gününde tek doğum olmuyor, yani
  // `_tickReproduction`'ın doğuran yarısı HİÇBİR testte koşmuyordu. Orada
  // `_villagers` üstünde iterasyon sürerken `_villagers.add` çağıran bir
  // ConcurrentModificationError vardı: her doğum, o tick'in geri kalanını
  // (iş dağıtımı, tarla büyümesi, göç, kamera takibi) sessizce düşürüyordu.
  // Oyun görünürde dönmeye devam ettiği için gözle fark edilmiyordu.
  //
  // Test doğumu ZORLAR (kProbeForceBirth) ve sonra köyün hâlâ tick attığını
  // arar — exception yutulsa bile donmuş bir sim yakalanır.
  testWidgets('doğum tick zincirini düşürmez (CME regresyonu)', (tester) async {
    await boot(tester);
    kProbeBirths = 0;
    // ŞART: doğum bildirim/başarım modalı açabilir ve sim'i KALICI dondurur
    // (harness'te kapatacak oyuncu yok). Bastırma `kProbeOn`'a bağlı — bu
    // olmadan test kendi kurduğu donmayı fix'in hatası sanır.
    kProbeOn = true;

    kDevSpeedBoostOverride = 12.0;
    kProbeForceBirth = true;
    await run(tester, 6);

    expect(kProbeBirths, greaterThan(0),
        reason: 'doğum hiç olmadı — test kendi iddiasını sınamıyor, '
            'kProbeForceBirth kapısı kopmuş olabilir');
    expect(tester.takeException(), isNull,
        reason: 'doğum sırasında exception — ConcurrentModificationError geri geldi');

    // Exception yutulmuş olabilir; asıl kanıt köyün doğumdan SONRA hâlâ
    // yürüyor olması (CME tick'in kalanını düşürürdü).
    final distAfterBirth = kMindDistance;
    await run(tester, 6);
    expect(kMindDistance, greaterThan(distAfterBirth),
        reason: 'doğumdan sonra köy yol kat etmedi — tick zinciri kopmuş');

    await shutdown(tester);
  });

  // FAZ 4 — HIRSIZLIĞIN TAM SAHNESİ.
  //
  // Eskiden hırsızlık şuydu: fail kapının önünde `idleTimer` kadar dikilir,
  // ambardan bir sayı düşer, kaçar. "Hırsızlık komik görünüyor" şikâyetinin
  // birebir tarifi. Sahne artık dört ânı geçmeli ve bu test o dördünü de
  // DAVRANIŞTAN doğrular — ekrana bakmadan:
  //   1) fail binaya girer (sprite kaybolur: isInsideBuilding)
  //   2) elinde ÇUVALLA çıkar (görünür yük + yavaşlama)
  //   3) zulayı gömer (mal buharlaşmaz, toprağa geçer)
  //   4) mal geri alınabilir kalır (stok + zula toplamı korunur)
  testWidgets('hırsızlık tam sahne: gir → çuval → göm', (tester) async {
    await boot(tester);
    kProbeOn = true;
    kDevSpeedBoostOverride = 6.0;
    // Muhafızsız köy: yakalanma zinciri BAŞKA testin konusu, burada sahnenin
    // kendisi ölçülüyor. Muhafız yakalarsa fail hiç gömmeye varamaz.
    kCaptureNoGuard = true;
    kCaptureCrime = true;
    kCaptureCrimeKind = CrimeKind.theft;
    addTearDown(() {
      kCaptureNoGuard = false;
      kCaptureCrime = false;
      kCaptureCrimeKind = null;
    });

    // Pencere BOL tutulur (1800 pump × 50ms × 6 boost ≈ 540 sim-sn): tek bir
    // hırsızlık denemesi yarıda kalabilir (fail uyur, ölür, mal biter) —
    // `kCaptureCrime` bir sonrakini kurar, ama bunun için sim zamanı gerek.
    // Dar pencere, sahnenin bozukluğunu değil şansı ölçerdi. Döngü ikisini de
    // görünce ERKEN çıkar; bolluk yalnız kötü günde bedel öder.
    var sawInside = false, sawSack = false;
    for (var i = 0; i < 1800 && !(sawInside && sawSack); i++) {
      await tester.pump(const Duration(milliseconds: 50));
      if (kProbeTheftInside) sawInside = true;
      if (kProbeTheftSack) sawSack = true;
    }

    expect(sawInside, isTrue,
        reason: 'fail binaya hiç girmedi — sahne eski "kapıda dikilme" hâlinde');
    expect(sawSack, isTrue,
        reason: 'fail çuvalla çıkmadı — çalınan mal görünür yük olmadı');

    // Gömmeye kadar sür.
    for (var i = 0; i < 1800 && kProbeLootCount == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(kProbeLootCount, greaterThan(0),
        reason: 'zula gömülmedi — çalınan mal dünyada bir yere geçmedi');

    // MALIN KORUNUMU — Faz 4'ün asıl sözleşmesi: hırsızlık bir sayı düşüşü
    // değil, malın YER DEĞİŞTİRMESİ. Çalınan her birim ya toprakta durur ya da
    // geri alınmıştır; hiçbiri buharlaşmaz.
    //
    // Ham stok toplamıyla ölçülemez: köyün ekonomisi paralel dönüyor (köylü
    // yiyor, işçi üretiyor) → o sayı hırsızlıktan bağımsız oynar. Bu yüzden
    // korunum hırsızlık alt-sistemine özel sayaçlarla sınanır.
    expect(kProbeTheftTaken, greaterThan(0),
        reason: 'hiç mal çalınmadı — test kendi iddiasını sınamıyor');
    expect(kProbeLootTotal + kProbeLootRecovered, kProbeTheftTaken,
        reason: 'mal buharlaştı — çalınan miktar ne toprakta ne ambarda');

    await shutdown(tester);
  });

  // ZULANIN GERİ ALINMASI — Faz 4'ün "gömmek bir jest değil, bir YER"
  // sözleşmesinin ikinci yarısı.
  //
  // Organik köyde hırsız zulayı çoğu kez GÖRÜLMEDEN gömer ve iz kapanır; mal
  // fiilen kaybolur. Bu doğru davranış (görülmeden gömen kazanır) ama şu riski
  // taşır: bulunma+iade yolu hiç koşmaz ve kimse fark etmeden ölü kod olur —
  // bu projede tam olarak bunun için "bağlanmayan alan eklenmez" kuralı var.
  // Test o yolu meydana görülmüş bir zula gömerek zorlar.
  testWidgets('gömülü zula bulunur ve mal ambara döner', (tester) async {
    await boot(tester);
    kProbeOn = true;
    kDevSpeedBoostOverride = 6.0;

    kProbePlantLoot = true;
    // NOT: "gömüldü" ânı gözlenmeye çalışılmaz. Meydana görülmüş bir zula
    // gömülünce çevredeki köylüler onu ÇOĞU KEZ ilk taramada buluyor; count>0
    // penceresi tek tick bile sürmeyebiliyor. Ölçülecek şey zincirin sonucu:
    // mal ambara döndü mü.
    for (var i = 0; i < 1200 && kProbeLootRecovered == 0; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    expect(kProbeLootRecovered, 10,
        reason: 'meydana gömülü GÖRÜLMÜŞ zula bulunup ambara dönmedi — '
            'bulma/iade yolu (_tickLoot → _uncoverLoot) fiilen ölü');
    expect(kProbeLootCount, 0,
        reason: 'zula geri alındı ama toprakta duruyor görünüyor');

    await shutdown(tester);
  });
}
