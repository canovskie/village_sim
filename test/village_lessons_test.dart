import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/village_lessons.dart';
import 'package:village_sim/world/season.dart';

/// ORTA OYUN DERSLERİ — katalog sözleşmesi.
///
/// Bir öğretici sisteminde en sinsi hata "ders var ama hiç açılmıyor"dur:
/// tetik yanlış yazılır, kimse fark etmez, oyuncu sistemi hiç öğrenmez. Bu
/// yüzden testler metnin güzelliğini değil, HER DERSİN ULAŞILABİLİR
/// olduğunu ve doğru anda önceliklendiğini kontrol ediyor.
LessonContext _ctx({
  Season season = Season.spring,
  int upsetHouses = 0,
  int crimesSeen = 0,
  int knownCrafts = 0,
  int coatsPending = 0,
  int enactedPolicies = 0,
  bool regimeNamed = false,
  int imperialVisits = 0,
}) =>
    LessonContext(
      season: season,
      upsetHouses: upsetHouses,
      crimesSeen: crimesSeen,
      knownCrafts: knownCrafts,
      coatsPending: coatsPending,
      enactedPolicies: enactedPolicies,
      regimeNamed: regimeNamed,
      imperialVisits: imperialVisits,
    );

/// Her dersi tek başına tetikleyen köy hâli.
const _triggers = <String, LessonContext>{
  'winter': LessonContext(season: Season.autumn),
  'coats': LessonContext(season: Season.spring, coatsPending: 3),
  'houseMood': LessonContext(season: Season.spring, upsetHouses: 1),
  'craft': LessonContext(season: Season.spring, knownCrafts: 3),
  'crime': LessonContext(season: Season.spring, crimesSeen: 1),
  'charter': LessonContext(season: Season.spring, enactedPolicies: 2),
  'imperial': LessonContext(season: Season.spring, imperialVisits: 1),
};

void main() {
  group('katalog', () {
    test('id\'ler tekil', () {
      final ids = VillageLessons.all.map((l) => l.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('her dersin başlığı, gövdesi ve EYLEMİ dolu', () {
      for (final l in VillageLessons.all) {
        expect(l.title.trim(), isNotEmpty, reason: l.id);
        expect(l.body.trim(), isNotEmpty, reason: l.id);
        // Eylemsiz ders bir tabeladır: oyuncu bilgiyi alır ama elinde bir kol
        // olduğunu öğrenmez.
        expect(l.action.trim(), isNotEmpty,
            reason: '"${l.id}" dersinin eylemi yok — ne yapacağını '
                'söylemeyen ders öğretmez');
        expect(l.icon.trim(), isNotEmpty, reason: l.id);
      }
    });

    test('öncelikler tekil — iki ders aynı anda "önce" olamaz', () {
      final p = VillageLessons.all.map((l) => l.priority).toList();
      expect(p.toSet().length, p.length);
    });

    test('sakin bir bahar gününde hiçbir ders açılmaz', () {
      expect(VillageLessons.pick(_ctx(), {}), isNull,
          reason: 'ders koşulla açılmalı; hiçbir şey olmadan konuşan '
              'öğretici dırdırdır');
    });
  });

  group('ulaşılabilirlik', () {
    test('kataloğun HER dersi bir köy hâliyle tetiklenebilir', () {
      for (final l in VillageLessons.all) {
        final ctx = _triggers[l.id];
        expect(ctx, isNotNull,
            reason: '"${l.id}" için tetik senaryosu yazılmamış — yeni ders '
                'eklendiyse bu teste de bir satır ekle');
        expect(l.when(ctx!), isTrue,
            reason: '"${l.id}" dersi hiçbir zaman açılmıyor: tetiği yanlış. '
                'Oyuncu bu sistemi hiç öğrenmez ve kimse fark etmez.');
      }
    });

    test('tetiklenen ders pick() ile GERÇEKTEN dönüyor', () {
      for (final e in _triggers.entries) {
        expect(VillageLessons.pick(e.value, {})?.id, e.key,
            reason: '${e.key}: tetik doğru ama seçim onu döndürmüyor');
      }
    });
  });

  group('seçim', () {
    test('görülen ders bir daha dönmez', () {
      final ctx = _ctx(season: Season.autumn);
      expect(VillageLessons.pick(ctx, {}), isNotNull);
      expect(VillageLessons.pick(ctx, {'winter'}), isNull);
    });

    test('birden çok koşulda EN ACİL olan önce gelir', () {
      // Kış (hayatta kalma) ile tüzük (yönetişim) aynı anda tetiklenirse
      // önce kış anlatılmalı.
      final both = _ctx(season: Season.autumn, enactedPolicies: 2);
      expect(VillageLessons.pick(both, {})?.id, 'winter');
      // Kış görüldüyse sıra ötekine geçer — hiçbir ders diğerini yutmaz.
      expect(VillageLessons.pick(both, {'winter'})?.id, 'charter');
    });

    test('yedi dersin tamamı sırayla tüketilebilir', () {
      // Hepsini birden tetikleyen bir köy hâli: dersler tek tek boşalmalı,
      // biri diğerini kalıcı olarak gölgelememeli.
      final everything = _ctx(
        season: Season.autumn,
        upsetHouses: 2,
        crimesSeen: 4,
        knownCrafts: 5,
        coatsPending: 2,
        enactedPolicies: 3,
        imperialVisits: 2,
      );
      final seen = <String>{};
      for (var i = 0; i < VillageLessons.all.length; i++) {
        final l = VillageLessons.pick(everything, seen);
        expect(l, isNotNull, reason: '${i + 1}. derste liste erken bitti');
        seen.add(l!.id);
      }
      expect(seen.length, VillageLessons.all.length);
      expect(VillageLessons.pick(everything, seen), isNull);
    });

    test('kimlik kazanılınca tüzük dersi susar', () {
      // Ders "mühürlerin bir kimliğe dönüştüğünü" anlatıyor; kimlik zaten
      // kazanıldıysa anlatacak bir şey kalmaz.
      expect(VillageLessons.pick(_ctx(enactedPolicies: 4), {})?.id, 'charter');
      expect(
          VillageLessons.pick(
              _ctx(enactedPolicies: 4, regimeNamed: true), {}),
          isNull);
    });
  });
}
