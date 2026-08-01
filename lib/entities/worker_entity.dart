import 'dart:math';
import '../characters/npc_visual.dart';
import '../core/constants.dart';
import '../systems/locomotion.dart';
import '../systems/path_context.dart';
import '../systems/pathfinder.dart';
import '../systems/road_system.dart';

/// Tüm çalışan NPC'lerin paylaştığı hareket ve dolaşma mantığı.
///
/// Alt sınıflar (Woodcutter, Miner, Fisher, LumberCamp ...) yalnızca kendi
/// state machine'lerini ve görev hedefi seçimini yazar.  Yürüme, dolaşma,
/// su-pushback ve hedefe gitme akışı burada şablonlanır.
///
/// Override noktaları:
///   - [speed]            : zorunlu — tile/sn cinsinden ana hız
///   - [wanderOriginX/Y]  : dolaşma merkezi (varsayılan: spawn noktası)
///   - [wanderRadius]     : dolaşma yarıçapı (tile)
///   - [idleSpeedFactor]  : idle hareket hızı (normal hızın çarpanı)
///   - [idleIntervalRange]: idle hedef yenileme aralığı (saniye)
abstract class WorkerEntity {
  /// Tek otorite — main.dart init'inde set edilir. moveTo/moveTowards üstünde
  /// yürünen tile road ise hızı çarpar (taş +%30, toprak/köprü +%15).
  /// null ise (henüz set edilmemiş test ortamı) etkisiz.
  static RoadSystem? roadSystem;

  /// A* path-aware hareket için ortak otorite. main.dart bir kez set eder.
  /// null ise pathing devre dışı — moveTo/moveTowards eski (düz çizgi)
  /// davranışına döner. World version değişimi cached path'leri invalidate
  /// eder; pathing kısa hop'larda (< 3 tile) atlanır (idle wander vb.).
  static PathContext? pathContext;

  // ── Per-entity path cache ──────────────────────────────────────────────────
  // _path: tile waypoint sırası (start dahil değil, goal dahil).
  // _pathIdx: işlenen sonraki waypoint indeksi.
  // _pathGoalC/R: en son hedef tile — değişirse path recompute.
  // _pathVersion: hesaplandığında pathContext.version değeri — eskirse recompute.
  List<(int, int)>? _path;
  int _pathIdx     = 0;
  int _pathGoalC   = -999;
  int _pathGoalR   = -999;
  int _pathVersion = -1;
  /// Aynı hedef için yeniden plan yapmadan önce beklenecek süre (sn).
  double _replanCd = 0;
  static const double _kReplanInterval = 0.30;

  double gridX;
  double gridY;
  double walkPhase   = 0.0;
  bool   isWalking   = false;

  /// HAREKET FİZİĞİ — hız vektörü, ivme, dönüş sınırı, bakış histerezisi.
  /// Tüm konum değişimi buradan geçer (bkz. [_stepDt] / [_stepFixed]).
  final Locomotion loco = Locomotion();

  /// Gövde yönü. Artık ham `dx` işareti değil, yumuşatılmış hızdan histerezisle
  /// türeyen karar. Dışarıdan set edilebilir (ateşe dönme, oturma) — o zaman da
  /// görsel dönüş [Locomotion.faceTick] ile yumuşak akar, tek karede aynalanmaz.
  bool get facingRight => loco.facingRight;
  set facingRight(bool v) => loco.faceTo(v);

  /// Renderer'ın dönüş anında uygulayacağı yatay ölçek (0.10..1.0).
  double get turnScaleX => loco.turnScaleX;

  /// AI gridX/Y'yi takip eden yumuşatılmış render pozisyonu.
  /// AI hassas tile-snap yaparken render lerp ile akıcı kalır.
  double renderX;
  double renderY;

  /// 0..1 — isWalking'e doğru exp-lerp olan sürekli hareket yoğunluğu.
  /// Walking ↔ idle animasyonu arasında smooth blend için kullanılır.
  double moveIntensity = 0.0;

  /// İlk doğum koordinatı — varsayılan dolaşma merkezi.
  final double spawnCol;
  final double spawnRow;

