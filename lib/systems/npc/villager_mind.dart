import 'dart:math';

/// DÜRTÜ — köylünün içindeki basınç. 0 = yok, 1 = dayanılmaz.
///
/// Bunlar "stat" değil: panelde çubuk olarak gösterilmezler, doğrudan bir sayı
/// olarak hiçbir şeye çarpılmazlar. Tek işleri **teklif puanı üretmek** —
/// köylünün bir sonraki eylemini neden seçtiğini açıklamak. Dürtü yükselince
/// ilgili teklif güçlenir, eylem yapılınca dürtü söner.
enum Drive {
  /// Açlık — sofra/pazar/ambar çeker.
  hunger,

  /// Yorgunluk — ev/yatak çeker. Gün boyu çalışmak büyütür, uyku söndürür.
  fatigue,

  /// Üşüme — ateş başı çeker. Gece + kış + yağmur büyütür.
  chill,

  /// Yalnızlık — komşu/meyhane/meydan çeker. Sohbet söndürür.
  company,

  /// Tedirginlik — eve/kalabalığa çeker, sokaktan kaçırır. Suç/kavga/baskı
  /// büyütür.
  unease,

  /// İşe yaramama — mesleğin işi çeker. İşsiz geçen zaman büyütür.
  purpose,
}

/// NİYET — köylünün o an ne yapmaya çalıştığı. `activity` (render durumu)
/// değil, **amaç**. Bir köylü "meydana yürüyor" olabilir ama niyeti
/// [IntentKind.social] ya da [IntentKind.worship] olabilir; oyuncuya
/// gösterilen sebep budur.
enum IntentKind {
  /// Hiçbir şey istemiyor — hakem henüz karar vermedi ya da teklif yok.
  idle,

  /// Mesleğinin işi (tezgâh, tarla, sürü, nöbet).
  work,

  /// Amaçlı gidiş — pazar, kuyu, komşu, gezinti.
  errand,

  /// Ateş başı, ısınma.
  hearth,

  /// Sohbet/müzik/dans.
  social,

  /// Mabet.
  worship,

  /// Eve/yatağa çekilme.
  rest,

  /// Kendine iş çıkarma (saz biçme, yatak kurma) — evsizin geçim uğraşı.
  forage,

  /// Gördüğü suçu devriyeye haber vermeye koşma.
  inform,

  /// Suç.
  crime,

  /// Çekişme/kavga.
  quarrel,

  /// Tehlikeden kaçış.
  flee,

  /// Dışarıdan dayatılan sahne (düğün, cenaze, ferman, imparatorluk).
  /// Köylünün kendi tercihi değildir; hakem buna karşı teklif toplamaz.
  ceremony,
}

/// Niyetin kesilebilirlik sırası. Aynı öncelikteki iki niyet PUANLA yarışır;
/// farklı öncelikte olan her zaman yüksek olanı kazanır.
///
/// Tasarım: bir köylü sohbet ederken açlıktan işini bırakabilir, ama düğün
/// alayındaki bir köylü acıktı diye alaydan kopmaz.
abstract final class IntentPriority {
  /// Dışarıdan dayatılan sahne — hiçbir dürtü bunu bölemez.
  static const int ceremony = 100;

  /// Can derdi — kaçış.
  static const int danger = 80;

  /// Başlamış suç/kavga — yarıda kesilirse sahne saçmalar.
  static const int committed = 60;

  /// Mesleğin işi.
  static const int work = 40;

  /// Gövdenin ihtiyacı — uyku, ısınma, ibadet, geçim.
  static const int need = 30;

  /// Gündelik akış — gidiş geliş, sohbet.
  static const int routine = 20;

  static const int none = 0;
}

/// Bir sistemin köylü için verdiği TEKLİF.
///
/// Sistemler artık köylüyü KAPMAZ (`if (activity == none) onu al`), teklif
/// verir. Hakem ([VillagerMind.deliberate]) kazananı seçer ve yalnız onun
/// [begin] geri çağrısını çalıştırır. "Tick sırasında kim önce gelirse o alır"
/// yarışı böylece biter.
class Bid {
  final IntentKind kind;

  /// Ne kadar istiyor (0..~2). Dürtü + dünya basıncı + kişilikten doğar.
  final double score;

  /// Oyuncuya gösterilecek SEBEP — birinci ağızdan, kısa. Köylü panelinde
  /// "şu an ne yapıyor ve neden" satırı budur. Boş bırakılamaz: sebebi
  /// yazılamayan bir davranış, oyuncunun anlayamayacağı bir davranıştır.
  final String reason;

  final int priority;

  /// Kazanırsa çalışacak eylem — köylüyü fiilen yola koyan kod.
  final void Function() begin;

