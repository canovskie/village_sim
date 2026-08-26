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
import '../core/constants.dart';
import '../entities/build_order.dart';
import '../entities/merchant_entity.dart';
import '../entities/road_order.dart';
import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';
import '../entities/worker_entity.dart';
import '../farm/farm_renderer.dart';
import '../farm/farm_tile.dart';
import '../systems/decor_population.dart';
import '../systems/event_system.dart';
import '../systems/hearth_warmth.dart';
import '../systems/lighting_system.dart';
import '../systems/road_system.dart';
import '../systems/villager_act.dart';
import '../systems/winter.dart';
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
import 'world_landmark_renderer.dart';

part 'game_ambient.dart';
part 'game_drawables.dart';
part 'game_fx.dart';
part 'game_paints.dart';

/// Retina/4K tam ekranlarda tam çözünürlüklü offscreen katmanlar raster
/// bütçesini tek başına aşabiliyor. Telefonu yalnız yüksek DPR'ı yüzünden bu
/// yola sokmamak için hem fiziksel piksel hem kısa kenar koşulu aranır.
const double kReducedEffectsPhysicalPixelThreshold = 2000000;

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
      _drawFireflies(canvas, size);
      _drawPollen(canvas, size);
      _drawSeasonParticles(canvas, size);
      _drawBirdFlocks(canvas, size);
      _drawBeeSwarms(canvas, size);
    }
    _drawRain(canvas, size);
    // Event overlay — aktif olayların ekran toneu + olaya özel partiküller.
    _drawEventOverlay(canvas, size);
  }

  // Yağmur sonrası çim üzerinde kalan küçük, dünya-uzaylı çamur izleri.
  // Kar mevsiminde çizilmez; kış zemini kar katmanıyla temiz kalır.
  void _drawMud(Canvas canvas, Size size) {
    // Çamur kaplaması zemin/çim ayrımını bozduğu için tamamen kaldırıldı.
    // Yağmur simülasyonu ve diğer hava efektleri çalışmaya devam eder.
    return;
  }

  void _drawGround(Canvas canvas, Size size) {
    final snowReady = SnowGroundRenderer.isReady;
    if (_groundCache == null ||
        _gcVersion != groundVersion ||
        _gcWidth != size.width ||
        _gcHeight != size.height ||
        _gcSeason != season ||
        _gcSnowReady != snowReady) {
      _buildGroundCache(size);
    }
    // Static layer'ı camera offset'iyle yerleştir.
    canvas.save();
    canvas.translate(camera.dx, camera.dy);
    canvas.drawPicture(_groundCache!);
    canvas.restore();

    // Dinamik su tile'ları (waves, sparkle, fish, rain rings) — her frame.
    _drawWaterTiles(canvas, size);

    // Map border + edge mist — dayLight ile değişir, cache dışında.
    _drawMapBorder(canvas, size);
  }

  void _buildGroundCache(Size size) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    // Camera-bağımsız: gridToScreen Offset.zero ile çağrılır. Outer canvas
    // replay'de translate(camera) uygular.
    const cam0 = Offset.zero;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    for (int row = 0; row < kRows; row++) {
      for (int col = 0; col < kCols; col++) {
        if (waterTiles.contains((col, row))) continue;
        final s = gridToScreen(col.toDouble(), row.toDouble(), size, cam0);
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        // Cache LOD=1.0 (tam detay) — bir kez render, sonra sınırsız frame
        // ucuza replay. Zoom-bağımlı LOD'a gerek yok.
        if (season == Season.winter && SnowGroundRenderer.isReady) {
          final hash = (col * 92821 + row * 68917) & 0x7fffffff;
          SnowGroundRenderer.draw(c, px, py, hash % 2, 1.0);
        } else {
          TileRenderer.drawGrassTile(c, px, py, hw, hh, col, row, zoom: 1.0);
        }
        int sides = 0;
        if (waterTiles.contains((col, row - 1))) sides++;
        if (waterTiles.contains((col + 1, row))) sides++;
        if (waterTiles.contains((col, row + 1))) sides++;
        if (waterTiles.contains((col - 1, row))) sides++;
        if (sides > 0) {
          TileRenderer.drawSandOverlay(c, px, py, hw, hh, sides);
        }
      }
    }

    _groundCache?.dispose();
    _groundCache = recorder.endRecording();
    _gcVersion = groundVersion;
    _gcWidth = size.width;
    _gcHeight = size.height;
    _gcSeason = season;
    _gcSnowReady = SnowGroundRenderer.isReady;
  }

  /// Viewport'un kapsadığı tile col/row aralığı (clamp'li). Köşe min/max'ı
  /// inline hesaplanır — frame başına 4 minik liste + .reduce allocation'ı yok.
  /// _drawWaterTiles + _drawWaterFoam ortak viewport bucketing'i.
  (int, int, int, int) _visibleTileBounds(Size size) {
    final (minX, maxX, minY, maxY) = _visBounds(size);
    final tl = screenToGrid(Offset(minX, minY), size, camera);
    final tr = screenToGrid(Offset(maxX, minY), size, camera);
    final bl = screenToGrid(Offset(minX, maxY), size, camera);
    final br = screenToGrid(Offset(maxX, maxY), size, camera);
    final colMin = min(
      min(tl.$1, tr.$1),
      min(bl.$1, br.$1),
    ).floor().clamp(0, kCols - 1);
    final colMax = max(
      max(tl.$1, tr.$1),
      max(bl.$1, br.$1),
    ).ceil().clamp(0, kCols - 1);
    final rowMin = min(
      min(tl.$2, tr.$2),
      min(bl.$2, br.$2),
    ).floor().clamp(0, kRows - 1);
    final rowMax = max(
      max(tl.$2, tr.$2),
      max(bl.$2, br.$2),
    ).ceil().clamp(0, kRows - 1);
    return (colMin, colMax, rowMin, rowMax);
  }

  // Devrilen ön-hat ağacı yaprak patlaması — kısa ömürlü prosedürel partiküller
  // (seed+yaştan; per-yaprak storage yok). Yayıl + yerçekimiyle düş + solar.
  static final Paint _pLeafBurst = Paint()..isAntiAlias = true;
  static final Paint _pTreeDust = Paint()..isAntiAlias = true;

  void _drawLeafBursts(Canvas canvas, Size size) {
    if (leafBursts.isEmpty) return;
    for (final lb in leafBursts) {
      final t = (lb.age / LeafBurst.lifetime).clamp(0.0, 1.0);
      final root = gridToScreen(lb.x, lb.y, size, camera);
      // Yapraklar kökten değil, yere çarpan taçtan kopar. Tam boy çamın yatay
      // uzantısı yaklaşık 50 px; direction ekran uzayında hazır tutulur.
      final base = root.translate(lb.direction * 48.0, -2);
      const n = 10;
      for (int i = 0; i < n; i++) {
        final h = (lb.seed + i * 0x9E3779B1) & 0xFFFFFF;
        final ang = (h & 0xFF) / 255.0 * 2 * pi;
        final spd = 12 + (h >> 8 & 0xFF) / 255.0 * 20;
        final lw = 3.0 + (h >> 4 & 3);
        final dx = cos(ang) * spd * t;
        final dy = sin(ang) * spd * t * 0.45 + t * t * 30 - 14; // yayıl+düş
        final leafCol = (h & 1) == 0
            ? const Color(0xFF6FA046) // yeşil
            : const Color(0xFFC79A3E); // sonbahar sarısı
        _pLeafBurst.color = leafCol.withValues(
          alpha: ((1 - t) * 0.95).clamp(0.0, 1.0),
        );
        canvas.save();
        canvas.translate(base.dx + dx, base.dy + dy);
        canvas.rotate(ang + t * 5);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset.zero, width: lw, height: lw * 0.55),
            Radius.circular(lw * 0.3),
          ),
          _pLeafBurst,
        );
        canvas.restore();
      }
      // Taç darbesiyle yere yayılan sıcak toz: ilk yarıda büyür, sonra solar.
      final dustT = (t / 0.72).clamp(0.0, 1.0);
      _pTreeDust.color = const Color(
        0xFFB89A69,
      ).withValues(alpha: ((1 - dustT) * 0.34).clamp(0.0, 1.0));
      for (int i = 0; i < 3; i++) {
        final side = i - 1.0;
        final radius = 3.5 + dustT * (8 + i * 2);
        canvas.drawOval(
          Rect.fromCenter(
            center: base.translate(side * (7 + dustT * 5), 3 - dustT * 2),
            width: radius * 1.8,
            height: radius * 0.55,
          ),
          _pTreeDust,
        );
      }
    }
  }

  void _drawWaterTiles(Canvas canvas, Size size) {
    if (waterTiles.isEmpty) return;
    final (colMin, colMax, rowMin, rowMax) = _visibleTileBounds(size);
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    for (int row = rowMin; row <= rowMax; row++) {
      for (int col = colMin; col <= colMax; col++) {
        if (!waterTiles.contains((col, row))) continue;
        final s = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
        WaterRenderer.drawTile(
          canvas,
          s.dx.roundToDouble(),
          s.dy.roundToDouble(),
          hw,
          hh,
          time: time,
          seed: col * 17 + row * 31,
          // Dalga fazı KONUMDAN: (col+row) derinlik ekseni (~11 tile'da bir
          // tam dalga), (col-row) enine kırılma. Rastgele tile fazı yüzeyi
          // yamalı gösteriyordu — bkz. WaterRenderer.drawTile.
          wavePhase: (col + row) * 0.55 + (col - row) * 0.17,
          dayLight: dayLight,
          rainIntensity: rainIntensity,
          zoom: zoom,
          skyTint: skyReflection,
        );
      }
    }
  }

  // ── Su köpüğü (su kenarlarında) ────────────────────────────────────────────

  void _drawWaterFoam(Canvas canvas, Size size) {
    if (waterTiles.isEmpty) return;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    // PERF: TÜM su karelerini gezmek yerine yalnız GÖRÜNÜR col/row aralığını
    // tara (_drawWaterTiles ile aynı viewport bucketing). Geniş denizde her
    // frame yüzlerce off-screen tile + gridToScreen israfını keser. Görsel aynı.
    final (colMin, colMax, rowMin, rowMax) = _visibleTileBounds(size);
    for (int row = rowMin; row <= rowMax; row++) {
      for (int col = colMin; col <= colMax; col++) {
        if (!waterTiles.contains((col, row))) continue;
        final hasLandNeighbor =
            !waterTiles.contains((col, row - 1)) ||
            !waterTiles.contains((col + 1, row)) ||
            !waterTiles.contains((col, row + 1)) ||
            !waterTiles.contains((col - 1, row));
        if (!hasLandNeighbor) continue;
        final s = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
        WaterRenderer.drawFoam(
          canvas,
          s.dx.roundToDouble(),
          s.dy.roundToDouble(),
          hw,
          hh,
          time,
          col * 17 + row * 31,
        );
      }
    }
  }

  void _drawMapBorder(Canvas canvas, Size size) {
    // dayLight'a bağlı (gece sis koyulaşır), Picture cache dışında çizilir.
    final p0 = gridToScreen(0, 0, size, camera);
    final p1 = gridToScreen(kCols.toDouble(), 0, size, camera);
    final p2 = gridToScreen(kCols.toDouble(), kRows.toDouble(), size, camera);
    final p3 = gridToScreen(0, kRows.toDouble(), size, camera);
    _scratchPath
      ..reset()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    // ── Kıyı şeridi: ada elmasının kenarı denizle "ada" gibi buluşur ────────
    // Eski koyu sis yerine sığ su şelfi (turkuaz hâle, dışa doğru açılır) +
    // ada kıyısında kırılan animasyonlu köpük + ıslak su çizgisi. Aynı 4
    // stroke katmanı, sadece renklendirildi → ek allocation yok.
    // Gece: lit düşer → renkler kararır (overlay zaten geceyi taşır).
    final lit =
        (0.34 + dayLight.clamp(0.0, 1.0) * 0.66) * (1.0 - nightClarity * 0.20);
    int a(double v) => (v * lit).round().clamp(0, 255);
    // Sığ su şelfi — dıştan içe açılan turkuaz hâle (kıyının "sığ" bandı).
    _pEdgeMistOuter.color = Color.fromARGB(a(0x24), 0x6E, 0xB6, 0xBE);
    _pEdgeMistMid.color = Color.fromARGB(a(0x40), 0x9A, 0xCF, 0xD2);
    // Köpük — kıyıda kırılan beyaz dalga, yavaşça nabız atar.
    final foam = 0.62 + 0.38 * (sin(time * 1.25) * 0.5 + 0.5);
    _pEdgeMistInner.color = Color.fromARGB(a(0x6E * foam), 0xE6, 0xF4, 0xF2);
    // Islak su çizgisi — yeşil yerine koyu teal (kara/su keskin sınırı kalksın).
    _pMapBorder.color = Color.fromARGB(a(0xCC), 0x1C, 0x46, 0x50);
    canvas.drawPath(_scratchPath, _pEdgeMistOuter);
    canvas.drawPath(_scratchPath, _pEdgeMistMid);
    canvas.drawPath(_scratchPath, _pEdgeMistInner);
    canvas.drawPath(_scratchPath, _pMapBorder);
  }

  // ── Tarla tile'ları ───────────────────────────────────────────────────────

  void _drawFarmTiles(Canvas canvas, Size size) {
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    for (final t in farmTiles) {
      final s = gridToScreen(t.col.toDouble(), t.row.toDouble(), size, camera);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      if (px < minX || px > maxX) continue;
      if (py < minY || py > maxY) continue;
      // Ekilmemiş / nadastaki tarla çıplak toprak (stage 0, progress yok) —
      // büyüyen ekinin cross-fade'i tetiklenmesin.
      final showProgress = t.needsSowing ? 0.0 : t.growthProgress;
      FarmRenderer.drawTile(
        canvas,
        px,
        py,
        hw,
        hh,
        t.stage,
        showProgress,
        season,
        watered: t.isWatered,
      );
    }
  }

  // ── Harman yeri ───────────────────────────────────────────────────────────

  void _drawHarmanSites(Canvas canvas, Size size) {
    if (harmanSites.isEmpty) return;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    for (final site in harmanSites) {
      for (final tile in site.tiles) {
        final s = gridToScreen(
          tile.$1.toDouble(),
          tile.$2.toDouble(),
          size,
          camera,
        );
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        if (px < minX || px > maxX || py < minY || py > maxY) continue;
        _scratchPath
          ..reset()
          ..moveTo(px, py)
          ..lineTo(px + hw, py + hh)
          ..lineTo(px, py + hh * 2)
          ..lineTo(px - hw, py + hh)
          ..close();
        canvas.drawPath(_scratchPath, _pHarmanGround);
        canvas.drawPath(_scratchPath, _pHarmanBorder);

        // Tırmık izleri: alanı tarladan ayıran, sıkıştırılmış toprak çizgileri.
        for (int i = 1; i <= 3; i++) {
          final t = i / 4.0;
          canvas.drawLine(
            Offset(px - hw * (1 - t), py + hh * (1 - t)),
            Offset(px + hw * t, py + hh * (1 + t)),
            _pHarmanRake,
          );
        }
      }
    }
  }

  // ── Yollar ────────────────────────────────────────────────────────────────
  // Tamamlanmış yollar full opacity + autotile mask; bekleyen orderlar yarı
  // saydam (0.3..0.85 progress'e göre) preview olarak çizilir.
  // Çizim sırası: zemin (grass) sonrası, sahne (NPC/bina) öncesi.
  void _drawRoads(Canvas canvas, Size size) {
    if (roadSystem.count == 0 && pendingRoadOrders.isEmpty) return;
    const hw = kTileW / 2;
    const hh = kTileH / 2;

    // Tamamlanmış yollar — cached Picture (ground gibi camera-bağımsız).
    // Zoom karşılaştırması tolerance'lı: ScaleUpdate.scale floating-point
    // mikro değişim yapıyor (1.0 → 1.000001) → her pan frame'inde Picture
    // rebuild oluyordu. 0.05 tolerance ile zoom kademe görsel olarak fark
    // edilmeyen aralıkta rebuild'i atlar, pan kasması biter.
    if (roadSystem.count > 0) {
      final zoomChanged = (_rcZoom - zoom).abs() > 0.05;
      if (_roadsCache == null ||
          _rcVersion != roadSystem.version ||
          _rcWidth != size.width ||
          _rcHeight != size.height ||
          zoomChanged) {
        _buildRoadsCache(size);
      }
      canvas.save();
      canvas.translate(camera.dx, camera.dy);
      canvas.drawPicture(_roadsCache!);
      canvas.restore();
    }

    // Bekleyen orderlar — preview, progress fade her frame değişir, cache dışı.
    if (pendingRoadOrders.isNotEmpty) {
      final (minX, maxX, minY, maxY) = _visBounds(size);
      final pendingTiles = <(int, int)>{
        for (final o in pendingRoadOrders)
          if (!o.completed) (o.col, o.row),
      };
      bool hasPendingRoad(int c, int r) =>
          roadSystem.has(c, r) || pendingTiles.contains((c, r));
      for (final o in pendingRoadOrders) {
        if (o.completed) continue;
        final s = gridToScreen(
          o.col.toDouble(),
          o.row.toDouble(),
          size,
          camera,
        );
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        if (px < minX || px > maxX) continue;
        if (py < minY || py > maxY) continue;
        // Stabil hash (col, row) — RoadTile.hash ile aynı formül
        final hash = (o.col * 73856093) ^ (o.row * 19349663);
        final opacity = 0.3 + 0.55 * o.progress;
        var mask = 0;
        if (hasPendingRoad(o.col, o.row - 1)) mask |= 1;
        if (hasPendingRoad(o.col + 1, o.row)) mask |= 2;
        if (hasPendingRoad(o.col, o.row + 1)) mask |= 4;
        if (hasPendingRoad(o.col - 1, o.row)) mask |= 8;
        RoadRenderer.drawRoadTile(
          canvas,
          px,
          py,
          hw,
          hh,
          o.surface,
          mask,
          hash,
          zoom: zoom,
          opacity: opacity,
        );
      }
    }
  }

  /// YOL ÖNİZLEMESİ — sürüklenen güzergâh. Henüz hiçbir şey harcanmadı; bu
  /// çizim oyuncunun bırakmadan önce gördüğü sözleşmedir.
  ///
  /// Döşemede: geçerli tile yeşil dolgu + yüzeyin soluk dokusu, geçersiz tile
  /// kırmızı. Silgide: kaldırılacak tile kırmızı çapraz.
  /// Sahne sprite'larından SONRA çizilir → bina arkasında kalmaz.
  void _drawRoadPreview(Canvas canvas, Size size) {
    if (roadPreview.isEmpty) return;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    final erasing = roadPreviewSurface == null;
    final previewTiles = <(int, int)>{
      if (!erasing)
        for (final (tile, ok) in roadPreview)
          if (ok) tile,
    };
    bool hasPreviewRoad(int c, int r) =>
        roadSystem.has(c, r) || previewTiles.contains((c, r));

    for (final (tile, ok) in roadPreview) {
      final (c, r) = tile;
      final s = gridToScreen(c.toDouble(), r.toDouble(), size, camera);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();

      // Geçerli döşemede yüzeyin kendi dokusu soluk çizilir → oyuncu ne
      // koyacağını (toprak mı taş mı) renginden anlar.
      if (ok && !erasing) {
        final hash = (c * 73856093) ^ (r * 19349663);
        var mask = 0;
        if (hasPreviewRoad(c, r - 1)) mask |= 1;
        if (hasPreviewRoad(c + 1, r)) mask |= 2;
        if (hasPreviewRoad(c, r + 1)) mask |= 4;
        if (hasPreviewRoad(c - 1, r)) mask |= 8;
        RoadRenderer.drawRoadTile(
          canvas,
          px,
          py,
          hw,
          hh,
          roadPreviewSurface!,
          mask,
          hash,
          zoom: zoom,
          opacity: 0.42,
        );
      }

      _scratchPath
        ..reset()
        ..moveTo(px, py - hh)
        ..lineTo(px + hw, py)
        ..lineTo(px, py + hh)
        ..lineTo(px - hw, py)
        ..close();
      _pGhostFill.color = ok
          ? (erasing ? const Color(0x55FF5544) : const Color(0x3300FF66))
          : const Color(0x33FF4444);
      _pGhostBorder.color = ok
          ? (erasing ? const Color(0xCCFF6655) : const Color(0xCC33DD77))
          : const Color(0x99CC4444);
      canvas.drawPath(_scratchPath, _pGhostFill);
      canvas.drawPath(_scratchPath, _pGhostBorder);
    }
  }

  void _buildRoadsCache(Size size) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const cam0 = Offset.zero;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    for (final t in roadSystem.all) {
      final s = gridToScreen(t.col.toDouble(), t.row.toDouble(), size, cam0);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      final mask = roadSystem.neighborMask(t.col, t.row);
      RoadRenderer.drawRoadTile(
        c,
        px,
        py,
        hw,
        hh,
        t.surface,
        mask,
        t.hash,
        zoom: zoom,
      );
    }
    _roadsCache?.dispose();
    _roadsCache = recorder.endRecording();
    _rcVersion = roadSystem.version;
    _rcWidth = size.width;
    _rcHeight = size.height;
    _rcZoom = zoom;
  }

  // ── Tarla seçim önizlemesi ────────────────────────────────────────────────

  void _drawFarmSelection(Canvas canvas, Size size) {
    final (c1, r1, c2, r2) = farmSelection!;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    final minC = c1 < c2 ? c1 : c2;
    final maxC = c1 < c2 ? c2 : c1;
    final minR = r1 < r2 ? r1 : r2;
    final maxR = r1 < r2 ? r2 : r1;

    for (int c = minC; c <= maxC; c++) {
      for (int r = minR; r <= maxR; r++) {
        final s = gridToScreen(c.toDouble(), r.toDouble(), size, camera);
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        _scratchPath
          ..reset()
          ..moveTo(px, py)
          ..lineTo(px + hw, py + hh)
          ..lineTo(px, py + hh * 2)
          ..lineTo(px - hw, py + hh)
          ..close();
        canvas.drawPath(_scratchPath, _pFarmFill);
        canvas.drawPath(_scratchPath, _pFarmBorder);
      }
    }
  }

  // ── Lumber seçim önizlemesi ───────────────────────────────────────────────

  void _drawLumberSelection(Canvas canvas, Size size) {
    final (c1, r1, c2, r2) = lumberSelection!;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    final minC = c1 < c2 ? c1 : c2;
    final maxC = c1 < c2 ? c2 : c1;
    final minR = r1 < r2 ? r1 : r2;
    final maxR = r1 < r2 ? r2 : r1;

    for (int c = minC; c <= maxC; c++) {
      for (int r = minR; r <= maxR; r++) {
        final s = gridToScreen(c.toDouble(), r.toDouble(), size, camera);
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        _scratchPath
          ..reset()
          ..moveTo(px, py)
          ..lineTo(px + hw, py + hh)
          ..lineTo(px, py + hh * 2)
          ..lineTo(px - hw, py + hh)
          ..close();
        canvas.drawPath(_scratchPath, _pLumberFill);
        canvas.drawPath(_scratchPath, _pLumberBorder);
      }
    }
  }

  // ── İşaretli ağaçlara küçük kırmızı X ───────────────────────────────────

  void _drawMarkedTrees(Canvas canvas, Size size) {
    for (final t in trees) {
      if (!t.isMarkedForCutting || t.isFelled) continue;
      final center = gridToScreen(t.col + 0.5, t.row + 0.5, size, camera);
      const r = 6.0;
      canvas.drawLine(
        Offset(center.dx - r, center.dy - r),
        Offset(center.dx + r, center.dy + r),
        _pTreeX,
      );
      canvas.drawLine(
        Offset(center.dx + r, center.dy - r),
        Offset(center.dx - r, center.dy + r),
        _pTreeX,
      );
    }
  }

  // ── Maden seçim önizlemesi ────────────────────────────────────────────────

  void _drawMineSelection(Canvas canvas, Size size) {
    final (c1, r1, c2, r2) = mineSelection!;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    final minC = c1 < c2 ? c1 : c2;
    final maxC = c1 < c2 ? c2 : c1;
    final minR = r1 < r2 ? r1 : r2;
    final maxR = r1 < r2 ? r2 : r1;
    for (int c = minC; c <= maxC; c++) {
      for (int r = minR; r <= maxR; r++) {
        final s = gridToScreen(c.toDouble(), r.toDouble(), size, camera);
        MineRenderer.drawSelectionTile(canvas, s.dx, s.dy, hw, hh);
      }
    }
  }

  // ── İşaretli maden düğümlerine ⛏ ─────────────────────────────────────────

  void _drawMarkedMines(Canvas canvas, Size size) {
    for (final n in mineNodes) {
      if (!n.isMarkedForMining || n.isDepleted) continue;
      final center = gridToScreen(n.col + 0.5, n.row + 0.5, size, camera);
      const r = 5.0;
      final cy = center.dy - kTileH * 0.9;
      canvas.drawLine(
        Offset(center.dx - r, cy - r),
        Offset(center.dx + r, cy + r),
        _pMineX,
      );
      canvas.drawLine(
        Offset(center.dx + r, cy - r),
        Offset(center.dx - r, cy + r),
        _pMineX,
      );
    }
  }

  // ── Zemin florası ────────────────────────────────────────────────────────

  /// Decor spatial cache'ini kaynak liste kimliği, açık mutasyon sürümü ve
  /// uzunluk üzerinden doğrular; sonra görünür dekoru iki çizim pass'inin ortak
  /// tamponuna toplar. Liste kimliği kontrolü aynı uzunlukta yeni dünya/listenin
  /// eski bucket'ları yanlışlıkla kullanmasını, [decorVersion] ise aynı listenin
  /// yerinde değiştirilmesini kapsar.
  void _collectVisibleDecor(Size size) {
    const bucketShift = 3; // cell size = 1 << 3 = 8 tile
    if (!identical(_decorBucketsSource, decor) ||
        _decorBucketsVersion != decorVersion ||
        _decorBucketsLen != decor.length) {
      _decorBuckets.clear();
      for (final d in decor) {
        final key = (d.col >> bucketShift, d.row >> bucketShift);
        (_decorBuckets[key] ??= []).add(d);
      }
      _decorBucketsSource = decor;
      _decorBucketsVersion = decorVersion;
      _decorBucketsLen = decor.length;
    }

    final visible = _visibleDecorBuffer..clear();
    if (decor.isEmpty) return;

    final (minX, maxX, minY, maxY) = _visBounds(size);
    final tl = screenToGrid(Offset(minX, minY), size, camera);
    final tr = screenToGrid(Offset(maxX, minY), size, camera);
    final br = screenToGrid(Offset(maxX, maxY), size, camera);
    final bl = screenToGrid(Offset(minX, maxY), size, camera);
    final minCol = min(min(tl.$1, tr.$1), min(br.$1, bl.$1));
    final maxCol = max(max(tl.$1, tr.$1), max(br.$1, bl.$1));
    final minRow = min(min(tl.$2, tr.$2), min(br.$2, bl.$2));
    final maxRow = max(max(tl.$2, tr.$2), max(br.$2, bl.$2));
    final cMinB = (minCol.floor() >> bucketShift) - 1;
    final cMaxB = (maxCol.ceil() >> bucketShift) + 1;
    final rMinB = (minRow.floor() >> bucketShift) - 1;
    final rMaxB = (maxRow.ceil() >> bucketShift) + 1;

    // Jitter + en geniş küçük decor sprite'ı için eski 48px güvenli marj.
    const up = 32.0;
    const side = 48.0;
    final ox = size.width / 2 + camera.dx;
    final oy = size.height * 0.28 + camera.dy;
    for (int by = rMinB; by <= rMaxB; by++) {
      for (int bx = cMinB; bx <= cMaxB; bx++) {
        final bucket = _decorBuckets[(bx, by)];
        if (bucket == null) continue;
        for (final d in bucket) {
          // Wilderness (orman duvarı altı) dekoru sisin üstünden sızmasın.
          if (wilderness.contains((d.col, d.row))) continue;
          final gx = d.col + 0.5;
          final gy = d.row + 0.5;
          final sx = ox + (gx - gy) * kTileW / 2;
          final sy = oy + (gx + gy) * kTileH / 2;
          if (sx >= minX - side &&
              sx <= maxX + side &&
              sy >= minY - up &&
              sy <= maxY + kTileH) {
            visible.add(d);
          }
        }
      }
    }
  }

  /// Çiçek ve yoncayı gerçek bir foreground objesi değil, zemine basılı flora
  /// olarak çizer. Hacimli dekor türleri [_drawScene]'de depth-sort'ta kalır.
  void _drawGroundFlora(Canvas canvas, Size size) {
    for (final d in _visibleDecorBuffer) {
      if (!isGroundFloraDecorKind(d.kind)) continue;
      final center = gridToScreen(
        d.col + 0.5 + d.jitterX,
        d.row + 0.5 + d.jitterY,
        size,
        camera,
      );
      DecorRenderer.draw(canvas, center, d, time: time);
    }
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
      if (e.isInsideBuilding) continue;
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(
          _VillagerDrawable(
            e,
            time,
            dayLight,
            primitiveClothing: primitiveClothing,
          ),
        );
      }
    }
    for (final e in merchants) {
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(
          e.hasCart
              ? _HorseCartDrawable(e, time)
              : _VillagerDrawable(e, time, dayLight),
        );
      }
    }
    for (final e in soldiers) {
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(_VillagerDrawable(e, time, dayLight));
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

  /// Ocağın ısıttığı bölge — çadır yerleştirilirken zemine iki izometrik oval:
  /// içteki dolu/sıcak alan (çadır kışı atlatır), dıştaki soluk sınır (ötesinde
  /// ocağın hiçbir faydası kalmaz). Arası yumuşak bant.
  void _drawHearthWarmthRings(Canvas canvas, int gc, int gr, Size size) {
    BuildingEntity? fire;
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        fire = b;
        break;
      }
    }
    if (fire == null) return; // ocak yoksa gösterilecek sıcak da yok

    final fx = fire.col + fire.cols * 0.5;
    final fy = fire.row + fire.rows * 0.5;
    final center = gridToScreen(fx, fy, size, camera);

    // Hayaletin durduğu yer sıcak mı — halkanın rengi bunu söyler.
    final warm =
        hearthWarmth(dx: (gc + 0.5) - fx, dy: (gr + 0.5) - fy, burning: true) >=
        kColdShelterThreshold;
    final tint = warm ? const Color(0xFFFFC062) : const Color(0xFF9FB6C8);

    Rect ovalFor(double r) => Rect.fromCenter(
      center: center,
      width: r * kTileW * 2,
      height: r * kTileH * 2,
    );

    // İç bölge: ocağın tam ısıttığı mahalle.
    canvas.drawOval(
      ovalFor(kHearthWarmRadius),
      Paint()
        ..color = tint.withAlpha(warm ? 0x2A : 0x18)
        ..isAntiAlias = true,
    );
    canvas.drawOval(
      ovalFor(kHearthWarmRadius),
      Paint()
        ..color = tint.withAlpha(0xAA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..isAntiAlias = true,
    );
    // Dış sınır: buradan sonrası kışın soğuk.
    canvas.drawOval(
      ovalFor(kHearthColdRadius),
      Paint()
        ..color = tint.withAlpha(0x55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );
  }

  /// Bina etki alanı görselleştirme — yumuşak isometric oval, ghost rengi ile.
  void _drawEffectRing(
    Canvas canvas,
    int gc,
    int gr,
    BuildingMeta meta,
    Size size,
  ) {
    final cx = gc + meta.cols * 0.5;
    final cy = gr + meta.rows * 0.5;
    final centerScreen = gridToScreen(cx, cy, size, camera);
    // İzometrik 2:1 — radius tile → ekran: x = r * kTileW, y = r * kTileH
    final rx = meta.effectRadius * kTileW;
    final ry = meta.effectRadius * kTileH;
    final rect = Rect.fromCenter(
      center: centerScreen,
      width: rx * 2,
      height: ry * 2,
    );
    final ringColor = ghostValid
        ? const Color(0x66FFD27A)
        : const Color(0x66FF8888);
    canvas.drawOval(
      rect,
      Paint()
        ..color = ringColor.withAlpha(0x22)
        ..isAntiAlias = true,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true,
    );
  }

  // ── Lighting pass ────────────────────────────────────────────────────────
  // Sahnenin üstüne çizilir. Beş katman, sırasıyla:
  //   (0) Ambient color grade — fullscreen modulate; her sprite günün rengini
  //       içer (gece soğuk mavi mehtap, altın saat amber, öğle ~beyaz).
  //   (1) Karanlık vertical gradient + vignette (saveLayer içinde)
  //   (2) Lokal ışık delikleri (BlendMode.dstOut → karanlığı eritir)
  //   (3) Per-light warm wash — saveLayer + plus radial: lit area'daki
  //       sprite'lar gerçekten "sıcak" görünür (ambient modulate'in soğuğunu
  //       lokal olarak iptal eder).
  //   (4) Sıcak halo (BlendMode.plus → dış atmosferik parlama)
  // Gündüz tam aydınlıkta sadece ambient grade + hafif vignette çizilir.
  void _drawLightingPass(Canvas canvas, Size size) {
    final darkness = (1.0 - dayLight).clamp(0.0, 1.0);

    // PerfMode fast path — tek vertical gradient overlay, ışık cutout / halo
    // saveLayer × 3 + 7-stop gradient × N tamamen atlanır. Gece basit dark
    // overlay olur, gündüz ise tam ekran atmosfer katmanları tamamen atlanır.
    // Bu kontrol gündüz fast path'inden ÖNCE olmalı; aksi halde performans modu
    // fullscreen'da dört ayrı tam-ekran blend pass'i çizmeye devam eder.
    if (perfMode) {
      if (overlayTop.a == 0 && overlayBottom.a == 0 && darkness < 0.05) {
        return;
      }
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      _pLighting.shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [overlayTop, overlayBottom],
      );
      canvas.drawRect(rect, _pLighting);
      _pLighting.shader = null;
      return;
    }

    // (0) Ambient color grade — gece/şafak/altın saatte sahneyi tonlar.
    // Modulate olduğu için strength=0'da beyaza lerp ederiz → identity.
    _drawAmbientGrade(canvas, size);

    // Gündüz fast path — overlay bantları şeffaf, tam aydınlık. Gündüz
    // atmosfer pass'i (güneş formu + hava perspektifi + bloom + sıcak vignette).
    if (overlayTop.a == 0 && overlayBottom.a == 0 && darkness < 0.05) {
      _drawDayAtmosphere(canvas, size);
      return;
    }

    _projectLights(size);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // saveLayer offscreen buffer → içerideki BlendMode.dstOut sadece bu
    // katmanı etkiler, sahnenin altındaki çizimleri silmez.
    canvas.saveLayer(rect, Paint());

    // (1a) Vertical gradient karanlık.
    _pLighting.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height),
      [overlayTop, overlayBottom],
    );
    canvas.drawRect(rect, _pLighting);
    _pLighting.shader = null;

    // (1b) Vignette — kenarları yumuşakça karartır. Mantıklı seviyede;
    // ışık delikleriyle birleşince aşırı kontrast yapmasın diye düşük tut.
    final vA = (darkness * 70 + 22).round().clamp(0, 110);
    _pLighting.shader = ui.Gradient.radial(
      Offset(size.width / 2, size.height / 2),
      max(size.width, size.height) * 0.70,
      [const Color(0x00000000), Color.fromARGB(vA, 0x05, 0x08, 0x18)],
    );
    canvas.drawRect(rect, _pLighting);
    _pLighting.shader = null;

    // (1c) Mehtap dolgusu — gece, dark overlay'in üstüne soğuk-mavi plus.
    // Düz siyah/lacivert yerine ATMOSFERIK moonlight (yukarıdan gelen ay
    // ışığı hissi). saveLayer içinde olduğu için dstOut ışık delikleri
    // moonfill'i de eritir → sıcak puddle vs soğuk mehtap kontrastı tam çıkar.
    // 0.30 darkness eşiğinin altında atlanır (alacakaranlıkta lüzumsuz).
    if (darkness > 0.30) {
      final moonF = ((darkness - 0.30) / 0.70).clamp(0.0, 1.0);
      final topA = (moonF * 78).round().clamp(0, 90);
      final botA = (moonF * 30).round().clamp(0, 50);
      _pMoonFill.shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          Color.fromARGB(topA, 0x68, 0x86, 0xC2), // üst — açık mehtap mavi
          Color.fromARGB(botA, 0x3A, 0x52, 0x90), // alt — derinleşmiş zemin
        ],
      );
      canvas.drawRect(rect, _pMoonFill);
      _pMoonFill.shader = null;
    }

    // (2) Işık kaynakları → karanlığı eritir. Inner draws BlendMode.lighten ile
    // RGB max alır ama alpha srcOver-stacked olur — overlap'te hafif birikme
    // (asimptotik 1.0). ColorFilter (alpha=R) ile MAX'a çevirmek denendi ama
    // ColorFilter.matrix unpremul ile çalışıyor; beyaz gradient için unpremul
    // R her zaman 1.0 → A'=1, dstOut TÜM gradient alanını full erase ediyor
    // (köy göz alır). Kabul edilebilir hafif stack olarak bırakıldı; kaynak
    // intensity'leri konservatif tutuluyor.
    if (_lightBuffer.isNotEmpty) {
      // Dış halo (4) atmosferik kapsamı veriyor → bu iç katman çekirdek
      // aydınlatma için sıkı tutuldu (radius 0.45×). Hâlâ blur ile yumuşak
      // sınır ama lit area kaynağın hemen çevresinde kalır.
      final coreBounds = _lightLayerBounds(
        size,
        radiusMultiplier: 0.45,
        blurSigma: 6,
      );
      if (coreBounds != null) {
        canvas.saveLayer(
          coreBounds,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        );
        for (final l in _lightBuffer) {
          // Viewport reject — ekran dışı ışıkların gradient + drawCircle pahalı.
          // Core radius * 1.5 (gradient buffer'ı için biraz fazla margin).
          final rCheck = l.radius * 1.5;
          if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
          if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
          final coreA = (l.intensity * 130).round().clamp(0, 140);
          final r = l.radius * 0.45;
          _drawBakedLight(canvas, l.sx, l.sy, r, Colors.white, coreA);
        }
        canvas.restore();
      }
    }

    canvas.restore();

    // (3) Per-light warm wash — sprite hue ısıtma.
    // Mevcut dış halo (4) dış atmosferi tutturuyor ama sprite'a hu zar
    // dokunmuyor (3.5× geniş, alpha düşük). Bu pass daha dar (~1.5×) ve
    // sprite alanını gerçekten warm renge çeker. Modulate'in soğuk grading'i
    // ışık altında iptal olur → contrast = sıcak puddle vs soğuk mehtap.
    // saveLayer + lighten içinde drawn → üst üste binen ışıklar MAX alır
    // (parlama patlaması yok), sonra dış katmana plus ile aktarılır.
    if (_lightBuffer.isNotEmpty && darkness > 0.15) {
      // Warm wash sprite hue ısıtması için sıkı tutuldu (radius 0.55×):
      // sprite alanı warm renge çekilir, atmosferik yayılım dış halo (4)'de.
      final warmBounds = _lightLayerBounds(
        size,
        radiusMultiplier: 0.55,
        blurSigma: 8,
      );
      if (warmBounds != null) {
        canvas.saveLayer(
          warmBounds,
          Paint()
            ..blendMode = BlendMode.plus
            ..isAntiAlias = true
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        );
        for (final l in _lightBuffer) {
          // Viewport reject (warm wash pass)
          final rCheck = l.radius * 2.0;
          if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
          if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
          final innerA = (l.intensity * darkness * 55).round().clamp(0, 65);
          if (innerA < 4) continue;
          final wr = (l.warm.r * 255).round();
          final wg = (l.warm.g * 255).round();
          final wb = (l.warm.b * 255).round();
          final r = l.radius * 0.55;
          _drawBakedLight(
            canvas,
            l.sx,
            l.sy,
            r,
            Color.fromARGB(255, wr, wg, wb),
            innerA,
          );
        }
        canvas.restore();
      }
    }

    // (4) Sıcak halo — geniş atmosferik gauss. Sigma 1.05× core radius +
    // küçük solid çekirdek → ~3σ effective span ama amplitüd asimptotik
    // 0'a düşer (matematik 0-noktası yok = görünür kenar yok). Plus blend
    // ile sahneye additive → kaynakların warm renkleri ortamda fiziksel
    // ışık gibi yayılır. Kaynak türü ayrımı warm renk + radius farkı ile
    // doğal görünür (fire geniş turuncu, lamp dar sarı, ev soluk yanık).
    if (_lightBuffer.isNotEmpty && darkness > 0.20) {
      // Önceki: haloAlpha cap 115, radius 2.5×, sigma 32 — ortalanmış noktada
      // 3 katman birikip patladı. Düşürüldü: cap 35, radius 1.7×, sigma 18.
      final haloBounds = _lightLayerBounds(
        size,
        radiusMultiplier: 1.7,
        blurSigma: 18,
      );
      if (haloBounds != null) {
        canvas.saveLayer(
          haloBounds,
          Paint()
            ..blendMode = BlendMode.plus
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        );
        for (final l in _lightBuffer) {
          // Viewport reject (outer halo pass) — radius 2.5× drawing
          final rCheck = l.radius * 2.5;
          if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
          if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
          final haloAlpha = (l.intensity * darkness * 28).round().clamp(0, 35);
          if (haloAlpha < 3) continue;
          final wr = (l.warm.r * 255).round();
          final wg = (l.warm.g * 255).round();
          final wb = (l.warm.b * 255).round();
          _drawBakedLight(
            canvas,
            l.sx,
            l.sy,
            l.radius * 1.7,
            Color.fromARGB(255, wr, wg, wb),
            haloAlpha,
          );
        }
        canvas.restore();
      }
    }
  }

  /// Tüm binaların gölgesini tek pass'te çizer (sahne sprite'larından önce).
  /// Her bina için light vector aggregation ile yumuşak yön + drop-shadow.
  void _drawBuildingShadows(Canvas canvas, Size size) {
    if (buildings.isEmpty) return;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    final ox = size.width / 2 + camera.dx;
    final oy = size.height * 0.28 + camera.dy;
    bool inView(double gx, double gy) {
      final sx = ox + (gx - gy) * kTileW / 2;
      final sy = oy + (gx + gy) * kTileH / 2;
      return sx >= minX - 160 &&
          sx <= maxX + 160 &&
          sy >= minY - 256 &&
          sy <= maxY + kTileH;
    }

    final shadowBoost = (1.0 - dayLight).clamp(0.0, 1.0);
    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      if (!inView(cx, cy)) continue;
      final corners = _corners(b.col, b.row, b.cols, b.rows, size, camera);
      final lightScr = _aggregateLightForBuilding(b, cx, cy, size);
      _drawBuildingShadow(
        canvas,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        lightScreen: lightScr,
        shadowBoost: shadowBoost,
      );
    }
  }

  // Bina gölge yönü için ışık AGREGASYONU.
  //
  // En yakın tek ışığı seçmek yerine, etki alanındaki tüm güçlü ışıkların
  // vector-sum'ı alınır (ağırlık = intensity × inverse-square distance).
  // İki lamba eşit uzaklıkta ise gölge ortada birleşir; bir lamba söndüğünde
  // yön zıplamadan kayar. "Sanal light" pozisyonu = bina'dan ortalama yöne
  // 5 tile geri — `_drawBuildingShadow` lightScreen olarak bunu kullanır.
  Offset? _aggregateLightForBuilding(
    BuildingEntity b,
    double bcx,
    double bcy,
    Size size,
  ) {
    if (lightSources.isEmpty || dayLight > 0.7) return null;
    final fpR = (b.cols * b.cols + b.rows * b.rows) * 0.25;
    double sumX = 0, sumY = 0;
    for (final l in lightSources) {
      if (l.intensity < 0.30) continue;
      final dx = bcx - l.gx;
      final dy = bcy - l.gy;
      final d2 = dx * dx + dy * dy;
      if (d2 < fpR) continue; // bina içinde — yön verme
      if (d2 > l.radius * l.radius * 2.25) continue;
      // Inverse-square weight × intensity → yakın güçlü ışık baskın.
      final w = l.intensity / (d2 + 0.5);
      sumX += dx * w;
      sumY += dy * w;
    }
    final mag2 = sumX * sumX + sumY * sumY;
    if (mag2 < 1e-4) return null;
    final mag = sqrt(mag2);
    final dirX = sumX / mag;
    final dirY = sumY / mag;
    // Sanal light pozisyonu — bina merkezinden ortalama yöne 5 tile uzaklık.
    return _worldToScreen(bcx - dirX * 5, bcy - dirY * 5, size);
  }

  // Sahnenin baz tonunu modüle eder. day_night_cycle ambientTint/Strength
  // sağlar → strength 0'da identity beyaza lerp ederek modulate atlanır.
  // Modulate fiziksel: az ışık = koyu+tinted, beyaz = nötr. SoftLight'a göre
  // gece atmosferik koyuluğu doğru taşır.
  void _drawAmbientGrade(Canvas canvas, Size size) {
    if (ambientStrength < 0.02) return;
    final s = ambientStrength.clamp(0.0, 1.0);
    // efektif = lerp(white, ambientTint, s). Strength=0 → beyaz → modulate
    // identity. Strength=1 → tint → kanalları tint oranında çarpar.
    final tr = (ambientTint.r * 255).round();
    final tg = (ambientTint.g * 255).round();
    final tb = (ambientTint.b * 255).round();
    final r = (255 - (255 - tr) * s).round().clamp(0, 255);
    final g = (255 - (255 - tg) * s).round().clamp(0, 255);
    final b = (255 - (255 - tb) * s).round().clamp(0, 255);
    _pAmbientGrade.color = Color.fromARGB(255, r, g, b);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _pAmbientGrade,
    );
  }

  // Gündüz renk grade matrisi — kontrast (mid-gray pivot) + luminance-koruyan
  // doygunluk. t = dayGrade (0..1, öğlede 1). ColorFilter.matrix 0..255 ölçekte
  // çalışır; offset sütunu (5.) 0..255. A satırı identity (alfa korunur).
  List<double> _dayGradeMatrix(double t) {
    final s = 1.0 + 0.24 * t; // doygunluk: pastel → canlı
    final k = 1.0 + 0.13 * t; // kontrast: değer ayrımı (form okunur)
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final a = 1.0 - s;
    // Saturation matrisi satırları
    final rr = lr * a + s, rg = lg * a, rb = lb * a;
    final gr = lr * a, gg = lg * a + s, gb = lb * a;
    final br = lr * a, bg = lg * a, bb = lb * a + s;
    final off = 128.0 * (1.0 - k); // kontrast pivot offseti
    return <double>[
      k * rr,
      k * rg,
      k * rb,
      0,
      off,
      k * gr,
      k * gg,
      k * gb,
      0,
      off,
      k * br,
      k * bg,
      k * bb,
      0,
      off,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  // Gündüz atmosfer pass'i — gündüz fast-path'inde çağrılır (overlay şeffaf,
  // tam aydınlık). Gece ışık katmanlarının gündüzdeki karşılığı: düz "boyama"
  // hissini güneş formu + hava perspektifi + bloom + sıcak vignette ile kırar.
  // Hepsi fullscreen blend (saveLayer yok) → ucuz. dayGrade ile ölçeklenir.
  void _drawDayAtmosphere(Canvas canvas, Size size) {
    final t = ((dayLight - 0.55) / 0.45).clamp(0.0, 1.0);
    if (t <= 0.01) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final maxR = max(size.width, size.height);
    int a(int base) => (base * t).round().clamp(0, 255);

    // (a) Güneş yönü formu — sol-üst sıcak / sağ-alt nötr, BlendMode.overlay.
    // Overlay: >mid-gray açar+ısıtır, <mid-gray koyar → sahneye hacim+kontrast.
    _pDayGrade.blendMode = BlendMode.overlay;
    _pDayGrade.shader = ui.Gradient.linear(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.78, size.height),
      [
        Color.fromARGB(a(255), 0x9C, 0x90, 0x74), // güneş tarafı — ılık açma
        Color.fromARGB(a(255), 0x6E, 0x6B, 0x68), // gölge tarafı — hafif koyu
      ],
    );
    canvas.drawRect(rect, _pDayGrade);

    // (b) Hava perspektifi — üst (izometrikte uzak) hafif serin pus, screen.
    _pDayGrade.blendMode = BlendMode.screen;
    _pDayGrade.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height * 0.55),
      [
        Color.fromARGB(a(0x22), 0xB4, 0xC8, 0xDC),
        const Color.fromARGB(0, 0xB4, 0xC8, 0xDC),
      ],
    );
    canvas.drawRect(rect, _pDayGrade);

    // (c) Güneş bloom — üst-orta yumuşak altın saçılma, plus düşük alfa.
    _pDayGrade.blendMode = BlendMode.plus;
    _pDayGrade.shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.10),
      maxR * 0.62,
      [
        Color.fromARGB(a(0x16), 0xFF, 0xE8, 0xAC),
        const Color.fromARGB(0, 0xFF, 0xE8, 0xAC),
      ],
    );
    canvas.drawRect(rect, _pDayGrade);

    // (d) Sıcak vignette — kenarları YUMUŞAK sıcak-koyu (gece soğuğu DEĞİL).
    // multiply: merkez nötr (beyaz), kenar hafif sıcak-bej → güneşli his.
    _pDayGrade.blendMode = BlendMode.multiply;
    final edge = Color.lerp(
      const Color(0xFFFFFFFF),
      const Color(0xFFE6D7BC),
      t,
    )!;
    _pDayGrade.shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.46),
      maxR * 0.74,
      [const Color(0xFFFFFFFF), edge],
    );
    canvas.drawRect(rect, _pDayGrade);

    _pDayGrade.shader = null;
    _pDayGrade.blendMode = BlendMode.srcOver;
  }

  // LightingSystem (world-space) listesi → screen-space _LightInfo buffer.
  // Flicker SADECE intensity (alpha) üzerinden uygulanır → ışık çemberinin
  // dış kenarı pulsating değil, sabit. Toplam parlaklık hafifçe nabız atar,
  // gözü yormaz.
  void _projectLights(Size size) {
    _lightBuffer.clear();
    for (final l in lightSources) {
      final p = _worldToScreen(l.gx, l.gy, size);
      final phase = l.gx * 0.4 + l.gy * 0.7;
      final flicker =
          1.0 +
          sin(time * 3.7 + phase) * 0.04 +
          sin(time * 8.3 + phase * 1.7) * 0.02;
      final rScreen = l.radius * kPixelsPerTile * zoom;
      final dynIntensity = (l.intensity * flicker).clamp(0.0, 1.0);
      _lightBuffer.add(_LightInfo(p.dx, p.dy, rScreen, l.warm, dynIntensity));
    }
  }

  /// Smallest on-screen buffer that can contain a light pass, including the
  /// visible 3σ extent of its Gaussian blur. The scene-wide darkness layer
  /// still covers the full viewport; only the three local-light intermediate
  /// buffers use this bound. This preserves the exact pixels while avoiding
  /// full-screen offscreen textures for lights clustered around the village.
  Rect? _lightLayerBounds(
    Size size, {
    required double radiusMultiplier,
    required double blurSigma,
  }) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final l in _lightBuffer) {
      final extent = l.radius * radiusMultiplier + blurSigma * 3.0;
      if (l.sx + extent < 0 ||
          l.sx - extent > size.width ||
          l.sy + extent < 0 ||
          l.sy - extent > size.height) {
        continue;
      }
      left = min(left, l.sx - extent);
      top = min(top, l.sy - extent);
      right = max(right, l.sx + extent);
      bottom = max(bottom, l.sy + extent);
    }
    if (!left.isFinite) return null;
    final viewport = Rect.fromLTWH(0, 0, size.width, size.height);
    final bounds = Rect.fromLTRB(left, top, right, bottom).intersect(viewport);
    return bounds.isEmpty ? null : bounds;
  }

  // ── Olay overlay'i (tint + partiküller) ─────────────────────────────────
  //
  // Aggregate tint, lighting pass üstüne yumuşak alpha çekilir. Sonra her
  // aktif EventFx için özelleştirilmiş partikül/animasyon pass'i.

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
      old.burningBuildings != burningBuildings ||
      old.perfMode != perfMode;
}
