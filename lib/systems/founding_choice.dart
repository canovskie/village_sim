import '../characters/villager_type.dart';

/// KAFİLENİN YÜKÜ — oyuncunun oyundaki İLK kararı.
///
/// Açılış eskiden şöyleydi: altı çekimlik sinematiği izle, köye bir ad ver,
/// ateşin yerini seç. Yani oyuncu kuruluşta hiçbir şey SEÇMİYORDU; kadro da
/// stok da her koşuda aynıydı. "Kurulumda karar yok, ilk dakikalar sığ"
/// şikâyetinin kaynağı buydu.
///
/// Şimdi kafile yola çıkarken arabaya her şey sığmıyor: azık mı, alet mi,
/// yoksa geride bırakılacak bir can mı? Seçim sinematiğin İÇİNDE veriliyor
/// (ayrı bir kurulum ekranı yok) ve doğrudan simülasyona giriyor — kurucu
/// kadronun meslekleri, köyün nüfusu ve başlangıç stoğu buradan gelir.
///
/// KURAL — cinsiyet deseni sabittir: (♂ ♀ ♂ ♀ ♂yaşlı). Barınak ataması listeyi
/// baştan tarar, yani yan yana duran iki kişi ilk kapasiteli evi çift olarak
/// paylaşır (bkz. `_spawnFoundingCaravan`). Deseni bozan bir kadro çiftleri
/// ayırır ve doğumu sessizce susturur. Beşinci her zaman yaşlı duldur
/// (ateş başı hikâye saatinin sesi). Beşten sonrası "fazladan can"dır:
/// bekâr gelir, dışarıdan bir eş bekler (tek soy kuralı korunur).
class FoundingChoice {
  final String id;
  final String icon;

  /// Kartın başlığı — arabaya ne yüklendiği.
  final String title;

  /// Tek cümlelik anlatı (ne getirdik).
  final String blurb;

  /// Tek cümlelik BEDEL (neyi bıraktık). Kartta kısık renkte durur —
  /// karar ancak bedeli görünürse karardır.
  final String cost;

  /// Kurucu kadro: (meslek, erkek mi). Sıra kritik — yukarıdaki kurala bak.
  final List<(VillagerType, bool)> roster;

  final int wood;
  final int stone;
  final int food;

  const FoundingChoice({
    required this.id,
    required this.icon,
    required this.title,
    required this.blurb,
    required this.cost,
    required this.roster,
    required this.wood,
    required this.stone,
    required this.food,
  });

  /// Kadronun kaç kişi olduğu — kartta "n ağız" olarak görünür.
  int get people => roster.length;

  /// Yeni oyuncuya kararın sonucunu anlatan kısa özet. Açılışta ham stok
  /// sayıları göstermek, henüz odunun/taşın ne işe yaradığını bilmeyen kişiye
  /// seçim yaptırmak yerine muhasebe yaptırıyordu.
  String get choiceSummary => switch (id) {
    'seed' => 'Bol yiyecek',
    'tools' => 'Hızlı inşaat',
    'people' => 'Bir kişi fazla',
    _ => 'Dengeli başlangıç',
  };

  /// Sinematikteki üç seçenek. Denge kasıtlı olarak ÜÇ AYRI EKSENDE kurulu:
  /// azık (zaman kazandırır), alet (sonraki binalara pay bırakır), can (el
  /// sayısı artırır). Her yük, zorunlu kuruluş zincirini beklemeden kuracak
  /// tabanı taşır; seçim bu tabanın ÜSTÜNDE farklı bir avantaj verir. Hiçbiri
  /// "doğru" değil — hepsi ilk iki günün ritmini başka türlü büker.
  static const List<FoundingChoice> all = [
    FoundingChoice(
      id: 'seed',
      icon: '🌾',
      title: 'Tohum sandığını yükledik',
      blurb: 'Tohum, kuru et, bir de değirmen taşı. Kimse aç kalmayacak.',
      cost: 'Az odun',
      roster: [
        (VillagerType.farmer, true), // reis
        (VillagerType.miller, false), // eşi
        (VillagerType.shepherd, true),
        (VillagerType.farmer, false), // eşi
        (VillagerType.priest, true), // dul yaşlı
      ],
      wood: 56,
      stone: 16,
      food: 80,
    ),
    FoundingChoice(
      id: 'tools',
      icon: '🪓',
      title: 'Aletleri yükledik',
      blurb: 'Balta, keser, testere, bir çuval çivi. İlk dam çabuk kalkar.',
      cost: 'Az yiyecek',
      roster: [
        (VillagerType.farmer, true),
        (VillagerType.shepherd, false),
        (VillagerType.blacksmith, true),
        (VillagerType.miller, false),
        (VillagerType.priest, true),
      ],
      wood: 68,
      stone: 30,
      food: 48,
    ),
    FoundingChoice(
      id: 'people',
      icon: '🤝',
      title: 'Kimseyi bırakmadık',
      blurb: 'Araba yük yerine can aldı — kafiledeki öksüz çocuk da bizimle.',
      cost: 'Az alet ve azık',
      roster: [
        (VillagerType.farmer, true),
        (VillagerType.shepherd, false),
        (VillagerType.hunter, true),
        (VillagerType.miller, false),
        (VillagerType.priest, true),
        (
          VillagerType.hunter,
          true,
        ), // fazladan can — bekâr, eşi dışarıdan gelir
      ],
      wood: 56,
      stone: 16,
      food: 64,
    ),
  ];

  /// Sinematik ATLANIRSA uygulanan kadro. Oyuncu seçmediyse de köy bir kararla
  /// kurulmalı — kimse "seçimsiz" başlamaz.
  static const FoundingChoice fallback = FoundingChoice(
    id: 'balanced',
    icon: '🧭',
    title: 'Elimizde ne varsa',
    blurb: 'Aceleyle yüklenmiş bir araba: biraz azık, biraz alet.',
    cost: 'Her şeyden biraz',
    roster: [
      (VillagerType.farmer, true),
      (VillagerType.shepherd, false),
      (VillagerType.hunter, true),
      (VillagerType.miller, false),
      (VillagerType.priest, true),
    ],
    wood: 56,
    stone: 16,
    food: 56,
  );

  static FoundingChoice byId(String id) {
    for (final c in all) {
      if (c.id == id) return c;
    }
    return fallback;
  }
}
