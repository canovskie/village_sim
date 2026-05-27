import 'dart:math';
import '../characters/villager_type.dart';
import '../characters/npc_visual.dart';
import '../characters/life_stage.dart';
import '../core/constants.dart';
import 'worker_entity.dart';

enum VillagerState { moving, idle, sleeping, walkingToSleep, walkingToPickup, carrying }

/// NPC'nin boş zaman hareket kişiliği — "otlayan inek" tekdüzeliğini kırar.
/// Tipe göre atanır (bkz. [VillagerEntity._behaviorFor]); her davranışın
/// kendine has dolaşma yarıçapı, duraklama süresi, yürüyüş hızı ve etrafa
/// bakınma sıklığı vardır.
///   - [patrol]    : iki nokta arası mekik + uçlarda tarama (muhafız)
///   - [ponder]    : çoğunlukla durağan, nadiren yavaş adım (büyücü)
///   - [stroll]    : orta menzilli amaçlı turlar (tüccar, çiftçi)
///   - [homebody]  : spawn çevresinde dar, telaşlı (demirci, madenci)
///   - [waterside] : geniş dolaşır, su kıyısını tercih eder (balıkçı)
///   - [playful]   : çocuk — hızlı kısa koşuşturmalar, sık yön değiştirme,
///                   yuva çevresinde oyun (yaşam evresi child iken geçerli)
enum WanderBehavior { patrol, ponder, stroll, homebody, waterside, playful }

class VillagerEntity extends WorkerEntity {
  final VillagerType type;

  /// Her NPC için kalıcı görsel kimlik — ten/saç/göz/sakal/kıyafet tonu.
  /// Aynı tipten NPC'lerin tıpatıp aynı görünmesini önler.
  final NpcVisual visual;

  double targetCol;
  double targetRow;

  VillagerState state = VillagerState.idle;
  double idleTimer = 0;

  @override
  final double speed;

  /// Bu NPC'nin boş zaman hareket kişiliği — tipe göre sabit.
  final WanderBehavior behavior;

  /// Etrafa bakınma sayacı — boştayken yerinde dönüp gözlem yapar.
  double _lookTimer = 0;

  // ── Devriye (patrol) durumu — iki uç nokta arası mekik ────────────────────
  bool _patInit = false;   // uçlar spawn'a göre bir kez hesaplanır
  bool _patToB  = true;    // sıradaki hedef B mi (değilse A)
  double _patAx = 0, _patAy = 0, _patBx = 0, _patBy = 0;

  // Uyku sistemi
  bool _wasSleeping = false;
  /// Nereye gidip uyuyacak (main.dart tarafından her gece atanır)
  (double, double)? sleepTarget;
  /// true → eve girmiş sayılır (render edilmez)
  bool sleepIsHome = false;
  /// Şu an bina içinde mi (gizlenir)
  bool isInsideBuilding = false;
  /// Atanan ev binası (null = evsiz)
  Object? homeBuilding; // BuildingEntity türü, döngüsel import önlemek için Object

  // Porter/carry sistemi
  Object? _pickupItem;           // ResourceBox veya HayEntity
  Object? carriedItem;           // aktif taşıma sırasında görünür
  double _pickupX = 0, _pickupY = 0;
  double _deliverX = 0, _deliverY = 0;
  void Function()? _onDelivered;

  /// Ahır binalarının verdiği taşıma hızı çarpanı (≥1). main.dart her tick atar.
  /// Yalnızca pickup/teslimat hareketine uygulanır.
  double carrySpeedMultiplier = 1.0;

  /// Yaş (oyun günü cinsinden) — her tick artar, yaşam evresini belirler.
  /// Doğan köylü 0'dan başlar; kurucu NPC'ler yetişkin yaşıyla doğar.
  double ageDays;

  /// Doğal ölüm yaşı (oyun günü). [ageDays] bunu geçince yaşlı köylü ölür.
  /// Varsayılan sonsuz = ölümsüz (geriye dönük güvenli); main gerçek değer verir.
  final double lifespanDays;

