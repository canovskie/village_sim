// KARARIN İZİ PROVASI — gerçek sahnede.
//
// Saf taraf (decision_trace_test) sözleşmeyi doğruladı: kayıt türü yaşıyor,
// şıkların anlatacak cümlesi var, mühür günü damgalanıyor. Bu dosya asıl
// soruyu sorar: KÖYDE gerçekten yazılıyor mu?
//
// Bu tam olarak "kod var ama hiç tetiklenmiyor" sınıfı bir iş: 41 dilekçenin
// 87 şıkkı yıllarca kroniğe hiçbir şey yazmadı ve hiçbir birim testi bunu
// görmedi, çünkü çağrının kendisi yoktu.
//
// Kurulum deseni house_stance_probe_test ile birebir aynı.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/main.dart';
import 'package:village_sim/systems/chronicle.dart';
import 'package:village_sim/ui/village_ledger.dart';

void _noop() {}

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
    kProbeDecisionLines = 0;
    kProbePlainDecisions = 0;
    kProbeLastDecision = '';
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
    // TUZAK: karar telemetrisi _tickProbe içinde yaşar ve o yalnız kProbeOn
    // açıkken koşar. Kapalı bırakılırsa test "karar kaydedilmedi" der; oysa
    // ölçen göz hiç açılmamıştır.
    kProbeOn = true;
    // Karar isteyen OLAY modali simi dondurur; ölçtüğümüz şey dilekçe kararı.
    kProbeNoEvents = true;
    // Vergi heyetinin pazarlık modali de simi dondurur — ölçtüğümüz şey
    // dilekçe kararı, heyet değil.
    kProbeNoImperial = true;

    var waitedMs = 0;
    await tester.runAsync(() async {
      await tester.pumpWidget(const MaterialApp(
        home: VillageScene(referenceVillage: true, slotId: 'decisionTrace'),
      ));
      for (var i = 0; i < 1200 && !kCaptureSceneReady; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 50));
        waitedMs += 50;
      }
    });
    await tester.pump();
    expect(kCaptureSceneReady, isTrue,
        reason: 'referans köy ${waitedMs ~/ 1000} sn içinde kurulamadı — '
            'bu bulgunun karar iziyle ilgisi YOK, sahne hiç ayağa kalkmadı.');
  }

  Future<void> shutdown(WidgetTester tester) async {
    kProbeOn = false;
    kProbeNoEvents = false;
    kProbeNoImperial = false;
    kProbeDecideNow = false;
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

  testWidgets('verilen dilekçe kararı GERÇEKTEN günceye düşer', (tester) async {
    await boot(tester);
    kDevSpeedBoostOverride = 24.0;

    final before = kProbeDecisionLines;

    // Dilekçe gelene kadar bekle, sonra ilk şıkkı seç (oyuncunun kararı gibi).
    // Birkaç karar üst üste verilir: aranan şey BESPOKE sahnesi olmayan bir
    // şıkkın da kaydedilmesi (kProbePlainDecisions) — kendi cümlesini zaten
    // yazan fx'ler (sulh/çağrı/suç hükmü) bu turun eklediği yolu KANITLAMAZ.
    var decided = false;
    for (var i = 0; i < 14 && kProbePlainDecisions == 0; i++) {
      kProbeDecideNow = true;
      await run(tester, 12);
      decided = decided || kProbeDecisionLines > before;
    }

    expect(decided, isTrue,
        reason: kProbePause.isNotEmpty
            ? 'sim donuk ("$kProbePause") — dünya ilerlemedi, bu bulgunun '
                'karar iziyle ilgisi yok'
            : 'karar verildi ama günceye tek satır düşmedi — kararın izi '
                'yalnız uçan bir bildirimde kalıyor '
                '(bekleyen dilekçe: "$kProbePendingPetition")');
    expect(kProbePlainDecisions, greaterThan(0),
        reason: 'yalnız bespoke sahneli kararlar kaydedildi — 87 şıkkın '
            'çoğunu kapsayan sade karar yolu (_chronicleDecision) koşmuyor');
    expect(kProbeLastDecision.trim(), isNotEmpty,
        reason: 'karar satırı boş yazıldı');
    // Kâtip başlık kopyalamamalı: satır ya yazılmış annal ya da şıkkın çözüm
    // cümlesidir; ikisi de yoksa "Başlık: Şık" düşerdi (iki nokta üst üste).
    expect(kProbeLastDecision.length, greaterThan(12),
        reason: 'karar satırı cılız: "$kProbeLastDecision"');

    await shutdown(tester);
  });

  // ── Defterin süzgeci ──────────────────────────────────────────────────────
  //
  // Sahneyi boot etmeye gerek yok: burada sorulan şey simin ne yaptığı değil,
  // defterin karışık bir günceyi AYIRABİLİYOR mu olduğu. Defter salt-okunur
  // bir gösterge, doğrudan kurulur (bkz. ledger_board_layout_test).

  testWidgets('KRONİK süzgeci kararları mevsim satırlarından ayırır',
      (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(const MaterialApp(
      home: VillageLedger(
        identity: 'Karaca Hanesi',
        morale: 0.6,
        population: 12,
        food: 100,
        gold: 40,
        agenda: [],
        houses: [],
        laws: [],
        marks: [],
        onOpenPetition: _noop,
        rosterRows: [],
        onClose: _noop,
        initialSection: LedgerSection.kronik,
        chronicle: [
          ChronicleEntry(
              day: 3, icon: '🌱', text: 'Bahar geldi, tarlalar uyandı.'),
          ChronicleEntry(
              day: 5,
              icon: '⚖',
              text: 'Nöbet başladı. Fenerler geç saate kadar yanıyor.',
              kind: ChronicleKind.decision),
          ChronicleEntry(
              day: 6,
              icon: '🩸',
              text: 'Kavgada kan döküldü.',
              kind: ChronicleKind.crisis),
        ],
      ),
    ));
    await tester.pump();

    // Süzgeçsiz: üçü de görünür.
    expect(find.textContaining('Bahar geldi'), findsOneWidget);
    expect(find.textContaining('Nöbet başladı'), findsOneWidget);
    expect(find.textContaining('Kavgada kan'), findsOneWidget);

    // KARARLAR rafı sayıyı gösterir — panelde yazan sayı, defterdeki satır.
    final chip = find.textContaining('KARARLAR · 1');
    expect(chip, findsOneWidget,
        reason: 'KRONİK süzgecinde KARARLAR rafı yok ya da sayı tutmuyor');

    await tester.tap(chip);
    await tester.pump();

    expect(find.textContaining('Nöbet başladı'), findsOneWidget,
        reason: 'süzgeç kararı da eledi');
    expect(find.textContaining('Bahar geldi'), findsNothing,
        reason: 'süzgeç açıkken yaşam satırı hâlâ görünüyor — kararlar '
            'mevsim annallerinin arasında kaybolmaya devam eder');
    expect(find.textContaining('Kavgada kan'), findsNothing);
  });
}
