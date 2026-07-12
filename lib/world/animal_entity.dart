import 'dart:math';

import '../characters/life_stage.dart' show kGameDaySeconds;

enum AnimalKind { cow, sheep, chicken }

/// Hayvan satın alma maliyeti (altın) — ahır/kümes BOŞ kurulur, oyuncu buradan
/// hayvan edinir (bina ile gelmez). Tür değeri kabaca: tavuk ucuz, inek pahalı.
const Map<AnimalKind, int> kAnimalGoldCost = {
  AnimalKind.cow: 10,
  AnimalKind.sheep: 6,
  AnimalKind.chicken: 3,
};

/// Bina başına tür kapasitesi — satın alma + üreme bu tavanı aşamaz.
const Map<AnimalKind, int> kAnimalBarnCap = {
  AnimalKind.cow: 5,
  AnimalKind.sheep: 5,
  AnimalKind.chicken: 6,
};

/// Türün Türkçe adı (UI butonları).
String animalKindLabel(AnimalKind k) => switch (k) {
      AnimalKind.cow => 'İnek',
      AnimalKind.sheep => 'Koyun',
      AnimalKind.chicken => 'Tavuk',
    };

/// 4 yönlü facing — sprite-based hayvanlarda hangi sprite seti kullanılacak.
/// Hareket yönüne göre güncellenir.
enum AnimalFacing { n, e, s, w }

/// Hayvan yaşam evresi. Köylü [LifeStage]'inin sadeleştirilmiş hâli — 3 evre.
/// Yavru otlar ama ürün vermez/üremez; yetişkin üretir+ürer; yaşlı yavaşlar.
enum AnimalLifeStage { juvenile, adult, elder }

extension AnimalLifeStageX on AnimalLifeStage {
  /// Sprite çizim ölçeği — yavru küçük, yetişkin tam, yaşlı hafif küçülmüş.
  double get renderScale => switch (this) {
        AnimalLifeStage.juvenile => 0.55,
        AnimalLifeStage.adult => 1.0,
        AnimalLifeStage.elder => 0.92,
      };

  /// Türe göre Türkçe etiket (yavru: buzağı/kuzu/civciv).
  String labelFor(AnimalKind k) => switch (this) {
        AnimalLifeStage.juvenile => switch (k) {
            AnimalKind.cow => 'Buzağı',
            AnimalKind.sheep => 'Kuzu',
            AnimalKind.chicken => 'Civciv',
          },
        AnimalLifeStage.adult => 'Yetişkin',
        AnimalLifeStage.elder => 'Yaşlı',
      };
}

/// Ağıla bağlı serbest dolaşan hayvan. Hunger ↗ zaman; otladıkça (= hareket
/// ettikçe) düşer. Doyduğunda milkProgress birikir. milkProgress≥1 olunca
/// çoban gelir, isBeingMilked aktif, bitince ürün spawn edilir.
///
/// İzometri/render için WorkerEntity ile aynı alanları taklit eder
/// (gridX/Y, renderX/Y, depth, walkPhase, facingRight) — char_renderer
/// uyumu için.
class AnimalEntity {
  final AnimalKind kind;
  final int barnCol;
  final int barnRow;

  /// Cinsiyet — çift bazlı üreme için (aynı ağılda dişi+erkek yetişkin gerek).
  final bool isMale;

  /// Yaş (oyun günü). Zamanla yaşam evresi ilerler; [lifespanDays]'i geçince
  /// hayvan sakince hayata veda eder (chill: kaynak cezası yok).
  double ageDays;

  /// Doğal ölüm yaşı (oyun günü). Yaşlı evresine girince + rastgele bir süre.
  double lifespanDays;

  /// Üreme sayacı (oyun günü). NaN = uygun değil (yavru/yaşlı/erkek);
  /// > 0 = sayıyor; ≤ 0 = hazır (sahne partner+kapasite kontrol eder).
  double fertilityDays = double.nan;

