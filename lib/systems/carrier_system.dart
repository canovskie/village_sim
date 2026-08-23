import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../buildings/craft.dart';
import '../characters/villager_type.dart';
import '../core/constants.dart';
import '../core/resources.dart';
import '../entities/villager_entity.dart';
import '../world/hay_entity.dart';
import '../world/resource_box.dart';
import '../world/resource_placement.dart';
import 'anchor_system.dart';

/// Idle köylüleri yere düşmüş kaynak kutularına ve hay balyalarına atar.
/// Çiftçi NPC'leri sadece hay/bale taşır — odun/maden/demir kutularına dokunmaz.
///
/// Teslim noktası AnchorSystem üzerinden:
///   • Önce warehouse slot'u, yoksa firepit slot'u (fallback chain).
///   • Slot iş bitince release; aynı teslim noktasında yığılma olmaz.
/// Hiç anchor yoksa (ne warehouse ne firepit) taşıma yapılmaz — varsayılan
/// "8,8" koordinatına atış kaldırıldı (kullanıcı görmesin).
void assignCarriers({
  required List<VillagerEntity> villagers,
  required List<BuildingEntity> buildings,
  required List<ResourceBox> resourceBoxes,
  required List<HayEntity> hayEntities,
  required ResourceBundle stockpile,
  required AnchorSystem anchorSystem,
  double baleYieldMultiplier = 1.0,
  double time = 0,

  /// İptal anındaki sahne saatini verir. [time] eski/doğrudan çağrılar için
  /// fallback'tir; uzun taşıma sonunda drop animasyonunun atama anına değil
  /// gerçek bırakma anına bağlanması için sahne bu callback'i geçer.
  double Function()? timeNow,

  /// Yiyeceğin köy ambarına GİRİŞ kapısı. Verilmezse doğrudan eklenir.
  /// Sahne bunu hane karşılığına bağlar: küskün hanenin taşıdığı balya köy
  /// ambarına değil hanenin kendi ambarına iner (bkz. scene_house_stance).
  void Function(VillagerEntity carrier, int amount)? routeFood,
}) {
  final hasAnyAnchor =
      anchorSystem.warehousePoints.isNotEmpty ||
      anchorSystem.firepitPoints.isNotEmpty;
  if (!hasAnyAnchor) return; // teslim noktası yoksa hiç başlama
  // Hay balyası için depo şartı korunur — eski davranış (sadece warehouse'a).
  final hasWarehouse = anchorSystem.warehousePoints.isNotEmpty;

  // Değirmen(ler): balya öğütme bonusu artık global boolean değil — çalışan
  // her değirmen katkı sağlar ([kMillBonusMaxCount]'a kadar yığılır),
  // duraklatılan sayılmaz. Değirmencinin katkısı ayrı: baleYieldMultiplier
  // (bkz. scene_work._millerYieldMul) — bina makine, değirmenci bereket.
  final mills = [
    for (final b in buildings)
      if (b.type == BuildingType.mill && !b.userPaused) b,
  ];
  final int millBonus =
      kMillBaleBonus *
      (mills.length > kMillBonusMaxCount ? kMillBonusMaxCount : mills.length);

  for (final v in villagers) {
    // `idle` tek başına yeterli değildir: iş darbesi, mikro-eylem ve sohbet de
    // state'i idle tutabilir. Modelin ortak kapısı yarım sahneyi kesmemizi ve
    // o sahnenin bir sonraki tick'te taşıma state'ini ezmesini engeller.
    if (!v.canAcceptCarryTask) continue;
    // Çocuklar çalışmaz — yalnızca oyun oynar.
    if (v.isChild) continue;
    // Çiftçiler odun/maden kutusu taşımaz — sadece saman/balya taşır.
    final isFarmer = v.type == VillagerType.farmer;

    if (!isFarmer) {
      ResourceBox? nearestBox;
      double bestDist = double.infinity;
      for (final b in resourceBoxes) {
        if (b.isBeingCarried || b.isDelivered) continue;
        final dx = b.gridX - v.gridX;
        final dy = b.gridY - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestDist && d < 10 * 10) {
          bestDist = d;
          nearestBox = b;
        }
      }
      if (nearestBox != null) {
        final claim = anchorSystem.claimDeliverySlot(
          nearestBox.gridX,
          nearestBox.gridY,
          v,
        );
        if (claim == null) continue; // tüm slot'lar dolu, bir dahaki tick'te
        final (point, slot) = claim;
        final box = nearestBox;
        final accepted = v.assignCarryTask(
          box,
          box.gridX,
          box.gridY,
          slot.col,
          slot.row,
          onDelivered: () {
            point.release(slot, v);
            box.isBeingCarried = false;
            box.isDelivered = true;
            resourceBoxes.remove(box);
            switch (box.type) {
              // Birikim kanalı: odun/taş taşıyan bu köylü marangozluk/taş
              // ustalığında deneyim kazanır (eşiği geçen zanaatı köye kazandırır,
              // bkz. _tickCraftDiscovery).
              case ResourceBoxType.woodChunk:
                stockpile.wood++;
                v.gainMastery(Craft.carpentry, 1.0);
              case ResourceBoxType.stoneBox:
                stockpile.stone++;
                v.gainMastery(Craft.masonry, 1.0);
              case ResourceBoxType.ironBox:
                stockpile.iron++;
              case ResourceBoxType.coalBox:
                stockpile.coal++;
              case ResourceBoxType.foodBasket:
                stockpile.food += box.amount;
            }
          },
          onCancelled: (wasPickedUp) {
            point.release(slot, v);
            box.isBeingCarried = false;
            // Pickup öncesi kesintide kutu zaten yerde doğru noktadadır.
            // Eline aldıktan sonra kesildiyse ayağına düşür; eski pickup
            // noktasına ışınlanıp uzakta yeniden belirmesin.
            if (wasPickedUp) {
              ResourcePlacement.placeBox(
                box,
                v.gridX,
                v.gridY,
                resourceBoxes,
                timeNow?.call() ?? time,
              );
            }
          },
        );
        if (!accepted) {
          // Reddedilen atama hiç başlamadı; onCancelled yalnız sonradan kesilen
          // kabul edilmiş görevlerindir. Ön claim'i burada geri al.
          point.release(slot, v);
          continue;
        }
        box.isBeingCarried = true;
        continue;
      }
    }

    // Balya (bale) varsa depoya taşı — pile'lar tarlada kalır.
    // Eski koşul: warehouse şart. Anchor'da depo varsa devam, yoksa atla.
    if (hasWarehouse) {
      HayEntity? nearestBale;
      double bestBaleDist = double.infinity;
      for (final h in hayEntities) {
        if (!h.isBale || h.isBeingCarried || h.isDelivered) continue;
        final dx = h.gridX - v.gridX;
        final dy = h.gridY - v.gridY;
        final d = dx * dx + dy * dy;
        if (d < bestBaleDist && d < 12 * 12) {
          bestBaleDist = d;
          nearestBale = h;
        }
      }
      if (nearestBale != null) {
        final claim = anchorSystem.claimWarehouseDeliverySlot(
          nearestBale.gridX,
          nearestBale.gridY,
          v,
        );
        if (claim == null) continue;
        final (point, slot) = claim;
        final bale = nearestBale;
        final accepted = v.assignCarryTask(
          bale,
          bale.gridX,
          bale.gridY,
          slot.col,
          slot.row,
          onDelivered: () {
            point.release(slot, v);
            bale.isBeingCarried = false;
            bale.isDelivered = true;
            hayEntities.remove(bale);
            // 1 balya = kHayPilesPerBale hasat. Değirmen başına +kMillBaleBonus
            // yem (kMillBonusMaxCount'a kadar yığılır). Mevsim/rejim/değirmenci
            // çarpanları baleYieldMultiplier'da toplanır.
            final base = kBaleFoodBase + millBonus;
            final yield_ = (base * baleYieldMultiplier).round();
            if (routeFood != null) {
              routeFood(v, yield_);
            } else {
              stockpile.food += yield_;
            }
            // En yakın değirmeni öğütmeye geçir → görünür duman + panel doğruluğu.
            if (mills.isNotEmpty) {
              var nearest = mills.first;
              var bd = double.infinity;
              for (final m in mills) {
                final dx = m.col - slot.col;
                final dy = m.row - slot.row;
                final d = dx * dx + dy * dy;
                if (d < bd) {
                  bd = d;
                  nearest = m;
                }
              }
              nearest.grindPulse = kMillGrindSeconds;
            }
          },
          onCancelled: (wasPickedUp) {
            point.release(slot, v);
            bale.isBeingCarried = false;
            if (wasPickedUp) {
              ResourcePlacement.placeHay(
                bale,
                v.gridX,
                v.gridY,
                hayEntities,
                timeNow?.call() ?? time,
              );
            }
          },
        );
        if (!accepted) {
          point.release(slot, v);
          continue;
        }
        bale.isBeingCarried = true;
      }
    }
  }
}
