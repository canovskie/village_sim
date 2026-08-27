import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../farm/farm_tile.dart';
import '../scene/scene_data.dart';
import 'reckoning.dart';
import 'village_year.dart';

/// Köy Akışı — bol görev + politika-odaklı Tüzük ilerlemesi (no-fail).
///
/// Tasarım: `ObjectiveTracker`'ın (artık emekli) zenginleştirilmiş hâli.
/// Görevler bildirimsel `check`'lerle tamamlanır; her görev bir **görsel ödül**
/// taşır (kaynak DEĞİL). Köyün kimlik kademesi (charterTier) AĞIRLIKLA çıkarılan
/// politikalara (berat) bağlıdır → ilerleme yönetişim-odaklı. Hiçbir görev
/// başarısız olmaz, kademe yalnızca ilerler.

/// Görev kategorisi — panel ikonlandırması / gruplama için.
enum QuestCategory {
  founding,
  production,
  population,
  social,
  governance,
  beauty,
}

/// Görsel ödül yoğunluğu — scene_flow `_grantVisualReward` bunu FX + decor
/// kombosuna çevirir (kaynak yok). sparkle<bloom<festival<landmark.
enum VisualReward { sparkle, bloom, festival, landmark }

/// Adımın DÜNYADAKİ hedefi — "nereye bakacağım" sorusunun cevabı.
///
/// Kuruluş adımları metin olarak doğruydu ama ekranda hiçbir yeri
/// göstermiyordu: "ağaçların dibine kur" hangi ağaçlar? Oyuncu cümleyi okuyup
/// ekranda arıyordu. Bu enum, adımı bir YERE bağlar; sahne onu çözer, çizim
/// oraya sakin bir işaret koyar.
///
/// Bilinçli olarak DAR tutuldu: her adıma özel bir işaret türü değil, birkaç
/// genel hedef. Yeni adım eklerken buradan birini seç; uymuyorsa işaretsiz
/// bırak (zaman/izleme adımlarında işaret zaten yanlış olur).
enum QuestPointer {
  /// İşaret yok — zaman geçmesini ya da izlemeyi isteyen adımlar.
  none,

  /// Orman kenarı — oduncu kulübesinin dikileceği yer.
  forest,

  /// Ocak (ateş yeri) — pişirme/toplanma adımları.
  hearth,

  /// Ateş çevresindeki kurucu saz yatakları.
  reedBeds,

  /// Köyün merkezi (ocak varsa orası, yoksa kurucuların durduğu yer) —
  /// "buraya bir şey dik" adımları.
  villageCenter,
}

/// Adımın istediği ARAYÜZ KAPISI — ne dünyada bir yer, ne bir inşa kartı.
///
/// Bugün tek kullanıcısı yönetişim ve sebebi tam olarak bu: berat bir bina
/// değil, Köy Defteri'nin içindeki bir hüküm. Bu hedef kuruluşta görünmez;
/// Belediye kurulduktan sonra yazılı yönetime geçişi öğretir.
enum QuestUi {
  none,

  /// Köy Defteri → KANUNNAME rafı. Defter kapalıysa önce onun kapısı.
  lawBook,
}

/// Tek bir görev — bildirimsel, durağan.
class Quest {
  final String id;
  final String icon;
  final String label;
  final String hint;
  final QuestCategory category;

  /// Bu iş hesaplaşmadaki hangi kefeyi besliyor.
  ///
  /// Her görev tam birincil eksen taşır; bileşik ana meseleler başka kefeleri
  /// de ölçebilir ama panelde oyuncuya tek, okunaklı bir yön gösterilir.
  final ReckoningAxis axis;

  /// Hangi kimlik kademesinde açılır (charterTier >= tier ise görünür).
  final int tier;
  final bool Function(QuestContext) check;
  final VisualReward reward;

  /// Stratejik faz kapısı. Yılın gelmesi görevi TAMAMLAMAZ; yalnız görünür
  /// kılar. [check] daima en az iki mevcut sistemde etkin sonuç arar.
  final int minYear;
  final bool capstone;

  /// Bu görevi KİM istiyor — kurucu kadrodan bir meslek ([VillagerType]).
  ///
  /// Görev listesi bir alışveriş listesi olmaktan çıkıp köyün insanlarının
  /// ağzından çıkmasının tek mekanizması bu. `null` ise görev köyün geneline
  /// aittir (geç oyun kademeleri böyle: artık kimse tek tek istemez, köy ister).
  ///
  /// Sahne bu tipten YAŞAYAN bir köylü bulur; bulamazsa görev sessizce
  /// isimsiz görünür — kurucu ölmüş olabilir, görev yine de durur.
  final VillagerType? speaker;

  /// Adımın istediği İNŞA KARTI — arayüz tarafının işareti.
  ///
  /// Dünyadaki işaret ([pointer]) "nereye" sorusunu cevaplıyor; bu alan "neye
  /// tıklayacağım"ı. İkisi ayrı sorular ve ikisi de cevapsız kalırsa adım
  /// cümlesi doğru olsa bile oyuncu ekranda arar: "Ateş Yeri" kartı altı
  /// kategoriden birinin içinde, üstelik kart görünür olsun diye önce doğru
  /// sekmeye geçmek gerekir.
  ///
  /// null = adımın inşayla işi yok (iş verme / izleme / zaman adımları).
  final BuildingType? buildTarget;

  /// Adımın istediği ARAYÜZ KAPISI (bkz. [QuestUi]).
  final QuestUi uiTarget;

