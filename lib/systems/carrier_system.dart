import 'dart:math';
import '../buildings/building_entity.dart';
import '../buildings/building_type.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../entities/villager_entity.dart';
import '../world/hay_entity.dart';
import '../world/resource_box.dart';

/// Idle köylüleri yere düşmüş kaynak kutularına ve hay balyalarına atar.
/// Çiftçi NPC'leri sadece hay/bale taşır — odun/maden/demir kutularına dokunmaz.
///
/// Hedef öncelik: warehouse > firepit > sabit (8, 8) varsayılanı.
/// Mesafe filtreleri: kutu için 10 tile yarıçap, balya için 12 tile yarıçap.
void assignCarriers({
  required List<VillagerEntity> villagers,
  required List<BuildingEntity> buildings,
  required BuildingEntity? firepit,
  required List<ResourceBox> resourceBoxes,
  required List<HayEntity> hayEntities,
  required ResourceBundle stockpile,
  required Random rng,
}) {
  final warehouse = buildings
      .where((b) => b.type == BuildingType.warehouse)
      .firstOrNull;
  final destX = warehouse?.col.toDouble() ?? firepit?.col.toDouble() ?? 8.0;
  final destY = warehouse?.row.toDouble() ?? firepit?.row.toDouble() ?? 8.0;

  for (final v in villagers) {
    if (v.state != VillagerState.idle) continue;
    // Çiftçiler odun/maden kutusu taşımaz — sadece saman/balya taşır.
    final isFarmer = v.type == VillagerType.farmer;

    if (!isFarmer) {
      ResourceBox? nearestBox;
      double bestDist = double.infinity;
      for (final b in resourceBoxes) {
        if (b.isBeingCarried || b.isDelivered) continue;
        final dx = b.gridX - v.gridX;
        final dy = b.gridY - v.gridY;
        final d  = dx * dx + dy * dy;
        if (d < bestDist && d < 10 * 10) {
          bestDist   = d;
          nearestBox = b;
        }
      }
      if (nearestBox != null) {
        nearestBox.isBeingCarried = true;
        final deliverX = destX + rng.nextDouble() * 2 - 1;
        final deliverY = destY + rng.nextDouble() * 2 - 1;
        final box = nearestBox;
        v.assignCarryTask(
          box,
          box.gridX, box.gridY,
          deliverX, deliverY,
          onDelivered: () {
            box.isDelivered = true;
            resourceBoxes.remove(box);
            switch (box.type) {
              case ResourceBoxType.woodChunk: stockpile.wood++;
              case ResourceBoxType.stoneBox:  stockpile.stone++;
              case ResourceBoxType.ironBox:   stockpile.iron++;
              case ResourceBoxType.coalBox:   stockpile.coal++;
            }
          },
        );
        continue;
      }
    }

    // Balya (bale) varsa depoya/ateşe taşı — pile'lar tarlada kalır.
    if (warehouse != null) {
      HayEntity? nearestBale;
      double bestBaleDist = double.infinity;
      for (final h in hayEntities) {
        if (!h.isBale || h.isBeingCarried || h.isDelivered) continue;
        final dx = h.gridX - v.gridX;
        final dy = h.gridY - v.gridY;
        final d  = dx * dx + dy * dy;
        if (d < bestBaleDist && d < 12 * 12) {
          bestBaleDist = d;
          nearestBale  = h;
        }
      }
      if (nearestBale != null) {
        nearestBale.isBeingCarried = true;
        final deliverX = destX + rng.nextDouble() * 2 - 1;
        final deliverY = destY + rng.nextDouble() * 2 - 1;
        final bale = nearestBale;
        v.assignCarryTask(
          bale,
          bale.gridX, bale.gridY,
          deliverX, deliverY,
          onDelivered: () {
            bale.isDelivered = true;
            hayEntities.remove(bale);
            // Bir balya = bir birim yiyecek (4 hay pile'dan oluşur).
            stockpile.food += 1;
          },
        );
      }
    }
  }
}
