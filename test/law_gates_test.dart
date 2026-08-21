// KANUNNAME DÜNYA KAPILARI — defterin köyün hâline göre kademe kademe açılması.
//
// Kırılan hata: 30 hükmün 28'i kapısızdı; beş kişilik, binasız, tarlasız yeni
// kurulmuş bir köy sürgün fermanını da öşür fermanını da ilk gün görüyordu.
// Kapılar eklendi (law_book.dart) ve görünürlük LawBook.visible'a bağlandı.
//
// Bu test kapıların İKİ yönünü de bekler: kapalıyken hüküm ortada olmayacak,
// köyün hâli o derdi doğurduğunda kendiliğinden deftere düşecek.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/buildings/craft.dart';
import 'package:village_sim/systems/law_book.dart';

/// Yeni kurulmuş köy: beş kurucu, tek hane, hiçbir şey yok.
const fresh = LawContext(population: 5, dayCount: 1, households: 1);

/// Olgun köy — her kapıyı açan hâl.
const mature = LawContext(
  population: 18,
  dayCount: 41,
  households: 4,
  children: 3,
  elders: 2,
  farmTiles: 6,
  animals: 7,
  deaths: 2,
  crimesSeen: 4,
  // Kırılganlık hükümlerinin kapıları: köy hastalık ve kan da gördü.
  illnessSeen: 3,
  feudsSeen: 1,
  knownCrafts: {Craft.carpentry, Craft.farming, Craft.husbandry, Craft.faith},
  buildings: {
    BuildingType.well,
    BuildingType.warehouse,
    BuildingType.barn,
    BuildingType.lumberCamp,
    BuildingType.church,
    BuildingType.firepit, // Ocak Nöbeti Fermanı'nın kapısı
    BuildingType.townhall, // Kanunname'nin kurumsal eşiği
  },
);

const noSeal = <String>{};

LawDef law(String id) => LawBook.byId(id)!;

List<String> visibleIds(LawContext c) => [
  for (final l in kLawBook)
    if (LawBook.visible(l, noSeal, c)) l.id,
];

