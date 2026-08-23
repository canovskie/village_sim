import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/npc_visual.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/rendering/character_renderer.dart';
import 'package:village_sim/rendering/game_painter.dart';
import 'package:village_sim/rendering/resource_renderer.dart';
import 'package:village_sim/systems/road_system.dart';
import 'package:village_sim/world/resource_box.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const width = 220;
  const height = 190;
  const feet = Offset(110, 160);

  Future<Uint8List> rawFrame({
    VillagerType type = VillagerType.farmer,
    NpcVisual? visual,
    bool flip = false,
    double phase = 0,
    double moveIntensity = 1,
    double outerScale = 1,
    bool carrying = true,
    void Function(Canvas)? heldItem,
    bool behindBody = false,
    CharGesture gesture = CharGesture.none,
    double gestureAmount = 0,
    double torchLevel = 0,
    bool attacking = false,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.translate(feet.dx, feet.dy);
    canvas.scale(outerScale, outerScale);
    CharacterRenderer.draw(
      canvas,
      type,
      visual: visual,
      flipX: flip,
      walkPhase: phase,
      moveIntensity: moveIntensity,
      carrying: carrying,
      heldItem: heldItem,
      heldItemBehindBody: behindBody,
      gesture: gesture,
      gestureAmount: gestureAmount,
      torchLevel: torchLevel,
      attacking: attacking,
    );
    final image = await recorder.endRecording().toImage(width, height);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }

  int countColor(Uint8List data, int red, int green, int blue) {
    var count = 0;
    for (var i = 0; i < data.length; i += 4) {
      if (data[i] == red &&
          data[i + 1] == green &&
          data[i + 2] == blue &&
          data[i + 3] == 255) {
        count++;
      }
    }
    return count;
  }

  int differingPixels(
    Uint8List a,
    Uint8List b, {
    int minX = 0,
    int maxX = width,
  }) {
    var differing = 0;
    for (var y = 0; y < height; y++) {
      for (var x = minX; x < maxX; x++) {
        final i = (y * width + x) * 4;
        if (a[i] != b[i] ||
            a[i + 1] != b[i + 1] ||
            a[i + 2] != b[i + 2] ||
            a[i + 3] != b[i + 3]) {
          differing++;
        }
      }
    }
    return differing;
  }

  Future<({Offset center, int pixels})> markerFrame({
    bool flip = false,
    double phase = 0,
    double moveIntensity = 1,
    double outerScale = 1,
    bool behindBody = false,
    Rect marker = const Rect.fromLTWH(8, -54, 5, 5),
  }) async {
    final data = await rawFrame(
      flip: flip,
      phase: phase,
      moveIntensity: moveIntensity,
      outerScale: outerScale,
      heldItem: (c) => c.drawRect(
        marker,
        Paint()
          ..color = const Color(0xFFFF00FF)
          ..isAntiAlias = false,
      ),
      behindBody: behindBody,
    );
    var sumX = 0.0;
    var sumY = 0.0;
    var count = 0;
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        final i = (y * width + x) * 4;
        if (data[i] == 255 &&
            data[i + 1] == 0 &&
            data[i + 2] == 255 &&
            data[i + 3] == 255) {
          sumX += x + 0.5;
          sumY += y + 0.5;
          count++;
        }
      }
    }
    return (
      center: count == 0 ? Offset.zero : Offset(sumX / count, sumY / count),
      pixels: count,
    );
  }

  test('iki elli yük açıları merkeze kapanır ve yürürken kavrama bozulmaz', () {
    for (var i = 0; i <= 16; i++) {
      final phase = i / 16 * 2 * pi;
      final grip = twoHandCarryArmAngles(phase, 1);
      expect(grip.armL, isNegative, reason: 'sol el yük merkezine uzanmalı');
      expect(grip.armR, isPositive, reason: 'sağ el yük merkezine uzanmalı');
      expect(grip.armL.abs(), closeTo(grip.armR.abs(), 1e-9));
      expect(grip.armL.abs(), lessThan(0.60));
    }
  });

  test('eldeki nesne karakterle birlikte yön değiştirir', () async {
    final right = await markerFrame(flip: false);
    final left = await markerFrame(flip: true);

    expect(right.pixels, greaterThan(0));
    expect(left.pixels, greaterThan(0));
    expect(right.center.dx, greaterThan(110));
    expect(left.center.dx, lessThan(110));
    expect(
      right.center.dx - 110,
      closeTo(110 - left.center.dx, 1.1),
      reason: 'yük gövdeden ayrı yönde/screen-space konumunda kalmamalı',
    );
  });

  test('eldeki nesne yürüyüş bobunu ve dış beden ölçeğini paylaşır', () async {
    final stepHigh = await markerFrame(phase: pi / 2);
    final stepGround = await markerFrame(phase: 0);
    expect(
      stepHigh.center.dy,
      lessThan(stepGround.center.dy - 2.5),
      reason: 'yük torso yükselirken havada sabit kalmamalı',
    );

    final full = await markerFrame(outerScale: 1);
    final childScale = await markerFrame(outerScale: 0.6);
    final fullLift = 160 - full.center.dy;
    final childLift = 160 - childScale.center.dy;
    expect(childLift / fullLift, closeTo(0.6, 0.06));
  });

  test(
    'sırt yükü gövdenin arkasında, ön yük gövdenin üstünde katmanlanır',
    () async {
      const torsoMarker = Rect.fromLTWH(-4, -62, 8, 8);
      final front = await markerFrame(marker: torsoMarker);
      final back = await markerFrame(marker: torsoMarker, behindBody: true);

      expect(front.pixels, greaterThan(40));
      expect(
        back.pixels,
        lessThan(front.pixels ~/ 4),
        reason: 'çuval gövde/kolların üstüne yapıştırılmamalı',
      );
    },
  );

  test('porter yükü mesleğin sabit el ve omuz propunu bastırır', () async {
    final visual = NpcVisual.fromSeed(27, forceMale: true).copyWith(build: 1);

    final guardIdle = await rawFrame(
      type: VillagerType.guard,
      visual: visual,
      carrying: false,
      moveIntensity: 0,
    );
    final guardLoaded = await rawFrame(
      type: VillagerType.guard,
      visual: visual,
      heldItem: (_) {},
      moveIntensity: 0,
    );
    // 0x7A5030 muhafız gövdesinde yalnız mızrak sapının temel rengidir.
    expect(countColor(guardIdle, 0x7A, 0x50, 0x30), greaterThan(0));
    expect(countColor(guardLoaded, 0x7A, 0x50, 0x30), 0);

    final millerIdle = await rawFrame(
      type: VillagerType.miller,
      visual: visual,
      carrying: false,
      moveIntensity: 0,
    );
    final millerLoaded = await rawFrame(
      type: VillagerType.miller,
      visual: visual,
      heldItem: (_) {},
      moveIntensity: 0,
    );
    // 0xBFAE86 değirmencinin omuzdaki meslek çuvalıdır.
    expect(countColor(millerIdle, 0xBF, 0xAE, 0x86), greaterThan(0));
    expect(countColor(millerLoaded, 0xBF, 0xAE, 0x86), 0);
  });

  test('jest, meşale ve saldırı iki elli yük katmanını değiştirmez', () async {
    final visual = NpcVisual.fromSeed(31, forceMale: true).copyWith(build: 1);
    void load(Canvas c) {
      c.drawRect(
        const Rect.fromLTWH(-9, -55, 18, 14),
        Paint()
          ..color = const Color(0xFFFF00FF)
          ..isAntiAlias = false,
      );
    }

    final base = await rawFrame(
      type: VillagerType.guard,
      visual: visual,
      phase: 1.1,
      heldItem: load,
    );
    final contended = await rawFrame(
      type: VillagerType.guard,
      visual: visual,
      phase: 1.1,
      heldItem: load,
      gesture: CharGesture.wave,
      gestureAmount: 1,
      torchLevel: 1,
      attacking: true,
    );

    expect(contended, orderedEquals(base));
  });

  test('tek elli prop sol meşaleyi ve saldırı kolunu kilitlemez', () async {
    final visual = NpcVisual.fromSeed(41, forceMale: true).copyWith(build: 1);
    void oneHandMarker(Canvas c) {
      c.drawRect(
        const Rect.fromLTWH(5, -52, 7, 12),
        Paint()
          ..color = const Color(0xFFFF00FF)
          ..isAntiAlias = false,
      );
    }

    final base = await rawFrame(
      visual: visual,
      carrying: false,
      moveIntensity: 0,
      heldItem: oneHandMarker,
    );
    final torch = await rawFrame(
      visual: visual,
      carrying: false,
      moveIntensity: 0,
      heldItem: oneHandMarker,
      torchLevel: 1,
    );
    final attack = await rawFrame(
      visual: visual,
      carrying: false,
      moveIntensity: 0,
      heldItem: oneHandMarker,
      attacking: true,
    );

    expect(torch, isNot(orderedEquals(base)));
    expect(attack, isNot(orderedEquals(base)));

    final torchAttack = await rawFrame(
      visual: visual,
      carrying: false,
      moveIntensity: 0,
      heldItem: oneHandMarker,
      torchLevel: 1,
      attacking: true,
    );
    expect(
      differingPixels(torch, torchAttack, maxX: 100),
      0,
      reason: 'saldırı sağ koldayken sol kol meşaleden kopmamalı',
    );
    expect(
      differingPixels(torch, torchAttack),
      greaterThan(0),
      reason: 'sağ kol saldırı hareketini yine yapmalı',
    );
  });

  testWidgets('rezervasyon yükü pickup anına kadar yerde görünür', (
    tester,
  ) async {
    final frames = await tester.runAsync(() async {
      await ResourceRenderer.loadAll();
      final carrier = VillagerEntity(
        type: VillagerType.merchant,
        name: 'Taşıyıcı',
        male: true,
        startCol: 4,
        startRow: 4,
        ageDays: kAdultStartDay + 2,
        visualSeed: 17,
        personalitySeed: 17,
      );
      final box = ResourceBox(
        type: ResourceBoxType.woodChunk,
        gridX: 0,
        gridY: 0,
      )..isBeingCarried = true;
      expect(carrier.assignCarryTask(box, 0, 0, 8, 8), isTrue);
      expect(carrier.state, VillagerState.walkingToPickup);

      Future<Uint8List> sceneFrame(List<ResourceBox> boxes) async {
        const size = ui.Size(512, 320);
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        VillageGamePainter(
          villagers: [carrier],
          buildings: const [],
          pendingOrders: const [],
          roadSystem: RoadSystem(),
          camera: Offset.zero,
          resourceBoxes: boxes,
          time: 1,
          perfMode: true,
        ).paint(canvas, size);
        final picture = recorder.endRecording();
        final image = await picture.toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        picture.dispose();
        final data = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        image.dispose();
        if (data == null) throw StateError('Painter kare verisi üretmedi');
        return Uint8List.fromList(data.buffer.asUint8List());
      }

      return (await sceneFrame([box]), await sceneFrame(const []));
    });

    expect(frames, isNotNull);
    final (reserved, absent) = frames!;
    var differing = 0;
    for (var i = 0; i < reserved.length; i += 4) {
      if (reserved[i] != absent[i] ||
          reserved[i + 1] != absent[i + 1] ||
          reserved[i + 2] != absent[i + 2] ||
          reserved[i + 3] != absent[i + 3]) {
        differing++;
      }
    }
    expect(
      differing,
      greaterThan(20),
      reason: 'pickup yolundaki rezervasyon yerdeki yükü gizlememeli',
    );
  });
}