  /// ÖĞRETİCİ BU ADIMA EŞLİK EDER Mİ.
  ///
  /// Kuruluşun tamamı bir süre rehberliydi: dokuz adımın dokuzunda da spot
  /// açılıyordu ve oyuncu köyü kurarken sürekli birinin parmağını izliyordu.
  /// Öğretici öğretmiyor, EŞLİK EDİYORDU.
  ///
  /// Kuruluşta yalnız ÜÇ adım rehberli: bir yapıyı haritaya kurmak (ocak),
  /// barınağın ayrı bir karar olduğu (çadır) ve işin binaya bağlı olduğu
  /// (oduncu kulübesi). Dördüncü rehber çok sonra, Belediye kurulunca yazılı
  /// yönetimin başladığını göstermek için gelir.
  final bool guided;

  /// KURUCUNUN AĞZINDAN — adım açılınca [speaker] bunu dünyada söyler.
  ///
  /// Neden havuz değil de tek cümle (bkz. voice.dart'ın varyant kuralı):
  /// kuruluş bir ANLATI, ambiyans değil. "Ateşi yak"ın gerekçesi her oyunda
  /// aynı olmalı; rastgele varyant burada karakteri değil belirsizliği artırır.
  /// Ambiyans cümleleri (selam, dedikodu, kutlama) havuzdan gelmeye devam eder.
  ///
  /// null → köylü susar, yalnız kart konuşur.
  final String? voice;

  /// Adım bitince aynı kişinin karşılığı — emek görülmeden kapanmasın.
  final String? thanks;

  /// Adımın dünyadaki hedefi (bkz. [QuestPointer]). Varsayılan işaretsiz:
  /// geç oyun kademelerinde köy zaten kurulmuş, oyuncu nereye bakacağını
  /// biliyor; işaret orada yol göstermez, dırdır eder.
  final QuestPointer pointer;

  const Quest({
    required this.id,
    required this.icon,
    required this.label,
    required this.hint,
    required this.category,
    required this.axis,
    required this.tier,
    required this.check,
    required this.reward,
    this.minYear = 1,
    this.capstone = false,
    this.speaker,
    this.pointer = QuestPointer.none,
    this.buildTarget,
    this.uiTarget = QuestUi.none,
    this.guided = false,
    this.voice,
    this.thanks,
  });

  bool isAvailable(QuestContext context) =>
      tier <= context.charterTier && minYear <= context.year;
}

/// Görevlerin baktığı köy durumu — zengin snapshot.
class QuestContext {
  final List<BuildingEntity> buildings;
  final List<FarmTile> farmTiles;
  final int population;
  final ResourceBundle stock;
  final VillagePolicies policies;
  final int decorCount;
  final int charterTier;

  /// Bilinen zanaat sayısı (bkz. [Craft]) — geç oyun görevleri köyün NE
  /// KURDUĞUNA değil NE BİLDİĞİNE de bakar; zanaat kaybı gerçek bir risk
  /// olduğu için bu sayı tek yönlü ilerlemez.
  final int craftCount;

  /// Oduncu tarafından yere indirilmiş kütük sayısı. Kuruluşta oduncu
  /// kulübesinin gerçekten çalıştığını kanıtlamak için tutulur; başlangıçtaki
  /// odun stoğu bu bilgiyi vermez.
  final int woodHarvested;

  /// Döşenmiş yol karesi — kasabalaşmanın en somut fiziksel izi.
  final int roadCount;

  /// Köy bir REJİM kimliği kazandı mı (ılımlı/merkez değil). Kimlik seçilmez,
  /// mühürlerin toplamından doğar (bkz. political compass) — bu yüzden geç
  /// oyunun "artık bir duruşun var" görevi.
  final bool regimeNamed;

  /// Kaçıncı gün — "ilk geceyi çıkar" gibi zaman adımları için.
  final int dayCount;

  /// Ateş çevresinde kurulmuş saz yatakları. İlk gece görevi yalnız takvime
  /// değil, her kurucunun gerçekten yatağı olmasına bakar.
  final int reedBedCount;

  /// Kuruluşta çadırın yetersizliğini öğreten güvenli hastalık gösterildi mi.
  final bool foundingTentIllnessTriggered;

  /// Yol ağının AYNI bağlı bileşenine komşu en yüksek üretim noktası sayısı.
  /// Ham yol karesi değil, yolun köyde neyi birbirine bağladığını ölçer.
  final int connectedProductionSites;

  // ── HANELER & HESAPLAŞMA (geç oyun) ───────────────────────────────────────
  //
  // Geç kademeler bir inşa listesine dönüşmüştü: on iki görevin sekizi "şu
  // binayı dik"ti. Oyunun en güçlü tarafı — dilekçe, kanunname, haneler —
  // merdiveni sürmüyor, yalnız süslüyordu. Aşağıdaki üç alan merdivenin son
  // basamaklarını KARARLARA bağlar; hiçbiri bir binayla kapatılamaz.

  /// Sana borçlu (sadık) hane sayısı.
  final int loyalHouses;

  /// Elini ya da ürününü çekmiş hane sayısı (el çekti/ambar/kopuş).
  final int withheldHouses;

  /// Köydeki hane sayısı — "bütün haneler" ölçüleri için payda.
  final int houseCount;

  /// Köyün hesaplaşmadaki dört iç kefesi (0..1). Görevler kapanışın
  /// türetilmiş gücünü değil yalnız, onu oluşturan karar alanlarını da okur.
  final double unity;
  final double charter;
  final double grit;
  final double legacy;

  /// Köyün hesaplaşmadaki bileşik gücü (0..1).
  final double standing;

  /// Geride bırakılmış kış + imparatorluk baskısı sayısı. Bu sayı tek başına
  /// hiçbir görevi bitirmez; toparlanma görevinde bugünkü rıza ve ağırlıkla
  /// birlikte kullanılır.
  final int pressuresWeathered;