  Bid({
    required this.kind,
    required this.score,
    required this.reason,
    required this.priority,
    required this.begin,
  }) : assert(reason.isNotEmpty, 'Sebepsiz teklif olmaz');
}

/// Yürürlükteki niyet — kazanan teklifin kalıcı izi.
class Intent {
  final IntentKind kind;
  final String reason;
  final int priority;
  final double score;

  const Intent({
    required this.kind,
    required this.reason,
    required this.priority,
    required this.score,
  });

  static const Intent idle = Intent(
    kind: IntentKind.idle,
    reason: 'boşta',
    priority: IntentPriority.none,
    score: 0,
  );

  bool get isIdle => kind == IntentKind.idle;
}

/// KÖYLÜNÜN AKLI — dürtüleri tutar, teklifleri tartar, niyeti seçer.
///
/// Saf sınıf: sahneyi, dünyayı, Flutter'ı bilmez. Girdi olarak yalnız dürtü
/// güncellemeleri ve teklif listesi alır. Bu sayede davranışın kalbi test
/// edilebilir kalır ([test/villager_mind_test.dart]).
class VillagerMind {
  /// Dürtü değerleri 0..1.
  final Map<Drive, double> _drives = {
    for (final d in Drive.values) d: 0.0,
  };

  Intent _intent = Intent.idle;

  /// Yürürlükteki niyet.
  Intent get intent => _intent;

  /// Bir sonraki müzakereye kalan süre (sn). Hakem her karede değil,
  /// aralıklarla düşünür — hem ucuz hem de "her an fikir değiştiren" köylü
  /// olmaz.
  double deliberateIn = 0;

  /// Niyetin ne kadardır sürdüğü (sn) — histerezis ve takılma teşhisi için.
  double intentAge = 0;

  double drive(Drive d) => _drives[d] ?? 0;

  /// Dürtüyü doğrudan kur (kayıttan dönüş / test).
  void setDrive(Drive d, double v) => _drives[d] = v.clamp(0.0, 1.0);

  /// Dürtüyü ilerlet. [rate] saniyedeki değişim; pozitif büyütür, negatif söndürür.
  void pushDrive(Drive d, double rate, double dt) {
    _drives[d] = ((_drives[d] ?? 0) + rate * dt).clamp(0.0, 1.0);
  }

  /// Bir eylem dürtüyü GİDERDİ — anında düşür (yemek yendi, sohbet edildi).
  void satisfy(Drive d, double amount) {
    _drives[d] = ((_drives[d] ?? 0) - amount).clamp(0.0, 1.0);
  }

  /// En baskın dürtü — köylü panelinde "şu an derdi ne" satırı.
  Drive get dominant {
    var best = Drive.purpose;
    var bestV = -1.0;
    for (final e in _drives.entries) {
      if (e.value > bestV) {
        bestV = e.value;
        best = e.key;
      }
    }
    return best;
  }

  /// Yeni niyeti zorla (tören/dayatma) — teklif yarışını atlar.
  void impose(IntentKind kind, String reason,
      {int priority = IntentPriority.ceremony}) {
    _intent = Intent(
        kind: kind, reason: reason, priority: priority, score: double.infinity);
    intentAge = 0;
  }

  /// Niyeti bitir — köylü boşa düşer, hakem bir sonraki turda yeniden seçer.
  void clear() {
    _intent = Intent.idle;
    intentAge = 0;
  }

  /// Mevcut niyet bu türden mi (sistemler "bu köylü benim mi" diye sorar).
  bool owns(IntentKind kind) => _intent.kind == kind;

  /// Yeni teklif yürürlükteki niyeti bölebilir mi?
  ///
  /// Kural: yüksek öncelik her zaman böler. Aynı öncelikte ise yalnız
  /// BELİRGİN biçimde daha iyi bir teklif böler ([kSwitchMargin]) — yoksa
  /// köylü iki eşdeğer hedef arasında gidip gelip titrer.
  bool canInterrupt(Bid b) {
    if (_intent.isIdle) return true;
    if (b.priority > _intent.priority) return true;
    if (b.priority < _intent.priority) return false;
    return b.score > _intent.score * kSwitchMargin;
  }

  /// Aynı öncelikte niyet değiştirmek için gereken üstünlük.
  static const double kSwitchMargin = 1.25;

