import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/entities/villager_job.dart';
import 'package:village_sim/systems/job_feedback.dart';

void main() {
  VillagerEntity villager(JobRole role) {
    return VillagerEntity(
      type: VillagerType.farmer,
      name: 'Davut',
      male: true,
      startCol: 0,
      startRow: 0,
      ageDays: kAdultStartDay + 2,
      visualSeed: 4,
      personalitySeed: 4,
    )..job = VillagerJob(role);
  }

  test('işe gidiş motor hedefinden ETA üretir', () {
    final v = villager(JobRole.woodcutter)..goTo(10, 0, 0.2);
    final f = feedbackFor(v);

    expect(f.state, 'İşyerine gidiyor');
    expect(f.etaSeconds, isNotNull);
    expect(f.etaSeconds!, lessThan(10));
    expect(f.result, contains('kütük'));
  });

  test('çalışma ilerlemesi gerçek cycle sayacını okur', () {
    final v = villager(JobRole.miner);
    v.job!
      ..working = true
      ..reportCycle(2, 8);

    final f = feedbackFor(v);
    expect(f.state, 'Cevher çıkarıyor');
    expect(f.progress, 0.25);
    expect(f.etaSeconds, 6);
  });

  test('tamamlanan iş vardiya hafızasında görünür', () {
    final v = villager(JobRole.fisher);
    v.job!.finishCycle();

    expect(feedbackFor(v).state, '1 iş tamamladı');
  });
}