  /// Kurucu meslek → yaşayan köylünün adı. Görev metnini o kişinin ağzına
  /// koymak için (bkz. [Quest.speaker]).
  final Map<VillagerType, String> speakerNames;

  const QuestContext({
    required this.buildings,
    required this.farmTiles,
    required this.population,
    required this.stock,
    required this.policies,
    required this.decorCount,
    required this.charterTier,
    this.craftCount = 0,
    this.woodHarvested = 0,
    this.roadCount = 0,
    this.regimeNamed = false,
    this.dayCount = 1,
    this.reedBedCount = 0,
    this.foundingTentIllnessTriggered = false,
    this.connectedProductionSites = 0,
    this.loyalHouses = 0,
    this.withheldHouses = 0,
    this.houseCount = 0,
    this.unity = 0,
    this.charter = 0,
    this.grit = 0,
    this.legacy = 0,
    this.standing = 0,
    this.pressuresWeathered = 0,
    this.speakerNames = const {},
  });

  int get enactedPolicies => policies.enactedCount;
  int get year => yearOf(dayCount);
  bool has(BuildingType t) => buildings.any((b) => b.type == t);
  bool hasRole(BuildingRole r) => buildings.any((b) => b.fn?.role == r);

  int get tentCapacity => buildings
      .where((b) => b.type == BuildingType.tent)
      .fold(0, (sum, b) => sum + (b.fn?.housingCapacity ?? 0));
}

/// Aynı kesintisiz yol bileşenine değen en yüksek üretim noktası sayısı.
///
/// Saf tutulur: sahne kendi [RoadSystem] nesnesini taşımadan yalnız tamamlanmış
/// yol koordinatlarını verir; görev ve test tam olarak aynı bağlantı kuralını
/// kullanır. Toplama, işleme ve pazar üretim dolaşımıdır. Konut/süs/depo,
/// kapısında yol olsa da üretim noktası sayılmaz.
int connectedProductionSiteCount({
  required List<BuildingEntity> buildings,
  required Iterable<(int, int)> roadTiles,
}) {
  final sites = buildings.where((b) {
    return switch (b.fn?.role) {
      BuildingRole.gathering ||
      BuildingRole.processing ||
      BuildingRole.trade => true,
      _ => false,
    };
  }).toList();
  final unvisited = roadTiles.toSet();
  if (sites.length < 3 || unvisited.isEmpty) return 0;

  var best = 0;
  while (unvisited.isNotEmpty) {
    final component = <(int, int)>{};
    final stack = <(int, int)>[unvisited.first];
    unvisited.remove(stack.first);
    while (stack.isNotEmpty) {
      final tile = stack.removeLast();
      component.add(tile);
      final (c, r) = tile;
      for (final next in [(c - 1, r), (c + 1, r), (c, r - 1), (c, r + 1)]) {
        if (unvisited.remove(next)) stack.add(next);
      }
    }

    var connected = 0;
    for (final b in sites) {
      if (_buildingTouchesRoad(b, component)) connected++;
    }
    if (connected > best) best = connected;
  }
  return best;
}

bool _buildingTouchesRoad(BuildingEntity building, Set<(int, int)> roads) {
  for (var c = building.col; c < building.col + building.cols; c++) {
    if (roads.contains((c, building.row - 1)) ||
        roads.contains((c, building.row + building.rows))) {
      return true;
    }
  }
  for (var r = building.row; r < building.row + building.rows; r++) {
    if (roads.contains((building.col - 1, r)) ||
        roads.contains((building.col + building.cols, r))) {
      return true;
    }
  }
  return false;
}

/// Bir görevin panel için durum snapshot'u.
class QuestState {
  final Quest quest;
  final bool completed;

  /// İlk henüz tamamlanmamış (açık) görev mi — UI vurgular.
  final bool active;

  /// Görevi isteyen köylünün adı — yaşayan bir karşılığı varsa dolu.
  final String? speakerName;
  const QuestState(this.quest, this.completed, this.active, {this.speakerName});
}

/// Köyün kimlik kademesi tanımı — ad + ilerleme eşiği.
class CharterTier {
  final String name;
  final String icon;

  /// Bu kademeye geçmek için gereken minimum yürürlükteki politika sayısı.
  final int minPolicies;

  /// + gereken toplam tamamlanmış görev sayısı.
  final int minQuests;
  const CharterTier(this.name, this.icon, this.minPolicies, this.minQuests);
}

class QuestBook {
  /// Kimlik kademeleri — ilerleme AĞIRLIKLA politikaya bağlı (mid+ kademeler
  /// berat ister), kuruluş (0→1) görev-sayısı ile.
  /// EŞİKLER ULAŞILABİLİR OLMALI: bir kademenin `minQuests`'i, ONDAN ÖNCEKİ
  /// kademelerde açılan toplam görev sayısını AŞAMAZ (üst kademe görevleri
  /// ancak o kademeye geçilince açılır — aşarsa merdiven kilitlenir).
  /// Bugünkü dağılım: t0:7 t1:5 t2:7 t3:5 t4:6 t5:6 → kümülatif
  /// 7/12/19/24/30/36. (Kuruluş 5→12→9→8: bkz. tier 0 başlığı.)
  ///
  /// Eşik ayrıca NEFES payı bırakmalı. Tavana "bir görev hariç hepsi" diye
  /// oturursa, kovan/çiçekçi gibi isteğe bağlı bir görevi atlayan oyuncu
  /// merdivenin sonuna hiç varamaz ve sebebini de anlayamaz (görev listesi
  /// tamamlananları gizliyor). Her kademede 3-4 görevlik pay bilinçli.
  static const List<CharterTier> tiers = [
    CharterTier('Yeni Yakılan Ocak', '🔥', 0, 0),
    CharterTier('Kapısı Açık Köy', '🏡', 0, 5),
    CharterTier('Davulu Duyulan Kasaba', '🎏', 2, 9),
    CharterTier('Harmanı Taşan Kasaba', '🌟', 4, 15),
    // ── GEÇ OYUN ───────────────────────────────────────────────────────────
    // Buraya kadar merdiven "köyü kur"du; bundan sonrası "köyü bir yer yap".
    // Eşikler politikaya daha ağır yaslanır: geç oyun bina dikmekle değil,
    // yönetişimin oturmasıyla ilerler (kademe adları da onu söylüyor).
    CharterTier('Adı Duyulan Kaza', '⚖️', 6, 19),
    CharterTier('Sancağı Olan Şehir', '👑', 8, 25),
  ];

