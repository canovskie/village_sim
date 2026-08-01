import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/house_action.dart';

/// Hane eylemleri: yetki kapısı + bedel dengesi. Bu testler tasarımın iki
/// omurgasını kilitler — (1) sert eylem yetkisiz/yasasız yapılamaz,
/// (2) kaynak kazandıran eylem bedelsiz değildir ve tekrar pahalanır.

const _allLaws = {'nizam.registry', 'nizam.exile'};

void main() {
  group('yetki kapısı', () {
    test('yumuşak eylemler hür rejimde de açık', () {
      for (final k in [
        HouseActionKind.punish,
        HouseActionKind.betroth,
        HouseActionKind.scheme,
      ]) {
        final g = gateFor(k,
            authority: -1.0, sealedLaws: const {}, members: 4, gold: 999);
        expect(g.open, isTrue, reason: '$k hür rejimde açık olmalı');
      }
    });

    test('el koyma: ferman yoksa kapalı, gerekçesi ferman', () {
      final g = gateFor(HouseActionKind.seize,
          authority: 1.0, sealedLaws: const {}, members: 4, gold: 0);
      expect(g.open, isFalse);
      expect(g.reason, contains('ferman'));
    });

    test('el koyma: ferman var ama rejim hür → meclis reddeder', () {
      final g = gateFor(HouseActionKind.seize,
          authority: -0.5, sealedLaws: _allLaws, members: 4, gold: 0);
      expect(g.open, isFalse);
      expect(g.reason, contains('Meclis'));
    });

    test('el koyma: ferman + baskı rejimi → açılır', () {
      final g = gateFor(HouseActionKind.seize,
          authority: 0.4, sealedLaws: _allLaws, members: 4, gold: 0);
      expect(g.open, isTrue);
    });

    test('sürgün el koymadan DAHA yüksek yetki ister', () {
      const auth = 0.20; // seize eşiği (0.15) üstü, exile eşiği (0.30) altı
      expect(
          gateFor(HouseActionKind.seize,
                  authority: auth,
                  sealedLaws: _allLaws,
                  members: 4,
                  gold: 0)
              .open,
          isTrue);
      expect(
          gateFor(HouseActionKind.exile,
                  authority: auth,
                  sealedLaws: _allLaws,
                  members: 4,
                  gold: 0)
              .open,
          isFalse);
    });

    test('son canı sürgüne yollayıp soyu tüketemezsin', () {
      final g = gateFor(HouseActionKind.exile,
          authority: 1.0, sealedLaws: _allLaws, members: 1, gold: 0);
      expect(g.open, isFalse);
      expect(g.reason, contains('tükenir'));
    });

    test('kese yetmezse bağış kapalı', () {
      final cost = grantCost(4, 2);
      expect(
          gateFor(HouseActionKind.grant,
                  authority: 0,
                  sealedLaws: const {},
                  members: 4,
                  gold: cost - 1,
                  grantTier: 2)
              .open,
          isFalse);
      expect(
          gateFor(HouseActionKind.grant,
                  authority: 0,
                  sealedLaws: const {},
                  members: 4,
                  gold: cost,
                  grantTier: 2)
              .open,
          isTrue);
    });
  });

  group('bedel dengesi', () {
    HouseActionOutcome out(HouseActionKind k,
            {int members = 4, int harsh = 0, bool auth = true}) =>
        outcomeOf(k,
            members: members, recentHarsh: harsh, authoritarian: auth);

    test('el koyma kaynak kazandırır AMA bedelsiz değil', () {
      final o = out(HouseActionKind.seize);
      expect(o.gold, greaterThan(0));
      expect(o.food, greaterThan(0));
      // Siyasi bedel: hedef kanar, köy korkar, huzursuzluk artar.
      expect(o.targetMood, lessThan(-0.2));
      expect(o.otherMood, lessThan(0), reason: 'diğer haneler korkmalı');
      expect(o.unrest, greaterThan(0));
      expect(o.villageMorale, lessThan(0));
    });

    test('aynı haneye tekrar sertlik: bedel KATLANIR, getiri artmaz', () {
      final ilk = out(HouseActionKind.seize, harsh: 0);
      final ucuncu = out(HouseActionKind.seize, harsh: 2);
      expect(ucuncu.gold, ilk.gold, reason: 'getiri sabit — sağmak işe yaramaz');
      expect(ucuncu.targetMood, lessThan(ilk.targetMood));
      expect(ucuncu.unrest, greaterThan(ilk.unrest));
      expect(escalationMul(2), greaterThan(escalationMul(0)));
    });

    test('bağış: hane güçlenir (nüfuzu artar) ama ötekiler kıskanır', () {
      final o = out(HouseActionKind.grant);
      expect(o.gold, lessThan(0), reason: 'keseden çıkar');
      expect(o.targetMood, greaterThan(0));
      expect(o.targetSway, greaterThan(0), reason: 'kayırdığın hane güçlenir');
      expect(o.otherMood, lessThan(0), reason: 'ötekiler kıskanır');
    });

    test('yumuşak eylemlerde tekrar bedeli birikmez', () {
      final a = out(HouseActionKind.grant, harsh: 0);
      final b = out(HouseActionKind.grant, harsh: 3);
      expect(a.targetMood, b.targetMood);
      expect(HouseActionKind.grant.harsh, isFalse);
      expect(HouseActionKind.seize.harsh, isTrue);
    });

    test('nikâh: zorlama (baskı) öneriden (hür) daha ağır', () {
      final zorla = out(HouseActionKind.betroth, auth: true);
      final oneri = out(HouseActionKind.betroth, auth: false);
      expect(zorla.targetMood, lessThan(oneri.targetMood));
      expect(zorla.unrest, greaterThan(oneri.unrest));
    });

    test('entrika: hâl değişmez (kimse bilmiyor), nüfuz sessizce kırılır', () {
      final o = out(HouseActionKind.scheme);
      expect(o.targetMood, 0);
      expect(o.otherMood, 0);
      expect(o.targetSway, lessThan(0));
      expect(o.gold, lessThan(0));
    });

    test('el koyma getirisi büyük hanede daha çok', () {
      expect(out(HouseActionKind.seize, members: 10).gold,
          greaterThan(out(HouseActionKind.seize, members: 2).gold));
    });

    test('sürgün en sert: el koymadan da ağır kanatır', () {
      expect(out(HouseActionKind.exile).targetMood,
          lessThan(out(HouseActionKind.seize).targetMood));
    });
  });

  _massSeizureTests();

  group('entrika ifşa riski', () {
    test('hür rejimde baskı rejiminden YÜKSEK', () {
      expect(schemeExposureChance(authority: -1.0, targetSwayShare: 0.2),
          greaterThan(schemeExposureChance(authority: 1.0, targetSwayShare: 0.2)));
    });

    test('nüfuzlu haneye dokunmak daha riskli', () {
      expect(schemeExposureChance(authority: 0, targetSwayShare: 0.6),
          greaterThan(schemeExposureChance(authority: 0, targetSwayShare: 0.1)));
    });

    test('olasılık her zaman makul aralıkta', () {
      for (final a in [-1.0, -0.3, 0.0, 0.5, 1.0]) {
        for (final s in [0.0, 0.5, 1.0]) {
          final p = schemeExposureChance(authority: a, targetSwayShare: s);
          expect(p, inInclusiveRange(0.05, 0.75));
        }
      }
    });
  });
}