  // ── Ölüm animasyonu ─────────────────────────────────────────────────────
  /// true → hayvan çöküp solmaya başladı (anlık silme yok; köylüyle simetrik).
  bool isDying = false;
  /// 0→1 çöküş/solma ilerlemesi; 1 olunca [deathFinished].
  double deathProgress = 0.0;
  bool get deathFinished => isDying && deathProgress >= 1.0;
  static const double _deathDuration = 2.4; // sn

  double gridX;
  double gridY;
  double renderX;
  double renderY;
  bool   facingRight = true;
  /// 4 yönlü facing — sprite-based hayvanlarda kullanılır (sheep). Cow ignore eder.
  AnimalFacing facing4 = AnimalFacing.s;
  double walkPhase   = 0.0;
  bool   isWalking   = false;

  /// 0 = tamamen tok, 1 = aç. Yürürken otladığı varsayılır.
  double hunger = 0.0;
  /// 0..1 — doyduğunda dolar; sağılınca sıfırlanır.
  double milkProgress = 0.0;
  /// Çoban tarafından şu anda sağılıyor.
  bool isBeingMilked = false;

  // ── Wander state ──────────────────────────────────────────────────────────
  double _wanderTargetX = -1;
  double _wanderTargetY = -1;
  double _wanderTimer   = 0;
  /// > 0 iken hayvan hedefe ulaştı, ot yiyor — yerinde dururur, yeni hedef seçmez.
  /// Gerçek otlatma davranışı: kısa yürüyüş + uzun otlama döngüsü.
  double _grazeTimer    = 0;

  AnimalEntity({
    required this.kind,
    required this.barnCol,
    required this.barnRow,
    required double startCol,
    required double startRow,
    this.isMale = false,
    this.ageDays = kAnimalAdultDay,   // default: yetişkin doğar (ilk spawn)
    double? lifespanDays,
  }) : gridX   = startCol,
       gridY   = startRow,
       renderX = startCol,
       renderY = startRow,
       lifespanDays = lifespanDays ?? kAnimalElderDay + 9.0;

  /// Wander radius scale — `freeRange` politikası açıkken scene 1.5 yapar.
  /// Default 1.0. AnimalEntity policy'ye erişmesin diye side channel.
  static double kWanderScale = 1.0;
  static double get _wanderRadius => 2.5 * kWanderScale;
  /// Açlık hız çarpanı — `winterFodder` politikası açıkken scene 0.55 yapar
  /// (yem stoku → hayvanlar daha geç acıkır, daha verimli). Default 1.0.
  static double kHungerScale = 1.0;
  static const double _walkSpeed    = 0.65;         // tile/sn, sakin ama uyuşuk değil
  static const double _hungerRate   = 1.0 / 70.0;   // 70 sn'de aç
  static const double _grazeRate    = 1.0 / 30.0;   // 30 sn yürüyüşle doyar
  static const double _milkRate     = 1.0 / 45.0;   // dolu kalınca 45 sn'de hazır

  // ── Yaşam evresi eşikleri (oyun günü) ────────────────────────────────────
  // Hayvanlar köylüden biraz daha kısa ömürlü → sürü yenilenmesi gözle görülür.
  static const double kAnimalAdultDay = 1.5;    // yavru → yetişkin
  // Yaşlı eşiği geniş tutuldu: doğurganlık penceresi (yetişkin→yaşlı) sayaçtan
  // belirgin uzun olsun ki hayvanlar yaşlanmadan rahatça yavrulasın.
  static const double kAnimalElderDay = 16.0;   // yetişkin → yaşlı

  AnimalLifeStage get lifeStage => ageDays < kAnimalAdultDay
      ? AnimalLifeStage.juvenile
      : ageDays < kAnimalElderDay
          ? AnimalLifeStage.adult
          : AnimalLifeStage.elder;

