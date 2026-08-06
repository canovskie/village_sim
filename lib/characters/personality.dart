import 'dart:math';
import 'villager_type.dart';

/// Bir köylünün mizacı — kişiliğin çekirdeği. Her köylüye 1-2 tanesi atanır.
/// Sadece görsel/anlatı + hafif davranış rengi (asla ceza/denge kırıcı değil).
enum Trait {
  cheerful('😄', 'Neşeli'),
  shy('😶', 'Çekingen'),
  diligent('💪', 'Çalışkan'),
  grumpy('😤', 'Huysuz'),
  curious('🤔', 'Meraklı'),
  gentle('🕊️', 'Yumuşak'),
  restless('🌀', 'Kıpır kıpır'),
  proud('🦚', 'Gururlu'),
  dreamer('💭', 'Hayalperest'),
  brave('🛡️', 'Cesur');

  final String icon;
  final String label;
  const Trait(this.icon, this.label);
}

/// Bir köylünün sevdiği şey — kişisel renk + hafif davranış eğilimi.
/// Ateş/hikaye/sohbet sevenler akşam ateş başına daha çok gelir ([atFireAffinity]).
enum Likes {
  fire('🔥', 'ateş başı'),
  stories('📖', 'hikâyeler'),
  company('🤝', 'sohbet'),
  flowers('🌸', 'çiçekler'),
  fishing('🎣', 'su kıyısı'),
  animals('🐑', 'hayvanlar'),
  harvest('🌾', 'hasat'),
  market('🪙', 'pazar'),
  solitude('🌙', 'yalnızlık'),
  stars('✨', 'yıldızlar');

  final String icon;
  final String label;
  const Likes(this.icon, this.label);

  /// Akşam ateş başı toplanmaya eğilim — bu sevgiler ateş çevresinde anlam bulur.
  bool get atFireAffinity =>
      this == Likes.fire || this == Likes.stories || this == Likes.company;
}

/// Bir köylünün değişmez kişiliği — seed'den deterministik üretilir (aynı seed →
/// aynı kişilik). Kayıt yalnızca seed'i tutar; kişilik yüklemede yeniden türer.
class Personality {
  /// 1-2 mizaç (ilki baskın).
  final List<Trait> traits;

  /// Sevdiği tek şey — kişisel renk.
  final Likes likes;

  /// Tek cümlelik künye/öykü — sevdiği şeye + mizaca dayalı.
  final String backstory;

  const Personality({
    required this.traits,
    required this.likes,
    required this.backstory,
  });

  Trait get dominant => traits.first;

  /// SOHBETE YATKINLIK (~0.5..1.5) — yalnızlık dürtüsünün ne hızla biriktiğini
  /// renklendirir (bkz. scene_mind). Çekingen bir köylü günlerce kimseyle
  /// konuşmadan durabilir, kıpır kıpır olan yarım günde meydana iner.
  ///
  /// Denge kırıcı değil, renk: uçlar bilerek dar tutulmuştur.
  double get sociability {
    var s = 1.0;
    for (final t in traits) {
      s += switch (t) {
        Trait.cheerful => 0.20,
        Trait.curious => 0.15,
        Trait.restless => 0.15,
        Trait.proud => 0.05,
        Trait.brave => 0.05,
        Trait.gentle => 0.0,
        Trait.diligent => -0.10,
        Trait.dreamer => -0.15,
        Trait.grumpy => -0.20,
        Trait.shy => -0.25,
      };
    }
    if (likes == Likes.company) s += 0.20;
    if (likes == Likes.solitude) s -= 0.25;
    return s.clamp(0.5, 1.5);
  }

  /// Seed'den kişilik üret. Tamamen deterministik.
  ///
  /// Meslek parametresi BİLEREK yok: bu projede ok ters yönde işliyor — kişilik
  /// mesleği doğurur (`callingFor`), meslek kişiliği değil. Eski imza bir
  /// `VillagerType` alıyordu ama hiç okumuyordu; çağıranlardan biri uydurma
  /// `VillagerType.farmer` geçiyordu.
  factory Personality.fromSeed(int seed) {
    final r = Random(seed);

    // 1-2 mizaç (çoğunlukla 2). İkincisi ilkinden farklı.
    final t0 = Trait.values[r.nextInt(Trait.values.length)];
    final traits = <Trait>[t0];
    if (r.nextInt(10) < 7) {
      Trait t1;
      do {
        t1 = Trait.values[r.nextInt(Trait.values.length)];
      } while (t1 == t0);
      traits.add(t1);
    }

    final likes = Likes.values[r.nextInt(Likes.values.length)];
    final pool = _backstories[likes]!;
    final backstory = pool[r.nextInt(pool.length)];

    return Personality(traits: traits, likes: likes, backstory: backstory);
  }
}

