import 'building_type.dart';
import '../characters/villager_type.dart';

/// ─── Köyün Bildiği Zanaatlar ────────────────────────────────────────────────
///
/// Oyunun gerçek ilerleme birimi. Bir bina, arkasındaki zanaatı köyde biri
/// BİLMEDİKÇE dikilemez. Bu bir evre/seviye sistemi DEĞİL — zanaatlar köyün
/// insanlarından organik doğar:
///   • Çağrı    — doğru mizaçtaki köylü yetişkinlikte kendi zanaatını keşfeder.
///   • Birikim  — bir işi çok tekrarlayan ustalaşır (odun taşıyan → marangoz).
///   • Dışarıdan— göçmen/tüccar bilmediğimiz bir zanaatı köye taşır.
/// ve usta-çırakla korunur; son usta çırak bırakmadan ölürse zanaat kaybolur.
///
/// Anahtarlar düz String (save'de esnek). Ortak bilgi = null (baştan bilinir).

class Craft {
  Craft._();

  static const carpentry = 'carpentry'; // Marangozluk — ahşap yapılar
  static const masonry = 'masonry'; // Taş Ustalığı — taş konut + görkemli civic
  static const farming = 'farming'; // Çiftçilik — tarla + bahçe + küçük hayvan
  static const husbandry = 'husbandry'; // Hayvancılık — ağıl/sürü
  static const milling = 'milling'; // Değirmencilik
  static const mining = 'mining'; // Madencilik — taş/demir/kömür
  static const fishing = 'fishing'; // Balıkçılık
  static const trade = 'trade'; // Ticaret — pazar/han/ahır
  static const faith = 'faith'; // İnanç — mabet/anıt

  static const all = <String>[
    carpentry, masonry, farming, husbandry, milling, mining, fishing, trade,
    faith,
  ];

  /// Yapı zanaatları — kişilikten değil, EMEKTEN (birikim) doğar.
  static const structural = <String>{carpentry, masonry};

  static String displayName(String key) => switch (key) {
        carpentry => 'Marangozluk',
        masonry => 'Taş Ustalığı',
        farming => 'Çiftçilik',
        husbandry => 'Hayvancılık',
        milling => 'Değirmencilik',
        mining => 'Madencilik',
        fishing => 'Balıkçılık',
        trade => 'Ticaret',
        faith => 'İnanç',
        _ => key,
      };
}

/// Her bina → dikilmesi için gereken zanaat. null = ortak bilgi (baştan bilinir,
/// hep açık: barınma/ısı/su/depo/oduncu — köyün survival kiti).
const Map<BuildingType, String?> kBuildingCraft = {
  // ── Ortak survival kiti (baştan bilinir) ──────────────────────────────────
  BuildingType.tent: null,
  BuildingType.firepit: null,
  BuildingType.well: null,
  BuildingType.warehouse: null,
  BuildingType.lumberCamp: null,
  BuildingType.lamppost: null,
  // ── Yapı zanaatları (birikim) ─────────────────────────────────────────────
  BuildingType.woodenHouse: Craft.carpentry,
  BuildingType.tavern: Craft.carpentry,
  BuildingType.stoneHouseBlue: Craft.masonry,
  BuildingType.stoneHouseGreen: Craft.masonry,
  BuildingType.manor: Craft.masonry,
  BuildingType.townhall: Craft.masonry,
  BuildingType.library: Craft.masonry,
  BuildingType.bathhouse: Craft.masonry,
  BuildingType.fountain: Craft.masonry,
  // ── Meslek zanaatları (çağrı / dışarıdan) ─────────────────────────────────
  BuildingType.floristCottage: Craft.farming,
  BuildingType.chickenCoop: Craft.farming,
  BuildingType.beehive: Craft.farming,
  BuildingType.barn: Craft.husbandry,
  BuildingType.mill: Craft.milling,
  BuildingType.mineBuilding: Craft.mining,
  BuildingType.fisherCabin: Craft.fishing,
  BuildingType.dock: Craft.fishing,
  BuildingType.market: Craft.trade,
  BuildingType.caravanserai: Craft.trade,
  BuildingType.stable: Craft.trade,
  BuildingType.church: Craft.faith,
  BuildingType.shrine: Craft.faith,
  BuildingType.belltower: Craft.faith,
  BuildingType.monument: Craft.faith,
};

/// Bir meslek/çağrının köye taşıdığı zanaat — çağrı (yetişkinlik) ve göç
/// (dışarıdan) kanalları bunu okur. null = o meslek bir bina zanaatı açmaz
/// (muhafız/avcı köyde iş görür ama bir yapı kilidi açmaz).
const Map<VillagerType, String?> kCallingCraft = {
  VillagerType.farmer: Craft.farming,
  VillagerType.shepherd: Craft.husbandry,
  VillagerType.miller: Craft.milling,
  VillagerType.fisher: Craft.fishing,
  VillagerType.merchant: Craft.trade,
  VillagerType.innkeeper: Craft.trade,
  VillagerType.priest: Craft.faith,
  VillagerType.blacksmith: Craft.mining, // demirci metali işler → madeni açar
  VillagerType.miner: Craft.mining,
  VillagerType.guard: null,
  VillagerType.hunter: null,
};
