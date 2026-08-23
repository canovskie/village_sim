import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/core/resources.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/entities/villager_job.dart';
import 'package:village_sim/systems/anchor_system.dart';
import 'package:village_sim/systems/carrier_system.dart';
import 'package:village_sim/systems/villager_act.dart';
import 'package:village_sim/systems/villager_mind.dart';
import 'package:village_sim/world/hay_entity.dart';
import 'package:village_sim/world/resource_box.dart';

void main() {
  VillagerEntity villager({double x = 0, double y = 0}) => VillagerEntity(
    type: VillagerType.merchant,
    name: 'Taşıyıcı',
    male: true,
    startCol: x,
    startRow: y,
    ageDays: kAdultStartDay + 2,
    visualSeed: 17,
    personalitySeed: 17,
  );

  void tick(VillagerEntity v, Random rng, [int frames = 1]) {
    for (var i = 0; i < frames; i++) {
      v.update(0.1, 40, 40, rng, dayLight: 1);
      v.smoothMotion(0.1);
    }
  }

  test('teslim callbackinden önce porter state atomik temizlenir', () {
    final v = villager();
    final rng = Random(1);
    final load = Object();
    var delivered = 0;

    expect(
      v.assignCarryTask(
        load,
        0,
        0,
        1.2,
        0,
        onDelivered: () {
          delivered++;
          expect(v.state, VillagerState.idle);
          expect(v.carriedItem, isNull);
          expect(v.deliveryEtaSeconds, isNull);
        },
      ),
      isTrue,
    );

    tick(v, rng); // pickup aynı noktada
    expect(v.state, VillagerState.carrying);
    expect(v.carriedItem, same(load));
    expect(v.holdsItemTwoHanded, isTrue);
    expect(v.torchEligibleDefault, isFalse);

    for (var i = 0; i < 80 && delivered == 0; i++) {
      tick(v, rng);
    }
    expect(delivered, 1);
    expect(v.state, VillagerState.idle);
    expect(v.isCarrying, isFalse);
  });

  test('iptal pickup evresini bildirir ve callback yalnız bir kez çalışır', () {
    final v = villager();
    final rng = Random(2);
    final phases = <bool>[];

    v.assignCarryTask(Object(), 0, 0, 8, 0, onCancelled: phases.add);
    tick(v, rng);
    expect(v.state, VillagerState.carrying);

    v.cancelCarryTask();
    v.cancelCarryTask();

    expect(phases, [true]);
    expect(v.state, VillagerState.idle);
    expect(v.carriedItem, isNull);
    expect(v.isWalking, isFalse);
  });

  test('pickup öncesi iptal false bildirir ve kaynak yerinde kalır', () {
    final v = villager();
    final phases = <bool>[];

    expect(
      v.assignCarryTask(Object(), 6, 5, 8, 8, onCancelled: phases.add),
      isTrue,
    );
    v.cancelCarryTask();
    v.cancelCarryTask();

    expect(phases, [false]);
    expect(v.hasCarryTask, isFalse);
    expect(v.state, VillagerState.idle);
  });

  test('çakışan atama reddedilir ve kabul edilmiş görev kesilmez', () {
    final v = villager();
    final firstPhases = <bool>[];
    final rejectedPhases = <bool>[];
    final firstLoad = Object();

    expect(
      v.assignCarryTask(firstLoad, 5, 5, 8, 8, onCancelled: firstPhases.add),
      isTrue,
    );
    expect(
      v.assignCarryTask(Object(), 1, 1, 2, 2, onCancelled: rejectedPhases.add),
      isFalse,
    );
    expect(rejectedPhases, isEmpty, reason: 'reddedilen görev başlamadı');
    expect(firstPhases, isEmpty, reason: 'eski görev zorla kesilmemeli');
    expect(v.hasCarryTask, isTrue);

    v.cancelCarryTask();
    expect(firstPhases, [false]);
  });

  test('ani ölüm yükü ayağa düşürür ve anchor rezervasyonunu salar', () {
    final v = villager(x: 1, y: 1);
    final box = ResourceBox(
      type: ResourceBoxType.woodChunk,
      gridX: 1,
      gridY: 1,
    );
    final boxes = <ResourceBox>[box];
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 8,
      row: 8,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);
    var sceneTime = 12.5;

    assignCarriers(
      villagers: [v],
      buildings: [warehouse],
      resourceBoxes: boxes,
      hayEntities: const [],
      stockpile: ResourceBundle(),
      anchorSystem: anchors,
      time: sceneTime,
      timeNow: () => sceneTime,
    );
    expect(box.isBeingCarried, isTrue);
    expect(
      anchors.warehousePoints.single.slots.where((s) => s.isFree).length,
      4,
    );

    final rng = Random(3);
    tick(v, rng); // yükü al
    tick(v, rng, 8); // pickup noktasından uzaklaş
    final dropX = v.gridX;
    final dropY = v.gridY;
    sceneTime = 27.25;
    v.startDying();

    expect(box.isBeingCarried, isFalse);
    expect(box.isDelivered, isFalse);
    expect(boxes, contains(same(box)));
    expect(box.gridX, closeTo(dropX.floor() + 0.5, 1e-9));
    expect(box.gridY, closeTo(dropY.floor() + 0.5, 1e-9));
    expect(
      box.spawnTime,
      27.25,
      reason: 'drop atama değil iptal anında doğmalı',
    );
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
    expect(v.carriedItem, isNull);
  });

  test('balya kesintisi de güncel saatte ayağa düşer ve slotu salar', () {
    final v = villager(x: 2, y: 2);
    final bale = HayEntity(type: HayType.bale, gridX: 2, gridY: 2);
    final hay = <HayEntity>[bale];
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 9,
      row: 9,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);
    var sceneTime = 3.0;

    assignCarriers(
      villagers: [v],
      buildings: [warehouse],
      resourceBoxes: const [],
      hayEntities: hay,
      stockpile: ResourceBundle(),
      anchorSystem: anchors,
      time: sceneTime,
      timeNow: () => sceneTime,
    );
    final rng = Random(33);
    tick(v, rng); // balyayı al
    tick(v, rng, 7);
    final dropX = v.gridX;
    final dropY = v.gridY;
    sceneTime = 18.75;

    v.startLeaving(39, 39);

    expect(bale.isBeingCarried, isFalse);
    expect(bale.isDelivered, isFalse);
    expect(hay, contains(same(bale)));
    expect(bale.gridX, closeTo(dropX.floor() + 0.5, 1e-9));
    expect(bale.gridY, closeTo(dropY.floor() + 0.5, 1e-9));
    expect(bale.spawnTime, 18.75);
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
    expect(v.hasCarryTask, isFalse);
  });

  test('pickup öncesi sistem iptali kaynağı başlangıç noktasında bırakır', () {
    final v = villager();
    final box = ResourceBox(
      type: ResourceBoxType.stoneBox,
      gridX: 4.25,
      gridY: 3.75,
    );
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 8,
      row: 8,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);

    assignCarriers(
      villagers: [v],
      buildings: [warehouse],
      resourceBoxes: [box],
      hayEntities: const [],
      stockpile: ResourceBundle(),
      anchorSystem: anchors,
      time: 22,
    );
    v.cancelCarryTask();

    expect(box.isBeingCarried, isFalse);
    expect(box.gridX, 4.25);
    expect(box.gridY, 3.75);
    expect(box.spawnTime, 0, reason: 'yerdeki kaynak yeniden düşürülmemeli');
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
  });

  test('dış goTo eldeki yükü düşürür ve anchor rezervasyonunu salar', () {
    final v = villager(x: 1, y: 1);
    final box = ResourceBox(
      type: ResourceBoxType.woodChunk,
      gridX: 1,
      gridY: 1,
    );
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 8,
      row: 8,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);

    assignCarriers(
      villagers: [v],
      buildings: [warehouse],
      resourceBoxes: [box],
      hayEntities: const [],
      stockpile: ResourceBundle(),
      anchorSystem: anchors,
      time: 13.5,
    );
    final rng = Random(31);
    tick(v, rng); // yükü al
    tick(v, rng, 8); // pickup noktasından uzaklaş
    final dropX = v.gridX;
    final dropY = v.gridY;

    // Hastalık, devriye, kavga ve benzeri zorlayıcı sahne yolları köylüyü
    // `goTo` ile başka yere yönlendirir. Bu yönlendirme porter zincirini
    // callback üzerinden kapatmalı; state'i yalnız ezmek kaynak/slot sızdırır.
    v.goTo(3, 3, 1);

    expect(box.isBeingCarried, isFalse);
    expect(box.isDelivered, isFalse);
    expect(box.gridX, closeTo(dropX.floor() + 0.5, 1e-9));
    expect(box.gridY, closeTo(dropY.floor() + 0.5, 1e-9));
    expect(box.spawnTime, 13.5);
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
    expect(v.carriedItem, isNull);
    expect(v.state, VillagerState.moving);
  });

  test('gerçek taşıyıcı teslimi kaynağı bir kez stoğa aktarır', () {
    final v = villager(x: 1, y: 1);
    final box = ResourceBox(
      type: ResourceBoxType.woodChunk,
      gridX: 1,
      gridY: 1,
    );
    final boxes = <ResourceBox>[box];
    final stockpile = ResourceBundle();
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 8,
      row: 8,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);

    assignCarriers(
      villagers: [v],
      buildings: [warehouse],
      resourceBoxes: boxes,
      hayEntities: const [],
      stockpile: stockpile,
      anchorSystem: anchors,
    );
    final rng = Random(32);
    for (var i = 0; i < 600 && boxes.isNotEmpty; i++) {
      tick(v, rng);
    }

    expect(boxes, isEmpty);
    expect(box.isBeingCarried, isFalse);
    expect(box.isDelivered, isTrue);
    expect(stockpile.wood, 1);
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
    expect(v.state, VillagerState.idle);
    expect(v.carriedItem, isNull);

    tick(v, rng, 20);
    expect(
      stockpile.wood,
      1,
      reason: 'teslim callbacki ikinci kez çalışmamalı',
    );
  });

  test('genel tarama yarım eylemi ve aktif iş darbesini taşıyıcı yapmaz', () {
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 5,
      row: 5,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);
    final box = ResourceBox(type: ResourceBoxType.stoneBox, gridX: 0, gridY: 0);

    final acting = villager()
      ..act = Act('kuyuda çalışıyor', const [
        ActStep.work(2, pose: ActPose.stoop),
      ]);
    final working = villager(x: 0.2)
      ..job = (VillagerJob(JobRole.miner)..working = true);

    assignCarriers(
      villagers: [acting, working],
      buildings: [warehouse],
      resourceBoxes: [box],
      hayEntities: const [],
      stockpile: ResourceBundle(),
      anchorSystem: anchors,
    );

    expect(acting.state, VillagerState.idle);
    expect(acting.act, isNotNull);
    expect(working.state, VillagerState.idle);
    expect(box.isBeingCarried, isFalse);
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
  });

  test('uygunluk yarım iş fazı, su turu, jest ve committed niyeti korur', () {
    final phased = villager()..job = (VillagerJob(JobRole.shepherd)..phase = 1);
    final claimed = villager()
      ..job = (VillagerJob(JobRole.miner)..claim = Object());
    final watering = villager()
      ..job = (VillagerJob(JobRole.farmer)..carryingWater = true);
    final waving = villager()..waveTime = 0.4;
    final committed = villager()
      ..mind.impose(
        IntentKind.crime,
        'başlamış sahne',
        priority: IntentPriority.committed,
      );
    final betweenCycles = villager()..job = VillagerJob(JobRole.woodcutter);

    expect(phased.canAcceptCarryTask, isFalse);
    expect(claimed.canAcceptCarryTask, isFalse);
    expect(watering.canAcceptCarryTask, isFalse);
    expect(waving.canAcceptCarryTask, isFalse);
    expect(committed.canAcceptCarryTask, isFalse);
    expect(betweenCycles.canAcceptCarryTask, isTrue);
  });

  test('ölüm ve ayrılış callback yeniden atamasını reddeder', () {
    final dying = villager();
    bool? deathRetry;
    dying.assignCarryTask(
      Object(),
      4,
      4,
      8,
      8,
      onCancelled: (_) {
        deathRetry = dying.assignCarryTask(Object(), 1, 1, 2, 2);
      },
    );
    dying.startDying();

    expect(deathRetry, isFalse);
    expect(dying.hasCarryTask, isFalse);

    final leaving = villager();
    bool? leaveRetry;
    leaving.assignCarryTask(
      Object(),
      4,
      4,
      8,
      8,
      onCancelled: (_) {
        leaveRetry = leaving.assignCarryTask(Object(), 1, 1, 2, 2);
      },
    );
    leaving.startLeaving(39, 39);

    expect(leaveRetry, isFalse);
    expect(leaving.hasCarryTask, isFalse);
  });

  test('anchor rebuild aynı binanın canlı rezervasyonunu korur', () {
    final v = villager();
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 8,
      row: 8,
    );
    final anchors = AnchorSystem()..rebuild([warehouse]);
    final claim = anchors.claimDeliverySlot(0, 0, v)!;
    final oldPoint = claim.$1;
    final slot = claim.$2;

    anchors.rebuild([warehouse]);

    expect(anchors.warehousePoints.single, same(oldPoint));
    expect(
      anchors.warehousePoints.single.slots.where((s) => s.isFree).length,
      4,
    );
    expect(anchors.hasReservationAt(warehouse, v), isTrue);
    oldPoint.release(slot, v);
    expect(anchors.warehousePoints.single.slots.every((s) => s.isFree), isTrue);
  });

  test('ambar doluyken balya ateş yerine fallback yapmaz', () {
    final warehouse = BuildingEntity(
      type: BuildingType.warehouse,
      col: 8,
      row: 8,
    );
    final firepit = BuildingEntity(type: BuildingType.firepit, col: 3, row: 3);
    final anchors = AnchorSystem()..rebuild([warehouse, firepit]);
    final blockers = <Object>[];
    for (var i = 0; i < 5; i++) {
      final owner = Object();
      blockers.add(owner);
      expect(anchors.warehousePoints.single.claim(owner), isNotNull);
    }
    final v = villager(x: 2, y: 2);
    final bale = HayEntity(type: HayType.bale, gridX: 2, gridY: 2);

    assignCarriers(
      villagers: [v],
      buildings: [warehouse, firepit],
      resourceBoxes: const [],
      hayEntities: [bale],
      stockpile: ResourceBundle(),
      anchorSystem: anchors,
    );

    expect(v.hasCarryTask, isFalse);
    expect(bale.isBeingCarried, isFalse);
    expect(anchors.firepitPoints.single.slots.every((s) => s.isFree), isTrue);
  });

  test('iki-elli gündelik prop da porter ile aynı el duruşunu kullanır', () {
    final v = villager();

    v.prop = PropKind.basket;
    expect(v.holdsItemTwoHanded, isTrue);
    v.prop = PropKind.mug;
    expect(v.holdsItemTwoHanded, isFalse);

    v.prop = PropKind.none;
    expect(v.assignCarryTask(Object(), 4, 0, 8, 0), isTrue);
    expect(
      v.holdsItemTwoHanded,
      isFalse,
      reason: 'pickup yolunda yük henüz elde değildir',
    );
  });
}
