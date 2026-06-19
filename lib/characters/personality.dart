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
