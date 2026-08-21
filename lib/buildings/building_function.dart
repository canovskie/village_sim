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
/// Yorumu etkiye göre değişir:
///  • morale       → amenite moral AĞIRLIĞI (bkz. amenityMoraleFrom). Ağırlıklar
///    toplanıp yumuşak doyuma sokulur; bina başına birebir moral DEĞİLDİR ama
///    büyüklükleri birbirine göre anlamlıdır (taverna 0.18 > anıt 0.06).
///  • carrierSpeed → taşıyıcı hız çarpanı katkısı (ör. 0.15 = +%15)
///  • none         → civicValue okunmaz (ör. belediye: yönetişimin koltuğu,
///    sayısal bir köy-çapı etkisi yok)
enum CivicEffect { morale, carrierSpeed, none }

/// Her bina türünün işlevsel tanımı — [kBuildingMeta]'nın ekonomik karşılığı.
class BuildingFunction {
  final BuildingRole role;

  /// Panelde gösterilen kısa açıklama.
  final String summary;

  /// Sakin kapasitesi (yalnızca housing).
  final int housingCapacity;

  /// Stok kapasitesi katkısı (yalnızca storage).
  final int storageCapacity;

  /// Civic etki türü + değeri. [civicValue] SİMÜLASYONUN OKUDUĞU sayıdır —
  /// panelde gösterilen ağırlık ile buradaki değer aynı yerden gelir, ikinci
  /// bir "hangi bina moral verir" listesi yoktur.
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

/// Pazar tahsilat periyodu (sn). Tahsilatın MİKTARI köyün fazlasından gelir —
/// bkz. marketBaseIncome (building_system).
const double kMarketIncomeInterval = 12.0;

/// Değirmen bir balya öğütünce kaç saniye "çalışıyor" görünür (duman + panel).
/// Hasat serpiştikçe her balya teslimi bu süreyi yeniler → değirmen döner.
const double kMillGrindSeconds = 6.0;

/// Çalışan bir değirmenin balyaya kattığı fazla yem (carrier_system).
const int kMillBaleBonus = 2;

/// Bonus veren azami değirmen sayısı — üçüncü değirmen ekonomiye katmaz.
const int kMillBonusMaxCount = 2;

/// Başında değirmenci DURAN bir değirmenin balya verimine çarpanı. İkinci
/// değirmenci yarı katkı verir (bkz. scene_work._millerYieldMul).
const double kMillerYieldBonus = 0.25;

/// Pazarda manuel satış: kaynak türü → (satılan parti, kazanılan altın).
const Map<ResourceKind, (int batch, int gold)> kMarketSellRates = {
  ResourceKind.wood: (10, 2),
  ResourceKind.stone: (10, 2),
  ResourceKind.iron: (5, 3),
  ResourceKind.coal: (8, 2),
  ResourceKind.food: (10, 2),
};

/// Gezgin tüccarın alımı: kaynak türü → (parti, altın, TABAN stok). Tüccar
/// köyün YALNIZ fazlasını alır — elde en az `keepFloor` kalır (zorunluyu satmaz).
/// Pazardan daha iyi öder (dışarıya satış primi) ve balın TEK alıcısıdır (pazarda
/// satış oranı yok) → arı kovanı üretimine gerçek bir amaç kazandırır.
const Map<ResourceKind, (int batch, int gold, int keepFloor)>
kMerchantBuyRates = {
  ResourceKind.food: (12, 3, 60), // yiyecek en son satılır (yüksek taban)
  ResourceKind.wood: (12, 4, 45),
  ResourceKind.stone: (12, 4, 45),
  ResourceKind.coal: (10, 4, 24),
  ResourceKind.iron: (6, 5, 16),
  ResourceKind.honey: (4, 6, 6), // lüks — az parti, yüksek değer
};

// ─── Bina işlev tablosu ──────────────────────────────────────────────────────

const Map<BuildingType, BuildingFunction> kBuildingFunctions = {
  BuildingType.firepit: BuildingFunction(
    role: BuildingRole.none,
    summary:
        'Köyün ilk ateşi ve hâlâ kalbi. Karanlık basınca herkes buraya toplanır; yakacak biterse sohbet de biter. Odun çabuk tutuşup çabuk biter, kömür uzun yanar — kışın ocak iki katı yer, o yüzden kara damar kışın altından değerlidir.',
  ),

  BuildingType.tent: BuildingFunction(
    role: BuildingRole.housing,
    summary:
        'Derme çatma barınak. Bir köylüyü sokağın soğuğundan alır ama '
        'gerçek bir ev kadar huzur vermez. Kendi ocağı da yoktur: kışın '
        'ısınmasının tek yolu köyün ateşine yakın kurulmuş olmaktır — uzağa '
        'kurulan çadırda geceler titreyerek geçer. Köy ev dikecek hâle gelene kadar.',
    housingCapacity: 1,
  ),

  BuildingType.woodenHouse: BuildingFunction(
    role: BuildingRole.housing,
    summary:
        'Bir dam, bir ocak, iki yatak. Işığı yanan her ev köyün '
        'taşıyabileceği can sayısını yukarı çeker.',
    housingCapacity: 2,
  ),

  BuildingType.stoneHouseBlue: BuildingFunction(
    role: BuildingRole.housing,
    summary:
        'Kalın taş duvar, kışın içeri sızmaz. Köy Evi\'nden geniş: üç kişi '
        'sıkışmadan yaşar, sabah dinlenmiş kalkar (moral).',
    housingCapacity: 3,
  ),

  // stoneHouseBlue ile birebir aynı işlev — yalnız çatı rengi farklı.
  BuildingType.stoneHouseGreen: BuildingFunction(
    role: BuildingRole.housing,
    summary:
        'Kalın taş duvar, kışın içeri sızmaz. Köy Evi\'nden geniş: üç kişi '
        'sıkışmadan yaşar, sabah dinlenmiş kalkar (moral).',
    housingCapacity: 3,
  ),

  BuildingType.manor: BuildingFunction(
    role: BuildingRole.housing,
    summary:
        'Köyün en büyük kapısı bu konağa açılır. Dört kişi burada dar '
        'değil geniş yaşar; içinde uyuyan kendini şanslı bilir.',
    housingCapacity: 4,
  ),

  BuildingType.lumberCamp: BuildingFunction(
    role: BuildingRole.gathering,
    summary:
        'Balta sesi buradan gelir. Oduncu çevresindeki ağaçları devirir, '
        'yerine fidan diker; kütükler istif olur, istif odun olur.',
  ),

  BuildingType.mineBuilding: BuildingFunction(
    role: BuildingRole.gathering,
    summary:
        'Damarın ağzına kurulmuş bir baraka. İçeriden çekiç sesi, dışarıya taş, demir ve kömür çıkar. Kömürün iki yolu var: ocakta yanar ya da pazarda satılır — kış yaklaşırken hangisi olduğuna sen karar verirsin.',
  ),

  BuildingType.fisherCabin: BuildingFunction(
    role: BuildingRole.gathering,
    summary:
        'Suyun kıyısında bir kulübe. Balıkçı sabah ağını atar, akşam sepetini ambara boşaltır: doğrudan yiyecek.',
  ),

  BuildingType.mill: BuildingFunction(
    role: BuildingRole.processing,
    summary:
        'Kanatlar döndükçe içerisi un kokar. Tarladan gelen her balya +2 '
        'fazla yiyecek eder (ikinci değirmen de sayılır, üçüncüsü katmaz); '
        'başında bir değirmenci duruyorsa harman büsbütün bereketlenir.',
  ),

  BuildingType.market: BuildingFunction(
    role: BuildingRole.trade,
    summary:
        'Tezgâhlar, bağırışlar, terazi. Köyün ihtiyacından FAZLASI burada '
        'altına döner: ambar taşarken kasa dolar, boşken tezgâh da boş durur. '
        'İstersen elinle de satarsın.',
    // Gelir civicValue'dan DEĞİL, köyün fazlasından hesaplanır (marketBaseIncome).
  ),

  BuildingType.warehouse: BuildingFunction(
    role: BuildingRole.storage,
    summary:
        'Serin, karanlık, tıka basa. Ambar durdukça harman yerde çürümez: köyün stok tavanı yükselir.',
    storageCapacity: 180,
  ),

  BuildingType.townhall: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Mühür burada durur, defter burada tutulur. Köyün yönetişimi — '
        'divan, gündem, vergi — bu kapıdan geçer. Deftere geçen her hüner köyün '
        'kalıcı hafızasına girer: zanaat bir daha kaybolmaz.',
    // Nüfus büyümesi artık doğal doğumda; belediyenin sayısal bir köy-çapı
    // etkisi yok — koltuğu yönetişim panelleri (Divan/Vergi) dolduruyor.
  ),