  static int get maxTier => tiers.length - 1;

  /// completedCount + enactedPolicies → ulaşılan en yüksek kademe.
  static int charterTier(int completedCount, int enactedPolicies) {
    var t = 0;
    for (var i = 1; i < tiers.length; i++) {
      if (enactedPolicies >= tiers[i].minPolicies &&
          completedCount >= tiers[i].minQuests) {
        t = i;
      } else {
        break;
      }
    }
    return t;
  }

  static CharterTier tierOf(int t) => tiers[t.clamp(0, maxTier)];

  /// Bir sonraki kademe (varsa) — panel "ilerleme ipucu" için.
  static CharterTier? nextTier(int t) => t < maxTier ? tiers[t + 1] : null;

  /// Açık kademedeki (tier <= charterTier) tamamlanmamış görevler — panel akışı.
  /// İlki "active" işaretlenir. Tamamlananlar listeden düşer (temiz to-do hissi).
  static List<QuestState> activeQuests(
    QuestContext ctx,
    Set<String> completed,
  ) {
    final res = <QuestState>[];
    var marked = false;
    for (final q in all) {
      if (!q.isAvailable(ctx)) continue;
      if (completed.contains(q.id)) continue;
      final active = !marked;
      marked = true;
      final sp = q.speaker;
      res.add(
        QuestState(
          q,
          false,
          active,
          speakerName: sp == null ? null : ctx.speakerNames[sp],
        ),
      );
    }
    return res;
  }

  /// Açık kademede yapılabilir iş kalmadıysa sıradaki yıl kapılı meseleyi
  /// görünür tutar. Oyuncu hedefin kaybolduğunu değil, neye hazırlandığını görür.
  static Quest? upcomingQuest(QuestContext ctx, Set<String> completed) {
    for (final q in all) {
      if (completed.contains(q.id)) continue;
      if (q.tier > ctx.charterTier) continue;
      if (q.minYear > ctx.year) return q;
    }
    return null;
  }

