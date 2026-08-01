import 'dart:math' as math;

import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../core/constants.dart';
import '../core/resources.dart';

/// Köy çapında, binalardan türetilen anlık istatistikler.
/// Hem oyun mantığı (kapasite sınırı, taşıyıcı hızı, amenite morali) hem de
/// detay paneli (kapasite çubuğu) bunları kullanır.
class VillageStats {
  /// Her malzeme kaynağının üst sınırı (depo sayısına bağlı).
  final int stockCapacity;

  /// Köy morali 0..1 — PASİF GÖSTERGE. Köylülerin bireysel moral ortalaması
  /// (bkz. villager_morale) sahneden buraya geçirilir. 0.5 = nötr.
  final double morale;

  /// Taşıyıcı NPC hız çarpanı (ahır/han sayısına bağlı, ≥1).
  final double carrierSpeedMultiplier;

  /// Köydeki kuyu sayısı — evlerin su deposunu doldurur.
  final int wellCount;

  /// Civic binaların köylü moraline GERÇEK katkısı (0..[kAmenityMoraleCap]).
  /// `evaluateVillagerMorale`'in bina terimi tam olarak budur — panelde
  /// gösterilen "amenite morali" ile simülasyonun okuduğu değer aynı sayıdır.
  final double amenityMorale;

  const VillageStats({
    required this.stockCapacity,
    required this.morale,
    required this.carrierSpeedMultiplier,
    this.wellCount = 0,
    this.amenityMorale = 0.0,
  });
}

// ─── Amenite morali ──────────────────────────────────────────────────────────

/// Amenite moralinin tavanı — bütün civic mahalle kurulsa bile aşılamaz.
const double kAmenityMoraleCap = 0.20;

/// Doyum ölçeği: toplam ağırlık bu değere yaklaştıkça tavanın ~%63'ü alınır.
/// Küçük tutulur ki İLK taverna/kuyu hissedilsin (tek başına ~+%9).
const double kAmenityMoraleScale = 0.30;

/// Bir binanın moral AĞIRLIĞI — yalnız civic + [CivicEffect.morale] binalar
/// taşır, değeri `BuildingFunction.civicValue`'dur. Başka bir yerde ikinci bir
/// liste tutulmaz: yeni bir moral binası eklemek için tabloya değer yazmak yeter.
double moraleWeightOf(BuildingType t) {
  final f = kBuildingFunctions[t];
  if (f == null || f.role != BuildingRole.civic) return 0.0;
  return f.civicEffect == CivicEffect.morale ? f.civicValue : 0.0;
}

/// Tür→adet sayımından amenite moralini üretir. Aynı türün İKİNCİSİ ve sonrası
/// ¼ ağırlıkla sayılır (ikinci taverna işe yarar ama ilki kadar değil), toplam
/// ağırlık yumuşak doyuma sokulur: tek bina bile hissedilir, on bina tavanı
/// patlatmaz. Saf fonksiyon — testten doğrudan çağrılabilir.
double amenityMoraleFrom(Map<BuildingType, int> counts) {
  double weight = 0.0;
  for (final e in counts.entries) {
    final w = moraleWeightOf(e.key);
    if (w <= 0) continue;
    weight += w * (1 + 0.25 * (e.value - 1));
  }
  if (weight <= 0) return 0.0;
  return kAmenityMoraleCap * (1 - math.exp(-weight / kAmenityMoraleScale));
}

// ─── Pazar geliri ────────────────────────────────────────────────────────────

/// Pazarın "fazla" saydığı taban: bu miktarın altındaki stok köyün kendi
/// ihtiyacıdır, satılığa çıkmaz.
const int kMarketSurplusFloor = 40;

/// Taban üstü her bu kadar birim fazla → +1 altın.
const int kMarketSurplusPerGold = 70;

/// Tek bir tahsilatın tavanı (pazar sayısı ne olursa olsun).
const int kMarketMaxIncome = 4;

/// Pazarın bir tahsilatta getireceği TABAN altın — köyün elindeki fazlaya
/// bağlıdır. Tezgâhta satacak bir şey yoksa 0 döner (pazar boş durur).
/// Altın ve saz sayılmaz (biri para, diğeri yataklık — pazara çıkmaz).
int marketBaseIncome(ResourceBundle s) {
  var surplus = 0;
  for (final k in ResourceKind.values) {
    if (k == ResourceKind.gold || k == ResourceKind.reed) continue;
    final over = s.get(k) - kMarketSurplusFloor;
    if (over > 0) surplus += over;
  }
  if (surplus <= 0) return 0;
  return (1 + surplus ~/ kMarketSurplusPerGold).clamp(1, kMarketMaxIncome);
}

