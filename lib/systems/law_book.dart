import '../buildings/building_type.dart';
import '../buildings/craft.dart';
import 'estate_system.dart';
import 'petition_system.dart';

/// KANUNNAME — köyün yasa defteri.
///
/// Eski "Karar Defteri" bir ayarlar menüsüydü: 17 ferman, beş sekme, her biri
/// aç/kapa bir düğme, altında ↑fayda/↓bedel maddeleri. Bir hüküm değil, bir
/// tercihler paneliydi; canın istediğinde açar, sıkılınca kapardın.
///
/// Kanunname bunun tersi üç ilke üstüne kurulur:
///
///   1. MÜHÜR UCUZ GERİ ALINMAZ. Bir ferman deftere girdiyse o köy artık öyle
///      bir köydür. Toggle yok: geçim hükmü ancak ağır bedelle feshedilir
///      ([LawBook.repealable]), kimliği yazan hüküm hiç bozulmaz.
///   2. MÜREKKEP KURUMADAN YENİSİ YAZILMAZ. Her mühür Divan'ı
///      [LawDef.deliberationDays] gün müzakerede bırakır. Oyunun ritmi bu:
///      "bugün hangi TEK fermanı mühürleyeceğim?"
///   3. KOL SEÇİLMEZ, KİMLİK BİRİKİR. [LawBranch.nizam] ile [LawBranch.dergah]
///      birbirini DIŞLAMAZ (eski tasarımdı, bırakıldı). Köyün ne olduğunu
///      mühürlerin toplamı söyler — bkz. law_compass.dart.
///
/// Mekanik olarak bir mühür = bir [PetitionOption]'ın uygulanması. Dilekçe
/// karar motoru (kaynak deltası, süreli moral, zümre morali+nüfuzu, hafıza
/// bayrağı, zincir dilekçesi) olduğu gibi devralınır — yasa da bir karardır.

/// Defterin BÖLÜKLERİ — artık dışlayan merdivenler DEĞİL, yalnızca konu başlığı.
/// Her yasa hep açıktır; [nizam] ve [dergah] bir arada yaşayabilir. Köyün
/// kimliği bir çatal seçiminden değil, HANGİ yasaları çıkardığından doğar.
enum LawBranch {
  gecim('GEÇİM', '🌾', 'Köy önce doyar, sonra düşünür.'),
  nizam('NİZAM', '⚔', 'Korkulan kapıdan hırsız girmez.'),
  dergah(
    'DERGÂH',
    '☾',
    'Aç karın, kırık gönül; ikisini de aynı kandil ısıtır.',
  );

  final String label;
  final String icon;

  /// Bölüğün kendi sözü — defterde o başlığın altında durur.
  final String motto;
  const LawBranch(this.label, this.icon, this.motto);
}

/// KONSEPT/TEMA — dizin kalabalığını kırmak için. [LawBranch] üç kaba koldur
/// (Geçim 20 hükümle çok kalabalık); tema onu okunur konulara böler. Üst yüzey
/// (altıgen petek) temaları gösterir, içine girince o temanın 3-6 hükmü çıkar.
enum LawTheme {
  toprak('Toprak & Hasat', '🌾'),
  suru('Sürü', '🐑'),
  aile('Aile & Beşik', '👶'),
  koy('Köy Yaşamı', '🤝'),
  asayis('Asayiş & Adalet', '⚔'),
  inanc('İnanç & Dergâh', '☾');

  final String label;
  final String icon;
  const LawTheme(this.label, this.icon);
}

/// Hüküm id'si → tema. Nizam/Dergâh bire bir; Geçim dört temaya bölünür.
const Map<String, LawTheme> kLawTheme = {
  // Toprak & Hasat
  'irrigation': LawTheme.toprak,
  'farmLabor': LawTheme.toprak,
  'sharedHarvest': LawTheme.toprak,
  'cropRotation': LawTheme.toprak,
  'treePlanting': LawTheme.toprak,
  'greenVillage': LawTheme.toprak,
  // Sürü
  'winterFodder': LawTheme.suru,
  'herdGrowth': LawTheme.suru,
  'freeRange': LawTheme.suru,
  // Aile & Beşik
  'familyReunion': LawTheme.aile,
  'familyEncouragement': LawTheme.aile,
  'oneChild': LawTheme.aile,
  'twoChild': LawTheme.aile,
  'slowMaturity': LawTheme.aile,
  // Köy Yaşamı
  'neighborliness': LawTheme.koy,
  'hospitality': LawTheme.koy,
  'peacefulEnd': LawTheme.koy,
  'eldersExemptFromFood': LawTheme.koy,
  'apprenticeship': LawTheme.koy,
  'tradeGuidance': LawTheme.koy,
  'quarantine': LawTheme.koy,
  'hearthWatch': LawTheme.koy,
  'outsideMarriage': LawTheme.aile,
  // Rejim fermanları — YENİ TEMA AÇMA (petek tam 6 yaprak; yedincisi düzeni
  // bozar). Yönetişim hükümleri Köy Yaşamı'na, vergi/zor Asayiş'e yazılır.
  'rejim.meclisDaimi': LawTheme.koy,
  'rejim.mulkTapusu': LawTheme.koy,
  'rejim.ortakAmbar': LawTheme.koy,
  'rejim.muhassil': LawTheme.asayis,
};

/// Bir yasanın o an gündeme gelip gelemeyeceğini köyün HÂLİNDEN okuyan bağlam.
///
/// KURAL: kapılar yalnız DÜNYA şartı okur — "köyde tarla var mı", "ölüm görüldü
/// mü", "suç işlendi mi". Bir kapı ASLA "şu yasa mühürlü mü" diye sormaz; o bir
/// path/skill-tree olurdu ve defter serbest katalog olmaktan çıkardı. (Tek
/// istisna sayılabilecek [memory] bayrakları da dünyada gerçekten olmuş şeyi
/// anlatır: 'cult.active' = köyde bir dergâh gerçekten kuruldu.)
///
/// Boş bağlam (varsayılan) = hiçbir şey bilinmiyor → koşullu hükümler kapalı.
class LawContext {
  final int population;
  final int dayCount;
  final double villageMorale; // 0..1

  /// Ayrı soyad sayısı — köy kaç haneye bölündü (tek aile ise 1).
  final int households;

  /// Yaşam evresi sayımları — beşik/yaşlılık hükümleri buradan okur.
  final int children;
  final int elders;

  /// İşlenmiş tarla parseli (ekili/büyüyen/nadas fark etmez — toprak açıldı mı).
  final int farmTiles;

  /// Köydeki hayvan (inek+koyun+tavuk) sayısı.
  final int animals;

  /// Köy ölümle tanıştı mı — mezar sayısı.
  final int deaths;

  /// Bugüne dek köyde İŞLENMİŞ suç sayısı (yakalansın yakalanmasın). Nizam kolu
  /// bunun üstüne kurulur: suç görülmeden ceza kanunu yazılmaz.
  final int crimesSeen;

  /// Bugüne dek köyde görülmüş hastalık atağı sayısı (veba dahil). Karantina
  /// hükmü bunun üstüne kurulur — köy hastalıkla tanışmadan tecrit konuşulmaz.
  /// [crimesSeen] gibi monoton: iyileşme sayacı geri almaz.
  final int illnessSeen;

  /// Bugüne dek kan davası doğuran ölümcül kavga sayısı. Diyet hükmünün kapısı.
  /// Husumet sonradan sulh olsa da sayaç düşmez: köy o kanı bir kez gördü.
  final int feudsSeen;

  /// Köyün bildiği zanaatlar (bkz. [Craft]).
  final Set<String> knownCrafts;

  /// Ayakta duran (tamamlanmış) bina türleri.
  final Set<BuildingType> buildings;

  /// Köy hafızası bayrakları — dilekçe/ferman sonuçlarının dünyaya yazdığı iz.
  final Set<String> memory;

  const LawContext({
    this.population = 0,
    this.dayCount = 0,
    this.villageMorale = 0.5,
    this.households = 0,
    this.children = 0,
    this.elders = 0,
    this.farmTiles = 0,
    this.animals = 0,
    this.deaths = 0,
    this.crimesSeen = 0,
    this.illnessSeen = 0,
    this.feudsSeen = 0,
    this.knownCrafts = const {},
    this.buildings = const {},
    this.memory = const {},
  });

  bool has(BuildingType t) => buildings.contains(t);
  bool hasAny(List<BuildingType> ts) => ts.any(buildings.contains);
  bool knows(String craft) => knownCrafts.contains(craft);

  /// Su alınacak bir yer var mı (kuyu ya da şadırvan).
  bool get hasWater => hasAny(const [BuildingType.well, BuildingType.fountain]);

  /// Sürünün altına gireceği bir dam var mı.
  bool get hasShelter => hasAny(const [
    BuildingType.barn,
    BuildingType.stable,
    BuildingType.chickenCoop,
  ]);

  /// Köyde bir kandil yanıyor mu — mabet, inanç ehli ya da kurulmuş dergâh.
  bool get faithPresent =>
      hasAny(const [
        BuildingType.church,
        BuildingType.shrine,
        BuildingType.belltower,
        BuildingType.monument,
      ]) ||
      knows(Craft.faith) ||
      memory.contains('cult.active');
}

/// Defterdeki tek bir ferman.
class LawDef {
  final String id;
  final String icon;
  final String title;

  /// Fermanın KENDİ SÖZÜ — buyuruldu ağzından, tırnak içinde. Defterde okunan
  /// hüküm budur; bir tooltip değil, beratın metni.
  final String decree;

