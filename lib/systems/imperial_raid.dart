// İmparatorluk baskın kataloğu. Sahne tek bir "askerler merkeze koşar" olayı
// oynatmasın diye baskının hedefini, kuvvetini ve bedelini saf veride tutar.

import '../world/season.dart';

enum ImperialRaidTarget {
  threshold('köy eşiği'),
  center('köy meydanı'),
  warehouse('ambar'),
  market('pazar'),
  homes('evler'),
  townHall('meclis konağı'),
  church('kilise'),
  fields('tarlalar'),
  lumberCamp('oduncu kampı'),
  stable('ahır'),
  manor('konak');

  const ImperialRaidTarget(this.label);
  final String label;
}

enum ImperialRaidKind {
  shieldWall,
  granaryRequisition,
  marketPillage,
  nightKnives,
  torchLine,
  youthSweep,
  harvestSeizure,
  winterLevy,
  timberColumn,
  cavalrySweep,
  hostageWrit,
  sanctuaryDragnet,
  manorSeizure,
  roadBlockade,
  punitiveMarch,
  scorchedHarvest,
  falseRetreat,
  deserterBreak,
  sapperBreach,
  occupationDay,
  stableRaid,
  commandDecapitation,
  dawnEncirclement,
  reliefColumn,
}

class ImperialRaidContext {
  final int year;
  final int population;
  final double favor;
  final bool isNight;
  final bool raining;
  final Season season;
  final bool hasWarehouse;
  final bool hasMarket;
  final bool hasTownHall;
  final bool hasChurch;
  final bool hasManor;
  final bool hasStable;
  final bool hasLumberCamp;

  const ImperialRaidContext({
    required this.year,
    required this.population,
    required this.favor,
    required this.isNight,
    required this.raining,
    required this.season,
    required this.hasWarehouse,
    required this.hasMarket,
    required this.hasTownHall,
    required this.hasChurch,
    required this.hasManor,
    required this.hasStable,
    required this.hasLumberCamp,
  });
}

class ImperialRaidScenario {
  final ImperialRaidKind kind;
  final String title;
  final String omen;
  final String objective;
  final ImperialRaidTarget target;
  final int minYear;
  final int minPopulation;
  final bool nightOnly;
  final bool rainOnly;
  final Season? seasonOnly;
  final double minFavor;
  final double maxFavor;
  final double attackDelta;
  final int casualtyDelta;
  final double lootMultiplier;
  final int groupBonus;
  final double holdBonus;
  final double barricadeBonus;
  final double chargeBonus;

  const ImperialRaidScenario({
    required this.kind,
    required this.title,
    required this.omen,
    required this.objective,
    required this.target,
    this.minYear = 1,
    this.minPopulation = 8,
    this.nightOnly = false,
    this.rainOnly = false,
    this.seasonOnly,
    this.minFavor = 0,
    this.maxFavor = 1,
    this.attackDelta = 0,
    this.casualtyDelta = 0,
    this.lootMultiplier = 1,
    this.groupBonus = 0,
    this.holdBonus = 0,
    this.barricadeBonus = 0,
    this.chargeBonus = 0,
  });

  bool isEligible(ImperialRaidContext c) {
    if (c.year < minYear || c.population < minPopulation) return false;
    if (nightOnly && !c.isNight) return false;
    if (rainOnly && !c.raining) return false;
    if (seasonOnly != null && c.season != seasonOnly) return false;
    if (c.favor < minFavor || c.favor > maxFavor) return false;
    return switch (target) {
      ImperialRaidTarget.warehouse => c.hasWarehouse,
      ImperialRaidTarget.market => c.hasMarket,
      ImperialRaidTarget.townHall => c.hasTownHall,
      ImperialRaidTarget.church => c.hasChurch,
      ImperialRaidTarget.manor => c.hasManor,
      ImperialRaidTarget.stable => c.hasStable,
      ImperialRaidTarget.lumberCamp => c.hasLumberCamp,
      _ => true,
    };
  }
}

