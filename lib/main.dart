import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'characters/villager_type.dart';
import 'entities/villager_entity.dart';
import 'entities/builder_entity.dart';
import 'entities/build_order.dart';
import 'rendering/game_painter.dart';
import 'core/constants.dart';
import 'buildings/building_entity.dart';
import 'buildings/building_renderer.dart';
import 'rendering/tile_renderer.dart';
import 'world/day_night_cycle.dart';
import 'farm/farm_tile.dart';
import 'entities/farm_farmer.dart';
import 'farm/farm_renderer.dart';
import 'world/tree_entity.dart';
import 'rendering/tree_renderer.dart';
import 'entities/woodcutter_entity.dart';
import 'entities/lumber_camp_entity.dart';
import 'world/mine_node.dart';
import 'rendering/mine_renderer.dart';
import 'entities/miner_entity.dart';
import 'entities/fisher_entity.dart';
import 'rendering/tool_renderer.dart';
import 'world/nature_entity.dart';
import 'rendering/nature_renderer.dart';
import 'world/world_generator.dart';
import 'buildings/building_type.dart';
import 'ui/hud.dart';
import 'ui/building_panel.dart';
import 'ui/building_info_panel.dart';
import 'ui/sky_widgets.dart';
import 'ui/loading_screen.dart';
import 'ui/mode_button.dart';
import 'world/resource_box.dart';
import 'world/hay_entity.dart';
import 'rendering/resource_renderer.dart';
import 'core/resources.dart';
import 'ui/game_theme.dart';
import 'ui/main_menu_screen.dart';
import 'systems/separation_system.dart';
import 'systems/hay_processor.dart';
import 'systems/carrier_system.dart';
import 'systems/building_system.dart';
import 'buildings/building_function.dart';
import 'characters/life_stage.dart';

void main() => runApp(const VillageSimApp());

class VillageSimApp extends StatelessWidget {
  const VillageSimApp({super.key});

  @override
  Widget build(BuildContext context) => const MaterialApp(
    title: 'Village Sim',
    debugShowCheckedModeBanner: false,
    home: _AppRoot(),
  );
}

/// Ana menüden oyuna ve geri geçişi yöneten kök widget.
/// Sahne değişimini state ile yapıyoruz; böylece oyundan çıkış doğrudan
/// menüye döner ve oyun durumu yeni başladığında temiz olur.
class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  bool _inGame = false;
  int _gameKey = 0; // Her yeni oyun için VillageScene'i yeniden oluşturur

  void _startGame() => setState(() {
    _inGame = true;
    _gameKey++;
  });
  void _exitGame() => setState(() => _inGame = false);

  @override
  Widget build(BuildContext context) {
    if (_inGame) {
      return VillageScene(key: ValueKey(_gameKey), onExitToMenu: _exitGame);
    }
    return MainMenuScreen(onNewGame: _startGame);
  }
}

// ─── MAIN SCENE ──────────────────────────────────────────────────────────────

class VillageScene extends StatefulWidget {
  final VoidCallback? onExitToMenu;
  const VillageScene({super.key, this.onExitToMenu});
  @override
  State<VillageScene> createState() => _VillageSceneState();
}

