// KANUNNAME SÖZLEŞMESİ — "yasa var ama karşılığı yok" sınıfına karşı bekçi.
//
// Bu testin doğduğu denetimde defterde şunlar bulundu: özeti bir hüküm vaat
// ederken yargıda hiçbir seçenek açmayan ferman (Tövbe Meydanı), "köyün ortasına
// dergâh kurula" deyip hiçbir bina dikmeyen ferman (Dergâh), hiçbir yerin
// okumadığı ölü bayrak (fields.watered), murmur'ında bedel anlatıp bedeli
// olmayan ferman (Kışlık Yem) ve yalnız basınç çarpanından ibaret dört rejim
// fermanı. Hepsi tek tek düzeltildi — bu dosya aynı boşlukların SESSİZCE geri
// gelmesini engeller.
//
// Sözleşme: bir hüküm deftere giriyorsa (1) ne yaptığı düz Türkçeyle yazılıdır,
// (2) pusuladaki yeri BİLİNÇLİ olarak beyan edilmiştir (nötr de bir beyandır),
// (3) köyün hâlini gerçekten değiştirir, (4) kapılıysa gerekçesi vardır.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/law_book.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/world_pressure.dart';
import 'package:village_sim/world/season.dart';

/// Bir basınç tablosunun bütün sayısal alanları — karşılaştırma için.
List<double> fields(WorldPressure w) => [
      w.curfewBias,
      w.workDrive,
      w.restDrive,
      w.marketPull,
      w.tavernPull,
      w.wellPull,
      w.firePull,
      w.churchPull,
      w.squarePull,
      w.homePull,
      w.visitPull,
      w.strollPull,
      w.patrolDensity,
      w.patrolVigilance,
      w.deference,
      w.outspoken,
      w.wariness,
      w.cheer,
      w.lanternMandate ? 1 : 0,
      w.crimeUrge,
      w.crimeRisk,
      w.informUrge,
    ];

WorldPressure pressureOf(Set<String> sealed,
        {Season season = Season.spring, int dayCount = 3}) =>
    WorldPressure.derive(
      sealed: sealed,
      compass: LawCompass.positionOf(const {}), // pusula etkisi dışarıda
      regime: VillageRegime.moderate,
      season: season,
      unrest: 0,
      dayCount: dayCount,
    );

/// Bir hükmün dünyaya dokunduğu her koşul. Bazı hükümler yalnız belli bir
/// mevsimde ya da haftanın belli bir gününde konuşur (Kışlık Yem kışın, Kutsal
/// Gün yedi günde bir) — "hiç dokunmuyor" demeden önce hepsine bakılır.
const _probes = <(Season, int)>[
  (Season.spring, 3),
  (Season.winter, 3),
  (Season.autumn, 3),
  (Season.spring, 7), // kutsal günün haftalık ritmi
];

