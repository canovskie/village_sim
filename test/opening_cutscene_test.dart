import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/cutscene/cutscene.dart';
import 'package:village_sim/cutscene/cutscene_player.dart';
import 'package:village_sim/systems/founding_choice.dart';

/// AÇILIŞIN KAPI ZİNCİRİ — sinematik artık izlenen bir film değil, iki karar.
///
/// Buradaki risk görsel değil YAPISAL: bir kapı cevabı host'a taşımazsa köy
/// kararsız kurulur (kadro/stok/soyad boşta kalır) ve bu ancak oyunun içinde,
/// dakikalar sonra fark edilir. Ayrıca üç kartlık sıra yatay telefonda taşarsa
/// (referans cihaz iPhone 11 — 896×414) seçenek okunamaz.
void main() {
  /// Kapı UI'ı repliklerin daktilosu bitince belirir; ticker'ı o ana kadar
  /// döndür. [finder] görünür olunca durur (boşuna pump'lamaz).
  ///
  /// TUZAK: oynatıcı dt'yi kare başına 0.05 sn'ye KIRPAR (uzun kare
  /// sıçramasın diye). Yani pump süresini büyütmek sahne saatini hızlandırmaz;
  /// 400 kare = 20 sn sahne. Kapılar ~24 sn'de açıldığı için test, sahneyi
  /// [timeScale] ile hızlandırır (animasyon odası kancası).
  Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 400; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('kapı hiç açılmadı: $finder');
  }

  Future<void> runOpening(WidgetTester tester, Size size) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    FoundingChoice? chosen;
    String? village, house;
    var done = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: CutscenePlayer(
            cutscene: kOpeningCutscene,
            timeScale: 4.0,
            onDone: () => done = true,
            onNameChosen: (v, h) {
              village = v;
              house = h;
            },
            onFoundingChoice: (c) => chosen = c,
          ),
        ),
      ),
    );

    // 1. KAPI — kafilenin yükü. Üç kart çıkar, biri seçilir.
    final card = find.text(
      '${FoundingChoice.all[1].icon}  ${FoundingChoice.all[1].title}',
    );
    await pumpUntil(tester, card);
    for (final c in FoundingChoice.all) {
      expect(
        find.text('${c.icon}  ${c.title}'),
        findsOneWidget,
        reason: 'seçenek ekranda yok: ${c.id}',
      );
      expect(
        find.text(c.cost),
        findsOneWidget,
        reason: 'bedeli görünmeyen seçim karar değildir: ${c.id}',
      );
    }
    // Kapı açıldığında soruyu SON HARFİNE kadar okuyabilmeliyiz. Kapılı
    // çekimde sahne saati daktilonun bitiş anına kırpılır; kayan nokta bir tık
    // aşağı düşerse floor() son karakteri yutar ve Maple soruyu yarım sorar.
    expect(
      find.text(kOpeningCutscene.shots[1].lines.last.text),
      findsOneWidget,
      reason: 'kapı açılırken replik eksik yazılmış',
    );

    await tester.tap(card);
    await tester.pump();
    expect(
      chosen?.id,
      FoundingChoice.all[1].id,
      reason: 'seçim host\'a taşınmadı — köy kararsız kurulur',
    );

    // 2. KAPI — köyün ve hanenin adı. İki alan, tek onay.
    final nameGate = find.byKey(const ValueKey('village_name_field'));
    await pumpUntil(tester, nameGate);
    expect(
      find.byKey(const ValueKey('house_name_field')),
      findsOneWidget,
      reason: 'hane adı alanı yok — kimlik yine rastgele soyada kalır',
    );
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(2));
    await tester.enterText(fields.at(0), 'Pınarköy');
    await tester.enterText(fields.at(1), 'Yılmaz');
    await tester.tap(find.byKey(const ValueKey('founding_name_submit')));
    await tester.pump();
    expect(village, 'Pınarköy');
    expect(house, 'Yılmaz');

    // Son kapı geçildi → sinematik kendiliğinden biter (oyuncu ateş yerine).
    for (var i = 0; i < 200 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done, isTrue, reason: 'son kapıdan sonra sinematik kapanmıyor');
  }

  testWidgets('açılış kapıları masaüstünde cevabı host\'a taşır', (
    tester,
  ) async {
    await runOpening(tester, const Size(1600, 1000));
  });

  testWidgets('açılış kapıları yatay telefonda da taşmadan çalışır', (
    tester,
  ) async {
    // Referans cihaz: iPhone 11 yatay. Üç kartlık sıra burada taşarsa
    // (RenderFlex overflow) test kırılır — seçenek okunamaz hâle gelir.
    await runOpening(tester, const Size(896, 414));
  });

  testWidgets('mobil ad rayı klavye açılınca sahneyi ezmeden incelir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(896, 414);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          resizeToAvoidBottomInset: false,
          body: CutscenePlayer(
            cutscene: Cutscene([kOpeningCutscene.shots.last]),
            timeScale: 6,
            onDone: () {},
            onNameChosen: (_, _) {},
          ),
        ),
      ),
    );

    final field = find.byKey(const ValueKey('village_name_field'));
    await pumpUntil(tester, field);
    final dock = find.byKey(const ValueKey('mobile_name_dock'));
    expect(tester.getSize(dock).height, lessThan(150));
    expect(find.byKey(const ValueKey('mobile_name_header')), findsOneWidget);

    // iPhone yatay klavyesi: body tam kadraj kalır, ray inset kadar yukarı
    // çıkar ve başlığı bırakarak yalnız girişleri taşır.
    tester.view.viewInsets = const FakeViewPadding(bottom: 180);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('mobile_name_header')), findsNothing);
    expect(tester.getSize(dock).height, lessThan(90));
    expect(tester.getBottomLeft(dock).dy, lessThanOrEqualTo(234));
    expect(find.byType(TextField), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sinematik ATLANIRSA hiçbir kapı cevabı uydurulmaz', (
    tester,
  ) async {
    // Atlayan oyuncunun kararını host varsayılana çevirir (bkz.
    // _onCutsceneDone); oynatıcı burada kendi kafasına göre bir seçim
    // GÖNDERMEMELİ — yoksa iki taraf ayrı kadro kurar.
    FoundingChoice? chosen;
    var done = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CutscenePlayer(
            cutscene: kOpeningCutscene,
            onDone: () => done = true,
            onNameChosen: (_, _) {},
            onFoundingChoice: (c) => chosen = c,
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.text('Atla ▸'));
    await tester.pump();
    expect(done, isTrue);
    expect(chosen, isNull);
  });
}