  /// Mühür basıldıktan SONRA köyün fısıltısı — tek cümle. Eski ↑fayda/↓bedel
  /// maddelerinin yerini bu alır: sonucu tablodan değil, köyün ağzından duy.
  final String murmur;

  final LawBranch branch;

  /// Mühürün etkisi — dilekçe karar motoruna olduğu gibi verilir.
  ///
  /// [PetitionOption.fx] burada da işler: mühür anında köyde GERÇEKTEN bir şey
  /// olur (mabet dikilir, köy mumlarla toplanır, meydan şenlenir). Uzun süre
  /// hiçbir fermanda fx yoktu ve Kanunname dünyada görünmez kaldı.
  ///
  /// Ama fx NADİR olmalı — her mühür tören olursa hiçbiri tören olmaz. Ölçü:
  /// yalnız kendi metninde kamusal bir an VAAT EDEN hüküm (bkz. dergah.lodge,
  /// dergah.holyDay, peacefulEnd, rejim.*). fx'in kendi kalıcı moral izi vardır
  /// (`_legacyOf`), o yüzden fx eklerken [legacy] ona göre kısılır.
  final PetitionOption seal;

  /// Divan'ın müzakere süresi (oyun günü). Mürekkep kurumadan yeni mühür yok.
  final double deliberationDays;

  /// Köy ruhunda sönmeyen iz (±). Büyük fermanlar geçici moralle kalmaz.
  final double legacy;

  /// Günlük idame — mühürlü kaldığı sürece her gün hazineden/ambardan akan
  /// (negatif = gider, pozitif = gelir). Öşür toplar, sicil vergi alır.
  final int goldPerDay;
  final int foodPerDay;

  /// Aynı [group]'tan tek bir yasa çıkarılır (bir HANE STANCE'i: tek/iki beşik).
  /// Bir tanesi mühürlenince öbürü listeden düşer — bu bir path/foreclosure
  /// DEĞİL, "o kararı zaten verdin" demektir. null = grupsuz, serbest.
  final String? group;

  /// Hükmün DÜNYA KAPISI: köyün hâlinden okunur (dünya şartı, yasa şartı
  /// DEĞİL). null = hep açık. Kapalıyken [gateReason] neden gündeme gelmediğini
  /// söyler. Sıradan hüküm kapalıyken defterde GÖRÜNMEZ (koşul oluşunca belirir);
  /// ağır hüküm ([grave]) kilitli ama görünür durur — ufuk olsun diye.
  final bool Function(LawContext)? gate;
  final String gateReason;

  /// Ağır yasa mı — köyün ne olduğunu ilan eden, geri dönüşü ağır hüküm.
  /// Kapının varlığından TÜRETİLMEZ (artık neredeyse her hükmün kapısı var);
  /// bu ayrı ve bilinçli bir işarettir.
  final bool grave;

  /// Fesihte köy hafızasından SİLİNECEK bayraklar.
  ///
  /// Bilerek `seal.setsFlags`'ten AYRI: bir bayrağı yalnız bu ferman basıyorsa
  /// fesihle kalkmalı, ama aynı bayrağı bir dilekçe de basabiliyorsa (ör.
  /// 'fields.tended', 'migrants.welcomed') fermanı bozmak o dilekçe kararının
  /// izini silemez. Eskiden fesih `setsFlags`'in tamamını siliyordu ve tam da
  /// bunu yapıyordu. Varsayılan boş: fesih hiçbir şey silmez.
  final List<String> repealClears;

  /// BAĞLAYICI — bedeli ne olursa olsun feshedilemez (rejim fermanları).
  /// "Mühür geri alınmaz" tezi gevşetildi: günlük geçim hükümleri bedelle
  /// bozulabilir ([LawBook.repealable]) ama köyün KİMLİĞİNİ yazan hüküm bozulmaz.
  final bool binding;

  const LawDef({
    required this.id,
    required this.icon,
    required this.title,
    required this.decree,
    required this.murmur,
    required this.branch,
    required this.seal,
    this.deliberationDays = 0.75,
    this.legacy = 0,
    this.goldPerDay = 0,
    this.foodPerDay = 0,
    this.group,
    this.gate,
    this.gateReason = '',
    this.grave = false,
    this.binding = false,
    this.repealClears = const [],
  });

  /// Ağır yasa mı — köyün ne olduğunu ilan eden, geri dönüşü ağır hüküm.
  bool get isGrave => grave;
}

// ─── DÜNYA KAPILARI ──────────────────────────────────────────────────────────
// Üst düzey fonksiyon tear-off'ları const'tur → LawDef.gate const kalır.
//
// TASARIM: bir hüküm, DERDİ köyde doğmadan gündeme gelmez. Beş kişilik yeni
// kurulmuş bir köy sürü nizamnamesi de görmez, sürgün fermanı da. Eşikler
// bilerek SAYIDAN ÇOK OLAYA bağlı (ilk ölüm, ilk suç, ilk beşik, açılan tarla)
// — takvim beklemek değil, köyün başından geçen şey defteri açsın.

// ── Toprak & Hasat ──
bool _fieldsAndWater(LawContext c) => c.farmTiles >= 1 && c.hasWater;
bool _fieldsMany(LawContext c) => c.farmTiles >= 3;
bool _fieldsWorn(LawContext c) => c.farmTiles >= 4 && c.dayCount >= 6;
bool _sharedHarvestNeed(LawContext c) => c.farmTiles >= 2 && c.households >= 2;
bool _axeAtWork(LawContext c) =>
    c.has(BuildingType.lumberCamp) || c.knows(Craft.carpentry);
bool _greenAmbition(LawContext c) =>
    c.population >= 12 && c.dayCount >= 10 && c.has(BuildingType.lumberCamp);

// ── Sürü ──
bool _herdSheltered(LawContext c) => c.animals >= 1 && c.hasShelter;
bool _herdBreeding(LawContext c) => c.animals >= 2;
bool _herdCrowded(LawContext c) => c.animals >= 4;

// ── Aile & Beşik ──
bool _marriageableVillage(LawContext c) => c.population >= 5;
bool _cradleMatters(LawContext c) => c.children >= 1 || c.population >= 7;
bool _cradleCrowded(LawContext c) => c.children >= 2 && c.households >= 2;
bool _hasChildren(LawContext c) => c.children >= 1;

// ── Köy Yaşamı ──
/// Köy hastalıkla tanıştı mı — tecrit ancak bulaşan bir şey görülünce konuşulur.
bool _illnessKnown(LawContext c) => c.illnessSeen >= 1;

/// Ateşin sönmesi bir dert olacak kadar köy oldu mu.
bool _hearthMatters(LawContext c) =>
    c.has(BuildingType.firepit) && c.population >= 5 && c.dayCount >= 4;

/// Köyde İKİNCİ bir hane var mı — yani dışarıdan biri gelip yerleşmiş mi.
/// (Köy tek soyla kurulur; ikinci soyadı ancak dışarıdan gelir.) Dışarıya
/// nikâh fermanı bu gerçeğin üstüne oturur.
bool _outsidersSettled(LawContext c) => c.households >= 2 && c.population >= 6;

bool _openDoorReady(LawContext c) =>
    c.population >= 6 && c.has(BuildingType.warehouse);
bool _mortalityKnown(LawContext c) => c.deaths >= 1 || c.elders >= 1;
bool _hasElders(LawContext c) => c.elders >= 1;
bool _craftsToPass(LawContext c) =>
    c.knownCrafts.length >= 2 && c.population >= 6;
bool _craftsToSteer(LawContext c) => c.knownCrafts.length >= 3;

// ── Asayiş (NİZAM) — suç görülmeden ceza kanunu yazılmaz ──
bool _crimeOnce(LawContext c) => c.crimesSeen >= 1;
bool _crimeTwice(LawContext c) => c.crimesSeen >= 2;
bool _crimeRepeated(LawContext c) => c.crimesSeen >= 3 && c.population >= 8;

/// Köy kan gördü mü — diyet ancak bir kan davası doğduktan sonra yazılır.
bool _bloodSpilled(LawContext c) => c.feudsSeen >= 1;
bool _manyHouseholds(LawContext c) => c.households >= 3 && c.dayCount >= 8;

/// Tek Söz gibi sert hükümler ancak köy gerçek bir kasaba olduğunda konuşulur.
bool _establishedTown(LawContext c) => c.population >= 12 && c.dayCount >= 12;

// ── İnanç (DERGÂH) ──
bool _consolationNeeded(LawContext c) => c.deaths >= 1 || c.population >= 8;
bool _faithLit(LawContext c) => c.faithPresent;
bool _faithAndBarn(LawContext c) =>
    c.faithPresent && c.has(BuildingType.warehouse);
bool _faithAndCrime(LawContext c) => c.faithPresent && c.crimesSeen >= 1;

/// Tek İnanç ancak nüfus kök saldığında ve kandil yandığında Meclis'e gelir.
bool _rootedVillage(LawContext c) =>
    c.population >= 10 && c.dayCount >= 10 && c.faithPresent;

// ── Rejim fermanları — KÖYÜN YEMİNİ kapısı ──
// Yemin bir yasa değil, köyün kendi hakkında ettiği ilandır (bkz. regime.dart);
// bayrak köy hafızasına yazılır, yani bu da bir dünya şartıdır.
bool _oathCommune(LawContext c) => c.memory.contains('oath.commune');
bool _oathMarket(LawContext c) => c.memory.contains('oath.market');
bool _oathIronTable(LawContext c) => c.memory.contains('oath.ironTable');
bool _oathSealedHand(LawContext c) => c.memory.contains('oath.sealedHand');

