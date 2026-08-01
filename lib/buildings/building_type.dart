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
  BuildingType.stoneHouseBlue: [
    BuildingLight(0.36, 0.74, LightKind.lantern),
    BuildingLight(0.13, 0.68, LightKind.lantern),
    BuildingLight(0.67, 0.42, LightKind.window),
    BuildingLight(0.61, 0.72, LightKind.window),
    BuildingLight(0.82, 0.64, LightKind.window),
    BuildingLight(0.26, 0.42, LightKind.window),
  ],
  BuildingType.stoneHouseGreen: [
    BuildingLight(0.70, 0.41, LightKind.window),
    BuildingLight(0.82, 0.65, LightKind.window),
    BuildingLight(0.66, 0.70, LightKind.window),
    BuildingLight(0.46, 0.71, LightKind.window),
    BuildingLight(0.28, 0.38, LightKind.window),
    BuildingLight(0.38, 0.73, LightKind.lantern),
    BuildingLight(0.14, 0.65, LightKind.lantern),
  ],
  BuildingType.manor: [
    BuildingLight(0.42, 0.67, LightKind.lantern),
    BuildingLight(0.25, 0.63, LightKind.lantern),
    BuildingLight(0.65, 0.68, LightKind.window),
    BuildingLight(0.73, 0.71, LightKind.window),
    BuildingLight(0.53, 0.67, LightKind.window),
    BuildingLight(0.35, 0.38, LightKind.window),
    BuildingLight(0.22, 0.58, LightKind.window),
    BuildingLight(0.79, 0.41, LightKind.window),
  ],
  BuildingType.mill: [
    BuildingLight(0.65, 0.51, LightKind.window),
  ],
  BuildingType.stable: [
    BuildingLight(0.87, 0.63, LightKind.window),
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
  BuildingType.church: [
    BuildingLight(0.52, 0.71, LightKind.window),
    BuildingLight(0.60, 0.74, LightKind.window),
    BuildingLight(0.67, 0.77, LightKind.window),
    BuildingLight(0.36, 0.79, LightKind.lantern),
    BuildingLight(0.13, 0.68, LightKind.lantern),
  ],
  BuildingType.library: [
    BuildingLight(0.35, 0.43, LightKind.window),
    BuildingLight(0.70, 0.55, LightKind.window),
    BuildingLight(0.66, 0.33, LightKind.window),
    BuildingLight(0.79, 0.53, LightKind.window),
    BuildingLight(0.44, 0.72, LightKind.lantern),
  ],
  BuildingType.bathhouse: [
    BuildingLight(0.17, 0.62, LightKind.lantern),
    BuildingLight(0.50, 0.35, LightKind.window),
    BuildingLight(0.63, 0.33, LightKind.window),
    BuildingLight(0.56, 0.25, LightKind.window),
    BuildingLight(0.65, 0.20, LightKind.window),
    BuildingLight(0.43, 0.25, LightKind.window),
    BuildingLight(0.36, 0.33, LightKind.window),
    BuildingLight(0.29, 0.28, LightKind.window),
    BuildingLight(0.35, 0.20, LightKind.window),
    BuildingLight(0.71, 0.63, LightKind.window),
    BuildingLight(0.82, 0.57, LightKind.window),
    BuildingLight(0.49, 0.67, LightKind.window),
  ],
  BuildingType.monument: [
    BuildingLight(0.44, 0.06, LightKind.lantern),
  ],
  // Liman & Ziyaret — yaklaşık; ışık editörüyle oturt.
  BuildingType.caravanserai: [
    BuildingLight(0.30, 0.55, LightKind.lantern),
    BuildingLight(0.50, 0.50, LightKind.window),
    BuildingLight(0.68, 0.55, LightKind.window),
  ],
  BuildingType.shrine: [
    BuildingLight(0.50, 0.55, LightKind.window),
    BuildingLight(0.30, 0.66, LightKind.lantern),
  ],
  BuildingType.belltower: [
    BuildingLight(0.50, 0.30, LightKind.window),
    BuildingLight(0.50, 0.70, LightKind.lantern),
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
  BuildingType.stoneHouseBlue: [
    BuildingChimney(0.70, 0.02),
  ],
  BuildingType.stoneHouseGreen: [
    BuildingChimney(0.74, 0.04),
  ],
  BuildingType.manor: [
    BuildingChimney(0.67, 0.02),
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
  BuildingType.library: [
    BuildingChimney(0.76, 0.10),
  ],
  BuildingType.bathhouse: [
    BuildingChimney(0.75, 0.10),
    BuildingChimney(0.54, 0.47),
    BuildingChimney(0.66, 0.41),
    BuildingChimney(0.20, 0.33),
  ],
};

// ─── Su parlaması bölgeleri ─────────────────────────────────────────────────

/// Sprite üzerinde animasyonlu su ışıltısı uygulanacak bölge. [nx],[ny] = 0..1
/// normalize merkez; [hw],[hh] = sprite genişlik/yükseklik oranında yarı eksen
/// (iso 2:1 ellipse maskesi). [intensity] ışıltı çarpanı.
class BuildingWater {
  final double nx;
  final double ny;
  final double hw;
  final double hh;
  final double intensity;
  const BuildingWater(this.nx, this.ny, this.hw, this.hh, {this.intensity = 1.0});
}

/// Su yüzeyi olan binalar — şadırvan havuzu, hamam su kanalı. Yaklaşık konumlar;
/// PNG değişirse ayarlanır (ileride ışık editörü gibi bir araca taşınabilir).
const Map<BuildingType, List<BuildingWater>> kBuildingWater = {
  BuildingType.fountain: [
    // Sekizgen havuzun teal su yüzeyi (merkez sütunun çevresi).
    BuildingWater(0.50, 0.56, 0.30, 0.12),
  ],
  BuildingType.bathhouse: [
    // Sağ-ön taban boyunca uzanan su kanalı.
    BuildingWater(0.74, 0.82, 0.17, 0.05, intensity: 0.9),
  ],
};

// ─────────────────────────────────────────────────────────────────────────────

enum BuildingType {
  placeholder,  // kullanılmaz, Dart boş enum'a izin vermediği için
  tent,         // 1x1 — procedurel çadır (asset yok). İlkel kalıcı ucuz konut.
  woodenHouse,  // 2x2 — minihouse.png (samanlı kulübe — temel ev)
  stoneHouseBlue,  // 2x2 — stonehouse_blue.png (taş+ahşap konut, mavi çatı)
  stoneHouseGreen, // 2x2 — stonehouse_green.png (taş+ahşap konut, yeşil çatı)
  manor,        // 3x3 — manor.png (görkemli taş konak — en lüks konut)
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
  barn,         // 3x2 — barn.png (ağıl: ahşap-çerçeve byre + samanlık + saman)
  lamppost,     // 1x1 — procedurel çizim (asset yok). Gece ışık kaynağı.
  floristCottage, // 2x2 — floristcottage.png. Çiçekçi kulübesi: çevreye çiçek spawn + Florist NPC sular.
  chickenCoop,    // 2x2 — chickencoop.png. Tavuk kümesi: 3-4 tavuk spawn + periyodik yumurta (food).
  beehive,        // 1x1 — beehive.png. Arı kovanı: menzildeki çiçeğe göre bal üretir + ambient arılar.
  church,         // 2x2 — church.png. Kilise: civic moral + cenaze töreni mekânı + yanına mezarlık.
  // ─── Köy Meydanı & Kültür Mahallesi ──────────────────────────────────────────
  fountain,       // 2x2 — fountain.png. Şadırvan: su kaynağı (kuyu gibi) + gündüz toplanma + dekoratif.
  library,        // 2x2 — library.png. Kütüphane: kültür ameniteleri morali + kronik evi.
  bathhouse,      // 2x2 — bathhouse.png. Hamam: kültür morali + buhar bacası.
  monument,       // 1x1 — monument.png. Anıt: prestij/kültür morali + landmark (ileride kronik).
  // ─── Liman & Ziyaret Mahallesi ───────────────────────────────────────────────
  caravanserai,   // 3x3 — caravanserai.png. Han: taşıyıcı hızı + tüccar (civic/carrierSpeed).
  shrine,         // 2x2 — shrine.png. Türbe: kültür-amenite morali + ziyaret landmark.
  belltower,      // 1x1 — belltower.png. Çan Kulesi: kültür morali + çan sesi + dikey landmark.
}

/// İnşa paleti kategorisi — alt çubuğun kalabalık tek sırasını anlamlı gruplara
/// böler (sekme). [araziYol] binasızdır: içeriği yol + Tarla/Kes/Kaz modlarıdır
/// (scene_ui o sekmede farklı içerik gösterir).
enum BuildCategory { konut, uretim, ticaret, civic, altyapi, araziYol }

extension BuildCategoryInfo on BuildCategory {
  String get label => switch (this) {
        BuildCategory.konut => 'Konut',
        BuildCategory.uretim => 'Üretim',
        BuildCategory.ticaret => 'Ticaret',
        BuildCategory.civic => 'Civic',
        BuildCategory.altyapi => 'Altyapı',
        BuildCategory.araziYol => 'Arazi/Yol',
      };
  String get icon => switch (this) {
        BuildCategory.konut => '🏠',
        BuildCategory.uretim => '⚒',
        BuildCategory.ticaret => '🪙',
        BuildCategory.civic => '🔥',
        BuildCategory.altyapi => '💡',
        BuildCategory.araziYol => '🌾',
      };
}

/// Her binanın paleti kategorisi. araziYol burada yer almaz (bina değil).
const Map<BuildingType, BuildCategory> kBuildingCategory = {
  BuildingType.tent: BuildCategory.konut,
  BuildingType.woodenHouse: BuildCategory.konut,
  BuildingType.stoneHouseBlue: BuildCategory.konut,
  BuildingType.stoneHouseGreen: BuildCategory.konut,
  BuildingType.manor: BuildCategory.konut,
  BuildingType.mill: BuildCategory.uretim,
  BuildingType.lumberCamp: BuildCategory.uretim,
  BuildingType.mineBuilding: BuildCategory.uretim,
  BuildingType.fisherCabin: BuildCategory.uretim,
  BuildingType.barn: BuildCategory.uretim,
  BuildingType.chickenCoop: BuildCategory.uretim,
  BuildingType.floristCottage: BuildCategory.uretim,
  BuildingType.beehive: BuildCategory.uretim,
  BuildingType.market: BuildCategory.ticaret,
  BuildingType.warehouse: BuildCategory.ticaret,
  BuildingType.stable: BuildCategory.ticaret,
  BuildingType.firepit: BuildCategory.civic,
  BuildingType.townhall: BuildCategory.civic,
  BuildingType.church: BuildCategory.civic,
  BuildingType.tavern: BuildCategory.civic,
  BuildingType.fountain: BuildCategory.civic,
  BuildingType.library: BuildCategory.civic,
  BuildingType.bathhouse: BuildCategory.civic,
  BuildingType.monument: BuildCategory.civic,
  BuildingType.caravanserai: BuildCategory.ticaret,
  BuildingType.shrine: BuildCategory.civic,
  BuildingType.belltower: BuildCategory.civic,
  BuildingType.well: BuildCategory.altyapi,
  BuildingType.lamppost: BuildCategory.altyapi,
};

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
// • Altın pazardan gelir: pasif gelir (bkz. _tickMarket) + manuel satış
//   (bkz. sellAtMarket, panel butonu scene_ui). En üst kademe binalarda gerekli.

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
    groundY: 1.0071,
    cols: 2,
    rows: 2,
    label: 'Oduncu Kulübesi',
    cost: ResourceCost(wood: 12),
    groundXCenter: 0.5037,
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
    groundY: 1.1282,
    spriteScale: 1.0,
    cols: 1,
    rows: 1,
    label: 'Sokak Feneri',
    cost: ResourceCost(wood: 2, iron: 1),
    groundXCenter: 0.3963,
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
    groundY: 1.002,
    cols: 2,
    rows: 2,
    label: 'Tavuk Kümesi',
    cost: ResourceCost(wood: 14, stone: 2),
    groundXCenter: 0.524,
    spriteScale: 0.9152,
    effectRadius: 3.5, // tavukların dolaştığı menzil
  ),
  BuildingType.beehive: BuildingMeta(
    groundY: 1.04,
    cols: 1,
    rows: 1,
    label: 'Arı Kovanı',
    cost: ResourceCost(wood: 8),
    groundXCenter: 0.5,
    spriteScale: 0.6123, // küçük kovan — well/firepit ölçeğine yakın
    walkable: true, // 1×1 dekor; etrafından geçilebilir
    effectRadius: 3.5, // bu menzildeki çiçekler bal üretimini hızlandırır
  ),
  BuildingType.church: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Kilise',
    cost: ResourceCost(wood: 30, stone: 24, iron: 3),
    // church.png trimlenmiş (1083×1156) → taban alt kenarda, merkez ~0.50.
    groundY: 1.083,
    groundXCenter: 0.5243,
    spriteScale: 1.0397, // görkemli landmark — footprint'in biraz dışına taşar
    effectRadius: 5.5, // moral menzili + cenaze töreni/mezarlık alanı
  ),
  // ─── Köy Meydanı & Kültür Mahallesi ────────────────────────────────────────
  // PNG'ler geldi; ebatlar yerleşim editörüyle oturtuldu (spriteScale/groundY
  // değerleri artık ölçülmüş değerler, başlangıç tahmini değil).
  BuildingType.fountain: BuildingMeta(
    spriteScale: 0.6422,
    cols: 2,
    rows: 2,
    label: 'Şadırvan',
    cost: ResourceCost(wood: 4, stone: 18),
    // fountain.png (1005×960) trimlenmiş; anchor bina tabanında (ölçüldü).
    groundY: 1.0777,
    groundXCenter: 0.4922,
    walkable: true,       // etrafında durulup toplanılan su öğesi
    effectRadius: 4.5,    // su erişimi (kuyu gibi) + gündüz toplanma menzili
  ),
  BuildingType.library: BuildingMeta(
    spriteScale: 1.0,
    cols: 2,
    rows: 2,
    label: 'Kütüphane',
    cost: ResourceCost(wood: 24, stone: 14, iron: 2),
    // library.png (996×1183) trimlenmiş; anchor bina tabanında (ölçüldü).
    groundY: 1.0277,
    groundXCenter: 0.543,
  ),
  BuildingType.bathhouse: BuildingMeta(
    spriteScale: 0.9041,
    cols: 2,
    rows: 2,
    label: 'Hamam',
    cost: ResourceCost(wood: 10, stone: 22),
    // bathhouse.png (1055×1112) trimlenmiş; anchor bina tabanında (ölçüldü).
    groundY: 1.009,
    groundXCenter: 0.5032,
  ),
  BuildingType.monument: BuildingMeta(
    spriteScale: 0.9907,
    cols: 2,
    rows: 2,
    label: 'Anıt',
    cost: ResourceCost(stone: 28, iron: 4, gold: 6),
    // monument.png (1091×927) trimlenmiş; anchor taban/çim (ölçüldü).
    groundY: 1.0763,
    groundXCenter: 0.446,
    walkable: true,       // 1×1 dekoratif landmark
  ),
  // ─── Liman & Ziyaret Mahallesi ─────────────────────────────────────────────
  // PNG'ler geldi; ebatlar yerleşim editörüyle oturtuldu.
  BuildingType.caravanserai: BuildingMeta(
    spriteScale: 1.0606,
    cols: 3,
    rows: 3,
    label: 'Han',
    cost: ResourceCost(wood: 20, stone: 24, iron: 3),
    groundY: 0.8061,
    groundXCenter: 0.4923,
  ),
  BuildingType.shrine: BuildingMeta(
    spriteScale: 1.0999,
    cols: 2,
    rows: 2,
    label: 'Türbe',
    cost: ResourceCost(wood: 6, stone: 22, gold: 2),
    groundY: 1.0014,
    groundXCenter: 0.4993,
    effectRadius: 4.0,    // ziyaret/moral menzili
  ),
  BuildingType.belltower: BuildingMeta(
    spriteScale: 1.271,
    cols: 1,
    rows: 1,
    label: 'Çan Kulesi',
    cost: ResourceCost(wood: 4, stone: 18, iron: 2),
    groundY: 0.9665,
    groundXCenter: 0.5,
  ),
  BuildingType.tent: BuildingMeta(
    cols: 1,
    rows: 1,
    label: 'Çadır',
    // İlk barınak: neredeyse bedava, yalnız odun. Köy daha ev dikemezken
    // başının sokmak için. Kalıcı ama düşük konfor (bkz. poorHousing morali).
    cost: ResourceCost(wood: 6),
    // tent.png trimlenmiş (1100×936) → taban alt kenarda, içerik merkezi 0.50.
    groundY: 1.0158,
    groundXCenter: 0.5171,
    spriteScale: 0.839, // 1×1 footprint'ten biraz taşan, evden küçük barınak
    walkable: true, // sakin içine girip uyur (ev gibi)
  ),
  BuildingType.woodenHouse: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Köy Evi',
    cost: ResourceCost(wood: 18, stone: 4),
    groundXCenter: 0.5,
    walkable: true, // sakinler içine girip uyur
  ),
  // Taş Konut — Köy Evi'nin bir üst kademesi. İki görsel varyant (mavi/yeşil
  // çatı) AYNI ekonomik şartlara sahip; oyuncu yalnız estetiğe göre seçer.
  // Daha pahalı (taş ağırlıklı) ama daha geniş (kapasite 3) + konfor moral
  // bonusu (bkz. villager_morale comfortHousing). 2×2 footprint, sprite biraz
  // taşar (görkemli iki katlı taş+ahşap ev).
  BuildingType.stoneHouseBlue: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Taş Konut (Mavi Çatı)',
    cost: ResourceCost(wood: 24, stone: 18),
    // stonehouse_blue.png (1146×1193). Sprite'ın ön plan süsleri (merdiven/fıçı)
    // bina tabanının ALTINA taşıyor — bu yüzden anchor sprite altı değil, BİNA
    // TABANI (ny≈0.914) olmalı; yoksa bina footprint'in üstünde havada durur ve
    // yeşil varyantla aynı hizada oturmaz. groundXCenter = taban orta noktası.
    groundY: 1.0776,
    groundXCenter: 0.4739,
    spriteScale: 0.954, // footprint'e otursun (1.18 çok taşıyordu); minihouse hissi
    walkable: true,
  ),
  BuildingType.stoneHouseGreen: BuildingMeta(
    cols: 2,
    rows: 2,
    label: 'Taş Konut (Yeşil Çatı)',
    // stoneHouseBlue ile birebir aynı maliyet — yalnız görsel farklı.
    cost: ResourceCost(wood: 24, stone: 18),
    // stonehouse_green.png (1138×1197). Bina tabanı sprite'ta ny≈0.947'de
    // (mavi'den farklı ön plan süs miktarı). Anchor bina tabanında → mavi
    // varyantla aynı yükseklikte oturur (twin tutarlılığı).
    groundY: 1.0712,
    groundXCenter: 0.4588,
    spriteScale: 0.885, // mavi varyantla aynı — footprint'e oturur
    walkable: true,
  ),
  // Konak — en lüks konut. Görkemli taş malikâne: yüksek kapasite (4) + güçlü
  // konfor bonusu (luxuryHousing). Üst kademe maliyet (demir + altın ister).
  // 3×3 footprint, prestij landmark.
  BuildingType.manor: BuildingMeta(
    cols: 3,
    rows: 3,
    label: 'Konak',
    cost: ResourceCost(wood: 40, stone: 34, iron: 6, gold: 10),
    // manor.png (1066×1177). 3×2 footprint (eski 3×3 fazla yer kaplıyordu).
    // Anchor bina tabanında (ny≈0.918); ön plan merdiven/saksılar öne taşar.
    groundY: 1.0583,
    groundXCenter: 0.4997,
    spriteScale: 0.9036,
    walkable: true,
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
    groundY: 1.04,
    spriteScale: 1.0,
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
    groundY: 1.0857,
    cols: 2,
    rows: 2,
    label: 'Depo',
    cost: ResourceCost(wood: 28, stone: 16),
    groundXCenter: 0.4986,
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
    // barn.png trimlenmiş (1171×939) → taban alt kenarda, yapısal merkez ~0.60.
    groundY: 1.0,
    groundXCenter: 0.6,
  ),
  BuildingType.market: BuildingMeta(
    groundY: 1.019,
    cols: 3,
    rows: 3,
    label: 'Pazar',
    cost: ResourceCost(wood: 30, stone: 22, iron: 4),
    groundXCenter: 0.4898,
    spriteScale: 0.9531,
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