  /// MÜZAKERE — teklifleri tart, kazananı seç, çalıştır.
  ///
  /// Dönüş: niyet değiştiyse true. Teklif yoksa ya da hiçbiri mevcut niyeti
  /// bölemiyorsa köylü ne yapıyorsa onu yapmaya devam eder.
  bool deliberate(List<Bid> bids) {
    if (bids.isEmpty) return false;
    Bid? best;
    for (final b in bids) {
      if (b.score <= 0) continue;
      if (best == null ||
          b.priority > best.priority ||
          (b.priority == best.priority && b.score > best.score)) {
        best = b;
      }
    }
    if (best == null) return false;
    if (!canInterrupt(best)) return false;

    _intent = Intent(
      kind: best.kind,
      reason: best.reason,
      priority: best.priority,
      score: best.score,
    );
    intentAge = 0;
    best.begin();
    return true;
  }

  /// Zamanı ilerlet (sayaçlar).
  void tick(double dt) {
    intentAge += dt;
    if (deliberateIn > 0) deliberateIn -= dt;
  }

  /// Dürtü dökümü — dev konsolu/panel için okunur özet.
  List<String> get readout {
    final out = <String>[];
    for (final e in _drives.entries) {
      if (e.value < 0.12) continue;
      out.add('${driveLabel(e.key)} ${(e.value * 100).round()}');
    }
    return out;
  }

  /// Kayıt/geri yükleme için dürtü haritası.
  Map<String, double> toJson() =>
      {for (final e in _drives.entries) e.key.name: e.value};

  void restore(Map<String, dynamic> j) {
    for (final d in Drive.values) {
      final v = j[d.name];
      if (v is num) _drives[d] = v.toDouble().clamp(0.0, 1.0);
    }
  }
}

/// Dürtünün oyuncu-yüzü adı.
String driveLabel(Drive d) => switch (d) {
      Drive.hunger => 'açlık',
      Drive.fatigue => 'yorgunluk',
      Drive.chill => 'üşüme',
      Drive.company => 'yalnızlık',
      Drive.unease => 'tedirginlik',
      Drive.purpose => 'işsizlik',
    };

/// Niyetin oyuncu-yüzü adı — köylü panelinde başlık.
String intentLabel(IntentKind k) => switch (k) {
      IntentKind.idle => 'Boşta',
      IntentKind.work => 'İşinde',
      IntentKind.errand => 'Yolda',
      IntentKind.hearth => 'Ateş başında',
      IntentKind.social => 'Sohbette',
      IntentKind.worship => 'İbadette',
      IntentKind.rest => 'Dinlenmede',
      IntentKind.forage => 'Geçim derdinde',
      IntentKind.inform => 'Haber vermeye koşuyor',
      IntentKind.crime => 'Bir işin peşinde',
      IntentKind.quarrel => 'Kavgada',
      IntentKind.flee => 'Kaçışta',
      IntentKind.ceremony => 'Törende',
    };

/// Teklif puanı için ortak eğri: dürtü eşiği aşınca hızla ağırlaşır.
///
/// Doğrusal puan "biraz acıkmış" ile "açlıktan ölüyor"u aynı görür; bu eğri
/// eşiğin altını neredeyse yok sayar, üstünü keskinleştirir. Böylece köylü
/// önemsiz dürtüyle işini bırakmaz ama gerçek ihtiyaçta bırakır.
double urgency(double drive, {double threshold = 0.35}) {
  if (drive <= threshold) return 0;
  final t = (drive - threshold) / (1.0 - threshold);
  return t * t;
}

/// Küçük deterministik serpinti — aynı dürtüye sahip iki köylü aynı anda aynı
/// kararı vermesin (sürü hâlinde hareket sahte durur). Köylünün seed'inden
/// türer, rastgele değil: aynı köylü aynı koşulda aynı eğilimi gösterir.
double jitterFor(int seed, IntentKind kind) {
  final h = (seed * 2654435761 + kind.index * 40503) & 0x7fffffff;
  return 0.92 + (h % 1000) / 1000.0 * 0.16; // 0.92..1.08
}

/// Test/denge için: dürtünün doğal birikim hızları (birim/sn). Oyun günü
/// [daySeconds] üstünden ölçeklenir ki gün uzunluğu değişirse denge kaymasın.
class DriveRates {
  final double daySeconds;
  const DriveRates(this.daySeconds);

  /// Bir oyun gününde sıfırdan doyma noktasına gelecek hız.
  double perDay(double amount) => amount / daySeconds;

  double get hunger => perDay(1.6);
  double get fatigue => perDay(1.25);
  double get company => perDay(1.1);
  double get purpose => perDay(2.0);

  /// Üşüme ve tedirginlik koşula bağlı; taban hız yalnız sönme içindir.
  double get decay => perDay(2.4);
}

/// Rastgeleliğin tek kapısı — teklif puanlarına ufak gürültü. Sistem
/// deterministik kalsın diye [Random] dışarıdan verilir.
double nudge(Random rng, double amount) => 1.0 + (rng.nextDouble() - 0.5) * amount;
