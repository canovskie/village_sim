import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_type.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../entities/villager_job.dart';
import '../farm/farm_tile.dart';
import '../scene/scene_data.dart';

/// Köy Akışı — bol görev + politika-odaklı Tüzük ilerlemesi (no-fail).
///
/// Tasarım: `ObjectiveTracker`'ın (artık emekli) zenginleştirilmiş hâli.
/// Görevler bildirimsel `check`'lerle tamamlanır; her görev bir **görsel ödül**
/// taşır (kaynak DEĞİL). Köyün kimlik kademesi (charterTier) AĞIRLIKLA çıkarılan
/// politikalara (berat) bağlıdır → ilerleme yönetişim-odaklı. Hiçbir görev
/// başarısız olmaz, kademe yalnızca ilerler.

/// Görev kategorisi — panel ikonlandırması / gruplama için.
enum QuestCategory { founding, production, population, social, governance, beauty }

/// Görsel ödül yoğunluğu — scene_flow `_grantVisualReward` bunu FX + decor
/// kombosuna çevirir (kaynak yok). sparkle<bloom<festival<landmark.
enum VisualReward { sparkle, bloom, festival, landmark }

/// Adımın DÜNYADAKİ hedefi — "nereye bakacağım" sorusunun cevabı.
///
/// Kuruluş adımları metin olarak doğruydu ama ekranda hiçbir yeri
/// göstermiyordu: "bir köylüye tıkla" hangi köylü, "böğürtlen çalısı" nerede,
/// "ağaçların dibine kur" hangi ağaçlar. Oyuncu cümleyi okuyup ekranda
/// arıyordu. Bu enum, adımı bir YERE bağlar; sahne onu çözer, çizim oraya
/// sakin bir işaret koyar.
///
/// Bilinçli olarak DAR tutuldu: her adıma özel bir işaret türü değil, altı
/// genel hedef. Yeni adım eklerken buradan birini seç; uymuyorsa işaretsiz
/// bırak (zaman/izleme adımlarında işaret zaten yanlış olur).
enum QuestPointer {
  /// İşaret yok — zaman geçmesini ya da izlemeyi isteyen adımlar.
  none,

  /// Mesleksiz/boşta bir köylü — "birine iş ver" adımları. Köylünün ayağının
  /// altındaki kehribar halka yanar (mevcut `highlightTimer`).
  villager,

  /// En yakın böğürtlen çalısı — ilk yiyeceğin geldiği yer.
  berryBush,

  /// Orman kenarı — oduncu kulübesinin dikileceği yer.
  forest,

  /// Ocak (ateş yeri) — pişirme/toplanma adımları.
  hearth,

  /// Köyün merkezi (ocak varsa orası, yoksa kurucuların durduğu yer) —
  /// "buraya bir şey dik" adımları.
  villageCenter,
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

  /// Adımın istediği İŞ — köylü panelindeki o rol düğmesi işaretlenir.
  ///
  /// Kuruluşun on iki adımından üçü "birine iş ver". Dünyadaki halka doğru
  /// köylüyü gösteriyor ama panel açılınca oyuncu yine bir liste ile baş başa
  /// kalıyordu: hangi rol? Bu alan zincirin son halkası.
  final JobRole? jobTarget;

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
    this.jobTarget,
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

  /// Döşenmiş yol karesi — kasabalaşmanın en somut fiziksel izi.
  final int roadCount;

  /// Köy bir REJİM kimliği kazandı mı (ılımlı/merkez değil). Kimlik seçilmez,
  /// mühürlerin toplamından doğar (bkz. political compass) — bu yüzden geç
  /// oyunun "artık bir duruşun var" görevi.
  final bool regimeNamed;

  // ── Kuruluş kademesi (tier 0) ─────────────────────────────────────────────
  // Bu beş alan yalnız kuruluşun mikro adımları için var. Kuruluş eskiden beş
  // "şu binayı dik" görevinden ibaretti ve aralarında dakikalarca hiçbir şey
  // olmuyordu. Artık merdivenin ilk basamakları KARAR (kime iş verdin) ve
  // SONUÇ (ilk sepet, ilk yemek, ilk gece) üzerinden ilerliyor.

  /// Kaçıncı gün — "ilk geceyi çıkar" gibi zaman adımları için.
  final int dayCount;

