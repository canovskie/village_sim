import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../core/constants.dart';
import '../core/resources.dart';

/// Köy çapında, binalardan türetilen anlık istatistikler.
/// Hem oyun mantığı (kapasite sınırı, taşıyıcı hızı) hem de detay paneli
/// (moral, kapasite çubuğu) bunları kullanır.
class VillageStats {
  /// Her malzeme kaynağının üst sınırı (depo sayısına bağlı).
  final int stockCapacity;

  /// Köy morali 0..1 (kuyu + taverna). 0.5 = nötr.
  final double morale;

  /// Nüfus büyüme hız çarpanı (moralden türer, ≥1).
  final double growthMultiplier;

  /// Taşıyıcı NPC hız çarpanı (ahır sayısına bağlı, ≥1).
  final double carrierSpeedMultiplier;

  /// Köydeki kuyu sayısı — evlerin su deposunu doldurur.
  final int wellCount;

  const VillageStats({
    required this.stockCapacity,
    required this.morale,
    required this.growthMultiplier,
    required this.carrierSpeedMultiplier,
    this.wellCount = 0,
  });
}

/// Köy çapı değerlerini binalardan türetir. Yan etkisizdir; her tick ve
/// panel açılışında güvenle çağrılabilir.
VillageStats computeVillageStats(List<BuildingEntity> buildings,
    {double starvation = 0.0}) {
  int capacity = kBaseStockCapacity;
  double moraleBonus = 0.0;
  double carrierBonus = 0.0;
  int wellCount = 0;

  // Susuz evler köyü mutsuz eder — dolu olan evlerin ortalama su seviyesi.
  double waterSum = 0.0;
  int occupiedHouses = 0;

  for (final b in buildings) {
    final f = b.fn;
    if (f == null) continue;
    if (b.type == BuildingType.well) wellCount++;
    switch (f.role) {
      case BuildingRole.storage:
        capacity += f.storageCapacity;
      case BuildingRole.housing:
        if (b.occupants > 0) {
          waterSum += b.waterLevel;
          occupiedHouses++;
        }
      case BuildingRole.civic:
        switch (f.civicEffect) {
          case CivicEffect.morale:
            moraleBonus += f.civicValue;
          case CivicEffect.carrierSpeed:
            carrierBonus += f.civicValue;
          case CivicEffect.populationGrowth:
          case CivicEffect.none:
            break;
        }
      default:
        break;
    }
  }

  moraleBonus = moraleBonus.clamp(0.0, 0.5);
  carrierBonus = carrierBonus.clamp(0.0, 0.8);

  // Su açığı cezası: dolu evlerin ortalaması düşükse moral ve büyüme düşer.
  final avgWater = occupiedHouses > 0 ? waterSum / occupiedHouses : 1.0;
  final waterPenalty =
      ((1.0 - avgWater) * kWaterMoralePenalty).clamp(0.0, kWaterMoralePenalty);

  // Açlık cezası: yiyecek tükenince köy mutsuzlaşır (su cezasına paralel).
  final starvePenalty =
      (starvation.clamp(0.0, 1.0) * kStarvationMoralePenalty);

  final penalty = waterPenalty + starvePenalty;
  return VillageStats(
    stockCapacity: capacity,
    morale: (0.5 + moraleBonus - penalty).clamp(0.0, 1.0),
    growthMultiplier: (1.0 + moraleBonus - penalty).clamp(0.5, 2.0),
    carrierSpeedMultiplier: 1.0 + carrierBonus,
    wellCount: wellCount,
  );
}