  // ── Görev havuzu ──────────────────────────────────────────────────────────
  static const List<Quest> all = [
    // ── Tier 0 — Yeni Ocak (KURULUŞ) ─────────────────────────────────────
    // Sekiz adım. Bu liste üç kez küçüldü ve her seferinde aynı sebeple:
    //
    // (1) Beş "şu binayı dik" görevinden ibaretti; arada dakikalarca hiçbir şey
    //     olmuyordu → on iki mikro adıma bölündü.
    // (2) On iki adımın üçü "şu köylüye şu işi ver"di. Kâğıtta karar, oyunda
    //     MİKRO KONTROL: köy artık kendi açlığına bakıyor (bkz. scene_jobs
    //     `_foragerTarget`/`_cookTarget`), oyuncu sepet dağıtmıyor. O üç adım
    //     düştü. İlk berat da Belediye öncesi yazılı kanun olmayacağı için
    //     kuruluşun dışına, Belediye adımının hemen arkasına taşındı.
    //
    // İlk DÖRT adım rehberli ([Quest.guided]) ve sırası bilinçli: ocak (bir
    // yapıyı haritaya kur) → saz yatak (geceyi dünyada gör) → çadır (barınak
    // ayrı bir karar) → oduncu kulübesi (iş binaya bağlı, kadroya değil).
    // Kuruluş boyunca Kanunname anlatılmaz.
    Quest(
      id: 'firepit',
      icon: '🔥',
      label: 'Ocağı yak',
      hint: 'Alttaki İnşa düğmesini aç, Ateş Yerini seç ve köyün ortasına kur.',
      category: QuestCategory.founding,
      axis: ReckoningAxis.grit,
      tier: 0,
      speaker: VillagerType.priest,
      reward: VisualReward.sparkle,
      check: _firepit,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.firepit,
      guided: true,
      voice: 'Yolun sonu burası. Ateşi yak da burası bir yer olsun.',
      thanks: 'Ateş yandı. Artık dönülecek bir yerimiz var.',
    ),
    Quest(
      id: 'firstNight',
      icon: '🌙',
      label: 'Saz yatakta sabahla',
      hint:
          'Ateşin çevresindeki saz yataklara bak. İlk gece herkes burada '
          'uyusun; herkes uzanınca bu ilk gece hemen sabaha saracak.',
      category: QuestCategory.founding,
      axis: ReckoningAxis.unity,
      tier: 0,
      speaker: VillagerType.priest,
      reward: VisualReward.festival,
      check: _survivedFirstNight,
      pointer: QuestPointer.reedBeds,
      guided: true,
      voice: 'Bu gece sazın üstünde yatacağız. Ateş sönmesin, sabahı görelim.',
      thanks: 'Sabah oldu. Şimdi herkese kuru bir örtü gerekecek.',
    ),
    Quest(
      id: 'tent',
      icon: '⛺',
      label: 'Herkese çadır kur',
      hint:
          'Her çadır iki kişi barındırır. Çadırları nüfusun tamamına yetecek '
          'sayıda kur; bir usta işi kendiliğinden alır.',
      category: QuestCategory.founding,
      axis: ReckoningAxis.unity,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.sparkle,
      check: _tent,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.tent,
      guided: true,
      voice: 'Saz çiyi çekti. İkişer kişilik çadırları herkese yetiştirelim.',
      thanks: 'Herkes örtü altında. Yine de bez duvar, dam değildir.',
    ),
    Quest(
      id: 'lumber',
      icon: '🪓',
      label: 'İlk kütüğü indir',
      hint:
          'Oduncu Kulübesini ağaçların yakınına kur. Bir köylü baltayı alıp '
          'ilk kütüğü yere indirsin; ardından odun kendiliğinden gelir.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 0,
      speaker: VillagerType.hunter,
      reward: VisualReward.bloom,
      check: _lumberCamp,
      pointer: QuestPointer.forest,
      buildTarget: BuildingType.lumberCamp,
      guided: true,
      voice: 'Odunsuz ne ev olur ne ateş. Baltayı ormana sok.',
      thanks: 'Balta işliyor. Odun artık ayağımıza geliyor.',
    ),
    Quest(
      id: 'well',
      icon: '💧',
      label: 'Suyu köye getir',
      hint:
          'Bir Kuyu kaz (4 odun + 8 taş). Evler doldurur, çiftçi ekinini '
          'sular; tarla olacak yere yakın kaz.',
      category: QuestCategory.founding,
      axis: ReckoningAxis.grit,
      tier: 0,
      reward: VisualReward.bloom,
      check: _well,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.well,
    ),
    // Kuyu ile ev arasındaki sıra bilinçli: kuyu biter bitmez pahalı eve
    // bakıp odun saymak yerine oyuncu suyun işe yarayacağı toprağı ÇİZER.
    // Kafile bütçesi bu kısa, etkin adımdan sonra ilk evi hazır karşılar
    // (bkz. founding_mode_ui_test). Böylece kuruluşta kaynak bekleme ekranı
    // değil, art arda kararlar vardır.
    Quest(
      id: 'farm',
      icon: '🌾',
      label: 'Toprağı sür',
      hint:
          'Tarla modunu aç, kuyunun yakınına düz bir alan seç. Böğürtlen köyü '
          'kurtarmaz, sadece ilk günleri kurtarır; karnı toprak doyurur.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.bloom,
      check: _farm,
      pointer: QuestPointer.villageCenter,
      voice: 'Su geldi. Şimdi onun yetiştireceği toprağı sürelim.',
      thanks: 'Toprak sürüldü. Gerisini yağmurla emek bilir.',
    ),
    Quest(
      id: 'tentIllness',
      icon: '🤒',
      label: 'Çadırın bedelini gör',
      hint:
          'Temeller hazır. Bir çadır sakini soğuk ve nemden ateşlenecek; '
          'öksürüğü duyunca neden kalıcı bir dam gerektiği anlaşılacak.',
      category: QuestCategory.founding,
      axis: ReckoningAxis.unity,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.sparkle,
      check: _tentIllness,
      pointer: QuestPointer.villageCenter,
      voice: 'Bez duvar rüzgârı kesmedi. Birinin öksürüğü ağırlaşıyor.',
      thanks: 'Gördük: çadır yol içindir. Buraya gerçek bir dam gerek.',
    ),
    Quest(
      id: 'house',
      icon: '🏠',
      label: 'İlk damı çat',
      hint:
          'Bir Köy Evi dik (18 odun + 4 taş). Çadır bir geceyi kurtarır, ev '
          'bir hane kurar — doğum ancak evde olur.',
      category: QuestCategory.founding,
      axis: ReckoningAxis.unity,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.bloom,
      check: _house,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.woodenHouse,
      voice: 'Çadır bir geceyi kurtarır. Bize bir dam lazım.',
      thanks: 'Dam çatıldı. Bu, bir hane kuruldu demek.',
    ),

    // ── Tier 1 — Kapısı Açık Köy ─────────────────────────────────────────
    Quest(
      id: 'townhall',
      icon: '🏛',
      label: 'Belediyeyi kur',
      hint:
          'Belediye binasını dik. Köyün mührü orada durur; Kanunname ancak '
          'Belediye kurulunca açılır.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 1,
      reward: VisualReward.bloom,
      check: _townhall,
    ),
    // YAZILI YÖNETİMİN İLK DERSİ. Belediye kurulmadan önce köyün kararları
    // Ocak Sözü'dür; Kanunname'yi kuruluş öğreticisine sokmak oyunun kendi
    // ilerlemesiyle çelişiyordu. Belediye görevi listede bunun hemen önünde:
    // bina yükselir, ardından Defter → Kanunname rehberi bir kez açılır.
    Quest(
      id: 'firstPolicy',
      icon: '📜',
      label: 'İlk hükmü yazıya geçir',
      hint:
          'Belediye ayakta. Köy Defterini aç, Kanunname rafından bir hüküm '
          'seç ve mühürle.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 1,
      speaker: VillagerType.priest,
      reward: VisualReward.festival,
      check: _firstPolicy,
      uiTarget: QuestUi.lawBook,
      guided: true,
      voice: 'Mühür artık yerini buldu. Ocak sözünü deftere geçirebiliriz.',
      thanks: 'Söz yazıya geçti. Köyün ilk hükmü defterde.',
    ),
    Quest(
      id: 'tavern',
      icon: '🍺',
      label: 'Tavernayı aç',
      hint: 'Bir Taverna kur. Akşam işten çıkanın gideceği bir yer olsun.',
      category: QuestCategory.social,
      axis: ReckoningAxis.unity,
      tier: 1,
      reward: VisualReward.bloom,
      check: _tavern,
    ),
    Quest(
      id: 'pop10',
      icon: '👪',
      label: 'On cana ulaş',
      hint:
          'Belediye ayakta, ambar dolu, ev boş olsun: nüfus kendi büyür. '
          'Onuncu köylüyü bekle.',
      category: QuestCategory.population,
      axis: ReckoningAxis.grit,
      tier: 1,
      reward: VisualReward.festival,
      check: _pop10,
    ),
    Quest(
      id: 'church',
      icon: '⛪',
      label: 'Kiliseyi dik',
      hint:
          'Bir Kilise kur. Köy hem duasını hem uğurlamasını orada yapar; '
          'yanı başında mezarlık büyür.',
      category: QuestCategory.social,
      axis: ReckoningAxis.unity,
      tier: 1,
      reward: VisualReward.bloom,
      check: _church,
    ),

    // ── Tier 2 — Davulu Duyulan Kasaba ───────────────────────────────────
    Quest(
      id: 'market',
      icon: '🛒',
      label: 'Pazarı kur',
      hint: 'Bir Pazar aç. Fazlan altına döner, meydan sesle dolar.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 2,
      reward: VisualReward.bloom,
      check: _market,
    ),
    Quest(
      id: 'beehive',
      icon: '🐝',
      label: 'Kovanı yerleştir',
      hint:
          'Kovanı çiçeklerin arasına koy. Menzilinde ne kadar çiçek varsa o '
          'kadar hızlı bal gelir.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 2,
      reward: VisualReward.bloom,
      check: _beehive,
    ),
    Quest(
      id: 'florist',
      icon: '🌷',
      label: 'Çiçekçiyi çağır',
      hint:
          'Çiçekçi Kulübesi kur. Kadın etrafındaki her şeyi sular, köy renk '
          'değiştirir.',
      category: QuestCategory.beauty,
      axis: ReckoningAxis.grit,
      tier: 2,
      reward: VisualReward.bloom,
      check: _florist,
    ),
    Quest(
      id: 'threePolicies',
      icon: '⚖️',
      label: 'Tüzüğü kalınlaştır',
      hint:
          'Belediyeden üç beratı birden yürürlükte tut. Yazılı köyün sözü geçer.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 2,
      reward: VisualReward.festival,
      check: _threePolicies,
    ),
    Quest(
      id: 'neighborly',
      icon: '🤝',
      label: 'Komşuluk beratı',
      hint:
          'Komşuluk politikasını aç. Karşılaşan iki köylü artık başını çevirip '
          'geçmez, selam verir.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.unity,
      tier: 2,
      reward: VisualReward.bloom,
      check: _neighborly,
    ),
    Quest(
      id: 'pop20',
      icon: '🧑‍🤝‍🧑',
      label: 'Yirmi cana ulaş',
      hint:
          'Ev yetiştir, ambarı boş bırakma. Yirminci köylüde artık buraya köy '
          'demek zor.',
      category: QuestCategory.population,
      axis: ReckoningAxis.grit,
      tier: 2,
      reward: VisualReward.festival,
      check: _pop20,
    ),
    Quest(
      id: 'bloomVillage',
      icon: '🌸',
      label: 'Köyü güzelleştir',
      hint: 'Görev bitirdikçe köye süs düşer. Kırk süs objesine ulaş.',
      category: QuestCategory.beauty,
      axis: ReckoningAxis.grit,
      tier: 2,
      reward: VisualReward.bloom,
      check: _bloom40,
    ),

    // ── Tier 3 — Harmanı Taşan Kasaba ────────────────────────────────────
    // Bu kademeden itibaren merdiven KARARLARI da ölçer. Aşağıdaki görevlerin
    // hiçbiri bir bina dikilerek kapanmaz: hane kazanmak, haneleri bir arada
    // tutmak ve hesaplaşmaya hazır olmak oyuncunun yönetişim siciline bakar.
    Quest(
      id: 'loyalHouse',
      icon: '🤝',
      label: 'Bir haneyi kazan',
      hint:
          'Bir hane sana borçlu kalsın. Bağış, nikâh, adil karar: hangisi '
          'olursa olsun bir ocağın gözünde iyi bir yere geç.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.unity,
      tier: 3,
      reward: VisualReward.festival,
      check: _loyalHouse,
    ),
    Quest(
      id: 'fivePolicies',
      icon: '👑',
      label: 'Beş beratlık tüzük',
      hint:
          'Beş politikayı aynı anda yürürlükte tut. Bu artık bir usul, bir '
          'heves değil.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 3,
      reward: VisualReward.landmark,
      check: _fivePolicies,
    ),
    Quest(
      id: 'hospitality',
      icon: '🚪',
      label: 'Misafirperverlik beratı',
      hint:
          'Misafirperverlik politikasını aç. Kervanla gelen yolcu köyde kalır.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.unity,
      tier: 3,
      reward: VisualReward.bloom,
      check: _hospitality,
    ),
    Quest(
      id: 'roads',
      icon: '🛣',
      label: 'Üretimin damarını bağla',
      hint:
          'Aynı kesintisiz yol ağına üç üretim noktası bağla. Yolun uzunluğu '
          'değil; oduncu, maden, değirmen ya da pazarın birbirine erişmesi '
          'sayılır.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 3,
      minYear: 3,
      capstone: true,
      reward: VisualReward.landmark,
      check: _productionNetwork,
    ),
    Quest(
      id: 'pop30',
      icon: '🌟',
      label: 'Otuz cana ulaş',
      hint:
          'Otuz köylü. Bu kadar ağız doyuyorsa toprak da yönetim de yerinde '
          'demektir.',
      category: QuestCategory.population,
      axis: ReckoningAxis.grit,
      tier: 3,
      reward: VisualReward.festival,
      check: _pop30,
    ),

    // ── Tier 4 — Adı Duyulan Kaza ────────────────────────────────────────
    // Dört hesaplaşma kefesi ilk kez aynı kademede açıkça yan yana gelir.
    Quest(
      id: 'recoverPressure',
      icon: '🌱',
      label: 'Köyü yeniden ayağa kaldır',
      hint:
          'Bir kışı ya da imparatorluk baskısını geride bırak; ardından '
          'hanelerin rızasını ve köyün ağırlığını yeniden sağlamlaştır.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.unity,
      tier: 4,
      minYear: 4,
      capstone: true,
      reward: VisualReward.landmark,
      check: _recoveredFromPressure,
    ),
    Quest(
      id: 'libraryLegacy',
      icon: '📚',
      label: 'Kararı kayda geçir',
      hint:
          'Kütüphaneyi kur; büyük kararların köyün hafızasında iyi bir iz '
          'bırakmış olsun. Duvar değil, içine yazılan söz sayılır.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.legacy,
      tier: 4,
      reward: VisualReward.landmark,
      check: _libraryLegacy,
    ),
    Quest(
      id: 'housesUnited',
      icon: '🏘',
      label: 'Haneleri bir arada tut',
      hint:
          'En az üç hane olsun ve hiçbiri elini çekmesin. Kalabalık köy '
          'kolay; küsmeyen köy zordur.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.unity,
      tier: 4,
      reward: VisualReward.festival,
      check: _housesUnited,
    ),
    Quest(
      id: 'crafts',
      icon: '🔨',
      label: 'Yedi zanaatı yaşat',
      hint:
          'Yedi ayrı zanaat köyde biliniyor olsun. Usta ölür, çırak kalırsa '
          'zanaat kalır; kalmazsa geri gider.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 4,
      reward: VisualReward.festival,
      check: _crafts7,
    ),
    Quest(
      id: 'townWeight',
      icon: '🌾',
      label: 'Kasabanın ağırlığını duyur',
      hint:
          'Nüfusu tek başına şişirme. En az otuz canı, dolu ambar ve keseyle '
          'birlikte taşı; hesaplaşmada köyün ağırlığı bunların bütünüdür.',
      category: QuestCategory.population,
      axis: ReckoningAxis.grit,
      tier: 4,
      reward: VisualReward.festival,
      check: _townHasWeight,
    ),
    Quest(
      id: 'politicalIdentity',
      icon: '⚖️',
      label: 'Köyün tarafını belli et',
      hint:
          'Birbiriyle uyumlu hükümler mühürle; pusulada ılımlı merkezden '
          'ayrılan belirgin bir kimlik ve taşıyacak kalınlık oluşsun.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 4,
      reward: VisualReward.landmark,
      check: _politicalIdentity,
    ),

    // ── Tier 5 — Sancağı Olan Şehir ──────────────────────────────────────
    // Ham siluet listesi değil: yapı varsa bile ancak kararın sonucunu
    // taşıdığı zaman sayılır. Dört hesaplaşma kefesi bu kademede de görünür.
    Quest(
      id: 'lastingMemory',
      icon: '🗿',
      label: 'Hatırayı taşa bağla',
      hint:
          'Bir Anıt dik ve iyi karar mirasını arkasına koy. Taş tek başına '
          'hatıra değildir; köyün anlatacağı bir karar da olmalı.',
      category: QuestCategory.beauty,
      axis: ReckoningAxis.legacy,
      tier: 5,
      reward: VisualReward.landmark,
      check: _lastingMemory,
    ),
    Quest(
      id: 'openRoutes',
      icon: '🏨',
      label: 'Köyün yolunu dışarı aç',
      hint:
          'Hanı aç; bağlı üretim ağını ve köy ağırlığını yolcu taşıyacak '
          'hâle getir. Boş han değil, işleyen kasaba kapısı sayılır.',
      category: QuestCategory.production,
      axis: ReckoningAxis.grit,
      tier: 5,
      reward: VisualReward.landmark,
      check: _openRoutes,
    ),
    Quest(
      id: 'charterVoice',
      icon: '📜',
      label: 'Tüzüğe tek bir ses ver',
      hint:
          'Hükümlerin birbirini götürmesin. Belirgin siyasi kimliğini, '
          'hesaplaşmada ağır gelecek bir tüzükle destekle.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 5,
      reward: VisualReward.landmark,
      check: _charterVoice,
    ),
    Quest(
      id: 'trustedCouncil',
      icon: '🤝',
      label: 'Hanelerin sözünü arkana al',
      hint:
          'En az üç hanenin rızasını güçlü tut; büyük kararların mirası da '
          'bu güveni boşa çıkarmasın.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.unity,
      tier: 5,
      reward: VisualReward.festival,
      check: _trustedCouncil,
    ),
    Quest(
      id: 'yearFiveMatter',
      icon: '⚖️',
      label: 'Beş yılın sözünü mühürle',
      hint:
          'Köyün siyasi kimliği belli, tüzüğü ağır, karar mirası güçlü olsun. '
          'Bu üçü aynı sözü söylemeden son yılın meselesi kapanmaz.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.legacy,
      tier: 5,
      minYear: 5,
      capstone: true,
      reward: VisualReward.landmark,
      check: _yearFiveMatter,
    ),
    Quest(
      id: 'beratReady',
      icon: '📜',
      label: 'Berat gününe hazır ol',
      hint:
          'İmparatorluk defteri açtığında köy kendi ayakları üstünde '
          'durabilsin. Görevde gördüğün dört kefe birlikte tartılacak.',
      category: QuestCategory.governance,
      axis: ReckoningAxis.charter,
      tier: 5,
      reward: VisualReward.landmark,
      check: _beratReady,
    ),
  ];

