import 'dart:collection';
import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../buildings/building_design.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';
import '../core/constants.dart';
import '../entities/build_order.dart';
import '../entities/merchant_entity.dart';
import '../entities/road_order.dart';
import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';
import '../entities/worker_entity.dart';
import '../farm/farm_renderer.dart';
import '../farm/farm_tile.dart';
import '../systems/events/event_system.dart';
import '../systems/npc/footstep_trail.dart';
import '../systems/npc/villager_act.dart';
import '../systems/npc/villager_mind.dart';
import '../systems/world/decor_population.dart';
import '../systems/world/hearth_warmth.dart';
import '../systems/world/lighting_system.dart';
import '../systems/world/road_system.dart';
import '../systems/world/winter.dart';
import '../world/animal_entity.dart';
import '../world/bee_flock.dart';
import '../world/bird_flock.dart';
import '../world/decor_entity.dart';
import '../world/egg_entity.dart';
import '../world/grave.dart';
import '../world/harman_site.dart';
import '../world/hay_entity.dart';
import '../world/leaf_burst.dart';
import '../world/loot_cache.dart';
import '../world/mine_node.dart';
import '../world/nature_entity.dart';
import '../world/reed_bed.dart';
import '../world/resource_box.dart';
import '../world/resource_placement.dart';
import '../world/road_surface.dart';
import '../world/season.dart';
import '../world/tree_entity.dart';
import '../world/world_landmark.dart';
import 'animal_renderer.dart';
import 'character_renderer.dart';
import 'decor_renderer.dart';
import 'flame_renderer.dart';
import 'grave_renderer.dart';
import 'mine_renderer.dart';
import 'nature_renderer.dart';
import 'ocean_renderer.dart';
import 'particle_renderer.dart';
import 'prop_renderer.dart';
import 'reed_bed_renderer.dart';
import 'resource_renderer.dart';
import 'road_renderer.dart';
import 'smoke_renderer.dart';
import 'snow_field.dart';
import 'snow_ground_renderer.dart';
import 'tile_renderer.dart';
import 'tool_renderer.dart';
import 'tree_renderer.dart';
import 'vehicle_renderer.dart';
import 'water_renderer.dart';
import 'wind.dart';
import 'world_landmark_renderer.dart';

part 'game_ambient.dart';
part 'game_surface_motion.dart';
part 'game_drawables.dart';
part 'game_drawables_building.dart';
part 'game_drawables_villager.dart';
part 'game_fx.dart';
part 'game_painter_ground.dart';
part 'game_painter_lighting.dart';
part 'game_paints.dart';

/// Retina/4K tam ekranlarda tam çözünürlüklü offscreen katmanlar raster
/// bütçesini tek başına aşabiliyor. Telefonu yalnız yüksek DPR'ı yüzünden bu
/// yola sokmamak için hem fiziksel piksel hem kısa kenar koşulu aranır.
const double kReducedEffectsPhysicalPixelThreshold = 2000000;

double _smoothUnit(double value) {
  final t = value.clamp(0.0, 1.0);
  return t * t * (3.0 - 2.0 * t);
}

bool useReducedEffectsForViewport(Size logicalSize, double devicePixelRatio) {
  if (logicalSize.isEmpty ||
      !logicalSize.width.isFinite ||
      !logicalSize.height.isFinite ||
      !devicePixelRatio.isFinite ||
      devicePixelRatio <= 0) {
    return false;
  }
  if (logicalSize.shortestSide < 700) return false;
  final physicalPixels =
      logicalSize.width *
      logicalSize.height *
      devicePixelRatio *
      devicePixelRatio;
  return physicalPixels >= kReducedEffectsPhysicalPixelThreshold;
}

/// Karakterin ayağı altında ince yatay elips. (sx, sy) = feet pozisyonu
/// (her character drawable'da gridToScreen sonucu). [scale] karakterin
/// efektif çizim ölçeği (kCharScale × yaşam-evresi) — gölge boyu onunla orantılı.
void _drawCharShadow(
  Canvas canvas,
  double sx,
  double sy, [
  double scale = kCharScale,
]) {
  final w = 34 * scale;
  final h = w * 0.34;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(sx, sy + 1), width: w, height: h),
    _pShadow,
  );
}

/// Ağaç gövdesi tabanında elips — TreeType'a göre genişlik.
/// growthScale fidan büyüme oranı.
void _drawTreeShadow(
  Canvas canvas,
  double cx,
  double cy,
  double widthScale,
  double growthScale,
  double fellProgress,
  int fallDirection,
) {
  final baseW = widthScale * growthScale * 1.25;
  final fall = fellProgress < 0
      ? 0.0
      : ((fellProgress - 0.14) / 0.68).clamp(0.0, 1.0);
  final eased = fall * fall * (3 - 2 * fall);
  final w = baseW + 76 * growthScale * eased;
  final shift = (w - baseW) * 0.42 * (fallDirection >= 0 ? 1 : -1);
  canvas.drawOval(
    Rect.fromCenter(
      center: Offset(cx + shift, cy + 3),
      width: w,
      height: baseW * (0.34 - eased * 0.08),
    ),
    _pShadow,
  );
}

/// Bina footprint'inin yere düşen gölgesi. İki katmanlı diamond (büyük soluk
/// dış + koyu iç), blur'suz "soft edge" hissi.
///
/// Eğer [lightScreen] verilmezse (gündüz veya yakın ışık yoksa) sabit
/// güney-doğu offset kullanılır — sun shadow yaklaşımı. Verilirse ışık
/// pozisyonundan UZAKLAŞMA yönüne kaydırılır — gece ateşin/lambanın
/// karşı tarafına düşen doğal gölge. [shadowBoost] gece (karanlık arttıkça)
/// gölgenin uzunluğunu artırır.
void _drawBuildingShadow(
  Canvas canvas,
  Offset back,
  Offset left,
  Offset right,
  Offset front, {
  Offset? lightScreen,
  double shadowBoost = 0.0,
}) {
  double dx = 4.0;
  double dy = 3.0;
  if (lightScreen != null) {
    final cx = (back.dx + front.dx) * 0.5;
    final cy = (back.dy + front.dy) * 0.5;
    final ldx = cx - lightScreen.dx;
    final ldy = cy - lightScreen.dy;
    final dist = sqrt(ldx * ldx + ldy * ldy);
    if (dist > 1.0) {
      // Gölge uzunluğu: karanlık artıkça daha uzun.
      final len = 6.0 + shadowBoost * 14.0;
      dx = ldx / dist * len;
      dy = ldy / dist * len;
    }
  }
  // Dış katman (1px büyük)
  _scratchPath
    ..reset()
    ..moveTo(back.dx + dx, back.dy + dy - 1)
    ..lineTo(right.dx + dx + 1, right.dy + dy)
    ..lineTo(front.dx + dx, front.dy + dy + 1)
    ..lineTo(left.dx + dx - 1, left.dy + dy)
    ..close();
  canvas.drawPath(_scratchPath, _pBuildingShadowOuter);
  // İç katman
  _scratchPath
    ..reset()
    ..moveTo(back.dx + dx, back.dy + dy)
    ..lineTo(right.dx + dx, right.dy + dy)
    ..lineTo(front.dx + dx, front.dy + dy)
    ..lineTo(left.dx + dx, left.dy + dy)
    ..close();
  canvas.drawPath(_scratchPath, _pBuildingShadowInner);
}

