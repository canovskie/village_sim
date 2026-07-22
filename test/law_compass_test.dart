import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/estate_system.dart';

void main() {
  group('LawCompass — konum', () {
    test('boş defter merkezde durur', () {
      final p = LawCompass.positionOf({});
      expect(p.authority, 0);
      expect(p.economy, 0);
      expect(p.faith, 0);
      expect(LawCompass.identify(p).regime, VillageRegime.moderate);
    });

    test('iki ilkel yasa henüz Merkez (teşekkül etmedi)', () {
      // neighborliness(-1) + winterFodder(-1) = econ -2 → /8 = -0.25 < band(0.30)
      final p = LawCompass.positionOf({'neighborliness', 'winterFodder'});
      expect(p.economy, closeTo(-0.25, 1e-9));
      expect(LawCompass.identify(p).regime, VillageRegime.moderate);
    });

    test('kolektif çiftçi seti → Ortak Ocak (Hür + Ortakçı)', () {
      final p = LawCompass.positionOf(
          {'sharedHarvest', 'winterFodder', 'irrigation', 'eldersExemptFromFood'});
      expect(p.economy, lessThan(-LawCompass.kBand));
      expect(p.authority.abs(), lessThan(LawCompass.kBand)); // otorite belirsiz → Hür
      final id = LawCompass.identify(p);
      expect(id.regime, VillageRegime.commune);
      expect(id.religious, isFalse);
      expect(id.base, Estate.laborers);
    });

    test('nizam kolu → Mühürlü El (Baskı + Mülkçü)', () {
      final p = LawCompass.positionOf(
          {'nizam.watch', 'nizam.registry', 'nizam.exile'});
      expect(p.authority, greaterThan(LawCompass.kBand));
      expect(p.economy, greaterThan(0)); // registry mülk tarafına iter
      final id = LawCompass.identify(p);
      expect(id.regime, anyOf(VillageRegime.sealedHand, VillageRegime.ironTable));
    });

    test('tek söz tek başına köyü belirgin Baskı yapar', () {
      final p = LawCompass.positionOf({'nizam.sole'});
      expect(p.authority, closeTo(5 / 8, 1e-9));
      expect(LawCompass.identify(p).committed, isTrue);
    });

    test('dergâh kolu → dinî overlay biner', () {
      final p = LawCompass.positionOf({'dergah.tithe', 'dergah.holyDay'});
      expect(p.faith, greaterThanOrEqualTo(LawCompass.kFaithBand));
      final id = LawCompass.identify(p);
      expect(id.religious, isTrue);
      // tithe+holyDay ortakçı+dinî, otorite zayıf → Tarikat-Köyü
      expect(id.title, 'Tarikat-Köyü');
    });

    test('dinî + baskı + mülk → Şeyh Beyliği', () {
      // oneFaith(auth4) + registry(auth2,econ2) + apprenticeship(auth1,econ2)
      // → auth 0.875, econ 0.5 (band'ı geçer) → Baskı+Mülkçü+dinî.
      final p = LawCompass.positionOf(
          {'dergah.oneFaith', 'nizam.registry', 'apprenticeship'});
      final id = LawCompass.identify(p);
      expect(id.religious, isTrue);
      expect(id.regime, VillageRegime.sealedHand);
      expect(id.title, 'Şeyh Beyliği');
    });

    test('salt nizam düzeni (mülk yasası yok) → Demir/Dergâh Düzeni', () {
      // Kılıç kolu ekonomik mülk yasası olmadan Ortakçı tarafta kalır — kimlik
      // ancak sicil+kürek gibi mülk/vergi yasaları birikince feodalleşir.
      final p = LawCompass.positionOf({'nizam.watch', 'nizam.exile', 'nizam.sole'});
      final id = LawCompass.identify(p);
      expect(id.regime, VillageRegime.ironTable);
    });

    test('preview: sonraki mühür konumu oynatır', () {
      final base = {'neighborliness'};
      final before = LawCompass.positionOf(base);
      final after = LawCompass.preview(base, 'nizam.sole');
      expect(after.authority, greaterThan(before.authority));
    });
  });
}