void main() {
  test('Kanunname nüfusa değil Belediye kurumuna bağlanır', () {
    const kalabalikAmaKurumsuz = LawContext(
      population: 30,
      dayCount: 60,
      households: 8,
    );
    expect(LawBook.governanceReady(kalabalikAmaKurumsuz), isFalse);
    expect(LawBook.governanceReady(mature), isTrue);
  });

  group('yeni köy defteri', () {
    test('yeni köy hükümlerin ezici çoğunluğunu GÖRMEZ', () {
      final vis = visibleIds(fresh);
      // Görünenlerin neredeyse tamamı AĞIR hüküm: ufukta kilitli dururlar
      // (gerekçesiyle) ama dokunulamazlar. Gerçek gündem avuç içi kalmalı.
      final actionable = LawBook.openAgenda(noSeal, fresh);
      expect(
        actionable.length,
        lessThan(4),
        reason:
            'yeni köyün gündemi avuç içi olmalı: '
            '${actionable.map((l) => l.id).toList()}',
      );
      final nonGrave = [
        for (final id in vis)
          if (!law(id).grave) id,
      ];
      expect(
        nonGrave.length,
        lessThan(4),
        reason: 'ağır olmayan görünür hüküm çok fazla: $nonGrave',
      );
      expect(kLawBook.length, greaterThan(25));
    });

    test('en temel hüküm ilk günden açıktır (defter tamamen ölü değil)', () {
      expect(LawBook.available(law('neighborliness'), noSeal, fresh), isTrue);
    });

    test('kapısı kapalı SIRADAN hüküm defterde hiç görünmez', () {
      for (final id in const ['nizam.exile', 'dergah.tithe', 'freeRange']) {
        expect(LawBook.visible(law(id), noSeal, fresh), isFalse, reason: id);
        expect(LawBook.available(law(id), noSeal, fresh), isFalse, reason: id);
      }
    });

    test('kapısı kapalı AĞIR hüküm görünür ama kilitli — ufukta durur', () {
      for (final id in const ['nizam.sole', 'dergah.oneFaith']) {
        expect(law(id).grave, isTrue, reason: id);
        expect(LawBook.visible(law(id), noSeal, fresh), isTrue, reason: id);
        expect(LawBook.available(law(id), noSeal, fresh), isFalse, reason: id);
        expect(law(id).gateReason, isNotEmpty, reason: id);
      }
    });
  });

  group('köy büyüyünce defter açılır', () {
    test('olgun köyde mühürsüz her hüküm gündeme gelir', () {
      final open = LawBook.openAgenda(noSeal, mature).map((l) => l.id).toSet();
      final missing = [
        for (final l in kLawBook)
          // Rejim fermanları bir DURUMLA değil bir EYLEMLE açılır (Köyün
          // Yemini) — olgunluk onları açmaz, açmamalı. Kapıları regime_test
          // kilitliyor.
          if (!l.id.startsWith('rejim.') && !open.contains(l.id))
            '${l.id} (${l.gateReason})',
      ];
      expect(
        missing,
        isEmpty,
        reason: 'olgun köyde kapalı kalan hüküm var: $missing',
      );
    });

    test(
      'rejim fermanları yemin edilmeden olgun köyde bile AÇILMAZ ama görünür',
      () {
        // Kapı yeminle açılır, olgunlukla değil. Ama hepsi `grave`: defterde
        // gerekçesiyle DURURLAR. Aksi hâlde yeminin ödülü, yemin edilene kadar
        // hiç görünmüyordu — oyuncu neyi kazanacağını bilmeden yemin ediyordu.
        final regimeLaws = [
          for (final l in kLawBook)
            if (l.id.startsWith('rejim.')) l,
        ];
        expect(regimeLaws, isNotEmpty);
        for (final l in regimeLaws) {
          expect(l.grave, isTrue, reason: l.id);
          expect(l.binding, isTrue, reason: l.id);
          expect(LawBook.available(l, noSeal, mature), isFalse, reason: l.id);
          expect(LawBook.visible(l, noSeal, mature), isTrue, reason: l.id);
          expect(l.gateReason, isNotEmpty, reason: l.id);
        }
      },
    );

    test('gündem yeni köyden olgun köye kesin olarak genişler', () {
      expect(
        LawBook.openAgenda(noSeal, mature).length,
        greaterThan(LawBook.openAgenda(noSeal, fresh).length * 4),
      );
    });
  });

  group('kapı = dünya şartı, yasa şartı değil', () {
    test('ilk suç işlenince bekçi fermanı kendiliğinden deftere düşer', () {
      const before = LawContext(population: 8, dayCount: 6, households: 2);
      const after = LawContext(
        population: 8,
        dayCount: 6,
        households: 2,
        crimesSeen: 1,
      );
      expect(LawBook.visible(law('nizam.watch'), noSeal, before), isFalse);
      expect(LawBook.available(law('nizam.watch'), noSeal, after), isTrue);
      // Tek vaka ceza kanununu açmaz — tekrar gerek.
      expect(LawBook.available(law('nizam.labor'), noSeal, after), isFalse);
    });

    test('tarla + kuyu olmadan su yolu fermanı yok', () {
      const fields = LawContext(population: 8, dayCount: 5, farmTiles: 3);
      const fieldsAndWell = LawContext(
        population: 8,
        dayCount: 5,
        farmTiles: 3,
        buildings: {BuildingType.well},
      );
      expect(LawBook.available(law('irrigation'), noSeal, fields), isFalse);
      expect(
        LawBook.available(law('irrigation'), noSeal, fieldsAndWell),
        isTrue,
      );
    });

    test('kandil yanmadan dergâh hükümleri konuşulmaz', () {
      const godless = LawContext(population: 12, dayCount: 20, deaths: 1);
      expect(
        LawBook.available(law('dergah.holyDay'), noSeal, godless),
        isFalse,
      );
      expect(
        LawBook.available(law('dergah.oneFaith'), noSeal, godless),
        isFalse,
      );
      // Dergâh kurulmuş bir köy (dünya bayrağı) kapıyı açar.
      const lodged = LawContext(
        population: 12,
        dayCount: 20,
        deaths: 1,
        memory: {'cult.active'},
      );
      expect(LawBook.available(law('dergah.holyDay'), noSeal, lodged), isTrue);
      expect(LawBook.available(law('dergah.oneFaith'), noSeal, lodged), isTrue);
    });

    test('defteri doldurmak kapı açmaz — kapılar yasaya değil dünyaya bakar', () {
      // Path/skill-tree yasağı: köy yerinde saydığı sürece, BÜTÜN öbür hükümler
      // mühürlenmiş olsa bile kapalı kapı kapalı kalır.
      for (final l in kLawBook) {
        if (l.gate == null || l.gate!(fresh)) continue;
        final othersSealed = {
          for (final o in kLawBook)
            if (o.id != l.id) o.id,
        };
        expect(
          LawBook.available(l, othersSealed, fresh),
          isFalse,
          reason: l.id,
        );
      }
    });

    test('her kapılı hükmün oyuncuya söyleyecek bir gerekçesi var', () {
      for (final l in kLawBook) {
        if (l.gate == null) continue;
        expect(l.gateReason, isNotEmpty, reason: l.id);
      }
    });
  });
}
