import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/estate_system.dart';
import 'package:village_sim/systems/law_compass.dart';

void main() {
  group('LawCompass — konum', () {
    test('boş defter merkezde durur', () {
      final p = LawCompass.positionOf({});
      expect(p.authority, 0);
      expect(p.economy, 0);
      expect(p.faith, 0);
      expect(LawCompass.identify(p).regime, VillageRegime.moderate);
    });

    test('sıradan köy hayatı hükümleri pusulayı hiç oynatmaz', () {
      // İKTİSAT EKSENİ KURALI: bir hüküm iktisat eksenini ancak MÜLKİYET ya da
      // PAYLAŞIM hakkında bir şey söylüyorsa oynatır. Selamlaşma, kışlık yem,
      // sürü çoğaltma, nadas, beşik teşviki — hiçbiri bir iktisat düzeni
      // kurmaz. (Eskiden hepsi "ortak/imece" gerekçesiyle −1 taşıyordu ve
      // eksen daha oyunun ortasında −1.0'a yapışıyordu; bkz. kLawVectors.)
      final p = LawCompass.positionOf({
        'neighborliness',
        'winterFodder',
        'herdGrowth',
        'cropRotation',
        'familyEncouragement',
        'familyReunion',
      });
      expect(p.economy, closeTo(0, 1e-9));
      expect(p.authority, closeTo(0, 1e-9));
      expect(LawCompass.identify(p).regime, VillageRegime.moderate);
    });

    test('mülkçü kutup birkaç gerçek tercihle ERİŞİLEBİLİR', () {
      // Denge düzeltmesinin asıl sınavı: Açık Pazar rejimi (ve ona bağlı
      // rejim.mulkTapusu fermanı) oynanabilir olmalı. Eskiden mülkçü tarafta
      // toplam yalnız +4 vardı ve ortakçı taraf −15'e kadar doyduğu için bu
      // köşeye ancak defterin %80'ine hiç dokunmayarak varılabiliyordu.
      final p = LawCompass.positionOf(
          {'hospitality', 'apprenticeship', 'outsideMarriage', 'freeRange'});
      expect(p.economy, greaterThan(LawCompass.kBand));
      expect(p.authority.abs(), lessThan(LawCompass.kBand)); // hâlâ Hür
      final id = LawCompass.identify(p);
      expect(id.regime, VillageRegime.market);
      // Yemin eşiğini de geçmeli — yoksa rejim fermanları yine ulaşılmaz kalır.
      expect(p.intensity, greaterThanOrEqualTo(LawCompass.kConvictionBand));
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
