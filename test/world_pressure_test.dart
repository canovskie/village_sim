// KÖYÜN HÂLİ — yasa/rejim/mevsim/huzursuzluk → tek davranış tablosu.
//
// Bu testin derdi sayıların TAM DEĞERİ değil (denge oynar), tablonun
// SÖZLEŞMESİ. Kilitlenen tasarım kararları:
//   • Mühür basmak dünyayı GÖZLE GÖRÜLÜR biçimde değiştirir — Tek Söz sokağı
//     boşaltır, Meclis-i Daimi meydanı doldurur. Yön yanlışsa test düşer.
//   • Aynı etken iki kez sayılmaz (nöbet yasası hem bayraktan hem hükümden).
//   • Tavanlar tutar: hükümler üst üste binse bile köy tanınmaz hâle gelmez;
//     özellikle sokağa çıkma yasağı köyü gündüz uykuya sokamaz.
//   • Kimliği olmayan (mühürsüz) köy tam olarak nötrdür — sistem "hep bir
//     şeyler oluyor" gürültüsü üretmez.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/world_pressure.dart';
import 'package:village_sim/world/season.dart';

/// Test kısayolu — yalnız ilgilenilen ekseni verip kalanı sabit tutar.
WorldPressure p({
  Set<String> sealed = const {},
  Set<String> memory = const {},
  VillageRegime regime = VillageRegime.moderate,
  Season season = Season.spring,
  double unrest = 0,
  double scarcity = 0,
  double plenty = 0,
  int dayCount = 3,
  double authority = 0,
  double economy = 0,
  double faith = 0,
}) =>
    WorldPressure.derive(
      sealed: sealed,
      memory: memory,
      compass: CompassPosition(
        authority: authority,
        economy: economy,
        faith: faith,
        lawCount: sealed.length,
      ),
      regime: regime,
      season: season,
      unrest: unrest,
      dayCount: dayCount,
      scarcity: scarcity,
      plenty: plenty,
    );