void _massSeizureTests() {
  const laws = {'nizam.registry'};

  group('topyekûn el koyma (kamulaştırma)', () {
    test('radikal + ortakçı + ferman → açık', () {
      final g = massSeizureGate(
          authority: 0.7,
          economy: -0.5,
          sealedLaws: laws,
          alreadyDone: false,
          houseCount: 4);
      expect(g.open, isTrue);
    });

    test('MÜLKÇÜ köy mülkiyeti kaldıramaz (kendi mantığıyla çelişir)', () {
      final g = massSeizureGate(
          authority: 0.9,
          economy: 0.5, // mülkçü
          sealedLaws: laws,
          alreadyDone: false,
          houseCount: 4);
      expect(g.open, isFalse);
      expect(g.reason, contains('mülkü kutsal'));
    });

    test('yeterince radikal değilse kapalı', () {
      final g = massSeizureGate(
          authority: 0.2,
          economy: -0.8,
          sealedLaws: laws,
          alreadyDone: false,
          houseCount: 4);
      expect(g.open, isFalse);
      expect(g.reason, contains('mutlak'));
    });

    test('ferman yoksa kapalı', () {
      final g = massSeizureGate(
          authority: 0.9,
          economy: -0.8,
          sealedLaws: const {},
          alreadyDone: false,
          houseCount: 4);
      expect(g.open, isFalse);
      expect(g.reason, contains('ferman'));
    });

    test('BİR KEZ yapılır — ikinci sefer kapalı', () {
      final g = massSeizureGate(
          authority: 0.9,
          economy: -0.8,
          sealedLaws: laws,
          alreadyDone: true,
          houseCount: 4);
      expect(g.open, isFalse);
      expect(g.reason, contains('ikinci kez'));
    });

    test('getiri konut sayısıyla ölçeklenir', () {
      expect(massSeizureYield(10).gold, greaterThan(massSeizureYield(2).gold));
      expect(massSeizureYield(10).food, greaterThan(massSeizureYield(2).food));
    });
  });

  group('bağış kademesi', () {
    test('konak bağışı ahşap evden pahalı', () {
      expect(grantCost(4, 4), greaterThan(grantCost(4, 3)));
      expect(grantCost(4, 3), greaterThan(grantCost(4, 2)));
    });

    test('bağışlanacak mülk yoksa (zaten konak) kapalı', () {
      final g = gateFor(HouseActionKind.grant,
          authority: 0,
          sealedLaws: const {},
          members: 3,
          gold: 9999,
          grantTier: null);
      expect(g.open, isFalse);
      expect(g.reason, contains('konakta'));
    });
  });
}