/// Bir kişilikten doğan **çağrı** — köylünün içindeki meslek eğilimi. Sevdiği
/// şey en güçlü tek ses, mizaç renklendirir; en yüksek skorlu meslek seçilir,
/// beraberlik [seed] ile deterministik çözülür (aynı kişilik+seed → aynı çağrı).
///
/// Yalnızca **sivil** meslekleri döner (çiftçi/tüccar/demirci/muhafız/rahip/
/// çoban/avcı/değirmenci/hancı); madenci & balıkçı kendi bina-NPC'leridir,
/// doğumla edinilmez. Bu, köyde doğan/göçen köylülerin meslek havuzuyla
/// birebir uyumludur.
VillagerType callingFor(Personality p, int seed) {
  final score = <VillagerType, double>{
    VillagerType.farmer: 0,
    VillagerType.merchant: 0,
    VillagerType.blacksmith: 0,
    VillagerType.guard: 0,
    VillagerType.priest: 0,
    VillagerType.shepherd: 0,
    VillagerType.hunter: 0,
    VillagerType.miller: 0,
    VillagerType.innkeeper: 0,
  };
  void add(VillagerType t, double w) => score[t] = score[t]! + w;

  // Sevdiği şey — en güçlü tek işaret.
  switch (p.likes) {
    case Likes.harvest:
      add(VillagerType.farmer, 3);
      add(VillagerType.miller, 1.5); // başak → un, aynı zincir
    case Likes.animals:
      add(VillagerType.shepherd, 3); // sürünün çağrısı
      add(VillagerType.farmer, 1);
    case Likes.flowers:
      add(VillagerType.farmer, 2);
      add(VillagerType.priest, 0.5);
    case Likes.fishing:
      add(VillagerType.hunter, 1.5); // sabır + kır
      add(VillagerType.farmer, 1);
      add(VillagerType.priest, 0.5);
    case Likes.market:
      add(VillagerType.merchant, 3);
      add(VillagerType.innkeeper, 1.5);
    case Likes.company:
      add(VillagerType.innkeeper, 2.5); // kalabalığı ağırlamak
      add(VillagerType.merchant, 2);
    case Likes.fire:
      add(VillagerType.blacksmith, 3);
      add(VillagerType.miller, 1); // fırın da ateştir
    case Likes.stories:
      add(VillagerType.priest, 2);
      add(VillagerType.innkeeper, 1.5); // han sohbeti
      add(VillagerType.merchant, 1);
    case Likes.solitude:
      add(VillagerType.hunter, 2); // ormanın sessizliği
      add(VillagerType.priest, 2);
      add(VillagerType.blacksmith, 1);
    case Likes.stars:
      add(VillagerType.priest, 3);
  }

  // Mizaç — baskın olan 1.5×, ikincil 1.0× ağırlık.
  for (int i = 0; i < p.traits.length; i++) {
    final w = i == 0 ? 1.5 : 1.0;
    switch (p.traits[i]) {
      case Trait.brave:
        add(VillagerType.guard, 3 * w);
        add(VillagerType.hunter, 2 * w);
      case Trait.proud:
        add(VillagerType.guard, 2 * w);
        add(VillagerType.merchant, 1 * w);
      case Trait.diligent:
        add(VillagerType.blacksmith, 2 * w);
        add(VillagerType.miller, 2 * w);
        add(VillagerType.farmer, 1 * w);
      case Trait.grumpy:
        add(VillagerType.blacksmith, 2 * w);
        add(VillagerType.miller, 1 * w);
      case Trait.restless:
        add(VillagerType.hunter, 2 * w);
        add(VillagerType.guard, 1 * w);
        add(VillagerType.merchant, 1 * w);
      case Trait.curious:
        add(VillagerType.priest, 2 * w);
        add(VillagerType.hunter, 1 * w);
      case Trait.dreamer:
        add(VillagerType.priest, 2 * w);
      case Trait.shy:
        add(VillagerType.shepherd, 1.5 * w); // sürüyle konuşmak kolaydır
        add(VillagerType.priest, 1 * w);
        add(VillagerType.farmer, 1 * w);
      case Trait.gentle:
        add(VillagerType.shepherd, 2 * w);
        add(VillagerType.farmer, 2 * w);
      case Trait.cheerful:
        add(VillagerType.innkeeper, 2.5 * w);
        add(VillagerType.merchant, 2 * w);
    }
  }

  // En yüksek skor; beraberlikte seed ile deterministik seçim.
  double best = -1;
  for (final s in score.values) {
    if (s > best) best = s;
  }
  final tied = [
    for (final e in score.entries)
      if (e.value >= best - 1e-9) e.key
  ];
  return tied[seed.abs() % tied.length];
}

