import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/estate_system.dart';
import 'package:village_sim/systems/law_compass.dart';
import 'package:village_sim/systems/petition_system.dart';
import 'package:village_sim/world/season.dart';

/// DİLEKÇE KATALOĞU — BÜTÜNLÜK.
///
/// Katalog 9 dosya, ~3.000 satır ve neredeyse tamamı veri. Verinin hatası
/// derlenmez, çökmez, `analyze`'a takılmaz: yalnızca sessizce YOKTUR. Bu
/// dosyanın kolladığı üç sessiz hata var ve üçü de gerçek bir oyunda ancak
/// aylar sonra fark edilir:
///
///   1. **Ölü bağ** — bir şık var olmayan bir takip dilekçesine işaret eder.
///      Oyuncu kararı verir, vaat edilen devam hiç gelmez.
///   2. **Öksüz halka** — bir takip dilekçesi yazılmış ama hiçbir şık onu
///      çağırmıyor. 200 satır metin, oyunda sıfır kez görünür.
///   3. **Ulaşılmaz dilekçe** — kapısı hiçbir köyde açılmayan dilekçe.
///      "Kod var ama hiç tetiklenmiyor"un veri hâli.
///
/// Metin/annal sözleşmesi başka yerde: `prose_test` (ham yer tutucu kalmaz),
/// `decision_trace_test` (her şık günceye bir cümle yazar), `late_petitions_test`
/// (olgunluk kapıları + olay ağaçlarının şekli).

/// Katalogdaki bir dilekçenin gerçek kapısı hiçbir bağlamda açılmıyorsa
/// [reachableIds] onu bulamaz — süpürme bu yüzden GENİŞ tutulur: her kapı
/// alanının hem açık hem kapalı hâli listede olmalı.
List<PetitionContext> sweep() {
  final out = <PetitionContext>[];

  // Taban: orta halli, olgun, her kapısı kapalı bir köy. Varyantlar bunun
  // üstüne TEK bir alanı açar — böylece bir dilekçe listeye giremezse suç
  // kesin olarak o alanın kapısındadır.
  PetitionContext base({
    int population = 20,
    int adults = 12,
    int food = 200,
    int gold = 90,
    double morale = 0.55,
    bool hasChurch = false,
    Set<String> memory = const {},
    Estate? aggrieved,
    Estate? ascendant,
    int herdSize = 0,
    bool herdHungry = false,
    Season season = Season.spring,
    bool hasCrops = false,
    bool hasResentful = false,
    bool hasFeud = false,
    String? withholdingHouse,
    int crimeSuspicion = 0,
    bool cropRotation = false,
    bool hospitality = false,
    bool hasHousing = false,
    int dayCount = 60,
    bool foundersAlive = true,
    int houseCount = 3,
    double dominantSway = 0.3,
    int sealedLaws = 4,
    VillageRegime regime = VillageRegime.moderate,
    double unrest = 0.2,
    bool craftLost = false,
    int imperialVisits = 1,
    double governanceLegacy = 0,
  }) => PetitionContext(
    population: population,
    adults: adults,
    food: food,
    gold: gold,
    morale: morale,
    hasChurch: hasChurch,
    memory: memory,
    aggrievedEstate: aggrieved,
    ascendant: ascendant,
    herdSize: herdSize,
    herdHungry: herdHungry,
    season: season,
    hasCrops: hasCrops,
    hasResentful: hasResentful,
    hasFeud: hasFeud,
    withholdingHouse: withholdingHouse,
    crimeSuspicion: crimeSuspicion,
    cropRotation: cropRotation,
    hospitality: hospitality,
    hasHousing: hasHousing,
    dayCount: dayCount,
    foundersAlive: foundersAlive,
    houseCount: houseCount,
    dominantSway: dominantSway,
    sealedLaws: sealedLaws,
    regime: regime,
    unrest: unrest,
    craftLost: craftLost,
    imperialVisits: imperialVisits,
    governanceLegacy: governanceLegacy,
  );

  out.add(base());

  // Köyün ölçeği — küçük kurucu köyünden kalabalığa.
  out.add(
    base(
      population: 3,
      adults: 2,
      dayCount: 2,
      sealedLaws: 0,
      houseCount: 1,
      imperialVisits: 0,
    ),
  );
  out.add(base(population: 6, adults: 4, dayCount: 6, sealedLaws: 0));
  out.add(base(population: 40, adults: 26, dayCount: 200, sealedLaws: 12));

  // Sıkıntı ve bolluk — kaynak kapıları iki uçtan da denenir.
  out.add(base(food: 0, gold: 0, morale: 0.1));
  out.add(base(food: 900, gold: 900, morale: 0.95));

  // Tekil kapılar — her biri TEK alanı açar.
  out.add(base(hasChurch: true));
  out.add(base(hasCrops: true));
  out.add(base(hasResentful: true));
  out.add(base(hasFeud: true));
  out.add(base(craftLost: true));
  out.add(base(foundersAlive: false));
  out.add(base(hospitality: true, hasHousing: true));
  out.add(base(cropRotation: true, hasCrops: true));
  out.add(base(withholdingHouse: 'Karaoğlu'));
  out.add(base(crimeSuspicion: 6));
  out.add(base(herdSize: 12));
  out.add(base(herdSize: 12, herdHungry: true));
  out.add(base(houseCount: 6, dominantSway: 0.85));
  out.add(base(imperialVisits: 5));
  out.add(base(governanceLegacy: 0.12));
  out.add(base(governanceLegacy: -0.12));

  // Mevsimler.
  for (final s in Season.values) {
    out.add(base(season: s, hasCrops: true));
  }

  // Rejim × huzursuzluk — sertleşen rejim itiraz, yumuşayan cesaret doğurur.
  for (final r in VillageRegime.values) {
    out.add(base(regime: r, unrest: 0.05));
    out.add(base(regime: r, unrest: 0.9));
  }

  // Zümreler — hem küskün hem baskın hâlleri.
  for (final e in Estate.values) {
    out.add(base(aggrieved: e));
    out.add(base(ascendant: e));
  }

  // Köyün hafızası — bayrak okuyan kapılar ancak bayrak konunca açılır.
  // Katalogda geçen HER bayrak toplanıp hepsi birden açılmış bir köy eklenir
  // (bayraklar birbirini dışlıyorsa tek tek de denenir).
  final flags = <String>{
    for (final p in PetitionSystem.allForTest)
      for (final o in p.options) ...o.setsFlags,
  };
  out.add(base(memory: flags, hasChurch: true));
  for (final f in flags) {
    out.add(base(memory: {f}, hasChurch: true));
  }

  return out;
}

