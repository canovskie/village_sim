/// Suda yüzen lotus (tek tile üzerinde).
class LotusEntity {
  final int col, row;
  final int variant; // 0 = beyaz, 1 = sarı

  const LotusEntity({required this.col, required this.row, required this.variant});

  double get depth => (col + row).toDouble() + 0.3;
}

/// Göl kenarında 2 kare kaplayan saz kümesi.
class ReedClump {
  final int col,  row;   // 1. tile
  final int col2, row2;  // 2. tile (yan yana)

  const ReedClump({
    required this.col,  required this.row,
    required this.col2, required this.row2,
  });

  // Derinlik: ikinci tile'ın önde olan ucunu kullan
  double get depth => (col + col2 + row + row2) / 2.0 + 0.5;
}
