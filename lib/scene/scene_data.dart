import '../systems/event_system.dart';
import '../systems/law_book.dart';

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

/// Aile planlaması — anne başına izinli doğum sayısı. Artık bir "ayar" değil,
/// Kanunname'deki iki mutex fermanın (`oneChild` / `twoChild`) OKUNUŞU:
/// hiçbiri mühürlü değilse [open]. Bkz. [VillagePolicies.family].
enum FamilyPolicy {
  open('Serbest'),
  oneChild('Tek beşik'),
  twoChild('İki beşik');

  final String label;
  const FamilyPolicy(this.label);
}


/// KANUNNAME'nin sahne tarafındaki hâli — hangi fermanlar mühürlü, hangi
/// davaya girildi, mürekkep ne zaman kurur.
///
/// Tek doğruluk kaynağı [sealed]'dir. Alttaki bool'lar sim'in HIZLI OKUMA
/// yüzeyi (tick döngüsü her karede `sealed.contains(...)` yapmasın diye);
/// [seal] ikisini birlikte yürütür. Bool'lar asla tek başına flip edilmez —
/// mühür geri alınmaz, o yüzden hepsi tek yönlü: false → true.
class VillagePolicies {
  /// Mühürlenmiş ferman id'leri (bkz. [kLawBook]). Defterin kendisi.
  final Set<String> sealed = {};

  /// Mürekkep bu sim time'a kadar ıslak — o ana dek yeni mühür basılamaz.
  /// Cooldown bir ceza değil, oyunun ritmi: "bugün hangi TEK fermanı?"
  double inkDryUntilSim;

  // ── Sim'in hızlı okuma yüzeyi (hepsi bir LawDef id'sinin yansıması) ────────
  bool familyEncouragement = false;
  bool peacefulEnd = false;
  bool eldersExemptFromFood = false;
  bool hospitality = false;
  bool apprenticeship = false;
  bool tradeGuidance = false;
  bool slowMaturity = false;
  bool neighborliness = false;
  bool familyReunion = false;
  bool treePlanting = false;
  bool sharedHarvest = false;
  bool cropRotation = false;
  bool irrigation = false;
  bool farmLabor = false;
  bool greenVillage = false;
  bool freeRange = false;
  bool herdGrowth = false;
  bool winterFodder = false;
  bool quarantine = false;
  bool hearthWatch = false;
  bool outsideMarriage = false;

  VillagePolicies({this.inkDryUntilSim = 0});

  /// Mühür seti her değiştiğinde çağrılır — sahne KÖYÜN HÂLİ tablosunu
  /// ([WorldPressure]) burada tazeler. Tek kanca: mühür/fesih/kayıttan dönüş
  /// hepsi buradan geçer, böylece "şu çağrı yerinde tazelemeyi unutmuşum"
  /// sınıfı hatalar mümkün olmaz. Sahne kurulmadan önce null.
  void Function()? onChanged;

  /// Bir fermanı deftere geçir. GERİ ALINMAZ — [sealed]'den bir şey çıkmaz.
  /// Sıra/path/foreclosure YOK: serbest katalog, tek sınır bedel+tempo+siyaset.
  void seal(LawDef l) {
    sealed.add(l.id);
    _mirror(l.id);
    onChanged?.call();
  }

  /// Mühürlü id → sim bool'u. Tek yönlü (mühür kalkmaz).
  void _mirror(String id) {
    switch (id) {
      case 'familyEncouragement': familyEncouragement = true;
      case 'peacefulEnd': peacefulEnd = true;
      case 'eldersExemptFromFood': eldersExemptFromFood = true;
      case 'hospitality': hospitality = true;
      case 'apprenticeship': apprenticeship = true;
      case 'tradeGuidance': tradeGuidance = true;
      case 'slowMaturity': slowMaturity = true;
      case 'neighborliness': neighborliness = true;
      case 'familyReunion': familyReunion = true;
      case 'treePlanting': treePlanting = true;
      case 'sharedHarvest': sharedHarvest = true;
      case 'cropRotation': cropRotation = true;
      case 'irrigation': irrigation = true;
      case 'farmLabor': farmLabor = true;
      case 'greenVillage': greenVillage = true;
      case 'freeRange': freeRange = true;
      case 'herdGrowth': herdGrowth = true;
      case 'winterFodder': winterFodder = true;
      case 'quarantine': quarantine = true;
      case 'hearthWatch': hearthWatch = true;
      case 'outsideMarriage': outsideMarriage = true;
    }
  }

  /// Kayıttan dönüş (ve dev "defteri yak") — mühür setini olduğu gibi kur,
  /// bool'ları SIFIRDAN ondan türet. Tek yerde `sealed` boşalabilir: burası.
  void restoreSealed(Iterable<String> ids) {
    familyEncouragement = false;
    peacefulEnd = false;
    eldersExemptFromFood = false;
    hospitality = false;
    apprenticeship = false;
    tradeGuidance = false;
    slowMaturity = false;
    neighborliness = false;
    familyReunion = false;
    treePlanting = false;
    sharedHarvest = false;
    cropRotation = false;
    irrigation = false;
    farmLabor = false;
    greenVillage = false;
    freeRange = false;
    herdGrowth = false;
    winterFodder = false;
    quarantine = false;
    hearthWatch = false;
    outsideMarriage = false;
    sealed
      ..clear()
      ..addAll(ids);
    for (final id in sealed) {
      _mirror(id);
    }
    onChanged?.call();
  }

  /// Aile planlaması — iki mutex fermanın okunuşu (ayrı bir state değil).
  FamilyPolicy get family => sealed.contains('oneChild')
      ? FamilyPolicy.oneChild
      : sealed.contains('twoChild')
          ? FamilyPolicy.twoChild
          : FamilyPolicy.open;

  /// Aile fermanının izin verdiği maksimum çocuk sayısı.
  int get maxChildren => switch (family) {
        FamilyPolicy.open => 1 << 30,
        FamilyPolicy.oneChild => 1,
        FamilyPolicy.twoChild => 2,
      };

  /// Defterdeki ferman sayısı — Tüzük kademesi (charterTier) buna bakar.
  int get enactedCount => sealed.length;
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
