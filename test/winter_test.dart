import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/winter.dart';
import 'package:village_sim/world/season.dart';

/// KIŞ ÇEKİRDEĞİ — saf matematiğin regresyonu.
///
/// Buradaki her sayı bir tasarım kararıdır (kış cezalandırmaz, hazırlığı
/// ödüllendirir; ölüm yalnız ihmalin birikmesiyle gelir). Sayılar kayarsa
/// kışın KARAKTERİ kayar — testler o karakteri tutar, ondalıkları değil.
void main() {
  WinterReadiness r({
    int mouths = 10,
    int animals = 4,
    double wood = 0,
    double coal = 0,
    double food = 0,
    double fodder = 0,
    int coats = 0,
    int? days,
  }) => winterReadiness(
    mouths: mouths,
    animals: animals,
    wood: wood,
    coal: coal,
    food: food,
    fodder: fodder,
    coats: coats,
    days: days,
  );

  group('kışa hazırlık', () {
    test('boş ambar = sıfır hazırlık', () {
      expect(r().overall, 0.0);
    });

    test('GEÇİMDE en zayıf halka belirler — ortalama değil', () {
      // Yakacak/yem/giysi tam, erzak yok: köy kışın aç kalır. Ortalama
      // alsaydık %75 "hazır" görünürdü.
      final w = r(
        wood: 999,
        fodder: 999,
        coats: 10,
        food: 0,
      );
      expect(w.overall, 0.0, reason: 'aç köy hazır sayılamaz');
      expect(w.weakest.label, 'Erzak');
    });

    test('GİYSİ göstergeyi sıfırlamaz — geçim değil rahatlık kalemi', () {
      // Ambarı dolu ama giysisiz köy: kışı çıkarır, titreyerek çıkarır.
      // Giysi de "en zayıf halka"ya dahilken bu köy %0 görünüyordu ve kışın
      // ortasında yün üretilemediği için oyuncunun yapabileceği bir şey yoktu.
      final w = r(wood: 999, food: 999, fodder: 999, coats: 0);
      expect(w.overall, greaterThan(0.65));
      expect(w.overall, lessThan(0.90), reason: 'giysisiz köy "hazır" olamaz');
      expect(w.ready, isFalse);
      expect(w.weakest.label, 'Kışlık', reason: 'eksik yine de adıyla anılmalı');
    });

    test('kömür odundan uzun yanar — aynı kışı daha az yükle çıkarır', () {
      // Miktar bilerek ihtiyacın ALTINDA: ikisi de yeterse oran 1.0'a
      // kırpılır ve test hiçbir şey ölçmez (ilk sürümün hatası).
      final withWood = r(wood: 10).fuel.ratio;
      final withCoal = r(coal: 10).fuel.ratio;
      expect(withCoal, greaterThan(withWood));
    });

    test('hayvan yoksa yem kalemi hazır sayılır (bölme hatası değil)', () {
      expect(r(animals: 0).fodder.ratio, 1.0);
      expect(r(animals: 0).fodder.ready, isTrue);
    });

    test('ihtiyaç nüfusla büyür — sabit sayı köy büyüyünce yalan söyler', () {
      final small = r(mouths: 5, food: 30).food.ratio;
      final big = r(mouths: 20, food: 30).food.ratio;
      expect(big, lessThan(small));
    });

    test('hazır köy %90 eşiğini geçer, son kırıntı kovalatılmaz', () {
      final w = r(
        mouths: 10,
        animals: 4,
        wood: 10 * kFuelPerMouthPerDay * kWinterDays * 0.95,
        food: 10 * kFoodPerMouthPerDay * kWinterDays * 0.95,
        fodder: 4 * kFodderPerAnimalPerDay * kWinterDays * 0.95,
        coats: 10,
      );
      expect(w.ready, isTrue);
    });

    test('kalan güne göre sorulabilir — kışın ortasında "ne kadar dayanırım"',
        () {
      final full = r(mouths: 10, food: 20, days: kWinterDays).food.ratio;
      final oneDay = r(mouths: 10, food: 20, days: 1).food.ratio;
      expect(oneDay, greaterThan(full));
    });
  });

  // Kış göstergesi HUD'dan kalkıp köyün ağzına taşındığında (bkz.
  // ui/winter_section.dart) uyarının BİRİMİ de değişti: yüzde değil GÜN.
  // "Odun iki güne biter" bir cümledir; "%40" bir puandır.
  group('kaç gün yeter', () {
    test('gün sayısı stok ÷ günlük ihtiyaç', () {
      // 10 ağız × 1.05 = günde 10.5 erzak; 21 birim tam iki gün eder.
      final w = r(mouths: 10, food: 10 * kFoodPerMouthPerDay * 2);
      expect(w.daysLeftOf(w.food), closeTo(2.0, 0.001));
    });

    test('gerekmeyen kalem sonsuz gün yeter — bölme hatası değil', () {
      final w = r(animals: 0, fodder: 0);
      expect(w.daysLeftOf(w.fodder), double.infinity);
    });

    test('İLK TÜKENECEK kalem seçilir — köy tek şeyden şikâyet eder', () {
      // Yakacak bol, erzak iki günlük, yem bir günlük: mırıltı yemi söylemeli.
      final w = r(
        mouths: 10,
        animals: 4,
        wood: 999,
        food: 10 * kFoodPerMouthPerDay * 2,
        fodder: 4 * kFodderPerAnimalPerDay * 1,
      );
      expect(w.tightest.label, 'Yem');
    });

    test('kışlık tükenme yarışına girmez — geçim kalemi değil', () {
      // Sırtlar çıplak ama ambar dolu: köyün söyleyeceği şey açlık değil.
      final w = r(wood: 999, food: 999, fodder: 999, coats: 0);
      expect(w.tightest.label, isNot('Kışlık'));
      expect(w.daysLeftOf(w.food), greaterThanOrEqualTo(w.days.toDouble()));
    });
  });

  group('bireyin üşümesi', () {
    test('giysi üşümeyi YAVAŞLATIR ama bitirmez', () {
      final withCoat = chillMultiplier(
        coat: true,
        child: false,
        elder: false,
        shelterWarmth: 0,
      );
      expect(withCoat, lessThan(1.0), reason: 'giysinin faydası olmalı');
      expect(withCoat, greaterThan(0.0),
          reason: 'giysi kışı tamamen çözerse ocak/dam anlamsızlaşır');
    });

    test('çocuk ve yaşlı daha hızlı üşür', () {
      double m({bool child = false, bool elder = false}) => chillMultiplier(
        coat: false,
        child: child,
        elder: elder,
        shelterWarmth: 0,
      );
      expect(m(child: true), greaterThan(m()));
      expect(m(elder: true), greaterThan(m()));
    });

    test('sıcak barınak üşümeyi yarıya indirir ama sıfırlamaz', () {
      final cold = chillMultiplier(
        coat: false,
        child: false,
        elder: false,
        shelterWarmth: 0,
      );
      final warm = chillMultiplier(
        coat: false,
        child: false,
        elder: false,
        shelterWarmth: 1,
      );
      expect(warm, lessThan(cold));
      expect(warm, greaterThan(0.0));
    });

    test('hafif üşüme iş hızını DÜŞÜRMEZ — kışın herkes biraz üşür', () {
      expect(chillWorkPenalty(0.0), 1.0);
      expect(chillWorkPenalty(0.44), 1.0);
    });

    test('dolan üşüme iş hızını düşürür ama işi durdurmaz', () {
      final full = chillWorkPenalty(1.0);
      expect(full, lessThan(1.0));
      expect(full, greaterThan(0.4), reason: 'köy kışın felç olmamalı');
    });
  });

  group('ihmal — kış tek başına öldürmez', () {
    test('tek ihmalin hastalık cezası YOK', () {
      expect(
        neglectIllnessMultiplier(coldNeglect(
          fireDead: true,
          coldShelter: false,
          noCoat: false,
          larderEmpty: false,
        )),
        1.0,
      );
    });

    test('iki ihmal uyarı, üç ihmal gerçek tehlike', () {
      final two = neglectIllnessMultiplier(2);
      final three = neglectIllnessMultiplier(3);
      expect(two, greaterThan(1.0));
      expect(three, greaterThan(two * 1.4),
          reason: 'üçüncü ihmal hissedilir bir sıçrama olmalı');
    });

    test('ihmal sayacı dördü geçmez, çarpan sınırlı', () {
      expect(
        coldNeglect(
          fireDead: true,
          coldShelter: true,
          noCoat: true,
          larderEmpty: true,
        ),
        4,
      );
      expect(neglectIllnessMultiplier(4), lessThanOrEqualTo(3.0));
    });
  });

  group('dünyanın kışı', () {
    test('yalnız kış donar', () {
      expect(waterFrozen(Season.winter), isTrue);
      for (final s in Season.values.where((s) => s != Season.winter)) {
        expect(waterFrozen(s), isFalse);
      }
    });

    test('karda yavaşlama hissedilir ama ağır çekim değil', () {
      expect(kSnowSpeedMultiplier, lessThan(1.0));
      expect(kSnowSpeedMultiplier, greaterThan(0.8));
    });
  });
}