  VillagerEntity({
    required this.type,
    required super.startCol,
    required super.startRow,
    int? visualSeed,
    this.ageDays = 0,
    this.lifespanDays = double.infinity,
  })  : targetCol = startCol,
        targetRow = startRow,
        speed     = _speedFor(type),
        behavior  = _behaviorFor(type),
        visual    = NpcVisual.fromSeed(
            visualSeed ?? _autoSeed(type, startCol, startRow));

  /// Otomatik visual seed — type + spawn pozisyonu hash'i.  Aynı pozisyondan
  /// aynı tipte spawn olan iki NPC olmaz pratikte, ama görsel seed verilebilir.
  static int _autoSeed(VillagerType t, double c, double r) =>
      t.index * 7919
      ^ (c * 1009).toInt() * 13
      ^ (r * 1031).toInt() * 31
      ^ DateTime.now().microsecondsSinceEpoch & 0xFFFF;

  bool get isSleeping => state == VillagerState.sleeping;
  bool get isCarrying => state == VillagerState.carrying || state == VillagerState.walkingToPickup;

  /// Güncel yaşam evresi (yaştan türer).
  LifeStage get lifeStage => lifeStageForDays(ageDays);

  /// Yetişkin/yaşlı → meslek görünümü; çocuk/genç → mesleksiz köylü.
  bool get hasProfession => lifeStage.hasProfession;

  /// Çocuk mu? Taşıma/iş ataması dışı tutulur, oyuncu davranış uygular.
  bool get isChild => lifeStage == LifeStage.child;

  /// O anki etkin dolaşma davranışı. Çocukken tipinin davranışı yerine
  /// [WanderBehavior.playful]; büyüyünce kendi tip davranışına döner.
  WanderBehavior get _activeBehavior =>
      isChild ? WanderBehavior.playful : behavior;

  void assignCarryTask(Object item, double pickX, double pickY,
      double destX, double destY, {void Function()? onDelivered}) {
    _pickupItem  = item;
    _pickupX     = pickX;
    _pickupY     = pickY;
    _deliverX    = destX;
    _deliverY    = destY;
    _onDelivered = onDelivered;
    state        = VillagerState.walkingToPickup;
    isWalking    = true;
  }

  static double _speedFor(VillagerType t) {
    switch (t) {
      case VillagerType.farmer:     return 1.2;
      case VillagerType.merchant:   return 0.9;
      case VillagerType.blacksmith: return 0.8;
      case VillagerType.guard:      return 1.6;
      case VillagerType.mage:       return 0.7;
      case VillagerType.miner:      return 0.85;
      case VillagerType.fisher:     return 1.1;
    }
  }

  static WanderBehavior _behaviorFor(VillagerType t) => switch (t) {
        VillagerType.guard      => WanderBehavior.patrol,
        VillagerType.mage       => WanderBehavior.ponder,
        VillagerType.merchant   => WanderBehavior.stroll,
        VillagerType.farmer     => WanderBehavior.stroll,
        VillagerType.blacksmith => WanderBehavior.homebody,
        VillagerType.miner      => WanderBehavior.homebody,
        VillagerType.fisher     => WanderBehavior.waterside,
      };

  // ── Kişilik parametreleri (etkin davranışa göre) ───────────────────────────
  /// Spawn çevresinde dolaşma yarıçapı (tile).
  double get _roamRadius => switch (_activeBehavior) {
        WanderBehavior.patrol    => 3.0,
        WanderBehavior.ponder    => 1.5,
        WanderBehavior.stroll    => 3.5,
        WanderBehavior.homebody  => 1.8,
        WanderBehavior.waterside => 4.0,
        WanderBehavior.playful   => 3.0, // yuva çevresinde koşuşturur
      };