/// Mühür anında meclise toplanan bir zümrenin duruşu. Ritüelin kalbi: fermanı
/// deftere koyduğunda dört zümrenin sözcüsü ne diyor?
enum LawStance { eager, willing, wary, opposed }

/// Zümre morali deltasından duruş — mühür ritüelinde sözcünün yüzü.
LawStance stanceOf(double delta) {
  if (delta >= 0.09) return LawStance.eager;
  if (delta > 0) return LawStance.willing;
  if (delta > -0.06) return LawStance.wary;
  return LawStance.opposed;
}

/// Bir zümrenin mühür masasındaki tek cümlesi. Havuzdan tohumla seçilir
/// (aynı gün aynı ferman aynı cümleyle karşılanır, rebuild'de zıplamaz).
List<String> stanceLines(Estate e, LawStance s) => switch (s) {
  LawStance.eager => switch (e) {
    Estate.laborers => const [
      'Emekçiler öne çıktı: "Bunu biz de yazardık, sen yazdın."',
      'Nasırlı eller masaya vurdu. Bekledikleri buydu.',
    ],
    Estate.artisans => const [
      'Ustalar birbirine baktı, ilk kez gülümsediler: "Tezgâh bunu sever."',
      'Zanaat tarafı mührü görmeden önünü açtı.',
    ],
    Estate.faithful => const [
      'İnananlar ellerini açtı: "Hayırlısı olsun."',
      'Dua tarafından bir onay mırıltısı yükseldi.',
    ],
    Estate.hearth => const [
      'Yaşlılar başını salladı: "Atalarımız da böyle yapardı."',
      'Ocak tarafı rahatladı; bu ferman onların dilinden çıkmış.',
    ],
  },
  LawStance.willing => switch (e) {
    Estate.laborers => const ['Emekçiler itiraz etmedi. Bu bir onaydır.'],
    Estate.artisans => const ['Ustalar omuz silkti: "Zararı yok."'],
    Estate.faithful => const ['İnananlar sustu; suskunlukları rıza.'],
    Estate.hearth => const ['Ocak tarafı kabullendi, gözünü kaçırmadı.'],
  },
  LawStance.wary => switch (e) {
    Estate.laborers => const [
      'Emekçiler ayağını değiştirdi. Söylemiyorlar ama hoşlanmadılar.',
    ],
    Estate.artisans => const [
      'Ustalar birbirine baktı. Bu fermanın hesabını sonra soracaklar.',
    ],
    Estate.faithful => const [
      'İnananlar başını eğdi. Bunu bir sınav sayıyorlar.',
    ],
    Estate.hearth => const ['Ocak tarafı yutkundu. Eve gidince konuşulacak.'],
  },
  LawStance.opposed => switch (e) {
    Estate.laborers => const [
      'Emekçiler ayağa kalktı: "Bunu biz taşırız, sen değil."',
      'Nasırlı el masadan çekildi. Bu bir küslüğün başlangıcı.',
    ],
    Estate.artisans => const [
      'Ustalar kalktı: "Bu ferman tezgâhı keser."',
      'Zanaat tarafı çıkışa yürüdü, mühür daha basılmadan.',
    ],
    Estate.faithful => const [
      'İnananlar yüzünü çevirdi: "Bunun hesabı sende kalmaz."',
      'Dua tarafından sert bir sessizlik geldi. Bu bir bedduaya yakın.',
    ],
    Estate.hearth => const [
      'Yaşlılar bastonunu yere vurdu: "Bu köy böyle bir köy değildi."',
      'Ocak tarafı ayağa kalktı. Bu fermanı bağışlamazlar.',
    ],
  },
};

// ─── DEFTER ─────────────────────────────────────────────────────────────────
// GEÇİM kolu: eski 17 ferman. Metinler korundu (güzeldiler) — kabuk değişti:
// artık sekme değil kademe, toggle değil mühür. requires zinciri defteri bir
// ağaca çevirir: köy önce doyar, sonra ısınır, sonra düşünmeye başlar.

