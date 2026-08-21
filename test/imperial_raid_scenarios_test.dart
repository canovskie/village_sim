import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/imperial_raid.dart';
import 'package:village_sim/world/season.dart';

ImperialRaidContext context({
  int year = 4,
  int population = 28,
  bool night = true,
  bool rain = true,
  Season season = Season.winter,
  bool buildings = true,
}) => ImperialRaidContext(
  year: year,
  population: population,
  favor: .2,
  isNight: night,
  raining: rain,
  season: season,
  hasWarehouse: buildings,
  hasMarket: buildings,
  hasTownHall: buildings,
  hasChurch: buildings,
  hasManor: buildings,
  hasStable: buildings,
  hasLumberCamp: buildings,
);

void main() {
  test('catalog contains two dozen genuinely distinct raid identities', () {
    expect(imperialRaidScenarios, hasLength(24));
    expect(imperialRaidScenarios.map((s) => s.kind).toSet(), hasLength(24));
    expect(imperialRaidScenarios.map((s) => s.title).toSet(), hasLength(24));
    expect(
      imperialRaidScenarios.map((s) => s.target).toSet().length,
      greaterThanOrEqualTo(9),
    );
  });

  test('world conditions open and close scenario branches', () {
    final early = eligibleImperialRaids(
      context(
        year: 1,
        population: 9,
        night: false,
        rain: false,
        buildings: false,
      ),
    );
    final warTown = eligibleImperialRaids(context());

    expect(early, isNotEmpty);
    expect(early.every((s) => s.minYear == 1), isTrue);
    expect(warTown.length, greaterThan(early.length));
    expect(
      warTown.any((s) => s.kind == ImperialRaidKind.occupationDay),
      isTrue,
    );
    expect(early.any((s) => s.kind == ImperialRaidKind.occupationDay), isFalse);
  });

  test('seasonal and night raids only appear in their proper worlds', () {
    final daySummer = eligibleImperialRaids(
      context(night: false, rain: false, season: Season.summer),
    );
    final nightWinter = eligibleImperialRaids(context());
    final autumn = eligibleImperialRaids(
      context(night: false, rain: false, season: Season.autumn),
    );

    expect(
      daySummer.any((s) => s.kind == ImperialRaidKind.nightKnives),
      isFalse,
    );
    expect(
      nightWinter.any((s) => s.kind == ImperialRaidKind.nightKnives),
      isTrue,
    );
    expect(
      autumn.any((s) => s.kind == ImperialRaidKind.harvestSeizure),
      isTrue,
    );
    expect(
      daySummer.any((s) => s.kind == ImperialRaidKind.scorchedHarvest),
      isTrue,
    );
    expect(
      daySummer.any((s) => s.kind == ImperialRaidKind.dawnEncirclement),
      isFalse,
    );
  });

  test('relations alter whether punishment or relief arrives', () {
    final hostile = eligibleImperialRaids(context());
    final friendly = eligibleImperialRaids(
      const ImperialRaidContext(
        year: 4,
        population: 28,
        favor: .8,
        isNight: true,
        raining: true,
        season: Season.winter,
        hasWarehouse: true,
        hasMarket: true,
        hasTownHall: true,
        hasChurch: true,
        hasManor: true,
        hasStable: true,
        hasLumberCamp: true,
      ),
    );
    expect(
      hostile.any((s) => s.kind == ImperialRaidKind.punitiveMarch),
      isTrue,
    );
    expect(
      friendly.any((s) => s.kind == ImperialRaidKind.punitiveMarch),
      isFalse,
    );
    expect(
      friendly.any((s) => s.kind == ImperialRaidKind.reliefColumn),
      isTrue,
    );
  });

  test('same world and seed select the same raid', () {
    final c = context();
    final a = selectImperialRaidScenario(c, 731);
    final b = selectImperialRaidScenario(c, 731);
    expect(a.kind, b.kind);
  });

  test('scenarios change force, losses, loot and tactical answer', () {
    expect(
      imperialRaidScenarios.map((s) => s.attackDelta).toSet().length,
      greaterThan(6),
    );
    expect(
      imperialRaidScenarios.map((s) => s.casualtyDelta).toSet().length,
      greaterThanOrEqualTo(4),
    );
    expect(
      imperialRaidScenarios.map((s) => s.lootMultiplier).toSet().length,
      greaterThan(6),
    );
    expect(
      imperialRaidScenarios
          .map((s) => (s.holdBonus, s.barricadeBonus, s.chargeBonus))
          .toSet()
          .length,
      greaterThan(12),
    );
  });
}
