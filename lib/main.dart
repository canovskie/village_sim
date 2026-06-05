import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'characters/villager_type.dart';
import 'characters/villager_names.dart';
import 'entities/villager_entity.dart';
import 'entities/builder_entity.dart';
import 'entities/build_order.dart';
import 'entities/road_order.dart';
import 'entities/worker_entity.dart';
import 'systems/path_context.dart';
import 'systems/road_system.dart';
import 'world/road_surface.dart';
import 'rendering/game_painter.dart';
import 'rendering/flame_renderer.dart';
import 'rendering/smoke_renderer.dart';
import 'rendering/water_shimmer_renderer.dart';
import 'core/constants.dart';
import 'buildings/building_entity.dart';
import 'buildings/building_renderer.dart';
import 'rendering/tile_renderer.dart';
import 'rendering/road_renderer.dart';
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
import 'entities/shepherd_entity.dart';
import 'world/animal_entity.dart';
import 'rendering/tool_renderer.dart';
import 'world/nature_entity.dart';
import 'rendering/nature_renderer.dart';
import 'world/world_generator.dart';
import 'buildings/building_type.dart';
import 'ui/hud.dart';
import 'ui/building_panel.dart';
import 'ui/road_panel.dart';
import 'ui/building_info_panel.dart';
import 'ui/villager_info_panel.dart';
import 'ui/event_banner.dart';
import 'ui/event_choice_modal.dart';
import 'ui/dev_panel.dart';
import 'ui/objective_panel.dart';
import 'systems/objective_tracker.dart';
import 'ui/sky_widgets.dart';
import 'ui/loading_screen.dart';
import 'ui/mode_button.dart';
import 'world/resource_box.dart';
import 'world/resource_placement.dart';
import 'world/hay_entity.dart';
import 'rendering/resource_renderer.dart';
import 'core/resources.dart';
import 'ui/game_theme.dart';
import 'ui/main_menu_screen.dart';
import 'systems/separation_system.dart';
import 'systems/anchor_system.dart';
import 'systems/hay_processor.dart';
import 'systems/carrier_system.dart';
import 'systems/building_system.dart';
import 'systems/event_system.dart';
import 'systems/lighting_system.dart';
import 'buildings/building_function.dart';
import 'characters/life_stage.dart';
import 'scene/scene_data.dart';