  BuildingType.well: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Kova iner, dolu çıkar. Evlerin küpü dolar, çiftçi ekinini sular '
        '(daha hızlı büyür); temiz suyu olan köy hâlinden memnun olur.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),

  BuildingType.tavern: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Akşam işten çıkanın uğradığı yer. Kahkaha, dedikodu, bir kadeh; köyün morali en çok buradan beslenir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.18,
  ),

  BuildingType.stable: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Saman ve at kokusu. Yük hayvanı burada dinlenir, taşıyıcılar yolu daha kısa katar.',
    civicEffect: CivicEffect.carrierSpeed,
    civicValue: 0.15,
  ),

  BuildingType.barn: BuildingFunction(
    role: BuildingRole.gathering,
    summary:
        'İnekler burada gecelenir. Çoban sabah sağar, süt ambara yiyecek olarak yazılır.',
  ),

  BuildingType.lamppost: BuildingFunction(
    role: BuildingRole.none,
    summary:
        'Akşam olunca kendiliğinden yanar. Yol kenarına dizilenler köyü gece haritada bir kolye gibi gösterir.',
  ),

  BuildingType.floristCottage: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Çiçekçi kadın sabahtan akşama etrafındakileri sular, ayıklar, '
        'budar. Kulübenin çevresi kendiliğinden çiçek tutar; güzel bir köyde '
        'yaşamak morali sürekli ayakta tutar.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),

  BuildingType.tailor: BuildingFunction(
    role: BuildingRole.none,
    summary:
        'Terzi kurulana kadar köylüler kaba post ve bezlerle dolaşır. '
        'Atölye tamamlandığında köyün günlük giysileri dikilir.',
  ),

  BuildingType.chickenCoop: BuildingFunction(
    role: BuildingRole.gathering,
    summary:
        'Üç dört tavuk gün boyu avluda eşinir, arada yumurtlar. Kümes '
        'gösterişsizdir ama ambara düzenli yiyecek yazar.',
  ),

  BuildingType.beehive: BuildingFunction(
    role: BuildingRole.gathering,
    summary:
        'Vızıltı sıcak günlerde köyün arka sesidir. Arılar menzildeki her '
        'çiçekten bal taşır: ne kadar çok çiçek, o kadar hızlı kavanoz. Bal '
        'lükstür; lüksü olan köy kendini şanslı sayar.',
  ),

  BuildingType.church: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Serin taş, mum kokusu, alçak sesler. Köy burada toplanır, burada '
        'iyileşir; biri göçtüğünde onu buradan uğurlar. Yanı başında mezarlık '
        'sessizce büyür.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.12,
  ),

  // ─── Köy Meydanı & Kültür Mahallesi ────────────────────────────────────────
  BuildingType.fountain: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Suyun şıpırtısı meydanın gündüz sesidir. Kuyu gibi yakın evleri ve '
        'ekinleri besler; sıcakta herkes başına toplanır, serinler, konuşur.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.library: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Köyün hafızası. Rafta ne varsa okuyan bulunur; vakanüvis defteri '
        'de burada tutulur. Okuyan köy daha sakin, daha memnun bir köydür. Bir '
        'zanaat yazıya geçince artık unutulmaz — usta göçse de bilgi rafta kalır.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.bathhouse: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Buhar, mermer, uzun sohbetler. Köylü yıkanır, gevşer, dedikodusunu '
        'eder; temiz ve dinlenmiş bir köyün morali kendiliğinden yükselir.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.monument: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Taşa kazınmış bir hatıra. Yolu buradan geçen başını kaldırıp bakar; '
        'köylü ona bakınca kendini biraz daha büyük hisseder.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.06,
  ),

  // ─── Liman & Ziyaret Mahallesi ─────────────────────────────────────────────
  BuildingType.caravanserai: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Kervan burada mola verir: hayvan dinlenir, kervancılar uyur, avlu geceyi '
        'yabancı dillerle geçirir. Köyün taşıyıcıları da bu düzenden hızlanır.',
    civicEffect: CivicEffect.carrierSpeed,
    civicValue: 0.15,
  ),
  BuildingType.shrine: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Bez bağlanmış bir ziyaretgâh. Kimse yüksek sesle konuşmaz; derdi '
        'olan uğrar, biraz hafiflemiş çıkar.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.10,
  ),
  BuildingType.belltower: BuildingFunction(
    role: BuildingRole.civic,
    summary:
        'Çan vakti söyler: iş başını, töreni, tehlikeyi. Sesini duyan köy '
        'kendini bir düzenin içinde hisseder.',
    civicEffect: CivicEffect.morale,
    civicValue: 0.08,
  ),
};
