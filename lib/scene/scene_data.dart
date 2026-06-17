import '../systems/event_system.dart';
import '../systems/estate_system.dart';

/// Sahnede aktif olan bir EventEffect örneği — banner kapansa da efekt
/// kendi süresince yaşar (animasyon süresi != moral süresi olabilir).
class ActiveFx {
  final EventEffect effect;
  double timeLeft;
  ActiveFx(this.effect, this.timeLeft);
}

/// Otomatik senaryo sonuç raporu — DevPanel'de gösterilir.
class ScenarioReport {
  final String name;
  final double durationSec;     // sim saniyesi geçilen
  final int popStart, popEnd;
  final Map<String, (int, int)> resources; // 'wood' → (start, end)
  final String verdict;         // metin özeti (denge skoru / not)
  final List<String> warnings;  // dengesizlik uyarıları
  const ScenarioReport({
    required this.name,
    required this.durationSec,
    required this.popStart,
    required this.popEnd,
    required this.resources,
    required this.verdict,
    required this.warnings,
  });
}

/// Aile planlaması yasası — anne başına izinli doğum sayısı (mutex).
/// `open` = sınırsız (varsayılan), `oneChild` = 1, `twoChild` = 2.
/// `_tickReproduction` `mother.birthCount` ile karşılaştırır, aşıldıysa
/// fertility frozen (NaN). Mutex çünkü ekonomik felsefeler birbirini iptal eder.
enum FamilyPolicy {
  open(
    'Serbest',
    'Anne istediği kadar bebek sahibi olur.',
    'Köy kendi akışında büyür',
    null,
  ),
  oneChild(
    'Tek çocuk',
    'Her aile en fazla 1 bebek.',
    'Sakin büyüme, dolu kile yetişir',
    'Aileler sınırı sezer, evlerde sessiz bir yas vardır',
  ),
  twoChild(
    'İki çocuk',
    'Her aile en fazla 2 bebek.',
    'Dengeli büyüme, ev rahat',
    'Hafif bir kısıt hissi köye sızar',
  );

  final String label;
  final String desc;
  final String benefit;
  final String? cost;
  const FamilyPolicy(this.label, this.desc, this.benefit, this.cost);
}

/// Politika metadata — icon, label, açıklama, kategori, fayda, bedel.
/// Her politika bir bütündür: ne yaptığı + neyi kazandırdığı + neyi feda
/// ettirdiği. UI her tile'da üçü birden gösterir.
class PolicyDef {
  final String id;
  final String icon;
  final String label;
  /// Ne yapar (mekanik özet, 1 cümle).
  final String desc;
  /// Faydası — açıkça oyuncu lehine sonuç ("↑" prefix UI'da eklenir).
  final String benefit;
  /// Bedeli — açıkça oyuncu aleyhine sonuç ("↓" prefix). null = bedelsiz.
  final String? cost;
  final PolicyCategory category;
  /// Bu fermanın ZÜMRELER üstündeki etkisi — (zümre, ±delta). Ferman proaktif
  /// kaldıraçtır: yürürlüğe sokmak sevindirdiği zümreyi memnun eder + köyü o
  /// yöne kaydırır (nüfuz); kaldırmak sevenleri küstürür. Politik denge burada
  /// da işler — bedelsiz ferman bile bir zümrenin gönlünü diğerine tercih eder.
  final List<(Estate, double)> estateMood;
  const PolicyDef({
    required this.id,
    required this.icon,
    required this.label,
    required this.desc,
    required this.benefit,
    required this.category,
    this.cost,
    this.estateMood = const [],
  });
}

/// Aile planlaması (mutex) fermanının zümre etkisi — enum'a gömmek yerine
/// burada (Estate import'u enum tarafına sızmasın). [_setFamilyPolicy] uygular.
List<(Estate, double)> familyPolicyEstateMood(FamilyPolicy fp) => switch (fp) {
      FamilyPolicy.open => const [(Estate.hearth, 0.05)],
      FamilyPolicy.oneChild => const [
          (Estate.hearth, -0.10),
          (Estate.artisans, 0.05),
        ],
      FamilyPolicy.twoChild => const [(Estate.hearth, -0.03)],
    };

