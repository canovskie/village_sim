import '../world/hay_entity.dart';

/// 4 saman yığını (pile) yan yana toplandığında balyaya (bale) dönüştürür.
/// Çağıran tarafın `update` döngüsünde her tick'te çağırılması beklenir.
///
/// Cluster detection: 1.5 tile yarıçap, en fazla 4 pile alınır.
/// Balya konumu: tile başına 2 slot (arka + ön). Slot'lar dolduğunda
/// bir sonraki balya bir sonraki tile'a düşer.
void processHayPiles(List<HayEntity> hayEntities) {
  final piles = hayEntities
      .where((h) => !h.isBale && !h.isBeingCarried && !h.isDelivered)
      .toList();
  for (int i = 0; i < piles.length; i++) {
    final cluster = piles.where((p) {
      final dx = p.gridX - piles[i].gridX;
      final dy = p.gridY - piles[i].gridY;
      return dx * dx + dy * dy <= 1.5 * 1.5;
    }).take(4).toList();

    if (cluster.length >= 4) {
      final rawCx = cluster.map((p) => p.gridX).reduce((a, b) => a + b) / 4;
      final rawCy = cluster.map((p) => p.gridY).reduce((a, b) => a + b) / 4;

      // Her balya 0.5×0.5 birim, alt alta dizilir.
      // Slot 0: (0, 0)       → arka (ekranda üst)
      // Slot 1: (0.58, 0.42) → ön   (ekranda alt, biraz sağa kayık)
      final tileC = rawCx.floor().toDouble();
      final tileR = rawCy.floor().toDouble();
      final balesInTile = hayEntities.where((h) =>
        h.isBale && !h.isDelivered &&
        h.gridX >= tileC && h.gridX < tileC + 1.0 &&
        h.gridY >= tileR && h.gridY < tileR + 1.0,
      ).length;
      final slot = balesInTile == 0 ? 0 : 1;
      final cx = tileC + (slot == 0 ? 0.0 : 0.58);
      final cy = tileR + (slot == 0 ? 0.0 : 0.42);

      for (final p in cluster) {
        p.isDelivered = true;
      }
      hayEntities.add(HayEntity(type: HayType.bale, gridX: cx, gridY: cy));
      break; // Bir tick'te bir cluster yeter — sonraki tick'te diğeri.
    }
  }
  hayEntities.removeWhere((h) => h.isDelivered);
}