/// Sahne kodunun `PetitionSystem.byId('...')` ile DOĞRUDAN çağırdığı dilekçe
/// id'leri. Bunlar ne rastgele havuza girer ne de bir şıktan zincirlenir —
/// olayın kendisi (suç, düğün, ateşin sönmesi) onları elle sahneye koyar.
///
/// Liste elle tutulmuyor, `lib/` taranıyor: elle tutulan liste eskir ve
/// eskiyen liste öksüz avını sessizce kapatır. Kaynağı okumak testi biraz
/// alışılmadık yapar ama alternatifi, bu dosyanın bir gün yalan söylemesidir.
Set<String> sceneSummonedIds() {
  final re = RegExp(r"""PetitionSystem\.byId\(\s*'([^']+)'""");
  final out = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    for (final m in re.allMatches(f.readAsStringSync())) {
      out.add(m.group(1)!);
    }
  }
  return out;
}

/// Bir dilekçenin bu bağlamlardan HERHANGİ birinde kapısı açılıyor mu.
Set<String> reachableIds(List<PetitionContext> contexts) {
  final out = <String>{};
  for (final g in PetitionSystem.gatesForTest) {
    if (g.weight <= 0) continue; // takip-yalnızca halka: zincirden çağrılır
    for (final c in contexts) {
      if (g.canFire(c)) {
        out.add(g.petition.id);
        break;
      }
    }
  }
  return out;
}

