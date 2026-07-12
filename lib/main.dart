import 'dart:math';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'characters/villager_type.dart';
import 'characters/personality.dart';
import 'characters/villager_names.dart';
import 'characters/npc_visual.dart';
import 'entities/villager_entity.dart';
import 'entities/merchant_entity.dart';
import 'entities/imperial_soldier.dart';
import 'entities/builder_entity.dart';
import 'entities/build_order.dart';
import 'entities/road_order.dart';
import 'entities/worker_entity.dart';
import 'systems/path_context.dart';
import 'systems/road_system.dart';
import 'world/road_surface.dart';
import 'world/road_tile.dart';
import 'rendering/game_painter.dart';
import 'rendering/flame_renderer.dart';
import 'rendering/smoke_renderer.dart';
import 'core/constants.dart';
import 'buildings/building_entity.dart';
import 'buildings/building_renderer.dart';
import 'rendering/tile_renderer.dart';
import 'rendering/road_renderer.dart';
import 'world/day_night_cycle.dart';
import 'world/season.dart';
import 'farm/farm_tile.dart';
import 'entities/farm_farmer.dart';
import 'farm/farm_renderer.dart';
import 'world/tree_entity.dart';
import 'world/leaf_burst.dart';
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
import 'world/egg_entity.dart';
import 'world/bird_flock.dart';
import 'world/bee_flock.dart';
import 'rendering/tool_renderer.dart';
import 'world/nature_entity.dart';
import 'world/decor_entity.dart';
import 'world/grave.dart';
import 'world/reed_bed.dart';
import 'rendering/nature_renderer.dart';
import 'rendering/decor_renderer.dart';
import 'rendering/animal_renderer.dart';
import 'world/world_generator.dart';
import 'buildings/building_type.dart';
import 'ui/app_ui.dart';
import 'ui/hud.dart';
import 'ui/building_panel.dart';
import 'ui/road_panel.dart';
import 'ui/building_info_panel.dart';
import 'ui/villager_info_panel.dart';
import 'ui/villager_stats_panel.dart';
import 'ui/event_banner.dart';
import 'ui/event_choice_modal.dart';
import 'ui/petition_modal.dart';
import 'systems/petition_system.dart';
import 'systems/estate_system.dart';
import 'systems/house_system.dart';
import 'systems/chronicle.dart';
import 'systems/villager_morale.dart';
import 'ui/dev_panel.dart';
import 'ui/objective_panel.dart';
import 'ui/house_banner.dart';
import 'ui/divan_panel.dart';
import 'systems/quest_book.dart';
import 'ui/loading_screen.dart';
import 'ui/mode_button.dart';
import 'ui/expand_compass.dart';
import 'ui/discovery_minimap.dart';
import 'world/resource_box.dart';
import 'world/resource_placement.dart';
import 'world/hay_entity.dart';
import 'rendering/resource_renderer.dart';
import 'core/resources.dart';
import 'ui/main_menu_screen.dart';
import 'cutscene/cutscene.dart';
import 'cutscene/cutscene_player.dart';
import 'systems/separation_system.dart';
import 'systems/anchor_system.dart';
import 'systems/hay_processor.dart';
import 'systems/carrier_system.dart';
import 'systems/building_system.dart';
import 'systems/event_system.dart';
import 'systems/lighting_system.dart';
import 'systems/audio_manager.dart';
import 'systems/imperial.dart';
import 'ui/imperial_modal.dart';
import 'buildings/building_function.dart';
import 'characters/life_stage.dart';
import 'scene/scene_data.dart';
import 'save/save_manager.dart';
import 'ui/save_slots_screen.dart';
import 'ui/settings_model.dart';

