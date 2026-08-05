// İNŞA KÜNYESİ — çizim dumanı testi.
//
// Hafızadaki ders: bir panel "çalışmıyor" derken çoğu kez GERÇEK bir render
// bug'ı vardır (non-uniform Border + borderRadius assert'i, Stack çökmesi,
// taşma). Künye iki farklı yerleşimde çizilir (masaüstü kartı / telefon
// şeridi) ve üç farklı durumda (avantaj kazanıldı / kaçtı / kural ihlali) —
// hepsinin gerçekten çizildiğini burada kilitliyoruz.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_lore.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/ui/building_brief.dart';

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  Size size = const Size(1280, 800),
}) async {
  // setSurfaceSize bir sonraki kareye kadar MediaQuery'ye YANSIMIYOR (ölçtük:
  // aynı karede hâlâ 800×600 okunuyor) — künyenin mobil/masaüstü ayrımı ölçüye
  // bağlı olduğu için view'ı doğrudan kuruyoruz.
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: Align(alignment: Alignment.bottomLeft, child: child),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 250));
  expect(tester.takeException(), isNull);
}

void main() {
  testWidgets('masaüstü: künye başlık + ipuçları + tatlı notla çizilir',
      (tester) async {
    await _pump(
      tester,
      const BuildingBrief(
        type: BuildingType.tent,
        facts: SiteFacts(
            hearthWarmth: 1.0, hasHearth: true, hearthLit: true, homesNear: 2),
        reason: null,
        noteSeed: 0,
      ),
    );
    expect(find.text('Çadır'), findsOneWidget);
    expect(find.text('NEREYE KURULMALI'), findsOneWidget);
    // Ocağın menzilindeyken avantaj rozeti "sıcak" der.
    expect(find.text('sıcak'), findsOneWidget);
  });

  testWidgets('avantaj kaçınca künye sakin kalır (ceza değil bilgi)',
      (tester) async {
    await _pump(
      tester,
      const BuildingBrief(
        type: BuildingType.tent,
        facts: SiteFacts(hasHearth: true, hearthLit: true),
        reason: null,
        noteSeed: 1,
      ),
    );
    expect(find.text('ocaktan uzak'), findsOneWidget);
  });

  testWidgets('kural ihlali: kırmızı sebep satırı künyenin içinde',
      (tester) async {
    await _pump(
      tester,
      const BuildingBrief(
        type: BuildingType.lumberCamp,
        facts: SiteFacts(),
        reason: 'Yakında ağaç yok — ormana yakın kur',
        noteSeed: 0,
      ),
    );
    expect(find.textContaining('Yakında ağaç yok'), findsOneWidget);
  });

  testWidgets('ölçüm yokken (hayalet haritada değil) ipuçları nötr çizilir',
      (tester) async {
    await _pump(
      tester,
      const BuildingBrief(
        type: BuildingType.beehive,
        facts: null,
        reason: null,
        noteSeed: 0,
      ),
    );
    // Yanlış bir ✓ göstermez: ölçüm rozeti (ör. "6 çiçek · ×2.3") hiç çıkmaz.
    // ("1×1 · 8 odun" başlık satırı ölçüm değil künyenin kimliğidir.)
    expect(find.textContaining('çiçek · ×'), findsNothing);
  });

  testWidgets('telefon: başlıksız ince şerit, ekranı yutmaz', (tester) async {
    // Referans cihaz: iPhone 11 yatay (bkz. mobile_ui).
    await _pump(
      tester,
      const BuildingBrief(
        type: BuildingType.beehive,
        facts: SiteFacts(flowersNear: 6, openTilesNear: 18),
        reason: null,
        noteSeed: 0,
      ),
      size: const Size(896, 414),
    );
    // Ad + maliyet komuta çubuğunda kalır; şeritte başlık yoktur.
    expect(find.text('Arı Kovanı'), findsNothing);
    final box = tester.getSize(find.byType(BuildingBrief));
    expect(box.height, lessThan(120),
        reason: 'telefon şeridi ekranın dörtte birinden fazlasını yemeli değil');
  });
}
