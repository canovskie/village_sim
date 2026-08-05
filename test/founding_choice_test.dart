import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/systems/founding_choice.dart';

/// KURULUŞ KARARI — açılış sinematiğine gömülü ilk seçim.
///
/// Buradaki sözleşmeler sayı değil TASARIM. İkisi de sessizce kırılabilecek
/// cinsten: kadro deseni bozulursa çiftler ayrılır ve doğum susar (sebebi
/// haftalar sonra anlaşılmaz); seçenekler birbirinin kopyası olursa karar
/// karar olmaktan çıkar ve "kurulumda seçim yok" şikâyeti geri döner.
void main() {
  final options = [...FoundingChoice.all, FoundingChoice.fallback];

  group('kafile yükü', () {
    test('üç seçenek + bir varsayılan var', () {
      expect(FoundingChoice.all.length, 3);
      // Sinematik atlanabilir; atlayan oyuncu da bir kadroyla başlamalı.
      expect(FoundingChoice.byId('yok-böyle-bir-id').id,
          FoundingChoice.fallback.id);
      for (final c in FoundingChoice.all) {
        expect(FoundingChoice.byId(c.id).id, c.id);
      }
    });

    test('id\'ler tekil', () {
      final ids = options.map((c) => c.id).toList();
      expect(ids.toSet().length, ids.length);
    });

    test('kadro deseni korunur — çiftler yan yana, yaşlı beşinci', () {
      // Barınak ataması listeyi BAŞTAN tarar: 0-1 ve 2-3 aynı evi paylaşır.
      // Desen (♂ ♀ ♂ ♀ ♂yaşlı) bozulursa çiftler ayrı evlere düşer ve doğum
      // sessizce durur — bkz. _spawnFoundingCaravan.
      for (final c in options) {
        expect(c.roster.length, greaterThanOrEqualTo(5),
            reason: '${c.id}: kadro beş kişiden az olamaz');
        final genders = [for (final (_, male) in c.roster.take(5)) male];
        expect(genders, [true, false, true, false, true],
            reason: '${c.id}: cinsiyet deseni bozulmuş — çiftler ayrılır');
        expect(c.roster[4].$1, VillagerType.priest,
            reason: '${c.id}: beşinci yaşlı dul olmalı (ateş başı anlatıcı)');
      }
    });

    test('her seçenek gerçekten farklı bir başlangıç verir', () {
      // Aynı stoğu veren iki kart karar değil süstür.
      final fingerprints = FoundingChoice.all
          .map((c) => '${c.wood}/${c.stone}/${c.food}/${c.people}')
          .toSet();
      expect(fingerprints.length, FoundingChoice.all.length);
    });

    test('hiçbir seçenek köyü açlıktan öldürmez, hiçbiri her şeyi vermez', () {
      // No-fail omurgası: yanlış seçim ceza değil, farklı bir ritim olmalı.
      for (final c in FoundingChoice.all) {
        expect(c.food, greaterThanOrEqualTo(10), reason: '${c.id}: azık çok az');
        expect(c.wood, greaterThanOrEqualTo(12),
            reason: '${c.id}: ateş yeri bedava ama ilk çadır (6 odun) '
                'kurulamıyorsa oyuncu ilk dakikada sıkışır');
        // Üstünlük TEK eksende kalmalı — hepsinde en iyi olan bir kart yok.
        final best = [
          c.wood == _max((x) => x.wood),
          c.food == _max((x) => x.food),
          c.people == _max((x) => x.people),
        ].where((b) => b).length;
        expect(best, lessThanOrEqualTo(1),
            reason: '${c.id}: birden çok eksende en iyi — bedeli yok');
      }
    });

    test('fazladan can yalnız beşinciden SONRA gelir', () {
      // Kafileye eklenen can bekârdır (eşi dışarıdan gelir) ve çift dizilimini
      // bozmaması için listenin SONUNA eklenir — tek soy kuralı korunur.
      for (final c in options) {
        expect(c.roster.length, lessThanOrEqualTo(6),
            reason: '${c.id}: kuruluş kalabalığı köyü kamp olmaktan çıkarır');
      }
      final crowd =
          FoundingChoice.all.where((c) => c.roster.length > 5).toList();
      expect(crowd.length, 1,
          reason: 'kalabalık seçeneği tek olmalı — ekseni o taşıyor');
    });

    test('kart metinleri bedeli söyler', () {
      for (final c in options) {
        expect(c.title.trim(), isNotEmpty);
        expect(c.blurb.trim(), isNotEmpty);
        expect(c.cost.trim(), isNotEmpty,
            reason: '${c.id}: bedeli görünmeyen seçim karar değildir');
      }
    });
  });
}

int _max(int Function(FoundingChoice) f) =>
    FoundingChoice.all.map(f).reduce((a, b) => a > b ? a : b);