  /// Per-NPC kalıcı görsel kimlik — ten/saç/göz/kıyafet tonu. Renderer bunu
  /// okuyup aynı meslekten NPC'lerin tıpatıp aynı görünmesini engeller.
  /// Constructor'da `visual` verilmediyse spawn pos hash'inden otomatik üretilir.
  final NpcVisual visual;

  // ── Meşale (gece dış mekan) — tek karar noktası, smooth fade ─────────────
  /// 0..1 yumuşatılmış meşale parlaklığı. `tickTorch` ile her tick güncellenir.
  /// Lighting + sprite + glow hepsi bu değeri okur (tek doğruluk).
  double torchLevel = 0.0;
  /// Per-NPC sabit flicker fazı — spawn pos hash'inden lazy. Tüm meşalelerin
  /// aynı anda titrememesi için.
  double? _torchPhase;
  double get torchPhase => _torchPhase ??= (spawnCol * 0.41 + spawnRow * 0.73);

  // ── Idle wander state (idleWander tarafından yönetilir) ────────────────────
  double _idleTargetX = -1;
  double _idleTargetY = -1;
  double _idleTimer   = 0;

  // ── İş arama throttle ──────────────────────────────────────────────────────
  double _workSearchCd = 0.0;

  // ── Stuck-detect + yield ───────────────────────────────────────────────────
  // Düz çizgi hareket + separation iki NPC'yi tam karşıdan kilitleyebilir;
  // tangential bias çoğu durumu çözer ama dar koridor + 3+ entity yığını
  // hâlâ tıkayabilir. Bu sistem fallback: isWalking olmasına rağmen yer
  // değişimi yoksa NPC kısa süreliğine durur → komşulardan biri pas geçer.
  double _stuckPollTimer = 0.0;
  double _stuckRefX = 0.0;
  double _stuckRefY = 0.0;
  /// > 0 iken hareket no-op (deadlock kırma için yer veriyor).
  double _yieldTimer = 0.0;

  // ── Micro-idle: nefes, sway, contextual glance ───────────────────────────
  // NPC dururken sin-bazlı zar zor belirgin gövde sallanması + bağlamsal
  // "etrafa bakma" anları (yoldan çıkarken, yieldden çıkarken, yeni hedef
  // seçince, yolculuk bitince). Random timer YOK — her bakış bir olaya bağlı.
  double _glanceTimer = 0.0;
  /// Bakınmadan önceki yön — süre dolunca buraya dönülür.
  bool   _glanceBack  = true;
  bool   _prevOnRoad  = false;
  bool   _prevIsWalking = false;

  /// Boştaki işçinin her frame tüm hedef listesini taramasını engeller.
  /// ~[kWorkSearchInterval]'de bir true döner; aradaki frame'lerde işçi
  /// yalnızca dolaşır. İş anında lazım değilse bu gecikme görünmez.
  bool readyToSearchWork(double dt) {
    _workSearchCd -= dt;
    if (_workSearchCd > 0) return false;
    _workSearchCd = kWorkSearchInterval;
    return true;
  }

  WorkerEntity({
    required double startCol,
    required double startRow,
    NpcVisual? visual,
  })  : gridX    = startCol,
        gridY    = startRow,
        renderX  = startCol,
        renderY  = startRow,
        spawnCol = startCol,
        spawnRow = startRow,
        visual   = visual ?? NpcVisual.fromSeed(_workerAutoSeed(startCol, startRow));

  static int _workerAutoSeed(double c, double r) =>
      ((c * 1009).toInt() * 13) ^
      ((r * 1031).toInt() * 31) ^
      (DateTime.now().microsecondsSinceEpoch & 0xFFFF);

  /// Her tick ana loop çağırır.  Render pozisyonu ve hareket yoğunluğunu
  /// günceller.
  /// - Render exp-smoothing: ~0.15 sn'de gridX/Y'ye yetişir
  /// - moveIntensity: 0.20 sn'de isWalking'e yetişir
  void smoothMotion(double dt) {
    _tickStuck(dt);
    _tickIdleAnim(dt);
    if (_replanCd > 0) _replanCd -= dt;

    // Bu karede hiç adım atılmadıysa (idle/oturma/uyku) hız sıfıra frenlenir —
    // konum ötelenmez, ama bir sonraki kalkış duran bir gövdeden başlar.
    if (!isWalking) loco.brake(dt);
    // Bakış yönü her karede ilerler: yürüyende hızdan, durakta dışarıdan
    // verilen karardan. Dönüş animasyonu (turnScaleX) burada akar.
    loco.faceTick(dt);

    final kPos  = 1 - exp(-dt * 14.0);
    renderX += (gridX - renderX) * kPos;
    renderY += (gridY - renderY) * kPos;

    final targetIntensity = isWalking ? 1.0 : 0.0;
    final kInt = 1 - exp(-dt * 8.0);
    moveIntensity += (targetIntensity - moveIntensity) * kInt;
  }