// `_VillageSceneState` part-of bölmeleri — her dosya konsept bazında bir
// alan (yerleştirme, tick döngüsü, world helper'ları, UI, vs).
part 'scene/scene_scenarios.dart';
part 'scene/scene_npc_activity.dart';
part 'scene/scene_npc_routine.dart';
part 'scene/scene_reed.dart';
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
part 'scene/scene_divan.dart';
part 'scene/scene_council.dart';
part 'scene/scene_fire.dart';
part 'scene/scene_funeral.dart';
part 'scene/scene_wedding.dart';
part 'scene/scene_chronicle.dart';
part 'scene/scene_reactions.dart';
part 'scene/scene_flow.dart';
part 'scene/scene_save.dart';
part 'scene/scene_personality.dart';
part 'scene/scene_conflict.dart';
part 'scene/scene_imperial.dart';
part 'scene/scene_merchant.dart';
part 'scene/scene_land.dart';

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

  // Aktif oyunun slot kimliği + adı + (varsa) yüklenecek dünya. _loadWorld
  // null ise taze köy üretilir; doluysa o slottan kaldığı yerden devam edilir.
  Map<String, dynamic>? _loadWorld;
  String _slotId = '';
  String _slotName = 'Köy';

  void _startNew() {
    setState(() {
      _loadWorld = null;
      _slotId = SaveManager.instance.newSlotId();
      _slotName = 'Köy';
      _inGame = true;
      _gameKey++;
    });
  }

  Future<void> _continue(SaveSlotMeta meta) async {
    final data = await SaveManager.instance.readSlot(meta.id);
    final world = data?['world'];
    if (world is! Map) {
      _startNew();
      return;
    }
    if (!mounted) return;
    setState(() {
      _loadWorld = Map<String, dynamic>.from(world);
      _slotId = meta.id;
      _slotName = meta.name;
      _inGame = true;
      _gameKey++;
    });
  }

  void _exitGame() => setState(() => _inGame = false);

  @override
  Widget build(BuildContext context) {
    if (_inGame) {
      return VillageScene(
        key: ValueKey(_gameKey),
        onExitToMenu: _exitGame,
        initialWorld: _loadWorld,
        slotId: _slotId,
        slotName: _slotName,
      );
    }
    return MainMenuScreen(onNewGame: _startNew, onContinue: _continue);
  }
}

// ─── MAIN SCENE ──────────────────────────────────────────────────────────────

/// Debug/capture hook: true iken yeni oyun açılış sinematiğini + ateş-yerleştirme
/// modunu atlar, sim doğrudan akar (scene_capture_main.dart bunu set eder).
bool kCaptureMode = false;
double kCaptureZoom = 1.0;
int kCaptureCarve = 0; // capture: başlangıçta bu kadar halka ön-hattı "oy" (kütük/recede demo)
bool kCaptureSceneReady = false; // asset yüklenip sahne hazır olunca true (harness bekler)

class VillageScene extends StatefulWidget {
  final VoidCallback? onExitToMenu;
  /// Kaldığı yerden devam için yüklenecek dünya (null = taze köy).
  final Map<String, dynamic>? initialWorld;
  /// Bu oyunun yazılacağı kayıt slotu.
  final String slotId;
  final String slotName;
  const VillageScene({
    super.key,
    this.onExitToMenu,
    this.initialWorld,
    this.slotId = '',
    this.slotName = 'Köy',
  });
  @override
  State<VillageScene> createState() => _VillageSceneState();
}