  // ── Görev kontrolleri ─────────────────────────────────────────────────────
  static bool _firepit(QuestContext c) => c.has(BuildingType.firepit);
  static bool _tent(QuestContext c) =>
      c.population > 0 && c.tentCapacity >= c.population;
  // "İlk dam" ÇADIR DEĞİL: çadırın kendi görevi var ve `hasRole(housing)`
  // onunla zaten dolardı → iki görev tek hamleyle biterdi.
  static bool _house(QuestContext c) => c.has(BuildingType.woodenHouse);
  // KURAL: BİR ADIM OYUNCUNUN HAMLESİNİ ÖLÇER, NPC'NİN HIZINI ÖLÇMEZ.
  //
  // İki kez kırıldı, iki kez aynı yere çıktı. Önce adımlar kararın SONUCUNU
  // istedi (sepet dolsun, kazan kaynasın): oyuncu hamlesini yapıyor, sonra
  // köylünün çalıya yürümesini seyrediyordu. Sonra yalnız kararı istedi ama
  // karar "şu köylüye şu işi ver"di: bu da hamle değil mikro kontroldü.
  // Kadro artık köyün kendi refleksi; adım kulübenin dikildiğini ölçer.
  static bool _lumberCamp(QuestContext c) =>
      c.has(BuildingType.lumberCamp) && c.woodHarvested > 0;
  static bool _survivedFirstNight(QuestContext c) =>
      c.population > 0 && c.reedBedCount >= c.population && c.dayCount >= 2;
  static bool _tentIllness(QuestContext c) => c.foundingTentIllnessTriggered;
  static bool _farm(QuestContext c) => c.farmTiles.isNotEmpty;
  static bool _well(QuestContext c) => c.has(BuildingType.well);
  static bool _townhall(QuestContext c) => c.has(BuildingType.townhall);
  static bool _tavern(QuestContext c) => c.has(BuildingType.tavern);
  static bool _church(QuestContext c) => c.has(BuildingType.church);
  static bool _market(QuestContext c) => c.has(BuildingType.market);
  static bool _beehive(QuestContext c) => c.has(BuildingType.beehive);
  static bool _florist(QuestContext c) => c.has(BuildingType.floristCottage);
  static bool _pop10(QuestContext c) => c.population >= 10;
  static bool _pop20(QuestContext c) => c.population >= 20;
  static bool _pop30(QuestContext c) => c.population >= 30;
  static bool _firstPolicy(QuestContext c) => c.enactedPolicies >= 1;
  static bool _threePolicies(QuestContext c) => c.enactedPolicies >= 3;
  static bool _fivePolicies(QuestContext c) => c.enactedPolicies >= 5;
  static bool _neighborly(QuestContext c) => c.policies.neighborliness;
  static bool _hospitality(QuestContext c) => c.policies.hospitality;
  static bool _bloom40(QuestContext c) => c.decorCount >= 40;
  // ── Geç oyun ─────────────────────────────────────────────────────────────
  static bool _crafts7(QuestContext c) => c.craftCount >= 7;