  /// Hedefe varınca duraklama süresi aralığı (saniye).
  (double, double) get _dwellRange => switch (_activeBehavior) {
        WanderBehavior.patrol    => (2.0, 4.0),
        WanderBehavior.ponder    => (4.0, 9.0),
        WanderBehavior.stroll    => (1.5, 4.5),
        WanderBehavior.homebody  => (1.0, 3.0),
        WanderBehavior.waterside => (2.0, 5.0),
        WanderBehavior.playful   => (0.2, 1.2), // hiç durmaz, hep hareket halinde
      };

  /// Yürürken ana hıza uygulanan çarpan — kişiliğe göre tempo.
  double get _tripSpeed => switch (_activeBehavior) {
        WanderBehavior.patrol    => 1.0,
        WanderBehavior.ponder    => 0.55,
        WanderBehavior.stroll    => 0.7,
        WanderBehavior.homebody  => 0.65,
        WanderBehavior.waterside => 0.85,
        WanderBehavior.playful   => 1.35, // kısa hızlı koşuşturmalar
      };

  /// Boştayken bir "bakınma anında" yön değiştirme olasılığı.
  double get _lookChance => switch (_activeBehavior) {
        WanderBehavior.patrol    => 0.7,
        WanderBehavior.ponder    => 0.5,
        WanderBehavior.stroll    => 0.4,
        WanderBehavior.homebody  => 0.55,
        WanderBehavior.waterside => 0.35,
        WanderBehavior.playful   => 0.85, // meraklı, sürekli etrafa bakar
      };

  /// Yeni hedef seçerken bazen hiç gitmeyip olduğu yerde oyalanma olasılığı.
  double get _stayChance => switch (_activeBehavior) {
        WanderBehavior.patrol    => 0.0,
        WanderBehavior.ponder    => 0.45,
        WanderBehavior.stroll    => 0.12,
        WanderBehavior.homebody  => 0.22,
        WanderBehavior.waterside => 0.10,
        WanderBehavior.playful   => 0.05, // nadiren durur
      };