/// Köyün kaçıncı pazarı ne kadar pay alır — ikinci pazar aynı fazlayı ikinci
/// kez satamaz. 1, ½, ⅓ …
double marketShare(int rank) => 1.0 / (1 + rank);

// ─── Köy istatistikleri ──────────────────────────────────────────────────────

/// Köy çapı değerlerini binalardan türetir (kapasite, taşıyıcı hızı, kuyu,
/// amenite morali). Köy morali burada HESAPLANMAZ — sahneden gelen [morale]
/// birikim değeri olduğu gibi taşınır (pasif gösterge). Yan etkisizdir.
VillageStats computeVillageStats(List<BuildingEntity> buildings,
    {double morale = 0.5}) {
  int capacity = kBaseStockCapacity;
  double carrierBonus = 0.0;
  int wellCount = 0;
  final amenityCounts = <BuildingType, int>{};

  for (final b in buildings) {
    final f = b.fn;
    if (f == null) continue;
    // Şadırvan da bir su kaynağı — kuyu gibi yakın evleri/ekinleri besler.
    if (b.type == BuildingType.well || b.type == BuildingType.fountain) {
      wellCount++;
    }
    switch (f.role) {
      case BuildingRole.storage:
        capacity += f.storageCapacity;
      case BuildingRole.civic:
        switch (f.civicEffect) {
          case CivicEffect.carrierSpeed:
            carrierBonus += f.civicValue;
          case CivicEffect.morale:
            amenityCounts[b.type] = (amenityCounts[b.type] ?? 0) + 1;
          case CivicEffect.none:
            break;
        }
      default:
        break;
    }
  }

  carrierBonus = carrierBonus.clamp(0.0, 0.8);

  return VillageStats(
    stockCapacity: capacity,
    morale: morale.clamp(0.0, 1.0),
    carrierSpeedMultiplier: 1.0 + carrierBonus,
    wellCount: wellCount,
    amenityMorale: amenityMoraleFrom(amenityCounts),
  );
}

/// Tüm bina işlevlerini bir tick ilerletir ve güncel [VillageStats] döner.
///
/// Yan etkiler:
///  • Konut: su deposu sakinlerle tüketilir, kuyularla doldurulur.
///  • Pazar: fazlaya bağlı periyodik altın geliri.
///  • Stok malzeme kaynakları kapasiteye göre kırpılır.
///
/// Nüfus büyümesi burada DEĞİL: doğal doğum (couple → fertilityDays →
/// scene._tickReproduction) devraldı; belediye yalnız yönetişimin koltuğu.
VillageStats updateBuildings({
  required double dt,
  required List<BuildingEntity> buildings,
  required ResourceBundle stockpile,
  bool enforceCapacity = true,
  double morale = 0.5,
}) {
  final stats = computeVillageStats(buildings, morale: morale);
  var marketRank = 0;

  for (final b in buildings) {
    final f = b.fn;
    if (f == null) continue;

    switch (f.role) {
      case BuildingRole.housing:
        _tickHousing(dt, b, stats.wellCount);
      case BuildingRole.trade:
        _tickMarket(dt, b, stockpile, marketRank++);
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

/// Pazarın pasif geliri KOŞULSUZ değildir: köyün taban üstü fazlası ne kadarsa
/// tezgâh o kadar döner. [rank] köyün kaçıncı pazarı olduğudur — ikinci pazar
/// aynı fazlayı ikinci kez satamaz, payı yarıya iner.
void _tickMarket(
  double dt,
  BuildingEntity b,
  ResourceBundle stockpile,
  int rank,
) {
  b.incomeTimer += dt;
  if (b.incomeTimer < kMarketIncomeInterval) return;
  b.incomeTimer = 0.0;
  final gain = (marketBaseIncome(stockpile) * marketShare(rank)).round();
  b.isActive = gain > 0; // fazla yoksa tezgâh boş durur (panel + duman)
  if (gain > 0) stockpile.gold += gain;
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

// ─── Kapasite kırpma ─────────────────────────────────────────────────────────

/// Malzeme kaynaklarını kapasiteye kırpar (altın hariç — para sınırsız).
void _clampStockpile(ResourceBundle s, int cap) {
  if (s.wood > cap) s.wood = cap;
  if (s.stone > cap) s.stone = cap;
  if (s.iron > cap) s.iron = cap;
  if (s.coal > cap) s.coal = cap;
  if (s.food > cap) s.food = cap;
}