  /// Üç üretim noktası AYNI yol bileşenine değmeli. Böylece altmış kareyi
  /// boş araziye döşemek değil, çalışan köyün dolaşımını kurmak ödüllenir.
  static bool _productionNetwork(QuestContext c) =>
      c.connectedProductionSites >= 3;

  /// Baskıyı görmek tarihsel kapı; toparlanmak bugünkü iki hesaplaşma
  /// kefesidir. Yılı beklemek bu görevi tek başına kapatamaz.
  static bool _recoveredFromPressure(QuestContext c) =>
      c.pressuresWeathered >= 1 && c.unity >= 0.55 && c.grit >= 0.45;

  static bool _libraryLegacy(QuestContext c) =>
      c.has(BuildingType.library) && c.legacy >= 0.55;

  /// Kırk can kapısının yerine nüfus + gerçek refah bileşimi.
  static bool _townHasWeight(QuestContext c) =>
      c.population >= 30 && c.grit >= 0.50;

  static bool _politicalIdentity(QuestContext c) =>
      c.regimeNamed && c.charter >= 0.55;

  static bool _lastingMemory(QuestContext c) =>
      c.has(BuildingType.monument) && c.legacy >= 0.60;

  static bool _openRoutes(QuestContext c) =>
      c.has(BuildingType.caravanserai) &&
      c.connectedProductionSites >= 3 &&
      c.grit >= 0.58;

