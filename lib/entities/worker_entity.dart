import 'dart:math';
import '../characters/npc_visual.dart';
import '../core/constants.dart';
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

  double gridX;
  double gridY;
  bool   facingRight = true;
  double walkPhase   = 0.0;
  bool   isWalking   = false;

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
      // Engelle karşılaşan NPC "etrafa bakıp" başka yol arar gibi görünür.
      glanceAround(duration: _yieldTimer);
    }
    _stuckRefX = gridX;
    _stuckRefY = gridY;
  }

  /// Glance state'i decrement eder + walking→idle geçişinde bir kez bakış.
  /// Diğer trigger'lar (yol bitimi, yield, yeni hedef) ilgili call site'lardan
  /// `glanceAround()`'u çağırır.
  void _tickIdleAnim(double dt) {
    if (_glanceTimer > 0) _glanceTimer -= dt;
    // Yolculuk yeni bitti (walking → idle) → varış kontrolü bakışı.
    if (_prevIsWalking && !isWalking) {
      glanceAround(duration: 0.9);
    }
    _prevIsWalking = isWalking;
  }

  /// Bağlamsal "etrafa bak" — geçici süreyle facingRight'ı ters gösterir.
  /// Yol bitiminde, yieldden çıkarken, yeni hedef seçildiğinde, varışta vb.
  /// çağrılır. Hash-bazlı süre varyasyonu desync sağlar.
  void glanceAround({double duration = 1.0}) {
    final seed = (identityHashCode(this) & 0xFF) / 255.0;
    final dur = duration * (0.85 + seed * 0.3);
    if (_glanceTimer < dur) _glanceTimer = dur;
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

  /// Render tarafı facing — bağlamsal glance sırasında ters çevirir.
  bool get effectiveFacingRight =>
      _glanceTimer > 0 ? !facingRight : facingRight;

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
    _stepFixed(next.$1, next.$2, step);
  }

  /// Hedefe `speed * dt` adımla ilerle. arriveD altına düşünce true döner —
  /// alt sınıf state geçişi için kullanır. Path-aware (bkz. moveTo).
  bool moveTowards(double tx, double ty, double dt, {double arriveD = 0.08}) {
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist <= arriveD) return true;
    final next = _nextWaypoint(tx, ty, dist);
    _stepDt(next.$1, next.$2, dt);
    return false;
  }

  /// (tx, ty) gerçek hedef; dönüş: bir SONRAKİ adımın hedefi (waypoint ya
  /// da true goal). Kısa mesafe / no-context → doğrudan true goal.
  (double, double) _nextWaypoint(double tx, double ty, double dist) {
    final ctx = pathContext;
    if (ctx == null || dist < 3.0) return (tx, ty);

    _ensurePath(tx, ty, ctx);
    final path = _path;
    if (path == null || path.isEmpty) return (tx, ty);

    // Yaklaşılmış waypoint'leri atla (NPC drift'inde geri dönme yok).
    while (_pathIdx < path.length) {
      final wp  = path[_pathIdx];
      final wpx = wp.$1 + 0.5;
      final wpy = wp.$2 + 0.5;
      final wd  = sqrt((wpx - gridX) * (wpx - gridX) +
                       (wpy - gridY) * (wpy - gridY));
      if (wd < 0.30) {
        _pathIdx++;
        continue;
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

    _pathGoalC   = goalC;
    _pathGoalR   = goalR;
    _pathVersion = ctx.version;
    // findPath başlangıcı içermez, hedef tile'ı içerir.
    _path = Pathfinder.findPath(myC, myR, goalC, goalR, ctx.costAt, ctx.blocked);
    _pathIdx = 0;
  }

  void _stepFixed(double tx, double ty, double step) {
    if (_yieldTimer > 0) return; // deadlock yield
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.01) return;
    final boost = roadSystem?.speedMultiplierAt(gridX, gridY) ?? 1.0;
    final ratio = min(step * boost / dist, 1.0);
    final prevX = gridX;
    gridX += dx * ratio;
    gridY += dy * ratio;
    facingRight = gridX >= prevX;
  }

  void _stepDt(double tx, double ty, double dt) {
    if (_yieldTimer > 0) return; // deadlock yield
    final dx   = tx - gridX;
    final dy   = ty - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist < 0.001) return;
    final boost = roadSystem?.speedMultiplierAt(gridX, gridY) ?? 1.0;
    final step = (speed * boost * dt).clamp(0.0, dist);
    gridX += (dx / dist) * step;
    gridY += (dy / dist) * step;
    facingRight = dx > 0;

    // Yol bitimi tetiği — yoldan toprağa geçişte ve hedef hâlâ uzaktaysa
    // NPC bir an "şimdi nereden gideyim" bakışı atar.
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
    moveTowards(_idleTargetX, _idleTargetY, dt * idleSpeedFactor);
    if (waterTiles.contains((gridX.round(), gridY.round()))) {
      gridX      = prevX;
      _idleTimer = 0.1;
    }
  }

  /// İki geçişli wander hedefi seçimi:
  ///  1. Önce soft engelsiz tile dene.
  ///  2. Bulunamazsa sadece su'dan kaçın (fallback).
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
  }) {
    final mC = maxC < 0 ? (kCols - 2).toDouble() : maxC;
    final mR = maxR < 0 ? (kRows - 2).toDouble() : maxR;

    for (int i = 0; i < 8; i++) {
      final tx = (homeCol + rng.nextDouble() * radius * 2 - radius).clamp(minC, mC);
      final ty = (homeRow + rng.nextDouble() * radius * 2 - radius).clamp(minR, mR);
      if (waterTiles.contains((tx.round(), ty.round()))) continue;
      if (softObstacles.contains((tx.round(), ty.round()))) continue;
      return (tx, ty);
    }
    for (int i = 0; i < 8; i++) {
      final tx = (homeCol + rng.nextDouble() * radius * 2 - radius).clamp(minC, mC);
      final ty = (homeRow + rng.nextDouble() * radius * 2 - radius).clamp(minR, mR);
      if (waterTiles.contains((tx.round(), ty.round()))) continue;
      return (tx, ty);
    }
    return null;
  }
}
