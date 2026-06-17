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
import 'entities/florist_entity.dart';
import 'entities/shepherd_entity.dart';
import 'world/animal_entity.dart';
import 'world/bird_flock.dart';
import 'world/bee_flock.dart';
import 'rendering/tool_renderer.dart';
import 'world/nature_entity.dart';
import 'world/decor_entity.dart';
import 'world/grave.dart';
import 'rendering/nature_renderer.dart';
import 'rendering/decor_renderer.dart';
import 'rendering/animal_renderer.dart';
import 'world/world_generator.dart';
import 'buildings/building_type.dart';
import 'ui/hud.dart';
import 'ui/building_panel.dart';
import 'ui/road_panel.dart';
import 'ui/building_info_panel.dart';
import 'ui/villager_info_panel.dart';
import 'ui/event_banner.dart';
import 'ui/event_choice_modal.dart';
import 'ui/petition_modal.dart';
import 'systems/petition_system.dart';
import 'systems/estate_system.dart';
import 'ui/dev_panel.dart';
import 'ui/objective_panel.dart';
import 'systems/quest_book.dart';
import 'ui/sky_widgets.dart';
import 'ui/loading_screen.dart';
import 'ui/mode_button.dart';
import 'world/resource_box.dart';
import 'world/resource_placement.dart';
import 'world/hay_entity.dart';
import 'rendering/resource_renderer.dart';
import 'core/resources.dart';
import 'ui/cozy_theme.dart';
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