  /// Köy hiç sıcak yemek pişirdi mi (bir kez true olur, geri dönmez).
  final bool everCooked;

  /// Şimdiye kadar toplanmış böğürtlen sepeti (kümülatif — stok değil; stok
  /// bakılsaydı görev, yenen yiyecek yüzünden geri alınmış gibi görünürdü).
  final int berriesPicked;

  /// Oyuncunun ELLE verdiği roller. "Sepeti birinin eline ver" adımı bina
  /// değil KARAR ölçer; otomatik atanan iş bu kümeye girmez, girseydi oyuncu
  /// hiçbir şey yapmadan görevi tamamlamış sayılırdı.
  final Set<JobRole> playerAssignedRoles;

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
    this.roadCount = 0,
    this.regimeNamed = false,
    this.dayCount = 1,
    this.everCooked = false,
    this.berriesPicked = 0,
    this.playerAssignedRoles = const {},
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
  const QuestState(this.quest, this.completed, this.active,
      {this.speakerName});
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
  /// Bugünkü dağılım: t0:12 t1:5 t2:7 t3:4 t4:6 t5:6 → kümülatif
  /// 12/17/24/28/34/40. (Kuruluş 5'ten 12'ye çıktı: bkz. tier 0 başlığı.)
  ///
  /// Eşik ayrıca NEFES payı bırakmalı. Tavana "bir görev hariç hepsi" diye
  /// oturursa, kovan/çiçekçi gibi isteğe bağlı bir görevi atlayan oyuncu
  /// merdivenin sonuna hiç varamaz ve sebebini de anlayamaz (görev listesi
  /// tamamlananları gizliyor). Her kademede 3-4 görevlik pay bilinçli.
  static const List<CharterTier> tiers = [
    CharterTier('Yeni Yakılan Ocak', '🔥', 0, 0),
    CharterTier('Kapısı Açık Köy',   '🏡', 0, 8),
    CharterTier('Davulu Duyulan Kasaba', '🎏', 2, 14),
    CharterTier('Harmanı Taşan Kasaba', '🌟', 4, 20),
    // ── GEÇ OYUN ───────────────────────────────────────────────────────────
    // Buraya kadar merdiven "köyü kur"du; bundan sonrası "köyü bir yer yap".
    // Eşikler politikaya daha ağır yaslanır: geç oyun bina dikmekle değil,
    // yönetişimin oturmasıyla ilerler (kademe adları da onu söylüyor).
    CharterTier('Adı Duyulan Kaza', '⚖️', 6, 24),
    CharterTier('Sancağı Olan Şehir', '👑', 8, 30),
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
  static CharterTier? nextTier(int t) =>
      t < maxTier ? tiers[t + 1] : null;

  /// Açık kademedeki (tier <= charterTier) tamamlanmamış görevler — panel akışı.
  /// İlki "active" işaretlenir. Tamamlananlar listeden düşer (temiz to-do hissi).
  static List<QuestState> activeQuests(QuestContext ctx, Set<String> completed) {
    final res = <QuestState>[];
    var marked = false;
    for (final q in all) {
      if (q.tier > ctx.charterTier) continue;
      if (completed.contains(q.id)) continue;
      final active = !marked;
      marked = true;
      final sp = q.speaker;
      res.add(QuestState(q, false, active,
          speakerName: sp == null ? null : ctx.speakerNames[sp]));
    }
    return res;
  }

  // ── Görev havuzu ──────────────────────────────────────────────────────────
  static const List<Quest> all = [
    // ── Tier 0 — Yeni Ocak (KURULUŞ) ─────────────────────────────────────
    // On iki mikro adım, ~iki güne yayılır. Eskiden burada beş görev vardı ve
    // beşi de "şu binayı dik"ti: oyuncu ateşi yakıyor, sonra odun birikmesini
    // bekliyor, arada hiçbir şey olmuyordu. Boşluğun kaynağı buydu.
    //
    // Yeni merdivenin ritmi bilinçli olarak KARAR → SONUÇ → KARAR:
    // birine iş ver (karar), ilk sepet gelsin (sonuç), aşçı ver (karar), ilk
    // yemek pişsin (sonuç)… Her adım oyuncunun bir hamlesinin karşılığını
    // gösteriyor; bekleme aralıkları saniyelere iniyor.
    Quest(
      id: 'firepit', icon: '🔥', label: 'Ocağı yak',
      hint: 'Kafile durdu, bir yer bekliyor. Meydan olacak yere Ateş Yeri koy; '
          'bedava. Köy, ateşin yandığı yerde kurulur.',
      category: QuestCategory.founding, tier: 0,
      speaker: VillagerType.priest,
      reward: VisualReward.sparkle, check: _firepit,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.firepit),
    Quest(
      id: 'giveBasket', icon: '🧺', label: 'Sepeti birinin eline ver',
      hint: 'Bir köylüye tıkla, İŞ bölümünden Toplayıcı de. Böğürtlen çalıları '
          'bina istemez — köyün ilk yiyeceği oradan gelir. Köyde sepeti '
          'kadınlar taşır; başkasına verirsen de olur, iş sadece ağır ilerler.',
      category: QuestCategory.production, tier: 0,
      speaker: VillagerType.shepherd,
      reward: VisualReward.sparkle, check: _assignedForager,
      pointer: QuestPointer.villager,
      jobTarget: JobRole.forager),
    Quest(
      id: 'firstBerries', icon: '🍇', label: 'İlk sepet dolsun',
      hint: 'Toplayıcı en yakın olgun çalıya gidip toplayacak. Sen bir şey '
          'yapma; sadece izle ve ambarın dolduğunu gör.',
      category: QuestCategory.production, tier: 0,
      reward: VisualReward.bloom, check: _firstBerries,
      pointer: QuestPointer.berryBush),
    Quest(
      id: 'giveCook', icon: '🍲', label: 'Ocağa bir aşçı ver',
      hint: 'Bir köylüyü Aşçı yap. Aşçı ham yiyeceği ocakta pişirir; pişen '
          'yemek iki katı ağız doyurur. Ateş yeri olmadan olmaz.',
      category: QuestCategory.production, tier: 0,
      speaker: VillagerType.miller,
      reward: VisualReward.sparkle, check: _assignedCook,
      pointer: QuestPointer.villager,
      jobTarget: JobRole.cook),
    Quest(
      id: 'firstMeal', icon: '🥘', label: 'İlk sıcak yemek pişsin',
      hint: 'Kazan kaynayınca köy ilk defa sofraya oturur. O akşam kimse kuru '
          'ekmek yemez.',
      category: QuestCategory.social, tier: 0,
      reward: VisualReward.festival, check: _firstMeal,
      pointer: QuestPointer.hearth),
    Quest(
      id: 'tent', icon: '⛺', label: 'İlk çadırı kur',
      hint: 'Bir Çadır dik (6 odun). Ucuzdur ve bu gece birini yıldızların '
          'altında bırakmaz — sağlam ev sonra gelir.',
      category: QuestCategory.founding, tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.sparkle, check: _tent,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.tent),
    Quest(
      id: 'lumber', icon: '🪓', label: 'Baltayı ormana sok',
      hint: 'Ağaçların dibine Oduncu Kulübesi kur (12 odun). Kulübe tek başına '
          'odun kesmez — kesecek adamı sen vereceksin.',
      category: QuestCategory.production, tier: 0,
      speaker: VillagerType.hunter,
      reward: VisualReward.sparkle, check: _lumber,
      pointer: QuestPointer.forest,
      buildTarget: BuildingType.lumberCamp),
    Quest(
      id: 'giveAxe', icon: '🪵', label: 'Baltayı birinin eline ver',
      hint: 'Bir köylüyü Oduncu yap. Odun ağır iştir; köyde baltayı erkekler '
          'sallar. Yine de karar senin — kadın da keser, sadece geç keser.',
      category: QuestCategory.production, tier: 0,
      speaker: VillagerType.hunter,
      reward: VisualReward.bloom, check: _assignedWoodcutter,
      pointer: QuestPointer.villager,
      jobTarget: JobRole.woodcutter),
    Quest(
      id: 'well', icon: '💧', label: 'Suyu köye getir',
      hint: 'Bir Kuyu kaz (4 odun + 8 taş). Evler doldurur, çiftçi ekinini '
          'sular; tarla olacak yere yakın kaz.',
      category: QuestCategory.founding, tier: 0,
      reward: VisualReward.bloom, check: _well,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.well),
    Quest(
      id: 'house', icon: '🏠', label: 'İlk damı çat',
      hint: 'Bir Köy Evi dik (18 odun + 4 taş). Çadır bir geceyi kurtarır, ev '
          'bir hane kurar — doğum ancak evde olur.',
      category: QuestCategory.founding, tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.bloom, check: _house,
      pointer: QuestPointer.villageCenter,
      buildTarget: BuildingType.woodenHouse),
    Quest(
      id: 'farm', icon: '🌾', label: 'Toprağı sür',
      hint: 'Tarla modunu aç, düz bir alan seç. Böğürtlen köyü kurtarmaz, '
          'sadece ilk günleri kurtarır; karnı toprak doyurur.',
      category: QuestCategory.production, tier: 0,
      speaker: VillagerType.farmer,
      reward: VisualReward.bloom, check: _farm,
      pointer: QuestPointer.villageCenter),
    Quest(
      id: 'firstNight', icon: '🌙', label: 'İlk geceyi çıkar',
      hint: 'Ateşi söndürme, kimseyi aç bırakma. Sabaha çıkan bir köy artık '
          'bir kamp değildir.',
      category: QuestCategory.founding, tier: 0,
      speaker: VillagerType.priest,
      reward: VisualReward.festival, check: _survivedFirstNight),

    // ── Tier 1 — Kapısı Açık Köy ─────────────────────────────────────────
    Quest(
      id: 'townhall', icon: '🏛', label: 'Belediyeyi kur',
      hint: 'Belediye binasını dik. Köyün mührü orada durur; berat oradan çıkar.',
      category: QuestCategory.governance, tier: 1,
      reward: VisualReward.bloom, check: _townhall),
    Quest(
      id: 'firstPolicy', icon: '📜', label: 'İlk beratı yaz',
      hint: 'Belediye panelini aç, bir politikayı yürürlüğe koy. Köyün tüzüğü '
          'o satırla başlar.',
      category: QuestCategory.governance, tier: 1,
      reward: VisualReward.festival, check: _firstPolicy),
    Quest(
      id: 'tavern', icon: '🍺', label: 'Tavernayı aç',
      hint: 'Bir Taverna kur. Akşam işten çıkanın gideceği bir yer olsun.',
      category: QuestCategory.social, tier: 1,
      reward: VisualReward.bloom, check: _tavern),
    Quest(
      id: 'pop10', icon: '👪', label: 'On cana ulaş',
      hint: 'Belediye ayakta, ambar dolu, ev boş olsun: nüfus kendi büyür. '
          'Onuncu köylüyü bekle.',
      category: QuestCategory.population, tier: 1,
      reward: VisualReward.festival, check: _pop10),
    Quest(
      id: 'church', icon: '⛪', label: 'Kiliseyi dik',
      hint: 'Bir Kilise kur. Köy hem duasını hem uğurlamasını orada yapar; '
          'yanı başında mezarlık büyür.',
      category: QuestCategory.social, tier: 1,
      reward: VisualReward.bloom, check: _church),

    // ── Tier 2 — Davulu Duyulan Kasaba ───────────────────────────────────
    Quest(
      id: 'market', icon: '🛒', label: 'Pazarı kur',
      hint: 'Bir Pazar aç. Fazlan altına döner, meydan sesle dolar.',
      category: QuestCategory.production, tier: 2,
      reward: VisualReward.bloom, check: _market),
    Quest(
      id: 'beehive', icon: '🐝', label: 'Kovanı yerleştir',
      hint: 'Kovanı çiçeklerin arasına koy. Menzilinde ne kadar çiçek varsa o '
          'kadar hızlı bal gelir.',
      category: QuestCategory.production, tier: 2,
      reward: VisualReward.bloom, check: _beehive),
    Quest(
      id: 'florist', icon: '🌷', label: 'Çiçekçiyi çağır',
      hint: 'Çiçekçi Kulübesi kur. Kadın etrafındaki her şeyi sular, köy renk '
          'değiştirir.',
      category: QuestCategory.beauty, tier: 2,
      reward: VisualReward.bloom, check: _florist),
    Quest(
      id: 'threePolicies', icon: '⚖️', label: 'Tüzüğü kalınlaştır',
      hint: 'Belediyeden üç beratı birden yürürlükte tut. Yazılı köyün sözü geçer.',
      category: QuestCategory.governance, tier: 2,
      reward: VisualReward.festival, check: _threePolicies),
    Quest(
      id: 'neighborly', icon: '🤝', label: 'Komşuluk beratı',
      hint: 'Komşuluk politikasını aç. Karşılaşan iki köylü artık başını çevirip '
          'geçmez, selam verir.',
      category: QuestCategory.governance, tier: 2,
      reward: VisualReward.bloom, check: _neighborly),
    Quest(
      id: 'pop20', icon: '🧑‍🤝‍🧑', label: 'Yirmi cana ulaş',
      hint: 'Ev yetiştir, ambarı boş bırakma. Yirminci köylüde artık buraya köy '
          'demek zor.',
      category: QuestCategory.population, tier: 2,
      reward: VisualReward.festival, check: _pop20),
    Quest(
      id: 'bloomVillage', icon: '🌸', label: 'Köyü güzelleştir',
      hint: 'Görev bitirdikçe köye süs düşer. Kırk süs objesine ulaş.',
      category: QuestCategory.beauty, tier: 2,
      reward: VisualReward.bloom, check: _bloom40),

    // ── Tier 3 — Harmanı Taşan Kasaba ────────────────────────────────────
    Quest(
      id: 'fivePolicies', icon: '👑', label: 'Beş beratlık tüzük',
      hint: 'Beş politikayı aynı anda yürürlükte tut. Bu artık bir usul, bir '
          'heves değil.',
      category: QuestCategory.governance, tier: 3,
      reward: VisualReward.landmark, check: _fivePolicies),
    Quest(
      id: 'hospitality', icon: '🚪', label: 'Misafirperverlik beratı',
      hint: 'Misafirperverlik politikasını aç. Yoldan geçen gezgin köyde kalır.',
      category: QuestCategory.governance, tier: 3,
      reward: VisualReward.bloom, check: _hospitality),
    Quest(
      id: 'warehouse', icon: '📦', label: 'Ambarı büyüt',
      hint: 'Bir Ambar kur. Harman yerde çürümesin, stok tavanı yükselsin.',
      category: QuestCategory.production, tier: 3,
      reward: VisualReward.bloom, check: _warehouse),
    Quest(
      id: 'pop30', icon: '🌟', label: 'Otuz cana ulaş',
      hint: 'Otuz köylü. Bu kadar ağız doyuyorsa toprak da yönetim de yerinde '
          'demektir.',
      category: QuestCategory.population, tier: 3,
      reward: VisualReward.festival, check: _pop30),

    // ── Tier 4 — Adı Duyulan Kaza ────────────────────────────────────────
    // Artık soru "yeter mi" değil, "burası nasıl bir yer". Görevler köyün
    // kendi ihtiyacını değil, DIŞARIDAN görünüşünü inşa eder.
    Quest(
      id: 'fountain', icon: '⛲', label: 'Şadırvanı yaptır',
      hint: 'Meydana bir Şadırvan koy. Kuyu suyu taşır; şadırvan suyu köyün '
          'ortasına oturtur.',
      category: QuestCategory.beauty, tier: 4,
      reward: VisualReward.landmark, check: _fountain),
    Quest(
      id: 'library', icon: '📚', label: 'Kütüphaneyi kur',
      hint: 'Bir Kütüphane dik. Kronik orada tutulur; köyün hafızası artık '
          'bir binada durur.',
      category: QuestCategory.governance, tier: 4,
      reward: VisualReward.landmark, check: _library),
    Quest(
      id: 'roads', icon: '🛣', label: 'Yolları döşe',
      hint: 'Altmış kare yol döşe. Ayak izi patikaydı; yol, kasabanın imzasıdır '
          've köylü yolu tercih eder.',
      category: QuestCategory.founding, tier: 4,
      reward: VisualReward.bloom, check: _roads60),
    Quest(
      id: 'crafts', icon: '🔨', label: 'Yedi zanaatı bil',
      hint: 'Yedi ayrı zanaat köyde biliniyor olsun. Usta ölür, çırak kalırsa '
          'zanaat kalır; kalmazsa geri gider.',
      category: QuestCategory.production, tier: 4,
      reward: VisualReward.festival, check: _crafts7),
    Quest(
      id: 'pop40', icon: '🧑‍🤝‍🧑', label: 'Kırk cana ulaş',
      hint: 'Kırk köylü. Bu kalabalık artık birbirini tanımıyor; işte kaza '
          'olmak budur.',
      category: QuestCategory.population, tier: 4,
      reward: VisualReward.festival, check: _pop40),
    Quest(
      id: 'sevenPolicies', icon: '📜', label: 'Yedi beratlık tüzük',
      hint: 'Yedi hükmü aynı anda yürürlükte tut. Bu kalınlıkta bir tüzük '
          'artık köyün huyunu belirler.',
      category: QuestCategory.governance, tier: 4,
      reward: VisualReward.landmark, check: _sevenPolicies),

    // ── Tier 5 — Sancağı Olan Şehir ──────────────────────────────────────
    // Son kademe: köyün bir KİMLİĞİ ve uzaktan görünen bir siluetı olur.
    Quest(
      id: 'monument', icon: '🗿', label: 'Anıtı dik',
      hint: 'Bir Anıt yaptır. Kimin adına dikildiğini torunlar tartışsın.',
      category: QuestCategory.beauty, tier: 5,
      reward: VisualReward.landmark, check: _monument),
    Quest(
      id: 'belltower', icon: '🔔', label: 'Çan kulesini yükselt',
      hint: 'Çan Kulesi köyün en uzak noktasından görünür. Sesi de oraya gider.',
      category: QuestCategory.beauty, tier: 5,
      reward: VisualReward.landmark, check: _belltower),
    Quest(
      id: 'caravanserai', icon: '🏨', label: 'Hanı aç',
      hint: 'Han kur. Yolcu geceyi köyde geçirsin; taşıyıcı yükünü hızlı '
          'indirsin.',
      category: QuestCategory.production, tier: 5,
      reward: VisualReward.landmark, check: _caravanserai),
    Quest(
      id: 'bathhouse', icon: '♨️', label: 'Hamamı yaptır',
      hint: 'Hamam kur. Bacasından buhar çıktığı gün köy kendine bakmaya '
          'başlamış demektir.',
      category: QuestCategory.beauty, tier: 5,
      reward: VisualReward.bloom, check: _bathhouse),
    Quest(
      id: 'regime', icon: '⚖️', label: 'Kimliğini kazan',
      hint: 'Mühürlerin toplamı köye bir duruş versin: ılımlı kalmak da bir '
          'seçim, ama sancak dikmek için bir yön gerek.',
      category: QuestCategory.governance, tier: 5,
      reward: VisualReward.landmark, check: _regimeNamed),
    Quest(
      id: 'pop50', icon: '🏙', label: 'Elli cana ulaş',
      hint: 'Elli köylü. Buraya artık köy diyen kalmadı.',
      category: QuestCategory.population, tier: 5,
      reward: VisualReward.festival, check: _pop50),
  ];

  // ── Görev kontrolleri ─────────────────────────────────────────────────────
  static bool _firepit(QuestContext c) => c.has(BuildingType.firepit);
  static bool _lumber(QuestContext c) => c.has(BuildingType.lumberCamp);
  static bool _tent(QuestContext c) => c.has(BuildingType.tent);
  // "İlk dam" ÇADIR DEĞİL: çadırın kendi görevi var ve `hasRole(housing)`
  // onunla zaten dolardı → iki görev tek hamleyle biterdi.
  static bool _house(QuestContext c) => c.has(BuildingType.woodenHouse);
  // ── Kuruluş: karar ve sonuç adımları ─────────────────────────────────────
  static bool _assignedForager(QuestContext c) =>
      c.playerAssignedRoles.contains(JobRole.forager);
  static bool _assignedCook(QuestContext c) =>
      c.playerAssignedRoles.contains(JobRole.cook);
  static bool _assignedWoodcutter(QuestContext c) =>
      c.playerAssignedRoles.contains(JobRole.woodcutter);
  static bool _firstBerries(QuestContext c) => c.berriesPicked >= 1;
  static bool _firstMeal(QuestContext c) => c.everCooked;
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
}
