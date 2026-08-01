/// ELDEKİ NESNE — köylünün taşıdığı görünür eşya.
///
/// Faz 3'ün sebebi: köylü bir yere varıp orada **hiçbir şey yapmıyordu**.
/// `idleTimer = dwell` verilip 8 saniye bekletiliyordu; oyuncunun gördüğü şey
/// "bir yere yürüyüp orada duran adam"dı. Elde görünür bir nesne olmadan hiçbir
/// varış noktası gerçek olamaz — pazardan dönen adamı pazardan dönmüş yapan şey
/// elindeki sepettir.
///
/// Sözleşme: buraya eklenen her nesnenin ÇİZİMİ olmalı (bkz. prop_renderer).
/// Çizilmeyen bir nesne, hafızada duran ama ekranda olmayan bir yalandır.
enum PropKind {
  none,

  /// Boş kova — kuyuya giderken.
  bucketEmpty,

  /// Dolu kova — kuyudan dönerken (ağır: yürüyüş yavaşlar).
  bucketFull,

  /// Çuval — hırsızın yükü, ambara taşınan zahire.
  sack,

  /// Somun ekmek — sofradan/pazardan.
  bread,

  /// Bardak/maşrapa — meyhanede.
  mug,

  /// Sepet — pazardan dönüş.
  basket,

  /// Odun demeti — ateşe yakıt.
  firewood,
}

/// Nesnenin oyuncu-yüzü adı (panel/ipucu).
String propLabel(PropKind p) => switch (p) {
      PropKind.none => '',
      PropKind.bucketEmpty => 'boş kova',
      PropKind.bucketFull => 'su kovası',
      PropKind.sack => 'çuval',
      PropKind.bread => 'ekmek',
      PropKind.mug => 'maşrapa',
      PropKind.basket => 'sepet',
      PropKind.firewood => 'odun',
    };

/// Nesnenin yürüyüş hızına etkisi. Dolu kova ve çuval AĞIRDIR — yüklü köylünün
/// yavaşlaması hem inandırıcıdır hem de oynanışta işe yarar (yüklü hırsız
/// yakalanabilir).
double propSpeedFactor(PropKind p) => switch (p) {
      PropKind.bucketFull => 0.78,
      PropKind.sack => 0.72,
      PropKind.firewood => 0.85,
      PropKind.basket => 0.92,
      _ => 1.0,
    };

/// Nesne iki elle mi taşınıyor — çizim ve duruş buna göre değişir.
bool propTwoHanded(PropKind p) =>
    p == PropKind.sack || p == PropKind.firewood || p == PropKind.basket;

/// EYLEM ADIMININ TÜRÜ.
enum ActVerb {
  /// Bir noktaya yürü.
  goTo,

  /// Bir noktaya dön (yalnız yön).
  face,

  /// Belirli bir süre bir iş yap — duruşla birlikte.
  work,

  /// Eline nesne al.
  take,

  /// Elindeki nesneyi bırak.
  put,
}

/// İŞ DURUŞU — [ActVerb.work] sırasındaki gövde dili.
///
/// Render katmanındaki `CharPose`'dan bilerek AYRI: burası sistem katmanı,
/// çizime bağımlı olamaz. Painter eşlemeyi kendi yapar.
enum ActPose {
  /// Ayakta, hafif meşgul (tezgâh başı, sohbet bekleme).
  stand,

  /// Eğilmiş — kova doldurma, yerden alma.
  stoop,

  /// Tekrarlı el işi — kürek, karıştırma, çekiçleme.
  labor,

  /// İçme/yeme.
  sip,

  /// Dizüstü — yaralının/hastanın başında, yakarışta, dua ederken.
  /// Ayakta duruşları override eder (CharPose.kneel).
  kneel,

  /// Yere çökmüş — hastalıktan düşen, yasa kapanan gövde (CharPose.mourn).
  /// Vinyet sahnelerinin en ağır jesti; gündelik işte kullanılmaz.
  slump,
}

/// Duruş gövdenin TAMAMINI ele alıyor mu (uzuv açıları CharacterRenderer'a
/// devredilir, ayakta mikro-tweak'ler devre dışı kalır)?
bool actPoseIsFullBody(ActPose p) =>
    p == ActPose.kneel || p == ActPose.slump;

/// EYLEMİN TEK ADIMI.
class ActStep {
  final ActVerb verb;

  /// [goTo] / [face] hedefi.
  final double x, y;

  /// [work] süresi (sn).
  final double seconds;

  /// [take] / [put] nesnesi.
  final PropKind prop;

  /// [work] duruşu.
  final ActPose pose;

  const ActStep._(
    this.verb, {
    this.x = 0,
    this.y = 0,
    this.seconds = 0,
    this.prop = PropKind.none,
    this.pose = ActPose.stand,
  });

  const ActStep.goTo(double x, double y) : this._(ActVerb.goTo, x: x, y: y);
  const ActStep.face(double x, double y) : this._(ActVerb.face, x: x, y: y);
  const ActStep.work(double seconds, {ActPose pose = ActPose.labor})
      : this._(ActVerb.work, seconds: seconds, pose: pose);
  const ActStep.take(PropKind prop) : this._(ActVerb.take, prop: prop);
  const ActStep.put() : this._(ActVerb.put);
}

/// BİR EYLEM — köylünün yürüttüğü adım dizisi.
///
/// Eskiden bir varış noktası tek bir sayıydı (`dwell`). Şimdi bir dizi: git,
/// eğil, doldur, taşı, bırak. Aradaki fark oyuncunun gözünde "orada duruyor"
/// ile "iş yapıyor" arasındaki farktır.
class Act {
  /// Oyuncu-yüzü etiket — köylü panelinde niyetin altında görünür.
  final String label;

  final List<ActStep> steps;

  int _cursor = 0;

  /// Yürüyen adımın kalan süresi (work için).
  double timer = 0;

  Act(this.label, this.steps);

  bool get done => _cursor >= steps.length;

  ActStep? get current => done ? null : steps[_cursor];

  int get cursor => _cursor;

  /// Sıradaki adıma geç.
  void advance() {
    _cursor++;
    timer = 0;
  }

  /// Eylemi baştan başlat (yeniden kullanılabilirlik / test).
  void reset() {
    _cursor = 0;
    timer = 0;
  }

  /// Bu eylem boyunca eline geçecek en ağır nesne — hız kestirimi ve
  /// "ne yapıyor" özeti için.
  PropKind get heaviestProp {
    var best = PropKind.none;
    var bestF = 1.0;
    for (final s in steps) {
      if (s.verb != ActVerb.take) continue;
      final f = propSpeedFactor(s.prop);
      if (f < bestF) {
        bestF = f;
        best = s.prop;
      }
    }
    return best;
  }
}
