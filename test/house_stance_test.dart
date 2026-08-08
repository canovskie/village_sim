import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/house_stance.dart';

/// Hane karşılığı: merdivenin İKİ omurgası kilitlenir —
///  (1) kızgınlık tek başına yetmez, hanenin KOZU da olmalı,
///  (2) her basamak bir öncekinin üstüne TEK yeni şey ekler (okunabilirlik),
///  (3) hiçbir basamak geri dönülemez değil (cozy sınırı).

/// Verilen kızgınlığı üreten mood — testleri eşik sayılarına bağlamamak için.
double _moodFor(double grievance) => kSettledMood * (1 - grievance);

HouseStance _stance(double grievance, {double leverage = 1.0, int houses = 4}) =>
    stanceFor(
      mood: _moodFor(grievance),
      swayShare: leverage / houses,
      houseCount: houses,
      members: 5,
    );

void main() {
  group('merdiven: kızgınlık', () {
    test('taban ve üstü razı — hane kızgın değildir', () {
      expect(_stance(0.0), HouseStance.content);
      expect(grievanceOf(kSettledMood), 0.0);
      expect(grievanceOf(0.9), 0.0, reason: 'taban üstü kızgınlık üretmez');
    });

    test('çok memnun hane SADIK — merdivenin ödül ucu', () {
      final s = stanceFor(
          mood: 0.85, swayShare: 0.25, houseCount: 4, members: 5);
      expect(s, HouseStance.loyal);
      expect(withholdingFor(s, grievance: 0).bounty, greaterThan(0),
          reason: 'sadık hane fazladan vermeli — karşılık iki yönlü');
    });

    test('serzeniş basamağı hiçbir şey esirgemez (uyarı penceresi)', () {
      final s = _stance((kMurmurGrievance + kWithdrawGrievance) / 2);
      expect(s, HouseStance.murmuring);
      expect(withholdingFor(s, grievance: 0.2).isNeutral, isTrue,
          reason: 'oyuncu bedel ödemeden uyarılmalı');
      expect(s.audible, isTrue, reason: 'ama köy bunu duymalı');
      expect(s.withholds, isFalse);
    });

    test('kızgınlık arttıkça basamak sertleşir', () {
      final ladder = [
        _stance(0.05),
        _stance(0.18),
        _stance(0.35),
        _stance(0.52, leverage: 1.5),
        _stance(0.75, leverage: 1.5),
      ];
      expect(ladder, [
        HouseStance.content,
        HouseStance.murmuring,
        HouseStance.withdrawn,
        HouseStance.hoarding,
        HouseStance.defiant,
      ]);
    });
  });

  group('merdiven: koz (leverage)', () {
    test('nüfuzsuz hane ne kadar kızarsa kızsın el çekmenin ötesine geçemez', () {
      for (final g in [0.5, 0.7, 0.95]) {
        final s = _stance(g, leverage: 0.3);
        expect(s, HouseStance.withdrawn,
            reason: 'kozu olmayan hane ambarı kapatamaz (kızgınlık $g)');
      }
    });

    test('kozlu hane aynı kızgınlıkta bir üst basamağa çıkar', () {
      const g = 0.5;
      expect(_stance(g, leverage: 0.4), HouseStance.withdrawn);
      expect(_stance(g, leverage: 1.2), HouseStance.hoarding);
    });

    test('koz ADİL PAYA oranlıdır — kalabalık köyde de merdiven tırmanılır', () {
      // %20 pay: 8 haneli köyde güçlü (1.6 koz), 2 haneli köyde zayıf (0.4).
      expect(leverageOf(0.20, 8), closeTo(1.6, 0.001));
      expect(leverageOf(0.20, 2), closeTo(0.4, 0.001));
      final crowded = stanceFor(
          mood: _moodFor(0.5), swayShare: 0.20, houseCount: 8, members: 5);
      expect(crowded, HouseStance.hoarding);
    });

    test('tek hane köyünde koz her zaman 1.0', () {
      expect(leverageOf(1.0, 1), 1.0);
      expect(leverageOf(0.0, 0), 1.0);
    });
  });

  group('esirgeme: her basamak TEK yeni şey ekler', () {
    HouseWithholding w(HouseStance s, double g) =>
        withholdingFor(s, grievance: g);

    test('el çekti: yalnız emek', () {
      final x = w(HouseStance.withdrawn, 0.35);
      expect(x.labor, greaterThan(0));
      expect(x.hoard, 0);
      expect(x.betrothal, isFalse);
      expect(x.council, isFalse);
    });

    test('ambar kapalı: emek + ürün, ama masa ve nikâh sürüyor', () {
      final x = w(HouseStance.hoarding, 0.5);
      expect(x.labor, greaterThan(0));
      expect(x.hoard, greaterThan(0));
      expect(x.betrothal, isFalse);
      expect(x.council, isFalse);
    });

    test('kopuş: hepsi', () {
      final x = w(HouseStance.defiant, 0.8);
      expect(x.betrothal, isTrue);
      expect(x.council, isTrue);
      expect(x.hoard, greaterThan(w(HouseStance.hoarding, 0.5).hoard));
    });

    test('basamak içinde kızgınlık rampası artan — sıçrama yok', () {
      final az = w(HouseStance.withdrawn, kWithdrawGrievance);
      final cok = w(HouseStance.withdrawn, kHoardGrievance);
      expect(cok.labor, greaterThan(az.labor));
      expect(cok.labor, lessThan(1.0), reason: 'el çekme hiçbir zaman tam değil');
    });

    test('hiçbir basamak emeği TAMAMEN kesmez — köy durmaz (cozy)', () {
      for (final s in HouseStance.values) {
        expect(w(s, 1.0).labor, lessThan(1.0));
      }
    });
  });

  group('üyesiz hane', () {
    test('sönmüş soy nüfuzu kağıtta dursa da hiçbir şey esirgeyemez', () {
      final s = stanceFor(
          mood: 0.02, swayShare: 0.9, houseCount: 3, members: 0);
      expect(s, HouseStance.content);
    });
  });

  group('stash: saklanan yiyecek', () {
    test('üye başına sınırlı — hane köyün ambarından büyük olamaz', () {
      expect(stashRoom(0, 5), 5 * kStashPerMember);
      expect(stashRoom(5 * kStashPerMember, 5), 0,
          reason: 'dolunca saklama durur, ambar kalıcı kurumaz');
      expect(stashRoom(999, 5), 0, reason: 'taşma negatife düşmemeli');
    });

    test('geri dönüş kademeli — barışın karşılığı birkaç güne yayılır', () {
      expect(kStashReturnPerDay, greaterThan(0));
      expect(kStashReturnPerDay, lessThan(1.0));
    });
  });

  group('önizleme', () {
    test('bir üst basamak gösterilebilir (bedel önceden görünür)', () {
      expect(nextRung(HouseStance.murmuring), HouseStance.withdrawn);
      expect(nextRung(HouseStance.hoarding), HouseStance.defiant);
    });

    test('uçlarda üst basamak yok', () {
      expect(nextRung(HouseStance.defiant), isNull);
      expect(nextRung(HouseStance.loyal), isNull);
    });
  });
}