const List<LawDef> kLawBook = [
  // ── GEÇİM · birinci kademe (gün bir açık) ─────────────────────────────────
  LawDef(
    id: 'neighborliness',
    icon: '👋',
    title: 'Komşuluk Beratı',
    decree:
        '"Buyuruldu ki: yolda karşılaşan selam vere. Selamsız geçilen '
        'sokak, insanı kendi köyünde yabancı eder."',
    murmur:
        'Ertesi sabah çeşme başında iki çift laf edildi. Küçük bir şey; '
        'ama köy küçük şeylerden yapılır.',
    branch: LawBranch.gecim,
    deliberationDays: 0.5,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['📜 Komşuluk Beratı deftere girdi. Yollarda selam var.'],
      estateMood: [(Estate.hearth, 0.06), (Estate.laborers, 0.03)],
    ),
  ),
  LawDef(
    id: 'winterFodder',
    gate: _herdSheltered,
    gateReason:
        'Ahırda kışlayacak hayvan yok. Sürü ağıla girsin, kışlık yem '
        'ondan sonra konuşulur.',
    icon: '🌾',
    title: 'Kışlık Yem Fermanı',
    decree:
        '"Buyuruldu ki: harmanın bir payı ahıra ayrıla. Kışın aç kalan '
        'inek, baharda süt vermez."',
    murmur:
        'Ambarcı bir kile ayırdı, kaşlarını çatarak. Sürü kışa tok girecek '
        'ama sofradan o kile eksildi.',
    branch: LawBranch.gecim,
    deliberationDays: 0.5,
    // Murmur "sofradan o kile eksildi" diyor — hüküm de öyle desin. Yem bedava
    // değil: sürü kışa tok girer ([AnimalEntity.kHungerScale] 0.55) ama harmanın
    // payı her gün ambardan ahıra gider. Bedelsizken bu ferman saf kazançtı.
    foodPerDay: -1,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['📜 Kışlık Yem Fermanı deftere girdi. Ahır dolduruldu.'],
      foodDelta: -6, // ilk kile: ahır bir kerede doldurulur
      estateMood: [(Estate.laborers, 0.07), (Estate.hearth, -0.04)],
    ),
  ),
  LawDef(
    id: 'sharedHarvest',
    gate: _sharedHarvestNeed,
    gateReason:
        'Müşterek harman iki hane ve iki tarla ister; tek ocak zaten '
        'müşterektir.',
    icon: '🌾',
    title: 'Müşterek Harman Fermanı',
    decree:
        '"Buyuruldu ki: tarlalar birlikte kaldırıla, geri kalana el '
        'uzatıla. Bir hane aç kalırsa harmanın tadı olmaz."',
    murmur:
        'Harman tek elden kalktı. Kimse geride kalmadı — kimse öne de '
        'geçemedi. Ustalar bunu sessizce not etti.',
    branch: LawBranch.gecim,
    deliberationDays: 0.5,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Müşterek Harman Fermanı deftere girdi. Tarlalar birlikte kalkıyor.',
      ],
      estateMood: [(Estate.laborers, 0.08), (Estate.artisans, -0.04)],
    ),
  ),
  LawDef(
    id: 'irrigation',
    gate: _fieldsAndWater,
    gateReason:
        'Sulanacak tarla ya da su alınacak kuyu yok. Önce toprak '
        'açılsın, kuyu kazılsın.',
    icon: '💧',
    title: 'Su Yolu Fermanı',
    decree:
        '"Buyuruldu ki: kuyudan tarlaya su taşına. Susuz toprak ekmek '
        'vermez; el emeği suyun ardınca gide."',
    murmur:
        'Çiftçiler sıra ile kovayı doldurdu. Ekin yeşerdi — ama sırtlar '
        'da o kovanın altında eğildi.',
    branch: LawBranch.gecim,
    deliberationDays: 0.5,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Su Yolu Fermanı deftere girdi. Kuyudan tarlaya su akıyor.',
      ],
      // Not: eskiden burada 'fields.watered' bayrağı basılıyordu; hiçbir yer
      // okumuyordu. Sulamanın gerçek yürütücüsü policies.irrigation
      // (scene_jobs) — ölü bayrak kaldırıldı.
      estateMood: [(Estate.laborers, 0.06)],
    ),
  ),
  LawDef(
    id: 'farmLabor',
    gate: _fieldsMany,
    gateReason: 'Bir iki tarla için seferberlik ilan edilmez. Ekin genişlesin.',
    icon: '🌾',
    title: 'Ekin Seferberliği Fermanı',
    decree:
        '"Buyuruldu ki: hasat vakti her el tarlaya koşa. Boş gezen kol, aç '
        'kalan sofra demektir."',
    murmur:
        'Meydan boşaldı, tarla doldu. Birkaç zanaatkâr tezgâhından oldu — '
        'ama harman bu yıl kimseyi beklemedi.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Ekin Seferberliği Fermanı deftere girdi. Her el tarlada.',
      ],
      estateMood: [(Estate.laborers, 0.08), (Estate.artisans, -0.06)],
    ),
  ),
  LawDef(
    id: 'hospitality',
    gate: _openDoorReady,
    gateReason:
        'Yabancıya açılan kapının ardında dolu bir ambar olmalı; köy '
        'henüz kendi karnını zor doyuruyor.',
    icon: '🚪',
    title: 'Açık Kapı Fermanı',
    decree:
        '"Buyuruldu ki: yolcuya kapı kapanmaya. Yorgun gelen tuz ekmek '
        'göre; gönlü kalırsa kalsın."',
    murmur:
        'İlk yabancı üç gün sonra geldi. Boş bir evde ocak yandı; meydanda '
        'birkaç ters bakış dolaştı.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Açık Kapı Fermanı deftere girdi. Yolcuya kapı açık.',
      ],
      setsFlags: ['migrants.welcomed'],
      estateMood: [(Estate.artisans, 0.08), (Estate.hearth, -0.06)],
    ),
  ),

  // ── GEÇİM · ikinci kademe ─────────────────────────────────────────────────
  LawDef(
    id: 'familyReunion',
    gate: _marriageableVillage,
    gateReason: 'Yuva kuracak kadar insan yok daha.',
    icon: '💞',
    title: 'Yuva Kurma Beratı',
    decree:
        '"Buyuruldu ki: yalnız kalana eş aranıla, ocağı bir başına '
        'bırakılmaya. Tek başına yanan ateş çabuk söner."',
    murmur: 'Bir hafta içinde iki sönmüş baca yeniden tütmeye başladı.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Yuva Kurma Beratı deftere girdi. Yalnızlar eşleşir.',
      ],
      estateMood: [(Estate.hearth, 0.10)],
    ),
  ),
  LawDef(
    id: 'herdGrowth',
    gate: _herdBreeding,
    gateReason: 'Çoğalacak sürü yok. Önce ağıla hayvan girsin.',
    icon: '🐄',
    title: 'Sürü Beratı',
    decree:
        '"Buyuruldu ki: ağıldaki çift ayrılmaya, yavrusu elinden alınmaya. '
        'Sürü büyürse köy de büyür."',
    murmur:
        'Ağılda ilk buzağı doğdu. Sevindiler — sonra yemliğe bakıp '
        'sustular.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['📜 Sürü Beratı deftere girdi. Ağıl çoğalıyor.'],
      estateMood: [(Estate.laborers, 0.08), (Estate.hearth, 0.03)],
    ),
  ),
  LawDef(
    id: 'cropRotation',
    gate: _fieldsWorn,
    gateReason:
        'Toprak yorulacak kadar ekilmedi. Nadas, çok tarlası olan köyün '
        'derdidir.',
    icon: '🌱',
    title: 'Dönemli Ekim Beratı',
    decree:
        '"Buyuruldu ki: tarlalar sıra ile dinlendirile. Toprağın da bir '
        'nefesi vardır; alması için vermek gerek."',
    // Berat artık gerçekten çalışıyor: hasat edilen tarla nadasa yatar
    // (kFarmFallowDuration), karşılığında balya verimi artar → hakiki takas.
    murmur:
        'Hasat edilen tarla bir süre çıplak dinleniyor. Sofra bir öğün '
        'geç kuruluyor — ama ertesi harman ağır geliyor.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Dönemli Ekim Beratı deftere girdi. Toprak nefes alıyor.',
      ],
      setsFlags: ['fields.tended'],
      estateMood: [(Estate.laborers, 0.07), (Estate.artisans, -0.04)],
    ),
  ),
  LawDef(
    id: 'apprenticeship',
    gate: _craftsToPass,
    gateReason: 'Aktarılacak zanaat birikmedi. Usta olmadan çırak olmaz.',
    icon: '🔨',
    title: 'Çıraklık Beratı',
    decree:
        '"Buyuruldu ki: çocuk babasının örsü başında büyüye. Zanaat sözle '
        'değil, elden ele geçer."',
    murmur:
        'Demircinin oğlu artık örs başında. Gözleri tezgâhta değil, '
        'pencerede — ama elleri işi öğreniyor.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['📜 Çıraklık Beratı deftere girdi. Zanaat soydan iner.'],
      estateMood: [
        (Estate.artisans, 0.10),
        (Estate.laborers, 0.04),
        (Estate.faithful, -0.03),
      ],
    ),
  ),
  // Mutex kardeşler — beşik sayısı. Birini mühürledin mi öbürü ebediyen kapanır.
  LawDef(
    id: 'oneChild',
    gate: _cradleCrowded,
    gateReason: 'Beşik sayısını sınırlamak için önce beşik gerek.',
    icon: '🕯️',
    title: 'Tek Beşik Fermanı',
    decree:
        '"Buyuruldu ki: her ocakta bir beşik sallana, fazlası olmaya. Az '
        'doğur, tok büyüt."',
    murmur:
        'Kile uzun yetti. Ama evlerde adı konmamış bir yas var: analar '
        'sınırı sezdi.',
    branch: LawBranch.gecim,
    group: 'besik',
    deliberationDays: 1.5,
    legacy: -0.02,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Tek Beşik Fermanı deftere girdi. Her ocakta bir beşik.',
      ],
      moraleAmount: -0.03,
      moraleDays: 3,
      estateMood: [(Estate.hearth, -0.10), (Estate.artisans, 0.05)],
    ),
  ),
  LawDef(
    id: 'twoChild',
    gate: _cradleCrowded,
    gateReason: 'Beşik sayısını sınırlamak için önce beşik gerek.',
    icon: '👨‍👩‍👧',
    title: 'İki Beşik Fermanı',
    decree:
        '"Buyuruldu ki: bir damın altında ikiden fazla beşik sallanmaya. '
        'Ölçüsünü bilen ev, kışa dayanır."',
    murmur:
        'Ev kalabalıktan bunalmadı. Üçüncüyü bekleyen ana kapıya küskün '
        'baktı, o kadar.',
    branch: LawBranch.gecim,
    group: 'besik',
    deliberationDays: 1.0,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 İki Beşik Fermanı deftere girdi. Bir damda iki beşik.',
      ],
      estateMood: [(Estate.hearth, -0.03)],
    ),
  ),

  // ── GEÇİM · üçüncü kademe ─────────────────────────────────────────────────
  LawDef(
    id: 'familyEncouragement',
    gate: _cradleMatters,
    gateReason: 'Doğum meselesi henüz köyün gündeminde değil.',
    icon: '💝',
    title: 'Beşik Beratı',
    decree:
        '"Buyuruldu ki: yeni doğana kapı açıla, anasına babasına el '
        'uzatıla. Çocuk sesi duyulmayan köy, kendi kendini unutur."',
    murmur:
        'Beşikler sık sallanmaya başladı. Mumlar sabaha kadar yanıyor; '
        'analar uykusuz ama ev sıcak.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['📜 Beşik Beratı deftere girdi. Doğana kapı açık.'],
      moraleAmount: 0.03,
      moraleDays: 2,
      estateMood: [
        (Estate.hearth, 0.10),
        (Estate.laborers, 0.04),
        (Estate.artisans, -0.04),
      ],
    ),
  ),
  LawDef(
    id: 'tradeGuidance',
    gate: _craftsToSteer,
    gateReason: 'Yönlendirilecek kadar zanaat yok; köy hâlâ tek işin peşinde.',
    icon: '🎯',
    title: 'Eksik Zanaat Fermanı',
    decree:
        '"Buyuruldu ki: köyün boş kalan işine genç yazıla. Değirmen '
        'dönmezse kimse türküyle doymaz."',
    murmur:
        'Boş tezgâhlar el buldu. Bir genç yanlış tezgâhta oturuyor ve '
        'bunu herkes biliyor.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Eksik Zanaat Fermanı deftere girdi. Kıt meslekler doldurulur.',
      ],
      estateMood: [
        (Estate.artisans, 0.08),
        (Estate.laborers, 0.05),
        (Estate.hearth, -0.05),
      ],
    ),
  ),
  LawDef(
    id: 'freeRange',
    gate: _herdCrowded,
    gateReason: 'Serbest otlatma ancak sürü kalabalıklaşınca dert olur.',
    icon: '🐑',
    title: 'Serbest Otlak Fermanı',
    decree:
        '"Buyuruldu ki: hayvan dar ağılda tutulmaya, otlağa salına. Otunu '
        'kendi seçen hayvanın sütü tatlı olur."',
    murmur:
        'Sürü semirdi. Çoban akşamları onları toplamak için tepe tepe '
        'yürüyor ve bundan hiç memnun değil.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['📜 Serbest Otlak Fermanı deftere girdi. Ağıl açıldı.'],
      estateMood: [(Estate.laborers, 0.06), (Estate.hearth, -0.03)],
    ),
  ),
  LawDef(
    id: 'treePlanting',
    gate: _axeAtWork,
    gateReason: 'Balta sesi duyulmadan fidan fermanı yazılmaz.',
    icon: '🌱',
    title: 'Fidan Fermanı',
    decree:
        '"Buyuruldu ki: devrilen her ağacın yerine bir fidan dikile. '
        'Baltanı gölgesinde bilediğin ağaç, sana emanettir."',
    murmur:
        'Balta ağır sallanıyor artık. Odun ambara geç düşüyor — ama orman '
        'kendi yarasını sarıyor.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Fidan Fermanı deftere girdi. Kesilene fidan dikilir.',
      ],
      estateMood: [(Estate.faithful, 0.06), (Estate.laborers, -0.06)],
    ),
  ),

  // ── GEÇİM · dördüncü kademe ───────────────────────────────────────────────
  LawDef(
    id: 'peacefulEnd',
    gate: _mortalityKnown,
    gateReason: 'Köy henüz ölümle tanışmadı.',
    icon: '🕊️',
    title: 'Huzurlu Son Beratı',
    decree:
        '"Buyuruldu ki: ömrünün ucuna gelen köylü kendi damının altında, '
        'kendi yatağında uğurlana. Kimse yolda, yalnız düşmeye."',
    murmur:
        'Ölüm sessiz geldi, ardında dinginlik bıraktı. Yaşlılık kısaldı; '
        'bilgelik olgunlaşmaya vakit bulamıyor.',
    branch: LawBranch.gecim,
    // legacy 0.01 → 0: kalıcı iz artık fx'ten geliyor (_legacyOf(remembrance)
    // = 0.015). İkisini birden yazmak aynı anı iki kez saymak olurdu.
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Huzurlu Son Beratı deftere girdi. Kimse yolda düşmez.',
      ],
      moraleAmount: 0.03,
      moraleDays: 3,
      // Berat bir anma günüyle açılır: köy mumlarla toplanır, KİMSE ölmez.
      fx: PetitionFx.remembrance,
      estateMood: [(Estate.hearth, 0.10), (Estate.faithful, 0.05)],
    ),
  ),
  LawDef(
    id: 'slowMaturity',
    gate: _hasChildren,
    gateReason: 'Çocukluğu uzatılacak çocuk yok.',
    icon: '🐢',
    title: 'Uzun Çocukluk Fermanı',
    decree:
        '"Buyuruldu ki: çocuk zorla büyütülmeye. Vakitsiz tutulan orak '
        'önce kendi elini keser."',
    murmur:
        'Bahçeden çocuk sesi eksilmiyor. İşe uzanacak eller mevsimlerce '
        'gecikecek ve bunu tarlada hissedeceksin.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Uzun Çocukluk Fermanı deftere girdi. Çocukluk uzadı.',
      ],
      estateMood: [(Estate.hearth, 0.06), (Estate.laborers, -0.05)],
    ),
  ),
  LawDef(
    id: 'eldersExemptFromFood',
    gate: _hasElders,
    gateReason: 'Köyde muaf tutulacak yaşlı yok.',
    icon: '🍞',
    title: 'Yaşlıya Saygı Fermanı',
    decree:
        '"Buyuruldu ki: saçı ağarmış olan ortak kilenin hesabından düşüle. '
        'Bir ömür harman kaldıran, ekmeğini kimseden istemez."',
    murmur:
        'Ortak sofra rahatladı. Bir yer boş kaldı; kuşaklar arasına '
        'sessizlik girdi.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Yaşlıya Saygı Fermanı deftere girdi. Yaşlı kileye yazılmaz.',
      ],
      estateMood: [(Estate.hearth, 0.08), (Estate.laborers, -0.04)],
    ),
  ),
  LawDef(
    id: 'greenVillage',
    gate: _greenAmbition,
    gateReason:
        'Köyü baştanbaşa yeşertmek büyük iş; küçük köyün eli buna '
        'varmaz.',
    icon: '🌸',
    title: 'Yeşil Köy Beratı',
    decree:
        '"Buyuruldu ki: yeni yapılan her evin eşiğine çiçek ekile. Göze '
        'güzel görünen, gönle de iyi gelir."',
    murmur:
        'Eşiklerde çiçek açtı, duvar diplerinde arı vızıldıyor. Kimse '
        'itiraz etmedi — nadir bir şey.',
    branch: LawBranch.gecim,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '📜 Yeşil Köy Beratı deftere girdi. Eşiklerde çiçek var.',
      ],
      moraleAmount: 0.02,
      moraleDays: 2,
      estateMood: [(Estate.faithful, 0.05), (Estate.hearth, 0.04)],
    ),
  ),

  // ── GEÇİM · kırılganlık hükümleri ─────────────────────────────────────────
  // Köyün hastalık/ateş/nikâh sistemleri uzun süre kanunnamede karşılıksızdı:
  // dünyada işleyen bir düzenek vardı ama oyuncunun ona dokunacak hiçbir hükmü
  // yoktu. Üçü de o boşluğu kapatır.
  LawDef(
    id: 'quarantine',
    gate: _illnessKnown,
    gateReason:
        'Köy henüz hastalıkla tanışmadı. Tecrit, bulaşan bir şey '
        'görülmeden konuşulmaz.',
    icon: '🌿',
    title: 'Tecrit Fermanı',
    decree:
        '"Buyuruldu ki: ateşlenen kendi damına çekile, kapısına dal asıla. '
        'Bir hane susarsa köy konuşmaya devam eder."',
    murmur:
        'Hasta kapısında bir dal var. İçeriden ses geliyor, kimse girmiyor; '
        'eşiğe bırakılan çanak akşam boşalmış oluyor.',
    branch: LawBranch.gecim,
    deliberationDays: 1.0,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '🌿 Tecrit Fermanı deftere girdi. Hasta kendi damında kalıyor.',
      ],
      moraleAmount: -0.02,
      moraleDays: 3,
      estateMood: [
        (Estate.faithful, 0.06),
        (Estate.laborers, 0.04),
        (Estate.hearth, -0.08), // ana çocuğundan ayrı kalıyor
      ],
    ),
  ),
  LawDef(
    id: 'hearthWatch',
    gate: _hearthMatters,
    gateReason:
        'Sönmesi dert olacak bir ocak yok daha. Önce meydanda ateş '
        'yansın, köy onun başına toplansın.',
    icon: '🪵',
    title: 'Ocak Nöbeti Fermanı',
    decree:
        '"Buyuruldu ki: meydan ateşi sönmeye, odunu vaktinden önce '
        'taşına. Sönmüş ocak, dağılmış köy demektir."',
    murmur:
        'Ateş artık hiç küllenmiyor. Odun ambarı da eskisi kadar dolmuyor; '
        'oduncu bunu her akşam söylüyor.',
    branch: LawBranch.gecim,
    deliberationDays: 0.75,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '🪵 Ocak Nöbeti Fermanı deftere girdi. Meydan ateşi sönmeyecek.',
      ],
      moraleAmount: 0.03,
      moraleDays: 3,
      estateMood: [(Estate.hearth, 0.09), (Estate.laborers, -0.05)],
    ),
  ),
  LawDef(
    id: 'outsideMarriage',
    gate: _outsidersSettled,
    gateReason:
        'Köyde tek ocak var; dışarıya nikâh, ikinci bir hane kurulunca '
        'gündeme gelir.',
    icon: '👰',
    title: 'Dışarıya Nikâh Fermanı',
    decree:
        '"Buyuruldu ki: kervanla gelen yolcuyla nikâh kıyıla, kurulan ocak '
        'köyden sayıla. Kendi içine kapanan soy, kendi içinde tükenir."',
    murmur:
        'Bir gelin kervanla geldi; kendi adını da getirdi. Yaşlılar '
        'düğüne gitti ama sofrada az konuştular.',
    branch: LawBranch.gecim,
    deliberationDays: 1.0,
    legacy: 0.01,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '👰 Dışarıya Nikâh Fermanı deftere girdi. Yalnız kalana kervan yolcularından eş aranır.',
      ],
      moraleAmount: 0.03,
      moraleDays: 3,
      estateMood: [
        (Estate.artisans, 0.10),
        (Estate.laborers, 0.05),
        (Estate.hearth, -0.07), // soy karışıyor; ocak tarafı hoşlanmaz
      ],
    ),
  ),

  // ── DAVA ▸ ⚔ NİZAM ────────────────────────────────────────────────────────
  // Kılıç yolu: köy önce korunur, sonra sayılır, sonra hizaya sokulur. Her
  // basamak bir öncekinin doğal sonucu gibi görünür — merdivenin marifeti bu.
  LawDef(
    id: 'nizam.watch',
    gate: _crimeOnce,
    gateReason: 'Köyde bekçi isteyen bir şey henüz olmadı.',
    icon: '🔥',
    title: 'Gece Bekçisi Fermanı',
    decree:
        '"Buyuruldu ki: gece meydanda bir bekçi dura, sabaha dek uyumaya. '
        'Uyuyan köyün bekçisi uyanık gerek."',
    murmur:
        'Meydanda gece boyu bir ateş yanıyor. Kimse dokunmuyor bu ateşe — '
        'ama herkes onun kimin ateşi olduğunu biliyor.',
    branch: LawBranch.nizam,
    deliberationDays: 1.5,
    legacy: 0.01,
    goldPerDay: -1,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '⚔ Gece Bekçisi Fermanı deftere girdi. Meydanda ateş sönmeyecek.',
      ],
      goldDelta: -3,
      moraleAmount: 0.02,
      moraleDays: 2,
      // 'crime.watch' — suç sistemine köprü: nöbet suç baskısını ×0.55 kısar
      // (scene_crime). Gece Bekçisi bunu PROAKTİF kurar, asayiş dilekçesini
      // beklemeden.
      setsFlags: ['nizam.watch', 'crime.watch'],
      estateMood: [(Estate.hearth, 0.08), (Estate.faithful, -0.05)],
    ),
  ),
  LawDef(
    id: 'nizam.registry',
    gate: _manyHouseholds,
    gateReason:
        'Deftere yazılacak kadar hane yok; herkes zaten birbirini '
        'tanıyor.',
    icon: '📖',
    title: 'Hane Sicili Fermanı',
    decree:
        '"Buyuruldu ki: her hane deftere yazıla; kaç can, kaç kile, kaç '
        'baş. Sayılmayan hane, kaybolan hanedir."',
    murmur:
        'Kâtip kapı kapı dolaştı. Herkes doğru söyledi — kimse kâtibin '
        'yüzüne bakmadı.',
    branch: LawBranch.nizam,
    deliberationDays: 1.5,
    goldPerDay: 2,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '⚔ Hane Sicili Fermanı deftere girdi. Her hane sayıldı, her kile yazıldı.',
      ],
      goldDelta: 6,
      moraleAmount: -0.03,
      moraleDays: 3,
      setsFlags: ['nizam.registry'],
      estateMood: [
        (Estate.artisans, 0.06),
        (Estate.hearth, -0.08),
        (Estate.laborers, -0.05),
      ],
    ),
  ),
  LawDef(
    id: 'nizam.labor',
    gate: _crimeTwice,
    gateReason: 'Tek bir vaka ceza kanunu yazdırmaz.',
    icon: '⛓',
    title: 'Kürek Cezası Fermanı',
    decree:
        '"Buyuruldu ki: suç işleyen zindana atılmaya, işe koşula. Boş '
        'yatan mahkûmdan köye hayır gelmez."',
    murmur:
        'İlk mahkûm taş ocağında. Verimli — kimse buna verimli demiyor '
        'ama herkes böyle düşünüyor.',
    branch: LawBranch.nizam,
    deliberationDays: 2.0,
    legacy: -0.02,
    goldPerDay: 2,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '⚔ Kürek Cezası Fermanı deftere girdi. Suçlu artık taş kırar.',
      ],
      moraleAmount: -0.04,
      moraleDays: 3,
      setsFlags: ['nizam.labor'],
      estateMood: [
        (Estate.laborers, 0.05),
        (Estate.faithful, -0.10),
        (Estate.hearth, -0.05),
      ],
    ),
  ),
  LawDef(
    id: 'nizam.exile',
    gate: _crimeRepeated,
    gateReason: 'Sürgün, suçun tekrarlandığı köyde konuşulur.',
    icon: '🚪',
    title: 'Sürgün Fermanı',
    decree:
        '"Buyuruldu ki: köyün huzurunu bozan yola vurula, bir daha bu '
        'kapıdan girmeye. Çürük elma sepeti bekletmez."',
    murmur:
        'Bir hane sabaha karşı çıktı köyden. Kimse uğurlamaya gelmedi. '
        'Kimse pencereden bakmadı — ama herkes uyanıktı.',
    branch: LawBranch.nizam,
    deliberationDays: 2.0,
    legacy: -0.03,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '⚔ Sürgün Fermanı deftere girdi. Huzuru bozan yola vurulur.',
      ],
      moraleAmount: -0.05,
      moraleDays: 4,
      setsFlags: ['nizam.exile'],
      estateMood: [
        (Estate.hearth, -0.10),
        (Estate.faithful, -0.08),
        (Estate.artisans, 0.04),
      ],
    ),
  ),
  LawDef(
    id: 'nizam.bloodPrice',
    gate: _bloodSpilled,
    gateReason:
        'Köy henüz kan görmedi. Diyet, bir kan davası doğduktan sonra '
        'yazılır — önlem değil, cevaptır.',
    icon: '🩸',
    title: 'Diyet Fermanı',
    decree:
        '"Buyuruldu ki: dökülen kanın bedeli keseden ödene, öcü elle '
        'alınmaya. Kan davası güden hane, köyün değil kendi hasmıdır."',
    murmur:
        'Bedel ödendi, bıçak çekilmedi. Maktulün anası keseyi aldı ve '
        'uzun süre eline baktı.',
    branch: LawBranch.nizam,
    deliberationDays: 1.5,
    legacy: 0.02,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '🩸 Diyet Fermanı deftere girdi. Kanın bedeli artık keseden ödenir.',
      ],
      moraleAmount: 0.03,
      moraleDays: 4,
      setsFlags: ['nizam.bloodPrice'],
      estateMood: [
        (Estate.hearth, 0.08),
        (Estate.faithful, 0.06),
        (Estate.artisans, -0.05), // kese onların kesesi
      ],
    ),
  ),
  LawDef(
    id: 'nizam.sole',
    grave: true,
    icon: '⚑',
    title: 'Tek Söz Fermanı',
    decree:
        '"Buyuruldu ki: bundan böyle divan toplanmaya, dilekçe yazılmaya. '
        'Köyün tek sözü vardır ve o söz senindir."',
    murmur:
        'Meydan sessiz. Kimse itiraz etmiyor. Bunun sebebi rıza değil ve '
        'sen de bunu biliyorsun.',
    branch: LawBranch.nizam,
    gate: _establishedTown,
    gateReason:
        'Küçük bir köy böyle bir hükmü kaldıramaz. Kasaba büyüyüp '
        'Divan gerçek bir güce dönüşünce Meclis gündemine gelir.',
    deliberationDays: 3.0,
    legacy: -0.05,
    seal: PetitionOption(
      label: 'Mührü bas — geri dönüşü yok',
      detail: '',
      resolutionPool: [
        '⚑ TEK SÖZ FERMANI. Köyün tek sözü var artık, o da senin. Kimse '
            'itiraz etmiyor.',
      ],
      moraleAmount: -0.06,
      moraleDays: 6,
      setsFlags: ['nizam.sole', 'council.elders'],
      estateMood: [
        (Estate.hearth, -0.12),
        (Estate.faithful, -0.12),
        (Estate.laborers, -0.05),
        (Estate.artisans, 0.05),
      ],
    ),
  ),

  // ── DAVA ▸ ☾ DERGÂH ───────────────────────────────────────────────────────
  // İman yolu: köy önce durur, sonra toplanır, sonra yalnız bir şeye inanır.
  LawDef(
    id: 'dergah.holyDay',
    gate: _faithLit,
    gateReason: 'Kandil yakılmadan kutsal gün ilan edilmez.',
    icon: '🕯️',
    title: 'Kutsal Gün Fermanı',
    decree:
        '"Buyuruldu ki: haftanın bir günü iş bırakıla, o gün yalnız dua '
        'ede. Durmadan dönen değirmen kendi taşını yer."',
    murmur:
        'O gün tarlaya kimse inmedi. Harman bir gün geriye düştü — ama '
        'akşam meydanda yüzler yumuşaktı.',
    branch: LawBranch.dergah,
    deliberationDays: 1.5,
    legacy: 0.01, // kalanı fx'ten (_legacyOf(remembrance) = 0.015)
    foodPerDay: -1,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '☾ Kutsal Gün Fermanı deftere girdi. Haftanın bir günü iş durur.',
      ],
      moraleAmount: 0.04,
      moraleDays: 3,
      // İLK kutsal gün mühürle birlikte tutulur: köy toplanır, mumlar yanar.
      fx: PetitionFx.remembrance,
      setsFlags: ['holyDay.active'],
      estateMood: [
        (Estate.faithful, 0.12),
        (Estate.hearth, 0.05),
        (Estate.laborers, -0.06),
      ],
    ),
  ),
  LawDef(
    id: 'dergah.lodge',
    gate: _consolationNeeded,
    gateReason: 'Dergâh, köyün teselliye ihtiyaç duyduğu gün gündeme gelir.',
    icon: '⛪',
    title: 'Dergâh Fermanı',
    decree:
        '"Buyuruldu ki: köyün ortasına bir dergâh kurula, kapısı gece de '
        'açık dura. Sığınacak yeri olmayanın inancı da olmaz."',
    murmur:
        'Dergâhın kapısı hiç kapanmıyor. Geceleri içeride biri var — kim '
        'olduğunu kimse sormuyor.',
    branch: LawBranch.dergah,
    deliberationDays: 1.5,
    legacy: 0.02,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: ['☾ Dergâh Fermanı deftere girdi. Kapısı gece de açık.'],
      woodDelta: -20,
      moraleAmount: 0.04,
      moraleDays: 3,
      // Hüküm "kurula" diyorsa köyün ortasına GERÇEKTEN bir mabet dikilir.
      fx: PetitionFx.templeRaised,
      setsFlags: ['cult.active', 'cult.temple'],
      estateMood: [
        (Estate.faithful, 0.14),
        (Estate.hearth, 0.04),
        (Estate.artisans, -0.05),
      ],
    ),
  ),
  LawDef(
    id: 'dergah.tithe',
    gate: _faithAndBarn,
    gateReason:
        'Öşür için hem bir dergâh hem de payı ayrılacak bir ambar '
        'gerek.',
    icon: '🍞',
    title: 'Öşür Fermanı',
    decree:
        '"Buyuruldu ki: her harmandan onda bir dergâha veriler. Veren el, '
        'aldığı günü unutmaz."',
    murmur:
        'Onda bir ayrıldı. Dergâh doydu, ambar inceldi. Emekçiler kileyi '
        'ölçerken konuşmuyor artık.',
    branch: LawBranch.dergah,
    deliberationDays: 2.0,
    goldPerDay: 1,
    foodPerDay: -2,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '☾ Öşür Fermanı deftere girdi. Her harmandan onda bir dergâha.',
      ],
      foodDelta: -10,
      moraleAmount: -0.02,
      moraleDays: 2,
      setsFlags: ['dergah.tithe'],
      estateMood: [
        (Estate.faithful, 0.12),
        (Estate.laborers, -0.09),
        (Estate.artisans, -0.05),
      ],
    ),
  ),
  LawDef(
    id: 'dergah.penance',
    gate: _faithAndCrime,
    gateReason:
        'Tövbe ile bağışlanacak bir suç ya da bağışlayacak bir kandil '
        'yok.',
    icon: '🙏',
    title: 'Tövbe Meydanı Fermanı',
    decree:
        '"Buyuruldu ki: günahını meydanda söyleye, köyün önünde tövbe ede. '
        'Gizli tutulan günah, köyün havasını bozar."',
    murmur:
        'İlk tövbe dün akşamdı. Adam ağladı, köy izledi. Kimse arkasından '
        'konuşmadı — kimse yüzüne de bakmadı.',
    branch: LawBranch.dergah,
    deliberationDays: 2.0,
    legacy: -0.02,
    seal: PetitionOption(
      label: 'Mührü bas',
      detail: '',
      resolutionPool: [
        '☾ Tövbe Meydanı Fermanı deftere girdi. Günah meydanda söylenir.',
      ],
      moraleAmount: -0.03,
      moraleDays: 4,
      setsFlags: ['dergah.penance'],
      estateMood: [
        (Estate.faithful, 0.10),
        (Estate.hearth, -0.09),
        (Estate.artisans, -0.06),
      ],
    ),
  ),
  LawDef(
    id: 'dergah.oneFaith',
    grave: true,
    icon: '⚑',
    title: 'Tek İnanç Fermanı',
    decree:
        '"Buyuruldu ki: bu köyde tek bir yol vardır ve o yoldan sapan '
        'köylü sayılmaya. Kapı herkese açıktı; artık yalnız içeri girene."',
    murmur:
        'Köy bir dergâha döndü. Kimse aç değil, kimse yalnız değil, kimse '
        'de kendi değil.',
    branch: LawBranch.dergah,
    gate: _rootedVillage,
    gateReason:
        'Tek inanç ancak köy kök saldığında konuşulur. Dergâh küçük '
        'bir köye değil, kalabalık bir cemaate hüküm olur.',
    deliberationDays: 3.0,
    // −0.045 çünkü ayin fx'i +0.015 getiriyor; hükmün net izi −0.03 kalsın.
    // Bu fermanın töreni güzel olabilir, bıraktığı iz güzel olamaz.
    legacy: -0.045,
    seal: PetitionOption(
      label: 'Mührü bas — geri dönüşü yok',
      detail: '',
      resolutionPool: [
        '⚑ TEK İNANÇ FERMANI. Köy artık bir dergâh. Kimse yalnız değil, '
            'kimse de kendi değil.',
      ],
      moraleAmount: -0.04,
      moraleDays: 6,
      // Cemaat dizüstü toplanır — köyün tek sesi olduğu an görülsün.
      fx: PetitionFx.cult,
      setsFlags: ['dergah.oneFaith', 'cult.suppressed'],
      estateMood: [
        (Estate.faithful, 0.16),
        (Estate.hearth, -0.12),
        (Estate.artisans, -0.10),
        (Estate.laborers, -0.06),
      ],
    ),
  ),

  // ── REJİM FERMANLARI ────────────────────────────────────────────────────────
  // Yalnız KÖYÜN YEMİNİ edilmişse deftere düşer (dünya kapısı: yemin bir yasa
  // değil, köyün kendi hakkında ettiği ilandır). Her biri kendi rejimini
  // derinleştirir ve BAĞLAYICIDIR — feshi yoktur. Yeminin asıl ödülü budur:
  // uçların gücüne ancak kendini ilan eden köy erişir.
  //
  // Dördü de `grave`: yemin edilmemişken kapıları kapalıdır ama defterde
  // GEREKÇESİYLE durur (bkz. LawBook.visible). Aksi hâlde yeminin ödülü,
  // yemin edilene kadar hiç görünmüyordu — oyuncu neyi kazanacağını
  // bilmeden yemin ediyordu. Ufukta duran ağırlık davetin kendisidir.
  LawDef(
    id: 'rejim.meclisDaimi',
    gate: _oathCommune,
    gateReason:
        'Meclis-i Daimi, ancak sözünü meydana bırakacağına yemin etmiş '
        'bir köyde kurulur.',
    binding: true,
    grave: true,
    icon: '🏛',
    title: 'Meclis-i Daimi Fermanı',
    decree:
        '"Buyuruldu ki: meclis dağılmaya, daim toplu ola. Köyün derdi '
        'kapıda beklemeye — meydanda çözüle."',
    murmur:
        'Divan artık hiç boşalmıyor. Kararlar sensiz de çıkıyor; bazıları '
        'senin vereceğinden iyi, bazıları değil.',
    branch: LawBranch.gecim,
    deliberationDays: 2.5,
    legacy: 0.025, // kalanı şenlik fx'inden (_legacyOf(festival) = 0.015)
    seal: PetitionOption(
      label: 'Mührü bas — sözü meydana bırak',
      detail: '',
      resolutionPool: [
        '🏛 Meclis-i Daimi kuruldu. Köy kendi derdini kendi çözüyor.',
      ],
      moraleAmount: 0.05,
      moraleDays: 6,
      // Söz meydana indi: köy meydanda kutlar. Yemin-kapılı olduğu için nadir.
      fx: PetitionFx.festival,
      setsFlags: ['rejim.meclisDaimi'],
      estateMood: [
        (Estate.laborers, 0.12),
        (Estate.hearth, 0.08),
        (Estate.artisans, -0.04),
      ],
    ),
  ),
  LawDef(
    id: 'rejim.mulkTapusu',
    gate: _oathMarket,
    gateReason:
        'Tapu defteri, kapısını pazara açacağına yemin etmiş köyde '
        'açılır.',
    binding: true,
    grave: true,
    icon: '📜',
    title: 'Mülk Tapusu Fermanı',
    decree:
        '"Buyuruldu ki: her dam, her tarla bir adla yazıla. Yazılan mülk '
        'sahibinindir; alınır, satılır, miras kalır."',
    murmur:
        'Tapu defteri açıldı. Bir hane iki dam birden yazdırdı; öbürü '
        'yazdıracak bir şey bulamadı.',
    branch: LawBranch.gecim,
    deliberationDays: 2.5,
    legacy: -0.02,
    goldPerDay: 3,
    seal: PetitionOption(
      label: 'Mührü bas — mülkü yaz',
      detail: '',
      resolutionPool: [
        '📜 Mülk Tapusu deftere girdi. Artık her damın bir sahibi var.',
      ],
      setsFlags: ['rejim.mulkTapusu'],
      estateMood: [
        (Estate.artisans, 0.14),
        (Estate.hearth, 0.04),
        (Estate.laborers, -0.10),
      ],
    ),
  ),
  LawDef(
    id: 'rejim.ortakAmbar',
    gate: _oathIronTable,
    gateReason: 'Ortak ambar, payı eşit ayıracağına yemin etmiş köyde kurulur.',
    binding: true,
    grave: true,
    icon: '🥣',
    title: 'Ortak Ambar Fermanı',
    decree:
        '"Buyuruldu ki: harman tek ambara gire, sofraya eşit paylarla '
        'çıka. Az yiyen de bir pay alır, çok çalışan da."',
    murmur:
        'Kimse aç kalmadı. Kimse fazladan bir kova da taşımadı — pay '
        'nasılsa eşit.',
    branch: LawBranch.gecim,
    deliberationDays: 2.5,
    legacy: 0.005, // kalanı şenlik fx'inden (_legacyOf(festival) = 0.015)
    seal: PetitionOption(
      label: 'Mührü bas — payı eşitle',
      detail: '',
      resolutionPool: [
        '🥣 Ortak Ambar kuruldu. Sofrada pay eşit, tezgâhta hevesi tartışılır.',
      ],
      moraleAmount: 0.06,
      moraleDays: 8,
      // İlk eşit sofra bir şölenle kurulur. Yemin-kapılı: ömürde bir kez.
      fx: PetitionFx.festival,
      setsFlags: ['rejim.ortakAmbar'],
      estateMood: [
        (Estate.laborers, 0.14),
        (Estate.hearth, 0.06),
        (Estate.artisans, -0.12),
      ],
    ),
  ),
  LawDef(
    id: 'rejim.muhassil',
    gate: _oathSealedHand,
    gateReason:
        'Muhassıl, tek sözün kendisine ait olduğuna yemin etmiş köyde '
        'kapı çalar.',
    binding: true,
    grave: true,
    icon: '👑',
    title: 'Muhassıl Fermanı',
    decree:
        '"Buyuruldu ki: hane hane gezile, pay toplana. Vermeyenin adı '
        'deftere ayrı yazıla."',
    murmur:
        'Muhassıl geçtiği sokakta kapılar kapanıyor. Kese doluyor — '
        'akşamları meydan boşalıyor.',
    branch: LawBranch.nizam,
    deliberationDays: 2.5,
    legacy: -0.05,
    goldPerDay: 5,
    seal: PetitionOption(
      label: 'Mührü bas — payı topla',
      detail: '',
      resolutionPool: [
        '👑 Muhassıl Fermanı deftere girdi. Kese doluyor, sokak susuyor.',
      ],
      moraleAmount: -0.05,
      moraleDays: 8,
      setsFlags: ['rejim.muhassil'],
      estateMood: [
        (Estate.artisans, 0.06),
        (Estate.laborers, -0.12),
        (Estate.hearth, -0.10),
        (Estate.faithful, -0.06),
      ],
    ),
  ),
];