// Selection/ghost/scaffold/border için ortak Path havuzu.
// paint() synchronous — Path drawn anında canvas'a yazılır, sonra mutate edebiliriz.
final Path _scratchPath = Path();

// Sahne drawable buffer'ı — her frame clear edilip yeniden doldurulur.
// Spread/sort her frame allocate yapmasın diye top-level static.
final List<_Drawable> _sceneBuffer = [];

// Occlusion AABB buffer'ı — _drawOcclusionSilhouettes içinde her frame clear
// edilip yeniden doldurulur (tek call içinde kurulup tüketilir). _sceneBuffer
// gibi top-level static → frame başına yeni List allocation'ı yok.
final List<(BuildingEntity, Rect)> _occBoxes = [];

// ─── Occlusion silhouette (C) parametreleri ─────────────────────────────────
// Bina gövde yüksekliği tahmini = footprint ekran yüksekliği * scale + base (px).
// Böylece kutunun üstü gerçek çatıya yakın olur (küçük/büyük binaya uyarlanır).
const double kOccWallScale = 1.7;
const double kOccWallBase = 26;
// Aktörün örtülme testinde kullanılan gövde nokta ofseti (ayaktan yukarı, px).
const double kOccProbeY = 46;
// Örtülen aktörün üstte yeniden çizildiği yarı saydam katman (~%40 opaklık).
final Paint _occFadePaint = Paint()..color = const Color(0x66FFFFFF);

// ─── İnşaat şeffaflığı (reveal) ──────────────────────────────────────────────
// Planlanan/yapılmakta olan bir şeyin önünde duran binalar bu opaklıkla çizilir.
// %30: silueti hâlâ okunur (bina kayboldu sanılmaz) ama arkası net görünür.
final Paint _revealFadePaint = Paint()..color = const Color(0x4DFFFFFF);
// Frame başına yeniden kurulan çalışma tamponları — allocation yok.
final Set<BuildingEntity> _fadedBuildings = {};
final Map<BuildingEntity, Rect> _revealBounds = {};

// ── Ground Picture cache ─────────────────────────────────────────────────────
// Çim+kum+border katmanı statik — her map için bir kez Picture'a kaydedilir,
// frame'lerde drawPicture ile replay edilir. Camera-bağımsız (Offset.zero ile
// render edildi, outer canvas translate ile yerleştirilir) → pan/zoom sırasında
// bile geçerli. Invalidate: groundVersion artar (yeni map) veya size değişir.
ui.Picture? _groundCache;
int _gcVersion = -1;
double _gcWidth = -1;
double _gcHeight = -1;
Season _gcSeason = Season.spring;
bool _gcSnowReady = false;

// Yollar cache — tamamlanmış road tile'ları statik (autotile mask topology'ye
// bağlı). Her road add/remove'da roadSystem.version++ → cache invalidate.
// Pending road order'lar dinamik (progress fade) → ayrı çizilir, cache dışı.
ui.Picture? _roadsCache;
int _rcVersion = -1;
double _rcWidth = -1;
double _rcHeight = -1;
double _rcZoom = -1;

// Maden binası dikdörtgenleri (col, row, cols, rows) — miner/mineNode gizleme
// kontrolü için frame başına bir kez doldurulur; her entity tüm binaları (ve
// kBuildingMeta lookup'ını) taramasın diye scratch.
final List<(int, int, int, int)> _mineRects = [];

// Static entity spatial bucket grid — decor/tree/lotus/reed/mine.
// 8-tile bucket cell, key = (col >> 3, row >> 3). Topology değişmedikçe
// viewport içinde olan bucket'lar iterate edilir; çok büyük listeler için her
// frame full scan'i atlar.
final Map<(int, int), List<DecorEntity>> _decorBuckets = {};
List<DecorEntity>? _decorBucketsSource;
int _decorBucketsVersion = -1;
int _decorBucketsLen = -1;
// Ground-flora ve depth-scene pass'leri aynı viewport taramasını paylaşır.
// paint senkron olduğu için frame başında doldurulup iki pass'te güvenle okunur.
final List<DecorEntity> _visibleDecorBuffer = [];
final Map<(int, int), List<TreeEntity>> _treeBuckets = {};
int _treeBucketsLen = -1;
final Map<(int, int), List<LotusEntity>> _lotusBuckets = {};
int _lotusBucketsLen = -1;
final Map<(int, int), List<ReedClump>> _reedBuckets = {};
int _reedBucketsLen = -1;
final Map<(int, int), List<MineNode>> _mineNodeBuckets = {};
int _mineNodeBucketsLen = -1;

// ── Lighting buffer ──────────────────────────────────────────────────────────
// Lokal ışık kaynakları (firepit, ev pencereleri, meşaleli NPC). Her frame
// _collectLights doldurulur, sonra lighting pass'ler iki kez tarar
// (karanlık deliği + sıcak halo).
class _LightInfo {
  final double sx, sy; // ekran piksel pozisyonu
  final double radius; // ekran piksel yarıçapı
  final Color warm; // halo tonu (turuncu/sarı)
  final double intensity; // 0..1 — alpha ve halo gücü
  const _LightInfo(this.sx, this.sy, this.radius, this.warm, this.intensity);
}

final List<_LightInfo> _lightBuffer = [];

// All local lights share the same seven-stop radial falloff. Building that
// gradient shader for every light in every pass is substantially more
// expensive than scaling a small pre-baked texture (see light_bench_main).
// The sprite is created lazily on the first night frame and reused forever.
ui.Image? _lightRadialSprite;
final Paint _pLightSprite = Paint()
  ..filterQuality = FilterQuality.low
  ..blendMode = BlendMode.lighten;

ui.Image _getLightRadialSprite() {
  final cached = _lightRadialSprite;
  if (cached != null) return cached;
  const side = 256;
  const radius = side / 2.0;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawCircle(
    const Offset(radius, radius),
    radius,
    Paint()
      ..shader = ui.Gradient.radial(
        const Offset(radius, radius),
        radius,
        const [
          Color(0xFFFFFFFF),
          Color(0xEBFFFFFF),
          Color(0xB5FFFFFF),
          Color(0x4DFFFFFF),
          Color(0x14FFFFFF),
          Color(0x05FFFFFF),
          Color(0x00FFFFFF),
        ],
        const [0.0, 0.15, 0.30, 0.50, 0.70, 0.85, 1.0],
      ),
  );
  final picture = recorder.endRecording();
  final image = picture.toImageSync(side, side);
  picture.dispose();
  return _lightRadialSprite = image;
}

