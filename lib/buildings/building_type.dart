import '../core/resources.dart';

// ── Gece ışık sistemi ──────────────────────────────────────────────────────

enum LightKind { window, lantern }

/// Sprite üzerindeki tek bir ışık noktası.
/// [nx],[ny] = 0..1 aralığında sprite koordinatı (sol-üst = 0,0)
class BuildingLight {
  final double   nx;
  final double   ny;
  final LightKind kind;
  const BuildingLight(this.nx, this.ny, this.kind);
}

/// Her bina türü için ışık noktaları listesi.
/// Sadece pencere / fener içeren binalar dahil (market, well hariç).
const Map<BuildingType, List<BuildingLight>> kBuildingLights = {
  BuildingType.woodenHouse: [
    BuildingLight(0.28, 0.42, LightKind.window),
    BuildingLight(0.38, 0.76, LightKind.window),
    BuildingLight(0.73, 0.70, LightKind.window),
    BuildingLight(0.15, 0.67, LightKind.lantern),
  ],
  BuildingType.mill: [
    BuildingLight(0.65, 0.51, LightKind.window),
  ],
  BuildingType.stable: [
    BuildingLight(0.87, 0.63, LightKind.window),
  ],
  BuildingType.market: [
    BuildingLight(0.64, 0.68, LightKind.lantern),
  ],
  BuildingType.townhall: [
    BuildingLight(0.40, 0.32, LightKind.window),
    BuildingLight(0.49, 0.51, LightKind.window),
    BuildingLight(0.30, 0.45, LightKind.window),
    BuildingLight(0.83, 0.47, LightKind.window),
    BuildingLight(0.80, 0.76, LightKind.window),
    BuildingLight(0.61, 0.76, LightKind.window),
    BuildingLight(0.18, 0.59, LightKind.window),
    BuildingLight(0.18, 0.71, LightKind.lantern),
    BuildingLight(0.44, 0.79, LightKind.lantern),
  ],
  BuildingType.tavern: [
    BuildingLight(0.28, 0.47, LightKind.window),
    BuildingLight(0.44, 0.74, LightKind.window),
    BuildingLight(0.72, 0.69, LightKind.window),
    BuildingLight(0.71, 0.49, LightKind.window),
    BuildingLight(0.19, 0.62, LightKind.lantern),
  ],
  BuildingType.fisherCabin: [
    BuildingLight(0.08, 0.62, LightKind.lantern),
    BuildingLight(0.54, 0.65, LightKind.window),
  ],
  BuildingType.warehouse: [
    BuildingLight(0.51, 0.74, LightKind.window),
    BuildingLight(0.30, 0.51, LightKind.window),
    BuildingLight(0.22, 0.48, LightKind.window),
  ],
  BuildingType.firepit: [
    BuildingLight(0.33, 0.52, LightKind.lantern),
    BuildingLight(0.49, 0.64, LightKind.lantern),
    BuildingLight(0.62, 0.51, LightKind.lantern),
    BuildingLight(0.48, 0.42, LightKind.lantern),
    BuildingLight(0.48, 0.54, LightKind.lantern),
  ],
  BuildingType.mineBuilding: [
    BuildingLight(0.57, 0.62, LightKind.lantern),
  ],
  BuildingType.lamppost: [
    BuildingLight(0.64, 0.48, LightKind.lantern),
    BuildingLight(0.55, 0.47, LightKind.lantern),
    BuildingLight(0.55, 0.57, LightKind.lantern),
    BuildingLight(0.63, 0.56, LightKind.lantern),
  ],
  BuildingType.floristCottage: [
    BuildingLight(0.75, 0.62, LightKind.window),
    BuildingLight(0.20, 0.57, LightKind.window),
    BuildingLight(0.40, 0.63, LightKind.window),
  ],
  BuildingType.chickenCoop: [
    BuildingLight(0.34, 0.55, LightKind.window),
    BuildingLight(0.53, 0.63, LightKind.lantern),
  ],
};

// ─── Baca / duman noktaları ────────────────────────────────────────────────

/// Sprite üzerinde duman çıkış noktası. [nx],[ny] = 0..1 normalize.
/// [density] partikül sayısı çarpanı (firepit büyük, ev küçük).
/// [rate] yayılma hızı (firepit hızlı, mill yavaş).
class BuildingChimney {
  final double nx;
  final double ny;
  final double density;
  final double rate;
  const BuildingChimney(this.nx, this.ny, {this.density = 1.0, this.rate = 1.0});
}