void main() {
  group('kanunname sözleşmesi', () {
    test('her fermanın id\'si tektir', () {
      final ids = <String>{};
      for (final l in kLawBook) {
        expect(ids.add(l.id), isTrue, reason: 'tekrar eden id: ${l.id}');
      }
    });

    test('her fermanın düz Türkçe bir özeti vardır', () {
      // Berat metni (decree) şiirseldir; oyuncu fermanın ADINA değil ETKİSİNE
      // bakarak seçsin diye ayrıca düz bir cümle zorunlu.
      for (final l in kLawBook) {
        expect(LawBook.summary(l.id), isNotEmpty,
            reason: '${l.id} kLawSummary\'de yok');
      }
    });

    test('her fermanın pusuladaki yeri BEYAN EDİLMİŞTİR', () {
      // Nötr olmak serbest ama SESSİZ olmak değil: haritada satırı olmayan yasa
      // "unutulmuş" ile "bilerek nötr" arasında ayırt edilemez.
      for (final l in kLawBook) {
        expect(kLawVectors.containsKey(l.id), isTrue,
            reason: '${l.id} kLawVectors haritasında yok');
      }
    });

    test('her ferman köyün hâlini GERÇEKTEN değiştirir', () {
      // Asıl bekçi bu: bir hüküm mühürlendiğinde WorldPressure tablosu nötrden
      // ayrılmalı. Ayrılmıyorsa o ferman NPC davranışında hiçbir karşılığı
      // olmayan bir panel satırıdır.
      for (final l in kLawBook) {
        final moved = _probes.any((probe) {
          final (season, day) = probe;
          final base = fields(pressureOf(const {}, season: season, dayCount: day));
          final got = fields(pressureOf({l.id}, season: season, dayCount: day));
          for (var i = 0; i < base.length; i++) {
            if (base[i] != got[i]) return true;
          }
          return false;
        });
        expect(moved, isTrue,
            reason: '${l.id} hiçbir mevsimde/günde basınç tablosunu '
                'oynatmıyor — world_pressure._applyLaw içinde karşılığı yok');
      }
    });

    test('kapılı her fermanın gerekçesi yazılıdır', () {
      // Kapalı AĞIR hüküm ufukta gerekçesiyle durur; gerekçesiz kapı oyuncuya
      // "neden yapamıyorum" sorusunu yanıtsız bırakır.
      for (final l in kLawBook) {
        if (l.gate == null) continue;
        expect(l.gateReason, isNotEmpty, reason: '${l.id} gerekçesiz kapılı');
      }
    });

    test('fesihte silinen bayraklar fermanın KENDİ bayraklarıdır', () {
      // repealClears, setsFlags'ten ayrı tutulur ama onun bir alt kümesi
      // olmalıdır: bir ferman basmadığı bayrağı silemez.
      for (final l in kLawBook) {
        for (final f in l.repealClears) {
          expect(l.seal.setsFlags, contains(f),
              reason: '${l.id} basmadığı bayrağı siliyor: $f');
        }
      }
    });

    test('bağlayıcı ve ağır fermanlar feshedilemez', () {
      for (final l in kLawBook) {
        if (!l.binding && !l.grave) continue;
        expect(LawBook.repealable(l), isFalse, reason: l.id);
      }
    });

    test('günlük idamesi olan ferman bunu özetinde söyler', () {
      // İdame her sabah ambardan/keseden sessizce kesiliyor; oyuncu ambarın
      // neden eridiğini okuyabilmeli. (Panel de ayrıca rozetle gösterir.)
      for (final l in kLawBook) {
        if (l.goldPerDay == 0 && l.foodPerDay == 0) continue;
        expect(LawBook.summary(l.id), contains('gün'),
            reason: '${l.id} günlük idame taşıyor ama özetinde geçmiyor');
      }
    });

    test('toplam idame tek tek fermanların toplamıdır', () {
      final all = {for (final l in kLawBook) l.id};
      var gold = 0, food = 0;
      for (final l in kLawBook) {
        gold += l.goldPerDay;
        food += l.foodPerDay;
      }
      expect(LawBook.dailyUpkeep(all), (gold, food));
      expect(LawBook.dailyUpkeep(const {}), (0, 0));
    });

    test('mutex grup kardeşleri birbirini defterden düşürür', () {
      final oneChild = LawBook.byId('oneChild')!;
      final twoChild = LawBook.byId('twoChild')!;
      expect(oneChild.group, twoChild.group);
      expect(LawBook.groupTaken(twoChild, {'oneChild'}), isTrue);
      expect(LawBook.visible(twoChild, {'oneChild'}, const LawContext()),
          isFalse);
    });

    test('NİZAM ve DERGÂH kolları birbirini DIŞLAMAZ', () {
      // Eski tasarımdı, bırakıldı. Mühür metinleri uzun süre "öbür kol ebediyen
      // kapandı" diyordu ama kodda hiçbir dışlama yoktu — oyuncuya yalandı.
      const both = {'nizam.watch', 'dergah.holyDay'};
      for (final id in both) {
        final l = LawBook.byId(id)!;
        expect(l.seal.resolution, isNot(contains('ebediyen kapandı')),
            reason: '$id hâlâ olmayan bir dışlamayı duyuruyor');
      }
      // İkisi birden mühürlenebilir olmalı (kapıları açıkken).
      const ctx = LawContext(
        population: 12,
        dayCount: 12,
        crimesSeen: 2,
        knownCrafts: {'faith'},
      );
      expect(
          LawBook.available(LawBook.byId('dergah.holyDay')!, {'nizam.watch'}, ctx),
          isTrue);
    });
  });
}