void _drawBakedLight(
  Canvas canvas,
  double x,
  double y,
  double radius,
  Color color,
  int alpha,
) {
  final sprite = _getLightRadialSprite();
  _pLightSprite.colorFilter = ui.ColorFilter.mode(
    color.withAlpha(alpha),
    BlendMode.modulate,
  );
  canvas.drawImageRect(
    sprite,
    Rect.fromLTWH(0, 0, sprite.width.toDouble(), sprite.height.toDouble()),
    Rect.fromCircle(center: Offset(x, y), radius: radius),
    _pLightSprite,
  );
}

class VillageGamePainter extends CustomPainter {
  final List<VillagerEntity> villagers;

  /// Gezgin tüccarlar — sakin köylülerden ayrı listede çizilir ama görsel
  /// olarak [_VillagerDrawable] ile (MerchantEntity extends VillagerEntity).
  final List<MerchantEntity> merchants;

  /// İmparatorluk askerleri — dış güç heyeti; köylülerden ayrı listede ama
  /// aynı [_VillagerDrawable] ile (ImperialSoldier extends VillagerEntity,
  /// NpcCostume.imperial kostümü çizilir).
  final List<VillagerEntity> soldiers;
  final List<BuildingEntity> buildings;

  final List<BuildOrder> pendingOrders;
  final RoadSystem roadSystem;
  final List<RoadOrder> pendingRoadOrders;
  final Offset camera;
  final BuildingType? ghostType;
  final BuildingDesign ghostDesign;
  final (int, int)? ghostTile;
  final bool ghostValid;
  final double time;

  /// YOL ÖNİZLEMESİ — sürüklenen (henüz döşenmemiş) güzergâh: (tile, geçerli mi).
  /// Boş liste = önizleme yok. Kaynak harcanmadan önce ne olacağı burada görünür.
  final List<((int, int), bool)> roadPreview;

  /// Önizlenen yüzey; silgi modunda null (kırmızı "kaldırılacak" işareti çizilir).
  final RoadSurface? roadPreviewSurface;

  /// [roadPreview] yerinde mutate edilen tek bir liste olduğu için içerik
  /// karşılaştırması işe yaramaz — repaint kararı bu sayaçtan verilir.
  final int roadPreviewVersion;

  /// ŞEFFAFLIK HEDEFLERİ — üzerinde inşaat/planlama olan tile'lar. Bunları ÖRTEN
  /// binalar yarı saydam çizilir, böylece hayalet bina, şantiye ve yol emri
  /// başka bir binanın arkasında kaybolmaz. Boşsa pass hiç çalışmaz (maliyetsiz).
  final Set<(int, int)> revealTiles;

  /// Day/night overlay — sahnenin üstüne çizilen vertical gradient'in
  /// üst/alt renkleri. Şafak/gün batımında üst mor-pembe, alt sıcak turuncu;
  /// gecede üst koyu lacivert, alt biraz açık tonda → atmosferik derinlik.
  final Color overlayTop;
  final Color overlayBottom;
  final double rainIntensity;

  /// 0 = puslu/default gece (current look), 1 = berrak gece. Smooth lerp ile
  /// DayNightCycle'dan gelir. Kıyı sisi yoğunluğunu azaltır → berrakta sis
  /// %55'e kadar çekilir, yıldızlar ve overlay hafiflemesi sky_widgets +
  /// cycle getter'larından gelir.
  final double nightClarity;

  /// Sahne sprite'larına BlendMode.modulate ile uygulanan "atmosfer rengi".
  /// Gece soğuk mavi mehtap, şafak şeftali, altın saat amber, öğle ~beyaz.
  /// _drawLightingPass içinde dark overlay'den önce çizilir → sprite'lar
  /// günün rengini içer (dstOut sadece karanlığı eritirken).
  final Color ambientTint;

  /// 0 = identity (sprite dokunulmaz), 1 = tam modulate. Painter strength=0'da
  /// pass'i atlar; aradaki değerler için tint'i beyaza lerp ederek uygular.
  final double ambientStrength;

  final List<FarmTile> farmTiles;
  final List<HarmanSite> harmanSites;

  /// Çoklu tarla seçim önizlemesi: (c1, r1, c2, r2)
  final (int, int, int, int)? farmSelection;

  final List<TreeEntity> trees;

  /// Sahip olunan (açık) kara — sis kapsamı bunun dışını örter.
  final Set<(int, int)> cleared;

  /// Vahşi orman tile'ları (scene_land) — entity'siz yoğun kanopi olarak çizilir.
  final Set<(int, int)> wilderness;

  /// Sınır halkasındaki gerçek ağaç tile'ları — kanopi bunların üstüne çizmesin
  /// (orada zaten _TreeDrawable var; çift çizim engeli).
  final Set<(int, int)> wildTreeTiles;

  /// Devrilen ön-hat ağacı yaprak patlamaları (kısa ömürlü fx).
  final List<LeafBurst> leafBursts;

  /// Oduncu kulübesinin otonom NPC'leri — woodcutter'dan ayrı tip.
  /// Oduncu alan seçim önizlemesi: (c1, r1, c2, r2)
  final (int, int, int, int)? lumberSelection;

  final List<MineNode> mineNodes;

  /// Madenci alan seçim önizlemesi
  final (int, int, int, int)? mineSelection;

  final Set<(int, int)> waterTiles;
  final double dayLight;
  final List<LotusEntity> lotuses;
  final List<ReedClump> reeds;
  final List<BerryBush> berryBushes;
  final List<DecorEntity> decor;

  /// [decor] yerinde mutate edildiğinde spatial bucket ve repaint invalidation
  /// tokeni. Aynı listeye ekleme/silme/değiştirme yapan sahne bunu artırır.
  final int decorVersion;

  final List<WorldLandmark> landmarks;
  final List<Grave> graves;
  final List<ReedBed> reedBeds;
  final List<AnimalEntity> cows;
  final double zoom;
  final List<ResourceBox> resourceBoxes;
  final List<HayEntity> hayEntities;
  final List<EggEntity> eggs;

  /// Gömülü zulalar (Faz 4) — eşelenmiş toprak izi.
  final List<LootCache> lootCaches;

  /// Zula izinin kapanma süresi (sn) — sahneden geçer, çizim tazeliği bundan.
  final double lootFade;

  /// Suya yansıtılan gökyüzü tonu — _cycle.skyMid'den geçer.
  final Color skyReflection;

  /// Adayı çevreleyen deniz (OceanRenderer) için zaman/güneş bilgisi.
  /// _cycle'dan geçer; gökyüzü widget'ı kaldırıldı, atmosfer artık denizde.
  final double timeOfDay;
  final Season season;
  final Color sunColor;
  final double sunOpacity;
  final double moonOpacity;

  /// Ground katman cache invalidation tokeni. Bu değer değişince Picture
  /// yeniden üretilir. VillageScene yeni harita ürettiğinde artırır.
  final int groundVersion;

  /// Kanopi (vahşi orman) cache invalidation tokeni. _wilderness/_wildTreeTiles
  /// değişince (arazi açılınca / yeni map / yükleme) artar → kanopi Picture'ı
  /// yeniden üretilir.
  final int forestVersion;