  static bool _charterVoice(QuestContext c) =>
      c.regimeNamed && c.charter >= 0.67;

  static bool _trustedCouncil(QuestContext c) =>
      c.houseCount >= 3 &&
      c.withheldHouses == 0 &&
      c.unity >= 0.67 &&
      c.legacy >= 0.55;

  static bool _yearFiveMatter(QuestContext c) =>
      c.regimeNamed && c.charter >= 0.67 && c.legacy >= 0.67;

  // ── Karar ölçen adımlar ───────────────────────────────────────────────────
  static bool _loyalHouse(QuestContext c) => c.loyalHouses >= 1;

  /// Üç hane eşiği bilinçli: tek haneli köyde "hiçbiri küsmedi" bedava
  /// geçerdi ve görev bir hediyeye dönerdi. Zorluk hane SAYISINDA değil,
  /// çoğaldıkça hepsini birden memnun tutmanın imkânsıza yaklaşmasında.
  static bool _housesUnited(QuestContext c) =>
      c.houseCount >= 3 && c.withheldHouses == 0;

  /// Kapanış ölçüsünün oyun içindeki karşılığı (bkz. systems/reckoning.dart).
  /// Eşik berat eşiğiyle AYNI sayı olmalı; iki ayrı sabit tutulursa görev
  /// "hazırsın" derken hesaplaşma "değildin" der.
  static bool _beratReady(QuestContext c) => c.standing >= kBeratThreshold;
}