class _VillageSceneState extends State<VillageScene>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  // ── part-of yardımcısı: setState @protected olduğundan extension'lardan
  // doğrudan çağrılamıyor. Bu wrapper sayesinde scene_*.dart part dosyaları
  // setStateHere(() {...}) ile state mutate edebilir.
  void setStateHere(VoidCallback fn) => setState(fn);

  // ── Game loop ──────────────────────────────────────────────────────────────
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  final _rng = Random();
  double _time = 0;

  // ── Kamera sarsıntısı (juice) — sarsıcı olaylarda kısa titreşim ─────────────
  // SettingsModel.shakeOnEvents kapalıysa hiç tetiklenmez. addCameraShake ile
  // kurulur, her frame söner; buildGameCanvas kamerayı bu offset'le çizer.
  double _shakeMag = 0;
  double _shakeTime = 0;
  double _shakeDur = 0.5;

  // ── Şimşek flash (fırtınada) — şekilsiz, beyaz, yumuşak gök parlaması ───────
  /// Anlık flash yoğunluğu (0..1) — buildLightningFlash beyaz overlay alfa'sı.
  double _lightningFlash = 0;
  /// Sonraki şimşeğe kalan süre (sn). Fırtına yokken dondurulur.
  double _lightningTimer = 6;
  /// Çift çakım (flicker) için ikinci darbeye kalan süre (>0 ise bekliyor).
  double _lightningPulse = 0;
  /// Şimşekten sonra gök gürültüsüne kalan süre (>0 bekliyor) — ışık-ses gecikmesi.
  double _thunderDelay = 0;

  // ── İmparatorluk (dış tehdit / vergici askerî heyet) ───────────────────────
  /// İmparatorlukla ilişki (0..1) — pazarlık şansı + talep sertliği + sıklık.
  double _imperialFavor = 0.5;
  /// Bir sonraki ziyarete kalan süre (sim sn). İlk ziyaret için gecikmeli.
  double _imperialTimer = 6.0 * kGameDaySeconds;
  /// Aktif talep (null = ziyaret yok). Non-null iken sim duraklar + modal açık.
  ImperialDemand? _imperialDemand;

  /// Fiziksel asker heyeti — köye formasyonla yürüyen geçici varlıklar (bkz.
  /// scene_imperial). Köyün sakini DEĞİL; kayda yazılmaz, nüfusa karışmaz.
  final List<ImperialSoldier> _soldiers = [];
  /// Heyet ziyaretinin evresi — yaklaşma/pazarlık/ayrılış makinesi.
  ImperialVisitPhase _imperialPhase = ImperialVisitPhase.idle;
  /// Formasyon çapası (komutanın hedefi) — yaklaşırken parley'e, ayrılırken
  /// çıkışa doğru kayar; askerler buna göre slotlanır.
  double _impAnchorCol = 0, _impAnchorRow = 0;
  /// Son yürüyüş yönü (formasyon slotlarını döndürmek için) — normalize.
  double _impDirX = 0, _impDirY = 1;
  /// Pazarlık noktası (köy eşiği) ve çıkış/giriş köşesi.
  double _impParleyCol = 0, _impParleyRow = 0;
  double _impExitCol = 0, _impExitRow = 0;
  /// Yaklaşma anında ölçülen refah — ayrılışta sonraki ziyaret aralığı için.
  double _impProsperity = 0;
  /// Bu ziyaret şiddetle bitti mi (reddetme / direniş ezilmesi) → ayrılış yerine
  /// önce köy merkezine YAĞMA dalışı (raiding evresi).
  bool _imperialRaid = false;
  /// Darbeyle düşecek kurbanlar — karar anında seçilir ama askerler merkeze
  /// VARINCA `startDying` çağrılır (ölüm darbe anıyla senkron).
  final List<VillagerEntity> _imperialRaidVictims = [];
  /// Yağma dalışında darbe vuruldu mu (bir kez) + dalış/bekleyiş sayacı.
  bool _impStruck = false;
  double _impRaidTimer = 0;
  /// Yağma dalış hedefi (köy merkezi, karaya sabit).
  double _impRaidCol = 0, _impRaidRow = 0;

  // ── Kayıt (otomatik + manuel) ───────────────────────────────────────────────
  /// Bu oyunun yazıldığı kayıt slotu.
  late final String _slotId = widget.slotId;
  late final String _slotName = widget.slotName;
  /// Periyodik otomatik kayıt için gerçek-zaman (wall clock) birikimi.
  double _autoSaveAccum = 0;
  static const double _kAutoSaveInterval = 30.0; // sn (gerçek zaman)
  /// Aynı anda iki yazım çakışmasın diye basit kilit.
  bool _saving = false;

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
  /// Gezgin tüccarlar — köyün sakini DEĞİL, arada gelip giden ambiyans (bkz.
  /// scene_merchant). Nüfusa/eve/dilekçeye karışmaz; kayda yazılmaz.
  final List<MerchantEntity> _merchants = [];
  /// Sonraki tüccar ziyaretine kalan süre (sim-saniye). _tickMerchants yönetir.
  double _merchantTimer = 0.7 * kGameDaySeconds;
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
  // ── Ateş yakıtı (scene_fire) ───────────────────────────────────────────────
  // Ateş artık beslenmek ister: yakıt tükenir, ateşçi odun taşır, odun
  // bittiyse söner → köy çapı huzursuzluk + dilekçe.
  bool _fireWasBurning = true;            // sönme/yeniden yanma geçişi için
  double _firekeeperScan = 0;             // ateşçi atama poll sayacı
  VillagerEntity? _firekeeper;            // o an ateşe odun taşıyan köylü
  bool _firekeeperLoaded = false;         // ateşçi odunu aldı mı (görsel + teslim)
  double _firekeeperGiveUp = 0;           // ulaşamazsa görevi bırakma sim zamanı
  // Odun azalma uyarısı için histerez: stok sağlıklı seviyeye çıkmadan uyarı
  // çıkmaz; bir kez çıkınca tekrar sağlığa dönene dek susar (spam önler).
  bool _woodHealthy = false;
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

  // ── Kamera "reach" (ulaşılabilir bölge) ──────────────────────────────────────
  // Reveal = ZOOM KISITLAMASI: kamera bu tile-kutusunun dışını gösteremez →
  // gerçek harita kenarı asla kadraja girmez ("havada yüzen ada" yok). Radius
  // zamanla büyür (hikâye beat'leri → organik); merkez = harita ortası (köy orada
  // doğar). scene_input._clampCamera uygular; _minZoomForReach zoom-out'u sınırlar.
  static const double _kMaxZoom = 4.0;
  static const double _kReachStart = 14.0;  // başlangıç zoom uzaklığı (büyük=uzak)
  static const double _kReachMax   = 32.0;  // kenarda hep ~8 tile tampon kalır
  final double _reachCx = kCols / 2;   // reach merkezi (spawn = harita ortası)
  final double _reachCy = kRows / 2;
  double _reachRadius = _kReachStart;  // hikâye beat'leri + organik ile büyür
  bool _cameraCentered = false;        // ilk geçerli frame'de spawn'a ortala
  // "Dünya açılıyor" anı: reach genişlerken oyuncu TAM zoom-out'a yapışıksa
  // kamerayı yumuşakça geriye bırakırız (scene_land._updateLandExpansion).
  double _lastMinZoom = 0.0;

  // ── Placement ──────────────────────────────────────────────────────────────
  BuildingType? _placing;
  (int, int)? _ghost;
  // İnşa paleti seçili kategori sekmesi (alt çubuk). Civic = ateş/belediye ile başla.
  BuildCategory _buildCategory = BuildCategory.civic;
  // Akıllı yerleştirme: hayalet geçersiz tile üstündeyse SEBEP (örn. "Yakında
  // ağaç yok"); geçerli/placing yokken null. Hover'da güncellenir.
  String? _placeReason;
  // Çoklu dikim: tek tık → bir bina kur + seçimi bırak. Basılı tutup sürükle
  // (long-press) → bu mod açılır, dokunulan her tile'a bina dikilir; bırakınca
  // seçim bırakılır. _placeStrokeTiles aynı tile'a iki kez denemeyi engeller.
  bool _multiPlace = false;
  final Set<(int, int)> _placeStrokeTiles = {};
  // Tutup-bırak: oyuncunun sürüklediği köylü (null = yok). Sürükleme sırasında
  // tick onu dondurur, imleci takip eder; bırakınca normale döner.
  VillagerEntity? _draggedVillager;
  bool _dragMovedVillager = false;
  Size _viewSize = Size.zero;

  // ── Hover etiketi (bina/NPC üstüne gelince imleç yanında küçük kart) ────────
  String? _hoverTitle;
  String? _hoverSub;
  Offset? _hoverPos;

  // ── Day/Night ──────────────────────────────────────────────────────────────
  final DayNightCycle _cycle = DayNightCycle();

  // ── Farm ───────────────────────────────────────────────────────────────────
  final List<FarmTile> _farmTiles = [];
  final List<FarmFarmer> _farmers = [];

  // ── Trees ──────────────────────────────────────────────────────────────────
  final List<TreeEntity> _trees = [];

  // ── Arazi / vahşi orman (scene_land) — "Nefes Alan Orman" ───────────────────
  // Köy sol-üst küçük bir açıklıkta başlar; harita geri kalanı vahşi ORMAN =
  // tek engel. Açıklığa komşu "ön hat" halkasında gerçek kesilebilir ağaçlar
  // (TreeEntity.isWild) durur; derin orman entity'siz kanopidir. Oduncular ön
  // hattı yer → devrilen ağacın tile'ı açılır, orman içeri bir halka çekilir.
  // Eski "vahşi orman / sis" reveal'ından kalıntı setler — zoom-reveal modelinde
  // HEP BOŞ (reveal = kamera kısıtı, örtü yok). Placement gate / obstacle /
  // painter guard'ları boş-guard'la kendiliğinden devre dışı. Tam alan temizliği
  // ayrı refactor: [scene_land].
  final Set<(int, int)> _cleared       = {};
  final Set<(int, int)> _wilderness    = {};
  final Set<(int, int)> _wildTreeTiles = {};
  final int _forestVersion = 0;              // painter repaint tokeni (sabit)
  final List<LeafBurst> _leafBursts = [];    // devrilen ağaç yaprak patlaması (fx)
  // Otonom açılım yön nudge'ı: null → köy kütlesine doğru (varsayılan); set ise
  // o yöne bias'lı açılır. Pusula UI (expand_compass) set eder.
  (double, double)? _expandDir;

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
  // Ateş etrafı saz yatakları — evsizler biçtiği sazla kurar, geceleri uyur.
  final List<ReedBed> _reedBeds = [];
  double _reedScan = 0; // _tickReed throttle sayacı

  // Kilometre taşı bildirimleri — bir kez tetiklenir.
  int _lastPopMilestone = 0;
  bool _firstReedBedShown = false;

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
  /// Kümeslerin bıraktığı görünür yumurtalar (toplan→food / çatla→civciv).
  final List<EggEntity> _eggs = [];

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
  /// Hayvan doğum/ölüm sayaçları — zümre morali beslemesi (scene_estates)
  /// bunları tüketir: doğum Emekçi moralini ↑, ölüm/açlık ↓.
  int _animalBirthsPending = 0;
  int _animalDeathsPending = 0;

  /// Oynayan sinematik (null = yok). Açılış/kademe/final/kriz hepsi buradan.
  /// Non-null iken sim duraklar (scene_tick) + tam ekran CutscenePlayer overlay.
  Cutscene? _activeCutscene;
  /// Köyün hikâye güncesi (kronik) — büyük anlar + başarımlar, yapısal kayıtlar.
  /// "Hikâye" panelinden okunur ([buildStoryButton]/[buildStoryPanel]). `_chronicle`
  /// ile yazılır; başarımlar `_award` ile (milestone:true). Kalıcı (kaydedilir).
  final List<ChronicleEntry> _storyLog = [];
  bool _storyPanelOpen = false;
  /// Köy Nüfus Defteri (istatistik) modalı açık mı — HUD'daki nüfus butonundan.
  bool _statsPanelOpen = false;
  /// Bir kez kazanılan başarımların id kümesi — tekrar tetiklenmez (kaydedilir).
  final Set<String> _achievedMilestones = {};
  /// Kıtlık sinematiği bir kez gösterildi mi (nadir kalsın).
  bool _famineShown = false;
  /// Hangi kademeler için sinematik oynatıldı (tekrar oynamasın).
  final Set<int> _tierCutscenesShown = {};
  /// Açılışta oyuncunun verdiği köy adı (kimlik/günce; oynanışa etki yok).
  String _villageName = 'Köy';
  /// Açılış sinematiği bitince oyuncu ateş yerini haritada seçmeli mi.
  bool _introPlaceFire = false;

  // ── Düğün yaşam döngüsü (scene_wedding) ──────────────────────────────────
  /// Şu an kur yapan/nişanlı çift — aynı evde, karşı cins, kan bağı yok, ikisi
  /// de henüz evlenmemiş. Kur olgunlaşınca düğün dilekçesi bunlara bağlı sunulur.
  VillagerEntity? _brideElect;
  VillagerEntity? _groomElect;
  /// Kur olgunlaşma sayacı (sn) — 0'a inince düğün dilekçesi sunulur.
  double _courtshipTimer = 0;
  /// Kur taraması throttle'ı.
  double _weddingScan = 0;
  /// Düğün dilekçesi sunulurken bağlanan çift (resolution bunları sahneler).
  (VillagerEntity, VillagerEntity)? _weddingCouple;

  /// Yaşam-evresi geçiş taraması throttle'ı (reşit oluş/yaşlanma → yaşam öyküsü).
  double _lifeStoryScan = 0;
  /// İlk ateş kurulunca "ateş yakma" sinematiği oynatılsın mı (bir kez).
  bool _firstFirePending = false;
  /// Sinematik kapandıktan sonra kısa süre canvas yerleştirmesini yok say —
  /// "ilerle" için atılan artçı dokunuşun ateşi kazara kurmasını önler.
  double _placeGuardUntil = 0;

  /// Açılış sinematiğinde köye ad verildi — kimlik + günce (oynanışa etkisiz).
  void _onVillageNamed(String name) {
    setStateHere(() {
      _villageName = name;
      _chronicle('Köye bir ad verildi: "$name"', icon: '🏷️');
    });
  }

  /// Sinematik bittiğinde — overlay'i kapat; açılışsa oyuncuyu ateş yeri
  /// seçimine (gerçek harita) yönlendir.
  void _onCutsceneDone() {
    setStateHere(() => _activeCutscene = null);
    if (_introPlaceFire) {
      _introPlaceFire = false;
      _firstFirePending = true;
      setStateHere(() => _placing = BuildingType.firepit);
      _placeGuardUntil = _time + 0.7; // artçı "ilerle" dokunuşunu yut
      _showNotification('🔥 Maple: İlk ateş için bir yer seç');
    }
  }
  /// Geçici moral etkileri — politika olaylarından (göçmen uyumu, aile birleşimi).
  /// Her giriş (untilSim, amount). _time geçince düşer; aktiflerin toplamı
  /// `_eventMorale`'ye eklenir.
  final List<({double untilSim, double amount})> _policyMoraleEffects = [];

  /// Kararların mirası — büyük yönetişim kararlarının köy ruhunda bıraktığı
  /// KALICI iz (geçici nudge'ın aksine sönmez). Milestone fx'ler birikir
  /// ([_legacyOf]), ±0.12 ile sınırlı (cozy: hükmün ağırlığı hissedilir ama
  /// morali domine etmez). Moral hedefine + HUD tooltip'e + Divan'a yansır.
  double _governanceLegacy = 0;

  // ── Resources ─────────────────────────────────────────────────────────────
  final List<ResourceBox> _resourceBoxes = [];
  final List<HayEntity> _hayEntities = [];
  double _carrierTimer = 0.0;

  /// Nüfus yiyecek tüketimi için kesirli birikim (≥1 olunca stoktan düşülür).
  double _foodHunger = 0.0;

  // Gün sayacı — timeOfDay 1.0'ı geçip sardığında artar.
  int _dayCount = 1;
  double _lastTimeOfDay = 0.0;

  /// Aktif mevsim — gün sayacından türetilir (ayrı state yok, save/load bedava).
  Season get _season => seasonForDay(_dayCount);

  /// Mevsim dönümünü yakalamak için son görülen mevsim. null → ilk tick'te
  /// sessizce kurulur (yüklemede/başlangıçta sahte olay tetiklenmez).
  Season? _lastSeason;

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

  // Köylülerin ortalama BİREYSEL morali (0..1) — scene_estates._tickVillagerMorale
  // her tick günceller; köy moraline (moraleTarget) ve panele beslenir.
  double _avgIndividualMorale = 0.6;

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

  // ── Olay mayalanması (omen) — scene_events ──────────────────────────────────
  // Olay ANINDA patlamaz: önce birkaç saniyelik diegetik uyarı (haberci metni +
  // hafif fx ön-titreşimi + köy tedirginliği) yaşanır, sonra olay vurur. "Yoktan
  // belirme" hissini kırar — oyuncu geleni sezer, hatta hazırlanır.
  EventOutcome? _omenEvent;
  double _omenLeft = 0;

  // ── Dilekçe / Meclis (scene_petitions) ─────────────────────────────────────
  // Ambient yönetişim: köy periyodik dilekçe sunar, HUD'da mühür belirir.
  // Modal açıkken oyun DURMAZ (ambient — _pendingChoice'tan farkı bu).
  Petition? _pendingPetition;
  bool _petitionModalOpen = false;
  // Mühlet doldu → modal zorla açıldı, sim duraklı. Köy artık yanıt bekliyor;
  // bu modunda boşluğa dokunarak kapatılamaz (görmezden gelmek imkânsız).
  bool _petitionForced = false;
  double _petitionTimer = 1.0 * kGameDaySeconds; // ilk dilekçe ~1 oyun günü sonra
  double _petitionDeadline = 0;
  // Zincir: tetiklenmiş takip dilekçeleri (id + ne zaman geleceği sim time).
  final List<({String id, double fireAtSim})> _petitionFollowUps = [];
  // Hafıza: çözülen dilekçe id → cooldown sim time (aynısı hemen random çıkmasın).
  final Map<String, double> _petitionCooldowns = {};
  // Köyün kalıcı hafızası: geçmiş kararların bıraktığı bayraklar (ör. 'cult.active').
  // Dilekçeler bunu okuyup dallanır; köyün "öyküsü" burada birikir.
  final Set<String> _villageMemory = {};
  // Bekleyen dilekçeyi GETİREN gerçek köylü (rastgele değil — kim olduğu bilinir).
  // Modal portresinde gösterilir; tıklanınca bilgi/aile paneli açılır.
  VillagerEntity? _petitionAuthor;

  // ── Meclis (proaktif yönetişim — scene_council) ────────────────────────────
  // Oyuncu AJANSI: Divan'dan meclisi çağırır → mayalanan bir gerilime PATLAMADAN
  // önce, kendi şartlarında müdahale eder (dilekçeyi beklemek yerine). Council
  // oturumu oyuncu-başlatımlıdır; ambient (oyun durmaz), istenince dağıtılır.
  // Bir seçenek uygulanınca kısa süre meclis "dinlenir" (_councilCooldownUntil).
  Petition? _councilSession;            // != null → meclis modal'ı açık
  VillagerEntity? _councilSpeaker;      // meclise çağrılan sözcü (portre + tepki)
  double _councilCooldownUntil = 0;     // bu sim time'a kadar yeni meclis yok

  // ── Haneler (soylar) — köyün politik birimi (eski 4-zümre sistemi söküldü;
  // `Estate` enum yalnız meslek-sınıflandırması olarak kaldı). Her köylü
  // surname'iyle bir haneye ait; hane üye moralinden doğar/güçlenir; dilekçe/
  // ferman/olay kararları hanelerin mood+sway'ini oynatır.
  final HouseSystem _houses = HouseSystem();
  /// Küskün hane postürü poll sayacı — ~5s aralıkla diegetik somurtma.
  double _estateMoodScan = 0;
  /// Köyün kimliği = baskın hanenin baskın hizbi; kimlik mekanik bonuslarını
  /// (_identityFarmMul / _identityYieldMul / _identityFoodMul /
  /// _identityMoraleBonus) besler. null = baskın hane yok (nötr, "Dengeli Köy").
  /// `_updateVillageIdentity` (scene_estates) günceller. Kaydedilmez (baskın
  /// haneden yüklemede yeniden türer).
  Estate? _identityEstate;

  // Geliştirici test paneli açık mı.
  bool _devPanelOpen = false;

  // Divan — köyün yönetişim merkezi paneli açık mı (zümre nabzından açılır).
  // Salt-okunur gösterge; oyun durmaz. scene_world reset'te kapanır.
  bool _divanOpen = false;

  // Ana menüye dönüş onay modal'ı açık mı.
  bool _exitConfirmOpen = false;

  // Kan davası yargısı onay bekliyor mu — (hedef köylü, idam mı/sürgün mü).
  // null = kapalı. scene_ui.buildJudgmentConfirm bunu okur.
  (VillagerEntity, bool)? _pendingJudgment;

  // Köy Defteri paneli daraltılmış mı (oyuncu küçültebilir).
  bool _objectivesCollapsed = false;
  // Zümre Nabzı tabelası daraltılmış mı (sağ kenar — Görevler ile simetrik).
  bool _estateCollapsed = false;
  // Alt-sol menü kümesi (menü/kaydet/📖) açık mı — gear ile aç-kapa, varsayılan kapalı.
  bool _menuClusterOpen = false;

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

  // Kişisel anlar (yıldönümü) tarama sayacı — scene_personality.
  double _annivScan = 0;

  // "Çağrısını buldu" (genç→yetişkin meslek keşfi) tarama sayacı.
  double _callingScan = 0;

  // Çekişme/kavga tarama sayacı — scene_conflict (nadir, faktöre bağlı).
  double _conflictPollSec = 0;
  // Gerginlik uyarısı throttle (sn) — köy gerginliği yükselince oyuncuya
  // diegetik herald gösterilir (kavga patlamadan önce görünür kılınır).
  double _tensionHeraldSec = 0;

  // Konfor talebi sayacı — köy ara sıra surplus konfor malını şölene çevirir
  // (bal/fazla yiyecek → moral). Pozitif sink, ceza yok. scene_firepit_gather.
  double _comfortTimer = 1.2 * kGameDaySeconds;

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

  // PERF: HUD ayrı, DÜŞÜK frekanslı notifier — GameHUD ağacı pahalı ve verisi
  // (kaynak/nüfus/saat) yavaş değişir. Canvas/gökyüzü 60fps (_frame) kalır,
  // HUD ~10Hz rebuild olur (_hudFrame). _hudAccum gerçek-zaman biriktirir.
  final ValueNotifier<int> _hudFrame = ValueNotifier<int>(0);
  double _hudAccum = 0;
  static const double _kHudInterval = 0.1; // sn (≈10Hz)

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
    WidgetsBinding.instance.addObserver(this);
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

    // Kayıttan devam → dünyayı kaldığı yerden kur; yoksa taze köy üret.
    final save = widget.initialWorld;
    if (save != null) {
      restoreWorld(save);
    } else {
      _generateWorld();
      if (!kCaptureMode) {
        // Yeni oyun → açılış sinematiği; bitince oyuncu ateş yerini seçer.
        _activeCutscene = kOpeningCutscene;
        _introPlaceFire = true;
        _chronicle('Köyün kuruluşu', icon: '🔥', milestone: true);
      } else {
        // Zoom-reveal: kamera clamp'i (_clampCamera) zaten reach'e göre
        // ortalayıp zoom'u sınırlar; capture ekstra bir şey yapmaz.
        _zoom = kCaptureZoom;
      }
    }
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
      kCaptureSceneReady = true; // capture harness bunu bekler
    });
    // Ses motoru — döngüler sessiz başlar, tick ortamı yükseltir.
    AudioManager.instance.start();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    AudioManager.instance.dispose();
    _ticker.dispose();
    _frame.dispose();
    _hudFrame.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Uygulama arka plana/kapanışa giderken sessizce kaydet — emek kaybı olmasın.
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.detached) {
      _saveNow();
    }
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

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _saveNow(); // menüye dönerken sessizce kaydet
          widget.onExitToMenu?.call();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF234E6A), // deniz tabanı (flash önler)
        // StackFit.expand ŞART: eski tam-ekran "gökyüzü" non-positioned katmanı
        // kaldırıldı → geriye kalan büyük çocuklar hep Positioned.fill (Stack
        // boyutuna katkısız). Loose fit'te Stack, pasif panellerin SizedBox.shrink
        // non-positioned çocuklarının boyutuna (≈0) çöker → tüm sahne görünmez
        // olur, arkadaki deniz tabanı rengi kalır. expand → Stack ekranı doldurur.
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Gökyüzü widget katmanı KALDIRILDI — adayı çevreleyen deniz artık
            // painter içinde (OceanRenderer) çizilir; atmosfer/güneş/bulut orada.
            Positioned.fill(child: buildGameCanvas()),
            // Şimşek flash — dünya üstünde, HUD altında; şekilsiz beyaz parlama.
            Positioned.fill(
              child: RepaintBoundary(
                child: ListenableBuilder(
                  listenable: _frame,
                  builder: (_, _) => IgnorePointer(
                    child: _lightningFlash <= 0.001
                        ? const SizedBox.shrink()
                        : ColoredBox(
                            color: Color.fromRGBO(
                                255, 255, 255, _lightningFlash.clamp(0.0, 0.32))),
                  ),
                ),
              ),
            ),
            Positioned.fill(child: buildHudLayer()),
            buildBottomToolbar(),
            buildExpandCompass(), // otonom açılım yön pusulası (orman varken)
            buildDiscoveryMinimap(), // keşif mini-haritası (öğrenme kanalı)
            // Akıllı yerleştirme: hayalet geçersiz tile üstündeyse sebep çubuğu.
            if (_placing != null && _placeReason != null) buildPlaceReason(),
            // Bekleyen dilekçe mührü — HUD üstünde, modal kapalıyken (ambient).
            if (_pendingPetition != null && !_petitionModalOpen)
              buildPetitionSeal(),
            // Divan mührü — yönetişimin KALICI kapısı (sol üst). Sağ-dock paneller
            // açıkken bile durur: Meclis artık hiçbir seçimle ekrandan kaybolmaz.
            buildDivanSeal(),
            if (_selectedBuilding != null) buildSelectedBuildingPanel(),
            if (_selectedVillager != null) buildSelectedVillagerPanel(),
            // Karar bekleyen olay — modal açıkken simülasyon dt = 0 (tick
            // yarıduraklatılır), oyuncu seçene kadar.
            if (_pendingChoice != null) buildEventChoiceModal(),
            // İmparatorluk vergi heyeti — karar zorunlu, sim duraklı.
            if (_imperialDemand != null) buildImperialModal(),
            // Dilekçe modal'ı — oyunu DURDURMAZ (ambient yönetişim).
            if (_petitionModalOpen && _pendingPetition != null)
              buildPetitionModal(),
            // Meclis oturumu — oyuncunun çağırdığı proaktif karar (ambient).
            if (_councilSession != null) buildCouncilModal(),
            if (_devPanelOpen) buildDevPanel(),
            // Divan — yönetişim merkezi (gündem + gerilimler + köyün hâli).
            // Oyun durmaz; boşluğa dokun = kapat. Dilekçe modal'ının üstünde
            // DEĞİL (modal açıksa Divan'a değil dilekçeye odaklanılır).
            if (_divanOpen && !_petitionModalOpen) buildDivanPanel(),
            if (_exitConfirmOpen) buildExitConfirm(),
            if (_pendingJudgment != null) buildJudgmentConfirm(),
            buildEventBanner(),
            buildObjectivesPanel(),
            // Sağ-dock panel açıkken zümre bandını gizle (sağ kenar çakışmasını
            // önler — seçim paneli veya geliştirici paneli o an sağın sahibi).
            if (_selectedVillager == null &&
                _selectedBuilding == null &&
                !_devPanelOpen)
              buildEstateBanner(),
            buildSaveButton(),
            buildHoverLabel(),
            if (_notification != null) buildNotificationToast(),
            if (_placing != null ||
                _farmMode ||
                _lumberMode ||
                _mineMode ||
                _placingRoad != null)
              buildHintRibbon(),
            if (_storyPanelOpen) buildStoryPanel(),
            if (_statsPanelOpen) buildStatsPanel(),
            // Sinematik — her şeyin üstünde, tam ekran. Sim duraklı.
            if (_activeCutscene != null)
              Positioned.fill(
                // Sinematik kimliğine bağlı key — sahne değişince oynatıcı
                // state'i (shotIndex/done) sıfırdan kurulur; aynı widget'ın
                // yeniden kullanılıp eski/karışık state ile yanlış oynamasını
                // (ör. art arda iki kez görünme) engeller.
                child: CutscenePlayer(
                  key: ValueKey(identityHashCode(_activeCutscene)),
                  cutscene: _activeCutscene!,
                  onDone: _onCutsceneDone,
                  onNameChosen: _onVillageNamed,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
