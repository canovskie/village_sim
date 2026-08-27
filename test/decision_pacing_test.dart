import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/decision_pacing.dart';

void main() {
  group('DecisionPacing sessizlik sözleşmesi', () {
    test('normal ağır kararlar tanımlı kısa sessizliği ihlal etmez', () {
      final pacing = DecisionPacing();
      final first = pacing.request(HeavyDecisionKind.petition, atDay: 0);
      expect(first.activated, isTrue);
      expect(pacing.resolve(first.request.id, atDay: 0.10), isTrue);

      final second = pacing.request(HeavyDecisionKind.majorEvent, atDay: 0.11);
      expect(second.activated, isFalse);
      const opensAt = 0.10 + DecisionPacing.defaultQuietDays;
      expect(pacing.advanceTo(opensAt - 0.001), isNull);
      expect(pacing.advanceTo(opensAt)?.id, second.request.id);
      expect(pacing.metrics.lastGapDays, closeTo(opensAt, 1e-9));
    });

    test('acil normal sessizliği aşar; acilin ardından ikinci acil bekler', () {
      final pacing = DecisionPacing();
      final petition = pacing.request(HeavyDecisionKind.petition, atDay: 2);
      pacing.resolve(petition.request.id, atDay: 2.1);

      final imperial = pacing.request(
        HeavyDecisionKind.imperial,
        atDay: 2.2,
        urgency: DecisionUrgency.urgent,
      );
      expect(
        imperial.activated,
        isTrue,
        reason: 'eşikteki heyet normal sessizliği aşabilmeli',
      );
      expect(pacing.metrics.emergencyBypasses, 1);
      pacing.resolve(imperial.request.id, atDay: 2.25);

      final verdict = pacing.request(
        HeavyDecisionKind.crimeVerdict,
        atDay: 2.26,
        urgency: DecisionUrgency.urgent,
      );
      expect(
        verdict.activated,
        isFalse,
        reason: 'bir acilin ardından ikinci ağır karar üstüne açılmamalı',
      );
      const opensAt = 2.25 + DecisionPacing.defaultQuietDays;
      expect(pacing.advanceTo(opensAt - 0.001), isNull);
      expect(pacing.advanceTo(opensAt)?.id, verdict.request.id);
    });
  });

  test('altı oyun yılı boyunca kuyruk hiçbir kararı kaybetmez', () {
    final pacing = DecisionPacing();
    var submitted = 0;
    final activated = <String>{};
    final resolved = <String>{};
    String? seenActive;
    double? activeSince;

    // 96 gün = 6 oyun yılı. Her 0,19 günde bir ağır karar adayı üretmek,
    // çözüm + kısa nefes penceresinden daha sık olduğu için kuyruğu gerçekten
    // doldurur; test yalnız rahat aralıkta çalışan sahte bir güvence olmaz.
    for (var step = 0; step <= 9600; step++) {
      final day = step / 100;
      if (day <= 96 && step % 19 == 0) {
        final kind = HeavyDecisionKind.values[submitted % 2];
        pacing.request(kind, atDay: day);
        submitted++;
      } else {
        pacing.advanceTo(day);
      }

      final active = pacing.active;
      if (active != null && active.id != seenActive) {
        activated.add(active.id);
        seenActive = active.id;
        activeSince = day;
      }
      if (active != null && day - activeSince! >= 0.08) {
        expect(pacing.resolve(active.id, atDay: day), isTrue);
        resolved.add(active.id);
        seenActive = null;
        activeSince = null;
      }
    }

    var day = 96.01;
    while (pacing.active != null || pacing.queueLength > 0) {
      pacing.advanceTo(day);
      final active = pacing.active;
      if (active != null) {
        activated.add(active.id);
        pacing.resolve(active.id, atDay: day + 0.08);
        resolved.add(active.id);
        day += 0.73;
      } else {
        day += 0.01;
      }
    }

    expect(activated.length, submitted);
    expect(resolved.length, submitted);
    expect(pacing.metrics.resolvedDecisions, submitted);
    expect(pacing.queueLength, 0);
    expect(pacing.metrics.deferredDecisions, greaterThan(0));
    expect(pacing.metrics.maxQueueWaitDays, greaterThan(0));
    expect(
      pacing.metrics.minGapDays,
      greaterThanOrEqualTo(DecisionPacing.defaultQuietDays),
    );
  });

  test('aktif karar, kuyruk ve ölçümler kayıt gidiş-dönüşünde korunur', () {
    final pacing = DecisionPacing();
    final first = pacing.request(HeavyDecisionKind.petition, atDay: 4);
    pacing.request(HeavyDecisionKind.majorEvent, atDay: 4.1);
    pacing.request(
      HeavyDecisionKind.imperial,
      atDay: 4.2,
      urgency: DecisionUrgency.urgent,
    );

    final restored = DecisionPacing.fromJson(pacing.toJson());
    expect(restored.active?.id, first.request.id);
    expect(restored.queueLength, 2);
    expect(restored.queued.first.kind, HeavyDecisionKind.majorEvent);
    expect(restored.queued.last.kind, HeavyDecisionKind.imperial);
    expect(restored.metrics.deferredDecisions, 2);
  });
}
