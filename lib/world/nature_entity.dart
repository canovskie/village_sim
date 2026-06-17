/// Suda yüzen lotus (tek tile üzerinde).
class LotusEntity {
  final int col, row;
  final int variant; // 0 = beyaz, 1 = sarı

  const LotusEntity({required this.col, required this.row, required this.variant});

  double get depth => (col + row).toDouble() + 0.3;
}

/// Göl kenarında 2 kare kaplayan saz kümesi.
/// Biçilebilir: olgunken (growth>=1) evsizler biçer, saz toplar. Biçilince
/// growth 0'a düşer (anız) ve su kenarında yavaşça yeniden büyür.
class ReedClump {
  final int col,  row;   // 1. tile
  final int col2, row2;  // 2. tile (yan yana)

  /// 0 = yeni biçilmiş (anız), 1 = olgun/biçilebilir.
  double growth;

  ReedClump({
    required this.col,  required this.row,
    required this.col2, required this.row2,
    this.growth = 1.0,
  });

  bool get harvestable => growth >= 1.0;

  /// Biç — sazı al, anıza dön.
  void harvest() => growth = 0.0;

  /// Yeniden büyüme — [regrowSeconds] sürede 0→1.
  void tickRegrow(double dt, double regrowSeconds) {
    if (growth < 1.0) {
      growth = (growth + dt / regrowSeconds).clamp(0.0, 1.0);
    }
  }

  // Derinlik: ikinci tile'ın önde olan ucunu kullan
  double get depth => (col + col2 + row + row2) / 2.0 + 0.5;
}