  /// 0.7s aralıkla yer değişimini ölç; isWalking olmasına rağmen <0.10 tile
  /// ilerlemediyse NPC kilitlenmiş → hash-bazlı desync ile 0.5-1.2s yield.
  /// Yield sırasında _stepDt/_stepFixed no-op; komşulardan biri pas geçer.
  void _tickStuck(double dt) {
    if (_yieldTimer > 0) {
      _yieldTimer -= dt;
      return;
    }
    _stuckPollTimer -= dt;
    if (_stuckPollTimer > 0) return;
    _stuckPollTimer = 0.7;

    if (!isWalking) {
      _stuckRefX = gridX;
      _stuckRefY = gridY;
      return;
    }

    final dxR = gridX - _stuckRefX;
    final dyR = gridY - _stuckRefY;
    if (dxR * dxR + dyR * dyR < 0.01) {
      // Hash-desync — komşu NPC'lerin aynı anda yield edip aynı anda
      // çıkmaması için her entity'nin yield süresi farklı.
      final seed = (identityHashCode(this) & 0xFF) / 255.0;
      _yieldTimer = 0.5 + seed * 0.7;
    }
    _stuckRefX = gridX;
    _stuckRefY = gridY;
  }

  /// Glance state'i decrement eder + walking→idle geçişinde bir kez bakış.
  /// Süre dolunca NPC eski yönüne döner (yine yumuşak dönüşle).
  void _tickIdleAnim(double dt) {
    if (_glanceTimer > 0) {
      _glanceTimer -= dt;
      if (_glanceTimer <= 0) loco.faceTo(_glanceBack);
    }
    // Yolculuk yeni bitti (walking → idle) → varış kontrolü bakışı.
    if (_prevIsWalking && !isWalking) {
      glanceAround(duration: 0.9);
    }
    _prevIsWalking = isWalking;
  }

  /// Bağlamsal "etrafa bak" — NPC bir süreliğine öbür yana dönüp geri döner.
  ///
  /// TUZAK (düzeltildi): bu eskiden `effectiveFacingRight` üzerinden sprite'ı
  /// ANINDA aynalıyordu ve varışta / yield'de / yoldan çıkışta / iş döngüsünün
  /// yedi ayrı yerinde tetikleniyordu. Oyuncunun "sürekli ileri geri
  /// yapıyorlar" dediği şeyin en gürültülü kaynağı buydu. Artık:
  ///   • yalnız DURAKTA çalışır — yürüyen NPC adımının ortasında geri dönmez,
  ///   • dönüş [Locomotion] üzerinden animasyonlu akar (aynalama yok),
  ///   • süre dolunca eski yönüne döner.
  void glanceAround({double duration = 1.0}) {
    if (isWalking || loco.speedNow > 0.18) return;
    if (_glanceTimer > 0) return; // zaten bakınıyor — üstüne binme
    final seed = (identityHashCode(this) & 0xFF) / 255.0;
    _glanceBack = facingRight;
    _glanceTimer = duration * (0.85 + seed * 0.3);
    loco.faceTo(!facingRight);
  }

  /// Her NPC'ye özgü deterministik faz offset'i (hashCode'dan). Nefes/sway
  /// rastgele görünür ama frame-to-frame stable.
  double get _idlePhaseSeed =>
      (identityHashCode(this) & 0xFFFF) / 65535.0 * 6.28318;

  /// Idle gövde scale Y modülasyonu — nefes (% 1.2 maks). Yürürken etkisiz.
  double idleBreathScale(double time) {
    final idleAmt = 1.0 - moveIntensity;
    if (idleAmt < 0.05) return 1.0;
    return 1.0 + sin(time * 0.7 + _idlePhaseSeed) * 0.012 * idleAmt;
  }