void main() {
  test('kuruluş odun krizi yalnız oyuncu hükmü ister', () {
    expect(petitionRequiresPlayerVerdict('woodLow', 0), isTrue);
    expect(petitionRequiresPlayerVerdict('woodLow', 1), isFalse);
    expect(petitionRequiresPlayerVerdict('fireDied', 0), isFalse);
  });

  final all = PetitionSystem.allForTest;
  final gates = PetitionSystem.gatesForTest;

  group('katalog bütünlüğü', () {
    test('id\'ler tekil — iki dilekçe aynı adı taşımaz', () {
      // byId ilk eşleşeni döner: çift id'nin ikincisi zincirden ASLA
      // çağrılamaz, sessizce ölür.
      final seen = <String>{};
      final dupes = <String>[];
      for (final p in all) {
        if (!seen.add(p.id)) dupes.add(p.id);
      }
      expect(dupes, isEmpty, reason: 'çift id: $dupes');
    });

    test('her dilekçenin en az iki şıkkı var — tek şık karar değildir', () {
      for (final p in all) {
        expect(
          p.options.length,
          greaterThanOrEqualTo(2),
          reason: '${p.id} tek şıklı: oyuncuya seçim sunmuyor',
        );
      }
    });

    test('hiçbir dilekçe sessiz değil — gövde ve şık metinleri dolu', () {
      for (final p in all) {
        expect(p.bodyPool, isNotEmpty, reason: '${p.id} gövdesiz');
        expect(p.title.trim(), isNotEmpty, reason: '${p.id} başlıksız');
        for (final o in p.options) {
          expect(
            o.label.trim(),
            isNotEmpty,
            reason: '${p.id}: etiketsiz şık — düğmede boşluk görünür',
          );
          expect(
            o.resolutionPool,
            isNotEmpty,
            reason: '${p.id}/${o.label}: çözüm metni yok',
          );
        }
      }
    });

    test('oyun metninde em-dash yok', () {
      // CLAUDE.md kuralı. Katalog en büyük metin yığını, kaçak buraya sızar.
      for (final p in all) {
        final texts = <String>[
          p.title,
          p.petitioner,
          ...p.bodyPool,
          if (p.note != null) p.note!,
          if (p.stakes != null) p.stakes!,
          for (final o in p.options) ...[
            o.label,
            o.detail,
            ...o.resolutionPool,
            ...o.annalPool,
          ],
        ];
        for (final t in texts) {
          expect(
            t.contains('—'),
            isFalse,
            reason: '${p.id}: em-dash geçiyor → "$t"',
          );
        }
      }
    });
  });

  group('zincirler kopmuyor', () {
    test('her takip bağı katalogda karşılık bulur — ölü bağ yok', () {
      final ids = {for (final p in all) p.id};
      for (final p in all) {
        for (final o in p.options) {
          final f = o.followUpId;
          if (f == null) continue;
          expect(
            ids.contains(f),
            isTrue,
            reason:
                '${p.id}/${o.label} → "$f" diye bir dilekçe yok: '
                'oyuncu kararı verir, vaat edilen devam hiç gelmez',
          );
        }
      }
    });

    test('takip halkalarının hepsi bir şıktan çağrılıyor — öksüz yok', () {
      final called = <String>{
        for (final p in all)
          for (final o in p.options)
            if (o.followUpId != null) o.followUpId!,
      };
      final rollable = reachableIds(sweep());
      final summoned = sceneSummonedIds();
      expect(
        summoned,
        isNotEmpty,
        reason:
            'kaynak taraması hiçbir byId çağrısı bulamadı — '
            'tarama bozulmuş, öksüz avı sessizce kapanmış olur',
      );
      for (final g in gates) {
        final id = g.petition.id;
        // Bir dilekçenin oyunda görünmesinin ÜÇ yolu var: rastgele havuz,
        // bir şıkkın zinciri, ya da sahnenin doğrudan çağrısı. Üçü de yoksa
        // o metin yazılmış ama oynanmaz.
        if (rollable.contains(id) || summoned.contains(id)) continue;
        expect(
          called.contains(id),
          isTrue,
          reason:
              '$id ne rastgele çıkıyor, ne bir şıktan çağrılıyor, ne de '
              'sahneden: yazılmış ama oyunda hiç görünmeyen metin',
        );
      }
    });

    test('takip gecikmesi pozitif — aynı karede iki dilekçe patlamaz', () {
      for (final p in all) {
        for (final o in p.options) {
          if (o.followUpId == null) continue;
          expect(
            o.followUpDelayDays,
            greaterThan(0),
            reason: '${p.id}/${o.label}: takip gecikmesi sıfır',
          );
        }
      }
    });
  });

  group('her dilekçenin bir köyü var', () {
    test('rastgele çıkabilen her dilekçe en az bir köyde tetiklenir', () {
      final contexts = sweep();
      final unreachable = <String>[];
      for (final g in gates) {
        if (g.weight <= 0) continue;
        if (!contexts.any(g.canFire)) unreachable.add(g.petition.id);
      }
      expect(
        unreachable,
        isEmpty,
        reason: 'kapısı hiçbir köyde açılmayan dilekçe: $unreachable',
      );
    });

    test(
      'taban köy susmaz — sıradan bir köyde her zaman soracak bir şey var',
      () {
        // Dilekçe sistemi köyün gündemidir; ortalama bir köyde havuz boşsa
        // yönetişim omurgası sessizleşir.
        final rng = Random(7);
        for (final c in sweep()) {
          expect(
            PetitionSystem.roll(c, rng),
            isNotNull,
            reason:
                'bu köyde hiçbir dilekçe uygun değil (nüfus ${c.population}, '
                'yıl ${c.years}, rejim ${c.regime})',
          );
        }
      },
    );
  });

  group('roll sözleşmesi', () {
    final ctx = sweep().first;

    test('bloklu id asla dönmez', () {
      // Cooldown'daki dilekçe tekrar çıkarsa köy kendini tekrar eder.
      final first = PetitionSystem.roll(ctx, Random(3))!;
      final blocked = {first.id};
      for (var i = 0; i < 400; i++) {
        final p = PetitionSystem.roll(ctx, Random(i), blocked: blocked);
        if (p == null) continue;
        expect(
          blocked.contains(p.id),
          isFalse,
          reason: '${p.id} bloklu olmasına rağmen çıktı',
        );
      }
    });

    test('hepsi bloklanınca null döner — uydurma dilekçe üretilmez', () {
      final everything = {for (final p in all) p.id};
      expect(PetitionSystem.roll(ctx, Random(1), blocked: everything), isNull);
    });

    test('küskün zümre gündemi ele geçirir', () {
      // Küskünlük "dişi": o zümrenin dilekçeleri belirgin biçimde daha sık
      // gelmeli, yoksa küsen zümre sessizce köşede kalır ve oyuncu hiç
      // uyarılmadan haneyi kaybeder.
      double shareOf(Estate e, {required bool aggrieved}) {
        final c = aggrieved
            ? PetitionContext(
                population: 20,
                adults: 12,
                food: 200,
                gold: 90,
                morale: 0.55,
                hasChurch: true,
                dayCount: 60,
                sealedLaws: 4,
                houseCount: 3,
                aggrievedEstate: e,
              )
            : const PetitionContext(
                population: 20,
                adults: 12,
                food: 200,
                gold: 90,
                morale: 0.55,
                hasChurch: true,
                dayCount: 60,
                sealedLaws: 4,
                houseCount: 3,
              );
        var hits = 0;
        const n = 3000;
        for (var i = 0; i < n; i++) {
          final p = PetitionSystem.roll(c, Random(i));
          if (p != null && p.estate == e) hits++;
        }
        return hits / n;
      }

      for (final e in Estate.values) {
        final calm = shareOf(e, aggrieved: false);
        if (calm == 0) {
          continue; // o zümrenin hiç dilekçesi yoksa ölçüm anlamsız
        }
        final angry = shareOf(e, aggrieved: true);
        expect(
          angry,
          greaterThan(calm),
          reason:
              '$e küskünken gündeme daha çok girmeli '
              '(sakin ${calm.toStringAsFixed(3)} → küskün ${angry.toStringAsFixed(3)})',
        );
      }
    });
  });

  group('şıklar birbirinden farklı', () {
    test('hiçbir dilekçede iki özdeş sonuçlu şık yok', () {
      // Aynı bedeli, aynı efekti, aynı bayrağı taşıyan iki şık oyuncuya
      // seçim sunmaz: iki düğme, tek karar.
      String fingerprint(PetitionOption o) => [
        o.foodDelta,
        o.woodDelta,
        o.stoneDelta,
        o.ironDelta,
        o.goldDelta,
        o.moraleAmount,
        o.moraleDays,
        o.fx,
        o.followUpId,
        o.setsFlags.join(','),
        o.clearsFlags.join(','),
        [for (final (e, d) in o.estateMood) '$e:$d'].join(','),
      ].join('|');

      for (final p in all) {
        final seen = <String, String>{};
        for (final o in p.options) {
          final fp = fingerprint(o);
          final twin = seen[fp];
          expect(
            twin,
            isNull,
            reason:
                '${p.id}: "$twin" ile "${o.label}" tıpatıp aynı sonucu '
                'veriyor — iki düğme, tek karar',
          );
          seen[fp] = o.label;
        }
      }
    });
  });
}