enum PolicyCategory {
  family('AİLE', '👨‍👩‍👧'),
  elder('YAŞLI', '🕯️'),
  community('TOPLULUK', '🤝'),
  economy('EKONOMİ', '🌾'),
  environment('ÇEVRE', '🌿');

  final String label;
  final String icon;
  const PolicyCategory(this.label, this.icon);
}

/// Tüm toggle politikalar — UI ve toggle callback'i bu listeyi kullanır.
/// Mutex `family` ayrı (`FamilyPolicy` enum), aile tab'inde radyo olarak.
const List<PolicyDef> kPolicyDefs = [
  // Aile
  PolicyDef(
      id: 'familyEncouragement',
      icon: '💝',
      label: 'Aile teşviki',
      desc: 'Aileler daha sık çocuk dünyaya getirir.',
      benefit: 'Beşikler sık sallanır',
      cost: 'Anne-baba yorgunluğu evlere sızar',
      category: PolicyCategory.family,
      estateMood: [(Estate.hearth, 0.10), (Estate.laborers, 0.04), (Estate.artisans, -0.04)]),
  PolicyDef(
      id: 'slowMaturity',
      icon: '🐢',
      label: 'Geç olgunlaşma',
      desc: 'Yaşam evreleri yavaş ilerler.',
      benefit: 'Çocukluk uzun ve dolu olur',
      cost: 'Eller işe geç uzanır',
      category: PolicyCategory.family,
      estateMood: [(Estate.hearth, 0.06), (Estate.laborers, -0.05)]),
  // Yaşlı
  PolicyDef(
      id: 'peacefulEnd',
      icon: '🕊️',
      label: 'Yaşlıya huzur',
      desc: 'Ömür sonu sakin geçer.',
      benefit: 'Köyde dingin bir hava hâkim olur',
      cost: 'Yaşlılık kısalır, bilgelik nadir olgunlaşır',
      category: PolicyCategory.elder,
      estateMood: [(Estate.hearth, 0.10), (Estate.faithful, 0.05)]),
  PolicyDef(
      id: 'eldersExemptFromFood',
      icon: '🍞',
      label: 'Yaşlıya saygı',
      desc: 'Yaşlılar ortak sofradan ayrı tutulur.',
      benefit: 'Sofra rahat, kile dolu kalır',
      cost: 'Kuşaklar arası bir sessizlik düşer',
      category: PolicyCategory.elder,
      estateMood: [(Estate.hearth, 0.08), (Estate.laborers, -0.04)]),
  // Topluluk
  PolicyDef(
      id: 'hospitality',
      icon: '🚪',
      label: 'Misafirperverlik',
      desc: 'Köy kapısı gezginlere açıktır.',
      benefit: 'Yabancı yüzler köyde ekmek bulur',
      cost: 'Köy ona alışana dek hafif gerilim olur',
      category: PolicyCategory.community,
      estateMood: [(Estate.artisans, 0.08), (Estate.hearth, -0.06)]),
  PolicyDef(
      id: 'apprenticeship',
      icon: '🔨',
      label: 'Çıraklık',
      desc: 'Çocuklar genelde anne-babasının zanaatını öğrenir.',
      benefit: 'Soydan soya zanaat geçer',
      cost: 'Yeni eller eski izden zor çıkar',
      category: PolicyCategory.community,
      estateMood: [(Estate.artisans, 0.10), (Estate.laborers, 0.04), (Estate.faithful, -0.03)]),
  PolicyDef(
      id: 'neighborliness',
      icon: '👋',
      label: 'Komşuluk',
      desc: 'Yakın geçen köylüler birbirini selamlar.',
      benefit: 'Selamlaşma köyü canlandırır',
      category: PolicyCategory.community,
      estateMood: [(Estate.hearth, 0.06), (Estate.laborers, 0.03)]),
  PolicyDef(
      id: 'familyReunion',
      icon: '💞',
      label: 'Aile birleşimi',
      desc: 'Bekar yetişkinler bir araya gelir.',
      benefit: 'Birleşimler köye sıcaklık katar',
      category: PolicyCategory.community,
      estateMood: [(Estate.hearth, 0.10)]),
  // Ekonomi
  PolicyDef(
      id: 'treePlanting',
      icon: '🌱',
      label: 'Doğa dostu',
      desc: 'Oduncu kestiği ağacın yanına fidan diker.',
      benefit: 'Orman kendini yeniler',
      cost: 'Balta daha yavaş sallanır',
      category: PolicyCategory.economy,
      estateMood: [(Estate.faithful, 0.06), (Estate.laborers, -0.06)]),
  PolicyDef(
      id: 'sharedHarvest',
      icon: '🌾',
      label: 'Müşterek hasat',
      desc: 'Tarlalar birlikte olgunlaşır.',
      benefit: 'Hiçbir tarla geride kalmaz',
      cost: 'Hiçbir tarla da öne geçemez',
      category: PolicyCategory.economy,
      estateMood: [(Estate.laborers, 0.08), (Estate.artisans, -0.04)]),
  // Çevre
  PolicyDef(
      id: 'greenVillage',
      icon: '🌸',
      label: 'Yeşil köy',
      desc: 'Yeni evlerin çevresine çiçek serpilir.',
      benefit: 'Köy çiçek açar',
      category: PolicyCategory.environment,
      estateMood: [(Estate.faithful, 0.05), (Estate.hearth, 0.04)]),
  PolicyDef(
      id: 'freeRange',
      icon: '🐑',
      label: 'Otlama serbest',
      desc: 'Hayvanlar geniş alanda dolaşır.',
      benefit: 'Sürü kendi yolunu bulur',
      cost: 'Çoban onları aramak için daha çok yürür',
      category: PolicyCategory.environment,
      estateMood: [(Estate.laborers, 0.06), (Estate.hearth, -0.03)]),
];

