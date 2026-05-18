enum OreType { stone, iron, coal }

extension OreTypeExt on OreType {
  int    get goldValue => switch (this) { OreType.stone => 8, OreType.iron => 22, OreType.coal => 15 };
  double get mineTime  => switch (this) { OreType.stone => 2.5, OreType.iron => 4.0, OreType.coal => 3.2 };
  String get label     => switch (this) { OreType.stone => 'Taş', OreType.iron => 'Demir', OreType.coal => 'Kömür' };
}

class MineNode {
  final int     col, row;
  final OreType type;

  bool isMarkedForMining = false;
  bool isBeingMined      = false;
  bool isDepleted        = false;

  /// −1 = aktif kazım yok.  0..2π = kazma darbe fazı (tree.chopPhase ile aynı mantık).
  double chopPhase = -1.0;

  MineNode({required this.col, required this.row, required this.type});

  double get depth => (col + row + 0.8).toDouble();
}
