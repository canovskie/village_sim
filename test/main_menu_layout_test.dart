// Ana menü YERLEŞİM testi — HİÇBİR ekranda kaydırma yok, her eleman içeride.
//
// Regresyon zemini iki ayrı hatadır:
//  1. Eski hâl dikey tek sütundu (başlık + 8 satır ≈ 800px) ve 390px'lik
//     telefonda kaydırmaya düşüyordu.
//  2. Sonraki hâl telefonu düzeltti ama TABLET (iPad 1180×820) yükseklik
//     eşiğini geçtiği için masaüstü sütununu alıyor, menü ekranın altından
//     taşıp yine kaydırılıyordu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:village_sim/ui/main_menu_screen.dart';
import 'package:village_sim/ui/mobile_ui.dart';

/// Dokunma yerleşiminde ekranda olması gereken her şey.
const _touchLabels = [
  'LUW',
  'DEVAM ET',
  'YENİ KÖY',
  'AYARLAR',
  'HAKKINDA',
];

/// Geliştirici araçları rozete indi — etiketleri Tooltip'te taşınır.
const _devTips = [
  'Referans Köy',
  'Işık Editörü',
  'Ebat Editörü',
  'Animasyonlar',
];

Future<void> _pumpMenu(WidgetTester tester, Size logical) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = logical;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: MainMenuScreen(
        onNewGame: () {},
        onContinue: (_) {},
        onReferenceVillage: () {},
      ),
    ),
  );
  // Ticker sürekli döndüğü için pumpAndSettle KULLANILMAZ — birkaç kare yeter
  // (AppReveal animasyonu bitsin).
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 60));
  }
}

void main() {
  setUp(() {
    // Testte gerçek kayıt dosyası yok; iki kartlı (DEVAM ET'li) en YOĞUN hâli
    // ölçmek istiyoruz.
    MainMenuScreen.debugSavesOverride = true;
    debugForceTouchUi = true;
  });
  tearDown(() {
    MainMenuScreen.debugSavesOverride = null;
    debugForceTouchUi = false;
  });

  for (final size in const [
    Size(844, 390), // iPhone 14 yatay
    Size(932, 430), // iPhone 15 Pro Max yatay
    Size(740, 360), // dar/alçak uç
    Size(1180, 820), // iPad Pro 11" yatay
    Size(1280, 800), // Android tablet
    Size(1024, 768), // iPad mini
  ]) {
    testWidgets(
      'dokunma ${size.width.toInt()}x${size.height.toInt()}: '
      'menünün tamamı kaydırmadan ekranda',
      (tester) async {
        await _pumpMenu(tester, size);

        // 1. Taşma yok (RenderFlex overflow FlutterError atar).
        expect(tester.takeException(), isNull);

        // 2. Kaydırılabilir gövde YOK — her şey zaten ekranda.
        expect(find.byType(Scrollable), findsNothing);

        // 3. Her eleman ekran sınırları İÇİNDE.
        final screen = Offset.zero & size;
        for (final label in _touchLabels) {
          final finder = find.text(label);
          expect(finder, findsOneWidget, reason: '$label görünmüyor');
          final rect = tester.getRect(finder);
          expect(
            screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
            isTrue,
            reason: '$label ekran dışına taşıyor: $rect',
          );
        }

        // 4. Geliştirici araçları rozet olarak duruyor ve dokunma tabanını
        //    (44dp) koruyor.
        for (final tip in _devTips) {
          final finder = find.byTooltip(tip);
          expect(finder, findsOneWidget, reason: '$tip rozeti yok');
          final rect = tester.getRect(finder);
          expect(rect.width, greaterThanOrEqualTo(44.0), reason: tip);
          expect(rect.height, greaterThanOrEqualTo(44.0), reason: tip);
          expect(
            screen.contains(rect.topLeft) && screen.contains(rect.bottomRight),
            isTrue,
            reason: '$tip ekran dışına taşıyor: $rect',
          );
        }
      },
    );
  }

  testWidgets('kayıt yokken tek kart kalır, taşma olmaz', (tester) async {
    MainMenuScreen.debugSavesOverride = false;
    await _pumpMenu(tester, const Size(844, 390));
    expect(tester.takeException(), isNull);
    expect(find.text('DEVAM ET'), findsNothing);
    expect(find.text('YENİ KÖY'), findsOneWidget);
    expect(find.byType(Scrollable), findsNothing);
  });

  testWidgets('masaüstü: tek sütun korunuyor ve KAYDIRMASIZ', (tester) async {
    debugForceTouchUi = false;
    await _pumpMenu(tester, const Size(1280, 900));
    expect(tester.takeException(), isNull);
    // Masaüstü dalı eskiden SingleChildScrollView'du; artık satır yüksekliği
    // kalan boşluktan türetiliyor → kaydırma yok.
    expect(find.byType(Scrollable), findsNothing);
    for (final label in const [
      'YENİ KÖY',
      'REFERANS KÖY',
      'AYARLAR',
      'HAKKINDA',
      'IŞIK EDİTÖRÜ',
      'EBAT EDİTÖRÜ',
      'ANİMASYONLAR',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
  });
}
