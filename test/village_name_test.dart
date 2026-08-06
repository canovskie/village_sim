import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_names.dart';
import 'package:village_sim/cutscene/cutscene.dart';
import 'package:village_sim/cutscene/cutscene_player.dart';
import 'package:village_sim/text/village_names.dart';
import 'package:village_sim/text/voice.dart';

/// KÖYÜN ADI bir etiket değil, kullanılan bir addır.
///
/// Buradaki riskler sessizdir: (1) ad havuzu soyad havuzuyla çakışırsa köyün
/// adı ile kurucu hanenin adı aynı kelime olur ve metinler okunamaz hâle gelir;
/// (2) ad ekranda BÜYÜK harfe çevrilirken Türkçe "i" noktasını kaybeder
/// ("DEĞIRMENLI"); (3) ada ek gelirken ünlü uyumu bozulursa ad her cümlede
/// yamalı durur. Üçü de derlemeyi kırmaz, yalnız metni ucuzlatır.
void main() {
  group('ad havuzu', () {
    test('hiçbir köy adı hane (soy) adı havuzuyla çakışmaz', () {
      // Aynı kelime iki rolde geçerse "Akpınar, Akpınar Hanesi'ni dinledi"
      // cümlesi çıkar; oyuncu köy ile haneyi ayırt edemez.
      final surnames = {
        for (var i = 0; i < 400; i++)
          randomVillagerSurname(Random(i)).toLowerCase(),
      };
      for (final idea in kVillageNameIdeas) {
        expect(surnames.contains(idea.name.toLowerCase()), isFalse,
            reason: '${idea.name} hem köy hem hane adı olabiliyor');
      }
    });

    test('her adın bir gerekçesi var ve gerekçe cümle gibi okunur', () {
      for (final idea in kVillageNameIdeas) {
        expect(idea.name.trim(), isNotEmpty);
        expect(idea.meaning.trim().length, greaterThan(20),
            reason: '${idea.name}: gerekçe tek kelimeye düşmüş');
        expect(idea.meaning.trim(), endsWith('.'));
      }
    });

    test('ad havuzunda tekrar yok', () {
      final names = kVillageNameIdeas.map((e) => e.name.toLowerCase()).toList();
      expect(names.toSet().length, names.length);
    });

    test('yazılan ad havuzdaysa gerekçesi bulunur, değilse sessiz kalır', () {
      expect(meaningOfVillageName('Pınarbaşı'), isNotNull);
      expect(meaningOfVillageName('  pınarbaşı '), isNotNull);
      expect(meaningOfVillageName('Kaynarköy'), isNull);
      expect(meaningOfVillageName(''), isNull);
    });
  });

  group('adın yazımı', () {
    test('Türkçe büyük harf "i"nin noktasını korur', () {
      expect(upperTr('Değirmenli'), 'DEĞİRMENLİ');
      expect(upperTr('Çiğdemli'), 'ÇİĞDEMLİ');
      // "ı" da noktasız kalmalı — ters yönde bozulma da hata.
      expect(upperTr('Pınarbaşı'), 'PINARBAŞI');
    });

    test('havuzdaki her ad ek aldığında ünlü uyumuna uyar', () {
      // Ad her cümlede çekimli geçiyor ({köy-e}, {köy-in}); havuza yeni bir ad
      // eklenince buradan geçmeli.
      expect(withSuffix('Pınarbaşı', Suffix.dative), "Pınarbaşı'ya");
      expect(withSuffix('Pınarbaşı', Suffix.genitive), "Pınarbaşı'nın");
      expect(withSuffix('Ovacık', Suffix.locative), "Ovacık'ta");
      expect(withSuffix('Ovacık', Suffix.dative), "Ovacık'a");
      expect(withSuffix('Taşköprü', Suffix.genitive), "Taşköprü'nün");
      expect(withSuffix('Yenice', Suffix.ablative), "Yenice'den");
      for (final idea in kVillageNameIdeas) {
        for (final s in Suffix.values) {
          expect(withSuffix(idea.name, s), contains("'"),
              reason: '${idea.name} ek almıyor');
        }
      }
    });
  });

  group('kuruluş kapısı', () {
    /// Kapı UI'ı repliklerin daktilosu bitince belirir (bkz.
    /// opening_cutscene_test).
    Future<void> pumpUntil(WidgetTester tester, Finder finder) async {
      for (var i = 0; i < 400; i++) {
        if (finder.evaluate().isNotEmpty) return;
        await tester.pump(const Duration(milliseconds: 100));
      }
      fail('kapı hiç açılmadı: $finder');
    }

    Future<void> openGate(WidgetTester tester, Size size) async {
      tester.view.physicalSize = size;
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
      await pumpUntil(
          tester, find.byKey(const ValueKey('village_name_field')));
    }

    testWidgets('masaüstünde öneriye dokunmak kutuyu doldurur ve gerekçe çıkar',
        (tester) async {
      await openGate(tester, const Size(1600, 1000));

      // Havuzdan gelen bir öneri ekranda olmalı — kutu boş bırakılmıyor.
      final chip = find.byWidgetPredicate((w) =>
          w is Text &&
          kVillageNameIdeas.any((i) => i.name == w.data));
      expect(chip, findsWidgets, reason: 'hiç ad önerisi çizilmemiş');

      final picked = tester.widget<Text>(chip.first).data!;
      final meaning = meaningOfVillageName(picked)!;
      expect(find.text(meaning), findsNothing, reason: 'gerekçe erken çıkmış');

      await tester.tap(chip.first);
      await tester.pump();

      final field = tester.widget<TextField>(
          find.byKey(const ValueKey('village_name_field')));
      expect(field.controller!.text, picked);
      expect(find.text(meaning), findsOneWidget,
          reason: 'ad seçildi ama nereden geldiği söylenmedi');
    });

    testWidgets('telefonda tek dokunuş hem köy hem hane adını doldurur',
        (tester) async {
      await openGate(tester, const Size(896, 414));

      final button = find.byKey(const ValueKey('mobile_name_idea_button'));
      expect(button, findsOneWidget);
      await tester.tap(button);
      await tester.pump();

      final village = tester.widget<TextField>(
          find.byKey(const ValueKey('village_name_field')));
      final house = tester.widget<TextField>(
          find.byKey(const ValueKey('house_name_field')));
      expect(meaningOfVillageName(village.controller!.text), isNotNull,
          reason: 'öneri havuzdan gelmedi');
      expect(house.controller!.text.trim(), isNotEmpty,
          reason: 'boş hane kutusu doldurulmadı');

      // İkinci dokunuş SIRADAKİ adı verir (aynı adı tekrar dayatmaz) ve
      // oyuncunun yazdığı hane adını EZMEZ.
      final firstVillage = village.controller!.text;
      final typedHouse = house.controller!.text;
      await tester.tap(button);
      await tester.pump();
      expect(village.controller!.text, isNot(firstVillage));
      expect(house.controller!.text, typedHouse);
    });
  });
}
