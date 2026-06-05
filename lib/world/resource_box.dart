enum ResourceBoxType { woodChunk, stoneBox, ironBox, coalBox }

class ResourceBox {
  final ResourceBoxType type;
  double gridX;
  double gridY;
  bool isBeingCarried = false;
  bool isDelivered = false;

  /// Spawn anındaki sahne zamanı (sn). Drop animation için renderer kullanır:
  /// time − spawnTime < kDropDuration ise yukarıdan inerek + bounce çizilir.
  double spawnTime = 0;
  /// Tile içindeki yığın slotu (0..8). Aynı tile'da birden fazla kutu varsa
  /// her birine ayrı slot atanır → 3×3 mini grid içinde yerleşim. 9+ olursa
  /// modulo + küçük jitter.
  int slotIndex = 0;

  ResourceBox({required this.type, required this.gridX, required this.gridY});

  double get depth => gridX + gridY;

  String get spriteName {
    switch (type) {
      case ResourceBoxType.woodChunk: return 'woodchunk';
      case ResourceBoxType.stoneBox:  return 'stonebox';
      case ResourceBoxType.ironBox:   return 'ironbox';
      case ResourceBoxType.coalBox:   return 'coalbox';
    }
  }
}