  void update(double dt, int gridCols, int gridRows, Random rng,
      {Set<(int, int)> waterTiles  = const {},
       Set<(int, int)> softObstacles = const {},
       double dayLight = 1.0}) {

    // ── Yaşlanma — her durumda (uyku/taşıma dahil) ilerler ────────────────
    ageDays += dt / kGameDaySeconds;

    // ── Gece/gündüz geçişi ────────────────────────────────────────────────
    final isNight = dayLight < kNightThreshold;
    final isDawn  = dayLight >= kDawnThreshold;

    // ── Porter: finish delivery first even at night ──────────────────────────
    if (state == VillagerState.walkingToPickup) {
      final dx   = _pickupX - gridX;
      final dy   = _pickupY - gridY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.25) {
        gridX       = _pickupX;
        gridY       = _pickupY;
        carriedItem = _pickupItem;
        _pickupItem = null;
        state       = VillagerState.carrying;
        isWalking   = false;
      } else {
        final step = speed * carrySpeedMultiplier * dt;
        gridX += (dx / dist) * min(step, dist);
        gridY += (dy / dist) * min(step, dist);
        facingRight = dx > 0;
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.carrying) {
      final dx   = _deliverX - gridX;
      final dy   = _deliverY - gridY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.25) {
        gridX = _deliverX;
        gridY = _deliverY;
        _onDelivered?.call();
        _onDelivered = null;
        carriedItem  = null;
        state        = VillagerState.idle;
        idleTimer    = 0.4 + rng.nextDouble() * 1.5;
        isWalking    = false;
      } else {
        final step = speed * carrySpeedMultiplier * dt;
        gridX += (dx / dist) * min(step, dist);
        gridY += (dy / dist) * min(step, dist);
        facingRight = dx > 0;
        isWalking = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
      walkPhase %= pi * 2;
      return;
    }

    if (isNight && !_wasSleeping) {
      _wasSleeping = true;
      if (sleepTarget != null) {
        state     = VillagerState.walkingToSleep;
        isWalking = true;
      } else {
        state     = VillagerState.sleeping;
        isWalking = false;
      }
    } else if (isDawn && _wasSleeping) {
      state               = VillagerState.idle;
      idleTimer           = 1.0 + rng.nextDouble() * 2.0;
      _wasSleeping        = false;
      isInsideBuilding    = false;
    }

    if (state == VillagerState.walkingToSleep) {
      final (tx, ty) = sleepTarget!;
      final dx   = tx - gridX;
      final dy   = ty - gridY;
      final dist = sqrt(dx * dx + dy * dy);
      if (dist < 0.55) {
        gridX = tx; gridY = ty;
        state = VillagerState.sleeping;
        isWalking = false;
        if (sleepIsHome) isInsideBuilding = true;
      } else {
        final step = speed * dt;
        gridX += (dx / dist) * min(step, dist);
        gridY += (dy / dist) * min(step, dist);
        facingRight = dx > 0;
        isWalking   = true;
      }
      walkPhase += dt * (isWalking ? speed * 5.5 : 0.4);
      walkPhase %= pi * 2;
      return;
    }

    if (state == VillagerState.sleeping) {
      walkPhase += dt * 0.4;
      walkPhase %= pi * 2;
      return;
    }

    // ── Normal gündüz davranışı ───────────────────────────────────────────
    switch (state) {
      case VillagerState.idle:
        idleTimer  -= dt;
        _lookTimer -= dt;
        // Boştayken ara sıra etrafa bakınma — donuk durmak yerine canlı durur.
        if (_lookTimer <= 0) {
          if (idleTimer > 0.5 && rng.nextDouble() < _lookChance) {
            facingRight = !facingRight;
          }
          _lookTimer = 0.7 + rng.nextDouble() * 1.8;
        }
        if (idleTimer <= 0) {
          _pickNewTarget(gridCols, gridRows, rng, waterTiles, softObstacles);
        }

      case VillagerState.moving:
        final dx   = targetCol - gridX;
        final dy   = targetRow - gridY;
        final dist = sqrt(dx * dx + dy * dy);

        if (dist < 0.05) {
          gridX = targetCol;
          gridY = targetRow;
          // Devriyede vardığında sıradaki uca dön.
          if (_activeBehavior == WanderBehavior.patrol) _patToB = !_patToB;
          state = VillagerState.idle;
          final (lo, hi) = _dwellRange;
          idleTimer  = lo + rng.nextDouble() * (hi - lo);
          _lookTimer = 0.4 + rng.nextDouble();
        } else {
          final step  = speed * _tripSpeed * dt;
          final ratio = min(step / dist, 1.0);
          final prevX = gridX;
          gridX += dx * ratio;
          gridY += dy * ratio;
          if (waterTiles.contains((gridX.round(), gridY.round()))) {
            gridX     = prevX;
            gridY    -= (dy / dist) * step * ratio;
            state     = VillagerState.idle;
            idleTimer = 0.1;
            break;
          }
          if (gridX - prevX > 0.001) {
            facingRight = true;
          } else if (gridX - prevX < -0.001) {
            facingRight = false;
          }
        }

      case VillagerState.sleeping:
      case VillagerState.walkingToSleep:
      case VillagerState.walkingToPickup:
      case VillagerState.carrying:
        break; // yukarıda ele alındı
    }

    isWalking  = state == VillagerState.moving;
    walkPhase += dt * (isWalking ? speed * 5.5 : 1.2);
    walkPhase %= pi * 2;
  }