/// Yasanın NE İŞE YARADIĞI — sade, tek cümle. Dizinde adın altında durur;
/// oyuncu fermanın ADINA değil, ETKİSİNE bakarak seçsin (decree şiirsel, bu düz).
const Map<String, String> kLawSummary = {
  'neighborliness':
      'Köylüler yolda selamlaşır; komşuluk bağı ve ocak morali güçlenir.',
  'winterFodder':
      'Harmanın bir payı ahıra ayrılır; sürü kışın aç kalmaz (günde 1 kile gider).',
  'sharedHarvest':
      'Tarlalar elbirliğiyle kaldırılır; kimse hasatta geride kalmaz.',
  'irrigation': 'Kuyudan tarlaya su taşınır; ekin susuz kalmaz, verim artar.',
  'farmLabor': 'Hasatta boşta gezen herkes tarlaya koşar; ürün hızlı kalkar.',
  'hospitality': 'Kapı kervan yolcusuna açılır; yeni haneler köye gelebilir.',
  'familyReunion': 'Gençler yuva kurar; yeni aileler doğar.',
  'herdGrowth': 'Sürüye iyi bakılır; hayvanlar daha hızlı çoğalır.',
  'cropRotation': 'Tarlalar dönüşümlü ekilir; toprak yorulmaz, verim korunur.',
  'apprenticeship': 'Gençler ustalara çırak verilir; zanaat aktarılır, sürer.',
  'oneChild':
      'Her ocakta tek çocuk; nüfus yavaşlar, kile uzun yeter (analar küser).',
  'twoChild': 'Her evde en çok iki çocuk; ölçülü, dengeli büyüme.',
  'familyEncouragement': 'Doğum teşvik edilir; nüfus daha hızlı artar.',
  'tradeGuidance': 'Köyde eksik kalan zanaatlara gençler yönlendirilir.',
  'freeRange': 'Sürü serbest otlar; yem yükü azalır.',
  'treePlanting': 'Boş alanlara fidan dikilir; köy zamanla yeşerir.',
  'peacefulEnd': 'Yaşlılar huzur içinde göçer; doğal ölüm köyü sarsmaz.',
  'slowMaturity': 'Çocukluk uzar; çocuklar geç ama daha sağlam büyür.',
  'eldersExemptFromFood':
      'Yaşlılar yiyecek yükünden muaf tutulur; saygı görür.',
  'greenVillage': 'Köy baştan başa yeşerir; herkesin morali biraz yükselir.',
  'quarantine':
      'Hasta kendi damına kapanır; bulaşma yarıya iner, salgın bir can az alır (o el tarlada eksilir).',
  'hearthWatch':
      'Meydan ateşi vaktinden önce beslenir; sönmez, ama odun daha hızlı tükenir.',
  'outsideMarriage':
      'Yalnız kalana kervanla eş gelir; gelen kendi adıyla yeni bir hane kurar.',
  'nizam.bloodPrice':
      'Ölümcül kavgada kanın bedeli keseden ödenir; kan davası doğmaz (kese boşsa hüküm tutmaz).',
  'nizam.watch':
      'Geceleri bekçi devriye gezer; suç caydırılır (günde 1 akçe gider).',
  'nizam.registry':
      'Her hane deftere yazılır; suçlu kolay bulunur, vergi toplanır (günde +2 akçe; hane küser).',
  'nizam.labor':
      'Yargıya "kürek cezası" hükmü eklenir: mahkûm sürülmez, taş ocağına koşulur. Zindan geliri günde +2 akçe (dua tarafı hoşnutsuz).',
  'nizam.exile': 'Ağır suçlu köyden sürülür; caydırıcı ama ocak ve dua küser.',
  'nizam.sole':
      'Divan ve dilekçe kapanır; tek söz senindir. Köy sesini yitirir (sürekli moral sızıntısı).',
  'dergah.holyDay':
      'Haftada bir dinlenme günü; moral yükselir (günde 1 kile gider, iş yavaşlar).',
  'dergah.lodge':
      'Köyde bir dergâh açılır; gönlü kırık teselli bulur, moral artar.',
  'dergah.tithe':
      'Her harmandan onda bir dergâha ayrılır; günde +1 akçe, −2 kile (emekçi küser).',
  'dergah.penance':
      'Suçlu ceza yerine tövbeyle bağışlanır; dua tarafı hoşnut, ocak değil.',
  'dergah.oneFaith':
      'Tek inanç dayatılır; yoldan sapan köylü sayılmaz (kapı yalnız içeri girene).',
  'rejim.meclisDaimi':
      'Meclis daim toplu; süresi dolan dilekçeyi rejim ne olursa olsun köy çözer, müzakere %30 hızlanır (karar senden çıkmaz).',
  'rejim.mulkTapusu':
      'Mülk sahibine yazılır; birikmiş servet kendi kazancını getirir, makas açılır. Hazineye günde +3 akçe (emekçi küser).',
  'rejim.ortakAmbar':
      'Harman tek ambardan eşit dağıtılır; açlık eşiği yarıya iner (kimse aç kalmaz) ama üretim hevesi düşer.',
  'rejim.muhassil':
      'Hane hane vergi toplanır; günde +5 akçe (moral düşer, huzursuzluk kaynar).',
};

