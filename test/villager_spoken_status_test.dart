import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/entities/villager_job.dart';
import 'package:village_sim/systems/villager_act.dart';
import 'package:village_sim/systems/villager_mind.dart';
import 'package:village_sim/systems/villager_spoken_status.dart';

void main() {
  VillagerEntity villager({JobRole role = JobRole.none}) {
    final v = VillagerEntity(
      type: VillagerType.farmer,
      name: 'Davut',
      male: true,
      startCol: 0,
      startRow: 0,
      ageDays: kAdultStartDay + 2,
      visualSeed: 4,
      personalitySeed: 4,
    );
    if (role != JobRole.none) v.job = VillagerJob(role);
    return v;
  }

  test('görünen sosyal sahne meslekten önce söylenir', () {
    final v = villager(role: JobRole.woodcutter)
      ..activity = VillagerActivity.chat;
    v.job!.working = true;

    expect(villagerSpokenStatus(v), 'Bir köylüyle sohbet ediyorum.');
  });

  test('kavga seyircisi gündelik işine dönmüş gibi konuşmaz', () {
    final v = villager(role: JobRole.woodcutter)
      ..activity = VillagerActivity.watchingConflict;
    v.job!.working = true;

    expect(villagerSpokenStatus(v), 'Kavgaya bakmaya koştum.');
  });

  test('mikro eylem birinci ağızdan söylenir', () {
    final v = villager()..act = Act('kuyudan su taşıyor', const <ActStep>[]);

    expect(villagerSpokenStatus(v), 'Kuyudan su taşıyorum.');
  });

  test('aktif iş gerçek rolünü söyler', () {
    final v = villager(role: JobRole.miner);
    v.job!.working = true;

    expect(villagerSpokenStatus(v), 'Cevher çıkarıyorum.');
  });

  test('işe giden köylü çalışıyormuş gibi konuşmaz', () {
    final v = villager(role: JobRole.builder)..goTo(8, 2, 0);
    v.mind.impose(
      IntentKind.work,
      'işinin başına dönüyor',
      priority: IntentPriority.work,
    );

    expect(villagerSpokenStatus(v), 'İşimin başına gidiyorum.');
  });

  test('ürün almaya giden köylü taşıma evresini söyler', () {
    final v = villager(role: JobRole.farmer)
      ..assignCarryTask(Object(), 2, 2, 6, 6);

    expect(villagerSpokenStatus(v), 'Taşıyacağım ürünü almaya gidiyorum.');
  });
}
