// SOKAĞA ÇIKMA YASAĞI — köyün hâlinin gövdeye değdiği ilk yer.
//
// [WorldPressure.curfewBias] köylünün "gece oldu, içeri" eşiğini yukarı iter.
// Bu testin asıl derdi bir REGRESYON tuzağı:
//
//   Yatma eşiği (kNightThreshold + bias) uyanma eşiğini (kDawnThreshold)
//   geçerse köylü şafakta uyanır, aynı karede "hâlâ gece" görüp tekrar yatar.
//   Kilitlenmiş bir titreme — ekranda köy sabaha karşı donmuş gibi görünür.
//
// Sözleşme: yasak akşamı ÖNE alır, sabahı kilitlemez.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';

VillagerEntity _villager({double curfewBias = 0, bool nightDuty = false}) {
  final v = VillagerEntity(
    type: VillagerType.farmer,
    name: 'Deneme',
    male: true,
    startCol: 10,
    startRow: 10,
    ageDays: kAdultStartDay + 5,
    visualSeed: 7,
    personalitySeed: 7,
  )
    ..curfewBias = curfewBias
    ..nightDuty = nightDuty
    ..sleepTarget = (10, 10)
    ..sleepIsHome = false;
  return v;
}

void _step(VillagerEntity v, double dayLight, {double dt = 0.1}) {
  v.update(dt, 64, 64, Random(1), dayLight: dayLight);
}

void main() {
  group('yasaksız köy — taban davranış korunur', () {
    test('gündüz uyanık, gece uykuda', () {
      final v = _villager();
      _step(v, 0.9);
      expect(v.isSleeping, isFalse);
      _step(v, 0.05);
      expect(v.isSleeping, isTrue);
    });

    test('şafakta uyanır ve uyanık kalır', () {
      final v = _villager();
      _step(v, 0.05);
      expect(v.isSleeping, isTrue);
      // Işık yükseliyor — kDawnThreshold (0.25) üstünde uyanmalı.
      for (var l = 0.10; l <= 0.60; l += 0.05) {
        _step(v, l);
      }
      // Kademeli uyanış: köylü şafakta kişisel bir gecikmeyle (≤~6.5s) uyanır —
      // köy tek karede toplu değil, dalga dalga kalksın diye. Gündüz ışığında
      // gecikme dolunca uyanmalı (ve uyanık kalmalı).
      for (var i = 0; i < 80; i++) {
        _step(v, 0.9);
      }
      expect(v.isSleeping, isFalse);
    });
  });

  group('yasak altında', () {
    test('köy DAHA AYDINLIKKEN içeri çekilir', () {
      final free = _villager();
      final curfewed = _villager(curfewBias: 0.16);
      // Akşam ışığı: yasaksız köylü için henüz gece değil, yasaklı için gece.
      const dusk = 0.20;
      _step(free, dusk);
      _step(curfewed, dusk);
      expect(free.isSleeping, isFalse, reason: 'yasaksız köylü hâlâ dışarıda');
      expect(curfewed.isSleeping, isTrue, reason: 'yasaklı köylü içeri çekildi');
    });

    test('AĞIR yasakta bile şafakta titremez — uyan/yat döngüsüne girmez', () {
      // Tavan bias (0.22): yatma eşiği 0.37, kDawnThreshold 0.25'in ÜSTÜNDE.
      // Naif kurulumda tam burada sonsuz döngü doğuyordu.
      final v = _villager(curfewBias: 0.22);
      _step(v, 0.05);
      expect(v.isSleeping, isTrue);

      // Şafak boyunca ışığı yavaşça yükselt; her adımda uyku durumunu izle.
      var flips = 0;
      var wasSleeping = v.isSleeping;
      for (var l = 0.05; l <= 0.95; l += 0.01) {
        _step(v, l);
        if (v.isSleeping != wasSleeping) {
          flips++;
          wasSleeping = v.isSleeping;
        }
      }
      // Tam olarak BİR geçiş olmalı: uyku → uyanık. Fazlası titremedir.
      expect(flips, 1, reason: 'şafakta $flips kez durum değişti (titreme)');
      expect(v.isSleeping, isFalse, reason: 'gün ortasında uyanık olmalı');
    });

    test('ağır yasak köyü gündüz uykuda tutmaz', () {
      final v = _villager(curfewBias: 0.22);
      _step(v, 0.05);
      for (var l = 0.05; l <= 0.80; l += 0.05) {
        _step(v, l);
      }
      // Kademeli uyanış gecikmesi (≤~6.5s) gündüz ışığında dolmalı.
      for (var i = 0; i < 80; i++) {
        _step(v, 0.9);
      }
      expect(v.isSleeping, isFalse);
    });
  });

  group('gece nöbeti', () {
    test('nöbetçi gece uykuya çekilmez', () {
      final v = _villager(nightDuty: true);
      for (var i = 0; i < 20; i++) {
        _step(v, 0.02);
      }
      expect(v.isSleeping, isFalse);
    });

    test('nöbetçi olmayan aynı koşulda uyur — fark nöbetten geliyor', () {
      final v = _villager();
      _step(v, 0.02);
      expect(v.isSleeping, isTrue);
    });

    test('yasak + nöbet birlikte: sokak boşalır ama nöbetçi ayakta kalır', () {
      final civilian = _villager(curfewBias: 0.16);
      final watch = _villager(curfewBias: 0.16, nightDuty: true);
      _step(civilian, 0.20);
      _step(watch, 0.20);
      expect(civilian.isSleeping, isTrue);
      expect(watch.isSleeping, isFalse);
    });
  });

  // ── YATAĞA DÖNÜŞ ──────────────────────────────────────────────────────────
  //
  // Gerçek şikâyetin kaynağı: köy hiçbir zaman sessizleşmiyordu. Prova
  // dökümünde derin gecede 15-18 kişilik köyde uyuyan 0-7 arasındaydı ve
  // geceyi "boşta" dikilerek geçiren 7-10 köylü vardı.
  //
  // Sebep `_wasSleeping`in TEK ATIŞLIK olmasıydı: köylüyü gece bir kez
  // yataktan koparan her şey (iş döngüsünün goTo'su, tören, taşıma görevi)
  // onu sabaha kadar ayakta bırakıyordu. Aşağıdaki iki test o kapıyı kilitler.
  group('yatağa dönüş', () {
    test('gece uyandırılan köylü boşa düşünce yatağına döner', () {
      final v = _villager();
      _step(v, 0.05);
      expect(v.isSleeping, isTrue, reason: 'önce uyumuş olmalı');

      // Gece yarısı bir şey onu ayağa kaldırdı (iş/tören/taşıma taklidi).
      v.state = VillagerState.idle;
      expect(v.isSleeping, isFalse);

      // Hâlâ gece ve köylü boşta → yatağına dönmeli.
      _step(v, 0.05);
      expect(v.isSleeping, isTrue,
          reason: 'boştaki köylü geceyi ayakta geçirmemeli');
    });

    test('gece uyandırılan MEŞGUL köylü zorla yatırılmaz', () {
      final v = _villager();
      _step(v, 0.05);
      expect(v.isSleeping, isTrue);

      // Sohbete girmiş: yürüyen/oynayan köylüyü yatağa zorlamak sahneyi bozar
      // (yarım kalan sohbet, ayağa fırlayan dinleyici). Dönüş yalnız BOŞTA.
      v.state = VillagerState.idle;
      v.activity = VillagerActivity.chat;
      _step(v, 0.05);
      expect(v.isSleeping, isFalse,
          reason: 'meşgul köylü yatağa çekilmemeli');
    });
  });
}