  /// Dünya-uzayında ışık kaynakları. LightingSystem.collect ile üretilir;
  /// hem renderer hem oyun mantığı (gelecekteki "ışıkta mı?" sorgusu) için
  /// ortak kaynak.
  final List<LightSource> lightSources;

  /// Aktif olayların aggregate edilmiş ekran tonu (alpha > 0 ise sahnenin
  /// üstüne overlay olarak çizilir). Kuraklık sarımsı, salgın yeşilimsi vb.
  final Color eventTint;

  /// Hangi sahne efektleri aktif — renderer bunlara göre özel partikül/
  /// animasyon pass'leri çizer.
  final Set<EventFx> activeFx;

  /// Efekt başına yerel zaman çizgisi. [activeFx] görünürlük için hızlı küme,
  /// bu map ise her olayın giriş/gelişme/çıkış animasyonunu 0'dan yürütür.
  final Map<EventFx, EventFxPlayback> fxPlayback;

  /// fireOutbreak fx aktif olduğunda yanan spesifik binalar — sprite üstüne
  /// alev + yoğun duman çizilir.
  final Set<BuildingEntity> burningBuildings;

  /// Ambient gökyüzü kuş sürüleri — sahnenin üstüne, son katman olarak çizilir.
  final List<BirdFlock> birdFlocks;

  /// Ambient arı sürüleri — her arı kovanı etrafında orbit; kuşlarla aynı
  /// ekran-uzayı pass'inde çizilir, gündüz görünür/gece fade.
  final List<BeeSwarm> beeSwarms;

  /// Performans modu — true ise pahalı ambient/light effect pass'leri atlanır
  /// (fireflies, polen, kuş, bina shadow refinement, light pass detayı).
  final bool perfMode;

