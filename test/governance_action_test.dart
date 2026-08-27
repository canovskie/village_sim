import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/event_system.dart';
import 'package:village_sim/systems/governance_action.dart';
import 'package:village_sim/systems/law_book.dart';
import 'package:village_sim/systems/petition_system.dart';

void main() {
  group('yönetişimin dünyadaki izi', () {
    test('her kanunun adlandırılmış ve tekrarlanabilir bir NPC imzası var', () {
      expect(lawSignatures.keys.toSet(), {for (final law in kLawBook) law.id});
      for (final law in kLawBook) {
        final signature = lawSignatures[law.id]!;
        expect(signature.lawId, law.id);
        expect(signature.source, isNotEmpty);
      }
    });

    test('dokuz olayın iki seçimi farklı kalıcı davranış bırakıyor', () {
      expect(EventSystem.events, hasLength(9));
      for (final event in EventSystem.events) {
        final choices = event.choices!;
        expect(choices, hasLength(2), reason: event.id);
        final a = aftermathForChoice(event.id, choices[0].id);
        final b = aftermathForChoice(event.id, choices[1].id);
        expect(a, isNotNull, reason: '${event.id}:${choices[0].id}');
        expect(b, isNotNull, reason: '${event.id}:${choices[1].id}');
        expect(a!.kind, isNot(b!.kind), reason: event.id);
        expect(a.source, isNot(b.source), reason: event.id);
        expect(a.durationDays, greaterThan(0));
        expect(b.durationDays, greaterThan(0));
      }
    });

    test('odun kararları varlık şartını ve gecikmeli yolu açıkça ayırıyor', () {
      for (final id in const ['woodLow', 'fireDied']) {
        final petition = PetitionSystem.byId(id)!;
        final caravan = petition.options.singleWhere(
          (o) => o.presence == DecisionPresence.activeCaravan,
        );
        final journey = petition.options.singleWhere((o) => o.process != null);
        expect(caravan.woodDelta, greaterThan(0));
        expect(journey.woodDelta, 0);
        expect(journey.process!.woodOnComplete, greaterThan(0));
        expect(journey.process!.durationDays, greaterThan(0));
      }
    });

    test('süren karar ve olay izi JSON gidiş dönüşünde korunuyor', () {
      const process = DecisionProcess(
        id: 'woodLow.market.1',
        kind: DecisionProcessKind.marketWoodRun,
        title: 'Pazar yolu',
        actorName: 'Aslı',
        startedSim: 12,
        dueSim: 140,
        completionText: 'Döndü',
        completionAnnal: 'Ulak döndü.',
        woodOnComplete: 10,
      );
      final processCopy = DecisionProcess.fromJson(process.toJson());
      expect(processCopy, isNotNull);
      expect(processCopy!.kind, process.kind);
      expect(processCopy.actorName, 'Aslı');
      expect(processCopy.woodOnComplete, 10);
      expect(processCopy.dueSim, 140);

      final aftermath = GovernanceAftermath(
        id: EventIds.storm,
        kind: GovernanceBeatKind.repairDuty,
        source: 'Çatıları berkitme',
        untilSim: 500,
        nextBeatSim: 80,
      );
      final aftermathCopy = GovernanceAftermath.fromJson(aftermath.toJson());
      expect(aftermathCopy, isNotNull);
      expect(aftermathCopy!.kind, GovernanceBeatKind.repairDuty);
      expect(aftermathCopy.source, 'Çatıları berkitme');
      expect(aftermathCopy.untilSim, 500);
    });
  });
}