  /// Idle gövde rotation — hafif yan-yana sallanma (~%1.3 rad ≈ 0.75°).
  double idleSwayRotation(double time) {
    final idleAmt = 1.0 - moveIntensity;
    if (idleAmt < 0.05) return 0.0;
    return sin(time * 0.45 + _idlePhaseSeed * 1.7) * 0.022 * idleAmt;
  }

  /// Render tarafı facing. Artık glance burada TERS ÇEVİRMEZ — bakınma da dahil
  /// her yön değişimi [Locomotion] içinde yumuşatılır, bu getter yalnız o
  /// kararın anlık işaretini verir. (Geriye dönük API: 20+ çizim noktası bunu
  /// kullanıyor.)
  bool get effectiveFacingRight => loco.facingRight;

  /// Meşale eligibility — subclass override edebilir. Worker'lar (oduncu,
  /// madenci, çoban, vd) her zaman dışarıda → gece torch hep yanmalı.
  /// isWalking koşulu çoğu state'i (chopping/mining/idle/sleeping ileride)
  /// dışarıda bırakıyordu → meşale neredeyse hiç görünmüyordu (user bug).
  /// VillagerEntity uyku/iç mekan/ateşte oturma için override eder.
  bool get torchEligibleDefault => true;

  /// Meşale fade tick — scene tarafı her tick çağırır (dayLight + rain ile).
  /// Smooth lerp: fadeIn 0.6/s, fadeOut 0.35/s. dlFade penceresi 0.40→0.20
  /// (alacakaranlık başında yanar, gecede tam). Yağmur 0..0.35 söndürür.
  void tickTorch(double dt, double dayLight, double rainIntensity,
      {bool? eligibleOverride}) {
    final eligible = eligibleOverride ?? torchEligibleDefault;
    final dlFade = (1.0 - (dayLight - 0.20) / 0.20).clamp(0.0, 1.0);
    final rainFade = (1.0 - rainIntensity / 0.35).clamp(0.0, 1.0);
    final target = (eligible ? dlFade * rainFade : 0.0).clamp(0.0, 1.0);
    final rate = (target > torchLevel) ? 0.6 : 0.35;
    final delta = target - torchLevel;
    final step = rate * dt;
    torchLevel = (delta.abs() < step)
        ? target
        : torchLevel + (delta > 0 ? step : -step);
  }

  double get depth => gridX + gridY;

  /// Tile/sn cinsinden ana hareket hızı. Alt sınıf override eder.
  double get speed;

  /// Dolaşma bölgesi merkezi — varsayılan spawn noktası.
  /// LumberCamp gibi sabit bölgeli işçiler bina merkezini döner.
  double get wanderOriginX => spawnCol;
  double get wanderOriginY => spawnRow;

  /// Dolaşma yarıçapı (tile).
  double get wanderRadius => 3.0;

  /// Idle modunda hız çarpanı — normal hızın yüzdesi.
  /// 0.4 = sakin yürüme; balıkçı/çiftçi 0.5 kullanır.
  double get idleSpeedFactor => 0.4;

  /// Idle hedef yenileme aralığı (min, max) saniye.
  (double, double) get idleIntervalRange => (3.0, 7.0);

