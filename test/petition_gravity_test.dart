import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/governance/petition_system.dart';

PetitionContext _context({
  required int population,
  int unwedAdultMen = 0,
  int herdSize = 0,
  Set<String> memory = const {},
}) => PetitionContext(
  population: population,
  adults: population,
  food: 20,
  gold: 5,
  morale: 0.5,
  hasChurch: false,
  unwedAdultMen: unwedAdultMen,
  herdSize: herdSize,
  memory: memory,
);

void main() {
  group('köy büyüklüğü → gündem ağırlığı', () {
    test('nüfus eşikleri dört okunur kademe üretir', () {
      expect(_context(population: 2).agendaGravity, PetitionGravity.personal);
      expect(_context(population: 7).agendaGravity, PetitionGravity.personal);
      expect(_context(population: 8).agendaGravity, PetitionGravity.communal);
      expect(_context(population: 13).agendaGravity, PetitionGravity.communal);
      expect(_context(population: 14).agendaGravity, PetitionGravity.civic);
      expect(_context(population: 21).agendaGravity, PetitionGravity.civic);
      expect(_context(population: 22).agendaGravity, PetitionGravity.critical);
    });

    test('geleceğin ağır içeriği erken köye hiç sızmaz', () {
      expect(
        petitionGravityWeight(
          PetitionGravity.communal,
          PetitionGravity.personal,
        ),
        0,
      );
      expect(
        petitionGravityWeight(PetitionGravity.critical, PetitionGravity.civic),
        0,
      );
    });

    test('büyüyen köy küçük meseleleri unutmadan geriye iter', () {
      expect(
        petitionGravityWeight(
          PetitionGravity.personal,
          PetitionGravity.personal,
        ),
        1,
      );
      expect(
        petitionGravityWeight(
          PetitionGravity.personal,
          PetitionGravity.communal,
        ),
        0.45,
      );
      expect(
        petitionGravityWeight(PetitionGravity.personal, PetitionGravity.civic),
        0.18,
      );
      expect(
        petitionGravityWeight(
          PetitionGravity.personal,
          PetitionGravity.critical,
        ),
        0.08,
      );
    });
  });

  group('başlangıç ikilemleri', () {
    test('Kendi Yolum yalnız uygun gerçek kişi varken açılır', () {
      final gate = PetitionSystem.gatesForTest.singleWhere(
        (g) => g.petition.id == PetitionIds.personalStyle,
      );
      expect(gate.canFire(_context(population: 5)), isFalse);
      expect(gate.canFire(_context(population: 5, unwedAdultMen: 1)), isTrue);
      expect(
        gate.canFire(
          _context(
            population: 5,
            unwedAdultMen: 1,
            memory: {'personalStyle.free'},
          ),
        ),
        isFalse,
      );
    });

    test('Kendi Yolum iki kalıcı ve farklı görünür sonuç bildirir', () {
      final petition = PetitionSystem.requireById(PetitionIds.personalStyle);
      expect(petition.authorKind, PetitionAuthorKind.unwedAdultMan);
      expect(petition.options, hasLength(2));
      expect(petition.options.map((o) => o.actorEffect).toSet(), {
        PetitionActorEffect.flowingOutfit,
        PetitionActorEffect.traditionalOutfit,
      });
      expect(petition.options.expand((o) => o.setsFlags).toSet(), {
        'personalStyle.free',
        'personalStyle.traditional',
      });
    });

    test('uygun kişi yoksa diğer küçük meseleler yine akar', () {
      final result = PetitionSystem.roll(_context(population: 5), Random(7));
      expect(result, isNotNull);
      expect(result!.id, isNot(PetitionIds.personalStyle));
    });
  });
}