// `_VillageSceneState` part-of bölmeleri — her dosya konsept bazında bir
// alan (yerleştirme, tick döngüsü, world helper'ları, UI, vs).
part 'scene/scene_scenarios.dart';
part 'scene/scene_npc_activity.dart';
part 'scene/scene_npc_routine.dart';
part 'scene/scene_events.dart';
part 'scene/scene_placement.dart';
part 'scene/scene_building_spawn.dart';
part 'scene/scene_world.dart';
part 'scene/scene_tick.dart';
part 'scene/scene_input.dart';
part 'scene/scene_ui.dart';
part 'scene/scene_firepit_gather.dart';
part 'scene/scene_petitions.dart';
part 'scene/scene_estates.dart';
part 'scene/scene_funeral.dart';
part 'scene/scene_reactions.dart';
part 'scene/scene_flow.dart';

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
  /// Oyuncu "Takip et" eylemini kullanırsa kamera bu NPC'ye demirlenir;
  /// her tick'te yumuşak lerp ile NPC merkeze çekilir. Manuel pan (scaleStart)
  /// otomatik iptal eder. null = serbest kamera.
  VillagerEntity? _followedVillager;

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
  // ── Ground decor (çiçek, mantar, çalı, kütük, taş) — pure visual ─────────
  final List<DecorEntity> _decor = [];

  // ── Mezarlık — kilise yanında biriken mezarlar (cenaze sistemi) ──────────
  final List<Grave> _graves = [];

  // ── Mining (maden kazma) ───────────────────────────────────────────────────
  final List<MineNode> _mineNodes = [];
  final List<MinerEntity> _miners = [];
  // ── Fisher ────────────────────────────────────────────────────────────────
  final List<FisherEntity> _fishers = [];

  // ── Florist (çiçekçi kulübesi NPC'si) ─────────────────────────────────────
  final List<FloristEntity> _florists = [];

  // ── Ağıl: çobanlar + inekler ──────────────────────────────────────────────
  final List<ShepherdEntity> _shepherds = [];
  final List<AnimalEntity> _cows = [];

  // ── Ambient gökyüzü kuş sürüleri ──────────────────────────────────────────
  // Etkileşim yok, pure atmosphere. Gündüz periyodik spawn, off-grid temizle.
  final List<BirdFlock> _birdFlocks = [];
  double _birdFlockSpawnTimer = 20.0; // ilk sürü 20s sonra

  // ── Ambient arı sürüleri — her arı kovanına bağlı, kovan etrafında orbit ──
  // Topology değişince _rebuildBeeSwarms ile kovanlardan türetilir (mevcutlar
  // pozisyona göre korunur). Pure atmosphere, gece fade.
  final List<BeeSwarm> _beeSwarms = [];

  // ── Ambient göktaşı yağmuru — seyrek, gece özel gök gösterisi (karar yok) ──
  // Geri sayım gün-gece boyunca akar; sıfırlanınca gece tetiklenir, köylüler
  // izler + moral artar. Nadir/özel — ilk gösteri ~4. gün, sonra her 5-9 günde.
  double _meteorShowerTimer = 4.0 * kGameDaySeconds;

  // ── Belediye politikaları — oyuncunun nüfus üstündeki kararları ──────────
  // Default hepsi kapalı. BuildingInfoPanel toggle ile değiştirir.
  final VillagePolicies _policies = VillagePolicies();
  /// Misafirperverlik politikası açıkken bir sonraki gezgin spawn timer'ı.
  /// Random 3-6 oyun günü; spawn olunca yeniden roll edilir.
  double _migrationTimerSec = 0;
  /// Komşuluk poll sayacı — 1.2s aralıkla selamlaşma scan.
  double _greetPollSec = 0;
  /// Aile birleşimi poll sayacı — 15s aralıkla solo eşleştirme.
  double _reunionPollSec = 0;
  /// Bilge yaşlı emergence poll — ~60s aralıkla rastgele tetikleme şansı.
  double _sageCheckSec = 60;
  /// Reproduction tick throttle — fertility kontrolü her frame gerek değil.
  /// 0.5s aralıkla full villager scan, kullanıcı fark etmez.
  double _reproPollSec = 0;
  /// Geçici moral etkileri — politika olaylarından (göçmen uyumu, aile birleşimi).
  /// Her giriş (untilSim, amount). _time geçince düşer; aktiflerin toplamı
  /// `_eventMorale`'ye eklenir.
  final List<({double untilSim, double amount})> _policyMoraleEffects = [];

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

  // Köy morali — PASİF BİRİKİM GÖSTERGESİ. Ekonomiden türemez; olay/eylem/
  // politika hedefe doğru iter, _morale yavaşça oraya süzülür ve tabana döner.
  // Hiçbir oyun mantığı bunu okumaz — yalnızca HUD/panel gösterir (_stats.morale).
  double _morale = 0.5;

  // ── Reaktif ortam (sürekli canlılık) ─────────────────────────────────────
  double _spontaneousTimer = 0; // ara sıra rastgele NPC'ye küçük gövde refleksi
  bool   _lastRainy = false;    // yağmur geçiş tespiti (başla/dur reaksiyonu)
  bool   _wasStarving = false;  // açlığa giriş tespiti (bir kerelik reaksiyon)

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

  // ── Dilekçe / Meclis (scene_petitions) ─────────────────────────────────────
  // Ambient yönetişim: köy periyodik dilekçe sunar, HUD'da mühür belirir.
  // Modal açıkken oyun DURMAZ (ambient — _pendingChoice'tan farkı bu).
  Petition? _pendingPetition;
  bool _petitionModalOpen = false;
  double _petitionTimer = 1.0 * kGameDaySeconds; // ilk dilekçe ~1 oyun günü sonra
  double _petitionDeadline = 0;
  // Zincir: tetiklenmiş takip dilekçeleri (id + ne zaman geleceği sim time).
  final List<({String id, double fireAtSim})> _petitionFollowUps = [];
  // Hafıza: çözülen dilekçe id → cooldown sim time (aynısı hemen random çıkmasın).
  final Map<String, double> _petitionCooldowns = {};
  // Köyün kalıcı hafızası: geçmiş kararların bıraktığı bayraklar (ör. 'cult.active').
  // Dilekçeler bunu okuyup dallanır; köyün "öyküsü" burada birikir.
  final Set<String> _villageMemory = {};

  // ── Zümreler / Hizipler (scene_estates) ────────────────────────────────────
  // Yönetişimin kalbi: 4 zümrenin morali + nüfuzu. Dilekçe/ferman kararları
  // oynatır; köy yavaşça bir kimliğe kayar. Küskün zümre köyde GÖRÜNÜR olur.
  final EstateSystem _estates = EstateSystem();
  /// Küskün zümre postürü poll sayacı — ~5s aralıkla diegetik somurtma.
  double _estateMoodScan = 0;
  /// Köyün en son DUYURULAN kimliği (baskın zümre). null = henüz dengeli.
  /// Değiştiğinde köy görünür biçimde dönüşür (_transformVillageIdentity).
  Estate? _identityEstate;

  // Geliştirici test paneli açık mı.
  bool _devPanelOpen = false;

  // Köy Defteri paneli daraltılmış mı (oyuncu küçültebilir).
  bool _objectivesCollapsed = false;

  // ── Köy Akışı (görev defteri + politika-odaklı Tüzük kademesi) ────────────
  // Tamamlanmış görev id'leri (yeni tamamlanan → görsel ödül + bildirim).
  final Set<String> _completedQuests = {};
  // Köyün kimlik kademesi (charterTier) — politika+görevle ilerler, asla gerilemez.
  int _charterTier = 0;
  // _tickFlow throttle sayacı.
  double _flowScan = 0;

  // Sosyal canlılık — bağlama duyarlı, dağıtık yoğunluk.
  // Her NPC kendi cooldown'unda bağımsız değerlendirilir; global cap yok.
  // Bağlam çarpanları (pazar/taverna/ateş/gece/yağmur) per-NPC ihtimalini
  // ayarlar → nüfus arttıkça doğal olarak köy daha canlı olur, dağıtık
  // bölgeler sessiz kalır.
  double _socialScanTimer = 0;
  /// NPC rutin (errand) tarama sayacı — scene_npc_routine.
  double _routineScan = 0;
  static const double _kSocialScanInterval =
      3.0; // her NPC için 3 sn'de bir bak

  // Ateş başı toplanma + hikaye saati (scene_firepit_gather) timer'ları.
  // Tick periyotları extension içinde sabit; field'lar burada tutulur.
  double _gatherScanTimer = 0;
  double _storyScanTimer = 0;

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
  /// Performans modu — pahalı ambient efektleri (fireflies, polen, kuş sürüleri,
  /// gölge refinement, light pass detayı) tek tıkla kapatır. Görsel atmosfer
  /// kaybı karşılığında dev FPS kazancı. Test/oynanış sırasında zayıf donanım
  /// yardımı.
  bool _perfMode = false;

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
    _cycle.onNightFall = () {
      _assignSleepTargets();
      // Berrak gece bayrağı set edildiyse ufak bir tebrik bildirimi.
      // %30 random → seyrek ama hatırlatıcı; cozy/chill tonda.
      if (_cycle.isClearNight) {
        _showNotification('🌌 Berrak gece — yıldızlar berrak');
      }
    };

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
      DecorRenderer.loadAll(),
      AnimalRenderer.loadAll(),
      MineRenderer.loadAll(),
      ResourceRenderer.loadAll(),
      RoadRenderer.loadAll(),
      FlameRenderer.loadAll(),
      SmokeRenderer.loadAll(),
    ]);
    _assetsReady.then((_) {
      if (!mounted) return;
      setState(() => _assetsLoaded = true);
      _ticker.start();
    });
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  // ── Zaman & bildirim helper'ları ───────────────────────────────────────────

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
  // Tüm widget alt-ağaçları scene_ui.dart'taki build* metotlarındadır.
  // Burada sadece Stack iskeleti + conditional layer'lar var.

  @override
  Widget build(BuildContext context) {
    if (!_assetsLoaded) {
      return LoadingScreen(onCancel: widget.onExitToMenu);
    }
    final screen = MediaQuery.of(context).size;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) widget.onExitToMenu?.call();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF1A3060),
        body: Stack(
          children: [
            Positioned.fill(child: buildSkyLayer(screen)),
            Positioned.fill(child: buildGameCanvas()),
            Positioned.fill(child: buildHudLayer()),
            buildBottomToolbar(),
            // Bekleyen dilekçe mührü — HUD üstünde, modal kapalıyken (ambient).
            if (_pendingPetition != null && !_petitionModalOpen)
              buildPetitionSeal(),
            if (_selectedBuilding != null) buildSelectedBuildingPanel(),
            if (_selectedVillager != null) buildSelectedVillagerPanel(),
            // Karar bekleyen olay — modal açıkken simülasyon dt = 0 (tick
            // yarıduraklatılır), oyuncu seçene kadar.
            if (_pendingChoice != null) buildEventChoiceModal(),
            // Dilekçe modal'ı — oyunu DURDURMAZ (ambient yönetişim).
            if (_petitionModalOpen && _pendingPetition != null)
              buildPetitionModal(),
            if (_devPanelOpen) buildDevPanel(),
            buildEventBanner(),
            buildObjectivesPanel(),
            if (_notification != null) buildNotificationToast(),
            if (_placing != null ||
                _farmMode ||
                _lumberMode ||
                _mineMode ||
                _placingRoad != null)
              buildHintRibbon(),
          ],
        ),
      ),
    );
  }
}