/// Belediye politikaları — köy yönetiminin nüfus üstündeki kararları.
/// Default: en izin verici set. Belediye panelinden değiştirilir; her
/// değişiklik decree cooldown'u (~1 oyun günü) sıfırlar — ping-pong önler.
class VillagePolicies {
  /// Aile planlaması (mutex): doğurganlık sınırı.
  FamilyPolicy family;
  /// Aile teşviki: fertility cooldown yarıya iner, doğum bildirimi şenlikli.
  bool familyEncouragement;
  /// Yaşlıya huzur: lifespan son %5'inde yaşlı sakin ayrılır, yetim
  /// bildirimi yumuşatılır ("huzurlu son").
  bool peacefulEnd;
  /// Yaşlıya saygı: yaşlılar yiyecek tüketmez (mouths sayımından düşer).
  bool eldersExemptFromFood;
  /// Misafirperverlik: periyodik gezgin köye katılır (boş ev varsa).
  bool hospitality;
  /// Çıraklık: bebekler rastgele meslek almak yerine baba ya da annenin
  /// mesleğini öğrenir — "demirci oğlu demirci" hissi.
  bool apprenticeship;
  /// Geç olgunlaşma: yaşam evresi geçişleri 1.6× yavaş ilerler (çocukluk
  /// uzar, işgücüne katılım gecikir).
  bool slowMaturity;
  /// Komşuluk: yakın geçen NPC'ler birbirine selam verir (chat bubble +
  /// glance), sosyal aktivite artar.
  bool neighborliness;
  /// Aile birleşimi: solo göçmenler ya da yalnız kalan yetişkinler köyde
  /// uygun bekar partner bulursa otomatik bir araya gelir (aynı eve geçer).
  bool familyReunion;
  /// Doğa dostu: oduncu bir ağaç keserse yakına bir fidan diker.
  bool treePlanting;
  /// Müşterek hasat: geride kalan tarlalar geçici bonus growth rate alır,
  /// tarlalar dengeli ilerler.
  bool sharedHarvest;
  /// Yeşil köy: her tamamlanan binanın çevresine küçük çiçek/çalı kümesi.
  bool greenVillage;
  /// Otlama serbest: hayvan wander radius +50%.
  bool freeRange;
  /// Bir sonraki politika değişikliğine kadar sim time (sn). Cooldown bitene
  /// kadar UI butonları disabled görünür. Decree ağırlığı için gerekli.
  double cooldownUntilSim;