/// Defter sorguları — UI ve sahne aynı kurallardan okusun diye tek yerde.
abstract final class LawBook {
  /// Kanunname bir kamp eylemi değildir: yazılı hüküm çıkarabilmek için köyün
  /// önce kalıcı bir yönetim makamı kurması gerekir. Nüfus tek başına yetmez;
  /// Belediye bu ilerleme eşiğinin dünyadaki görünür karşılığıdır.
  static bool governanceReady(LawContext ctx) =>
      ctx.buildings.contains(BuildingType.townhall);

  /// Yasanın sade "ne işe yarar" açıklaması (yoksa boş).
  static String summary(String id) => kLawSummary[id] ?? '';

  static LawDef? byId(String id) {
    for (final l in kLawBook) {
      if (l.id == id) return l;
    }
    return null;
  }

  static List<LawDef> ofBranch(LawBranch b) => [
    for (final l in kLawBook)
      if (l.branch == b) l,
  ];

  /// Bir hükmün teması — haritada yoksa koluna göre (nizam/dergah bire bir).
  static LawTheme themeOf(LawDef l) =>
      kLawTheme[l.id] ??
      switch (l.branch) {
        LawBranch.nizam => LawTheme.asayis,
        LawBranch.dergah => LawTheme.inanc,
        LawBranch.gecim => LawTheme.koy,
      };

