import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/systems/locomotion.dart';

/// NPC hareketinin "akıcılık" sözleşmesi.
///
/// Bu dosyanın varlık sebebi tek bir şikâyet: köylüler sürekli ileri geri
/// gidip geliyordu. Aşağıdaki testler o davranışın dört kaynağını da kilitler —
/// ivme, dönüş sınırı, bakış histerezisi ve hedef sürekliliği. Biri gevşerse
/// titreme geri gelir.
void main() {
  group('Locomotion — ivme ve atalet', () {
    test('duraktan tam hıza tek karede sıçramaz', () {
      final l = Locomotion();
      final (dx, _) = l.advance(1 / 60.0, 1, 0, 2.0);
      // Tek kare (16ms) ivmeyle hızın küçük bir kısmı alınır.
      expect(l.vx, lessThan(2.0 * 0.35),
          reason: 'ilk karede tam hıza ulaşmamalı (atalet)');
      expect(dx, greaterThan(0), reason: 'yine de ileri gitmeli');
    });

    test('yeterli süre sonra istenen hıza yakınsar', () {
      final l = Locomotion();
      for (int i = 0; i < 120; i++) {
        l.advance(1 / 60.0, 1, 0, 2.0);
      }
      expect(l.speedNow, closeTo(2.0, 0.05));
    });

    test('hedef hız düşünce frenler', () {
      final l = Locomotion();
      for (int i = 0; i < 120; i++) {
        l.advance(1 / 60.0, 1, 0, 2.0);
      }
      for (int i = 0; i < 30; i++) {
        l.brake(1 / 60.0);
      }
      expect(l.speedNow, lessThan(0.15));
    });
  });

  group('Locomotion — dönüş sınırı (keskin köşe yok)', () {
    test('180° ters yön isteği tek karede uygulanmaz', () {
      final l = Locomotion();
      for (int i = 0; i < 120; i++) {
        l.advance(1 / 60.0, 1, 0, 2.0);
      }
      // Tam ters yön iste.
      l.advance(1 / 60.0, -1, 0, 2.0);
      expect(l.vx, greaterThan(0),
          reason: 'hız tek karede işaret değiştirmemeli — U dönüşü zaman alır');
    });

    test('U dönüşü makul sürede tamamlanır (takılıp kalmaz)', () {
      final l = Locomotion();
      for (int i = 0; i < 120; i++) {
        l.advance(1 / 60.0, 1, 0, 2.0);
      }
      for (int i = 0; i < 90; i++) {
        l.advance(1 / 60.0, -1, 0, 2.0);
      }
      expect(l.vx, lessThan(-1.0), reason: '1.5 sn içinde ters yöne geçmeli');
    });
  });

  group('Locomotion — bakış yönü', () {
    test('eşik altı gürültü bakış yönünü çevirmez', () {
      final l = Locomotion();
      l.snapFacing(true);
      // Deadband içinde salınan küçük bir hız.
      for (int i = 0; i < 200; i++) {
        l.vx = (i.isEven ? 1 : -1) * Locomotion.kFaceDeadband * 0.9;
        l.faceTick(1 / 60.0);
      }
      expect(l.facingRight, isTrue, reason: 'gürültü bandında yön sabit kalmalı');
      expect(l.turnScaleX, 1.0, reason: 'dönüş animasyonu hiç tetiklenmemeli');
    });

    test('kararlı ters hız yön değiştirir ama anında değil', () {
      final l = Locomotion();
      l.snapFacing(true);
      l.vx = -1.5;
      const dt = 1 / 60.0;
      // Histerezis süresi dolmadan karar değişmemeli.
      for (double t = 0; t < Locomotion.kFaceHold * 0.5; t += dt) {
        l.faceTick(dt);
      }
      expect(l.facingRight, isTrue);
      expect(l.turnScaleX, 1.0, reason: 'karar verilmeden dönüş başlamamalı');
      // Histerezis dolar → karar değişir, görsel dönüş akmaya başlar.
      for (double t = 0; t < Locomotion.kFaceHold * 0.7; t += dt) {
        l.faceTick(dt);
      }
      expect(l.facingSign, lessThan(1.0));
      expect(l.turnScaleX, lessThan(1.0),
          reason: 'dönüş anında sprite yatayda daralmalı');
      for (int i = 0; i < 60; i++) {
        l.faceTick(1 / 60.0);
      }
      expect(l.facingRight, isFalse);
      expect(l.turnScaleX, 1.0, reason: 'dönüş bitince ölçek geri gelmeli');
    });

    test('turnScaleX hiçbir zaman sıfırlanmaz (karakter kaybolmaz)', () {
      final l = Locomotion();
      l.snapFacing(true);
      l.faceTo(false);
      for (int i = 0; i < 60; i++) {
        expect(l.turnScaleX, greaterThanOrEqualTo(Locomotion.kEdgeOnScale));
        l.faceTick(1 / 240.0);
      }
    });
  });

  group('Locomotion — kaçınma yönü büker, ezmez', () {
    test('kaçınma vektörü gidişi saptırır ama geri çevirmez', () {
      final l = Locomotion();
      for (int i = 0; i < 120; i++) {
        l.advance(1 / 60.0, 1, 0, 2.0);
      }
      l.addAvoid(0, 0.85); // yandan iten komşu
      for (int i = 0; i < 20; i++) {
        l.advance(1 / 60.0, 1, 0, 2.0);
        l.addAvoid(0, 0.85);
      }
      expect(l.vx, greaterThan(0.8),
          reason: 'hedefe doğru ilerleme sürmeli (kaçınma hedefi ezmemeli)');
      expect(l.vy, greaterThan(0.1), reason: 'yandan dolanma görünmeli');
    });

    test('kaçınma her karede tüketilir (birikip patlamaz)', () {
      final l = Locomotion();
      l.addAvoid(0, 1.0);
      l.advance(1 / 60.0, 1, 0, 2.0);
      expect(l.avoidX, 0);
      expect(l.avoidY, 0);
    });
  });

  group('Köylü — git-gel regresyonu', () {
    /// Bir köylüyü [seconds] sn boyunca boşta dolaştırıp bakış yönünün kaç kez
    /// değiştiğini sayar. Eski sistemde `glanceAround` her varışta sprite'ı
    /// aynalıyor, hedefler de zıt yönlerde seçiliyordu → dakikada onlarca flip.
    int facingFlips(VillagerEntity v, double seconds) {
      final rng = Random(7);
      var flips = 0;
      var last = v.facingRight;
      const dt = 1 / 60.0;
      for (double t = 0; t < seconds; t += dt) {
        v.update(dt, 64, 64, rng);
        v.smoothMotion(dt);
        if (v.facingRight != last) {
          flips++;
          last = v.facingRight;
        }
      }
      return flips;
    }

    test('çocuk (en telaşlı persona) dakikada makul sayıda yön değiştirir', () {
      // playful davranış: en kısa oyalanma, en yüksek tempo — worst case.
      final v = VillagerEntity(
          type: VillagerType.farmer,
          name: 'Çocuk',
          male: true,
          startCol: 32,
          startRow: 32);
      final flips = facingFlips(v, 120.0);
      // 2 dakikada 40'tan az → ortalama 3 sn'de birden seyrek. Eski sistemde
      // yalnız varış glance'ları bunun katlarını üretiyordu.
      expect(flips, lessThan(40),
          reason: 'sürekli ileri geri dönme geri gelmiş olabilir ($flips flip)');
    });

    test('köylü gerçekten yol kat eder (titremeye çare diye donmadı)', () {
      final v = VillagerEntity(
          type: VillagerType.farmer,
          name: 'Ali',
          male: true,
          startCol: 32,
          startRow: 32);
      final rng = Random(3);
      const dt = 1 / 60.0;
      double travelled = 0;
      var px = v.gridX, py = v.gridY;
      for (double t = 0; t < 120.0; t += dt) {
        v.update(dt, 64, 64, rng);
        v.smoothMotion(dt);
        travelled += sqrt(pow(v.gridX - px, 2) + pow(v.gridY - py, 2));
        px = v.gridX;
        py = v.gridY;
      }
      expect(travelled, greaterThan(10.0),
          reason: 'köylü hâlâ dolaşmalı (kat edilen yol $travelled tile)');
    });

    test('yürürken glanceAround yok sayılır', () {
      final v = VillagerEntity(
          type: VillagerType.guard,
          name: 'Nöbetçi',
          male: true,
          startCol: 32,
          startRow: 32);
      v.goTo(40, 32, 2.0);
      final rng = Random(1);
      const dt = 1 / 60.0;
      for (int i = 0; i < 60; i++) {
        v.update(dt, 64, 64, rng);
        v.smoothMotion(dt);
      }
      expect(v.isWalking, isTrue);
      final before = v.facingRight;
      v.glanceAround(duration: 1.0);
      v.smoothMotion(dt);
      expect(v.facingRight, before,
          reason: 'yürüyen NPC adımının ortasında geri dönmemeli');
    });
  });
}