/// Sevdiği şeye göre künye havuzu — bir cümlelik SOMUT insan detayı (alışkanlık,
/// eşya, kusur), açıklama değil. Seed havuzdan seçer.
const Map<Likes, List<String>> _backstories = {
  Likes.fire: [
    'Elini alevlere fazla yaklaştırır; parmak uçlarında eski yanık izleri var.',
    'Ateşi hep o tutuşturur. Başkası denerse tepesi atar.',
    'Karanlık çökünce sırtını rüzgâra, yüzünü kora çevirir.',
  ],
  Likes.stories: [
    'Duyduğu masalı bir daha anlatır, her seferinde biraz uzatır.',
    'Anlatıcı susunca ilk soruyu hep o sorar.',
    'Bir gün kendi adının da anlatılacağını umuyor, ama kimseye söylemiyor.',
  ],
  Likes.company: [
    'Tek kişilik sofraya oturmaz; bir bahane uydurup komşu kapısını çalar.',
    'Kalabalıkta pek konuşmaz. Orada olmak yeter ona.',
    'Herkesin adını bilir, kimin neyi sevmediğini de.',
  ],
  Likes.flowers: [
    'Pencere önündeki kırık testide her zaman taze bir dal durur.',
    'Kokusuna göre ayırır çiçekleri; adlarını çoğu zaman karıştırır.',
    'Baharın ilk tomurcuğunu herkesten önce görür ve kimseye söylemez.',
  ],
  Likes.fishing: [
    'Kıyıda saatlerce oturur; oltasının ucu çoğu gün boş döner, umursamaz.',
    'Ayakkabılarının içi hep nemlidir.',
    'Su sesi olmayan bir gecede zor uyuyor.',
  ],
  Likes.animals: [
    'Her kuzuya ad takar, sonra hepsini birbirine karıştırır.',
    'Hayvanlar onun elinden ilk günden yem alır; kimse sebebini bilmiyor.',
    'Cebinde daima bir tutam arpa taşır.',
  ],
  Likes.harvest: [
    'Ambarı sebepsiz açar, içine bakar, kapatır.',
    'Toprağı avucuna alıp koklar; yağmuru bir gün önceden bildiğini söyler.',
    'Hasat vakti geldi mi geceyi birkaç saatlik uykuyla geçirir.',
  ],
  Likes.market: [
    'Pazarlıkta acele etmez; karşısındakini bıktırıp fiyatı kırar.',
    'Kesesini saymadan yatmaz.',
    'Bir kez kötü takas yaptı, yıllardır anlatıyor.',
  ],
  Likes.solitude: [
    'Kalabalıktan sıyrılıp tepeye çıkar, nereye gittiğini söylemez.',
    'Az konuşuyor diye kimseye küs değil. Öyle işte.',
    'Yemeğini çoğu akşam eşikte, tek başına yer.',
  ],
  Likes.stars: [
    'Berrak gecelerde damda uyuyakalır; sabah üstü çiy içinde bulunur.',
    'Takımyıldızlara kendi adlarını koymuş, listeyi kimseye göstermiyor.',
    'Yıldız kayınca dileğini yüksek sesle söyler, sonra utanır.',
  ],
};
