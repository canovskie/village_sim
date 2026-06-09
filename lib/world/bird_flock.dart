import 'dart:math';
import '../core/constants.dart';

/// V-formation slot — leader-relative koordinatlar (uçuş yönü = along, sol 90° = perp).
class Bird {
  final double slotAlong; // 0 = leader, <0 = arkada
  final double slotPerp;  // ±, leader'ın yan kanatları
  final double wingPhaseOffset;
  const Bird({
    required this.slotAlong,
    required this.slotPerp,
    required this.wingPhaseOffset,
  });
}

/// Ambient gökyüzü kuş sürüsü. Etkileşim yok — pure atmosphere katmanı.
/// Bir kenardan girer, karşı kenara uçar, off-grid olunca temizlenir.
class BirdFlock {
  /// Leader (formasyon başı) dünya konumu (tile).
  double leadX, leadY;
  /// Normalize uçuş yönü.
  final double dirX, dirY;
  /// tile/sn.
  final double speed;
  /// Ekran üzerinde gökyüzü yüksekliği — render'da Y offset olarak çekilir (px).
  final double altitude;
  final List<Bird> birds;
  /// Spawn fade-in için yaş (sn).
  double age = 0.0;

  BirdFlock({
    required this.leadX,
    required this.leadY,
    required this.dirX,
    required this.dirY,
    required this.speed,
    required this.altitude,
    required this.birds,
  });

  void update(double dt) {
    leadX += dirX * speed * dt;
    leadY += dirY * speed * dt;
    age += dt;
  }

  /// 10 tile dışına çıktıysa öldü → liste temizlemeli.
  bool get isDead =>
      leadX < -10 || leadX > kCols + 10 ||
      leadY < -10 || leadY > kRows + 10;

  /// Bird'ün dünya konumu. Slot leader-relative; uçuş yönüne göre rotate.
  (double, double) birdWorldPos(Bird b) {
    final wx = leadX + b.slotAlong * dirX + b.slotPerp * (-dirY);
    final wy = leadY + b.slotAlong * dirY + b.slotPerp * dirX;
    return (wx, wy);
  }

  /// Rastgele bir kenardan girip karşı yöne uçan V-formation sürü üretir.
  static BirdFlock spawnRandomEdge(Random rng) {
    final edge = rng.nextInt(4);
    late double sx, sy, dx, dy;
    final crossT = 0.15 + rng.nextDouble() * 0.7;
    switch (edge) {
      case 0: // N → S
        sx = crossT * kCols;
        sy = -8;
        dx = (rng.nextDouble() - 0.5) * 0.5;
        dy = 1.0;
      case 1: // E → W
        sx = kCols + 8.0;
        sy = crossT * kRows;
        dx = -1.0;
        dy = (rng.nextDouble() - 0.5) * 0.5;
      case 2: // S → N
        sx = crossT * kCols;
        sy = kRows + 8.0;
        dx = (rng.nextDouble() - 0.5) * 0.5;
        dy = -1.0;
      default: // W → E
        sx = -8.0;
        sy = crossT * kRows;
        dx = 1.0;
        dy = (rng.nextDouble() - 0.5) * 0.5;
    }
    final dlen = sqrt(dx * dx + dy * dy);
    dx /= dlen;
    dy /= dlen;

    // V-formation: leader + her kanat için 2-3 kuş, geriye doğru staggered.
    final wingCount = 2 + rng.nextInt(2);
    final birds = <Bird>[
      Bird(slotAlong: 0, slotPerp: 0, wingPhaseOffset: rng.nextDouble() * 2 * pi),
    ];
    final spread = 0.55 + rng.nextDouble() * 0.25;
    for (int i = 1; i <= wingCount; i++) {
      birds.add(Bird(
        slotAlong: -i * spread * 1.25,
        slotPerp:  -i * spread,
        wingPhaseOffset: rng.nextDouble() * 2 * pi,
      ));
      birds.add(Bird(
        slotAlong: -i * spread * 1.25,
        slotPerp:   i * spread,
        wingPhaseOffset: rng.nextDouble() * 2 * pi,
      ));
    }

    return BirdFlock(
      leadX: sx,
      leadY: sy,
      dirX: dx,
      dirY: dy,
      speed: 1.7 + rng.nextDouble() * 1.0, // 1.7-2.7 tile/sn — sakin glide
      altitude: 75.0 + rng.nextDouble() * 50.0,
      birds: birds,
    );
  }
}
