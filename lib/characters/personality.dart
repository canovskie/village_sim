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

  /// Seed + tip'ten kişilik üret. Tamamen deterministik.
  factory Personality.fromSeed(int seed, VillagerType type) {
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
/// Yalnızca **sivil** meslekleri döner (çiftçi/tüccar/demirci/muhafız/büyücü);
/// madenci & balıkçı kendi bina-NPC'leridir, doğumla edinilmez. Bu, köyde
/// doğan/göçen köylülerin meslek havuzuyla birebir uyumludur.
VillagerType callingFor(Personality p, int seed) {
  final score = <VillagerType, double>{
    VillagerType.farmer: 0,
    VillagerType.merchant: 0,
    VillagerType.blacksmith: 0,
    VillagerType.guard: 0,
    VillagerType.mage: 0,
  };
  void add(VillagerType t, double w) => score[t] = score[t]! + w;

  // Sevdiği şey — en güçlü tek işaret.
  switch (p.likes) {
    case Likes.harvest:
      add(VillagerType.farmer, 3);
    case Likes.animals:
      add(VillagerType.farmer, 3);
    case Likes.flowers:
      add(VillagerType.farmer, 2);
      add(VillagerType.mage, 0.5);
    case Likes.fishing:
      add(VillagerType.farmer, 1);
      add(VillagerType.mage, 1);
    case Likes.market:
      add(VillagerType.merchant, 3);
    case Likes.company:
      add(VillagerType.merchant, 2);
    case Likes.fire:
      add(VillagerType.blacksmith, 3);
    case Likes.stories:
      add(VillagerType.mage, 2);
      add(VillagerType.merchant, 1);
    case Likes.solitude:
      add(VillagerType.mage, 2);
      add(VillagerType.blacksmith, 1);
    case Likes.stars:
      add(VillagerType.mage, 3);
  }

  // Mizaç — baskın olan 1.5×, ikincil 1.0× ağırlık.
  for (int i = 0; i < p.traits.length; i++) {
    final w = i == 0 ? 1.5 : 1.0;
    switch (p.traits[i]) {
      case Trait.brave:
        add(VillagerType.guard, 3 * w);
      case Trait.proud:
        add(VillagerType.guard, 2 * w);
        add(VillagerType.merchant, 1 * w);
      case Trait.diligent:
        add(VillagerType.blacksmith, 2 * w);
        add(VillagerType.farmer, 1 * w);
      case Trait.grumpy:
        add(VillagerType.blacksmith, 2 * w);
      case Trait.restless:
        add(VillagerType.guard, 1 * w);
        add(VillagerType.merchant, 1 * w);
      case Trait.curious:
        add(VillagerType.mage, 2 * w);
      case Trait.dreamer:
        add(VillagerType.mage, 2 * w);
      case Trait.shy:
        add(VillagerType.mage, 1 * w);
        add(VillagerType.farmer, 1 * w);
      case Trait.gentle:
        add(VillagerType.farmer, 2 * w);
      case Trait.cheerful:
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

/// Sevdiği şeye göre künye havuzu — sıcak, tek cümlelik. Seed havuzdan seçer.
const Map<Likes, List<String>> _backstories = {
  Likes.fire: [
    'Akşamları ateşin çıtırtısında huzur bulur.',
    'En sevdiği yer, alevin ısıttığı o küçük çember.',
    'Karanlık çökünce gözleri hep ateşi arar.',
  ],
  Likes.stories: [
    'Eski bir masalı dinlemek için her şeyi bırakır.',
    'Anlatılan her hikâyeyi yıllarca aklında tutar.',
    'Bir gün kendi öyküsünün anlatılmasını diler.',
  ],
  Likes.company: [
    'Kalabalığın sıcaklığı olmadan duramaz.',
    'Bir gülüşü paylaşmak ona yeter.',
    'Yalnız bir akşamı asla sevmedi.',
  ],
  Likes.flowers: [
    'Yol kenarındaki her çiçeğe eğilip bakar.',
    'Evinin önünü çiçeklendirmek en büyük zevki.',
    'Baharın ilk tomurcuğunu herkesten önce görür.',
  ],
  Likes.fishing: [
    'Suyun kıyısında saatlerce oturabilir.',
    'Denizi özler, sular onu çağırır.',
    'Durgun bir gölün yüzü onu büyüler.',
  ],
  Likes.animals: [
    'Sürünün arasında kendini evinde hisseder.',
    'Her kuzuya bir ad takar.',
    'Hayvanların dilinden anladığına inanır.',
  ],
  Likes.harvest: [
    'Dolu bir ambardan daha güzel bir şey bilmez.',
    'Toprağın kokusu içini ısıtır.',
    'Hasat vakti gözleri parlar.',
  ],
  Likes.market: [
    'Pazarın curcunasında pazarlık etmeye bayılır.',
    'Bir kese altının şıkırtısı onu mutlu eder.',
    'En iyi takası yapmakla övünür.',
  ],
  Likes.solitude: [
    'Tek başına bir yürüyüş ona dünyaları değer.',
    'Sessizlikte kendi düşüncelerine sığınır.',
    'Kalabalıktan sıyrılıp ufka bakmayı sever.',
  ],
  Likes.stars: [
    'Berrak gecelerde başını göğe çevirip kaybolur.',
    'Yıldızların bir gün ona yol göstereceğine inanır.',
    'Her takımyıldıza kendi adını koymuş.',
  ],
};