part 'scene/scene_scenarios.dart';
part 'scene/scene_npc_activity.dart';
part 'scene/scene_events.dart';
part 'scene/scene_placement.dart';
part 'scene/scene_building_spawn.dart';

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
  // ── part-of yardımcısı: setState @protected olduğundan extension'lardan
  // doğrudan çağrılamıyor. Bu wrapper sayesinde scene_*.dart part dosyaları
  // setStateHere(() {...}) ile state mutate edebilir.
  void setStateHere(VoidCallback fn) => setState(fn);

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

  // ── Yol sistemi ────────────────────────────────────────────────────────────
  // _roadSystem tamamlanmış yolları tutar (autotile + hız çarpanı kaynağı).
  // _roadOrders builder kuyruğu — completed olunca _roadSystem'e geçer.
  // _placingRoad set ise tap+drag ile döşeme modu aktif.
  // _roadStrokeTiles drag boyunca aynı tile'a iki kez order düşmesini engeller.
  final RoadSystem _roadSystem = RoadSystem();
  final List<RoadOrder> _roadOrders = [];
  RoadSurface? _placingRoad;
  final Set<(int, int)> _roadStrokeTiles = {};

  // A* pathfinding context — roadSystem + blockedTiles ref + version sayacı.
  // World topology değişince (yeni bina/yol, maden tükenme) version bump'lanır
  // ve NPC'ler cached path'i invalidate eder.
  late final PathContext _pathContext = PathContext(roadSystem: _roadSystem);
  // Sosyal noktalardaki (kuyu vd.) rezerve edilebilir slot'ları yöneten otorite.
  // Topology değişince (yeni/silinmiş bina) rebuild edilir, runtime claim/release
  // sırasında dokunulmaz — aksi halde aktif rezervasyonlar reset olur.
  final AnchorSystem _anchorSystem = AnchorSystem();

  // ── Firepit & home sistemi ─────────────────────────────────────────────────
  bool _hasFire = false;
  BuildingEntity? _firepitBuilding;
  BuildingEntity? _selectedBuilding;
  VillagerEntity? _selectedVillager;

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

  // ── Ağıl: çobanlar + inekler ──────────────────────────────────────────────
  final List<ShepherdEntity> _shepherds = [];
  final List<AnimalEntity> _cows = [];

  // ── Resources ─────────────────────────────────────────────────────────────
  final List<ResourceBox> _resourceBoxes = [];
  final List<HayEntity> _hayEntities = [];
  double _carrierTimer = 0.0;

  /// Nüfus yiyecek tüketimi için kesirli birikim (≥1 olunca stoktan düşülür).
  double _foodHunger = 0.0;

  // Gün sayacı — timeOfDay 1.0'ı geçip sardığında artar.
  int _dayCount = 1;
  double _lastTimeOfDay = 0.0;

  // ── Spatial cache (her frame yeniden kurulmaz; kSpatialRebuildInterval) ──────
  // Engel/yumuşak-engel/kuyu/yasak set'leri yavaş değişir; throttle'lı yenilenir.
  final Set<(int, int)> _obstacles = {};
  final Set<(int, int)> _softObs = {};
  // 1-tile genişlikte engel koridorları (karşılıklı komşuları blocked).
  // PathContext bu tile'ları yüksek cost'la pahalı yapar → A* mümkünse
  // etrafından dolaşır. Block DEĞİL: tek geçit oraysa NPC yine geçer.
  final Set<(int, int)> _squeezeTiles = {};
  final Set<(int, int)> _forbiddenForTrees = {};
  double _spatialTimer = 0.0;

  // HUD için "yolda" kaynak sayımları — her frame tek geçişte hesaplanır
  // (build içinde 5 ayrı .where().length yerine).
  int _woodInTransit = 0,
      _stoneInTransit = 0,
      _ironInTransit = 0,
      _coalInTransit = 0,
      _foodInTransit = 0;

  // ── Rastgele olaylar ───────────────────────────────────────────────────────
  double _eventTimer = kEventFirstDelay; // bir sonraki olaya kalan süre
  double _eventMorale = 0.0; // aktif geçici moral etkisi (+/−)
  double _eventMoraleLeft = 0.0; // o etkinin kalan süresi (sn)
  String? _eventLabel; // aktif geçici olayın HUD etiketi
  // Pop-up event banner — son tetiklenen olay; ekran ortasında zengin kart.
  EventOutcome? _activeEvent;
  double _activeEventLeft = 0.0;

  // Karar bekleyen olay — modal açıkken `_pendingChoice != null`. Tick'te
  // simülasyon dt = 0 (oyun donar), oyuncu seçince serbest kalır.
  EventOutcome? _pendingChoice;

  // Geliştirici test paneli açık mı.
  bool _devPanelOpen = false;

  // Hedef listesi paneli daraltılmış mı (oyuncu küçültebilir).
  bool _objectivesCollapsed = false;
  // Hangi hedefler önceden tamamlanmıştı — yeni tamamlanan için bildirim.
  final Set<String> _completedObjectives = {};

  // Sosyal canlılık — bağlama duyarlı, dağıtık yoğunluk.
  // Her NPC kendi cooldown'unda bağımsız değerlendirilir; global cap yok.
  // Bağlam çarpanları (pazar/taverna/ateş/gece/yağmur) per-NPC ihtimalini
  // ayarlar → nüfus arttıkça doğal olarak köy daha canlı olur, dağıtık
  // bölgeler sessiz kalır.
  double _socialScanTimer = 0;
  static const double _kSocialScanInterval =
      3.0; // her NPC için 3 sn'de bir bak
  static const List<String> _kChatIcons = [
    '💬',
    '🍞',
    '🌾',
    '⚒',
    '😊',
    '❓',
    '☀',
    '✨',
    '🪵',
    '🪙',
  ];
  static const List<String> _kPlayIcons = ['⚽', '🪁', '🎈', '🐈', '🪀'];

  // Dev: simülasyon hız boost'u. Normal _timeScale ile çarpılır. 1.0 = normal,
  // 30.0 = hızlı denge testi. DevPanel slider'ı set eder.
  double _devSpeedBoost = 1.0;

  // Dev: 5 sn'de bir kaynak/nüfus snapshot — denge analizi için. Son 30
  // snapshot tutulur, grafik/tablo gösterilir.
  final List<SimSnapshot> _simHistory = [];
  double _simSnapshotTimer = 0;
  static const int _kMaxSnapshots = 30;
  static const double _kSnapshotInterval = 5.0;

  // Otomatik senaryo testi durumu.
  String? _scenarioName; // çalışan senaryonun adı (null = pasif)
  double _scenarioProgress = 0;
  ScenarioReport? _lastReport;

  // Aktif sahne efektleri — banner'dan bağımsız, sahnede partikül/overlay
  // çizen ve simülasyona multiplier uygulayan etkiler. Bir tick'te aşağıdaki
  // alanlara aggregate edilir.
  final List<ActiveFx> _activeFx = [];
  // Aggregate cache (her tick yenilenir):
  Color _fxTint = const Color(0x00000000); // ekran üstüne overlay
  double _fxRainBoost = 0.0; // min rain intensity zorlaması
  double _fxNpcSpeedMul = 1.0; // NPC hız çarpanı
  double _fxFarmMul = 1.0; // tarla büyüme çarpanı
  double _fxBuilderMul = 1.0; // inşaatçı çarpanı
  final Set<EventFx> _fxActiveIds = {}; // hangi fx'ler aktif (render için)

  // fireOutbreak fx aktifken yanan spesifik bina(lar). Event tetiklendiğinde
  // rastgele konut/işyeri seçilir, fx süresince işaretli kalır. Painter
  // sprite'ın üstüne alev + yoğun duman çizer.
  final Set<BuildingEntity> _burningBuildings = {};

  // ── God mode ───────────────────────────────────────────────────────────────
  bool _godMode = false;

  // ── Zaman yönetimi ─────────────────────────────────────────────────────────
  // Simülasyon hızı çarpanı. 0.0 = duraklatılmış (sahne animasyonları da
  // donar, sadece UI canlı kalır), 1×/2×/4× hızlandırma. HUD'daki tek butona
  // basınca cycle eder.
  static const List<double> _speedSteps = [1.0, 2.0, 4.0, 0.0];
  int _speedIdx = 0;
  double _timeScale = 1.0;

  bool _mineMode = false;
  (int, int)? _mineStart;
  (int, int)? _mineEnd;

  bool _farmMode = false;
  (int, int)? _farmStart;
  (int, int)? _farmEnd;

  // ── Notification ───────────────────────────────────────────────────────────
  String? _notification;
  int _notifId = 0;

  // ── Frame notifier ────────────────────────────────────────────────────────
  // Tick'te value++ → ListenableBuilder bağlı widget'lar repaint olur.
  // setState() yerine bunu kullanırız: outer Scaffold/PopScope ağacı her frame
  // yeniden inşa edilmez, sadece time-driven leaf'ler.
  final ValueNotifier<int> _frame = ValueNotifier<int>(0);

  // Ground Picture cache invalidation tokeni — yeni harita üretildikçe artar,
  // painter cache'i bozar. Sadece map içeriği değişince invalidate.
  int _groundVersion = 0;

  // Aktif ışık kaynakları — her tick yeniden hesaplanır (gündüz boş).
  // Hem renderer hem ileride NPC "ışıkta mı?" sorgusu için ortak kaynak.
  List<LightSource> _lightSources = const [];

  // ──────────────────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    // Gece eşiği geçişi — DayNightCycle edge-trigger eder.
    _cycle.onNightFall = _assignSleepTargets;

    // Tüm worker'ların yol hız çarpanı sorgusu için tek otorite — bir kez set.
    WorkerEntity.roadSystem = _roadSystem;
    // A* pathfinding bağlamı — blockedTiles aşağıda spatial cache ile aynı
    // referansa bind edilir (içerik update, ref sabit).
    WorkerEntity.pathContext = _pathContext;
    _pathContext.blockedTiles = _obstacles;
    _pathContext.squeezeTiles = _squeezeTiles;

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
      RoadRenderer.loadAll(),
      FlameRenderer.loadAll(),
      SmokeRenderer.loadAll(),
      WaterShimmerRenderer.loadAll(),
    ]);
    _assetsReady.then((_) {
      if (!mounted) return;
      setState(() => _assetsLoaded = true);
      _ticker.start();
    });
  }

  /// Yavaş değişen engel/kuyu/yasak set'lerini yeniden doldurur. Container'lar
  /// yeniden tahsis edilmez (clear + refill) — frame başına GC baskısını keser.
  void _rebuildSpatialCaches() {
    _obstacles.clear();
    // Su tile engel sayılır ama üstünde köprü varsa NPC geçebilir.
    for (final t in _waterTiles) {
      if (!_roadSystem.hasBridgeAt(t.$1, t.$2)) _obstacles.add(t);
    }
    for (final n in _mineNodes) {
      if (!n.isDepleted) _obstacles.add((n.col, n.row));
    }
    // Solid binalar — BuildingMeta.walkable=false olanlar NPC engel sayar.
    // (walkable: firepit, well, lamppost, woodenHouse — etrafında/içinde
    // dolaşılanlar). Pending order'lar engel SAYILMAZ — builder içine girmeli.
    for (final b in _buildings) {
      final meta = kBuildingMeta[b.type];
      if (meta == null || meta.walkable) continue;
      for (int c = b.col; c < b.col + meta.cols; c++) {
        for (int r = b.row; r < b.row + meta.rows; r++) {
          _obstacles.add((c, r));
        }
      }
    }

    _softObs.clear();
    for (final r in _reeds) {
      _softObs.add((r.col, r.row));
      _softObs.add((r.col2, r.row2));
    }

    _forbiddenForTrees.clear();
    for (final t in _farmTiles) {
      _forbiddenForTrees.add((t.col, t.row));
    }
    for (final b in _buildings) {
      for (int c = b.col; c < b.col + b.cols; c++) {
        for (int r = b.row; r < b.row + b.rows; r++) {
          _forbiddenForTrees.add((c, r));
        }
      }
    }
    // Yollar — oduncu yol tile'ına ağaç dikmesin. Lamba zaten bina footprint
    // içinde (1×1 bina), ek kontrol gerek değil.
    for (final t in _roadSystem.all) {
      _forbiddenForTrees.add((t.col, t.row));
    }
    // Pending inşaat orderları — yere bir bina düşecek, oraya ağaç dikme.
    for (final o in _orders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type]!;
      for (int c = o.col; c < o.col + m.cols; c++) {
        for (int r = o.row; r < o.row + m.rows; r++) {
          _forbiddenForTrees.add((c, r));
        }
      }
    }
    // Sazlıklar — kıyı bitkisi, ağaç dikilmesin (görsel çakışma).
    for (final r in _reeds) {
      _forbiddenForTrees.add((r.col, r.row));
      _forbiddenForTrees.add((r.col2, r.row2));
    }

    // Squeeze tile'ları: walkable ama karşılıklı (N+S ya da E+W) komşuları
    // engelli → 1-tile genişlikte koridor. Bina kümesinin arasında kalan
    // dar geçitlere NPC sıkışmasın diye pathfinder'a yüksek cost olarak verilir.
    // Sadece bina engelleri etrafında oluşan koridorlar hedef; su komşuluğu
    // doğal kıyıda fazla penaltı yaratmasın diye dahil edilse de etkisi az
    // (NPC zaten kıyıdan kaçınır separation + idleWander su check).
    _squeezeTiles.clear();
    for (int c = 0; c < kCols; c++) {
      for (int r = 0; r < kRows; r++) {
        if (_obstacles.contains((c, r))) continue; // zaten bloke
        final n = _obstacles.contains((c, r - 1));
        final s = _obstacles.contains((c, r + 1));
        final e = _obstacles.contains((c + 1, r));
        final w = _obstacles.contains((c - 1, r));
        if ((n && s) || (e && w)) {
          _squeezeTiles.add((c, r));
        }
      }
    }
  }

  void _onTick(Duration elapsed) {
    final raw = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    // Karar bekleyen olay açıkken sim durur (sahne kalır, modal odakta).
    // Time scale × dev speed boost uygulanır. Boost denge testi için 1-30x
    // arası DevPanel slider'ından gelir; normal oyunda 1.0.
    final effectiveScale = _pendingChoice != null
        ? 0.0
        : _timeScale * _devSpeedBoost;
    // Boost ile dt clamp'i de artırıldı (30x'te 0.25'lik tek sıçrama büyük
    // adım yaratıyor, NPC update'lerinde stability açısından sınırlı tutuldu).
    final dt = (raw * effectiveScale).clamp(0.0, 0.5);
    if (dt <= 0) {
      _frame.value = _frame.value + 1;
      return;
    }
    // setState yerine sim mutate + _frame.value++ → outer ağaç rebuild olmaz,
    // sadece ListenableBuilder bağlı bölgeler repaint olur.
    {
      _time += dt;
      _cycle.update(dt);
      // Gün sayacı — timeOfDay sarınca (örn. 0.98 → 0.02) yeni gün.
      if (_cycle.timeOfDay < _lastTimeOfDay) _dayCount++;
      _lastTimeOfDay = _cycle.timeOfDay;

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
      final mouths =
          _villagers.length +
          _farmers.length +
          _woodcutters.length +
          _miners.length +
          _fishers.length +
          _builders.length;
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

      // ── Rastgele olaylar ────────────────────────────────────────────────────
      // Aktif geçici etki sönümlenir; zamanlayıcı dolunca yeni olay tetiklenir.
      if (_eventMoraleLeft > 0) {
        _eventMoraleLeft -= dt;
        if (_eventMoraleLeft <= 0) {
          _eventMorale = 0;
          _eventLabel = null;
        }
      }
      // Pop-up banner countdown — süresi bitince banner kapanır.
      if (_activeEventLeft > 0) {
        _activeEventLeft -= dt;
        if (_activeEventLeft <= 0) {
          _activeEvent = null;
        }
      }
      // Aktif sahne efektleri — decay + aggregate (tint, rain, mul'lar).
      _updateActiveFx(dt);
      // Yağmur boost'u — fırtına, yaz yağmuru efektlerinde rain min yükseltilir.
      if (_fxRainBoost > _cycle.rainIntensity) {
        _cycle.rainIntensity = _fxRainBoost;
      }
      if (!_godMode && _villagers.isNotEmpty) {
        _eventTimer -= dt;
        if (_eventTimer <= 0) {
          _triggerRandomEvent();
          _eventTimer =
              kEventMinInterval +
              _rng.nextDouble() * (kEventMaxInterval - kEventMinInterval);
        }
      }

      // ── Bina işlevleri: üretim, ticaret, nüfus büyümesi, stok kapasitesi ────
      _stats = updateBuildings(
        dt: dt,
        buildings: _buildings,
        stockpile: _stockpile,
        freeHousingSlots: _freeHousingSlots(),
        onSpawnVillager: _spawnGrownVillager,
        enforceCapacity: !_godMode,
        starvation: starvation,
        eventMorale: _eventMorale,
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
          case BuildingType.barn:
            b.isActive = _shepherds.any(
              (sh) =>
                  sh.barnCol == b.col &&
                  sh.barnRow == b.row &&
                  sh.state != ShepherdState.idle,
            );
          default:
            break;
        }
      }
      // Engel/yumuşak-engel set'leri yavaş değişir → her frame değil, throttle'lı
      // yeniden kur (su statik; maden/sazlık değişimi kSpatialRebuildInterval
      // gecikmesiyle yansır — yürüyüş için görünmez).
      _spatialTimer -= dt;
      if (_spatialTimer <= 0) {
        _rebuildSpatialCaches();
        _spatialTimer = kSpatialRebuildInterval;
      }
      final obstacles = _obstacles;
      final softObs = _softObs;
      // Sim multiplier'ları — aktif efekt aggregate'inden.
      final npcDt = dt * _fxNpcSpeedMul;
      final farmDt = dt * _fxFarmMul;
      final buildDt = dt * _fxBuilderMul;
      for (final v in _villagers) {
        v.update(
          npcDt,
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
      // Aile bağı: ölenin parents listesinden onu kaldır, kendisinin children
      // listesinde de parent ref'lerini temizle (çocuklar yetim olabilir).
      _villagers.removeWhere((v) {
        if (v.ageDays < v.lifespanDays || v.isCarrying) return false;
        for (final p in v.parents) {
          p.children.remove(v);
        }
        for (final c in v.children) {
          c.parents.remove(v);
        }
        final orphans = v.children.where((c) => c.parents.isEmpty).length;
        final msg = orphans > 0
            ? '🕯️ ${v.name} hayata veda etti. $orphans çocuk yetim kaldı.'
            : '🕯️ ${v.name} hayata veda etti.';
        _showNotification(msg);
        return true;
      });
      for (final b in _builders) {
        b.update(
          buildDt,
          _orders,
          _roadOrders,
          _buildings,
          _roadSystem,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
        );
      }
      // Tamamlanan inşaatlar için özel aksiyonlar
      bool topologyChanged = false;
      for (final o in _orders) {
        if (o.completed) {
          _onBuildingCompleted(o);
          topologyChanged = true;
        }
      }
      if (_roadOrders.any((o) => o.completed)) topologyChanged = true;
      _orders.removeWhere((o) => o.completed);
      _roadOrders.removeWhere((o) => o.completed);
      // World topology değişti → NPC'ler cached path'i invalidate etsin +
      // anchor sistemi yeni binalara göre slot'ları yenilesin.
      if (topologyChanged) {
        _pathContext.bumpVersion();
        _anchorSystem.rebuild(_buildings);
      }
      for (final t in _farmTiles) {
        t.update(farmDt);
      }
      // Kuyu erişimi anchor sistemi üzerinden — çiftçi 4 yönden birinde
      // boş slot bulur, aynı kuyuda çakışma olmaz.
      for (final f in _farmers) {
        f.update(
          npcDt,
          _farmTiles,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
          anchorSystem: _anchorSystem,
        );
        // Çiftçi hasat sonucunu altın olarak değil yiyecek olarak hay pile
        // yığınıyla üretir; piller balya olur, balyalar depoya taşınır.
        if (f.harvestHayPos != null) {
          final hay = HayEntity(
            type: HayType.pile,
            gridX: f.harvestHayPos!.$1.toDouble(),
            gridY: f.harvestHayPos!.$2.toDouble(),
          );
          ResourcePlacement.placeHay(
            hay,
            f.harvestHayPos!.$1.toDouble(),
            f.harvestHayPos!.$2.toDouble(),
            _hayEntities,
            _time,
          );
          _hayEntities.add(hay);
          f.harvestHayPos = null;
        }
      }
      processHayPiles(_hayEntities);
      for (final w in _woodcutters) {
        w.update(
          npcDt,
          _trees,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
        );
        if (w.harvestReady) {
          // Kesilen ağacın yanına tile-snap + slot-stack ile yerleştir.
          final box = ResourceBox(
            type: ResourceBoxType.woodChunk,
            gridX: w.lastHarvestX.toDouble(),
            gridY: w.lastHarvestY.toDouble(),
          );
          ResourcePlacement.placeBox(
            box,
            w.lastHarvestX.toDouble(),
            w.lastHarvestY.toDouble(),
            _resourceBoxes,
            _time,
          );
          _resourceBoxes.add(box);
        }
      }
      // Tarla + bina tile'ları → ağaç dikilemez (spatial cache'ten).
      final forbiddenForTrees = _forbiddenForTrees;
      for (final lc in _lumberCamps) {
        lc.update(
          npcDt,
          _trees,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
          forbiddenTiles: forbiddenForTrees,
        );
        if (lc.harvestReady) {
          final box = ResourceBox(
            type: ResourceBoxType.woodChunk,
            gridX: lc.lastHarvestX.toDouble(),
            gridY: lc.lastHarvestY.toDouble(),
          );
          ResourcePlacement.placeBox(
            box,
            lc.lastHarvestX.toDouble(),
            lc.lastHarvestY.toDouble(),
            _resourceBoxes,
            _time,
          );
          _resourceBoxes.add(box);
        }
      }
      // Fidan büyümesi güncelle, kesilen ağaçları kaldır
      for (final t in _trees) {
        t.update(dt);
      }
      _trees.removeWhere((t) => t.isFelled);
      for (final m in _miners) {
        m.update(
          npcDt,
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
          final box = ResourceBox(
            type: boxType,
            gridX: m.lastHarvestX.toDouble(),
            gridY: m.lastHarvestY.toDouble(),
          );
          ResourcePlacement.placeBox(
            box,
            m.lastHarvestX.toDouble(),
            m.lastHarvestY.toDouble(),
            _resourceBoxes,
            _time,
          );
          _resourceBoxes.add(box);
        }
      }
      for (final f in _fishers) {
        f.update(npcDt, _rng, waterTiles: _waterTiles, softObstacles: softObs);
        // Balıkçı doğrudan stoğa yiyecek üretir — fiziksel kutu yok.
        if (f.harvestReady) _stockpile.food += 1;
      }
      // Ağıl: inekler otlar, çobanlar sağar. Sağım = +1 food (balıkçı pattern).
      for (final c in _cows) {
        c.update(npcDt, _rng, waterTiles: obstacles);
      }
      for (final sh in _shepherds) {
        sh.update(
          npcDt,
          _cows,
          _rng,
          waterTiles: obstacles,
          softObstacles: softObs,
        );
        if (sh.harvestReady) _stockpile.food += 1;
      }
      final mineCountBefore = _mineNodes.length;
      _mineNodes.removeWhere((n) => n.isDepleted);
      if (_mineNodes.length != mineCountBefore) _pathContext.bumpVersion();
      _carrierTimer -= dt;
      if (_carrierTimer <= 0) {
        _carrierTimer = kCarrierAssignInterval;
        assignCarriers(
          villagers: _villagers,
          buildings: _buildings,
          resourceBoxes: _resourceBoxes,
          hayEntities: _hayEntities,
          stockpile: _stockpile,
          anchorSystem: _anchorSystem,
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
        shepherds: _shepherds,
        cows: _cows,
        // _obstacles: su + maden + solid bina. Separation NPC'leri buraya
        // itmesin (eski "waterTiles" param adı geçici; pratikte tüm engeller).
        waterTiles: _obstacles,
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
      for (final sh in _shepherds) {
        sh.smoothMotion(dt);
      }

      // HUD "yolda" kaynak sayımları — tek geçiş (build içinde 5 ayrı
      // .where().length taraması yerine; her frame allocation'ı keser).
      _woodInTransit = _stoneInTransit = _ironInTransit = _coalInTransit = 0;
      for (final b in _resourceBoxes) {
        if (b.isDelivered) continue;
        switch (b.type) {
          case ResourceBoxType.woodChunk:
            _woodInTransit++;
          case ResourceBoxType.stoneBox:
            _stoneInTransit++;
          case ResourceBoxType.ironBox:
            _ironInTransit++;
          case ResourceBoxType.coalBox:
            _coalInTransit++;
        }
      }
      _foodInTransit = 0;
      for (final h in _hayEntities) {
        if (h.isBale && !h.isDelivered) _foodInTransit++;
      }

      // Işık kaynaklarını topla — render + ileride NPC sorguları için.
      _lightSources = LightingSystem.collect(
        buildings: _buildings,
        villagers: _villagers,
        dayLight: _cycle.dayLight,
      );

      // ── Sohbet baloncukları — sosyal canlılık katmanı ───────────────────
      // Aktif baloncukları decay et + zaman zaman yakın çift için yeni başlat.
      for (final v in _villagers) {
        if (v.chatBubbleTime > 0) {
          v.chatBubbleTime -= dt;
          if (v.chatBubbleTime <= 0) {
            v.chatBubbleIcon = '';
            v.activity = VillagerActivity.none;
          }
        }
      }
      // Kişisel cooldown'lar her tick decay.
      for (final v in _villagers) {
        if (v.socialCooldown > 0) v.socialCooldown -= dt;
      }
      _socialScanTimer += dt;
      if (_socialScanTimer >= _kSocialScanInterval) {
        _socialScanTimer = 0;
        _tryStartChats();
      }

      // Yeni tamamlanan hedef için bildirim (sadece bir kez).
      final objStates = ObjectiveTracker.evaluate(
        ObjectiveContext(
          buildings: _buildings,
          farmTiles: _farmTiles,
          population: _villagers.length,
        ),
      );
      for (final s in objStates) {
        if (s.completed && !_completedObjectives.contains(s.obj.id)) {
          _completedObjectives.add(s.obj.id);
          _showNotification('🎯 ${s.obj.label} — tamamlandı!');
        }
      }

      // Denge testi snapshot'u — 5 sn'de bir kaynak/nüfus kaydı.
      _simSnapshotTimer += dt;
      if (_simSnapshotTimer >= _kSnapshotInterval) {
        _simSnapshotTimer = 0;
        _simHistory.add(
          SimSnapshot(
            simTime: _time,
            day: _dayCount,
            population: _villagers.length,
            buildings: _buildings.length,
            wood: _stockpile.wood,
            stone: _stockpile.stone,
            iron: _stockpile.iron,
            coal: _stockpile.coal,
            food: _stockpile.food,
            gold: _stockpile.gold,
          ),
        );
        if (_simHistory.length > _kMaxSnapshots) {
          _simHistory.removeAt(0);
        }
      }
    }
    _frame.value = _frame.value + 1;
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ── Ateşten NPC spawn ────────────────────────────────────────────────────

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
      kElderStartDay +
      kElderLifeMin +
      _rng.nextDouble() * (kElderLifeMax - kElderLifeMin);

  /// Rastgele bir köy olayı tetikler. Karar isteyen olaylar modal açar,
  /// otomatik olanlar anında uygulanır.
  /// Köyün ev tavanı — tüm evlerin sakin kapasitesi toplamı.
  int _populationCap() {
    int cap = 0;
    for (final b in _buildings) {
      final f = b.fn;
      if (f != null && f.role == BuildingRole.housing) cap += f.housingCapacity;
    }
    return cap;
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

  /// Tile merkezine en yakın görünür köylüyü döndür (mesafe < 0.7 tile).
  /// Bina içindeyse veya çok uzaksa null. Tıklama hedefi olarak kullanılır.
  VillagerEntity? _villagerAt(int col, int row) {
    final cx = col + 0.5;
    final cy = row + 0.5;
    VillagerEntity? best;
    double bestD2 = 0.49; // 0.7² eşik
    for (final v in _villagers) {
      if (v.isInsideBuilding) continue;
      final dx = v.gridX - cx;
      final dy = v.gridY - cy;
      final d2 = dx * dx + dy * dy;
      if (d2 < bestD2) {
        bestD2 = d2;
        best = v;
      }
    }
    return best;
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
    _roadOrders.clear();
    _roadSystem.clear();
    _placingRoad = null;
    _roadStrokeTiles.clear();
    _pathContext.bumpVersion(); // yeni harita → tüm cached path'ler iptal
    _anchorSystem.rebuild(const []); // tüm slot rezervasyonlarını sil
    _lumberCamps.clear();
    _miners.clear();
    _fishers.clear();
    _shepherds.clear();
    _cows.clear();
    _farmers.clear();
    _woodcutters.clear();
    _builders.clear();
    _villagers.clear();
    _resourceBoxes.clear();
    _hayEntities.clear();

    _stockpile.clear();
    // Başlangıç kaynak paketi — oyuncunun erken oyun sıkışmaması için.
    // Ateş yeri ücretsiz; sonrasında oduncu kulübesi (12 odun) veya bir ev
    // (18 odun + 4 taş) ya da kuyu (4 odun + 8 taş) kurabilir.
    // 25/15/25: ilk 1-2 binayı kurmak + ilk günü atlatmak için yeterli.
    _stockpile.wood = 25;
    _stockpile.stone = 15;
    _stockpile.food = 25;
    _hasFire = false;
    _firepitBuilding = null;
    _selectedBuilding = null;

    // Olay & gün durumunu sıfırla
    _eventTimer = kEventFirstDelay;
    _eventMorale = 0.0;
    _eventMoraleLeft = 0.0;
    _eventLabel = null;
    _activeEvent = null;
    _activeEventLeft = 0.0;
    _pendingChoice = null;
    _activeFx.clear();
    _completedObjectives.clear();
    _foodHunger = 0.0;
    _dayCount = 1;
    _lastTimeOfDay = _cycle.timeOfDay;
    _spatialTimer =
        0.0; // yeni harita → spatial cache'i ilk tick'te yeniden kur

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

    // Yeni map → ground picture cache invalid.
    _groundVersion++;

    _fixNpcSpawns();
  }

  /// Su üzerindeki tüm entity'leri en yakın kuru tile'a taşır.
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

  void _cycleSpeed() {
    setState(() {
      _speedIdx = (_speedIdx + 1) % _speedSteps.length;
      _timeScale = _speedSteps[_speedIdx];
    });
    final label = _timeScale == 0.0
        ? 'Duraklatıldı ⏸'
        : 'Hız: ${_timeScale.toInt()}×';
    _showNotification(label);
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

    // ── Güneş / Ay ark sabitleri — ekran boyutuna bağlı (frame'den bağımsız)
    const kSunSize = 32.0;
    const kMoonSize = 24.0;
    final arcCx = screen.width / 2;
    final arcBy = screen.height * 0.50;
    final arcR = screen.width * 0.42;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExitToMenu?.call();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A3060),
        body: Stack(
          children: [
            // ── SKY / SUN / MOON / CLOUDS ──────────────────────────────────
            // Time-driven katmanlar — ListenableBuilder ile her tick yalnızca
            // bu blok rebuild olur (RepaintBoundary ile diğer katmanları
            // etkilemeden). Outer Scaffold/PopScope ağacı tick'te rebuild OLMAZ.
            Positioned.fill(
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (context, _) {
                    final sunNorm = ((_cycle.timeOfDay - 0.25) / 0.50).clamp(
                      0.0,
                      1.0,
                    );
                    final sunAngle = pi * sunNorm;
                    final sunX = arcCx + arcR * cos(sunAngle) - kSunSize / 2;
                    final sunY = arcBy - arcR * sin(sunAngle) - kSunSize / 2;
                    final moonT = (_cycle.timeOfDay + 0.5) % 1.0;
                    final moonNorm = ((moonT - 0.25) / 0.50).clamp(0.0, 1.0);
                    final moonAngle = pi * moonNorm;
                    final moonX = arcCx + arcR * cos(moonAngle) - kMoonSize / 2;
                    final moonY = arcBy - arcR * sin(moonAngle) - kMoonSize / 2;
                    final w = screen.width;
                    final wrap = w + 240.0;
                    const clouds =
                        <(double, double, double, double, double, double)>[
                          (0.08, 22.0, 0.55, 2.5, 0.30, 0.50),
                          (0.40, 14.0, 0.60, 2.8, 0.35, 0.40),
                          (0.76, 32.0, 0.50, 2.2, 0.28, 0.50),
                          (0.18, 58.0, 0.85, 5.0, 0.65, 0.35),
                          (0.55, 48.0, 0.95, 5.5, 0.70, 0.30),
                          (0.88, 68.0, 0.75, 4.5, 0.60, 0.45),
                          (0.04, 96.0, 1.30, 9.0, 1.00, 0.25),
                          (0.38, 116.0, 1.45, 9.5, 1.00, 0.20),
                          (0.72, 88.0, 1.20, 8.5, 1.00, 0.30),
                        ];
                    return Stack(
                      children: [
                        PixelSky(
                          topColor: _cycle.skyTop,
                          midColor: _cycle.skyMid,
                        ),
                        Positioned.fill(
                          child: StarField(
                            opacity: _cycle.starOpacity,
                            time: _time,
                          ),
                        ),
                        Positioned(
                          left: sunX,
                          top: sunY,
                          child: Opacity(
                            opacity: _cycle.sunOpacity,
                            child: PixelSun(color: _cycle.sunColor),
                          ),
                        ),
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
                                  Container(
                                    width: 140,
                                    height: 140,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0x30C8E8FF),
                                          Color(0x00C8E8FF),
                                        ],
                                      ),
                                    ),
                                  ),
                                  Container(
                                    width: 60,
                                    height: 60,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: RadialGradient(
                                        colors: [
                                          Color(0x55DDEEFF),
                                          Color(0x00DDEEFF),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const PixelMoon(),
                                ],
                              ),
                            ),
                          ),
                        ),
                        for (final cfg in clouds)
                          Positioned(
                            left:
                                ((cfg.$1 * w) + (_time * cfg.$4)) % wrap - 120,
                            top: cfg.$2,
                            child: Opacity(
                              opacity: _cycle.cloudOpacity,
                              child: PixelCloud(
                                dark: _cycle.rainIntensity > cfg.$6,
                                scale: cfg.$3,
                                parallax: cfg.$5,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
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
                        _camera = _camera + focal * (1 / newZoom - 1 / _zoom);
                        _zoom = newZoom;
                        _frame.value = _frame.value + 1;
                      }
                    },
                    child: GestureDetector(
                      onScaleStart: (d) {
                        _scaleStart = _zoom;
                        _panAnchor = d.localFocalPoint;
                        _cameraAnchor = _camera;
                        if (_mineMode) {
                          final tile = _toTile(d.localFocalPoint);
                          _mineStart = tile;
                          _mineEnd = tile;
                          _frame.value = _frame.value + 1;
                        } else if (_lumberMode) {
                          final tile = _toTile(d.localFocalPoint);
                          _lumberStart = tile;
                          _lumberEnd = tile;
                          _frame.value = _frame.value + 1;
                        } else if (_farmMode) {
                          final tile = _toTile(d.localFocalPoint);
                          _farmStart = tile;
                          _farmEnd = tile;
                          _frame.value = _frame.value + 1;
                        } else if (_placingRoad != null) {
                          // Yol döşeme: stroke başla, basılan tile'ı paint et
                          _roadStrokeTiles.clear();
                          final tile = _toTile(d.localFocalPoint);
                          if (tile != null) _paintRoadTile(tile.$1, tile.$2);
                        }
                      },
                      onScaleUpdate: (d) {
                        if (_mineMode || _lumberMode || _farmMode) {
                          // Seçim modlarında sürükleme; zoom yok
                          final tile = _toTile(d.localFocalPoint);
                          bool changed = false;
                          if (_mineMode && tile != _mineEnd) {
                            _mineEnd = tile;
                            changed = true;
                          }
                          if (_lumberMode && tile != _lumberEnd) {
                            _lumberEnd = tile;
                            changed = true;
                          }
                          if (_farmMode && tile != _farmEnd) {
                            _farmEnd = tile;
                            changed = true;
                          }
                          if (changed) _frame.value = _frame.value + 1;
                        } else if (_placingRoad != null) {
                          // Yol döşeme: drag boyunca her yeni tile'a paint et
                          final tile = _toTile(d.localFocalPoint);
                          if (tile != null &&
                              !_roadStrokeTiles.contains(tile)) {
                            _paintRoadTile(tile.$1, tile.$2);
                          }
                        } else if (_placing != null) {
                          // Bina yerleştirme modunda ghost güncelle
                          final tile = _toTile(d.localFocalPoint);
                          if (tile != _ghost) {
                            _ghost = tile;
                            _frame.value = _frame.value + 1;
                          }
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
                          _zoom = newZoom;
                          _camera =
                              _cameraAnchor! +
                              (d.localFocalPoint - _panAnchor!) +
                              focal * (1 / newZoom - 1 / _scaleStart);
                          _frame.value = _frame.value + 1;
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
                          // Seçim: önce bina, yoksa NPC, yoksa hiçbir şey.
                          final tile = _toTile(d.localPosition);
                          if (tile != null) {
                            final b = _buildingAt(tile.$1, tile.$2);
                            if (b != null) {
                              setState(() {
                                _selectedBuilding = b;
                                _selectedVillager = null;
                              });
                            } else {
                              final v = _villagerAt(tile.$1, tile.$2);
                              setState(() {
                                _selectedVillager = v;
                                _selectedBuilding = null;
                              });
                            }
                          } else {
                            setState(() {
                              _selectedBuilding = null;
                              _selectedVillager = null;
                            });
                          }
                        }
                      },
                      child: MouseRegion(
                        onHover: (e) {
                          if (_placing != null) {
                            final tile = _toTile(e.localPosition);
                            if (tile != _ghost) {
                              _ghost = tile;
                              _frame.value = _frame.value + 1;
                            }
                          }
                        },
                        child: RepaintBoundary(
                          child: ListenableBuilder(
                            listenable: _frame,
                            builder: (_, _) => CustomPaint(
                              painter: VillageGamePainter(
                                villagers: _villagers,
                                buildings: _buildings,
                                builders: _builders,
                                pendingOrders: _orders,
                                roadSystem: _roadSystem,
                                pendingRoadOrders: _roadOrders,
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
                                overlayTop: _cycle.overlayTop,
                                overlayBottom: _cycle.overlayBottom,
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
                                shepherds: _shepherds,
                                cows: _cows,
                                zoom: _zoom,
                                resourceBoxes: _resourceBoxes,
                                hayEntities: _hayEntities,
                                skyReflection: _cycle.skyMid,
                                groundVersion: _groundVersion,
                                lightSources: _lightSources,
                                eventTint: _fxTint,
                                activeFx: _fxActiveIds,
                                burningBuildings: _burningBuildings,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),

            // HUD — frame'e bağlı (timeOfDay, dayLight, transit sayımları
            // her tick değişir). ListenableBuilder içinde repaint.
            RepaintBoundary(
              child: ListenableBuilder(
                listenable: _frame,
                builder: (_, _) => GameHUD(
                  stockpile: _stockpile,
                  woodInTransit: _woodInTransit,
                  stoneInTransit: _stoneInTransit,
                  ironInTransit: _ironInTransit,
                  coalInTransit: _coalInTransit,
                  foodInTransit: _foodInTransit,
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
                  dayCount: _dayCount,
                  buildingCount: _buildings.length,
                  pendingOrderCount: _orders.where((o) => !o.completed).length,
                  morale: _stats.morale,
                  lowWater: _buildings.any(
                    (b) =>
                        b.fn?.role == BuildingRole.housing &&
                        b.occupants > 0 &&
                        b.waterLevel < 0.3,
                  ),
                  starving: !_godMode && _stockpile.food < kStarveRampFood,
                  eventLabel: _eventLabel,
                  effectTimeLeft: _eventMoraleLeft,
                  effectDuration: _activeEvent?.duration ?? 1,
                  effectPositive: (_eventMorale >= 0),
                  onToggleDev: () =>
                      setState(() => _devPanelOpen = !_devPanelOpen),
                  godMode: _godMode,
                  onNewMap: () => setState(() => _generateWorld()),
                  onToggleGod: () => setState(() => _godMode = !_godMode),
                  onTriggerEvent: _triggerRandomEvent,
                  timeScale: _timeScale,
                  onCycleSpeed: _cycleSpeed,
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
                          _lumberMode = false;
                          _mineMode = false;
                          _placingRoad = null;
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
                      RoadPanel(
                        stockpile: _stockpile,
                        selected: _placingRoad,
                        onSelect: (s) => setState(() {
                          _placing = null;
                          _ghost = null;
                          _farmMode = false;
                          _lumberMode = false;
                          _mineMode = false;
                          _placingRoad = _placingRoad == s ? null : s;
                          _roadStrokeTiles.clear();
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
                          _placingRoad = null;
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
                          _placingRoad = null;
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
                          _placingRoad = null;
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
                  barnCows: _selectedBuilding!.type == BuildingType.barn
                      ? _cows
                            .where(
                              (c) =>
                                  c.barnCol == _selectedBuilding!.col &&
                                  c.barnRow == _selectedBuilding!.row,
                            )
                            .toList()
                      : const [],
                  barnShepherd: _selectedBuilding!.type == BuildingType.barn
                      ? _shepherds
                            .where(
                              (sh) =>
                                  sh.barnCol == _selectedBuilding!.col &&
                                  sh.barnRow == _selectedBuilding!.row,
                            )
                            .firstOrNull
                      : null,
                  stockpile: _stockpile,
                  stats: _stats,
                  population: _villagers.length,
                  populationCap: _populationCap(),
                  onClose: () => setState(() => _selectedBuilding = null),
                  onSell: (kind) => setState(() {
                    if (sellAtMarket(_stockpile, kind)) {
                      // Satış oldu → seçili market binasına son satış zamanı
                      // mühürlenir; _BuildingDrawable 1sn altın parıltısı çizer.
                      _selectedBuilding?.lastSaleTime = _time;
                    }
                  }),
                ),
              ),

            // Köylü bilgi paneli — bina paneliyle aynı pozisyon, eş zamanlı
            // ikisi gösterilmez (seçim mantığı tek değer tutuyor).
            if (_selectedVillager != null)
              Positioned(
                bottom: 120,
                left: 14,
                child: VillagerInfoPanel(
                  villager: _selectedVillager!,
                  homeLabel: _selectedVillager!.homeBuilding == null
                      ? null
                      : kBuildingMeta[(_selectedVillager!.homeBuilding
                                    as BuildingEntity)
                                .type]
                            ?.label,
                  onClose: () => setState(() => _selectedVillager = null),
                  onSelect: (v) => setState(() => _selectedVillager = v),
                ),
              ),

            // Event choice modal — karar bekleyen olaylar için full-screen
            // karartılmış overlay + zengin seçim kartı. Modal açıkken
            // simülasyon dt = 0 (tick yarıduraklatılır), oyuncu seçene kadar.
            if (_pendingChoice != null)
              Positioned.fill(
                child: EventChoiceModal(
                  event: _pendingChoice!,
                  onChoose: (c) => _applyEventChoice(_pendingChoice!, c),
                ),
              ),

            // Geliştirici test paneli — sağdan slide-in.
            // ListenableBuilder ile her tick'te canlı güncelleniyor (sim
            // hızı yüksekken kaynak rakamları sahnedeki gibi akıcı değişir).
            if (_devPanelOpen)
              Positioned.fill(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) => DevPanel(
                    godMode: _godMode,
                    rainIntensity: _cycle.rainIntensity,
                    timeOfDay: _cycle.timeOfDay,
                    villagerCount: _villagers.length,
                    buildingCount: _buildings.length,
                    onClose: () => setState(() => _devPanelOpen = false),
                    onToggleGod: () => setState(() => _godMode = !_godMode),
                    onSetRain: (v) => setState(() => _cycle.rainIntensity = v),
                    onSetTimeOfDay: (v) => setState(() => _cycle.timeOfDay = v),
                    onTriggerEvent: (e) {
                      setState(() {
                        if (e.needsChoice) {
                          _pendingChoice = e;
                          _showNotification(
                            '${e.icon} ${e.title} — karar bekliyor',
                          );
                        } else {
                          _applyEventAutomatic(e);
                        }
                        _devPanelOpen = false;
                      });
                    },
                    onAddResource: (k, n) => setState(() {
                      _stockpile.add(k, n);
                      final cur = _stockpile.get(k);
                      if (cur < 0) _stockpile.add(k, -cur);
                    }),
                    onSpawnVillager: () {
                      final fp = _firepitBuilding;
                      if (fp != null) setState(() => _spawnGrownVillager(fp));
                    },
                    onKillRandomVillager: () {
                      if (_villagers.isEmpty) return;
                      setState(() {
                        final v = _villagers[_rng.nextInt(_villagers.length)];
                        v.ageDays = v.lifespanDays + 1; // bir sonraki tick ölür
                      });
                    },
                    onClearEffects: () => setState(() {
                      _activeFx.clear();
                      _eventMorale = 0;
                      _eventMoraleLeft = 0;
                      _eventLabel = null;
                      _activeEvent = null;
                      _activeEventLeft = 0;
                    }),
                    onNewMap: () => setState(() => _generateWorld()),
                    onWakeAll: () => setState(() {
                      for (final v in _villagers) {
                        v.isInsideBuilding = false;
                        v.sleepTarget = null;
                        v.sleepIsHome = false;
                      }
                    }),
                    onSeedLivingVillage: () {
                      _buildLivingVillage();
                      setState(() => _devPanelOpen = false);
                    },
                    simSpeedBoost: _devSpeedBoost,
                    simHistory: [
                      for (final s in _simHistory)
                        SimSnapshot(
                          simTime: s.simTime,
                          day: s.day,
                          population: s.population,
                          buildings: s.buildings,
                          wood: s.wood,
                          stone: s.stone,
                          iron: s.iron,
                          coal: s.coal,
                          food: s.food,
                          gold: s.gold,
                        ),
                    ],
                    onSetSimSpeed: (v) => setState(() => _devSpeedBoost = v),
                    onClearSimHistory: () =>
                        setState(() => _simHistory.clear()),
                    activeScenario: _scenarioName,
                    scenarioProgress: _scenarioProgress,
                    lastReport: _lastReport == null
                        ? null
                        : ScenarioReport(
                            name: _lastReport!.name,
                            durationSec: _lastReport!.durationSec,
                            popStart: _lastReport!.popStart,
                            popEnd: _lastReport!.popEnd,
                            resources: _lastReport!.resources,
                            verdict: _lastReport!.verdict,
                            warnings: _lastReport!.warnings,
                          ),
                    onScenarioBaseline: _scenarioBaseline,
                    onScenarioPlague: _scenarioPlague,
                    onScenarioDrought: _scenarioDrought,
                    onScenarioFire: _scenarioFire,
                    onPlayMusic: () {
                      if (!_devStartMusic()) {
                        _showNotification('Uygun NPC yok');
                      }
                    },
                    onStartDance: () {
                      if (!_devStartDance()) {
                        _showNotification(
                          'Yan yana iki yetişkin NPC bulunamadı',
                        );
                      }
                    },
                    onStartChat: () {
                      if (!_devStartChat()) {
                        _showNotification(
                          'Yan yana iki yetişkin NPC bulunamadı',
                        );
                      }
                    },
                    onClearActivities: () => setState(_devClearActivities),
                  ),
                ),
              ),

            // Event banner — pop-up zengin kart, frame'e bağlı (countdown
            // canlı görünür diye ListenableBuilder altında).
            Positioned(
              top: 90,
              left: 0,
              right: 0,
              child: Center(
                child: RepaintBoundary(
                  child: ListenableBuilder(
                    listenable: _frame,
                    builder: (_, _) {
                      final e = _activeEvent;
                      if (e == null) return const SizedBox.shrink();
                      return EventBanner(
                        event: e,
                        timeLeft: _activeEventLeft,
                        duration: kEventBannerDuration,
                        onClose: () => setState(() {
                          _activeEvent = null;
                          _activeEventLeft = 0;
                        }),
                      );
                    },
                  ),
                ),
              ),
            ),

            // Hedef listesi — sol kolonda HUD'un altında. Oyuncu erken oyun
            // adımlarını izler. ListenableBuilder ile her tick'te güncellenir.
            Positioned(
              left: 14,
              top: 190,
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) {
                    final states = ObjectiveTracker.evaluate(
                      ObjectiveContext(
                        buildings: _buildings,
                        farmTiles: _farmTiles,
                        population: _villagers.length,
                      ),
                    );
                    return ObjectivePanel(
                      objectives: states,
                      collapsed: _objectivesCollapsed,
                      onToggleCollapse: () => setState(
                        () => _objectivesCollapsed = !_objectivesCollapsed,
                      ),
                    );
                  },
                ),
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
            if (_placing != null ||
                _farmMode ||
                _lumberMode ||
                _mineMode ||
                _placingRoad != null)
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
                        : _placingRoad != null
                        ? const Color(0xEE2A1808)
                        : const Color(0xEE1A3A1A),
                    child: Text(
                      _mineMode
                          ? 'Madenci — sürükle seç, madenleri işaretle'
                          : _lumberMode
                          ? 'Oduncu — sürükle seç, bırak ağaçları işaretle'
                          : _farmMode
                          ? 'Tarla — sürükle seç, bırak onayla'
                          : _placingRoad != null
                          ? '${_placingRoad!.label} — sürükle döşe'
                          : '${kBuildingMeta[_placing!]!.label} — haritaya tıkla',
                      style: TextStyle(
                        color: _mineMode
                            ? const Color(0xFFAABBFF)
                            : _lumberMode
                            ? const Color(0xFFFFAA44)
                            : _placingRoad != null
                            ? const Color(0xFFDDB880)
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