  VillagePolicies({
    this.family = FamilyPolicy.open,
    this.familyEncouragement = false,
    this.peacefulEnd = false,
    this.eldersExemptFromFood = false,
    this.hospitality = false,
    this.apprenticeship = false,
    this.slowMaturity = false,
    this.neighborliness = false,
    this.familyReunion = false,
    this.treePlanting = false,
    this.sharedHarvest = false,
    this.greenVillage = false,
    this.freeRange = false,
    this.cooldownUntilSim = 0,
  });

  /// Yürürlükteki (aktif) berat/politika sayısı — köyün Tüzük ilerlemesi için.
  /// family != open bir berat sayılır; açık her toggle bir berat. Pasif
  /// gösterge değil — akış kademesi (charterTier) buna bakar.
  int get enactedCount {
    var n = family != FamilyPolicy.open ? 1 : 0;
    for (final id in const [
      'familyEncouragement', 'peacefulEnd', 'eldersExemptFromFood',
      'hospitality', 'apprenticeship', 'slowMaturity', 'neighborliness',
      'familyReunion', 'treePlanting', 'sharedHarvest', 'greenVillage',
      'freeRange',
    ]) {
      if (isOn(id)) n++;
    }
    return n;
  }

  /// Aile politikasının izin verdiği maksimum çocuk sayısı.
  int get maxChildren => switch (family) {
        FamilyPolicy.open => 1 << 30,
        FamilyPolicy.oneChild => 1,
        FamilyPolicy.twoChild => 2,
      };

  /// Policy id → on/off lookup. UI metadata-driven listede kullanır.
  bool isOn(String id) => switch (id) {
        'familyEncouragement' => familyEncouragement,
        'peacefulEnd' => peacefulEnd,
        'eldersExemptFromFood' => eldersExemptFromFood,
        'hospitality' => hospitality,
        'apprenticeship' => apprenticeship,
        'slowMaturity' => slowMaturity,
        'neighborliness' => neighborliness,
        'familyReunion' => familyReunion,
        'treePlanting' => treePlanting,
        'sharedHarvest' => sharedHarvest,
        'greenVillage' => greenVillage,
        'freeRange' => freeRange,
        _ => false,
      };
}

/// Belediye nüfus planlama dashboard'ı için aggregat veri — yaş dağılımı,
/// çift/hamile sayımı, konut, yiyecek tüketimi. scene_ui hesaplayıp
/// BuildingInfoPanel'e geçirir; panel townhall için renderlar.
class PopulationPlanning {
  final int children;
  final int adults;
  final int elders;
  final int couples;       // ev'de aktif yetişkin kadın+erkek çift sayısı
  final int pregnantSoon;  // fertilityDays ≤ 1 olan kadın sayısı (yakında bebek)
  final int housedSlots;   // dolu yatak
  final int totalHousing;  // toplam yatak kapasitesi
  final double foodPerDay; // tüm ağızların günlük tüketimi
  final int foodStock;     // anlık stok
  const PopulationPlanning({
    required this.children,
    required this.adults,
    required this.elders,
    required this.couples,
    required this.pregnantSoon,
    required this.housedSlots,
    required this.totalHousing,
    required this.foodPerDay,
    required this.foodStock,
  });

  /// Kaç gün yetiştiği — sıfır tüketimde sonsuz.
  double get daysOfFoodLeft =>
      foodPerDay > 0.001 ? foodStock / foodPerDay : double.infinity;
}

/// Denge testi için zaman içinde kaynak/nüfus snapshot'u.
class SimSnapshot {
  final double simTime;
  final int day;
  final int population;
  final int buildings;
  final int wood, stone, iron, coal, food, gold;
  const SimSnapshot({
    required this.simTime,
    required this.day,
    required this.population,
    required this.buildings,
    required this.wood,
    required this.stone,
    required this.iron,
    required this.coal,
    required this.food,
    required this.gold,
  });
}