  bool get isJuvenile => lifeStage == AnimalLifeStage.juvenile;
  /// Üretim + üreme yalnızca yetişkinde (yaşlı da üretir ama daha az ürer).
  bool get isAdult => ageDays >= kAnimalAdultDay;
  double get renderScale => lifeStage.renderScale;

  bool get readyToMilk =>
      isAdult && !isDying && milkProgress >= 1.0 && !isBeingMilked;
  double get depth => gridX + gridY;

  /// Çöküş başlat — anlık silme yerine görünür veda (köylüyle simetrik).
  void startDying() {
    if (isDying) return;
    isDying = true;
    deathProgress = 0.0;
    isBeingMilked = false;
    isWalking = false;
    fertilityDays = double.nan;
  }

  void update(double dt, Random rng,
      {Set<(int, int)> waterTiles = const {}}) {
    // Çöküş animasyonu — solar + yerinde kalır, başka hiçbir şey işlemez.
    if (isDying) {
      deathProgress = (deathProgress + dt / _deathDuration).clamp(0.0, 1.0);
      isWalking = false;
      _smoothRender(dt);
      return;
    }

    // Yaşlanma — evre & üreme uygunluğu ageDays'ten türetilir.
    ageDays += dt / kGameDaySeconds;
    // Üreme sayacı: yetişkin dişiler için aktif (yaşlıda dondurulur).
    if (!isMale && lifeStage == AnimalLifeStage.adult) {
      if (fertilityDays.isNaN) {
        // İlk gebelik sayacı — yetişkin penceresinden (1.5→16 gün) kısa olsun.
        fertilityDays = 3.0 + rng.nextDouble() * 3.0;
      } else if (fertilityDays > 0) {
        fertilityDays -= dt / kGameDaySeconds;
      }
    } else {
      fertilityDays = double.nan;
    }

    if (isBeingMilked) {
      isWalking = false;
      walkPhase += dt * 1.2;
      _smoothRender(dt);
      return;
    }

    // Hunger / milk metabolizması — otlarken (duruşta) yer; yürürken aramaz.
    hunger += dt * _hungerRate * kHungerScale;
    if (hunger > 1.0) hunger = 1.0;
    if (_grazeTimer > 0 && hunger > 0.0) {
      hunger -= dt * _grazeRate;
      if (hunger < 0.0) hunger = 0.0;
    }
    // Ürün sadece yetişkinden; yavru otlar ama süt vermez (büyümek anlam kazanır).
    if (isAdult && hunger < 0.3 && milkProgress < 1.0) {
      milkProgress += dt * _milkRate;
      if (milkProgress > 1.0) milkProgress = 1.0;
    }

    // Otlama freeze — hedefe varınca burada kilitleniriz, yerinde dururuz.
    if (_grazeTimer > 0) {
      _grazeTimer -= dt;
      isWalking = false;
      walkPhase = 0; // idle frame'de sabit, walkPhase ilerlemesin
      _smoothRender(dt);
      return;
    }

    // Yürüyüş — wanderTimer "hedefe ulaşamadan" safety; varış otomatik freeze.
    _wanderTimer -= dt;
    if (_wanderTimer <= 0) {
      _pickWanderTarget(rng, waterTiles);
      _wanderTimer = 8.0 + rng.nextDouble() * 6.0;
    }

    final dx   = _wanderTargetX - gridX;
    final dy   = _wanderTargetY - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.1) {
      // Vardık → otlama. Yeni hedef freeze bittikten sonra seçilir.
      _grazeTimer = 4.0 + rng.nextDouble() * 5.0;
      isWalking = false;
      walkPhase = 0;
      _smoothRender(dt);
      return;
    }
    if (dist > 0.05) {
      final step = (_walkSpeed * dt).clamp(0.0, dist);
      final sx = dx / dist * step;
      final sy = dy / dist * step;

      // Tile çarpışması — axis separation. Hayvan ASLA engel tile'ına girmesin
      // (bina footprint / su / maden). Önce diyagonal, blok ise sırayla X-only,
      // Y-only dene. İkisi de bloksa dur + sonraki tick'te yeni hedef seç.
      // Mevcut tile zaten engelse (spawn anormalliği / legacy state) tıkanmamak
      // için tüm hareketlere izin ver — escape modu.
      final stuck = _blocked(waterTiles, gridX, gridY);
      bool moved = false;
      if (stuck || !_blocked(waterTiles, gridX + sx, gridY + sy)) {
        gridX += sx;
        gridY += sy;
        moved = true;
      } else if (!_blocked(waterTiles, gridX + sx, gridY)) {
        gridX += sx;
        moved = true;
      } else if (!_blocked(waterTiles, gridX, gridY + sy)) {
        gridY += sy;
        moved = true;
      }

      if (moved) {
        facingRight = dx >= 0;
        // 4-yön: |dx| vs |dy| baskınlığına göre yön seç. Hafif hysteresis
        // istemiyoruz şimdilik — basit clean dominant axis.
        if (dx.abs() > dy.abs()) {
          facing4 = dx >= 0 ? AnimalFacing.e : AnimalFacing.w;
        } else {
          facing4 = dy >= 0 ? AnimalFacing.s : AnimalFacing.n;
        }
        isWalking = true;
        walkPhase += dt * 6.0;
      } else {
        // Tamamen tıkalı — bir sonraki tick'te yeni hedef seçilsin.
        _wanderTimer = 0;
        isWalking = false;
        walkPhase += dt * 1.0;
      }
    } else {
      isWalking = false;
      walkPhase += dt * 1.0;
    }
    walkPhase %= 2 * pi;