  const VillageGamePainter({
    required this.villagers,
    this.merchants = const [],
    this.soldiers = const [],
    required this.buildings,
    required this.pendingOrders,
    required this.roadSystem,
    this.pendingRoadOrders = const [],
    required this.camera,
    this.ghostType,
    this.ghostDesign = BuildingDesign.original,
    this.ghostTile,
    this.ghostValid = false,
    this.roadPreview = const [],
    this.roadPreviewSurface,
    this.roadPreviewVersion = 0,
    this.revealTiles = const {},
    this.time = 0,
    this.overlayTop = const Color(0x00000000),
    this.overlayBottom = const Color(0x00000000),
    this.rainIntensity = 0.0,
    this.nightClarity = 0.0,
    this.ambientTint = const Color(0xFFFFFFFF),
    this.ambientStrength = 0.0,
    this.farmTiles = const [],
    this.harmanSites = const [],
    this.farmSelection,
    this.trees = const [],
    this.cleared = const {},
    this.wilderness = const {},
    this.leafBursts = const [],
    this.wildTreeTiles = const {},
    this.lumberSelection,
    this.mineNodes = const [],
    this.mineSelection,
    this.waterTiles = const {},
    this.dayLight = 1.0,
    this.lotuses = const [],
    this.reeds = const [],
    this.berryBushes = const [],
    this.decor = const [],
    this.decorVersion = 0,
    this.landmarks = const [],
    this.graves = const [],
    this.reedBeds = const [],
    this.cows = const [],
    this.zoom = 1.0,
    this.resourceBoxes = const [],
    this.hayEntities = const [],
    this.eggs = const [],
    this.lootCaches = const [],
    this.lootFade = 1.0,
    this.skyReflection = const Color(0xFFA0C0E0),
    this.timeOfDay = 0.5,
    this.season = Season.spring,
    this.sunColor = const Color(0xFFFFF1C0),
    this.sunOpacity = 0.0,
    this.moonOpacity = 0.0,
    this.groundVersion = 0,
    this.forestVersion = 0,
    this.lightSources = const [],
    this.eventTint = const Color(0x00000000),
    this.activeFx = const {},
    this.fxPlayback = const {},
    this.burningBuildings = const {},
    this.birdFlocks = const [],
    this.beeSwarms = const [],
    this.perfMode = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ── Deniz arka planı (ekran-uzayı, zoom'dan bağımsız) ────────────────────
    // Adayı çevreleyen suluboya deniz; eski düz gök boşluğunun yerini alır.
    // Ada elması + sahne bunun üstüne çizilir, kıyı şeridi ikisini birleştirir.
    OceanRenderer.draw(
      canvas,
      size,
      time: time,
      dayLight: dayLight,
      skyMid: skyReflection,
      sunColor: sunColor,
      sunOpacity: sunOpacity,
      moonOpacity: moonOpacity,
      timeOfDay: timeOfDay,
      reducedEffects: perfMode,
    );

    // ── Zoom: dünya içeriği ekran merkezine göre ölçeklenir ──────────────────
    final cx = size.width / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(zoom, zoom);
    canvas.translate(-cx, -cy);

    // Gündüz renk gradingi — sahne sprite/zemin katmanı bir saveLayer içinde
    // ColorFilter.matrix (kontrast + doygunluk) ile işlenir. SADECE gündüz
    // platosunda (dayLight yüksek) devreye girer → gece/şafak/altın saat
    // tamamen dokunulmadan kalır (mevcut ambient grade + ışık katmanları o
    // saatleri zaten taşıyor). "Pastel" düz his değer kontrastı + doygunluk
    // eksikliğinden; bu pass onu gerçek bir grade ile çözer (alpha tweak değil).
    final dayGrade = ((dayLight - 0.55) / 0.45).clamp(0.0, 1.0);
    final useGrade = !perfMode && dayGrade > 0.01;
    if (useGrade) {
      canvas.saveLayer(
        null,
        Paint()..colorFilter = ColorFilter.matrix(_dayGradeMatrix(dayGrade)),
      );
    }

    _drawGround(canvas, size);
    // Çiçek/yonca zeminin parçası gibi davranır: tarla, yol, gölge, bina ve
    // aktörlerden önce çizilir. Böylece tatlı bir zemin detayı olarak kalır;
    // karakterlerin ve animasyonların üstüne yapışmaz.
    _collectVisibleDecor(size);
    _drawGroundFlora(canvas, size);
    _drawMud(canvas, size);
    _drawFarmTiles(canvas, size);
    _drawHarmanSites(canvas, size);
    _drawWaterFoam(canvas, size);
    // Bina gölgeleri — sahne sprite'larından ÖNCE, zemin üstüne. Bu sayede
    // hiçbir bina gölgesi başka sprite'ın üstüne taşıyamaz.
    // PerfMode: light aggregation iteration ağır; basit drop-shadow yeterli.
    if (!perfMode) _drawBuildingShadows(canvas, size);
    _drawRoads(canvas, size);
    _drawMudFootprints(canvas, size);
    _drawFootsteps(canvas, size);
    if (!perfMode && season != Season.winter && rainIntensity > 0.01) {
      _drawGroundSplashes(canvas, size, rainIntensity);
    }
    if (!perfMode) _drawRiverMist(canvas, size);
    if (farmSelection != null) _drawFarmSelection(canvas, size);
    if (lumberSelection != null) _drawLumberSelection(canvas, size);
    if (mineSelection != null) _drawMineSelection(canvas, size);
    _drawScene(canvas, size);
    _drawLeafBursts(canvas, size);
    _drawMarkedTrees(canvas, size);
    _drawMarkedMines(canvas, size);
    if (ghostType != null && ghostTile != null) {
      _drawGhost(canvas, size);
    }
    // Yol önizlemesi sahneden SONRA — bina arkasında kaybolmasın.
    _drawRoadPreview(canvas, size);

    if (useGrade) canvas.restore();
    canvas.restore();

    // ── Ekran uzayı efektleri (zoom'dan etkilenmez) ──────────────────────────
    // Çok hafif KENAR TÜLÜ — kamera reach dışını göstermez, bu tül ekranın en
    // kenarında zarif bir atmosfer solması bırakır ("ulaşabildiğin dünyanın
    // kenarı" hissi). Aydınlık/inci (koyu sis DEĞİL); lighting'ten ÖNCE ki gece
    // doğal kararsın.
    _drawEdgeHaze(canvas, size);
    // Lighting pass: gradient karanlık + vignette + lokal ışık + sıcak halo.
    _drawLightingPass(canvas, size);
    // PerfMode: ambient partikül pass'lerini atla (her frame yüzlerce circle).
    if (!perfMode) {
      _drawLampMoths(canvas, size);
      _drawFireflies(canvas, size);
      _drawPollen(canvas, size);
      _drawButterflies(canvas, size);
      _drawSeasonParticles(canvas, size);
      _drawBirdFlocks(canvas, size);
      _drawBeeSwarms(canvas, size);
    }
    _drawRain(canvas, size);
    // Event overlay — aktif olayların ekran toneu + olaya özel partiküller.
    _drawEventOverlay(canvas, size);
  }

  // ── Sahne (derinlik sıralı) ────────────────────────────────────────────────
  //
  // Viewport culling: her entity'nin ekran pozisyonu hesaplanır, viewport
  // dışında olanlar atlanır. Sprite uzantısı için yön bazlı margin:
  //   - karakterler:  upChar=72,  side=48
  //   - ağaç/bina:    upTall=256, side=160 (4x3 townhall worst-case)
  //   - küçükler:     upSmall=32, side=32  (lotus, kutu, mine node)

  void _drawScene(Canvas canvas, Size size) {
    final (minX, maxX, minY, maxY) = _visBounds(size);

    // Grid → ekran (gridToScreen ile aynı, inline — sıcak yol allocation azaltır)
    final ox = size.width / 2 + camera.dx;
    final oy = size.height * 0.28 + camera.dy;

    // (sx, sy) screen-space anchor. Sprite uzantısına göre genişletilmiş aralık.
    bool inView(double gx, double gy, double up, double side) {
      final sx = ox + (gx - gy) * kTileW / 2;
      final sy = oy + (gx + gy) * kTileH / 2;
      return sx >= minX - side &&
          sx <= maxX + side &&
          sy >= minY - up &&
          sy <= maxY + kTileH;
    }

    // Culling sınırları sprite tipine göre kalibre edilmiş — gevşek tutmak
    // ekran kenarında scrolling sırasında popping önler, ama her +1 ekstra
    // entity drawable allocation × sort cost demek.
    const upChar = 72.0; // karakter ~64 + margin
    const upTall = 180.0; // ağaç sprite ~118 + margin (eski 256 cömert)
    // Decor margin: jitter ±26px + drawW/2 max ~20 = ±46. 48 güvenli sınır.
    // (32 dene ANCAK fallen_log + jitter köşede pop edebilir.)
    const upSmall = 32.0; // decor/lotus/reed üst kenar
    const sideS = 48.0; // decor küçük sprite + jitter
    const sideTree = 132.0; // yatay devrilen ağacın taç uzantısı
    const sideM = 48.0; // karakter sprite yan kenar
    const sideL = 160.0; // bina + scaffold

    _sceneBuffer.clear();

    // Spatial bucket grid — 8-tile cell. Topology değişmedikçe cache geçerli,
    // viewport içinde olan bucket'lar iterate edilir. Çok yoğun haritalarda
    // (200+ decor + 100+ ağaç) her frame full scan'i atlar.
    const kBucket = 3; // bit shift: cell size = 1 << 3 = 8 tile
    // Viewport bucket range — ekran köşelerinin grid karşılıkları + 1 margin.
    final tlG = screenToGrid(Offset(minX, minY), size, camera);
    final trG = screenToGrid(Offset(maxX, minY), size, camera);
    final brG = screenToGrid(Offset(maxX, maxY), size, camera);
    final blG = screenToGrid(Offset(minX, maxY), size, camera);
    int cMinB =
        ((tlG.$1 < trG.$1 ? tlG.$1 : trG.$1) <
                    (brG.$1 < blG.$1 ? brG.$1 : blG.$1)
                ? (tlG.$1 < trG.$1 ? tlG.$1 : trG.$1)
                : (brG.$1 < blG.$1 ? brG.$1 : blG.$1))
            .floor() >>
        kBucket;
    int cMaxB =
        ((tlG.$1 > trG.$1 ? tlG.$1 : trG.$1) >
                    (brG.$1 > blG.$1 ? brG.$1 : blG.$1)
                ? (tlG.$1 > trG.$1 ? tlG.$1 : trG.$1)
                : (brG.$1 > blG.$1 ? brG.$1 : blG.$1))
            .ceil() >>
        kBucket;
    int rMinB =
        ((tlG.$2 < trG.$2 ? tlG.$2 : trG.$2) <
                    (brG.$2 < blG.$2 ? brG.$2 : blG.$2)
                ? (tlG.$2 < trG.$2 ? tlG.$2 : trG.$2)
                : (brG.$2 < blG.$2 ? brG.$2 : blG.$2))
            .floor() >>
        kBucket;
    int rMaxB =
        ((tlG.$2 > trG.$2 ? tlG.$2 : trG.$2) >
                    (brG.$2 > blG.$2 ? brG.$2 : blG.$2)
                ? (tlG.$2 > trG.$2 ? tlG.$2 : trG.$2)
                : (brG.$2 > blG.$2 ? brG.$2 : blG.$2))
            .ceil() >>
        kBucket;
    cMinB--;
    cMaxB++;
    rMinB--;
    rMaxB++;

    // Görünür decor bucket'ları ground-flora pass'inden önce bir kez tarandı.
    // Yalnız hacimli/öne çıkması gereken türleri depth-sort sahnesine al;
    // çiçek ve yonca zeminde kaldığı için aktör/bina üstüne binemez.
    for (final d in _visibleDecorBuffer) {
      if (!isGroundFloraDecorKind(d.kind)) {
        _sceneBuffer.add(_DecorDrawable(d, time));
      }
    }

    // Mezarlar — sayı az (kilise yanında birikir); bucket'a gerek yok.
    for (final g in graves) {
      if (inView(g.col + 0.5, g.row + 0.5, upSmall, sideS)) {
        _sceneBuffer.add(_GraveDrawable(g));
      }
    }

    // Harabe/özel yerler — dünya başına yalnız beş tane; bucket gereksiz.
    for (final site in landmarks) {
      if (inView(site.col + 0.5, site.row + 0.5, upTall, sideS)) {
        _sceneBuffer.add(_WorldLandmarkDrawable(site));
      }
    }

    // Saz yatakları — sayı az (ateş etrafı); bucket'a gerek yok.
    for (final b in reedBeds) {
      if (inView(b.gridX, b.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_ReedBedDrawable(b));
      }
    }

    // Lotus bucket
    if (_lotusBucketsLen != lotuses.length) {
      _lotusBuckets.clear();
      for (final l in lotuses) {
        final key = (l.col >> kBucket, l.row >> kBucket);
        (_lotusBuckets[key] ??= []).add(l);
      }
      _lotusBucketsLen = lotuses.length;
    }
    for (int by = rMinB; by <= rMaxB; by++) {
      for (int bx = cMinB; bx <= cMaxB; bx++) {
        final list = _lotusBuckets[(bx, by)];
        if (list == null) continue;
        for (final l in list) {
          if (wilderness.contains((l.col, l.row))) {
            continue; // açılmamış = sisli
          }
          if (inView(l.col + 0.5, l.row + 0.5, upSmall, sideS)) {
            _sceneBuffer.add(_LotusDrawable(l, time));
          }
        }
      }
    }

    // Reed bucket — ReedClump iki yan tile kapsar, baz col,row yeterli
    // (col2,row2 8-tile cell içinde aynı bucket'ta kalır pratikte).
    if (_reedBucketsLen != reeds.length) {
      _reedBuckets.clear();
      for (final r in reeds) {
        final key = (r.col >> kBucket, r.row >> kBucket);
        (_reedBuckets[key] ??= []).add(r);
      }
      _reedBucketsLen = reeds.length;
    }
    for (int by = rMinB; by <= rMaxB; by++) {
      for (int bx = cMinB; bx <= cMaxB; bx++) {
        final list = _reedBuckets[(bx, by)];
        if (list == null) continue;
        for (final r in list) {
          if (wilderness.contains((r.col, r.row))) {
            continue; // orman altı sızmasın
          }
          if (inView(r.col + 0.5, r.row + 0.5, upSmall, sideS)) {
            _sceneBuffer.add(_ReedDrawable(r, time));
          }
        }
      }
    }
    // Böğürtlen çalıları — sayı az (öbekler), bucket'a gerek yok. Ağaçlarla
    // aynı derinlik hattında sıralanır (ikisi de tek tile, zemine oturur).
    for (final bb in berryBushes) {
      if (wilderness.contains((bb.col, bb.row))) continue;
      if (inView(bb.col + 0.5, bb.row + 0.5, upSmall, sideS)) {
        _sceneBuffer.add(_BerryBushDrawable(bb, time));
      }
    }

    // `isBeingCarried` pickup noktasına yürürken de rezervasyon bayrağıdır;
    // o evrede yük hâlâ yerde görünmelidir. Yalnız gerçekten bir köylünün
    // eline geçmiş nesneleri zemin pass'inden çıkar.
    final heldLoads = HashSet<Object>.identity();
    for (final villager in villagers) {
      if (villager.state == VillagerState.carrying &&
          villager.carriedItem != null) {
        heldLoads.add(villager.carriedItem!);
      }
    }

    for (final b in resourceBoxes) {
      if (b.isDelivered || heldLoads.contains(b)) continue;
      if (inView(b.gridX, b.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_ResourceBoxDrawable(b, time));
      }
    }
    for (final e in eggs) {
      if (inView(e.gridX, e.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_EggDrawable(e, time));
      }
    }
    for (final l in lootCaches) {
      if (inView(l.gridX, l.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_LootCacheDrawable(l, lootFade));
      }
    }
    for (final h in hayEntities) {
      if (h.isDelivered || heldLoads.contains(h)) continue;
      if (inView(h.gridX, h.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_HayDrawable(h, time));
      }
    }
    final primitiveClothing = !buildings.any(
      (b) => b.type == BuildingType.tailor,
    );
    for (final e in villagers) {
      final post = e.battlePost;
      if (post != null && inView(post.$1, post.$2, upSmall, sideS)) {
        _sceneBuffer.add(_BattleBarricadeDrawable(post.$1, post.$2));
      }
      if (e.isInsideBuilding) continue;
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(
          _VillagerDrawable(
            e,
            time,
            dayLight,
            season: season,
            rainIntensity: rainIntensity,
            primitiveClothing: primitiveClothing,
          ),
        );
      }
    }
    for (final e in merchants) {
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(
          e.hasCart
              ? _HorseCartDrawable(e)
              : _VillagerDrawable(
                  e,
                  time,
                  dayLight,
                  season: season,
                  rainIntensity: rainIntensity,
                ),
        );
      }
    }
    for (final e in soldiers) {
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(
          _VillagerDrawable(
            e,
            time,
            dayLight,
            season: season,
            rainIntensity: rainIntensity,
          ),
        );
      }
    }
    // Maden binası dikdörtgenlerini bir kez topla — aşağıdaki miner/mineNode
    // gizleme kontrolleri her entity için tüm bina listesini taramasın.
    _mineRects.clear();
    for (final b in buildings) {
      if (b.type != BuildingType.mineBuilding) continue;
      final meta = kBuildingMeta[b.type]!;
      _mineRects.add((b.col, b.row, meta.cols, meta.rows));
    }