/// Her bina için 0..N baca/duman çıkış noktası.
/// Boş veya tanımsızsa duman çizilmez.
const Map<BuildingType, List<BuildingChimney>> kBuildingChimneys = {
  BuildingType.woodenHouse: [
    BuildingChimney(0.65, 0.07),
  ],
  BuildingType.mill: [
    BuildingChimney(0.51, 0.05),
  ],
  BuildingType.townhall: [
    BuildingChimney(0.57, 0.09),
  ],
  BuildingType.tavern: [
    BuildingChimney(0.60, 0.03),
  ],
  BuildingType.fisherCabin: [
    BuildingChimney(0.63, 0.04),
  ],
  BuildingType.firepit: [
    BuildingChimney(0.48, 0.20, density: 2.00, rate: 1.70),
  ],
  BuildingType.floristCottage: [
    BuildingChimney(0.79, 0.16),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────

enum BuildingType {
  placeholder,  // kullanılmaz, Dart boş enum'a izin vermediği için
  woodenHouse,  // 2x2 — minihouse.png
  mill,         // 2x2 — mill.png
  stable,       // 3x2 — stable.png
  well,         // 1x1 — well.png
  market,       // 3x2 — market.png
  townhall,     // 4x3 — townhall.png
  tavern,       // 2x2 — tavern.png
  fisherCabin,  // 2x2 — fishercabin.png
  warehouse,    // 3x2 — warehouse.png
  firepit,      // 1x1 — firepit.png
  lumberCamp,   // 2x2 — lumberjack.png  (ağaç keser + diker)
  mineBuilding, // 2x2 — mine.png        (maden ocağı)
  barn,         // 3x2 — geçici stable.png (TODO: dedicated barn.png)
  lamppost,     // 1x1 — procedurel çizim (asset yok). Gece ışık kaynağı.
  floristCottage, // 2x2 — floristcottage.png. Çiçekçi kulübesi: çevreye çiçek spawn + Florist NPC sular.
  chickenCoop,    // 2x2 — chickencoop.png. Tavuk kümesi: 3-4 tavuk spawn + periyodik yumurta (food).
}

class BuildingMeta {
  final int cols;
  final int rows;
  final String label;
  final ResourceCost cost;
  final double groundY;
  final double groundXCenter;
  final double spriteScale;
  /// true → NPC bu binanın footprint tile'larından geçebilir (firepit, well,
  /// lamppost = etrafında durulan dekor; woodenHouse = içine girilen ev).
  /// false → katı bina, pathfinder + wander engel sayar.
  final bool walkable;
  /// Bina merkezinden tile cinsinden etki yarıçapı (Öklid mesafesi).
  /// 0 → etkisiz. Çiçek bahçesi gibi dekoratif etki, well için su erişimi,
  /// tavern için moral menzili, firepit için ısı/ışık menzili vs.
  /// Sistemler bu alanı bina-özel yorumlar (place hook'unda çiçek dağıtma,
  /// civic effect bir radius içindeki villager'a uygulama, vb.).
  final double effectRadius;

  const BuildingMeta({
    required this.cols,
    required this.rows,
    required this.label,
    required this.cost,
    // groundY 1.0 (sprite alt kenarı = footprint güney köşesi) çoğu PNG'de
    // floating hissi yaratıyor: pixel art assetlerin altında genelde 2-4 px
    // şeffaf padding olur. 1.04 → sprite'ı %4 yere doğru iter, padding'i
    // absorbe eder. Spesifik bir bina daha çok / az iniyorsa per-bina override.
    this.groundY = 1.04,
    this.groundXCenter = 0.5,
    this.spriteScale = 1.0,
    this.walkable = false,
    this.effectRadius = 0.0,
  });
}

// ─── Bina Maliyetleri ────────────────────────────────────────────────────────
// Tasarım notları:
// • Ateş yeri ücretsiz — başlangıç noktası, kaynak üretimini başlatır.
// • Erken oyun (ev, kulübeler): ağırlıklı odun, az taş.
// • Orta oyun (değirmen, ahır, depo, taverna, fisher): odun + taş.
// • İleri oyun (pazar, belediye): demir + altın gerektirir.
// • Altın yalnız pazar üzerinden gelir (gelecek özellik); şimdilik yalnızca
//   en üst kademe binalarda gerekli.

const Map<BuildingType, BuildingMeta> kBuildingMeta = {
  BuildingType.firepit: BuildingMeta(
    cols: 1,
    rows: 1,
    label: 'Ateş Yeri',
    cost: ResourceCost.empty, // ücretsiz başlangıç
    // Asset 1179×1136 → 1134×1064 trimlendi; anchor pixel sabit, oran güncel.
    groundXCenter: 0.5066,
    groundY: 1.069,
    spriteScale: 0.62,
    walkable: true, // etrafında toplanılan dekor
    effectRadius: 4.0, // ısı + ışık menzili, gece toplanma noktası
  ),
  BuildingType.lumberCamp: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Oduncu Kulübesi',
    cost: ResourceCost(wood: 12),
    groundXCenter: 0.50,
    spriteScale: 1.0,
  ),
  BuildingType.fisherCabin: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Balıkçı Kulübesi',
    cost: ResourceCost(wood: 14),
    groundXCenter: 0.50,
    spriteScale: 1.0,
  ),
  BuildingType.well: BuildingMeta(
    cols: 1,
    rows: 1,
    label: 'Kuyu',
    cost: ResourceCost(wood: 4, stone: 8),
    groundXCenter: 0.5,
    walkable: true, // su alma noktası — etrafından dolaşılmaz, yanına gelinir
    effectRadius: 5.0, // su erişimi: yakın evler/farmlar otomatik sulanır
  ),
  BuildingType.lamppost: BuildingMeta(
    cols: 1,
    rows: 1,
    label: 'Sokak Feneri',
    cost: ResourceCost(wood: 2, iron: 1),
    groundXCenter: 0.50,
    walkable: true, // 1x1 dekor
    effectRadius: 3.5, // gece ışık menzili
  ),
  BuildingType.floristCottage: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Çiçekçi Kulübesi',
    cost: ResourceCost(wood: 16, stone: 4),
    groundXCenter: 0.50,
    spriteScale: 1.0,
    effectRadius: 4.5, // çiçekçi bu menzilde dolaşır + çevreye çiçek serpilir
  ),
  BuildingType.chickenCoop: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Tavuk Kümesi',
    cost: ResourceCost(wood: 14, stone: 2),
    groundXCenter: 0.50,
    spriteScale: 1.0,
    effectRadius: 3.5, // tavukların dolaştığı menzil
  ),
  BuildingType.woodenHouse: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Köy Evi',
    cost: ResourceCost(wood: 18, stone: 4),
    groundXCenter: 0.5,
    walkable: true, // sakinler içine girip uyur
  ),
  BuildingType.mineBuilding: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Maden Ocağı',
    cost: ResourceCost(wood: 16, stone: 8),
    groundXCenter: 0.50,
    spriteScale: 1.0,
  ),
  BuildingType.tavern: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Taverna',
    cost: ResourceCost(wood: 22, stone: 10, food: 6),
    groundXCenter: 0.51,
    effectRadius: 6.0, // moral menzili
  ),
  BuildingType.mill: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Değirmen',
    cost: ResourceCost(wood: 24, stone: 12),
    groundXCenter: 0.49,
    spriteScale: 1.551,
  ),
  BuildingType.warehouse: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Depo',
    cost: ResourceCost(wood: 28, stone: 16),
    groundXCenter: 0.50,
    spriteScale: 1.0,
  ),
  BuildingType.stable: BuildingMeta(
    cols: 3,
    rows: 2,
    label: 'Ahır (Yük)',
    cost: ResourceCost(wood: 32, stone: 10),
    groundXCenter: 0.6,
  ),
  BuildingType.barn: BuildingMeta(
    cols: 3,
    rows: 2,
    label: 'Ağıl',
    cost: ResourceCost(wood: 26, stone: 6),
    groundXCenter: 0.6,
  ),
  BuildingType.market: BuildingMeta(
    cols: 3,
    rows: 2,
    label: 'Pazar',
    cost: ResourceCost(wood: 30, stone: 22, iron: 4),
    groundXCenter: 0.514,
    spriteScale: 1.15,
  ),
  BuildingType.townhall: BuildingMeta(
    cols: 4,
    rows: 3,
    label: 'Belediye',
    cost: ResourceCost(wood: 45, stone: 40, iron: 12, gold: 25),
    groundXCenter: 0.575,
    spriteScale: 1.096,
  ),
};
