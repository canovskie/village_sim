import '../core/resources.dart';
import 'building_type.dart';

/// Bir binanın oyun içi rolü — detay paneli ve [updateBuildings] mantığını
/// belirler. Her [BuildingType] tam olarak bir role sahiptir.
enum BuildingRole {
  /// Özel işlevi yok (ör. ateş yeri — sadece başlangıç/ışık).
  none,

  /// Köylülere ev (uyku + nüfus kapasitesi) sağlar.
  housing,

  /// Kendi işçisini doğurur, dünyadan ham kaynak toplar
  /// (oduncu, maden, balıkçı). Mantığı kendi entity'lerinde.
  gathering,

  /// Bir kaynağı zaman içinde başka/daha değerli kaynağa çevirir (değirmen).
  processing,

  /// Kaynakları altına çevirir — pasif gelir + manuel satış (pazar).
  trade,

  /// Köy stoğunun kapasitesini artırır (depo).
  storage,

  /// Köy çapında pasif etki: nüfus, moral, hız (belediye, kuyu, ahır, taverna).
  civic,
}

/// Bir civic binanın köy çapındaki etkisini niceleyen tek sayı.
/// Yorumu role/türe göre değişir:
///  • townhall → nüfus büyüme süresinin temel saniyesi
///  • well     → moral katkısı (0..1)
///  • tavern   → moral katkısı (0..1)
///  • stable   → taşıyıcı hız çarpanı katkısı (ör. 0.15 = +%15)
enum CivicEffect { populationGrowth, morale, carrierSpeed, none }

/// Her bina türünün işlevsel tanımı — [kBuildingMeta]'nın ekonomik karşılığı.
class BuildingFunction {
  final BuildingRole role;

  /// Panelde gösterilen kısa açıklama.
  final String summary;

  /// Sakin kapasitesi (yalnızca housing).
  final int housingCapacity;

  /// Stok kapasitesi katkısı (yalnızca storage).
  final int storageCapacity;

  /// Civic etki türü + değeri.
  final CivicEffect civicEffect;
  final double civicValue;

  const BuildingFunction({
    required this.role,
    required this.summary,
    this.housingCapacity = 0,
    this.storageCapacity = 0,
    this.civicEffect = CivicEffect.none,
    this.civicValue = 0.0,
  });
}

// ─── Ekonomi sabitleri ───────────────────────────────────────────────────────

/// Hiç depo yokken temel stok kapasitesi.
const int kBaseStockCapacity = 120;

/// Belediye bir köylü üretmek için harcadığı yiyecek.
const int kPopulationGrowthFoodCost = 10;

/// Nüfus büyümesinin başlaması için gereken minimum yiyecek stoğu.
const int kPopulationGrowthFoodFloor = 14;

/// Pazar pasif altın geliri: her [kMarketIncomeInterval] sn'de civicValue altın.
const double kMarketIncomeInterval = 12.0;

/// Değirmen bir balya öğütünce kaç saniye "çalışıyor" görünür (duman + panel).
/// Hasat serpiştikçe her balya teslimi bu süreyi yeniler → değirmen döner.
const double kMillGrindSeconds = 6.0;

/// Pazarda manuel satış: kaynak türü → (satılan parti, kazanılan altın).
const Map<ResourceKind, (int batch, int gold)> kMarketSellRates = {
  ResourceKind.wood: (10, 2),
  ResourceKind.stone: (10, 2),
  ResourceKind.iron: (5, 3),
  ResourceKind.coal: (8, 2),
  ResourceKind.food: (10, 2),
};

// ─── Bina işlev tablosu ──────────────────────────────────────────────────────