/// Yirmi dört ayrı askerî durum. Her satır farklı bir hedef, koşul veya denge
/// profili taşır; başlık değiştirilmiş aynı olaylar değildir.
const imperialRaidScenarios = <ImperialRaidScenario>[
  ImperialRaidScenario(
    kind: ImperialRaidKind.shieldWall,
    title: 'Demir Saf',
    omen:
        'Kalkanlar birbirine kilitlendi; kolon eşikte meydan muharebesi arıyor.',
    objective: 'Savunma hattını kırıp köyü boyun eğdirmek',
    target: ImperialRaidTarget.threshold,
    holdBonus: .06,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.granaryRequisition,
    title: 'Ambar Baskını',
    omen: 'Yük arabaları boş geldi. Mızrakların yönü doğrudan ambara dönük.',
    objective: 'Kışlık zahireyi zorla götürmek',
    target: ImperialRaidTarget.warehouse,
    lootMultiplier: 1.45,
    barricadeBonus: .08,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.marketPillage,
    title: 'Pazar Yağması',
    omen: 'Tahsilat mührü yok; askerler keseleri ve tezgâhları sayıyor.',
    objective: 'Pazarı dağıtıp altına el koymak',
    target: ImperialRaidTarget.market,
    lootMultiplier: 1.35,
    chargeBonus: .05,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.nightKnives,
    title: 'Gece Bıçakları',
    omen: 'Fener yok, sancak yok. Karanlıkta yalnız zırh sürtünmesi duyuluyor.',
    objective: 'Evleri sessizce basıp rehineler almak',
    target: ImperialRaidTarget.homes,
    nightOnly: true,
    attackDelta: .10,
    casualtyDelta: 1,
    holdBonus: -.04,
    barricadeBonus: .07,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.torchLine,
    title: 'Meşale Hattı',
    omen: 'Her üçüncü askerin elinde meşale var; bu kez defter taşımıyorlar.',
    objective: 'Evleri ateşe vererek ibret yaratmak',
    target: ImperialRaidTarget.homes,
    minYear: 2,
    nightOnly: true,
    casualtyDelta: 1,
    lootMultiplier: .7,
    barricadeBonus: .05,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.youthSweep,
    title: 'Devşirme Taraması',
    omen: 'Kâtip yaşları soruyor; askerler kaçış yollarını tutuyor.',
    objective: 'Gençleri meydanda toplayıp kolona katmak',
    target: ImperialRaidTarget.center,
    minPopulation: 12,
    holdBonus: .03,
    chargeBonus: -.03,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.harvestSeizure,
    title: 'Hasat Kancası',
    omen: 'Orak vakti gelen asker tarlaya vergi değil, boş çuval getirdi.',
    objective: 'Hasadı köylünün elinden tarlada almak',
    target: ImperialRaidTarget.fields,
    seasonOnly: Season.autumn,
    lootMultiplier: 1.55,
    holdBonus: -.05,
    chargeBonus: .08,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.winterLevy,
    title: 'Kış Tahsili',
    omen: 'Karın içinde ilerleyen kolon kendi erzağını köyden tamamlayacak.',
    objective: 'Yiyecek ve yakacağı kış ortasında söküp almak',
    target: ImperialRaidTarget.warehouse,
    seasonOnly: Season.winter,
    attackDelta: .04,
    lootMultiplier: 1.65,
    barricadeBonus: .10,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.timberColumn,
    title: 'Kereste Kolu',
    omen: 'Baltalı istihkâm erleri oduncu yoluna saptı.',
    objective: 'Kampı ve kesilmiş keresteyi ele geçirmek',
    target: ImperialRaidTarget.lumberCamp,
    lootMultiplier: 1.4,
    holdBonus: .04,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.cavalrySweep,
    title: 'Atlı Süpürme',
    omen:
        'Nal sesi iki koldan geliyor; meydanı çevirip hattı yarmaya çalışacaklar.',
    objective: 'Meydanı kuşatıp direnişi hareket halinde ezmek',
    target: ImperialRaidTarget.center,
    minYear: 2,
    minPopulation: 16,
    attackDelta: .13,
    casualtyDelta: 1,
    groupBonus: 3,
    barricadeBonus: .12,
    chargeBonus: -.08,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.hostageWrit,
    title: 'Rehine Fermanı',
    omen: 'Komutanın elindeki mühürlü kâğıtta bir hane adı var.',
    objective: 'Köy ileri gelenini canlı ele geçirmek',
    target: ImperialRaidTarget.townHall,
    minYear: 2,
    casualtyDelta: -1,
    chargeBonus: .06,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.sanctuaryDragnet,
    title: 'Mabet Çemberi',
    omen: 'Askerler çanı susturup kilise kapısını çevreliyor.',
    objective: 'Sığınanları dışarı sürüklemek',
    target: ImperialRaidTarget.church,
    minYear: 2,
    attackDelta: .05,
    casualtyDelta: 1,
    holdBonus: .07,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.manorSeizure,
    title: 'Konak Müsaderesi',
    omen: 'Kâtip tapu defterini açtı; sancak konağın kapısına dikilecek.',
    objective: 'Konağı ve hanenin servetini taç adına almak',
    target: ImperialRaidTarget.manor,
    minYear: 2,
    lootMultiplier: 1.6,
    groupBonus: 1,
    chargeBonus: .05,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.roadBlockade,
    title: 'Yol Ablukası',
    omen: 'Kolon köye girmiyor; erzak yoluna kazık ve sancak dikiyor.',
    objective: 'Köyü aç bırakıp teslim olmaya zorlamak',
    target: ImperialRaidTarget.threshold,
    minYear: 2,
    attackDelta: -.04,
    lootMultiplier: 1.2,
    chargeBonus: .09,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.punitiveMarch,
    title: 'Ceza Yürüyüşü',
    omen:
        'Davul ritmi tahsilat değil infaz ritmi; eski retlerin hesabı geliyor.',
    objective: 'Köyü topluca cezalandırmak',
    target: ImperialRaidTarget.center,
    minYear: 2,
    attackDelta: .14,
    casualtyDelta: 2,
    groupBonus: 3,
    holdBonus: .04,
    maxFavor: .4,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.scorchedHarvest,
    title: 'Yakılmış Hasat',
    omen: 'Meşaleler rüzgâr altında tarlalara doğru eğiliyor.',
    objective: 'Ürünü götürmek yerine yakıp gelecek kışı vurmak',
    target: ImperialRaidTarget.fields,
    minYear: 3,
    seasonOnly: Season.summer,
    casualtyDelta: 1,
    lootMultiplier: 1.25,
    chargeBonus: .07,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.falseRetreat,
    title: 'Sahte Ricat',
    omen: 'Ön saf geri dönüyor ama yan kollar ağaç çizgisinde bekliyor.',
    objective: 'Köy savunmasını eşikten çıkarıp çevirmek',
    target: ImperialRaidTarget.threshold,
    minYear: 3,
    attackDelta: .09,
    groupBonus: 2,
    holdBonus: .11,
    chargeBonus: -.14,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.deserterBreak,
    title: 'Firar Yarığı',
    omen:
        'İmparatorluk safında iki mızrak yere indi; askerler kendi içinde bölündü.',
    objective: 'Dağılan kolonu yeniden toplayıp köyü susturmak',
    target: ImperialRaidTarget.threshold,
    minYear: 3,
    attackDelta: -.14,
    groupBonus: -1,
    chargeBonus: .10,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.sapperBreach,
    title: 'Lağımcı Hücumu',
    omen: 'Kalkanların arkasında kazma ve kanca taşıyan istihkâm erleri var.',
    objective: 'Savunma noktasını söküp içeri gedik açmak',
    target: ImperialRaidTarget.townHall,
    minYear: 3,
    minPopulation: 18,
    attackDelta: .12,
    casualtyDelta: 1,
    groupBonus: 2,
    barricadeBonus: -.12,
    chargeBonus: .08,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.occupationDay,
    title: 'İşgal Günü',
    omen:
        'Çadır, erzak arabası ve nöbet direkleri geliyor; bu kolon dönmeye niyetli değil.',
    objective: 'Meydanı işgal edip köyü askerî idareye almak',
    target: ImperialRaidTarget.center,
    minYear: 4,
    minPopulation: 22,
    attackDelta: .17,
    casualtyDelta: 2,
    lootMultiplier: 1.5,
    groupBonus: 4,
    barricadeBonus: .08,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.stableRaid,
    title: 'Nal ve İp',
    omen: 'Seyisler ordunun arkasında; hedef insan değil köyün hayvanları.',
    objective: 'Ahırı boşaltıp ulaşım gücünü kırmak',
    target: ImperialRaidTarget.stable,
    lootMultiplier: 1.25,
    chargeBonus: .06,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.commandDecapitation,
    title: 'Başsız Köy',
    omen: 'Okçular meydanı değil, meclis kapısını nişanlıyor.',
    objective: 'Köy yönetimini tek darbede çökertmek',
    target: ImperialRaidTarget.townHall,
    minYear: 3,
    attackDelta: .11,
    casualtyDelta: 1,
    groupBonus: 1,
    holdBonus: .08,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.dawnEncirclement,
    title: 'Şafak Çemberi',
    omen: 'Sis çekilirken üç ayrı sancak köyün çevresinde beliriyor.',
    objective: 'Kaçış yollarını kapatıp ev ev aramak',
    target: ImperialRaidTarget.homes,
    minYear: 2,
    attackDelta: .08,
    casualtyDelta: 1,
    groupBonus: 2,
    barricadeBonus: .06,
    rainOnly: true,
  ),
  ImperialRaidScenario(
    kind: ImperialRaidKind.reliefColumn,
    title: 'Yorgun Takviye',
    omen: 'Başka cepheden gelen yaralı bir birlik köyde erzak ve yatak arıyor.',
    objective: 'Yorgun birliği zorla besleyip barındırmak',
    target: ImperialRaidTarget.center,
    minYear: 2,
    attackDelta: -.08,
    lootMultiplier: 1.3,
    groupBonus: 1,
    holdBonus: .05,
    minFavor: .55,
  ),
];

List<ImperialRaidScenario> eligibleImperialRaids(ImperialRaidContext context) =>
    imperialRaidScenarios.where((s) => s.isEligible(context)).toList();

ImperialRaidScenario selectImperialRaidScenario(
  ImperialRaidContext context,
  int seed,
) {
  final eligible = eligibleImperialRaids(context);
  // Demir Saf her bağlamda uygun olduğundan liste boş kalmaz.
  return eligible[seed.abs() % eligible.length];
}