  /// Hedefe `step` kadar ilerle (saniyeden bağımsız mutlak adım).
  /// Path-aware: uzak hedef (≥ 3 tile) için A* waypoint dizisi izlenir;
  /// kısa hedefler ve pathContext yokken doğrudan vektör adımı.
  void moveTo(double tx, double ty, double step) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final next = _nextWaypoint(tx, ty, dist);
    _stepFixed(next.$1, next.$2, step, dist);
  }

  /// Hedefe `speed * dt` adımla ilerle. arriveD altına düşünce true döner —
  /// alt sınıf state geçişi için kullanır. Path-aware (bkz. moveTo).
  ///
  /// [speedScale] tempo çarpanı (taşıma hızı, kişilik temposu, sürünme…).
  /// TUZAK: bunu eskiden çağıranlar `dt * çarpan` diye geçiyordu. Lokomosyon
  /// gelince bu yanlış oldu — dt'yi ölçeklemek ivme/dönüş zaman sabitlerini de
  /// ölçekler, NPC yavaşlarken aynı zamanda ağırlaşırdı. Tempo artık ayrı.
  bool moveTowards(double tx, double ty, double dt,
      {double arriveD = 0.08, double speedScale = 1.0}) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist <= arriveD) return true;
    final next = _nextWaypoint(tx, ty, dist);
    _stepDt(next.$1, next.$2, dt, speedScale, dist);
    return false;
  }

  /// (tx, ty) gerçek hedef; dönüş: bir SONRAKİ adımın hedefi (waypoint ya
  /// da true goal). Kısa mesafe / no-context → doğrudan true goal.
  /// A*'ın atlandığı mesafe eşiği (tile). Eskiden 3.0 idi; köyün içindeki
  /// gidiş gelişlerin çoğu bu eşiğin ALTINDA kaldığı için NPC'ler yolları hiç
  /// kullanmıyor, binaların arasından çapraz kesiyordu. 1.8'e indirmek kısa
  /// mesafeleri de yol ağına oturtur (yol maliyeti [PathContext.costAt]'te
  /// zaten indirimli) — gerçekten bir adımlık hoplar hâlâ düz gider.
  static const double kPathMinDist = 1.8;

  (double, double) _nextWaypoint(double tx, double ty, double dist) {
    final ctx = pathContext;
    if (ctx == null || dist < kPathMinDist) return (tx, ty);

    _ensurePath(tx, ty, ctx);
    final path = _path;
    if (path == null || path.isEmpty) return (tx, ty);

    // Geride kalan waypoint'leri atla.
    //
    // İKİ KURAL. Sadece "yeterince yaklaştıysan atla" yetmiyor: kaçınma kavisi
    // (bkz. separation → [Locomotion.addAvoid]) NPC'yi bir waypoint'in
    // İLERİSİNE sürükleyebiliyor ve NPC geri dönüp o noktayı işaretlemeye
    // çalışıyor — tam da düzeltmeye çalıştığımız git-gel. İkinci kural bunu
    // kapatır: bir SONRAKİ waypoint daha yakınsa, mevcut olan geride kalmıştır.
    while (_pathIdx < path.length) {
      final wp  = path[_pathIdx];
      final wpx = wp.$1 + 0.5;
      final wpy = wp.$2 + 0.5;
      final wd  = sqrt((wpx - gridX) * (wpx - gridX) +
                       (wpy - gridY) * (wpy - gridY));
      if (wd < 0.35) {
        _pathIdx++;
        continue;
      }
      if (_pathIdx + 1 < path.length) {
        final nxt = path[_pathIdx + 1];
        final nx  = nxt.$1 + 0.5;
        final ny  = nxt.$2 + 0.5;
        final nd  = sqrt((nx - gridX) * (nx - gridX) +
                         (ny - gridY) * (ny - gridY));
        if (nd < wd) {
          _pathIdx++;
          continue;
        }
      }
      return (wpx, wpy);
    }
    // Path tükendi — sub-tile presizyon için true goal'a yönel.
    return (tx, ty);
  }

  void _ensurePath(double tx, double ty, PathContext ctx) {
    final goalC = tx.round();
    final goalR = ty.round();
    final myC   = gridX.round();
    final myR   = gridY.round();

    final goalChanged  = goalC != _pathGoalC || goalR != _pathGoalR;
    final versionStale = _pathVersion != ctx.version;
    final pathExhausted = _path == null || _pathIdx >= (_path?.length ?? 0);

    if (!goalChanged && !versionStale && !pathExhausted) return;
    // Replan kısıtı — [kPathMinDist] 3.0'dan 1.8'e indiği için kısa gidişler de
    // A* kullanıyor; hedef değişmediği sürece saniyede birkaç kereden fazla
    // yeniden plan yapmak boşuna (her çağrı 128×128 buffer'ı üç kez siliyor).
    // Hedef ya da dünya değiştiyse kısıt yok — gecikmeli tepki istemiyoruz.
    if (!goalChanged && !versionStale && _replanCd > 0) return;
    _replanCd = _kReplanInterval;

    _pathGoalC   = goalC;
    _pathGoalR   = goalR;
    _pathVersion = ctx.version;
    // findPath başlangıcı içermez, hedef tile'ı içerir.
    _path = Pathfinder.findPath(myC, myR, goalC, goalR, ctx.costAt, ctx.blocked);
    _pathIdx = 0;
  }

  /// Sabit adımlı hareket (dt'den bağımsız mutlak `step`). Lokomosyonun aynı
  /// ivme/dönüş kurallarından geçer; `step` burada "bu karede kat edilmek
  /// istenen mesafe" olarak istenen hıza çevrilir.
  void _stepFixed(double tx, double ty, double step, double goalDist) {
    // dt bilinmiyor — çağıran kare başına mutlak adım verir. Hızı adımdan
    // türetmek için nominal 1/60 kare varsayılır.
    const nominalDt = 1 / 60.0;
    _drive(tx, ty, nominalDt, step / nominalDt, goalDist);
  }

  void _stepDt(
      double tx, double ty, double dt, double speedScale, double goalDist) {
    final boost = roadSystem?.speedMultiplierAt(gridX, gridY) ?? 1.0;
    _drive(tx, ty, dt, speed * boost * speedScale, goalDist);
  }

  /// ORTAK SÜRÜŞ — hedefe doğru bir kare ilerlet.
  ///
  /// Eskiden burada hedefe düz çizgi bir "ışınlanma" vardı: yön anlık,
  /// hız anlık, bakış ham `dx > 0`. Artık gidiş [Locomotion] üzerinden:
  /// kalkışta ivmelenir, hedefe yaklaşırken frenler, yön değişimi açısal hız
  /// sınırıyla kavise dönüşür.
  ///
  /// [tx],[ty] bir SONRAKİ adımın hedefi — A* izlenirken ara waypoint olabilir.
  /// [goalDist] ise GERÇEK hedefe kalan mesafe: varış freni buna bakar, yoksa
  /// NPC her waypoint'te yavaşlayıp yol boyunca zıplayarak ilerlerdi.
  void _drive(double tx, double ty, double dt, double maxSpeed, double goalDist) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);

    // Deadlock yield ya da hedefin üstündeyiz → yumuşak duruş (konum sabit).
    if (_yieldTimer > 0 || dist < 0.001) {
      loco.brake(dt);
      return;
    }

    // Varış freni — GERÇEK hedefin son ~1 tile'ında hız düşer, NPC duvara
    // toslar gibi durmaz. Taban çarpan sürünmeyi engeller.
    var want = maxSpeed;
    if (goalDist < Locomotion.kArriveRadius) {
      final t = goalDist / Locomotion.kArriveRadius;
      want *= t < Locomotion.kArriveFloor ? Locomotion.kArriveFloor : t;
    }

    var (mx, my) = loco.advance(dt, dx / dist, dy / dist, want);
    // Hedefi aşma — kalan mesafeden uzun adım atma.
    final m = sqrt(mx * mx + my * my);
    if (m > dist && m > 1e-9) {
      final s = dist / m;
      mx *= s;
      my *= s;
    }
    gridX += mx;
    gridY += my;

    // Yol bitimi tetiği — yoldan toprağa geçiş. (Yürürken bakınma artık no-op;
    // NPC hedefine varıp duraklayınca gerçekleşir.)
    final onRoad = roadSystem?.has(gridX.round(), gridY.round()) ?? false;
    if (_prevOnRoad && !onRoad && dist > 1.5) {
      glanceAround(duration: 1.1);
    }
    _prevOnRoad = onRoad;
  }

  /// Boştayken rasgele bir hedefe doğru yavaşça yürür.
  /// Su/soft engele girilirse geri çekilir.  Yeni hedef [idleIntervalRange]
  /// aralığında bir süre sonra seçilir.
  void idleWander(double dt, Random rng,
      Set<(int, int)> waterTiles,
      Set<(int, int)> softObstacles) {
    _idleTimer -= dt;
    if (_idleTimer <= 0) {
      final result = pickWanderTarget(
        wanderOriginX, wanderOriginY, wanderRadius, rng,
        waterTiles:    waterTiles,
        softObstacles: softObstacles,
        headX:         loco.vx,
        headY:         loco.vy,
        minDist:       1.2,
      );
      if (result != null) {
        _idleTargetX = result.$1;
        _idleTargetY = result.$2;
        // Yeni hedef → kısa "nereye gideyim" bakışı.
        glanceAround(duration: 0.75);
      }
      final (lo, hi) = idleIntervalRange;
      _idleTimer = lo + rng.nextDouble() * (hi - lo);
    }
    final prevX = gridX;
    moveTowards(_idleTargetX, _idleTargetY, dt, speedScale: idleSpeedFactor);
    if (waterTiles.contains((gridX.round(), gridY.round()))) {
      gridX      = prevX;
      loco.reset();
      _idleTimer = 0.1;
    }
  }

  /// Dolaşma hedefi seçimi — SEÇMELİ, rastgele değil.
  ///
  /// Eski hâli [homeCol],[homeRow] çevresinde düzgün rastgele bir nokta
  /// seçiyordu; ardışık iki hedef yaklaşık yarı yarıya ZIT yönde çıkıyor ve
  /// NPC gerçek anlamda git-gel yapıyordu. Artık aday havuzu puanlanır:
  ///   • ileri süreklilik — mevcut gidiş yönüyle aynı tarafta olan hedef
  ///     kazanır ([headX],[headY] verilmişse); geri dönüşler cezalanır,
  ///   • mesafe — çok yakın (yerinde titreme) ve çok uzak adaylar elenir
  ///     ([minDist] altı hiç kabul edilmez),
  ///   • yol — yol tile'ı üstündeki hedef bonus alır; köy trafiği kendiliğinden
  ///     damarlara oturur,
  ///   • küçük gürültü — aynı köylü hep aynı köşeye gitmesin.
  ///
  /// Hiçbir aday geçmezse yalnız sudan kaçınan eski fallback devreye girer.
  (double, double)? pickWanderTarget(
    double homeCol,
    double homeRow,
    double radius,
    Random rng, {
    required Set<(int, int)> waterTiles,
    Set<(int, int)> softObstacles = const {},
    double minC = 1.0,
    double minR = 1.0,
    double maxC = -1,
    double maxR = -1,
    double headX = 0,
    double headY = 0,
    double minDist = 0,
  }) {
    final mC = maxC < 0 ? (kCols - 2).toDouble() : maxC;
    final mR = maxR < 0 ? (kRows - 2).toDouble() : maxR;

    final headMag = sqrt(headX * headX + headY * headY);
    final sweet = radius * 0.75; // tercih edilen yolculuk uzunluğu

    (double, double)? best;
    double bestScore = -1e9;

    for (int i = 0; i < 14; i++) {
      final tx = (homeCol + rng.nextDouble() * radius * 2 - radius).clamp(minC, mC);
      final ty = (homeRow + rng.nextDouble() * radius * 2 - radius).clamp(minR, mR);
      final c = tx.round(), r = ty.round();
      if (waterTiles.contains((c, r))) continue;
      if (softObstacles.contains((c, r))) continue;

      final dx = tx - gridX, dy = ty - gridY;
      final d = sqrt(dx * dx + dy * dy);
      if (d < minDist) continue;

      double score = rng.nextDouble() * 0.30;
      // İleri süreklilik — mevcut yönle hizalı hedef kazanır.
      if (headMag > 1e-6 && d > 1e-6) {
        score += ((dx * headX + dy * headY) / (d * headMag)) * 1.5;
      }
      // Mesafe uygunluğu — sweet spot'tan uzaklaştıkça düşer.
      score += (1.0 - (d - sweet).abs() / (radius + 1.0)) * 0.6;
      // Yol tercihi.
      if (roadSystem?.has(c, r) ?? false) score += 0.75;

      if (score > bestScore) {
        bestScore = score;
        best = (tx, ty);
      }
    }
    if (best != null) return best;

    for (int i = 0; i < 8; i++) {
      final tx = (homeCol + rng.nextDouble() * radius * 2 - radius).clamp(minC, mC);
      final ty = (homeRow + rng.nextDouble() * radius * 2 - radius).clamp(minR, mR);
      if (waterTiles.contains((tx.round(), ty.round()))) continue;
      return (tx, ty);
    }
    return null;
  }
}