class _VillageSceneState extends State<VillageScene>
    with SingleTickerProviderStateMixin {
  // ── Game loop ──────────────────────────────────────────────────────────────
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _rng = Random();
  double _time = 0;

  // ── Asset loading ──────────────────────────────────────────────────────────
  /// Tüm sprite cache'leri yüklenene kadar oyun render edilmez.
  /// initState'te paralel başlatılır; yüklenince ticker başlar.
  late final Future<void> _assetsReady;
  bool _assetsLoaded = false;

  // ── Economy ────────────────────────────────────────────────────────────────
  // Köy stoğu — taşıyıcılar tarafından doldurulur, inşaat orderları tüketir.
  // Ateş yeri ücretsiz; gerçek malzemeler işçiler ürettikçe birikir.
  final ResourceBundle _stockpile = ResourceBundle();

  // Binalardan türeyen köy istatistikleri (kapasite, moral, taşıyıcı hızı).
  // Her tick updateBuildings ile güncellenir; panel ve HUD okur.
  VillageStats _stats = const VillageStats(
    stockCapacity: kBaseStockCapacity,
    morale: 0.5,
    growthMultiplier: 1.0,
    carrierSpeedMultiplier: 1.0,
    wellCount: 0,
  );

  // ── Entities ───────────────────────────────────────────────────────────────
  final List<VillagerEntity> _villagers = [];
  final List<BuildingEntity> _buildings = [];
  final List<BuilderEntity> _builders = [];
  final List<BuildOrder> _orders = [];

  // ── Firepit & home sistemi ─────────────────────────────────────────────────
  bool _hasFire = false;
  BuildingEntity? _firepitBuilding;
  BuildingEntity? _selectedBuilding;

  // ── Camera + Zoom ──────────────────────────────────────────────────────────
  Offset _camera = const Offset(-160, -80);
  Offset? _panAnchor;
  Offset? _cameraAnchor;
  double _zoom = 1.0;
  double _scaleStart = 1.0;

  // ── Placement ──────────────────────────────────────────────────────────────
  BuildingType? _placing;
  (int, int)? _ghost;
  Size _viewSize = Size.zero;

  // ── Day/Night ──────────────────────────────────────────────────────────────
  final DayNightCycle _cycle = DayNightCycle();

  // ── Farm ───────────────────────────────────────────────────────────────────
  final List<FarmTile> _farmTiles = [];
  final List<FarmFarmer> _farmers = [];

  // ── Trees ──────────────────────────────────────────────────────────────────
  final List<TreeEntity> _trees = [];

  // ── Lumber (ağaç kesme) ────────────────────────────────────────────────────
  final List<WoodcutterEntity> _woodcutters = [];
  // Oduncu kulübeleri — her bina kendi LumberCampEntity'sine sahip
  final List<LumberCampEntity> _lumberCamps = [];
  bool _lumberMode = false;
  (int, int)? _lumberStart;
  (int, int)? _lumberEnd;

  // ── World ─────────────────────────────────────────────────────────────────
  late int _worldSeed;
  final Set<(int, int)> _waterTiles = {};
  final List<LotusEntity> _lotuses = [];
  final List<ReedClump> _reeds = [];

  // ── Mining (maden kazma) ───────────────────────────────────────────────────
  final List<MineNode> _mineNodes = [];
  final List<MinerEntity> _miners = [];
  // ── Fisher ────────────────────────────────────────────────────────────────
  final List<FisherEntity> _fishers = [];

  // ── Resources ─────────────────────────────────────────────────────────────
  final List<ResourceBox> _resourceBoxes = [];
  final List<HayEntity> _hayEntities = [];
  double _carrierTimer = 0.0;

  /// Nüfus yiyecek tüketimi için kesirli birikim (≥1 olunca stoktan düşülür).
  double _foodHunger = 0.0;

  // ── God mode ───────────────────────────────────────────────────────────────
  bool _godMode = false;

  bool _mineMode = false;
  (int, int)? _mineStart;
  (int, int)? _mineEnd;

  bool _farmMode = false;
  (int, int)? _farmStart;
  (int, int)? _farmEnd;

  // ── Notification ───────────────────────────────────────────────────────────
  String? _notification;
  int _notifId = 0;

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Gece eşiği geçişi — DayNightCycle edge-trigger eder.
    _cycle.onNightFall = _assignSleepTargets;

    _generateWorld();
    _ticker = createTicker(_onTick);

    // Tüm asset cache'lerini paralel yükle. Yüklenmeden ticker başlamaz —
    // sprite cache'leri boşken painter düzgün çizemez.
    _assetsReady = Future.wait([
      BuildingRenderer.loadAll(),
      TileRenderer.loadAll(),
      FarmRenderer.loadAll(),
      TreeRenderer.loadAll(),
      ToolRenderer.loadAll(),
      NatureRenderer.loadAll(),
      MineRenderer.loadAll(),
      ResourceRenderer.loadAll(),
    ]);
    _assetsReady.then((_) {
      if (!mounted) return;
      setState(() => _assetsLoaded = true);
      _ticker.start();
    });
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    setState(() {
      _time += dt;
      _cycle.update(dt);

      // ── God mode efektleri ────────────────────────────────────────────────────
      if (_godMode) {
        _stockpile.wood = 9999;
        _stockpile.stone = 9999;
        _stockpile.iron = 9999;
        _stockpile.coal = 9999;
        _stockpile.food = 9999;
        _stockpile.gold = 9999;
        _hasFire = true;
        // İnşaatları anında tamamla
        for (final o in _orders) {
          o.progress = 1.0;
          o.completed = true;
        }
      }

      // Konut doluluğunu güncelle — ev su tüketimi sakin sayısına bağlı.
      for (final b in _buildings) {
        if (b.fn?.role == BuildingRole.housing) b.occupants = 0;
      }
      for (final v in _villagers) {
        if (v.homeBuilding case final h?) (h as BuildingEntity).occupants++;
      }

      // ── Nüfus yiyecek tüketimi ──────────────────────────────────────────────
      // Tüm köylüler + işçiler zamanla yiyecek yer; üretim yetmezse stok azalır.
      final mouths = _villagers.length + _farmers.length + _woodcutters.length +
          _miners.length + _fishers.length + _builders.length;
      if (!_godMode && mouths > 0) {
        _foodHunger += dt * mouths * (kFoodPerVillagerPerDay / kGameDaySeconds);
        if (_foodHunger >= 1.0) {
          final eat = _foodHunger.floor();
          _foodHunger -= eat;
          _stockpile.food = (_stockpile.food - eat).clamp(0, 1 << 30);
        }
      }
      // Açlık 0..1: stok kStarveRampFood altına inince devreye girer (moral düşer).
      final starvation = _stockpile.food >= kStarveRampFood
          ? 0.0
          : (1.0 - _stockpile.food / kStarveRampFood);

      // ── Bina işlevleri: üretim, ticaret, nüfus büyümesi, stok kapasitesi ────
      _stats = updateBuildings(
        dt: dt,
        buildings: _buildings,
        stockpile: _stockpile,
        freeHousingSlots: _freeHousingSlots(),
        onSpawnVillager: _spawnGrownVillager,
        enforceCapacity: !_godMode,
        starvation: starvation,
      );
      // Ahır bonusunu taşıyıcılara uygula
      for (final v in _villagers) {
        v.carrySpeedMultiplier = _stats.carrierSpeedMultiplier;
      }

      // ── Toplama binaları çalışıyor mu? (panel durumu) ──────────────────────
      for (final b in _buildings) {
        switch (b.type) {
          case BuildingType.mineBuilding:
            b.isActive = _miners.any(
              (m) =>
                  m.isMining &&
                  m.gridX >= b.col - 0.5 &&
                  m.gridX < b.col + b.cols + 0.5 &&
                  m.gridY >= b.row - 0.5 &&
                  m.gridY < b.row + b.rows + 0.5,
            );
          case BuildingType.lumberCamp:
            b.isActive = _lumberCamps.any(
              (lc) =>
                  lc.buildingCol == b.col &&
                  lc.buildingRow == b.row &&
                  lc.state != LumberCampState.idle,
            );
          case BuildingType.fisherCabin:
            b.isActive = _fishers.any((f) => f.isFishing);
          default:
            break;
        }
      }
      // Su + aktif maden node'ları → geçilmez alan
      final obstacles = <(int, int)>{
        ..._waterTiles,
        for (final n in _mineNodes)
          if (!n.isDepleted) (n.col, n.row),
      };
      // Sazlık tile'ları → yumuşak engel (tercih edilmez ama geçilebilir)
      final softObs = <(int, int)>{
        for (final r in _reeds) ...<(int, int)>[
          (r.col, r.row),
          (r.col2, r.row2),
        ],
      };
      for (final v in _villagers) {
        v.update(
          dt,
          kCols,
          kRows,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
          dayLight: _cycle.dayLight,
        );
      }
      // Doğal ölüm — ömrü dolan yaşlılar köyden ayrılır. Taşıma işi varsa
      // önce bitirsin (yerde öksüz kutu/balya kalmasın). Belediye yerini doldurur.
      _villagers.removeWhere((v) {
        if (v.ageDays < v.lifespanDays || v.isCarrying) return false;
        _showNotification('🕯️ Yaşlı bir köylü hayata veda etti.');
        return true;
      });
      for (final b in _builders) {
        b.update(
          dt,
          _orders,
          _buildings,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
        );
      }
      // Tamamlanan inşaatlar için özel aksiyonlar
      for (final o in _orders) {
        if (o.completed) _onBuildingCompleted(o);
      }
      _orders.removeWhere((o) => o.completed);
      for (final t in _farmTiles) {
        t.update(dt);
      }
      // Kuyu binaları → çiftçilerin su aldığı kaynak (1x1, merkez konum).
      final wellPositions = <(double, double)>[
        for (final b in _buildings)
          if (b.type == BuildingType.well)
            (b.col + b.cols / 2, b.row + b.rows / 2),
      ];
      for (final f in _farmers) {
        f.update(
          dt,
          _farmTiles,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
          wellPositions: wellPositions,
        );
        // Çiftçi hasat sonucunu altın olarak değil yiyecek olarak hay pile
        // yığınıyla üretir; piller balya olur, balyalar depoya taşınır.
        if (f.harvestHayPos != null) {
          _hayEntities.add(
            HayEntity(
              type: HayType.pile,
              gridX: f.harvestHayPos!.$1.toDouble(),
              gridY: f.harvestHayPos!.$2.toDouble(),
            ),
          );
          f.harvestHayPos = null;
        }
      }
      processHayPiles(_hayEntities);
      for (final w in _woodcutters) {
        w.update(
          dt,
          _trees,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
        );
        if (w.harvestReady) {
          // Ağacın çevresine dağıt (ağacın içine değil)
          final angle = _rng.nextDouble() * 2 * pi;
          final dist = 0.6 + _rng.nextDouble() * 0.5;
          _resourceBoxes.add(
            ResourceBox(
              type: ResourceBoxType.woodChunk,
              gridX: w.lastHarvestX + 0.5 + cos(angle) * dist,
              gridY: w.lastHarvestY + 0.5 + sin(angle) * dist,
            ),
          );
        }
      }
      // Tarla + bina tile'ları → ağaç dikilemez
      final forbiddenForTrees = <(int, int)>{
        for (final t in _farmTiles) (t.col, t.row),
        for (final b in _buildings)
          for (int c = b.col; c < b.col + b.cols; c++)
            for (int r = b.row; r < b.row + b.rows; r++) (c, r),
      };
      for (final lc in _lumberCamps) {
        lc.update(
          dt,
          _trees,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
          forbiddenTiles: forbiddenForTrees,
        );
        if (lc.harvestReady) {
          final angle = _rng.nextDouble() * 2 * pi;
          final dist = 0.6 + _rng.nextDouble() * 0.5;
          _resourceBoxes.add(
            ResourceBox(
              type: ResourceBoxType.woodChunk,
              gridX: lc.lastHarvestX + 0.5 + cos(angle) * dist,
              gridY: lc.lastHarvestY + 0.5 + sin(angle) * dist,
            ),
          );
        }
      }
      // Fidan büyümesi güncelle, kesilen ağaçları kaldır
      for (final t in _trees) {
        t.update(dt);
      }
      _trees.removeWhere((t) => t.isFelled);
      for (final m in _miners) {
        m.update(
          dt,
          _mineNodes,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
        );
        if (m.harvestReady) {
          final boxType = switch (m.lastOreType) {
            OreType.iron => ResourceBoxType.ironBox,
            OreType.coal => ResourceBoxType.coalBox,
            _ => ResourceBoxType.stoneBox,
          };
          final angle = _rng.nextDouble() * 2 * pi;
          final dist = 0.7 + _rng.nextDouble() * 0.4;
          _resourceBoxes.add(
            ResourceBox(
              type: boxType,
              gridX: m.lastHarvestX + 0.5 + cos(angle) * dist,
              gridY: m.lastHarvestY + 0.5 + sin(angle) * dist,
            ),
          );
        }
      }
      for (final f in _fishers) {
        f.update(dt, _rng, waterTiles: _waterTiles, softObstacles: softObs);
        // Balıkçı doğrudan stoğa yiyecek üretir — fiziksel kutu yok.
        if (f.harvestReady) _stockpile.food += 1;
      }
      _mineNodes.removeWhere((n) => n.isDepleted);
      _carrierTimer -= dt;
      if (_carrierTimer <= 0) {
        _carrierTimer = kCarrierAssignInterval;
        assignCarriers(
          villagers: _villagers,
          buildings: _buildings,
          firepit: _firepitBuilding,
          resourceBoxes: _resourceBoxes,
          hayEntities: _hayEntities,
          stockpile: _stockpile,
          rng: _rng,
        );
      }
      applySeparation(
        dt: dt,
        villagers: _villagers,
        farmers: _farmers,
        woodcutters: _woodcutters,
        miners: _miners,
        fishers: _fishers,
        builders: _builders,
        waterTiles: _waterTiles,
      );

      // Hareket yumuşatma — renderX/Y ve moveIntensity.
      // AI'ın gridX/Y sıçramaları animasyona anlık değil, exp-lerp ile
      // yansır → donuk değil akıcı.
      for (final v in _villagers) {
        v.smoothMotion(dt);
      }
      for (final f in _farmers) {
        f.smoothMotion(dt);
      }
      for (final w in _woodcutters) {
        w.smoothMotion(dt);
      }
      for (final m in _miners) {
        m.smoothMotion(dt);
      }
      for (final b in _builders) {
        b.smoothMotion(dt);
      }
      for (final f in _fishers) {
        f.smoothMotion(dt);
      }
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  // ── Ateşten NPC spawn ────────────────────────────────────────────────────

  void _spawnStartingNPCs(BuildingEntity firepit) {
    final cx = firepit.col + 0.5;
    final cy = firepit.row + 0.5;

    // Her NPC ateşin etrafında farklı bir açıdan çıkar
    final types = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    for (int i = 0; i < types.length; i++) {
      final angle = i * (2 * pi / types.length);
      final dist = 1.2 + _rng.nextDouble() * 0.6;
      // Kurucular yetişkin/yaşlı yaşıyla doğar — köy ilk günden işlevsel.
      final founderAge =
          kAdultStartDay + _rng.nextDouble() * (kElderStartDay - kAdultStartDay + 5);
      _villagers.add(
        VillagerEntity(
          type: types[i],
          startCol: cx + cos(angle) * dist,
          startRow: cy + sin(angle) * dist,
          ageDays: founderAge,
          lifespanDays: _rollLifespan(),
        ),
      );
    }

    // 2 inşaatçı
    for (int i = 0; i < 2; i++) {
      final angle = pi / 4 + i * pi;
      _builders.add(
        BuilderEntity(
          startCol: cx + cos(angle) * 1.8,
          startRow: cy + sin(angle) * 1.8,
        ),
      );
    }

    _fixNpcSpawns();
  }

  // ── Gece: uyku hedeflerini ata ───────────────────────────────────────────

  void _assignSleepTargets() {
    int idx = 0;
    for (final v in _villagers) {
      if (v.homeBuilding case final home?) {
        // Eve ata: ev merkezine yürüyüp içeri gir
        final b = home as BuildingEntity;
        final meta = kBuildingMeta[b.type]!;
        v.sleepTarget = (b.col + meta.cols / 2.0, b.row + meta.rows / 2.0);
        v.sleepIsHome = true;
      } else if (_firepitBuilding != null) {
        // Ateş etrafında dağılarak uyu
        final fp = _firepitBuilding!;
        final angle = idx * (2 * pi / _villagers.length);
        final dist = 1.4 + (_rng.nextDouble() * 0.7);
        v.sleepTarget = (
          fp.col + 0.5 + cos(angle) * dist,
          fp.row + 0.5 + sin(angle) * dist,
        );
        v.sleepIsHome = false;
      }
      idx++;
    }
  }

  // ── Nüfus & ev kapasitesi ─────────────────────────────────────────────────

  /// Ev binalarındaki boş sakin kapasitesinin toplamı.
  int _freeHousingSlots() {
    int free = 0;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      final occ = _villagers.where((v) => v.homeBuilding == b).length;
      final slots = f.housingCapacity - occ;
      if (slots > 0) free += slots;
    }
    return free;
  }

  /// Rastgele doğal ömür (oyun günü) — yaşlı evresinden sonra biraz daha yaşar.
  double _rollLifespan() =>
      kElderStartDay + kElderLifeMin +
      _rng.nextDouble() * (kElderLifeMax - kElderLifeMin);

  /// Köyün ev tavanı — tüm evlerin sakin kapasitesi toplamı.
  int _populationCap() {
    int cap = 0;
    for (final b in _buildings) {
      final f = b.fn;
      if (f != null && f.role == BuildingRole.housing) cap += f.housingCapacity;
    }
    return cap;
  }

  /// Belediyenin büyüme döngüsü dolunca yeni köylü doğurur, boş eve yerleştirir.
  void _spawnGrownVillager(BuildingEntity townhall) {
    BuildingEntity? house;
    for (final b in _buildings) {
      final f = b.fn;
      if (f == null || f.role != BuildingRole.housing) continue;
      final occ = _villagers.where((v) => v.homeBuilding == b).length;
      if (occ < f.housingCapacity) {
        house = b;
        break;
      }
    }

    const civilianTypes = [
      VillagerType.farmer,
      VillagerType.merchant,
      VillagerType.blacksmith,
      VillagerType.guard,
      VillagerType.mage,
    ];
    final type = civilianTypes[_rng.nextInt(civilianTypes.length)];
    final (sx, sy) = _nearestLand(
      townhall.col + townhall.cols / 2.0,
      townhall.row + townhall.rows.toDouble(),
    );
    // Bebek olarak doğar (ageDays=0); büyüdükçe mesleğini (type) edinir.
    final v = VillagerEntity(
        type: type, startCol: sx, startRow: sy, lifespanDays: _rollLifespan());
    if (house != null) v.homeBuilding = house;
    _villagers.add(v);
    _showNotification('👶 Köye bir bebek doğdu!');
  }

  // ── Bina tile kontrolü ────────────────────────────────────────────────────

  BuildingEntity? _buildingAt(int col, int row) {
    for (final b in _buildings) {
      if (col >= b.col &&
          col < b.col + b.cols &&
          row >= b.row &&
          row < b.row + b.rows) {
        return b;
      }
    }
    return null;
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  (int, int)? _toTile(Offset pos) {
    // Ekran koordinatını zoom'suz dünya koordinatına dönüştür
    final center = Offset(_viewSize.width / 2, _viewSize.height / 2);
    final adjusted = (pos - center) / _zoom + center;
    final (fc, fr) = screenToGrid(adjusted, _viewSize, _camera);
    final c = fc.floor();
    final r = fr.floor();
    if (c >= 0 && c < kCols && r >= 0 && r < kRows) return (c, r);
    return null;
  }

  bool _isValidPlacement(int col, int row, BuildingType type) {
    final meta = kBuildingMeta[type]!;
    if (col + meta.cols > kCols || row + meta.rows > kRows) return false;
    bool overlaps(
      int c1,
      int r1,
      int w1,
      int h1,
      int c2,
      int r2,
      int w2,
      int h2,
    ) => c1 < c2 + w2 && c1 + w1 > c2 && r1 < r2 + h2 && r1 + h1 > r2;

    final farmSet = {for (final t in _farmTiles) (t.col, t.row)};
    final mineSet = {
      for (final n in _mineNodes)
        if (!n.isDepleted) (n.col, n.row),
    };
    // Canlı ağaç tile'ları — bina footprint'i bunlara çakışamaz.
    final treeSet = {
      for (final t in _trees)
        if (!t.isFelled) (t.col, t.row),
    };

    // ── Maden Ocağı: maden tile'ı üzerine kurulmalı ──────────────────────────
    if (type == BuildingType.mineBuilding) {
      bool hasMine = false;
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return false;
          if (farmSet.contains((c, r))) return false;
          if (treeSet.contains((c, r))) return false;
          if (mineSet.contains((c, r))) hasMine = true;
        }
      }
      if (!hasMine) return false;
    }
    // ── Oduncu Kulübesi: yakında ağaç olmalı (ama üstüne kurulamaz) ─────────
    else if (type == BuildingType.lumberCamp) {
      final cx = col + meta.cols / 2.0;
      final cy = row + meta.rows / 2.0;
      const radius = LumberCampEntity.kTerritoryRadius;
      bool hasTree = false;
      for (final t in _trees) {
        if (t.isFelled) continue;
        final dx = t.col + 0.5 - cx;
        final dy = t.row + 0.5 - cy;
        if (dx * dx + dy * dy <= radius * radius) {
          hasTree = true;
          break;
        }
      }
      if (!hasTree) return false;
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return false;
          if (farmSet.contains((c, r))) return false;
          if (treeSet.contains((c, r))) return false;
          if (mineSet.contains((c, r))) return false;
        }
      }
    }
    // ── Normal binalar ────────────────────────────────────────────────────────
    else {
      for (int c = col; c < col + meta.cols; c++) {
        for (int r = row; r < row + meta.rows; r++) {
          if (_waterTiles.contains((c, r))) return false;
          if (farmSet.contains((c, r))) return false;
          if (treeSet.contains((c, r))) return false;
          if (mineSet.contains((c, r))) return false;
        }
      }
    }

    for (final b in _buildings) {
      if (overlaps(
        col,
        row,
        meta.cols,
        meta.rows,
        b.col,
        b.row,
        b.cols,
        b.rows,
      )) {
        return false;
      }
    }
    for (final o in _orders) {
      final om = kBuildingMeta[o.type]!;
      if (overlaps(
        col,
        row,
        meta.cols,
        meta.rows,
        o.col,
        o.row,
        om.cols,
        om.rows,
      )) {
        return false;
      }
    }
    return true;
  }

  /// İnşaat tamamlandığında çalışır — bina tipine özel aksiyonlar.
  void _onBuildingCompleted(BuildOrder o) {
    // Tamamlanan binayı listeden bul (yeni eklendi)
    final building = _buildings.firstWhere(
      (b) => b.col == o.col && b.row == o.row && b.type == o.type,
      orElse: () => BuildingEntity(type: o.type, col: o.col, row: o.row),
    );

    switch (o.type) {
      case BuildingType.firepit:
        _hasFire = true;
        _firepitBuilding = building;
        _spawnStartingNPCs(building);
        _showNotification('Ateş yakıldı! Köy kurulmaya başlıyor...');

      case BuildingType.woodenHouse:
        // Evsiz köylüleri bu eve ata (max 2)
        int assigned = 0;
        for (final v in _villagers) {
          if (assigned >= 2) break;
          if (v.homeBuilding == null) {
            v.homeBuilding = building;
            assigned++;
          }
        }
        if (assigned > 0) {
          _showNotification('$assigned köylü eve taşındı.');
        }

      case BuildingType.lumberCamp:
        _lumberCamps.add(
          LumberCampEntity(buildingCol: o.col, buildingRow: o.row),
        );

      case BuildingType.mineBuilding:
        // Footprint içindeki maden node'larını otomatik işaretle
        final meta = kBuildingMeta[o.type]!;
        for (final n in _mineNodes) {
          if (n.col >= o.col &&
              n.col < o.col + meta.cols &&
              n.row >= o.row &&
              n.row < o.row + meta.rows) {
            n.isMarkedForMining = true;
          }
        }
        // Binaya özel madenci oluştur
        _miners.add(
          MinerEntity(
            startCol: o.col + meta.cols / 2.0,
            startRow: o.row + meta.rows / 2.0,
          ),
        );

      case BuildingType.fisherCabin:
        // Balıkçı kulübesi tamamlandığında balıkçı ekle
        _fishers.add(
          FisherEntity(startCol: o.col + 1.0, startRow: o.row + 1.0),
        );

      default:
        break;
    }
  }

  void _generateWorld({int? forceSeed}) {
    _worldSeed = forceSeed ?? Random().nextInt(0x7FFFFFFF);
    final result = WorldGenerator(_worldSeed).generate();

    _waterTiles.clear();
    _lotuses.clear();
    _reeds.clear();
    _trees.clear();
    _mineNodes.clear();
    _buildings.clear();
    _orders.clear();
    _lumberCamps.clear();
    _miners.clear();
    _fishers.clear();
    _farmers.clear();
    _woodcutters.clear();
    _builders.clear();
    _villagers.clear();
    _resourceBoxes.clear();
    _hayEntities.clear();

    _stockpile.clear();
    _hasFire = false;
    _firepitBuilding = null;
    _selectedBuilding = null;

    // Köylülerin ev/uyku atamalarını sıfırla
    for (final v in _villagers) {
      v.homeBuilding = null;
      v.sleepTarget = null;
      v.sleepIsHome = false;
      v.isInsideBuilding = false;
    }

    _waterTiles.addAll(result.waterTiles);
    _lotuses.addAll(result.lotuses);
    _reeds.addAll(result.reeds);
    _trees.addAll(result.trees);
    _mineNodes.addAll(result.mineNodes);

    _fixNpcSpawns();
  }

  /// Su üzerindeki tüm entity'leri en yakın kuru tile'a taşır.
  void _fixNpcSpawns() {
    void fix(double gx, double gy, void Function(double, double) set) {
      final (nx, ny) = _nearestLand(gx, gy);
      if (nx != gx || ny != gy) set(nx, ny);
    }

    for (final v in _villagers) {
      fix(v.gridX, v.gridY, (x, y) {
        v.gridX = x;
        v.gridY = y;
      });
    }
    for (final f in _farmers) {
      fix(f.gridX, f.gridY, (x, y) {
        f.gridX = x;
        f.gridY = y;
      });
    }
    for (final w in _woodcutters) {
      fix(w.gridX, w.gridY, (x, y) {
        w.gridX = x;
        w.gridY = y;
      });
    }
    for (final m in _miners) {
      fix(m.gridX, m.gridY, (x, y) {
        m.gridX = x;
        m.gridY = y;
      });
    }
    for (final b in _builders) {
      fix(b.gridX, b.gridY, (x, y) {
        b.gridX = x;
        b.gridY = y;
      });
    }
    for (final f in _fishers) {
      fix(f.gridX, f.gridY, (x, y) {
        f.gridX = x;
        f.gridY = y;
      });
    }
  }

  /// Verilen pozisyona en yakın su-olmayan tile'ı spiral aramayla bulur.
  (double, double) _nearestLand(double gx, double gy) {
    final c0 = gx.round();
    final r0 = gy.round();
    if (!_waterTiles.contains((c0, r0))) return (gx, gy);
    for (int radius = 1; radius < 12; radius++) {
      for (int dc = -radius; dc <= radius; dc++) {
        for (int dr = -radius; dr <= radius; dr++) {
          if (dc.abs() != radius && dr.abs() != radius) {
            continue; // sadece dış halka
          }
          final nc = (c0 + dc).clamp(0, kCols - 1);
          final nr = (r0 + dr).clamp(0, kRows - 1);
          if (!_waterTiles.contains((nc, nr))) {
            return (nc.toDouble(), nr.toDouble());
          }
        }
      }
    }
    return (gx, gy); // fallback (olmamalı)
  }

  void _commitMine((int, int) start, (int, int) end) {
    final c1 = start.$1 < end.$1 ? start.$1 : end.$1;
    final c2 = start.$1 < end.$1 ? end.$1 : start.$1;
    final r1 = start.$2 < end.$2 ? start.$2 : end.$2;
    final r2 = start.$2 < end.$2 ? end.$2 : start.$2;
    int marked = 0;
    setState(() {
      for (final n in _mineNodes) {
        if (n.col >= c1 && n.col <= c2 && n.row >= r1 && n.row <= r2) {
          if (!n.isMarkedForMining && !n.isDepleted) {
            n.isMarkedForMining = true;
            marked++;
          }
        }
      }
      _mineMode = false;
      _mineStart = null;
      _mineEnd = null;
    });
    if (marked > 0) {
      _showNotification('$marked maden işaretlendi!');
    } else {
      _showNotification('Seçilen alanda maden yok.');
    }
  }

  void _commitLumber((int, int) start, (int, int) end) {
    final c1 = start.$1 < end.$1 ? start.$1 : end.$1;
    final c2 = start.$1 < end.$1 ? end.$1 : start.$1;
    final r1 = start.$2 < end.$2 ? start.$2 : end.$2;
    final r2 = start.$2 < end.$2 ? end.$2 : start.$2;
    int marked = 0;
    setState(() {
      for (final t in _trees) {
        if (t.col >= c1 && t.col <= c2 && t.row >= r1 && t.row <= r2) {
          if (!t.isMarkedForCutting && !t.isFelled) {
            t.isMarkedForCutting = true;
            marked++;
          }
        }
      }
      _lumberMode = false;
      _lumberStart = null;
      _lumberEnd = null;
    });
    if (marked > 0) {
      _showNotification('$marked ağaç kesilmek üzere işaretlendi!');
    } else {
      _showNotification('Seçilen alanda işaretlenecek ağaç yok.');
    }
  }

  void _commitFarm((int, int) start, (int, int) end) {
    final c1 = start.$1 < end.$1 ? start.$1 : end.$1;
    final c2 = start.$1 < end.$1 ? end.$1 : start.$1;
    final r1 = start.$2 < end.$2 ? start.$2 : end.$2;
    final r2 = start.$2 < end.$2 ? end.$2 : start.$2;
    final existing = {for (final t in _farmTiles) (t.col, t.row)};
    setState(() {
      for (int c = c1; c <= c2; c++) {
        for (int r = r1; r <= r2; r++) {
          if (!existing.contains((c, r)) && !_waterTiles.contains((c, r))) {
            _farmTiles.add(FarmTile(c, r));
          }
        }
      }
      // Her 6 tarla tile'ı için 1 çiftçi — eksik olanları spawn et
      final needed = (_farmTiles.length / 6).ceil().clamp(1, 4);
      final centerC = (c1 + c2) / 2.0;
      final centerR = (r1 + r2) / 2.0;
      while (_farmers.length < needed) {
        final angle = _rng.nextDouble() * 2 * pi;
        _farmers.add(
          FarmFarmer(
            startCol: centerC + cos(angle) * 1.5,
            startRow: centerR + sin(angle) * 1.5,
          ),
        );
      }
      _farmMode = false;
      _farmStart = null;
      _farmEnd = null;
    });
  }

  void _tryPlace(Offset pos) {
    if (_placing == null) return;
    final tile = _toTile(pos);
    if (tile == null) return;
    final (c, r) = tile;
    if (!_isValidPlacement(c, r, _placing!)) {
      _showNotification('Bu alana inşa edilemiyor!');
      return;
    }
    final cost = kBuildingMeta[_placing!]!.cost;
    if (!_stockpile.canAfford(cost)) {
      _showNotification('Eksik malzeme: ${_stockpile.formatMissing(cost)}');
      return;
    }
    final isFirepit = _placing == BuildingType.firepit;
    setState(() {
      _stockpile.spend(cost);

      // Ateş yeri inşaatçısız anında kurulur — NPC'ler buradan doğar
      if (isFirepit) {
        final b = BuildingEntity(type: BuildingType.firepit, col: c, row: r);
        _buildings.add(b);
        _onBuildingCompleted(
          BuildOrder(type: BuildingType.firepit, col: c, row: r)
            ..completed = true,
        );
      } else {
        _orders.add(BuildOrder(type: _placing!, col: c, row: r));
      }

      _placing = null;
      _ghost = null;
    });
    _showNotification(isFirepit ? 'Ateş yakıldı!' : 'İnşaatçı yola çıkıyor...');
  }

  void _showNotification(String msg) {
    final id = ++_notifId;
    setState(() => _notification = msg);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted && _notifId == id) setState(() => _notification = null);
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (!_assetsLoaded) {
      return LoadingScreen(onCancel: widget.onExitToMenu);
    }
    final screen = MediaQuery.of(context).size;

    // ── Güneş / Ay ark hesabı ─────────────────────────────────────────────
    // Sağ ufuktan (timeOfDay=0.25) tepeye (0.50) sol ufuka (0.75) yarım daire
    const kSunSize = 32.0;
    const kMoonSize = 24.0;
    final arcCx = screen.width / 2;
    final arcBy = screen.height * 0.50; // yatay ufuk seviyesi
    final arcR = screen.width * 0.42; // yarıçap

    // Güneş — timeOfDay 0.25→sağ ufuk  0.50→tepe  0.75→sol ufuk
    final sunNorm = ((_cycle.timeOfDay - 0.25) / 0.50).clamp(0.0, 1.0);
    final sunAngle = pi * sunNorm; // 0..π
    final sunX = arcCx + arcR * cos(sunAngle) - kSunSize / 2;
    final sunY = arcBy - arcR * sin(sunAngle) - kSunSize / 2;

    // Ay — güneşin tam karşı tarafında (0.5 offset)
    final moonT = (_cycle.timeOfDay + 0.5) % 1.0;
    final moonNorm = ((moonT - 0.25) / 0.50).clamp(0.0, 1.0);
    final moonAngle = pi * moonNorm;
    final moonX = arcCx + arcR * cos(moonAngle) - kMoonSize / 2;
    final moonY = arcBy - arcR * sin(moonAngle) - kMoonSize / 2;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExitToMenu?.call();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A3060),
        body: Stack(
          children: [
            // Gökyüzü
            PixelSky(topColor: _cycle.skyTop, midColor: _cycle.skyMid),

            // Yıldızlar
            Positioned.fill(
              child: StarField(opacity: _cycle.starOpacity, time: _time),
            ),

            // Güneş — ark boyunca hareket eder
            Positioned(
              left: sunX,
              top: sunY,
              child: Opacity(
                opacity: _cycle.sunOpacity,
                child: PixelSun(color: _cycle.sunColor),
              ),
            ),

            // Ay — güneşin peşinden, zıt tarafta (ışık hâlesi ile)
            Positioned(
              left: moonX - 58,
              top: moonY - 58,
              child: Opacity(
                opacity: _cycle.moonOpacity,
                child: SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Dış ışık hâlesi
                      Container(
                        width: 140,
                        height: 140,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x30C8E8FF), Color(0x00C8E8FF)],
                          ),
                        ),
                      ),
                      // İç parlama
                      Container(
                        width: 60,
                        height: 60,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0x55DDEEFF), Color(0x00DDEEFF)],
                          ),
                        ),
                      ),
                      const PixelMoon(),
                    ],
                  ),
                ),
              ),
            ),

            // Bulutlar — 3 katman parallax (uzak/orta/yakın).  Uzak: yavaş+
            // küçük+soluk, yakın: hızlı+büyük+doygun. Toplam 9 bulut —
            // atmospheric perspective ile derinlik hissi.
            Builder(
              builder: (ctx) {
                final w    = MediaQuery.of(ctx).size.width;
                final wrap = w + 240.0;
                // (baseX_rel, y, scale, speed, parallax, rainAlphaThresh)
                const clouds = <(double, double, double, double, double, double)>[
                  // Uzak katman — yavaş, küçük, soluk
                  (0.08, 22.0,  0.55, 2.5, 0.30, 0.50),
                  (0.40, 14.0,  0.60, 2.8, 0.35, 0.40),
                  (0.76, 32.0,  0.50, 2.2, 0.28, 0.50),
                  // Orta katman
                  (0.18, 58.0,  0.85, 5.0, 0.65, 0.35),
                  (0.55, 48.0,  0.95, 5.5, 0.70, 0.30),
                  (0.88, 68.0,  0.75, 4.5, 0.60, 0.45),
                  // Yakın katman — hızlı, büyük, doygun
                  (0.04, 96.0,  1.30, 9.0, 1.00, 0.25),
                  (0.38, 116.0, 1.45, 9.5, 1.00, 0.20),
                  (0.72, 88.0,  1.20, 8.5, 1.00, 0.30),
                ];
                return Stack(
                  children: [
                    for (final cfg in clouds)
                      Positioned(
                        left: ((cfg.$1 * w) + (_time * cfg.$4)) % wrap - 120,
                        top:  cfg.$2,
                        child: Opacity(
                          opacity: _cycle.cloudOpacity,
                          child: PixelCloud(
                            dark:     _cycle.rainIntensity > cfg.$6,
                            scale:    cfg.$3,
                            parallax: cfg.$5,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),

            // Game canvas
            Positioned.fill(
              child: LayoutBuilder(
                builder: (ctx, constraints) {
                  _viewSize = constraints.biggest;
                  return Listener(
                    // ── Fare tekerleği ile zoom ───────────────────────────────────
                    onPointerSignal: (event) {
                      if (event is PointerScrollEvent) {
                        final delta = event.scrollDelta.dy;
                        final factor = (1.0 - delta * 0.0012).clamp(0.80, 1.25);
                        final newZoom = (_zoom * factor).clamp(0.20, 4.0);
                        final center = Offset(
                          _viewSize.width / 2,
                          _viewSize.height / 2,
                        );
                        final focal = event.localPosition - center;
                        setState(() {
                          _camera = _camera + focal * (1 / newZoom - 1 / _zoom);
                          _zoom = newZoom;
                        });
                      }
                    },
                    child: GestureDetector(
                      onScaleStart: (d) {
                        _scaleStart = _zoom;
                        _panAnchor = d.localFocalPoint;
                        _cameraAnchor = _camera;
                        if (_mineMode) {
                          final tile = _toTile(d.localFocalPoint);
                          setState(() {
                            _mineStart = tile;
                            _mineEnd = tile;
                          });
                        } else if (_lumberMode) {
                          final tile = _toTile(d.localFocalPoint);
                          setState(() {
                            _lumberStart = tile;
                            _lumberEnd = tile;
                          });
                        } else if (_farmMode) {
                          final tile = _toTile(d.localFocalPoint);
                          setState(() {
                            _farmStart = tile;
                            _farmEnd = tile;
                          });
                        }
                      },
                      onScaleUpdate: (d) {
                        if (_mineMode || _lumberMode || _farmMode) {
                          // Seçim modlarında sürükleme; zoom yok
                          final tile = _toTile(d.localFocalPoint);
                          setState(() {
                            if (_mineMode && tile != _mineEnd) _mineEnd = tile;
                            if (_lumberMode && tile != _lumberEnd) {
                              _lumberEnd = tile;
                            }
                            if (_farmMode && tile != _farmEnd) _farmEnd = tile;
                          });
                        } else if (_placing != null) {
                          // Bina yerleştirme modunda ghost güncelle
                          final tile = _toTile(d.localFocalPoint);
                          if (tile != _ghost) setState(() => _ghost = tile);
                        } else {
                          // Serbest mod: kaydır + zoom (focal noktaya doğru)
                          final newZoom = (_scaleStart * d.scale).clamp(
                            0.20,
                            4.0,
                          );
                          final center = Offset(
                            _viewSize.width / 2,
                            _viewSize.height / 2,
                          );
                          final focal = _panAnchor! - center;
                          setState(() {
                            _zoom = newZoom;
                            _camera =
                                _cameraAnchor! +
                                (d.localFocalPoint - _panAnchor!) +
                                focal * (1 / newZoom - 1 / _scaleStart);
                          });
                        }
                      },
                      onScaleEnd: (_) {
                        if (_mineMode &&
                            _mineStart != null &&
                            _mineEnd != null) {
                          _commitMine(_mineStart!, _mineEnd!);
                        } else if (_lumberMode &&
                            _lumberStart != null &&
                            _lumberEnd != null) {
                          _commitLumber(_lumberStart!, _lumberEnd!);
                        } else if (_farmMode &&
                            _farmStart != null &&
                            _farmEnd != null) {
                          _commitFarm(_farmStart!, _farmEnd!);
                          setState(() {
                            _farmStart = null;
                            _farmEnd = null;
                          });
                        }
                      },
                      onTapUp: (d) {
                        if (_mineMode) {
                          final tile = _toTile(d.localPosition);
                          if (tile != null) _commitMine(tile, tile);
                        } else if (_lumberMode) {
                          final tile = _toTile(d.localPosition);
                          if (tile != null) _commitLumber(tile, tile);
                        } else if (_farmMode) {
                          final tile = _toTile(d.localPosition);
                          if (tile != null) _commitFarm(tile, tile);
                          setState(() {
                            _farmStart = null;
                            _farmEnd = null;
                          });
                        } else if (_placing != null) {
                          _tryPlace(d.localPosition);
                        } else {
                          // Bina seçimi
                          final tile = _toTile(d.localPosition);
                          if (tile != null) {
                            final b = _buildingAt(tile.$1, tile.$2);
                            setState(() => _selectedBuilding = b);
                          } else {
                            setState(() => _selectedBuilding = null);
                          }
                        }
                      },
                      child: MouseRegion(
                        onHover: (e) {
                          if (_placing != null) {
                            final tile = _toTile(e.localPosition);
                            if (tile != _ghost) setState(() => _ghost = tile);
                          }
                        },
                        child: CustomPaint(
                          painter: VillageGamePainter(
                            villagers: _villagers,
                            buildings: _buildings,
                            builders: _builders,
                            pendingOrders: _orders,
                            camera: _camera,
                            ghostType: _placing,
                            ghostTile: _ghost,
                            ghostValid: _ghost != null && _placing != null
                                ? _isValidPlacement(
                                    _ghost!.$1,
                                    _ghost!.$2,
                                    _placing!,
                                  )
                                : false,
                            time: _time,
                            sceneOverlay: _cycle.sceneOverlay,
                            rainIntensity: _cycle.rainIntensity,
                            farmTiles: _farmTiles,
                            farmers: _farmers,
                            farmSelection:
                                (_farmMode &&
                                    _farmStart != null &&
                                    _farmEnd != null)
                                ? (
                                    _farmStart!.$1,
                                    _farmStart!.$2,
                                    _farmEnd!.$1,
                                    _farmEnd!.$2,
                                  )
                                : null,
                            trees: _trees,
                            woodcutters: _woodcutters,
                            lumberSelection:
                                (_lumberMode &&
                                    _lumberStart != null &&
                                    _lumberEnd != null)
                                ? (
                                    _lumberStart!.$1,
                                    _lumberStart!.$2,
                                    _lumberEnd!.$1,
                                    _lumberEnd!.$2,
                                  )
                                : null,
                            mineNodes: _mineNodes,
                            miners: _miners,
                            mineSelection:
                                (_mineMode &&
                                    _mineStart != null &&
                                    _mineEnd != null)
                                ? (
                                    _mineStart!.$1,
                                    _mineStart!.$2,
                                    _mineEnd!.$1,
                                    _mineEnd!.$2,
                                  )
                                : null,
                            waterTiles: _waterTiles,
                            dayLight: _cycle.dayLight,
                            lotuses: _lotuses,
                            reeds: _reeds,
                            fishers: _fishers,
                            zoom: _zoom,
                            resourceBoxes: _resourceBoxes,
                            hayEntities: _hayEntities,
                            skyReflection: _cycle.skyMid,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // HUD
            GameHUD(
              stockpile: _stockpile,
              woodInTransit: _resourceBoxes
                  .where(
                    (b) =>
                        b.type == ResourceBoxType.woodChunk && !b.isDelivered,
                  )
                  .length,
              stoneInTransit: _resourceBoxes
                  .where(
                    (b) => b.type == ResourceBoxType.stoneBox && !b.isDelivered,
                  )
                  .length,
              ironInTransit: _resourceBoxes
                  .where(
                    (b) => b.type == ResourceBoxType.ironBox && !b.isDelivered,
                  )
                  .length,
              coalInTransit: _resourceBoxes
                  .where(
                    (b) => b.type == ResourceBoxType.coalBox && !b.isDelivered,
                  )
                  .length,
              foodInTransit: _hayEntities
                  .where((h) => h.isBale && !h.isDelivered)
                  .length,
              villagerCount: _villagers.length,
              farmerCount: _farmers.length,
              woodcutterCount: _woodcutters.length,
              minerCount: _miners.length,
              fisherCount: _fishers.length,
              builderCount: _builders.length,
              busyBuilders: _builders
                  .where((b) => b.state != BuilderState.idle)
                  .length,
              timeOfDay: _cycle.timeOfDay,
              rainIntensity: _cycle.rainIntensity,
              dayLight: _cycle.dayLight,
              buildingCount: _buildings.length,
              pendingOrderCount: _orders.where((o) => !o.completed).length,
              morale: _stats.morale,
              lowWater: _buildings.any((b) =>
                  b.fn?.role == BuildingRole.housing &&
                  b.occupants > 0 &&
                  b.waterLevel < 0.3),
              starving: !_godMode && _stockpile.food < kStarveRampFood,
              onNewMap: () => setState(() => _generateWorld()),
            ),

            // God mode toggle — sağ üst köşe
            Positioned(
              top: 10,
              right: 10,
              child: GestureDetector(
                onTap: () => setState(() => _godMode = !_godMode),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: MedievalTheme.buttonDecoration(
                    active: _godMode,
                    accentColor: const Color(0xFFFFAA00),
                  ),
                  child: Text(
                    _godMode ? '⚡ GOD' : '⚡',
                    style: TextStyle(
                      color: _godMode
                          ? MedievalTheme.textAccent
                          : MedievalTheme.textDim,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    ),
                  ),
                ),
              ),
            ),

            // Bina seçim paneli (alt) — yalnızca gerçek binalar gösterilir
            if (kBuildingMeta.isNotEmpty)
              Positioned(
                bottom: 14,
                left: 0,
                right: 0,
                child: Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      BuildingPanel(
                        stockpile: _stockpile,
                        selected: _placing,
                        hasFirepit: _hasFire,
                        onSelect: (type) => setState(() {
                          _farmMode = false;
                          if (_placing == type) {
                            _placing = null;
                            _ghost = null;
                          } else {
                            _placing = type;
                            _ghost = null;
                          }
                        }),
                      ),
                      const SizedBox(width: 6),
                      // Tarla modu butonu
                      ModeButton(
                        icon: '🌾',
                        label: 'Tarla',
                        active: _farmMode,
                        accentColor: const Color(0xFF88CC22),
                        onTap: () => setState(() {
                          _placing = null;
                          _ghost = null;
                          _lumberMode = false;
                          _lumberStart = null;
                          _lumberEnd = null;
                          _mineMode = false;
                          _mineStart = null;
                          _mineEnd = null;
                          _farmMode = !_farmMode;
                          _farmStart = null;
                          _farmEnd = null;
                        }),
                      ),
                      const SizedBox(width: 4),
                      ModeButton(
                        icon: '🪓',
                        label: 'Kes',
                        active: _lumberMode,
                        accentColor: const Color(0xFFCC6600),
                        onTap: () => setState(() {
                          _placing = null;
                          _ghost = null;
                          _farmMode = false;
                          _farmStart = null;
                          _farmEnd = null;
                          _mineMode = false;
                          _mineStart = null;
                          _mineEnd = null;
                          _lumberMode = !_lumberMode;
                          _lumberStart = null;
                          _lumberEnd = null;
                        }),
                      ),
                      const SizedBox(width: 4),
                      ModeButton(
                        icon: '⛏',
                        label: 'Kaz',
                        active: _mineMode,
                        accentColor: const Color(0xFF8888CC),
                        onTap: () => setState(() {
                          _placing = null;
                          _ghost = null;
                          _farmMode = false;
                          _farmStart = null;
                          _farmEnd = null;
                          _lumberMode = false;
                          _lumberStart = null;
                          _lumberEnd = null;
                          _mineMode = !_mineMode;
                          _mineStart = null;
                          _mineEnd = null;
                        }),
                      ),
                    ],
                  ),
                ),
              ),

            // Bina bilgi paneli
            if (_selectedBuilding != null)
              Positioned(
                bottom: 120,
                left: 14,
                child: BuildingInfoPanel(
                  building: _selectedBuilding!,
                  residents: _villagers
                      .where((v) => v.homeBuilding == _selectedBuilding)
                      .toList(),
                  activeMiners: _miners.where((m) {
                    final b = _selectedBuilding!;
                    return m.isMining &&
                        m.gridX >= b.col - 0.5 &&
                        m.gridX < b.col + b.cols + 0.5 &&
                        m.gridY >= b.row - 0.5 &&
                        m.gridY < b.row + b.rows + 0.5;
                  }).toList(),
                  stockpile: _stockpile,
                  stats: _stats,
                  population: _villagers.length,
                  populationCap: _populationCap(),
                  onClose: () => setState(() => _selectedBuilding = null),
                  onSell: (kind) =>
                      setState(() => sellAtMarket(_stockpile, kind)),
                ),
              ),

            // Bildirim
            if (_notification != null)
              Positioned(
                top: 70,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 7,
                    ),
                    decoration: MedievalTheme.panelDecoration(),
                    child: Text(
                      _notification!,
                      style: const TextStyle(
                        color: MedievalTheme.textAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),

            // Yerleştirme ipucu
            if (_placing != null || _farmMode || _lumberMode || _mineMode)
              Positioned(
                top: 52,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    color: _mineMode
                        ? const Color(0xEE0A0A2A)
                        : _lumberMode
                        ? const Color(0xEE2A1A00)
                        : const Color(0xEE1A3A1A),
                    child: Text(
                      _mineMode
                          ? 'Madenci — sürükle seç, madenleri işaretle'
                          : _lumberMode
                          ? 'Oduncu — sürükle seç, bırak ağaçları işaretle'
                          : _farmMode
                          ? 'Tarla — sürükle seç, bırak onayla'
                          : '${kBuildingMeta[_placing!]!.label} — haritaya tıkla',
                      style: TextStyle(
                        color: _mineMode
                            ? const Color(0xFFAABBFF)
                            : _lumberMode
                            ? const Color(0xFFFFAA44)
                            : const Color(0xFF88FF88),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
