/// Ağaç devrildiğinde kısa ömürlü yaprak patlaması (kesim juice'u).
///
/// Yalnız pozisyon + seed + yaş tutar; tek tek yapraklar render'da seed+yaştan
/// PROSEDÜREL hesaplanır (per-yaprak storage yok). scene_tick devrilen ön-hat
/// ağacında spawn eder, [age] ilerler, [dead] olunca silinir.
class LeafBurst {
  final double x, y; // grid (kesirli tile) — ağacın tabanı
  final int seed;
  final int direction; // ekran uzayında taç düşüş yönü (-1 / +1)
  double age = 0;
  LeafBurst(this.x, this.y, this.seed, {this.direction = 1});

  static const double lifetime = 0.95;
  bool get dead => age >= lifetime;
}