  static List<LawDef> ofTheme(LawTheme t) => [
    for (final l in kLawBook)
      if (themeOf(l) == t) l,
  ];

  /// Bu yasa DEFTERDE zaten var mı (mühürlü)?
  static bool isEnacted(LawDef l, Set<String> sealed) => sealed.contains(l.id);

  /// Bir grubun stance'i başka bir yasayla zaten belirlenmiş mi (ör. beşik)?
  /// path/foreclosure değil — "o kararı zaten verdin".
  static bool groupTaken(LawDef l, Set<String> sealed) {
    if (l.group == null) return false;
    for (final o in kLawBook) {
      if (o.id != l.id && o.group == l.group && sealed.contains(o.id)) {
        return true;
      }
    }
    return false;
  }

  /// Ağır yasa kapısı köyün hâlince kapalı mı (henüz gündeme gelmedi)?
  static bool gateLocked(LawDef l, LawContext ctx) =>
      l.gate != null && !l.gate!(ctx);

  /// Bu yasa ŞU AN çıkarılabilir mi? Serbest katalog: mühürlü değil + grubu
  /// başkasınca tutulmamış + (varsa) ağır yasa kapısı köyce açık. Sıra/path YOK.
  static bool available(LawDef l, Set<String> sealed, LawContext ctx) =>
      !isEnacted(l, sealed) && !groupTaken(l, sealed) && !gateLocked(l, ctx);

