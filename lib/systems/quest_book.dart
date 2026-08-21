import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../farm/farm_tile.dart';
import '../scene/scene_data.dart';
import 'reckoning.dart';

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

  /// Hangi kimlik kademesinde açılır (charterTier >= tier ise görünür).
  final int tier;
  final bool Function(QuestContext) check;
  final VisualReward reward;

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
    required this.tier,
    required this.check,
    required this.reward,
    this.speaker,
    this.pointer = QuestPointer.none,
    this.buildTarget,
    this.uiTarget = QuestUi.none,
    this.guided = false,
    this.voice,
    this.thanks,
  });
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

  /// Köyün hesaplaşmadaki gücü (0..1, bkz. systems/reckoning.dart). Berat
  /// eşiğini geçmek son kademenin görevidir: oyuncu kapanışta neyle
  /// tartılacağını oyunun içinde öğrensin, kapanış ekranında değil.
  final double standing;

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
    this.loyalHouses = 0,
    this.withheldHouses = 0,
    this.houseCount = 0,
    this.standing = 0,
    this.speakerNames = const {},
  });

  int get enactedPolicies => policies.enactedCount;
  bool has(BuildingType t) => buildings.any((b) => b.type == t);
  bool hasRole(BuildingRole r) => buildings.any((b) => b.fn?.role == r);
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
  /// Bugünkü dağılım: t0:8 t1:4 t2:7 t3:4 t4:6 t5:6 → kümülatif
  /// 7/12/19/23/29/35. (Kuruluş 5→12→9→8→7: bkz. tier 0 başlığı.)
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
      if (q.tier > ctx.charterTier) continue;
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

  // ── Görev havuzu ──────────────────────────────────────────────────────────
  static const List<Quest> all = [
    // ── Tier 0 — Yeni Ocak (KURULUŞ) ─────────────────────────────────────
    // Yedi adım. Bu liste üç kez küçüldü ve her seferinde aynı sebeple:
    //
    // (1) Beş "şu binayı dik" görevinden ibaretti; arada dakikalarca hiçbir şey
    //     olmuyordu → on iki mikro adıma bölündü.
    // (2) On iki adımın üçü "şu köylüye şu işi ver"di. Kâğıtta karar, oyunda
    //     MİKRO KONTROL: köy artık kendi açlığına bakıyor (bkz. scene_jobs
    //     `_foragerTarget`/`_cookTarget`), oyuncu sepet dağıtmıyor. O üç adım
    //     düştü. İlk berat da Belediye öncesi yazılı kanun olmayacağı için
    //     kuruluşun dışına, Belediye adımının hemen arkasına taşındı.
    //
    // İlk ÜÇ adım rehberli ([Quest.guided]) ve sırası bilinçli: ocak (bir
    // yapıyı haritaya kur) → çadır (barınak ayrı bir karar) → oduncu kulübesi
    // (iş binaya bağlı, kadroya değil). Kuruluş boyunca Kanunname anlatılmaz.
    Quest(
      id: 'firepit',
      icon: '🔥',
      label: 'Ocağı yak',
      hint: 'Alttaki İnşa düğmesini aç, Ateş Yerini seç ve köyün ortasına kur.',
      category: QuestCategory.founding,
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
      id: 'tent',
      icon: '⛺',
      label: 'İlk çadırı kur',
      hint:
          'İnşa düğmesinden Çadırı seçip boş bir kareye kur. Bir usta işi alır.',
      category: QuestCategory.founding,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.sparkle,
      check: _tent,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.tent,
      guided: true,
      voice: 'Gece yaklaşıyor. Hiç olmazsa bir çadır kuralım.',
      thanks: 'Bu gece biri örtünün altında yatacak.',
    ),
    Quest(
      id: 'lumber',
      icon: '🪓',
      label: 'İlk kütüğü indir',
      hint:
          'Oduncu Kulübesini ağaçların yakınına kur. Bir köylü baltayı alıp '
          'ilk kütüğü yere indirsin; ardından odun kendiliğinden gelir.',
      category: QuestCategory.production,
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
      tier: 0,
      reward: VisualReward.bloom,
      check: _well,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.well,
    ),
    Quest(
      id: 'house',
      icon: '🏠',
      label: 'İlk damı çat',
      hint:
          'Bir Köy Evi dik (18 odun + 4 taş). Çadır bir geceyi kurtarır, ev '
          'bir hane kurar — doğum ancak evde olur.',
      category: QuestCategory.founding,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.bloom,
      check: _house,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.woodenHouse,
      voice: 'Çadır bir geceyi kurtarır. Bize bir dam lazım.',
      thanks: 'Dam çatıldı. Bu, bir hane kuruldu demek.',
    ),
    Quest(
      id: 'farm',
      icon: '🌾',
      label: 'Toprağı sür',
      hint:
          'Tarla modunu aç, düz bir alan seç. Böğürtlen köyü kurtarmaz, '
          'sadece ilk günleri kurtarır; karnı toprak doyurur.',
      category: QuestCategory.production,
      tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.bloom,
      check: _farm,
      pointer: QuestPointer.villageCenter,
      voice: 'Böğürtlen bir gün biter. Toprağı sürelim.',
      thanks: 'Toprak sürüldü. Gerisini yağmur bilir.',
    ),
    Quest(
      id: 'firstNight',
      icon: '🌙',
      label: 'İlk geceyi çıkar',
      hint:
          'Ateşi söndürme, kimseyi aç bırakma. Sabaha çıkan bir köy artık '
          'bir kamp değildir.',
      category: QuestCategory.founding,
      tier: 0,
      speaker: VillagerType.priest,
      reward: VisualReward.festival,
      check: _survivedFirstNight,
      voice: 'Ateşi söndürme, kimseyi aç bırakma. Sabahı görelim.',
      thanks: 'Sabah oldu. Burası artık bir kamp değil.',
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
      tier: 3,
      reward: VisualReward.bloom,
      check: _hospitality,
    ),
    Quest(
      id: 'warehouse',
      icon: '📦',
      label: 'Ambarı büyüt',
      hint: 'Bir Ambar kur. Harman yerde çürümesin, stok tavanı yükselsin.',
      category: QuestCategory.production,
      tier: 3,
      reward: VisualReward.bloom,
      check: _warehouse,
    ),
    Quest(
      id: 'pop30',
      icon: '🌟',
      label: 'Otuz cana ulaş',
      hint:
          'Otuz köylü. Bu kadar ağız doyuyorsa toprak da yönetim de yerinde '
          'demektir.',
      category: QuestCategory.population,
      tier: 3,
      reward: VisualReward.festival,
      check: _pop30,
    ),

    // ── Tier 4 — Adı Duyulan Kaza ────────────────────────────────────────
    // Artık soru "yeter mi" değil, "burası nasıl bir yer". Görevler köyün
    // kendi ihtiyacını değil, DIŞARIDAN görünüşünü inşa eder.
    Quest(
      id: 'fountain',
      icon: '⛲',
      label: 'Şadırvanı yaptır',
      hint:
          'Meydana bir Şadırvan koy. Kuyu suyu taşır; şadırvan suyu köyün '
          'ortasına oturtur.',
      category: QuestCategory.beauty,
      tier: 4,
      reward: VisualReward.landmark,
      check: _fountain,
    ),
    Quest(
      id: 'library',
      icon: '📚',
      label: 'Kütüphaneyi kur',
      hint:
          'Bir Kütüphane dik. Kronik orada tutulur; köyün hafızası artık '
          'bir binada durur.',
      category: QuestCategory.governance,
      tier: 4,
      reward: VisualReward.landmark,
      check: _library,
    ),
    Quest(
      id: 'roads',
      icon: '🛣',
      label: 'Yolları döşe',
      hint:
          'Altmış kare yol döşe. Ayak izi patikaydı; yol, kasabanın imzasıdır '
          've köylü yolu tercih eder.',
      category: QuestCategory.founding,
      tier: 4,
      reward: VisualReward.bloom,
      check: _roads60,
    ),
    Quest(
      id: 'crafts',
      icon: '🔨',
      label: 'Yedi zanaatı bil',
      hint:
          'Yedi ayrı zanaat köyde biliniyor olsun. Usta ölür, çırak kalırsa '
          'zanaat kalır; kalmazsa geri gider.',
      category: QuestCategory.production,
      tier: 4,
      reward: VisualReward.festival,
      check: _crafts7,
    ),
    Quest(
      id: 'pop40',
      icon: '🧑‍🤝‍🧑',
      label: 'Kırk cana ulaş',
      hint:
          'Kırk köylü. Bu kalabalık artık birbirini tanımıyor; işte kaza '
          'olmak budur.',
      category: QuestCategory.population,
      tier: 4,
      reward: VisualReward.festival,
      check: _pop40,
    ),
    Quest(
      id: 'sevenPolicies',
      icon: '📜',
      label: 'Yedi beratlık tüzük',
      hint:
          'Yedi hükmü aynı anda yürürlükte tut. Bu kalınlıkta bir tüzük '
          'artık köyün huyunu belirler.',
      category: QuestCategory.governance,
      tier: 4,
      reward: VisualReward.landmark,
      check: _sevenPolicies,
    ),

    // ── Tier 5 — Sancağı Olan Şehir ──────────────────────────────────────
    // Son kademe: köyün bir KİMLİĞİ ve uzaktan görünen bir siluetı olur.
    Quest(
      id: 'monument',
      icon: '🗿',
      label: 'Anıtı dik',
      hint: 'Bir Anıt yaptır. Kimin adına dikildiğini torunlar tartışsın.',
      category: QuestCategory.beauty,
      tier: 5,
      reward: VisualReward.landmark,
      check: _monument,
    ),
    Quest(
      id: 'belltower',
      icon: '🔔',
      label: 'Çan kulesini yükselt',
      hint:
          'Çan Kulesi köyün en uzak noktasından görünür. Sesi de oraya gider.',
      category: QuestCategory.beauty,
      tier: 5,
      reward: VisualReward.landmark,
      check: _belltower,
    ),
    Quest(
      id: 'caravanserai',
      icon: '🏨',
      label: 'Hanı aç',
      hint:
          'Han kur. Yolcu geceyi köyde geçirsin; taşıyıcı yükünü hızlı '
          'indirsin.',
      category: QuestCategory.production,
      tier: 5,
      reward: VisualReward.landmark,
      check: _caravanserai,
    ),
    Quest(
      id: 'bathhouse',
      icon: '♨️',
      label: 'Hamamı yaptır',
      hint:
          'Hamam kur. Bacasından buhar çıktığı gün köy kendine bakmaya '
          'başlamış demektir.',
      category: QuestCategory.beauty,
      tier: 5,
      reward: VisualReward.bloom,
      check: _bathhouse,
    ),
    Quest(
      id: 'regime',
      icon: '⚖️',
      label: 'Kimliğini kazan',
      hint:
          'Mühürlerin toplamı köye bir duruş versin: ılımlı kalmak da bir '
          'seçim, ama sancak dikmek için bir yön gerek.',
      category: QuestCategory.governance,
      tier: 5,
      reward: VisualReward.landmark,
      check: _regimeNamed,
    ),
    Quest(
      id: 'pop50',
      icon: '🏙',
      label: 'Elli cana ulaş',
      hint: 'Elli köylü. Buraya artık köy diyen kalmadı.',
      category: QuestCategory.population,
      tier: 5,
      reward: VisualReward.festival,
      check: _pop50,
    ),
    Quest(
      id: 'housesUnited',
      icon: '🏘',
      label: 'Haneleri bir arada tut',
      hint:
          'Üç hane ya da daha fazlası olsun ve hiçbiri elini çekmiş '
          'olmasın. Kalabalık köy kolay, küsmeyen köy zordur.',
      category: QuestCategory.governance,
      tier: 5,
      reward: VisualReward.festival,
      check: _housesUnited,
    ),
    Quest(
      id: 'beratReady',
      icon: '📜',
      label: 'Berat gününe hazır ol',
      hint:
          'İmparatorluk gelip defteri açtığında köy kendi ayakları üstünde '
          'durabilsin: hanelerin rızası, tüzüğün kalınlığı ve köyün ağırlığı '
          'birlikte tartılacak.',
      category: QuestCategory.governance,
      tier: 5,
      reward: VisualReward.landmark,
      check: _beratReady,
    ),
  ];

  // ── Görev kontrolleri ─────────────────────────────────────────────────────
  static bool _firepit(QuestContext c) => c.has(BuildingType.firepit);
  static bool _tent(QuestContext c) => c.has(BuildingType.tent);
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
  static bool _survivedFirstNight(QuestContext c) => c.dayCount >= 2;
  static bool _farm(QuestContext c) => c.farmTiles.isNotEmpty;
  static bool _well(QuestContext c) => c.has(BuildingType.well);
  static bool _townhall(QuestContext c) => c.has(BuildingType.townhall);
  static bool _tavern(QuestContext c) => c.has(BuildingType.tavern);
  static bool _church(QuestContext c) => c.has(BuildingType.church);
  static bool _market(QuestContext c) => c.has(BuildingType.market);
  static bool _beehive(QuestContext c) => c.has(BuildingType.beehive);
  static bool _florist(QuestContext c) => c.has(BuildingType.floristCottage);
  static bool _warehouse(QuestContext c) => c.has(BuildingType.warehouse);
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
  static bool _fountain(QuestContext c) => c.has(BuildingType.fountain);
  static bool _library(QuestContext c) => c.has(BuildingType.library);
  static bool _monument(QuestContext c) => c.has(BuildingType.monument);
  static bool _belltower(QuestContext c) => c.has(BuildingType.belltower);
  static bool _caravanserai(QuestContext c) => c.has(BuildingType.caravanserai);
  static bool _bathhouse(QuestContext c) => c.has(BuildingType.bathhouse);
  static bool _roads60(QuestContext c) => c.roadCount >= 60;
  static bool _crafts7(QuestContext c) => c.craftCount >= 7;
  static bool _pop40(QuestContext c) => c.population >= 40;
  static bool _pop50(QuestContext c) => c.population >= 50;
  static bool _sevenPolicies(QuestContext c) => c.enactedPolicies >= 7;
  static bool _regimeNamed(QuestContext c) => c.regimeNamed;

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
