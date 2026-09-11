import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/systems/events/event_system.dart';
import 'package:village_sim/systems/events/governance_event.dart';
import 'package:village_sim/systems/governance/decision_customs.dart';
import 'package:village_sim/systems/governance/petition_system.dart';
import 'package:village_sim/text/voice.dart';

void main() {
  test('karar tüm maliyetlerini aynı anda karşılamalı', () {
    const option = PetitionOption(
      label: 'Onar',
      detail: 'Kaynak ayır',
      resolutionPool: ['Onarıldı.'],
      foodDelta: -2,
      woodDelta: -3,
      stoneDelta: -4,
      ironDelta: -5,
      goldDelta: -6,
    );
    final stock = ResourceBundle(food: 2, wood: 3, stone: 4, iron: 5, gold: 6);
    expect(option.canAfford(stock), isTrue);
    for (final resource in [
      ResourceKind.food,
      ResourceKind.wood,
      ResourceKind.stone,
      ResourceKind.iron,
      ResourceKind.gold,
    ]) {
      stock.add(resource, -1);
      expect(option.canAfford(stock), isFalse, reason: resource.name);
      stock.add(resource, 1);
    }
    expect(option.canAfford(ResourceBundle()), isFalse);
  });

  test('katalogdaki her dilekçenin kaynak yokken seçilebilir bir kolu var', () {
    for (final petition in PetitionSystem.all) {
      expect(
        petition.options.any(
          (o) =>
              o.canAfford(ResourceBundle()) &&
              o.requiredLaw == null &&
              o.presence.name == 'none',
        ),
        isTrue,
        reason: petition.id,
      );
    }
  });

  test('yargı ilk sunum ve yüklemede yürürlükteki kanunlardan kurulur', () {
    final unsealed = crimeVerdictFor({}).options.map((o) => o.fx);
    expect(unsealed, isNot(contains(PetitionFx.crimeExile)));
    expect(unsealed, isNot(contains(PetitionFx.crimeLabor)));
    expect(unsealed, isNot(contains(PetitionFx.crimePenance)));
    final sealed = crimeVerdictFor({
      'nizam.exile',
      'nizam.labor',
      'dergah.penance',
    });
    final spoken = sealed.spoken(const VoiceCtx(name: 'Ali', seed: 3));
    expect(
      spoken.options.map((o) => o.fx),
      containsAll([
        PetitionFx.crimeExile,
        PetitionFx.crimeLabor,
        PetitionFx.crimePenance,
      ]),
    );
    expect(
      spoken.options
          .singleWhere((o) => o.fx == PetitionFx.crimeLabor)
          .requiredLaw,
      'nizam.labor',
    );
  });

  test(
    'rejim krizleri katalogdan geri kurulur ve dokuma eylemi değiştirmez',
    () {
      for (final kind in ['revolt', 'deadlock', 'idleness', 'inequality']) {
        final p = PetitionSystem.requireById('regime.crisis.$kind');
        final spoken = p.spoken(const VoiceCtx(seed: 17));
        expect(
          spoken.options.map((o) => o.unrestDelta),
          p.options.map((o) => o.unrestDelta),
        );
        expect(
          spoken.options.map((o) => o.action),
          p.options.map((o) => o.action),
        );
        expect(p.options.any((o) => o.unrestDelta < 0), isTrue);
        expect(isVillageIssue(p.id), isTrue);
      }
      final p = PetitionSystem.requireById('regime.crisis.revolt');
      expect(p.options[1].action, PetitionAction.exileAgitator);
      expect(p.options[1].requiredLaw, 'nizam.exile');
    },
  );

  test('köy meselesi olay ekranına maliyeti korunarak çevrilir', () {
    final p = PetitionSystem.requireById(PetitionIds.crimeWave);
    final event = governanceEvent(p);
    expect(isVillageIssue(p.id), isTrue);
    expect(isVillageIssue(PetitionIds.personalStyle), isFalse);
    expect(isVillageIssue(PetitionIds.crimeVerdict), isFalse);
    expect(event.choices!.first.canAfford(ResourceBundle()), isFalse);
    expect(event.choices!.last.canAfford(ResourceBundle()), isTrue);
  });

  test('gündelik kararlar karşılıklı dışlayan kalıcı usuller yazar', () {
    for (final id in [
      PetitionIds.ovenTurn,
      PetitionIds.hearthSeat,
      PetitionIds.wellBucket,
      PetitionIds.animalBell,
      PetitionIds.quietEvening,
    ]) {
      final p = PetitionSystem.requireById(id);
      expect(p.options[0].setsFlags, isNotEmpty);
      expect(p.options[0].clearsFlags, containsAll(p.options[1].setsFlags));
      expect(p.options[1].clearsFlags, containsAll(p.options[0].setsFlags));
    }
  });

  test('dönüşümlü pişirme sırası kayıt yüklemeyle başa sarmaz', () {
    final c = DecisionCustoms();
    final memory = {'oven.rotation'};
    expect(c.cookingHouse(memory, 0, ['B', 'A']), 'A');
    c.cookedHouses.add('A');
    final loaded = DecisionCustoms.fromJson(c.toJson());
    expect(loaded.cookingHouse(memory, 0, ['B', 'A']), 'B');
    expect(loaded.cookingHouse(memory, 1, ['A', 'B']), 'B');
    expect(DecisionCustoms().cookingHouse({'oven.early'}, 0, ['B', 'A']), 'B');
  });

  test('sessizlik ve çan usulleri gündüzü ve geceyi ayırır', () {
    expect(DecisionCustoms.musicAllowed({'music.quiet'}, .8), isFalse);
    expect(DecisionCustoms.musicAllowed({'music.quiet'}, .5), isTrue);
    expect(DecisionCustoms.musicAllowed({'music.hour'}, .76), isTrue);
    expect(DecisionCustoms.musicAllowed({'music.hour'}, .9), isFalse);
    expect(DecisionCustoms.bellWorn({'bell.day'}, .9), isFalse);
    expect(DecisionCustoms.bellWorn({'bell.day'}, .5), isTrue);
    expect(DecisionCustoms.bellWorn({'bell.always'}, .9), isTrue);
  });

  test('sıcak yerin önceliği kararın tarafına uyar', () {
    double rank(Set<String> flags, bool elder, double chill) =>
        DecisionCustoms.hearthPriority(flags, elder: elder, chill: chill);
    expect(
      rank({'hearth.elders'}, true, .4),
      greaterThan(rank({'hearth.elders'}, false, .9)),
    );
    expect(
      rank({'hearth.cold'}, true, .4),
      lessThan(rank({'hearth.cold'}, false, .9)),
    );
  });

  test('asayişi yok saymak nöbet etkisi veya şüphe temizliği vermez', () {
    final options = PetitionSystem.requireById(PetitionIds.crimeWave).options;
    expect(options[0].setsFlags, contains('crime.watch'));
    expect(options[1].setsFlags, contains('crime.patrol'));
    expect(options.last.fx, PetitionFx.none);
    expect(options.last.setsFlags, isEmpty);
  });

  test('rastgele olayların pasif kolu ve dünyada devam eden işi vardır', () {
    expect(EventSystem.events, isNotEmpty);
    expect(
      EventSystem.events.map((e) => e.id).toSet().length,
      EventSystem.events.length,
    );
    for (final e in EventSystem.events) {
      expect(e.messagePool, isNotEmpty);
      expect(e.timeoutChoice!.requiresResources, isFalse);
      for (final c in e.choices!) {
        expect(c.aftermath, isNotNull);
        expect(c.annal, isNotEmpty);
      }
    }
  });
}