  /// Defterde görünmeli mi?
  ///   • Mühürlü olan HEP görünür (nişanıyla).
  ///   • Grubu başkasınca tutulan gizlenir ("o kararı zaten verdin").
  ///   • Kapısı kapalı SIRADAN hüküm gizlenir — köyün derdi doğunca BELİRİR.
  ///     Beş kişilik köy sürgün fermanını görmez; defter köyle birlikte açılır.
  ///   • Kapısı kapalı AĞIR hüküm ([LawDef.grave]) kilitli ama GÖRÜNÜR durur —
  ///     oyuncunun ufkunda bir ağırlık olsun, gerekçesi de yanında yazsın.
  static bool visible(LawDef l, Set<String> sealed, LawContext ctx) {
    if (isEnacted(l, sealed)) return true;
    if (groupTaken(l, sealed)) return false;
    if (gateLocked(l, ctx)) return l.grave;
    return true;
  }

  /// Köyün ŞU AN gündeminde olan (görünür + çıkarılabilir) hükümler — "yeni
  /// hüküm gündeme geldi" bildirimi ve defter sayaçları buradan okur.
  static List<LawDef> openAgenda(Set<String> sealed, LawContext ctx) => [
    for (final l in kLawBook)
      if (available(l, sealed, ctx)) l,
  ];

  /// Bu hüküm bedelle FESHEDİLEBİLİR mi?
  ///
  /// "Her mühür ebediyen geri alınmaz" tezi gevşetildi: günlük GEÇİM hükümleri
  /// bozulabilir — ama bedava değil (müzakere yanar, moral iz bırakır, köy
  /// hafızası tutar; bkz. scene_regime._repealLaw). Kimliği yazan hükümler
  /// (dava kolları, ağır fermanlar, rejim fermanları) bağlayıcıdır: köy bir kez
  /// öyle bir köy olmuştur.
  static bool repealable(LawDef l) =>
      !l.grave && !l.binding && l.branch == LawBranch.gecim;

  /// Mühürlü fermanların günlük idamesi — (altın, yiyecek). Öşür toplar, gece
  /// bekçisi yer, sicil vergi alır.
  static (int, int) dailyUpkeep(Set<String> sealed) {
    var gold = 0, food = 0;
    for (final l in kLawBook) {
      if (!sealed.contains(l.id)) continue;
      gold += l.goldPerDay;
      food += l.foodPerDay;
    }
    return (gold, food);
  }
}