const Map<BuildingType, BuildingFunction> kBuildingFunctions = {
  BuildingType.firepit: BuildingFunction(
    role: BuildingRole.none,
    summary: 'Köyün kalbi. Köylüler geceleri etrafında toplanır.',
  ),

  BuildingType.tent: BuildingFunction(
    role: BuildingRole.housing,
    summary: 'Derme çatma barınak. Bir köylüyü sokağın soğuğundan alır ama '
        'gerçek bir ev kadar huzur vermez. Köy ev dikecek hâle gelene kadar.',
    housingCapacity: 1,
  ),

  BuildingType.woodenHouse: BuildingFunction(
    role: BuildingRole.housing,
    summary: 'Köylülere yuva. Dolu evler nüfus tavanını yükseltir.',
    housingCapacity: 2,
  ),

  BuildingType.stoneHouseBlue: BuildingFunction(
    role: BuildingRole.housing,
    summary: 'Taş ve ahşaptan sağlam bir konut. Köy Evi\'nden geniş ve daha '
        'huzurlu — sakinleri burada rahat eder (moral). Üç köylü barındırır.',
    housingCapacity: 3,
  ),

  // stoneHouseBlue ile birebir aynı işlev — yalnız çatı rengi farklı.
  BuildingType.stoneHouseGreen: BuildingFunction(
    role: BuildingRole.housing,
    summary: 'Taş ve ahşaptan sağlam bir konut. Köy Evi\'nden geniş ve daha '
        'huzurlu — sakinleri burada rahat eder (moral). Üç köylü barındırır.',
    housingCapacity: 3,
  ),

  BuildingType.manor: BuildingFunction(
    role: BuildingRole.housing,
    summary: 'Köyün en görkemli evi. Geniş taş konak dört köylüye lüks bir '
        'yuva sunar; burada yaşamak köylüyü belirgin biçimde mutlu eder.',
    housingCapacity: 4,
  ),

  BuildingType.lumberCamp: BuildingFunction(
    role: BuildingRole.gathering,
    summary: 'Bölgesindeki ağaçları keser, yenilerini diker. Odun üretir.',
  ),

  BuildingType.mineBuilding: BuildingFunction(
    role: BuildingRole.gathering,
    summary: 'Maden damarını kazar. Taş, demir ve kömür çıkarır.',
  ),

  BuildingType.fisherCabin: BuildingFunction(
    role: BuildingRole.gathering,
    summary: 'Sudan balık tutar. Doğrudan yiyecek üretir.',
  ),

  BuildingType.mill: BuildingFunction(
    role: BuildingRole.processing,
    summary: 'Tahılı öğütüp ekmek yapar. Çalışırken tarladan gelen her balya '
        '+1 fazla yiyecek verir.',
  ),

  BuildingType.market: BuildingFunction(
    role: BuildingRole.trade,
    summary: 'Fazla kaynakları altına çevirir. Pasif gelir + manuel satış.',
    civicValue: 1.0, // periyodik pasif altın
  ),

  BuildingType.warehouse: BuildingFunction(
    role: BuildingRole.storage,
    summary: 'Köy stoğunun taşıma kapasitesini artırır.',
    storageCapacity: 180,
  ),

  BuildingType.townhall: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün yönetimi. Yiyecek harcayarak yeni köylüler yetiştirir.',
    civicEffect: CivicEffect.populationGrowth,
    civicValue: 22.0, // büyüme süresi (sn)
  ),

  BuildingType.well: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Temiz su sağlar: evlerin su deposunu doldurur, çiftçiler ekinleri '
        'sular (daha hızlı büyür) ve köy morali yükselir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),

  BuildingType.tavern: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köylülerin dinlendiği yer. Morali güçlü biçimde yükseltir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.18,
  ),

  BuildingType.stable: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Yük hayvanları barındırır. Taşıyıcıların hızını artırır.',
    civicEffect: CivicEffect.carrierSpeed,
    civicValue: 0.15,
  ),

  BuildingType.barn: BuildingFunction(
    role: BuildingRole.gathering,
    summary: 'İnekleri barındırır. Çoban inekleri sağar ve süt → yiyecek üretir.',
  ),

  BuildingType.lamppost: BuildingFunction(
    role: BuildingRole.none,
    summary: 'Geceleri sokağı aydınlatır. Yol kenarına dizilirse köy ışıl ışıl.',
  ),

  BuildingType.floristCottage: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Çiçekçi kadın etki alanındaki çiçekleri sular ve bakar; köy '
        'morali sürekli yüksek kalır. Kulübenin etrafına doğal çiçek demetleri biter.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),

  BuildingType.chickenCoop: BuildingFunction(
    role: BuildingRole.gathering,
    summary: '3-4 tavuk barındırır. Tavuklar dolaşır ve periyodik olarak '
        'yumurta yumurtlar — kümes düzenli olarak yiyecek üretir.',
  ),

  BuildingType.beehive: BuildingFunction(
    role: BuildingRole.gathering,
    summary: 'Arılar etraftaki çiçeklerden bal taşır. Menzilinde ne kadar çok '
        'çiçek varsa o kadar hızlı bal üretir — çiçekçinin yanına yakışır. '
        'Biriken bal köyü mutlu eder (lüks).',
  ),

  BuildingType.church: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün ruh evi. Köylüler huzur ve birlik bulur, moral yükselir. '
        'Biri hayata veda ettiğinde köy onu burada uğurlar; yanında usulca '
        'bir mezarlık büyür.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.12,
  ),

  // ─── Köy Meydanı & Kültür Mahallesi ────────────────────────────────────────
  BuildingType.fountain: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün gündüz kalbi. Temiz su verir (kuyu gibi yakın evleri/ekinleri '
        'besler) ve köylüler gün boyu başında toplanıp serinler — su erişimi '
        'morali yukarı çeker.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.library: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün belleği. Bir kültür ocağı: okuryazar, dingin bir köy daha '
        'mutludur. Köyün vakanüvis defteri burada tutulur.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.bathhouse: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Sıcak buharlı hamam. Köylüler yıkanıp dinlenir; temizlik ve '
        'sohbet morali tatlı tatlı yükseltir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.monument: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün gururu. Dikildiği yerde bir landmark — köylüler ondan '
        'onur duyar, moral hafifçe yükselir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.06,
  ),

  // ─── Liman & Ziyaret Mahallesi ─────────────────────────────────────────────
  BuildingType.dock: BuildingFunction(
    role: BuildingRole.trade,
    summary: 'Deniz kapısı. Tüccar tekneleri yanaşır; köy fazlasını denizaşırı '
        'satar — düzenli pasif altın geliri sağlar.',
    civicValue: 1.0, // periyodik pasif altın (market mekaniği)
  ),
  BuildingType.caravanserai: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Kervanların konak yeri. Yük hayvanları dinlenir, tüccarlar uğrar; '
        'taşıyıcılar daha hızlı yol alır.',
    civicEffect: CivicEffect.carrierSpeed,
    civicValue: 0.15,
  ),
  BuildingType.shrine: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün ziyaretgâhı. Sessiz bir maneviyat ocağı — köylüler huzur '
        'bulur, "yaşanası köy" morali yükselir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.belltower: BuildingFunction(
    role: BuildingRole.civic,
    summary: 'Köyün çan kulesi. Saatleri ve törenleri çanıyla duyurur; dikilişi '
        'köye düzen ve moral katar.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.08,
  ),
};