/// Tüm bina işlevlerini bir tick ilerletir ve güncel [VillageStats] döner.
///
/// Yan etkiler:
///  • Konut: su deposu sakinlerle tüketilir, kuyularla doldurulur.
///  • Pazar: periyodik pasif altın geliri.
///  • Belediye: yiyecek harcayıp [onSpawnVillager] ile yeni köylü ister.
///  • Stok malzeme kaynakları kapasiteye göre kırpılır.
///
/// [freeHousingSlots] büyümenin tetiklenebilmesi için boş ev kapasitesi.
/// [onSpawnVillager] bir köylü doğurmak gerektiğinde büyüten binayla çağrılır.
VillageStats updateBuildings({
  required double dt,
  required List<BuildingEntity> buildings,
  required ResourceBundle stockpile,
  required int freeHousingSlots,
  required void Function(BuildingEntity townhall) onSpawnVillager,
  bool enforceCapacity = true,
  double starvation = 0.0,
}) {
  final stats = computeVillageStats(buildings, starvation: starvation);
  int remainingHousing = freeHousingSlots;

  for (final b in buildings) {
    final f = b.fn;
    if (f == null) continue;

    switch (f.role) {
      case BuildingRole.housing:
        _tickHousing(dt, b, stats.wellCount);
      case BuildingRole.trade:
        _tickMarket(dt, b, f, stockpile);
      case BuildingRole.civic:
        if (f.civicEffect == CivicEffect.populationGrowth) {
          remainingHousing = _tickGrowth(
            dt, b, f, stockpile, stats, remainingHousing, onSpawnVillager,
          );
        }
      default:
        break;
    }
  }

  if (enforceCapacity) _clampStockpile(stockpile, stats.stockCapacity);
  return stats;
}

// ─── Konut su deposu ─────────────────────────────────────────────────────────

/// Evin su deposunu bir tick ilerletir: sakinler tüketir, kuyular doldurur.
/// Kuyu yoksa depo boşalır → moral düşer (bkz. [computeVillageStats]).
void _tickHousing(double dt, BuildingEntity b, int wellCount) {
  final drain  = kHouseWaterDrainPerOccupant * b.occupants * dt;
  final refill = kWellWaterRefill * wellCount * dt;
  b.waterLevel = (b.waterLevel + refill - drain).clamp(0.0, 1.0);
}

// ─── Ticaret (pazar) ─────────────────────────────────────────────────────────

void _tickMarket(
  double dt,
  BuildingEntity b,
  BuildingFunction f,
  ResourceBundle stockpile,
) {
  b.incomeTimer += dt;
  if (b.incomeTimer >= kMarketIncomeInterval) {
    b.incomeTimer = 0.0;
    stockpile.gold += f.civicValue.round();
    b.isActive = true;
  }
}

/// Pazarda manuel satış: bir parti kaynağı altına çevirir. Panel butonu çağırır.
/// Yeterli stok yoksa false döner.
bool sellAtMarket(ResourceBundle stockpile, ResourceKind kind) {
  final rate = kMarketSellRates[kind];
  if (rate == null) return false;
  final (batch, gold) = rate;
  if (stockpile.get(kind) < batch) return false;
  stockpile.add(kind, -batch);
  stockpile.gold += gold;
  return true;
}

// ─── Nüfus büyümesi (belediye) ───────────────────────────────────────────────

int _tickGrowth(
  double dt,
  BuildingEntity b,
  BuildingFunction f,
  ResourceBundle stockpile,
  VillageStats stats,
  int remainingHousing,
  void Function(BuildingEntity) onSpawnVillager,
) {
  final canGrow = remainingHousing > 0 &&
      stockpile.food >= kPopulationGrowthFoodFloor;

  if (!canGrow) {
    // İhtiyaç karşılanmıyorsa ilerleme yavaşça gerilesin.
    b.growthProgress = (b.growthProgress - dt * 0.05).clamp(0.0, 1.0);
    return remainingHousing;
  }

  // Süre: temel saniye / moral çarpanı → mutlu köy daha hızlı büyür.
  final growthTime = f.civicValue / stats.growthMultiplier;
  b.growthProgress += dt / growthTime;

  if (b.growthProgress >= 1.0) {
    b.growthProgress = 0.0;
    if (stockpile.food >= kPopulationGrowthFoodCost) {
      stockpile.food -= kPopulationGrowthFoodCost;
      onSpawnVillager(b);
      remainingHousing -= 1;
    }
  }
  return remainingHousing;
}

// ─── Kapasite kırpma ─────────────────────────────────────────────────────────

/// Malzeme kaynaklarını kapasiteye kırpar (altın hariç — para sınırsız).
void _clampStockpile(ResourceBundle s, int cap) {
  if (s.wood > cap) s.wood = cap;
  if (s.stone > cap) s.stone = cap;
  if (s.iron > cap) s.iron = cap;
  if (s.coal > cap) s.coal = cap;
  if (s.food > cap) s.food = cap;
}