    _smoothRender(dt);
  }

  /// (x, y) sürekli koordinatının düştüğü tile engel mi?
  static bool _blocked(Set<(int, int)> tiles, double x, double y) {
    return tiles.contains((x.floor(), y.floor()));
  }

  /// İki nokta arasındaki segment üzerinde 6 ara örnek; biri engel tile'a
  /// düşerse path tıkalı sayılır. Bina köşesinden geçişi keser.
  static bool _segmentClear(
      Set<(int, int)> tiles, double x0, double y0, double x1, double y1) {
    const samples = 6;
    for (int i = 1; i <= samples; i++) {
      final t = i / (samples + 1);
      if (_blocked(tiles, x0 + (x1 - x0) * t, y0 + (y1 - y0) * t)) {
        return false;
      }
    }
    return true;
  }

  void _pickWanderTarget(Random rng, Set<(int, int)> waterTiles) {
    final cx = barnCol + 1.5;
    final cy = barnRow + 1.0;
    for (int i = 0; i < 12; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * _wanderRadius;
      final tx = cx + cos(a) * r;
      final ty = cy + sin(a) * r;
      if (_blocked(waterTiles, tx, ty)) continue;
      if (!_segmentClear(waterTiles, gridX, gridY, tx, ty)) continue;
      _wanderTargetX = tx;
      _wanderTargetY = ty;
      return;
    }
    // Hiçbir aday bulunamadı → yerinde kal (binaya doğru fallback YAPMA;
    // ağıl/kümes merkezi bina tile'ı olabilir).
    _wanderTargetX = gridX;
    _wanderTargetY = gridY;
  }

  void _smoothRender(double dt) {
    final k = 1 - exp(-dt * 12.0);
    renderX += (gridX - renderX) * k;
    renderY += (gridY - renderY) * k;
  }

  /// Çoban sağmayı tamamladı: bir "yiyecek" birimi üretir, milk sıfırlanır,
  /// hunger geri yükselmeye başlar (bir kova süt = belli enerji).
  void onMilked() {
    isBeingMilked = false;
    milkProgress = 0.0;
    hunger = (hunger + 0.15).clamp(0.0, 1.0);
  }
}