void main() {
  group('nötr köy', () {
    test('mühürsüz köy tam nötrdür — sistem kendiliğinden gürültü üretmez', () {
      final n = p();
      expect(n.curfewBias, 0);
      expect(n.workDrive, 1);
      expect(n.marketPull, 1);
      expect(n.squarePull, 1);
      expect(n.crimeUrge, 1);
      expect(n.crimeRisk, 1);
      expect(n.lanternMandate, isFalse);
    });

    test('mühürsüz köyün özetinde yönetişim satırı çıkmaz', () {
      // Mevsim GERÇEK dünya durumudur (ilkbahar gezintiyi artırır) — özette
      // görünmesi doğru. Sözleşme şu: köy hiçbir hüküm mühürlemediyse özette
      // YÖNETİŞİM kaynaklı hiçbir satır olmaz.
      final r = p().readout;
      for (final governance in const [
        'sokağa çıkma',
        'itaat',
        'fener',
        'devriye',
        'tedirginlik',
      ]) {
        expect(r.any((s) => s.contains(governance)), isFalse,
            reason: 'mühürsüz köyde "$governance" satırı olmamalı: $r');
      }
    });
  });

  group('Tek Söz — köyün en sert hükmü', () {
    final sole = p(sealed: const {'nizam.sole'});

    test('sokağa çıkma yasağı gerçekten doğar', () {
      expect(sole.curfewBias, greaterThan(0.1));
    });

    test('meydan boşalır, ev dolar', () {
      expect(sole.squarePull, lessThan(0.6));
      expect(sole.homePull, greaterThan(1.2));
    });

    test('köy susar ve eğilir', () {
      expect(sole.outspoken, lessThan(p().outspoken));
      expect(sole.deference, greaterThan(0.3));
      expect(sole.wariness, greaterThan(0.15));
    });

    test('caydırıcılık yükselir, karanlıkta fener mecburi olur', () {
      expect(sole.crimeRisk, greaterThan(1.4));
      expect(sole.lanternMandate, isTrue);
    });
  });

  group('Meclis-i Daimi — Tek Söz\'ün tam karşıtı', () {
    final meclis = p(sealed: const {'rejim.meclisDaimi'});

    test('meydan dolar ve köy konuşur', () {
      expect(meclis.squarePull, greaterThan(1.8));
      expect(meclis.outspoken, greaterThan(p().outspoken));
    });

    test('iki hüküm zıt yönde çeker — biri diğerini bastırmaz, toplanır', () {
      final both = p(sealed: const {'nizam.sole', 'rejim.meclisDaimi'});
      final soleOnly = p(sealed: const {'nizam.sole'});
      expect(both.squarePull, greaterThan(soleOnly.squarePull));
      expect(both.squarePull, lessThan(meclis.squarePull));
    });
  });

  group('Kutsal Gün — haftalık ritim', () {
    test('kutsal günde mesai durur, mabet dolar', () {
      final holy = p(sealed: const {'dergah.holyDay'}, dayCount: 7);
      expect(holy.workDrive, lessThan(0.6));
      expect(holy.churchPull, greaterThan(2.0));
      expect(holy.restDrive, greaterThan(1.2));
    });

    test('sıradan günde aynı hüküm köyü durdurmaz', () {
      final plain = p(sealed: const {'dergah.holyDay'}, dayCount: 8);
      expect(plain.workDrive, 1);
      expect(plain.churchPull, lessThan(1.3));
    });
  });

  group('çift sayım tuzağı', () {
    test('gece nöbeti caydırıcılığı bayraktan gelir, hükümden İKİNCİ KEZ değil',
        () {
      // nizam.watch hükmü köy hafızasına 'crime.watch' basar. Etki tek kez
      // uygulanmalı; hüküm + bayrak birlikte verildiğinde sonuç yalnız
      // bayrağınkiyle aynı büyüklük mertebesinde kalmalı.
      final flagOnly = p(memory: const {'crime.watch'});
      final lawAndFlag = p(
        sealed: const {'nizam.watch'},
        memory: const {'crime.watch'},
      );
      expect(lawAndFlag.crimeRisk, flagOnly.crimeRisk);
      // Hükme özgü kalan (uyanıklık) yine de eklenmeli — yoksa hüküm boş olurdu.
      expect(lawAndFlag.patrolVigilance, greaterThan(flagOnly.patrolVigilance));
      expect(lawAndFlag.patrolDensity, greaterThan(flagOnly.patrolDensity));
    });
  });

  group('sebepler', () {
    test('açlık suç dürtüsünü besler — en eski sebep', () {
      expect(p(scarcity: 0.8).crimeUrge, greaterThan(p().crimeUrge * 1.5));
    });

    test('huzursuzluk önce dile gelir, sonra meydana', () {
      final hot = p(unrest: 0.9);
      expect(hot.outspoken, greaterThan(p().outspoken));
      expect(hot.squarePull, greaterThan(1.2));
      expect(hot.cheer, lessThan(p().cheer));
      // Kaynayan köyde kimse kimseyi ele vermez.
      expect(hot.informUrge, lessThan(p().informUrge));
    });

    test('ortak ambar hırsızlığın sebebini kurutur, mülk tapusu yaratır', () {
      expect(p(sealed: const {'rejim.ortakAmbar'}).crimeUrge, lessThan(1.0));
      expect(p(sealed: const {'rejim.mulkTapusu'}).crimeUrge, greaterThan(1.0));
    });

    test('kış köyü ateş başına ve eve toplar', () {
      final w = p(season: Season.winter);
      expect(w.firePull, greaterThan(1.4));
      expect(w.strollPull, lessThan(0.8));
      expect(w.homePull, greaterThan(1.1));
    });
  });

  group('rejim silueti', () {
    test('rejim etkisi pusula şiddetiyle ölçeklenir — merkez renksizdir', () {
      final weak = p(regime: VillageRegime.sealedHand, authority: 0.05);
      final strong = p(regime: VillageRegime.sealedHand, authority: 0.9);
      expect(weak.deference, lessThan(strong.deference));
      expect(strong.squarePull, lessThan(weak.squarePull));
    });

    test('komün ile mühürlü el zıt siluetler üretir', () {
      final commune =
          p(regime: VillageRegime.commune, authority: -0.8, economy: -0.8);
      final sealed =
          p(regime: VillageRegime.sealedHand, authority: 0.8, economy: 0.8);
      expect(commune.squarePull, greaterThan(sealed.squarePull * 2));
      expect(commune.visitPull, greaterThan(sealed.visitPull));
      expect(sealed.deference, greaterThan(commune.deference));
      expect(sealed.homePull, greaterThan(commune.homePull));
    });
  });

  group('tavanlar', () {
    test('her şey üst üste binse bile köy gündüz uykuya gömülmez', () {
      final worst = p(
        sealed: const {
          'nizam.sole',
          'nizam.watch',
          'nizam.labor',
          'nizam.exile',
          'nizam.registry',
          'dergah.oneFaith',
          'rejim.mulkTapusu',
          'rejim.muhassil',
        },
        memory: const {'crime.watch'},
        regime: VillageRegime.sealedHand,
        authority: 1.0,
        economy: 1.0,
        faith: 1.0,
        season: Season.winter,
        unrest: 1.0,
        scarcity: 1.0,
      );
      // kNightThreshold 0.15 + bias, kDawnThreshold 0.25 — bias tavanı bunu
      // aşabilir ama köylü uyanma eşiği buna göre kayar (villager_entity).
      // Buradaki sözleşme: bias SONSUZ büyümez.
      expect(worst.curfewBias, lessThanOrEqualTo(0.22));
      expect(worst.workDrive, greaterThanOrEqualTo(0.35));
      // Tamamen susmuş bir köy bile sıfır sosyal olmaz (0'a kilitlenirse
      // sohbet sistemi tamamen ölür).
      expect(worst.outspoken, greaterThanOrEqualTo(0.0));
      expect(worst.squarePull, greaterThanOrEqualTo(0.15));
      expect(worst.crimeUrge, lessThanOrEqualTo(3.0));
      expect(worst.crimeRisk, lessThanOrEqualTo(3.0));
    });

    test('bolluk ve şenlik tarafı da tavanlıdır', () {
      final best = p(
        sealed: const {
          'neighborliness',
          'greenVillage',
          'familyEncouragement',
          'hospitality',
          'sharedHarvest',
          'peacefulEnd',
          'eldersExemptFromFood',
          'slowMaturity',
          'rejim.meclisDaimi',
          'rejim.ortakAmbar',
          'dergah.holyDay',
        },
        regime: VillageRegime.commune,
        authority: -1.0,
        economy: -1.0,
        dayCount: 7,
      );
      expect(best.cheer, lessThanOrEqualTo(1.0));
      expect(best.squarePull, lessThanOrEqualTo(3.5));
      expect(best.churchPull, lessThanOrEqualTo(3.5));
      expect(best.crimeUrge, greaterThanOrEqualTo(0.15));
    });
  });

  test('okunur özet gerçekten değişeni yazar', () {
    final r = p(sealed: const {'nizam.sole'}).readout;
    expect(r.any((s) => s.contains('sokağa çıkma')), isTrue);
    expect(r.any((s) => s.contains('fener')), isTrue);
    expect(r.any((s) => s.contains('meydan')), isTrue);
  });

  // ── GÖRÜNEN HÂL (Faz 5) ────────────────────────────────────────────────────
  //
  // Üç kanalın sözleşmesi: köyün NASIL GÖRÜNDÜĞÜ, ne yaptığından türer. Bu
  // testlerin asıl işi yönü kilitlemek — kılık/öbeklenme/telaş ters yöne
  // bakarsa yasa dünyada YANLIŞ bir cümle kurar, ki sessiz kalmasından beterdir.
  group('görünen hâl', () {
    test('mühürsüz köy görünüşte de tabana yakındır', () {
      final n = p();
      // Kılık tam sıfır: ambar dolu da boş da değilse kumaş taban palettedir.
      expect(n.provision, 0);
      // Öbeklenme/telaş tam taban DEĞİL, tabana yakın: `p()` varsayılanı
      // İLKBAHAR ve mevsim şenliği hafifçe yükseltir. Bu kasıtlı — mevsim de
      // köyün hâlidir, mühür olmadan da köy baharda biraz daha bir aradadır.
      // Test yönü değil, BÜYÜKLÜĞÜ kilitler: mevsim payı fark edilir olmamalı.
      expect(n.huddle, closeTo(0.35, 0.05));
      expect(n.hurry, closeTo(1.0, 0.05));
      // Kış tersine iter (curfewBias + şenlik düşüşü) ama yine ölçülü kalır.
      expect(p(season: Season.winter).huddle, lessThan(n.huddle));
    });

    test('ambar boşalınca kılık solar, dolunca doyar', () {
      expect(p(scarcity: 1.0).provision, lessThan(-0.5));
      expect(p(plenty: 1.0).provision, greaterThan(0.5));
      // Yoksunluk daha ağır basar — aç köy tok köyden çabuk okunur.
      expect(p(scarcity: 1.0).provision.abs(),
          greaterThan(p(plenty: 1.0).provision.abs()));
      // İkisi aynı anda gelirse (ambar hem boş hem dolu olamaz ama eşik
      // aralığında ikisi de küçük değer verebilir) tablo çökmez.
      expect(p(scarcity: 0.5, plenty: 0.5).provision.abs(), lessThan(0.5));
    });

    test('kılık YALNIZ ambardan konuşur — rejim/yasa kumaşı boyamaz', () {
      // Kasıtlı sözleşme: kılık ekseni yoksunluk↔refah. Rejim rengi ayrı bir
      // eksen olarak sonradan eklenebilir, ama bugün karışmamalı — yoksa
      // oyuncu solmuş kumaşa bakıp "kıtlık mı, otorite mi?" diye kalır.
      expect(p(regime: VillageRegime.sealedHand, authority: 1.0).provision, 0);
      expect(p(sealed: const {'nizam.sole'}).provision, 0);
    });

    test('baskı sokağı dağıtır ve adımı hızlandırır', () {
      final free = p(regime: VillageRegime.commune, authority: -1.0, economy: -1.0);
      final hard = p(regime: VillageRegime.sealedHand, authority: 1.0, economy: 1.0);
      expect(hard.huddle, lessThan(free.huddle),
          reason: 'baskı altındaki köy hür köyden daha kalabalık duramaz');
      expect(hard.hurry, greaterThan(free.hurry),
          reason: 'baskı altında sokakta oyalanılmaz');
    });

    test('sokağa çıkma yasağı öbeklenmeyi kırar', () {
      final base = p();
      final curfew = p(sealed: const {'nizam.sole'});
      expect(curfew.huddle, lessThan(base.huddle));
      expect(curfew.hurry, greaterThan(base.hurry));
    });

    test('huzursuzluk hem toplar hem gerer', () {
      // Huzursuzluk sözü açar (outspoken↑ → öbeklenme) ama tedirginlik de
      // ekler (wariness↑ → telaş). İkisi aynı anda doğru: kalabalık toplanır
      // ve tedirgin yürür. Test yalnız telaşın arttığını kilitler; öbeklenme
      // yönü rejime göre değişebilir.
      expect(p(unrest: 0.9).hurry, greaterThan(p().hurry));
    });

    test('tavanlar tutar — köy ne heykel ne kaçkın olur', () {
      final extreme = p(
        sealed: const {'nizam.sole', 'nizam.watch', 'nizam.curfewHarsh'},
        regime: VillageRegime.sealedHand,
        authority: 1.0,
        economy: 1.0,
        unrest: 1.0,
        scarcity: 1.0,
      );
      expect(extreme.hurry, lessThanOrEqualTo(1.35));
      expect(extreme.hurry, greaterThanOrEqualTo(0.85));
      expect(extreme.huddle, greaterThanOrEqualTo(0.0));
      expect(extreme.huddle, lessThanOrEqualTo(1.0));
      expect(extreme.provision, greaterThanOrEqualTo(-1.0));
    });

    test('özet görünen hâli de yazar', () {
      final r = p(scarcity: 1.0).readout;
      expect(r.any((s) => s.contains('kılık')), isTrue,
          reason: 'kıtlıkta kumaş soluyor ama köyün hâli satırı susuyor');
    });
  });
}
