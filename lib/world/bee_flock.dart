import 'dart:math';

/// Tek bir arının kovan etrafındaki orbit durumu. Açı sürekli döner,
/// yarıçap + dikey bob sinüsle nefes alır → "vızıltı" hissi.
class Bee {
  double angle;            // mevcut yörünge açısı (rad)
  final double angSpeed;   // açısal hız (rad/sn) — işareti dönüş yönü
  final double radBase;    // temel yörünge yarıçapı (tile)
  final double radJitter;  // yarıçap salınım genliği (tile)
  final double radPhase;   // yarıçap salınım fazı
  final double bobPhase;   // dikey bob fazı
  final double bobAmp;     // dikey bob genliği (px)
  final double wingPhase;  // kanat çırpış fazı (desync)

  Bee({
    required this.angle,
    required this.angSpeed,
    required this.radBase,
    required this.radJitter,
    required this.radPhase,
    required this.bobPhase,
    required this.bobAmp,
    required this.wingPhase,
  });
}

/// Bir arı kovanına bağlı ambient arı sürüsü. Kovan merkezinin etrafında
/// orbit eden birkaç arı — pure atmosphere, etkileşim yok. Kovan yaşadığı
/// sürece yaşar; gündüz görünür, gece fade (render tarafı). Kuş sürüsünün
/// ([BirdFlock]) orbit-bazlı küçük kardeşi.
class BeeSwarm {
  /// Bağlı olduğu kovanın footprint merkezi (tile).
  final double hiveX, hiveY;
  final List<Bee> bees;
  double time = 0.0;

  BeeSwarm({required this.hiveX, required this.hiveY, required this.bees});

  void update(double dt) {
    time += dt;
    for (final b in bees) {
      b.angle += b.angSpeed * dt;
    }
  }

  /// Arının o anki dünya konumu (tile). Yarıçap nefes alır; izometrik zemin
  /// için y ekseni hafif yassıdır (0.6). Dikey bob render'da px olarak eklenir.
  (double, double) beeWorldPos(Bee b) {
    final r = b.radBase + sin(time * 1.7 + b.radPhase) * b.radJitter;
    final wx = hiveX + cos(b.angle) * r;
    final wy = hiveY + sin(b.angle) * r * 0.6;
    return (wx, wy);
  }

  /// Arının render dikey ofseti (px) — kovan üstünde belirgin yükseklikte uçar.
  double beeBob(Bee b) => -16.0 + sin(time * 6.0 + b.bobPhase) * b.bobAmp;

  /// Bir kovan için rastgele sürü üretir (6-8 arı).
  static BeeSwarm spawn(double hiveX, double hiveY, Random rng) {
    final count = 6 + rng.nextInt(3); // 6-8
    final bees = <Bee>[
      for (int i = 0; i < count; i++)
        Bee(
          angle: rng.nextDouble() * 2 * pi,
          // Yön karışık (saat yönü / tersi), hız orta — telaşsız vızıltı.
          angSpeed: (rng.nextBool() ? 1 : -1) * (1.1 + rng.nextDouble() * 1.3),
          radBase: 0.7 + rng.nextDouble() * 1.1, // 0.7-1.8 tile — kovan çevresi
          radJitter: 0.15 + rng.nextDouble() * 0.22,
          radPhase: rng.nextDouble() * 2 * pi,
          bobPhase: rng.nextDouble() * 2 * pi,
          bobAmp: 3.5 + rng.nextDouble() * 3.0,
          wingPhase: rng.nextDouble() * 2 * pi,
        ),
    ];
    return BeeSwarm(hiveX: hiveX, hiveY: hiveY, bees: bees);
  }
}