    for (final c in cows) {
      if (inView(c.renderX, c.renderY, upChar, sideM)) {
        switch (c.kind) {
          case AnimalKind.cow:
            _sceneBuffer.add(_CowDrawable(c));
            break;
          case AnimalKind.sheep:
            _sceneBuffer.add(_SheepDrawable(c));
            break;
          case AnimalKind.chicken:
            _sceneBuffer.add(_ChickenDrawable(c));
            break;
        }
      }
    }
    // MineNode bucket — yoğun maden alanında her tile'da node olabilir.
    if (_mineNodeBucketsLen != mineNodes.length) {
      _mineNodeBuckets.clear();
      for (final n in mineNodes) {
        final key = (n.col >> kBucket, n.row >> kBucket);
        (_mineNodeBuckets[key] ??= []).add(n);
      }
      _mineNodeBucketsLen = mineNodes.length;
    }
    for (int by = rMinB; by <= rMaxB; by++) {
      for (int bx = cMinB; bx <= cMaxB; bx++) {
        final list = _mineNodeBuckets[(bx, by)];
        if (list == null) continue;
        for (final n in list) {
          if (n.isDepleted) continue;
          if (wilderness.contains((n.col, n.row))) {
            continue; // açılmamış = sisli
          }
          bool hidden = false;
          for (final mr in _mineRects) {
            if (n.col >= mr.$1 &&
                n.col < mr.$1 + mr.$3 &&
                n.row >= mr.$2 &&
                n.row < mr.$2 + mr.$4) {
              hidden = true;
              break;
            }
          }
          if (hidden) continue;
          if (inView(n.col + 0.5, n.row + 0.5, upSmall, sideS)) {
            _sceneBuffer.add(_MineDrawable(n));
          }
        }
      }
    }
    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      if (inView(cx, cy, upTall, sideL)) {
        final isBurning = burningBuildings.contains(b);
        _sceneBuffer.add(
          _BuildingDrawable(
            b,
            time,
            dayLight,
            rainIntensity,
            season,
            isBurning,
            perfMode,
          ),
        );
      }
    }
    for (final o in pendingOrders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type]!;
      final cx = o.col + m.cols / 2.0;
      final cy = o.row + m.rows / 2.0;
      if (inView(cx, cy, upTall, sideL)) {
        _sceneBuffer.add(_ScaffoldDrawable(o, time));
      }
    }
    // Tree bucket — yoğun ormanda %80+ ağaç viewport dışında olur.
    if (_treeBucketsLen != trees.length) {
      _treeBuckets.clear();
      for (final t in trees) {
        final key = (t.col >> kBucket, t.row >> kBucket);
        (_treeBuckets[key] ??= []).add(t);
      }
      _treeBucketsLen = trees.length;
    }
    for (int by = rMinB; by <= rMaxB; by++) {
      for (int bx = cMinB; bx <= cMaxB; bx++) {
        final list = _treeBuckets[(bx, by)];
        if (list == null) continue;
        for (final t in list) {
          // DERİN orman ağaçları kanopi cache'inde çizilir (entity yok zaten).
          // ÖN HAT (wildTreeTiles) gerçek ağaçları burada _TreeDrawable olarak
          // çizilir — net, kesilebilir, doğru depth-sort. Sadece derin orman
          // tile'ındaki (olası) ağaç atlanır.
          if (wilderness.contains((t.col, t.row)) &&
              !wildTreeTiles.contains((t.col, t.row))) {
            continue;
          }
          if (inView(t.col + 0.5, t.row + 0.5, upTall, sideTree)) {
            _sceneBuffer.add(_TreeDrawable(t, time, season));
          }
        }
      }
    }

    // (A) Stabil sıralama — depth eşitse ekleme sırası (deterministik) belirler.
    // Dart List.sort stabil değil; bu yüzden order'ı elle veriyoruz → aynı
    // diyagonaldeki objeler frame'den frame'e yer değiştirip titremez/örtmez.
    for (int i = 0; i < _sceneBuffer.length; i++) {
      _sceneBuffer[i].sortIndex = i;
    }
    _sceneBuffer.sort((a, b) {
      final d = a.depth.compareTo(b.depth);
      return d != 0 ? d : a.sortIndex.compareTo(b.sortIndex);
    });

    // İNŞAAT ŞEFFAFLIĞI — planlanan/yapılmakta olan bir şeyin önünde duran
    // binaları yarı saydam çiz (aşağıda). Hedef yoksa hiç hesaplanmaz.
    _computeRevealFades(size, camera);

    for (final d in _sceneBuffer) {
      final b = d.building;
      if (b != null &&
          _fadedBuildings.isNotEmpty &&
          _fadedBuildings.contains(b)) {
        final box = _revealBounds[b];
        canvas.saveLayer(box, _revealFadePaint);
        d.draw(canvas, size, camera);
        canvas.restore();
      } else {
        d.draw(canvas, size, camera);
      }
    }

    // (C) Occlusion silhouette — önde çizilen bir bina bir aktörü (NPC/işçi)
    // örtüyorsa, aktörü en üstte yarı saydam yeniden çiz → asla tamamen
    // kaybolmaz (Sims/Tropico tarzı "duvarın ardından hayalet").
    _drawOcclusionSilhouettes(canvas, size, camera);
  }

  /// İNŞAAT ŞEFFAFLIĞI — planlanan ya da yapılmakta olan bir şey (hayalet bina,
  /// şantiye, yol emri, yol önizlemesi) başka bir binanın ARKASINA denk
  /// geliyorsa, o binayı yarı saydam çizilecekler listesine alır.
  ///
  /// Oyuncunun derdi buydu: izometride önde duran bir bina, arkasındaki
  /// şantiyeyi ve yolu tamamen yutuyordu — nereye ne kurduğunu göremiyordun.
  ///
  /// Örtme testi occlusion silüetiyle ([_drawOcclusionSilhouettes]) aynı iki
  /// kuralı kullanır: (1) hedef binanın ARKASINDA mı (footprint kuralı — tek
  /// skaler depth off-axis'te yanılır), (2) hedefin ekran noktası binanın gövde
  /// kutusunun içinde mi.
  void _computeRevealFades(Size size, Offset camera) {
    _fadedBuildings.clear();
    _revealBounds.clear();
    if (revealTiles.isEmpty) return;

    for (final d in _sceneBuffer) {
      final b = d.building;
      if (b == null) continue;
      final (back, left, right, front) = _corners(
        b.col,
        b.row,
        b.cols,
        b.rows,
        size,
        camera,
      );
      final minX = min(min(back.dx, left.dx), min(right.dx, front.dx));
      final maxX = max(max(back.dx, left.dx), max(right.dx, front.dx));
      final wallPx = (front.dy - back.dy) * kOccWallScale + kOccWallBase;
      final box = Rect.fromLTRB(minX, back.dy - wallPx, maxX, front.dy);

      for (final (tc, tr) in revealTiles) {
        // Bina kendi tile'ını örtmüş sayılmaz (şantiye kendi yerinde).
        if (tc >= b.col &&
            tc < b.col + b.cols &&
            tr >= b.row &&
            tr < b.row + b.rows) {
          continue;
        }
        // Hedef binanın ÖNÜNDEyse örtülemez.
        if (tc >= b.col + b.cols || tr >= b.row + b.rows) continue;
        // Tile'ın ekran merkezi bina gövdesinin içinde mi?
        final s = gridToScreen(tc + 0.5, tr + 0.5, size, camera);
        if (!box.contains(s)) continue;
        _fadedBuildings.add(b);
        _revealBounds[b] = box.inflate(8);
        break;
      }
    }
  }

  /// Aktör, önünde çizilen bir binanın ekran gövdesi altında kalıyorsa üstüne
  /// yarı saydam kopyasını çizer. Footprint AABB'si gövde yüksekliği kadar
  /// yukarı uzatılır (duvar bölgesi). Aktör örtülmüyorsa hiç çizilmez (maliyetsiz).
  void _drawOcclusionSilhouettes(Canvas canvas, Size size, Offset camera) {
    // Önde çizilen binaların footprint + ekran AABB'si. Kutunun üstü, gerçek
    // çatıya yaklaşsın diye binanın footprint ekran yüksekliğiyle ORANTILI tahmin
    // edilir (kuyu kısa, kilise uzun) → ne gökyüzüne taşar ne örtmeyi kaçırır.
    final occ = _occBoxes..clear();
    for (final d in _sceneBuffer) {
      final b = d.building;
      if (b == null) continue;
      // Çadırın eğimli bez yüzeyi bir duvar değil. Aktörü onun üzerinde
      // hayalet olarak tekrar çizmek, yürürken çatıya çıkmış gibi gösterir.
      if (!kBuildingMeta[b.type]!.showOccludedActors) continue;
      final (back, left, right, front) = _corners(
        b.col,
        b.row,
        b.cols,
        b.rows,
        size,
        camera,
      );
      final minX = min(min(back.dx, left.dx), min(right.dx, front.dx));
      final maxX = max(max(back.dx, left.dx), max(right.dx, front.dx));
      final wallPx = (front.dy - back.dy) * kOccWallScale + kOccWallBase;
      occ.add((b, Rect.fromLTRB(minX, back.dy - wallPx, maxX, front.dy)));
    }
    if (occ.isEmpty) return;

    for (final d in _sceneBuffer) {
      final a = d.actor;
      if (a == null) continue;
      final s = gridToScreen(a.renderX, a.renderY, size, camera);
      final probe = Offset(s.dx, s.dy - kOccProbeY); // gövde/baş noktası
      Rect? clip; // ghost'u SADECE örten bina bölgesine kıs → "duvar ardından"
      for (final (b, box) in occ) {
        // Aktör binanın ÖNÜNDE mi? (footprint'in güney VEYA doğusunda) → örtülemez.
        // Tek-skaler depth off-axis'te yanılıyor; footprint kuralı doğru ön/arka verir.
        if (a.renderX >= b.col + b.cols || a.renderY >= b.row + b.rows) {
          continue;
        }
        if (box.contains(probe)) {
          clip = box;
          break;
        }
      }
      if (clip == null) continue;
      // Yarı saydam aktörü EN ÜSTTE ama yalnız bina silüeti içinde çiz →
      // çatının üstüne taşmaz, "üstüne çıkmış" gibi durmaz. Bina dışına
      // (zaten görünen baş/omuz) hiç çizilmez → çift görüntü yok.
      final box = Rect.fromLTRB(s.dx - 44, s.dy - 132, s.dx + 44, s.dy + 20);
      canvas.save();
      canvas.clipRect(clip);
      canvas.saveLayer(box, _occFadePaint);
      d.draw(canvas, size, camera);
      canvas.restore();
      canvas.restore();
    }
  }

  // ── Hayalet bina ────────────────────────────────────────────────────────────

  void _drawGhost(Canvas canvas, Size size) {
    final (gc, gr) = ghostTile!;
    final meta = kBuildingMeta[ghostType!]!;
    final (back, left, right, front) = _corners(
      gc,
      gr,
      meta.cols,
      meta.rows,
      size,
      camera,
    );

    final tileFill = ghostValid
        ? const Color(0x4400FF00)
        : const Color(0x44FF0000);
    final tileBorder = ghostValid
        ? const Color(0xCC00CC00)
        : const Color(0xCCCC0000);

    _scratchPath
      ..reset()
      ..moveTo(back.dx, back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    _pGhostFill.color = tileFill;
    _pGhostBorder.color = tileBorder;
    canvas.drawPath(_scratchPath, _pGhostFill);
    canvas.drawPath(_scratchPath, _pGhostBorder);

    // Etki alanı halkası — bina effectRadius > 0 ise zemine yumuşak
    // isometric oval olarak çizilir. Oyuncu placement sırasında menzili görür.
    if (meta.effectRadius > 0) {
      _drawEffectRing(canvas, gc, gr, meta, size);
    }

    // OCAĞIN SICAĞI — çadırın kendi ocağı yoktur; kışın ısınmasının tek yolu
    // köyün ateşine yakın kurulmuş olmaktır (bkz. hearth_warmth). Bu kural
    // ancak sınırı GÖRÜLEBİLİRSE adil: çadır yerleştirilirken ateşin çevresine
    // sıcak bölge ve soğuk sınır çizilir, hayaletin rengi de hangisinde
    // durduğunu söyler.
    if (ghostType == BuildingType.tent) {
      _drawHearthWarmthRings(canvas, gc, gr, size);
    }

    canvas.saveLayer(null, Paint()..color = const Color(0xAAFFFFFF));
    BuildingRenderer.draw(
      canvas,
      ghostType!,
      back,
      left,
      right,
      front,
      design: ghostDesign,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(VillageGamePainter old) =>
      old.camera != camera ||
      old.time != time ||
      old.ghostTile != ghostTile ||
      old.ghostType != ghostType ||
      old.ghostDesign != ghostDesign ||
      old.ghostValid != ghostValid ||
      // Yol önizlemesi/şeffaflık hedefleri her sürükleme karesinde değişebilir.
      // TUZAK: roadPreview state'te YERİNDE mutate edilen tek bir liste — `old`
      // ile aynı nesne, uzunluk/içerik karşılaştırması hep eşit çıkar. Bu yüzden
      // ayrı bir sürüm sayacı taşınıyor.
      old.roadPreviewVersion != roadPreviewVersion ||
      old.roadPreviewSurface != roadPreviewSurface ||
      old.revealTiles.length != revealTiles.length ||
      old.overlayTop != overlayTop ||
      old.overlayBottom != overlayBottom ||
      old.rainIntensity != rainIntensity ||
      old.nightClarity != nightClarity ||
      old.farmTiles != farmTiles ||
      old.harmanSites != harmanSites ||
      old.farmSelection != farmSelection ||
      old.lumberSelection != lumberSelection ||
      old.villagers != villagers ||
      old.merchants != merchants ||
      old.buildings != buildings ||
      old.pendingOrders != pendingOrders ||
      old.roadSystem != roadSystem ||
      old.pendingRoadOrders != pendingRoadOrders ||
      old.trees != trees ||
      old.mineNodes != mineNodes ||
      old.mineSelection != mineSelection ||
      old.waterTiles != waterTiles ||
      old.dayLight != dayLight ||
      old.lotuses != lotuses ||
      old.reeds != reeds ||
      old.berryBushes != berryBushes ||
      old.decor != decor ||
      old.decorVersion != decorVersion ||
      old.landmarks != landmarks ||
      old.cows != cows ||
      old.zoom != zoom ||
      old.resourceBoxes != resourceBoxes ||
      old.eggs != eggs ||
      old.lootCaches != lootCaches ||
      old.hayEntities != hayEntities ||
      old.groundVersion != groundVersion ||
      old.forestVersion != forestVersion ||
      old.lightSources != lightSources ||
      old.ambientTint != ambientTint ||
      old.ambientStrength != ambientStrength ||
      old.eventTint != eventTint ||
      old.activeFx != activeFx ||
      old.fxPlayback != fxPlayback ||
      old.burningBuildings != burningBuildings ||
      old.perfMode != perfMode;
}