  /// Kişiliğe göre yeni dolaşma hedefi seçer.  Hedefler artık spawn noktasına
  /// demirlenir (haritada başıboş sürüklenme yerine kendi bölgesinde kalır).
  void _pickNewTarget(int cols, int rows, Random rng,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles) {
    const pad  = 1;
    final minC = pad.toDouble(), minR = pad.toDouble();
    final maxC = (cols - 1 - pad).toDouble();
    final maxR = (rows - 1 - pad).toDouble();

    // Bazı kişilikler bazen hiç hareket etmeden olduğu yerde oyalanır.
    if (_activeBehavior != WanderBehavior.patrol && rng.nextDouble() < _stayChance) {
      final (lo, hi) = _dwellRange;
      idleTimer = lo + rng.nextDouble() * (hi - lo);
      return;
    }

    // Devriye: iki sabit uç arasında mekik.
    if (_activeBehavior == WanderBehavior.patrol) {
      if (!_patInit) _initPatrol(rng, minC, minR, maxC, maxR, waterTiles);
      targetCol = _patToB ? _patBx : _patAx;
      targetRow = _patToB ? _patBy : _patAy;
      state     = VillagerState.moving;
      return;
    }

    // Tur başına yarıçap dalgalanması — tekdüze adımları kırar.
    final radius = _roamRadius * (0.7 + rng.nextDouble() * 0.5);

    (double, double)? result;
    if (_activeBehavior == WanderBehavior.waterside) {
      result = _waterEdgeTarget(
          rng, radius, waterTiles, softObstacles, minC, minR, maxC, maxR);
    }
    result ??= pickWanderTarget(
      spawnCol, spawnRow, radius, rng,
      waterTiles:    waterTiles,
      softObstacles: softObstacles,
      minC: minC, minR: minR, maxC: maxC, maxR: maxR,
    );

    if (result != null) {
      targetCol = result.$1;
      targetRow = result.$2;
      state     = VillagerState.moving;
    } else {
      idleTimer = 0.3 + rng.nextDouble();
    }
  }

  /// Devriye uçlarını spawn'dan geçen rastgele bir eksen boyunca bir kez kurar.
  void _initPatrol(Random rng, double minC, double minR, double maxC,
      double maxR, Set<(int, int)> waterTiles) {
    _patInit = true;
    final ang  = rng.nextDouble() * pi;          // 0..π → eksen yönü
    final half = 2.5 + rng.nextDouble() * 2.0;   // yarı uzunluk
    final dx = cos(ang) * half, dy = sin(ang) * half;
    _patAx = (spawnCol - dx).clamp(minC, maxC);
    _patAy = (spawnRow - dy).clamp(minR, maxR);
    _patBx = (spawnCol + dx).clamp(minC, maxC);
    _patBy = (spawnRow + dy).clamp(minR, maxR);
    // Bir uç su üstüne denk gelirse spawn'a çek.
    if (waterTiles.contains((_patAx.round(), _patAy.round()))) {
      _patAx = spawnCol; _patAy = spawnRow;
    }
    if (waterTiles.contains((_patBx.round(), _patBy.round()))) {
      _patBx = spawnCol; _patBy = spawnRow;
    }
  }

  /// Su kenarı hedefi — suya komşu ama su olmayan bir tile tercih eder.
  /// Bulunamazsa null döner (çağıran normal dolaşmaya düşer).
  (double, double)? _waterEdgeTarget(Random rng, double radius,
      Set<(int, int)> waterTiles, Set<(int, int)> softObstacles,
      double minC, double minR, double maxC, double maxR) {
    for (int i = 0; i < 10; i++) {
      final tx = (spawnCol + rng.nextDouble() * radius * 2 - radius)
          .clamp(minC, maxC);
      final ty = (spawnRow + rng.nextDouble() * radius * 2 - radius)
          .clamp(minR, maxR);
      final c = tx.round(), r = ty.round();
      if (waterTiles.contains((c, r))) continue;
      if (softObstacles.contains((c, r))) continue;
      final nearWater = waterTiles.contains((c + 1, r)) ||
          waterTiles.contains((c - 1, r)) ||
          waterTiles.contains((c, r + 1)) ||
          waterTiles.contains((c, r - 1));
      if (nearWater) return (tx, ty);
    }
    return null;
  }
}
