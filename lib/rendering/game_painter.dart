import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'character_renderer.dart';
import '../entities/villager_entity.dart';
import '../entities/worker_entity.dart';
import '../characters/life_stage.dart';
import '../entities/builder_entity.dart';
import '../entities/build_order.dart';
import '../entities/road_order.dart';
import '../systems/road_system.dart';
import 'road_renderer.dart';
import '../core/constants.dart';
import 'tile_renderer.dart';
import '../world/tree_entity.dart';
import 'tree_renderer.dart';
import '../entities/woodcutter_entity.dart';
import '../world/mine_node.dart';
import 'mine_renderer.dart';
import '../entities/miner_entity.dart';
import 'water_renderer.dart';
import '../world/nature_entity.dart';
import '../world/decor_entity.dart';
import 'nature_renderer.dart';
import 'decor_renderer.dart';
import 'animal_renderer.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../systems/lighting_system.dart';
import '../systems/event_system.dart';
import 'flame_renderer.dart';
import 'particle_renderer.dart';
import 'smoke_renderer.dart';
import '../farm/farm_tile.dart';
import '../entities/farm_farmer.dart';
import '../farm/farm_renderer.dart';
import '../entities/fisher_entity.dart';
import '../entities/florist_entity.dart';
import '../entities/shepherd_entity.dart';
import '../world/animal_entity.dart';
import '../world/bird_flock.dart';
import '../world/resource_box.dart';
import '../world/hay_entity.dart';
import '../world/resource_placement.dart';
import 'resource_renderer.dart';
import 'tool_renderer.dart';

// ── Static Paint havuzu (game_painter genelinde paylaşılır) ───────────────────
// Progress bar
final _ppBg     = Paint()..color = const Color(0xFF111111)..isAntiAlias = false;
final _ppFill   = Paint()..color = const Color(0xFFE8A020)..isAntiAlias = false;
final _ppBorder = Paint()
  ..color = const Color(0xFFFFFFFF)..style = PaintingStyle.stroke
  ..strokeWidth = 1..isAntiAlias = false;

// Selection overlays — sabit renkler, bir kez yaratılır
final _pFarmFill   = Paint()..color = const Color(0x5544AA22)..isAntiAlias = false;
final _pFarmBorder = Paint()
  ..color = const Color(0xCC66DD33)..style = PaintingStyle.stroke
  ..strokeWidth = 1.5..isAntiAlias = false;
final _pLumberFill   = Paint()..color = const Color(0x44AA4400)..isAntiAlias = false;
final _pLumberBorder = Paint()
  ..color = const Color(0xCCDD6600)..style = PaintingStyle.stroke
  ..strokeWidth = 1.5..isAntiAlias = false;

// Marker paints
final _pTreeX = Paint()
  ..color = const Color(0xDDFF3300)..strokeWidth = 2.5..isAntiAlias = false;
final _pMineX = Paint()
  ..color = const Color(0xDDFFCC00)..strokeWidth = 2.0..isAntiAlias = false;

// Scaffold — sıkıştırılmış toprak zemin (build site marker). Ahşap iskele
// kaldırıldı; sprite reveal + hammer spark + completion pop yeterli.
final _pScaffGround = Paint()..color = const Color(0xFFD4B896)..isAntiAlias = false;
final _pScaffBorder = Paint()
  ..color = const Color(0xFF7A5810)..style = PaintingStyle.stroke
  ..strokeWidth = 1..isAntiAlias = false;

// Lighting pass paint havuzu (lokal ışık + halo).
// saveLayer içine karanlık + vignette → bu paint normal blend.
final _pLighting   = Paint()..isAntiAlias = false;
// Light mask buffer — her ışık BlendMode.lighten ile birleştirilir.
// lighten RGB için MAX alır (premul beyaz: R=G=B=a → max RGB = max alpha) ama
// alpha kanalı srcOver-stacked olur. dstOut erasure alpha'yı kullandığı için
// outer Paint'e ColorFilter (alpha = R) konur → gerçek MAX alpha bypass.
final _pLightMask  = Paint()..blendMode = BlendMode.lighten..isAntiAlias = true;
// Sıcak halo paint — saveLayer içinde lighten ile birleştirilir, dış
// saveLayer plus blend ile sahneye uygulanır. Premul-warm RGB'ler için
// lighten zaten MAX verir; plus dst.RGB ekler → overlap'te ekstra parlaklık yok.
final _pWarmHalo   = Paint()..blendMode = BlendMode.lighten..isAntiAlias = true;

// Ambient color grade — fullscreen modulate (= multiply). Sahnenin "günün
// içinde bulunduğu ışık tonu" (mehtap mavi, altın saat amber, ...). Strength=0
// için identity beyaza lerp edilir → öğle neredeyse dokunulmaz.
final _pAmbientGrade = Paint()..blendMode = BlendMode.modulate..isAntiAlias = false;
// Per-light warm wash — sprite'ı ışık alanında ısıtır. BlendMode.plus
// radial gradient, dış halo'dan dar ve daha düşük alfa: hedef sprite hue
// değişimi, parlama patlaması değil. (Layer paint inline yapılıyor —
// imageFilter.blur sigma'sı pass'e özel.)
final _pWarmWash      = Paint()..blendMode = BlendMode.lighten..isAntiAlias = true;
// Mehtap dolgusu — gece ışıksız alanlarda hafif soğuk-mavi plus
// (saveLayer'ın DIŞINA, dstOut tarafından korunmadan). Karanlığı
// "düz siyah" olmaktan kurtarır, ışığa kontrast üretir.
final _pMoonFill = Paint()..blendMode = BlendMode.plus..isAntiAlias = false;

// Map border
final _pMapBorder = Paint()
  ..color = const Color(0xFF1E4820)..style = PaintingStyle.stroke
  ..strokeWidth = 2..isAntiAlias = false;

// Kıyı sisi — kara kenarı boyunca yumuşak karanlık hale. Tek path/frame,
// 3 kalın stroke (azalan alpha) ile yumuşak görünüm — MaskFilter.blur'dan
// 4–8× ucuz (CPU shader yolu).
final _pEdgeMistOuter = Paint()
  ..color = const Color(0x180A1018)..style = PaintingStyle.stroke
  ..strokeWidth = 26..isAntiAlias = false;
final _pEdgeMistMid = Paint()
  ..color = const Color(0x300A1018)..style = PaintingStyle.stroke
  ..strokeWidth = 16..isAntiAlias = false;
final _pEdgeMistInner = Paint()
  ..color = const Color(0x520A1018)..style = PaintingStyle.stroke
  ..strokeWidth = 8..isAntiAlias = false;

// Gece ateş böcekleri — 2 katmanlı circle (geniş soluk + parlak çekirdek).
// Blur yok → particle başı maliyet ~5× düşer.
final _pFireflyGlow = Paint()..isAntiAlias = true;
final _pFireflyCore = Paint()..isAntiAlias = true;

// Gündüz polen/toz zerreleri — küçük blur kaldırıldı, anti-aliased crisp circle.
final _pPollen = Paint()..isAntiAlias = true;

// Ghost
final _pGhostFill   = Paint()..isAntiAlias = false;
final _pGhostBorder = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..isAntiAlias = false;

// Rain — 3 parallax katman + ground splash. Paint havuzu (per-frame
// allocation yok). AA AÇIK: damlalar piksel satırları arasında geçerken
// sub-pixel akıyor → yağmur akıcı kayar. Pixel-art kapalı AA tile/sprite'a
// özgü; ekran uzayı efektleri (yağmur, mist) AA ile daha temiz.
// _pRain: 1px far/mid katmanı, _pRainBold: 1.6px ön katman,
// _pRainTail: ön katman damlaların soluk motion-trail çizgisi.
// _pSplash: yere çarpan damlanın droplet/crown daireleri (fill, AA).
// _pSplashRing: çarpma noktasında genişleyen iso oval (stroke, AA).
// _pRainMist: yoğun yağmurda hafif mavi-gri atmosfer perde overlay.
final _pRain     = Paint()
  ..strokeWidth = 1.0
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
final _pRainBold = Paint()
  ..strokeWidth = 1.6
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
final _pRainTail = Paint()
  ..strokeWidth = 0.9
  ..strokeCap = StrokeCap.round
  ..isAntiAlias = true;
final _pSplash     = Paint()..isAntiAlias = true;
final _pSplashRing = Paint()
  ..style = PaintingStyle.stroke
  ..strokeWidth = 1.0
  ..isAntiAlias = true;
final _pRainMist   = Paint();

// Gölgeler — karakter/ağaç için yumuşak eliptik, bina için yumuşak diamond.
// Önce: 2 katman sert diamond + sert contact AO → toplam 3 stamp, "öküz".
// Şimdi: 2 katman BLUR'LU diamond, alpha düşük → tek yumuşak ambient gölge
// hissi. Contact AO ayrı olarak yok — alttaki katman zaten o işi yapıyor.
final _pShadow              = Paint()..color = const Color(0x77000000)..isAntiAlias = true;
final _pBuildingShadowOuter = Paint()
  ..color = const Color(0x1E000000) // ~12% black, çok soluk halo
  ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 5.0)
  ..isAntiAlias = true;
final _pBuildingShadowInner = Paint()
  ..color = const Color(0x32000000) // ~20% black, çekirdek koyuluk
  ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 2.0)
  ..isAntiAlias = true;

/// Karakterin ayağı altında ince yatay elips. (sx, sy) = feet pozisyonu
/// (her character drawable'da gridToScreen sonucu). [scale] karakterin
/// efektif çizim ölçeği (kCharScale × yaşam-evresi) — gölge boyu onunla orantılı.
void _drawCharShadow(Canvas canvas, double sx, double sy,
    [double scale = kCharScale]) {
  final w = 34 * scale;
  final h = w * 0.34;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(sx, sy + 1), width: w, height: h),
    _pShadow,
  );
}

/// Worker / villager için meşale halo helper'ı — tüm character drawable'lar
/// kullanır. torchLevel ≤ 0.02 ise no-op. Glow konumu sağ omuz + baş üstü.
void _drawWorkerTorchGlow(Canvas canvas, double sx, double sy, WorkerEntity e) {
  if (e.torchLevel <= 0.02) return;
  final shoulderX = (e.effectiveFacingRight ? 1 : -1) * 5.0 * kCharScale;
  final headY = -64 * kCharScale;
  ToolRenderer.drawTorchGlow(canvas, sx + shoulderX, sy + headY,
      _sceneTime, e.torchPhase, intensity: e.torchLevel);
}

/// Ağaç gövdesi tabanında elips — TreeType'a göre genişlik.
/// growthScale fidan büyüme oranı.
void _drawTreeShadow(Canvas canvas, double cx, double cy,
    double widthScale, double growthScale) {
  final w = widthScale * growthScale * 1.25;
  canvas.drawOval(
    Rect.fromCenter(center: Offset(cx, cy + 3), width: w, height: w * 0.34),
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
void _drawBuildingShadow(Canvas canvas, Offset back, Offset left,
    Offset right, Offset front, {Offset? lightScreen, double shadowBoost = 0.0}) {
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
    ..moveTo(back.dx + dx,      back.dy + dy - 1)
    ..lineTo(right.dx + dx + 1, right.dy + dy)
    ..lineTo(front.dx + dx,     front.dy + dy + 1)
    ..lineTo(left.dx + dx - 1,  left.dy + dy)
    ..close();
  canvas.drawPath(_scratchPath, _pBuildingShadowOuter);
  // İç katman
  _scratchPath
    ..reset()
    ..moveTo(back.dx + dx,  back.dy + dy)
    ..lineTo(right.dx + dx, right.dy + dy)
    ..lineTo(front.dx + dx, front.dy + dy)
    ..lineTo(left.dx + dx,  left.dy + dy)
    ..close();
  canvas.drawPath(_scratchPath, _pBuildingShadowInner);
}

// Selection/ghost/scaffold/border için ortak Path havuzu.
// paint() synchronous — Path drawn anında canvas'a yazılır, sonra mutate edebiliriz.
final Path _scratchPath = Path();

// Sahne drawable buffer'ı — her frame clear edilip yeniden doldurulur.
// Spread/sort her frame allocate yapmasın diye top-level static.
final List<_Drawable> _sceneBuffer = [];

// ── Ground Picture cache ─────────────────────────────────────────────────────
// Çim+kum+border katmanı statik — her map için bir kez Picture'a kaydedilir,
// frame'lerde drawPicture ile replay edilir. Camera-bağımsız (Offset.zero ile
// render edildi, outer canvas translate ile yerleştirilir) → pan/zoom sırasında
// bile geçerli. Invalidate: groundVersion artar (yeni map) veya size değişir.
ui.Picture? _groundCache;
int _gcVersion = -1;
double _gcWidth = -1;
double _gcHeight = -1;

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
// (list length aynı) viewport içinde olan bucket'lar iterate edilir; çok
// büyük listeler için her frame full scan'i atlar.
// Invalidate: list length değişimi (entity eklendi/silindi).
final Map<(int, int), List<DecorEntity>>  _decorBuckets   = {};
int _decorBucketsLen = -1;
final Map<(int, int), List<TreeEntity>>   _treeBuckets    = {};
int _treeBucketsLen = -1;
final Map<(int, int), List<LotusEntity>>  _lotusBuckets   = {};
int _lotusBucketsLen = -1;
final Map<(int, int), List<ReedClump>>    _reedBuckets    = {};
int _reedBucketsLen = -1;
final Map<(int, int), List<MineNode>>     _mineNodeBuckets = {};
int _mineNodeBucketsLen = -1;

// ── Lighting buffer ──────────────────────────────────────────────────────────
// Lokal ışık kaynakları (firepit, ev pencereleri, meşaleli NPC). Her frame
// _collectLights doldurulur, sonra lighting pass'ler iki kez tarar
// (karanlık deliği + sıcak halo).
class _LightInfo {
  final double sx, sy;     // ekran piksel pozisyonu
  final double radius;     // ekran piksel yarıçapı
  final Color  warm;       // halo tonu (turuncu/sarı)
  final double intensity;  // 0..1 — alpha ve halo gücü
  const _LightInfo(this.sx, this.sy, this.radius, this.warm, this.intensity);
}
final List<_LightInfo> _lightBuffer = [];

/// Scene buffer drawable'larından erişilen anlık zaman. VillageGamePainter.paint
/// her frame başında set eder; drawable'lar idle anim (nefes/sway) için okur.
double _sceneTime = 0;

// ─── DRAWABLE ABSTRACTION ────────────────────────────────────────────────────

abstract class _Drawable {
  double get depth;
  void draw(Canvas canvas, Size size, Offset camera);
}

class _VillagerDrawable extends _Drawable {
  final VillagerEntity e;
  final double time;
  final double dayLight;
  _VillagerDrawable(this.e, this.time, this.dayLight);
  @override double get depth => e.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    if (e.isInsideBuilding) return;

    final s = gridToScreen(e.renderX, e.renderY, size, camera);

    // Gölge — ayak altında, torch glow'un da altında.  Boyut karakter
    // ölçeğiyle (yaşam-evresi dahil) orantılı.
    _drawCharShadow(canvas, s.dx, s.dy, kCharScale * e.lifeStage.renderScale);

    // Lokal meşale glow + alev — sprite'tan ÖNCE çizilir ki karakter üstüne
    // binsin. Entity.torchLevel tek karar noktası; 0..1 fade. Glow konumu
    // meşalenin GERÇEK ucunda (sağ omuz +x, baş üstü -68 yüksekliği — char
    // scale * lifeStage.renderScale ile ölçeklenmiş).
    final torchLv = e.torchLevel;
    final showTorch = torchLv > 0.02;
    if (showTorch) {
      final charScaleNow = kCharScale * e.lifeStage.renderScale;
      final shoulderX = (e.effectiveFacingRight ? 1 : -1) * 5.0 * charScaleNow;
      final headY = -64 * charScaleNow;
      ToolRenderer.drawTorchGlow(canvas,
          s.dx + shoulderX, s.dy + headY,
          time, e.torchPhase, intensity: torchLv);
    }

    if (e.isSleeping && !e.isInsideBuilding) {
      // Yatay uyku pozu — yastık + battaniye + kapalı göz, hafif breath.
      final sleepScale = kCharScale * e.lifeStage.renderScale;
      canvas.save();
      canvas.translate(s.dx, s.dy);
      canvas.scale(sleepScale, sleepScale);
      CharacterRenderer.drawSleeping(canvas, e.type,
          walkPhase: e.walkPhase,
          flipX: !e.facingRight);
      canvas.restore();
      _drawZzz(canvas, s);
      return;
    }

    // Yaşam evresine göre boy ölçeği — çocuk küçük, yetişkin tam, yaşlı hafif.
    final charScale = kCharScale * e.lifeStage.renderScale;
    // Dans → gerçek zıplama. NPC her vuruşta yere iner çıkar.
    double danceBounce = 0;
    double danceSway   = 0;
    if (e.activity == VillagerActivity.dance) {
      // 2 Hz beat — sin'in mutlak değeri ile sürekli pozitif zıplama.
      danceBounce = sin(time * 6.0 + e.gridX * 1.1).abs() * 4.0;
      danceSway   = sin(time * 3.0 + e.gridX * 0.7) * 0.20;
    }
    // Ateş başı oturma — sprite'ı dikeyde sıkıştırıp aşağı kaydırarak
    // "çömelme" hissi. Anlatıcıda hafif öne-arka sallanma.
    double sitYOff   = 0;
    double sitYScale = 1.0;
    double sitSway   = 0;
    final isSeated = e.isSeatedAtFire && (
        e.activity == VillagerActivity.warm ||
        e.activity == VillagerActivity.storytelling ||
        e.activity == VillagerActivity.listening);
    if (isSeated) {
      sitYOff   = 4;
      sitYScale = 0.78;
      if (e.activity == VillagerActivity.storytelling) {
        sitSway = sin(time * 2.0 + e.gridX) * 0.06;
      }
    }
    canvas.save();
    canvas.translate(s.dx, s.dy - danceBounce + sitYOff);
    if (danceSway != 0) canvas.rotate(danceSway);
    if (sitSway != 0)   canvas.rotate(sitSway);
    // Idle micro-anim — nefes + sway, yalnız dans/oturma yokken anlamlı (idle
    // helper'ları walking/işteyken zaten 0/1 döner).
    if (danceSway == 0 && sitSway == 0) {
      final swayR = e.idleSwayRotation(time);
      if (swayR != 0) canvas.rotate(swayR);
    }
    final breathY = (danceSway == 0 && sitSway == 0) ? e.idleBreathScale(time) : 1.0;
    canvas.scale(charScale, charScale * sitYScale * breathY);
    CharacterRenderer.draw(canvas, e.type,
        flipX:         !e.effectiveFacingRight,
        walkPhase:     e.walkPhase,
        moveIntensity: e.moveIntensity,
        carrying:      e.isCarrying && e.carriedItem != null,
        torchLevel:    torchLv,
        torchPhase:    e.torchPhase,
        visual:        e.visual,
        time:          time,
        stage:         e.lifeStage);
    // Müzik aktivitesinde eline saz/bağlama çiz — sprite scale'inde, göğüs
    // hizasında. Karakter sprite ile birlikte çizilir ki flip etse de doğru
    // tarafta olsun.
    if (e.activity == VillagerActivity.music && e.chatBubbleTime > 0) {
      canvas.save();
      // Göğüs hizası — yaklaşık y=-52 (origin ayakta), x=4 (sağ el).
      canvas.translate(e.facingRight ? 6 : -6, -52);
      // Hafif çalma animasyonu — el sağ-sol küçük titreşim
      canvas.rotate(sin(time * 8 + e.gridX) * 0.08);
      ToolRenderer.drawSaz(canvas);
      canvas.restore();
    }
    canvas.restore();

    // Draw carried item above the villager
    if (e.carriedItem != null) {
      final item = e.carriedItem!;
      if (item is ResourceBox) {
        ResourceRenderer.drawCarriedBox(canvas, item, s.dx, s.dy - danceBounce);
      } else if (item is HayEntity) {
        ResourceRenderer.drawCarriedHay(canvas, item, s.dx, s.dy - danceBounce);
      }
    }
    // Sohbet baloncuğu — chat ve storytelling. Müzik/dans görsel ipucuna sahip.
    if ((e.activity == VillagerActivity.chat ||
         e.activity == VillagerActivity.storytelling) &&
        e.chatBubbleTime > 0 && e.chatBubbleIcon.isNotEmpty) {
      _drawChatBubble(canvas, Offset(s.dx, s.dy - danceBounce + sitYOff),
          e.chatBubbleIcon, e.chatBubbleTime);
    }
    // Müzik aktivitesinde sazın etrafında uçuşan notalar.
    if (e.activity == VillagerActivity.music && e.chatBubbleTime > 0) {
      _drawMusicNotes(canvas, Offset(s.dx, s.dy - danceBounce),
          e.gridX, e.gridY, e.chatBubbleTime);
    }
  }

  void _drawMusicNotes(Canvas canvas, Offset base, double gx, double gy,
      double timeLeft) {
    // 3 nota — farklı fazda yükselip yan kayarak solar.
    const notes = ['♪', '♫', '♩'];
    for (int i = 0; i < 3; i++) {
      final phase = (time * 0.5 + i * 0.33 + gx * 0.1 + gy * 0.13) % 1.0;
      final rise  = phase * 28;
      final sway  = sin(time * 1.5 + i * 1.7 + gx) * 6 * phase;
      double a;
      if (phase < 0.15) {
        a = phase / 0.15;
      } else {
        a = 1.0 - (phase - 0.15) / 0.85;
      }
      a = a.clamp(0.0, 1.0);
      // Aktivite sönerken son 1.5 sn fade out.
      final lifeFade = timeLeft < 1.5 ? (timeLeft / 1.5) : 1.0;
      final alpha = (a * lifeFade * 220).round().clamp(0, 220);
      if (alpha < 10) continue;
      final tp = TextPainter(
        text: TextSpan(
          text: notes[i],
          style: TextStyle(
            fontSize: 10 + i * 1.5,
            color: Color.fromARGB(alpha, 240, 220, 180),
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas,
          Offset(base.dx + 8 + sway, base.dy - 20 - rise));
    }
  }

  void _drawChatBubble(Canvas canvas, Offset base, String icon, double timeLeft) {
    // Fade in (ilk 0.4 sn) + tut + fade out (son 0.6 sn).
    // Kısa sohbet (≤5 sn) ve uzun hikaye (>5 sn) baloncukları için ortak.
    double a;
    if (timeLeft < 0.6) {
      a = timeLeft / 0.6;            // Fade out
    } else if (timeLeft > 4.6 && timeLeft < 5.0) {
      a = (5.0 - timeLeft) / 0.4;    // Kısa baloncuk için fade in
    } else {
      a = 1.0;
    }
    a = a.clamp(0.0, 1.0);
    if (a <= 0.02) return;
    final alpha = (a * 255).round();

    // Hafif yukarı float — yaşıyor hissi.
    final yBob = sin(time * 2 + base.dx * 0.1) * 1.2;
    final cx = base.dx;
    final cy = base.dy - 26 + yBob;

    // Baloncuk arka planı — yumuşak beyaz kart + ince koyu çerçeve.
    final bgPaint = Paint()
      ..color = Color.fromARGB((alpha * 0.92).round(), 250, 246, 232);
    final borderPaint = Paint()
      ..color = Color.fromARGB((alpha * 0.78).round(), 70, 50, 30)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = true;
    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 18, height: 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(rect, bgPaint);
    canvas.drawRRect(rect, borderPaint);
    // Küçük "kuyruk" üçgeni (sprite'a doğru).
    final tail = Path()
      ..moveTo(cx - 2, cy + 7)
      ..lineTo(cx + 2, cy + 7)
      ..lineTo(cx, cy + 11)
      ..close();
    canvas.drawPath(tail, bgPaint);
    canvas.drawPath(tail, borderPaint);
    // İkon metni.
    final tp = TextPainter(
      text: TextSpan(
        text: icon,
        style: TextStyle(
          fontSize: 11,
          color: Color.fromARGB(alpha, 30, 24, 16),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
  }

  void _drawZzz(Canvas canvas, Offset base) {
    // Pixel-art Z'ler — text yerine ParticleRenderer.drawSleepZzz.
    // 3 farklı seed → 3 Z asenkron drift eder, doğal "Z Z Z" hissi.
    final entitySeed = e.gridX.toInt() * 13 + e.gridY.toInt() * 7;
    for (int i = 0; i < 3; i++) {
      // Yatay offset yelpaze — uyuyan NPC baş çevresinde dağıt.
      final ox = (i - 1) * 4.0;
      ParticleRenderer.drawSleepZzz(
          canvas, base.dx + ox, base.dy - 24, time, entitySeed + i * 17);
    }
  }
}

class _BuilderDrawable extends _Drawable {
  final BuilderEntity b;
  _BuilderDrawable(this.b);
  @override double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(b.renderX, b.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, b);
    final working = b.state == BuilderState.building;
    canvas.save();
    canvas.translate(s.dx, s.dy);
    // Çekiç sallarken idle anim uygulama; aksi halde nefes + sway.
    if (!working) {
      final swayR = b.idleSwayRotation(_sceneTime);
      if (swayR != 0) canvas.rotate(swayR);
    }
    final breathY = working ? 1.0 : b.idleBreathScale(_sceneTime);
    canvas.scale(kCharScale, kCharScale * breathY);
    CharacterRenderer.drawBuilder(canvas,
        flipX:         !b.effectiveFacingRight,
        visual:        b.visual,
        time:          _sceneTime,
        torchLevel:    b.torchLevel,
        torchPhase:    b.torchPhase,
        walkPhase:     b.walkPhase,
        moveIntensity: b.moveIntensity,
        working:       working);
    canvas.restore();

    if (working && b.currentBuildOrder != null) {
      _drawProgressBar(canvas, s, b.currentBuildOrder!.progress);
      // Çekiç vuruş anı: walkPhase'in sin tepe noktasında (sin > 0.92, ~%8 frame).
      // Building state phaseRate 4.0 rad/sn → her ~1.57sn'de bir vuruş.
      // Spark builder'ın çekiç-ucu civarında 2-3 küçük sarı-beyaz nokta.
      final swing = sin(b.walkPhase).abs();
      if (swing > 0.92) {
        _drawHammerSpark(canvas, s.dx, s.dy, b.facingRight);
      }
    }
  }

  void _drawHammerSpark(Canvas canvas, double sx, double sy, bool facingRight) {
    final dir = facingRight ? 1.0 : -1.0;
    final px = sx + dir * 14;
    final py = sy - 38; // builder kafa-omuz hizası
    final paint = Paint()
      ..color = const Color(0xFFFFFFB0)
      ..isAntiAlias = false;
    final paintDim = Paint()
      ..color = const Color(0xCCFFD060)
      ..isAntiAlias = false;
    canvas.drawRect(Rect.fromLTWH(px, py, 2, 2), paint);
    canvas.drawRect(Rect.fromLTWH(px + dir * 3, py - 2, 2, 2), paint);
    canvas.drawRect(Rect.fromLTWH(px - dir * 2, py + 2, 1, 1), paintDim);
    canvas.drawRect(Rect.fromLTWH(px + dir * 5, py + 1, 1, 1), paintDim);
  }

  void _drawProgressBar(Canvas canvas, Offset pos, double progress) {
    const w = 34.0;
    const h = 4.0;
    final left = pos.dx - w / 2;
    final top  = pos.dy - 52;
    canvas.drawRect(Rect.fromLTWH(left, top, w, h),           _ppBg);
    canvas.drawRect(Rect.fromLTWH(left, top, w * progress, h), _ppFill);
    canvas.drawRect(Rect.fromLTWH(left, top, w, h),            _ppBorder);
  }
}

class _FarmerDrawable extends _Drawable {
  final FarmFarmer f;
  _FarmerDrawable(this.f);
  @override double get depth => f.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(f.renderX, f.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, f);
    canvas.save();
    canvas.translate(s.dx, s.dy);
    final swayR = f.idleSwayRotation(_sceneTime);
    if (swayR != 0) canvas.rotate(swayR);
    canvas.scale(kCharScale, kCharScale * f.idleBreathScale(_sceneTime));
    CharacterRenderer.drawFarmer(canvas,
        flipX:         !f.effectiveFacingRight,
        walkPhase:     f.walkPhase,
        moveIntensity: f.moveIntensity,
        harvesting:    f.state == FarmerState.harvesting,
        harvestPhase:  f.harvestPhase,
        carryingWater: f.isHandlingWater,
        visual:        f.visual,
        time:          _sceneTime,
        torchLevel:    f.torchLevel,
        torchPhase:    f.torchPhase);
    canvas.restore();

    // Splash: kuyu su alımı + ekin sulama anlarının ilk 0.4 sn'sinde.
    // _waterTimer state geçişinde 0'lanır → her aksiyonda bir kez splash.
    if (f.state == FarmerState.fetchingWater ||
        f.state == FarmerState.watering) {
      final wt = f.waterTimerForSplash;
      if (wt >= 0 && wt < 0.4) {
        final lt = wt / 0.4;
        ParticleRenderer.drawSplash(canvas, s.dx, s.dy - 10, lt);
      }
    }
  }
}

class _MinerDrawable extends _Drawable {
  final MinerEntity m;
  _MinerDrawable(this.m);
  @override double get depth => m.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(m.renderX, m.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, m);
    canvas.save();
    canvas.translate(s.dx, s.dy);
    final swayR = m.idleSwayRotation(_sceneTime);
    if (swayR != 0) canvas.rotate(swayR);
    canvas.scale(kCharScale, kCharScale * m.idleBreathScale(_sceneTime));
    CharacterRenderer.drawMiner(canvas,
        flipX:         !m.effectiveFacingRight,
        walkPhase:     m.walkPhase,
        moveIntensity: m.moveIntensity,
        mining:        m.isMining,
        chopPhase:     m.chopPhase,
        visual:        m.visual,
        time:          _sceneTime,
        torchLevel:    m.torchLevel,
        torchPhase:    m.torchPhase);
    canvas.restore();

    // Mining iken her chopPhase cycle başında taş chip uçur.
    // Cycle 2π rad (~1.5sn). İlk %30'u chip lifetime.
    if (m.isMining) {
      const chipWindow = 2 * pi * 0.30;
      if (m.chopPhase < chipWindow) {
        final lt = m.chopPhase / chipWindow;
        // Spawn point: kazma ucu civarı (kafa-omuz hizası, yüzü yöne)
        final dir = m.facingRight ? 1.0 : -1.0;
        final ox = dir * 12;
        final oy = -18;
        final seed = m.gridX.toInt() * 7 + m.gridY.toInt() * 13;
        ParticleRenderer.drawChip(canvas,
            s.dx + ox, s.dy + oy, lt,
            color: const Color(0xFFA8A4A0),
            shade: const Color(0xFF5A5450),
            direction: dir, seed: seed);
      }
    }
  }
}

class _MineDrawable extends _Drawable {
  final MineNode n;
  _MineDrawable(this.n);
  @override double get depth => n.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(n.col.toDouble(), n.row.toDouble(), size, camera);
    MineRenderer.draw(canvas, s.dx, s.dy,
        type: n.type,
        chopPhase: n.chopPhase,
        seed: n.col * 13 + n.row * 29);
  }
}

class _WoodcutterDrawable extends _Drawable {
  final WoodcutterEntity w;
  _WoodcutterDrawable(this.w);
  @override double get depth => w.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(w.renderX, w.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, w);
    canvas.save();
    canvas.translate(s.dx, s.dy);
    final swayR = w.idleSwayRotation(_sceneTime);
    if (swayR != 0) canvas.rotate(swayR);
    canvas.scale(kCharScale, kCharScale * w.idleBreathScale(_sceneTime));
    CharacterRenderer.drawWoodcutter(canvas,
        flipX:         !w.effectiveFacingRight,
        walkPhase:     w.walkPhase,
        moveIntensity: w.moveIntensity,
        chopping:      w.isChopping,
        chopPhase:     w.chopPhase,
        visual:        w.visual,
        time:          _sceneTime,
        torchLevel:    w.torchLevel,
        torchPhase:    w.torchPhase);
    canvas.restore();

    // Chopping iken her cycle başında sarı-kahve tahta yongası uçur.
    if (w.isChopping) {
      const chipWindow = 2 * pi * 0.30;
      if (w.chopPhase < chipWindow) {
        final lt = w.chopPhase / chipWindow;
        final dir = w.facingRight ? 1.0 : -1.0;
        final seed = w.gridX.toInt() * 7 + w.gridY.toInt() * 13;
        ParticleRenderer.drawChip(canvas,
            s.dx + dir * 12, s.dy - 18, lt,
            color: const Color(0xFFCFA060),  // açık sarı-kahve tahta
            shade: const Color(0xFF8A6A40),
            direction: dir, seed: seed);
      }
    }
  }
}

class _FisherDrawable extends _Drawable {
  final FisherEntity f;
  _FisherDrawable(this.f);
  @override double get depth => f.depth;
  // Fisher splash wiring _FisherDrawable.draw içinde — fishPhase cycle başına
  // tek splash (kıyıya doğru biraz öne).
  void _maybeSplash(Canvas canvas, double sx, double sy) {
    if (!f.isFishing) return;
    // fishPhase 0..2π döngüde. İlk %25'i splash lifetime → ~0.3 sn.
    const window = 2 * pi * 0.25;
    if (f.fishPhase >= window) return;
    final lt = f.fishPhase / window;
    final dir = f.facingRight ? 1.0 : -1.0;
    // Su olta uzantısında — fisher önünde ~14 px, biraz aşağıda.
    ParticleRenderer.drawSplash(canvas, sx + dir * 14, sy - 4, lt);
  }
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(f.renderX, f.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, f);
    canvas.save();
    canvas.translate(s.dx, s.dy);
    final swayR = f.idleSwayRotation(_sceneTime);
    if (swayR != 0) canvas.rotate(swayR);
    canvas.scale(kCharScale, kCharScale * f.idleBreathScale(_sceneTime));
    CharacterRenderer.drawFisher(canvas,
        flipX:         !f.effectiveFacingRight,
        walkPhase:     f.walkPhase,
        moveIntensity: f.moveIntensity,
        fishing:       f.isFishing,
        fishPhase:     f.fishPhase,
        visual:        f.visual,
        time:          _sceneTime,
        torchLevel:    f.torchLevel,
        torchPhase:    f.torchPhase);
    canvas.restore();
    _maybeSplash(canvas, s.dx, s.dy);
  }
}

class _FloristDrawable extends _Drawable {
  final FloristEntity fl;
  _FloristDrawable(this.fl);
  @override double get depth => fl.gridX + fl.gridY;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(fl.renderX, fl.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, fl);
    canvas.save();
    canvas.translate(s.dx, s.dy);
    final swayR = fl.idleSwayRotation(_sceneTime);
    if (swayR != 0) canvas.rotate(swayR);
    canvas.scale(kCharScale, kCharScale * fl.idleBreathScale(_sceneTime));
    // Çiçekçi = farmer + watering can (carryingWater) + watering anında bend
    // (harvesting motion'unu sulama hareketi olarak yeniden kullanırız).
    CharacterRenderer.drawFarmer(canvas,
        flipX:         !fl.effectiveFacingRight,
        walkPhase:     fl.walkPhase,
        moveIntensity: fl.moveIntensity,
        harvesting:    fl.isWatering,
        harvestPhase:  fl.waterPhase,
        carryingWater: true,
        visual:        fl.visual,
        time:          _sceneTime,
        torchLevel:    fl.torchLevel,
        torchPhase:    fl.torchPhase);
    canvas.restore();
  }
}

class _ShepherdDrawable extends _Drawable {
  final ShepherdEntity sh;
  _ShepherdDrawable(this.sh);
  @override double get depth => sh.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(sh.renderX, sh.renderY, size, camera);
    _drawCharShadow(canvas, s.dx, s.dy);
    _drawWorkerTorchGlow(canvas, s.dx, s.dy, sh);
    canvas.save();
    canvas.translate(s.dx, s.dy);
    final swayR = sh.idleSwayRotation(_sceneTime);
    if (swayR != 0) canvas.rotate(swayR);
    canvas.scale(kCharScale, kCharScale * sh.idleBreathScale(_sceneTime));
    CharacterRenderer.drawShepherd(canvas,
        flipX:         !sh.effectiveFacingRight,
        visual:        sh.visual,
        time:          _sceneTime,
        torchLevel:    sh.torchLevel,
        torchPhase:    sh.torchPhase,
        walkPhase:     sh.walkPhase,
        moveIntensity: sh.moveIntensity,
        milking:       sh.isMilking,
        milkPhase:     sh.milkPhase);
    canvas.restore();
  }
}

class _CowDrawable extends _Drawable {
  final AnimalEntity a;
  _CowDrawable(this.a);
  @override double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawCow(
      canvas,
      s,
      facing:     a.facing4,
      walkPhase:  a.walkPhase,
      isWalking:  a.isWalking,
    );
  }
}

class _SheepDrawable extends _Drawable {
  final AnimalEntity a;
  _SheepDrawable(this.a);
  @override double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawSheep(
      canvas,
      s,
      facing:     a.facing4,
      walkPhase:  a.walkPhase,
      isWalking:  a.isWalking,
    );
  }
}

class _ChickenDrawable extends _Drawable {
  final AnimalEntity a;
  _ChickenDrawable(this.a);
  @override double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawChicken(
      canvas,
      s,
      facing:     a.facing4,
      walkPhase:  a.walkPhase,
      isWalking:  a.isWalking,
    );
  }
}

class _DecorDrawable extends _Drawable {
  final DecorEntity d;
  _DecorDrawable(this.d);
  @override double get depth => d.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(d.col + 0.5 + d.jitterX, d.row + 0.5 + d.jitterY, size, camera);
    DecorRenderer.draw(canvas, center, d);
  }
}

class _LotusDrawable extends _Drawable {
  final LotusEntity l;
  final double time;
  _LotusDrawable(this.l, this.time);
  @override double get depth => l.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(l.col + 0.5, l.row + 0.5, size, camera);
    NatureRenderer.drawLotus(canvas, center,
        variant: l.variant, time: time, seed: l.col * 23 + l.row * 37);
  }
}

class _ReedDrawable extends _Drawable {
  final ReedClump r;
  final double time;
  _ReedDrawable(this.r, this.time);
  @override double get depth => r.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    // İki tile'ın üst köşelerinin ortası
    final s1 = gridToScreen(r.col.toDouble(),  r.row.toDouble(),  size, camera);
    final s2 = gridToScreen(r.col2.toDouble(), r.row2.toDouble(), size, camera);
    final cx = (s1.dx + s2.dx) / 2;
    final cy = (s1.dy + s2.dy) / 2 + kTileH / 2; // tile orta yüksekliğine in
    NatureRenderer.drawReeds(canvas, cx, cy,
        time: time, seed: r.col * 19 + r.row * 41,
        col: r.col.toDouble(), row: r.row.toDouble());
  }
}

class _TreeDrawable extends _Drawable {
  final TreeEntity t;
  final double time;
  _TreeDrawable(this.t, this.time);
  @override double get depth => t.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(t.col + 0.5, t.row + 0.5, size, camera);
    // Çam gövdesi tabanında dar elips gölge
    _drawTreeShadow(canvas, center.dx, center.dy, 28.0, t.growthScale);
    TreeRenderer.draw(canvas, t.type, center,
        time: time, seed: t.col * 17 + t.row * 31,
        chopPhase: t.chopPhase,
        growthScale: t.growthScale,
        col: t.col + 0.5, row: t.row + 0.5);
  }
}

class _BuildingDrawable extends _Drawable {
  final BuildingEntity b;
  final double time;
  final double dayLight;
  final double rainIntensity;
  /// fireOutbreak event'inde bu bina yanıyor mu — sprite üstüne alev + duman.
  final bool burning;
  final bool perfMode;
  _BuildingDrawable(this.b, this.time, this.dayLight, this.rainIntensity,
      this.burning, this.perfMode);
  // Painter's algorithm: bina ön-en (frontmost) tile'ının diagonal sum'ı.
  // (col+cols-1, row+rows-1) bina footprint'inin güney-doğu (ön) tile'ı.
  // Eski formül (col+row + (cols+rows)/2 = orta) → bina arkasındaki NPC önde
  // görünebiliyordu. Ön-tile sort'u izometride doğru z-order verir.
  @override double get depth =>
      (b.col + b.cols - 1.0) + (b.row + b.rows - 1.0);
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final corners = _corners(b.col, b.row, b.cols, b.rows, size, camera);
    // GÖLGE ARTIK BURADA ÇİZİLMEZ — ayrı pass'te (paint() başında, sahne
    // sprite'larından önce). Bu sayede başka binaların gölgesi bu sprite'ın
    // üstüne taşmaz, hep zemin seviyesinde kalır.

    // Spawn pop: ilk 0.6 sn'de overshoot settle (scale 1.06 → 1.0). Anchor =
    // front köşe → bina alttan büyür gibi durur. spawnTime == 0 (eski/init
    // binalar) için 0..0.6 aralığı kapalı, hiç pop yok.
    final age = b.spawnTime > 0 ? time - b.spawnTime : 999.0;
    final popping = age >= 0 && age < 0.6;
    if (popping) {
      final t = age / 0.6;
      final scale = 1.0 + 0.06 * (1.0 - t) * (1.0 - t);
      final fx = corners.$4.dx;
      final fy = corners.$4.dy;
      canvas.save();
      canvas.translate(fx, fy);
      canvas.scale(scale, scale);
      canvas.translate(-fx, -fy);
      BuildingRenderer.draw(canvas, b.type, corners.$1, corners.$2, corners.$3, corners.$4,
          time: time, seed: b.col * 17 + b.row * 31,
          dayLight: dayLight, rainIntensity: rainIntensity,
          isActive: b.isActive, perfMode: perfMode);
      canvas.restore();
    } else {
      BuildingRenderer.draw(canvas, b.type, corners.$1, corners.$2, corners.$3, corners.$4,
          time: time, seed: b.col * 17 + b.row * 31,
          dayLight: dayLight, rainIntensity: rainIntensity,
          isActive: b.isActive, perfMode: perfMode);
    }

    // Toz bulutu — ilk 0.4 sn footprint kenarlarında 3 partikül. Açık bej ton.
    if (b.spawnTime > 0 && age >= 0 && age < 0.4) {
      final dust = 1.0 - age / 0.4;
      final midY = (corners.$2.dy + corners.$3.dy) * 0.5 + 2;
      final fw = (corners.$3.dx - corners.$2.dx).abs();
      final dustScale = 0.35 + fw / 200.0; // büyük bina ~ daha geniş toz
      const dustTint = Color(0xFFE8DCC4);
      SmokeRenderer.draw(canvas, corners.$2.dx + 4, midY,
          dustScale, time, b.col * 31 + b.row * 7,
          tint: dustTint, intensity: dust);
      SmokeRenderer.draw(canvas, corners.$4.dx, corners.$4.dy - 1,
          dustScale, time, b.col * 31 + b.row * 11,
          tint: dustTint, intensity: dust);
      SmokeRenderer.draw(canvas, corners.$3.dx - 4, midY,
          dustScale, time, b.col * 31 + b.row * 13,
          tint: dustTint, intensity: dust);
    }

    if (burning) {
      _drawBurningOverlay(canvas, corners.$1, corners.$2, corners.$3, corners.$4);
    }

    // Pazar satış parıltısı — son satış üstünden < 1sn ise altın yukarı çıkar.
    if (b.lastSaleTime > 0) {
      final saleAge = time - b.lastSaleTime;
      if (saleAge >= 0 && saleAge < 1.0) {
        // Pazar üstü merkez — back ile front'un X ortası, back Y'den biraz aşağı.
        final cx = (corners.$1.dx + corners.$4.dx) * 0.5;
        final cy = corners.$1.dy + 4;
        ParticleRenderer.drawGoldSparkle(canvas, cx, cy, saleAge);
      }
    }
  }

  // Yanan bina overlay'i — sprite çatısı/orta seviyesinde 2-3 alev + yukarı
  // kalkan koyu duman partikülleri + sıcak halo. Footprint köşelerinden
  // ortalanmış pozisyon hesabı.
  static final Paint _pBurnGlow  = Paint()..isAntiAlias = true;

  void _drawBurningOverlay(Canvas canvas,
      Offset back, Offset left, Offset right, Offset front) {
    // Sprite çatı orta noktası: footprint orta x, back y (sprite yukarı
    // doğru uzar). Tile genişliğine göre alev ölçeği.
    final cx = (back.dx + front.dx) * 0.5;
    final roofY = (back.dy + left.dy) * 0.5 - 4; // back'ten biraz yukarı
    final tileW = (right.dx - left.dx).abs();
    final flameScale = tileW / 26.0;

    // Sıcak halo (additive plus blend — gece sıcak parlama)
    final pulse = sin(time * 4.7 + b.col * 0.3) * 0.15 + 0.85;
    _pBurnGlow.blendMode = BlendMode.plus;
    _pBurnGlow.color = Color.fromARGB(
        (140 * pulse).round().clamp(0, 200), 0xFF, 0x60, 0x18);
    canvas.drawCircle(Offset(cx, roofY), 30 * flameScale, _pBurnGlow);
    _pBurnGlow.blendMode = BlendMode.srcOver;

    // Birden fazla alev — çatıya yayılır
    for (int i = 0; i < 3; i++) {
      final fx = cx + (i - 1) * (10 * flameScale);
      final fy = roofY - (i == 1 ? 4 * flameScale : 0);
      FlameRenderer.draw(canvas, fx, fy, flameScale * 2.0,
          time + i * 0.41, b.col * 7 + i,
          intensity: 1.0, sparks: true);
    }

    // Yangın dumanı — sprite-based, koyu siyah-gri tint, yoğun yüksek scale.
    // İki duman sütunu (çatının iki ucundan) → yangının büyüklüğünü vurgular.
    SmokeRenderer.draw(canvas, cx - 4 * flameScale, roofY,
        flameScale * 2.4, time, b.col * 17 + b.row * 31,
        tint: const Color(0xFF504842), intensity: 1.0);
    SmokeRenderer.draw(canvas, cx + 4 * flameScale, roofY - 2,
        flameScale * 2.0, time + 0.7, b.col * 23 + b.row * 41 + 7,
        tint: const Color(0xFF504842), intensity: 0.9);
  }
}

class _ScaffoldDrawable extends _Drawable {
  final BuildOrder order;
  final double time;
  _ScaffoldDrawable(this.order, this.time);
  @override
  double get depth {
    // Ön köşe — _BuildingDrawable ile aynı kuralda kalmak için tutarlı.
    final m = kBuildingMeta[order.type]!;
    return (order.col + m.cols - 1.0) + (order.row + m.rows - 1.0);
  }
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final m = kBuildingMeta[order.type]!;
    final (back, left, right, front) = _corners(order.col, order.row, m.cols, m.rows, size, camera);

    // ── 1) Zemin diamond — inşaat alanı (toprak/sıkıştırılmış renk) ──
    _scratchPath
      ..reset()
      ..moveTo(back.dx,  back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx,  left.dy)
      ..close();
    canvas.drawPath(_scratchPath, _pScaffGround);
    canvas.drawPath(_scratchPath, _pScaffBorder);

    // ── 2) Bina sprite reveal (smoothstep + jitter + clip kenarı gölge) ──
    BuildingRenderer.drawConstruction(
        canvas, order.type, left, right, front, order.progress, time);
  }
}

(Offset, Offset, Offset, Offset) _corners(int col, int row, int cols, int rows, Size size, Offset camera) {
  final back  = gridToScreen(col.toDouble(),          row.toDouble(),          size, camera);
  final left  = gridToScreen(col.toDouble(),          (row + rows).toDouble(), size, camera);
  final right = gridToScreen((col + cols).toDouble(), row.toDouble(),          size, camera);
  final front = gridToScreen((col + cols).toDouble(), (row + rows).toDouble(), size, camera);
  return (back, left, right, front);
}

class _ResourceBoxDrawable extends _Drawable {
  final ResourceBox b;
  final double time;
  _ResourceBoxDrawable(this.b, this.time);
  @override double get depth {
    // Stack içindeki ön-arka offset depth'e dahil — aynı tile'da öndeki
    // kutu arkadakini sprite olarak kapatır.
    final off = ResourcePlacement.offsetFor(b.slotIndex);
    return (b.gridX + off.$1) + (b.gridY + off.$2);
  }
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final off = ResourcePlacement.offsetFor(b.slotIndex);
    final s = gridToScreen(b.gridX + off.$1, b.gridY + off.$2, size, camera);
    ResourceRenderer.drawBox(canvas, b, s.dx, s.dy, time);
  }
}

class _HayDrawable extends _Drawable {
  final HayEntity h;
  final double time;
  _HayDrawable(this.h, this.time);
  @override double get depth {
    if (h.isBale) return h.gridX + h.gridY + 1.0;
    final off = ResourcePlacement.offsetFor(h.slotIndex);
    return (h.gridX + off.$1) + (h.gridY + off.$2);
  }
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    if (h.isBale) {
      const bs = 0.5;
      final right = gridToScreen(h.gridX + bs, h.gridY,       size, camera);
      final left  = gridToScreen(h.gridX,      h.gridY + bs,  size, camera);
      final front = gridToScreen(h.gridX + bs, h.gridY + bs,  size, camera);
      final spriteW = (right.dx - left.dx).abs();
      ResourceRenderer.drawBale(canvas, front.dx, front.dy, spriteW, time, h);
    } else {
      final off = ResourcePlacement.offsetFor(h.slotIndex);
      final s = gridToScreen(h.gridX + off.$1, h.gridY + off.$2, size, camera);
      ResourceRenderer.drawHay(canvas, h, s.dx, s.dy, time);
    }
  }
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────

class VillageGamePainter extends CustomPainter {
  final List<VillagerEntity> villagers;
  final List<BuildingEntity> buildings;
  final List<BuilderEntity>  builders;
  final List<BuildOrder>     pendingOrders;
  final RoadSystem           roadSystem;
  final List<RoadOrder>      pendingRoadOrders;
  final Offset camera;
  final BuildingType? ghostType;
  final (int, int)?   ghostTile;
  final bool          ghostValid;
  final double        time;

  /// Day/night overlay — sahnenin üstüne çizilen vertical gradient'in
  /// üst/alt renkleri. Şafak/gün batımında üst mor-pembe, alt sıcak turuncu;
  /// gecede üst koyu lacivert, alt biraz açık tonda → atmosferik derinlik.
  final Color  overlayTop;
  final Color  overlayBottom;
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
  final Color  ambientTint;
  /// 0 = identity (sprite dokunulmaz), 1 = tam modulate. Painter strength=0'da
  /// pass'i atlar; aradaki değerler için tint'i beyaza lerp ederek uygular.
  final double ambientStrength;

  final List<FarmTile>   farmTiles;
  final List<FarmFarmer> farmers;
  /// Çoklu tarla seçim önizlemesi: (c1, r1, c2, r2)
  final (int, int, int, int)? farmSelection;

  final List<TreeEntity>       trees;
  final List<WoodcutterEntity> woodcutters;
  /// Oduncu alan seçim önizlemesi: (c1, r1, c2, r2)
  final (int, int, int, int)? lumberSelection;

  final List<MineNode>    mineNodes;
  final List<MinerEntity> miners;
  /// Madenci alan seçim önizlemesi
  final (int, int, int, int)? mineSelection;

  final Set<(int, int)>  waterTiles;
  final double           dayLight;
  final List<LotusEntity> lotuses;
  final List<ReedClump>   reeds;
  final List<DecorEntity> decor;
  final List<FisherEntity> fishers;
  final List<FloristEntity> florists;
  final List<ShepherdEntity> shepherds;
  final List<AnimalEntity>   cows;
  final double zoom;
  final List<ResourceBox> resourceBoxes;
  final List<HayEntity>   hayEntities;
  /// Suya yansıtılan gökyüzü tonu — _cycle.skyMid'den geçer.
  final Color skyReflection;
  /// Ground katman cache invalidation tokeni. Bu değer değişince Picture
  /// yeniden üretilir. VillageScene yeni harita ürettiğinde artırır.
  final int groundVersion;
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
  /// Performans modu — true ise pahalı ambient/light effect pass'leri atlanır
  /// (fireflies, polen, kuş, bina shadow refinement, light pass detayı).
  final bool perfMode;

  const VillageGamePainter({
    required this.villagers,
    required this.buildings,
    required this.builders,
    required this.pendingOrders,
    required this.roadSystem,
    this.pendingRoadOrders = const [],
    required this.camera,
    this.ghostType,
    this.ghostTile,
    this.ghostValid    = false,
    this.time          = 0,
    this.overlayTop    = const Color(0x00000000),
    this.overlayBottom = const Color(0x00000000),
    this.rainIntensity = 0.0,
    this.nightClarity  = 0.0,
    this.ambientTint     = const Color(0xFFFFFFFF),
    this.ambientStrength = 0.0,
    this.farmTiles     = const [],
    this.farmers       = const [],
    this.farmSelection,
    this.trees         = const [],
    this.woodcutters   = const [],
    this.lumberSelection,
    this.mineNodes     = const [],
    this.miners        = const [],
    this.mineSelection,
    this.waterTiles    = const {},
    this.dayLight      = 1.0,
    this.lotuses       = const [],
    this.reeds         = const [],
    this.decor         = const [],
    this.fishers       = const [],
    this.florists      = const [],
    this.shepherds     = const [],
    this.cows          = const [],
    this.zoom          = 1.0,
    this.resourceBoxes = const [],
    this.hayEntities   = const [],
    this.skyReflection = const Color(0xFFA0C0E0),
    this.groundVersion = 0,
    this.lightSources  = const [],
    this.eventTint     = const Color(0x00000000),
    this.activeFx      = const {},
    this.burningBuildings = const {},
    this.birdFlocks    = const [],
    this.perfMode      = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _sceneTime = time;
    // ── Zoom: dünya içeriği ekran merkezine göre ölçeklenir ──────────────────
    final cx = size.width  / 2;
    final cy = size.height / 2;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(zoom, zoom);
    canvas.translate(-cx, -cy);

    _drawGround(canvas, size);
    _drawFarmTiles(canvas, size);
    _drawWaterFoam(canvas, size);
    // Bina gölgeleri — sahne sprite'larından ÖNCE, zemin üstüne. Bu sayede
    // hiçbir bina gölgesi başka sprite'ın üstüne taşıyamaz.
    // PerfMode: light aggregation iteration ağır; basit drop-shadow yeterli.
    if (!perfMode) _drawBuildingShadows(canvas, size);
    _drawRoads(canvas, size);
    if (farmSelection   != null) _drawFarmSelection(canvas, size);
    if (lumberSelection != null) _drawLumberSelection(canvas, size);
    if (mineSelection   != null) _drawMineSelection(canvas, size);
    _drawScene(canvas, size);
    _drawMarkedTrees(canvas, size);
    _drawMarkedMines(canvas, size);
    if (ghostType != null && ghostTile != null) {
      _drawGhost(canvas, size);
    }

    canvas.restore();

    // ── Ekran uzayı efektleri (zoom'dan etkilenmez) ──────────────────────────
    // Lighting pass: gradient karanlık + vignette + lokal ışık + sıcak halo.
    _drawLightingPass(canvas, size);
    // PerfMode: ambient partikül pass'lerini atla (her frame yüzlerce circle).
    if (!perfMode) {
      _drawFireflies(canvas, size);
      _drawPollen(canvas, size);
      _drawBirdFlocks(canvas, size);
    }
    _drawRain(canvas, size);
    // Event overlay — aktif olayların ekran toneu + olaya özel partiküller.
    _drawEventOverlay(canvas, size);
  }

  /// Dünya (grid) noktasını, paint()'teki zoom dönüşümüyle aynı biçimde ekran
  /// koordinatına çevirir. Gece overlay'inin ÜSTÜNE çizilen efektler için.
  Offset _worldToScreen(double gx, double gy, Size size) {
    final s  = gridToScreen(gx, gy, size, camera);
    final cx = size.width / 2;
    final cy = size.height / 2;
    return Offset(cx + (s.dx - cx) * zoom, cy + (s.dy - cy) * zoom);
  }

  // ── Gece ateş böcekleri ─────────────────────────────────────────────────────
  // Geceleri kara üzerinde yavaşça süzülen, parıldayan sıcak ışık noktaları.
  // Prosedürel (durumsuz): konum index + time'dan türer. Overlay sonrası çizilir
  // ki parlasın; gündüz/yağmurda görünmez.
  void _drawFireflies(Canvas canvas, Size size) {
    final strength = ((0.42 - dayLight) / 0.42).clamp(0.0, 1.0);
    if (strength <= 0.01 || rainIntensity > 0.3) return;
    // Zoom çok küçükse particle'lar görünmez derecede ufalır — kısıt.
    final count = zoom < 0.4 ? 18 : (zoom < 0.7 ? 28 : 38);
    for (int i = 0; i < count; i++) {
      final h     = i * 73856093;
      final baseC = (h % 1000) / 1000.0 * kCols;
      final baseR = ((h ~/ 1000) % 1000) / 1000.0 * kRows;
      final gx    = baseC + sin(time * 0.18 + i * 1.3) * 1.4;
      final gy    = baseR + cos(time * 0.15 + i * 2.1) * 1.1;
      final p     = _worldToScreen(gx, gy, size);
      if (p.dx < -20 || p.dx > size.width + 20 ||
          p.dy < -20 || p.dy > size.height + 20) {
        continue;
      }
      final tw = sin(time * 2.3 + i * 4.7) * 0.5 + 0.5;
      final a  = (strength * tw * tw * 205).round().clamp(0, 220);
      if (a < 8) continue;
      final r = (1.6 + tw * 1.4) * zoom;
      // Blur yerine 2 katman concentric: dış soluk geniş, iç parlak çekirdek.
      _pFireflyGlow.color = Color.fromARGB((a * 0.20).round(), 0xC8, 0xFF, 0x9A);
      canvas.drawCircle(p, r * 2.6, _pFireflyGlow);
      _pFireflyGlow.color = Color.fromARGB((a * 0.40).round(), 0xC8, 0xFF, 0x9A);
      canvas.drawCircle(p, r * 1.6, _pFireflyGlow);
      _pFireflyCore.color = Color.fromARGB(a, 0xEC, 0xFF, 0xC0);
      canvas.drawCircle(p, r, _pFireflyCore);
    }
  }

  // ── Gündüz polen/toz zerreleri ──────────────────────────────────────────────
  // Güneşte parıldayan, havada yumuşakça süzülen soluk parçacıklar — ateş
  // böceklerinin gündüz karşılığı. Geceye doğru sönümlenir, yağmurda görünmez.
  void _drawPollen(Canvas canvas, Size size) {
    final strength = ((dayLight - 0.5) / 0.5).clamp(0.0, 1.0);
    if (strength <= 0.02 || rainIntensity > 0.2) return;
    // Zoom out'ta parçacıklar zaten görünmüyor — kısıt.
    final count = zoom < 0.4 ? 0 : (zoom < 0.7 ? 24 : 46);
    if (count == 0) return;
    for (int i = 0; i < count; i++) {
      final h  = i * 40503;
      final bc = (h % 1000) / 1000.0 * kCols;
      final br = (h ~/ 1000 % 1000) / 1000.0 * kRows;
      final gx = bc + sin(time * 0.35 + i * 1.1) * 1.6 + sin(time * 0.13 + i) * 0.9;
      final gy = br + cos(time * 0.30 + i * 1.7) * 1.1;
      final p  = _worldToScreen(gx, gy, size);
      if (p.dx < -10 || p.dx > size.width + 10 ||
          p.dy < -10 || p.dy > size.height + 10) {
        continue;
      }
      final tw = sin(time * 1.3 + i * 2.3) * 0.5 + 0.5;
      final a  = (strength * (0.35 + tw * 0.65) * 95).round().clamp(0, 110);
      if (a < 6) continue;
      final r = (0.8 + tw * 0.9) * zoom;
      _pPollen.color = Color.fromARGB(a, 0xFF, 0xF2, 0xC8);
      canvas.drawCircle(p, r, _pPollen);
    }
  }

  // ── Ambient kuş sürüleri ───────────────────────────────────────────────────
  // Sahnenin üstüne (son katman), ekran uzayında çizilir. Her kuş = küçük
  // koyu silüet; kanatlar sinüs ile çırpınır. Geceleri / şiddetli yağmurda
  // görünmez. Pure atmosfer — game state'i etkilemez.
  void _drawBirdFlocks(Canvas canvas, Size size) {
    if (birdFlocks.isEmpty) return;
    final dayFade = ((dayLight - 0.2) / 0.3).clamp(0.0, 1.0);
    final rainFade = (1.0 - (rainIntensity / 0.6)).clamp(0.0, 1.0);
    final visibility = dayFade * rainFade;
    if (visibility < 0.05) return;

    final wingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.6 * zoom;
    final bodyPaint = Paint();

    for (final flock in birdFlocks) {
      final fadeIn = (flock.age * 1.3).clamp(0.0, 1.0);
      final fa = (visibility * fadeIn * 200).round().clamp(0, 220);
      if (fa < 10) continue;
      for (final bird in flock.birds) {
        final (wx, wy) = flock.birdWorldPos(bird);
        final ground = _worldToScreen(wx, wy, size);
        final p = Offset(ground.dx, ground.dy - flock.altitude * zoom);

        if (p.dx < -30 || p.dx > size.width + 30 ||
            p.dy < -30 || p.dy > size.height + 30) {
          continue;
        }

        // Kanat çırpış — sin, ~4.5 Hz; her kuş kendi faz offset'iyle desync.
        final wing = sin(time * 9.0 + bird.wingPhaseOffset);
        final wingLen = 5.5 * zoom;
        // Wing tip Y: aşağı (positive) ↔ yukarı (negative) salınımı.
        final tipDy = wing * 2.2 * zoom;
        final leftTip  = Offset(p.dx - wingLen, p.dy + tipDy);
        final rightTip = Offset(p.dx + wingLen, p.dy + tipDy);

        wingPaint.color = Color.fromARGB(fa, 0x33, 0x2E, 0x28);
        canvas.drawLine(leftTip, p, wingPaint);
        canvas.drawLine(p, rightTip, wingPaint);
        bodyPaint.color = Color.fromARGB(fa, 0x22, 0x1E, 0x18);
        canvas.drawCircle(p, 1.4 * zoom, bodyPaint);
      }
    }
  }

  // ── Görünür dünya-koordinat sınırları (zoom'a göre) ───────────────────────
  //
  // canvas.scale(zoom) ekran merkezine uygulandığı için,
  // gridToScreen'in döndürdüğü dünya noktası (wx) ekranda görünür ↔
  //   center + (wx - center) * zoom  ∈  [0, size]
  // → wx  ∈  [center - center/zoom,  center + (size-center)/zoom]
  //
  // Hesaplanan aralık, kTileW/H kadarlık buffer ile döndürülür.
  (double, double, double, double) _visBounds(Size size) {
    final inv = 1.0 / zoom;
    final hw  = size.width  / 2;
    final hh  = size.height / 2;
    return (
      hw  * (1.0 - inv) - kTileW,        // minX
      hw  * (1.0 + inv) + kTileW,        // maxX
      hh  * (1.0 - inv) - kTileH * 2,   // minY
      hh  * (1.0 + inv) + kTileH * 2,   // maxY
    );
  }

  // ── Zemin ──────────────────────────────────────────────────────────────────
  // 1) Çim + kum + border = static layer → Picture cache (camera-bağımsız).
  // 2) Su tile'ları animasyonlu → her frame ayrı çizilir.

  void _drawGround(Canvas canvas, Size size) {
    if (_groundCache == null ||
        _gcVersion != groundVersion ||
        _gcWidth   != size.width ||
        _gcHeight  != size.height) {
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
        TileRenderer.drawGrassTile(c, px, py, hw, hh, col, row, zoom: 1.0);
        int sides = 0;
        if (waterTiles.contains((col,     row - 1))) sides++;
        if (waterTiles.contains((col + 1, row    ))) sides++;
        if (waterTiles.contains((col,     row + 1))) sides++;
        if (waterTiles.contains((col - 1, row    ))) sides++;
        if (sides > 0) {
          TileRenderer.drawSandOverlay(c, px, py, hw, hh, sides);
        }
      }
    }

    _groundCache?.dispose();
    _groundCache = recorder.endRecording();
    _gcVersion = groundVersion;
    _gcWidth   = size.width;
    _gcHeight  = size.height;
  }

  void _drawWaterTiles(Canvas canvas, Size size) {
    if (waterTiles.isEmpty) return;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    final tl = screenToGrid(Offset(minX, minY), size, camera);
    final tr = screenToGrid(Offset(maxX, minY), size, camera);
    final bl = screenToGrid(Offset(minX, maxY), size, camera);
    final br = screenToGrid(Offset(maxX, maxY), size, camera);
    final colMin = [tl.$1, tr.$1, bl.$1, br.$1]
        .reduce(min).floor().clamp(0, kCols - 1);
    final colMax = [tl.$1, tr.$1, bl.$1, br.$1]
        .reduce(max).ceil().clamp(0, kCols - 1);
    final rowMin = [tl.$2, tr.$2, bl.$2, br.$2]
        .reduce(min).floor().clamp(0, kRows - 1);
    final rowMax = [tl.$2, tr.$2, bl.$2, br.$2]
        .reduce(max).ceil().clamp(0, kRows - 1);
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    for (int row = rowMin; row <= rowMax; row++) {
      for (int col = colMin; col <= colMax; col++) {
        if (!waterTiles.contains((col, row))) continue;
        final s = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
        WaterRenderer.drawTile(canvas, s.dx.roundToDouble(), s.dy.roundToDouble(),
            hw, hh,
            time: time, seed: col * 17 + row * 31,
            dayLight: dayLight, rainIntensity: rainIntensity,
            zoom: zoom, skyTint: skyReflection);
      }
    }
  }

  // ── Su köpüğü (su kenarlarında) ────────────────────────────────────────────

  void _drawWaterFoam(Canvas canvas, Size size) {
    if (waterTiles.isEmpty) return;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    // _visBounds döngü DIŞINDA — her tile için yeniden hesaplamayı önler
    final (minX, maxX, minY, maxY) = _visBounds(size);
    for (final (col, row) in waterTiles) {
      final hasLandNeighbor =
          !waterTiles.contains((col,     row - 1)) ||
          !waterTiles.contains((col + 1, row    )) ||
          !waterTiles.contains((col,     row + 1)) ||
          !waterTiles.contains((col - 1, row    ));
      if (!hasLandNeighbor) continue;
      final s  = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      if (px < minX || px > maxX) continue;
      if (py < minY || py > maxY) continue;
      WaterRenderer.drawFoam(canvas, px, py, hw, hh, time,
          col * 17 + row * 31);
    }
  }

  void _drawMapBorder(Canvas canvas, Size size) {
    // dayLight'a bağlı (gece sis koyulaşır), Picture cache dışında çizilir.
    final p0 = gridToScreen(0,                0,                size, camera);
    final p1 = gridToScreen(kCols.toDouble(), 0,                size, camera);
    final p2 = gridToScreen(kCols.toDouble(), kRows.toDouble(), size, camera);
    final p3 = gridToScreen(0,                kRows.toDouble(), size, camera);
    _scratchPath
      ..reset()
      ..moveTo(p0.dx, p0.dy)
      ..lineTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..lineTo(p3.dx, p3.dy)
      ..close();
    // Önce yumuşak kıyı sisi (kenarı karanlığa eritir), sonra ince kara çizgisi.
    // 3 katman stroke (azalan alpha, artan kalınlık)  → blur'suz soft edge.
    // Berrak gecede sis %55'e kadar çekilir → ufuk görünür, sahne nefes alır.
    var mistA = (0x6E - (0x6E - 0x1E) * dayLight.clamp(0.0, 1.0)).round();
    mistA = (mistA * (1.0 - nightClarity * 0.55)).round();
    _pEdgeMistOuter.color = Color.fromARGB((mistA * 0.25).round(), 0x0A, 0x10, 0x18);
    _pEdgeMistMid.color   = Color.fromARGB((mistA * 0.55).round(), 0x0A, 0x10, 0x18);
    _pEdgeMistInner.color = Color.fromARGB(mistA, 0x0A, 0x10, 0x18);
    canvas.drawPath(_scratchPath, _pEdgeMistOuter);
    canvas.drawPath(_scratchPath, _pEdgeMistMid);
    canvas.drawPath(_scratchPath, _pEdgeMistInner);
    canvas.drawPath(_scratchPath, _pMapBorder);
  }

  // ── Tarla tile'ları ───────────────────────────────────────────────────────

  void _drawFarmTiles(Canvas canvas, Size size) {
    final hw = kTileW / 2;
    final hh = kTileH / 2;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    for (final t in farmTiles) {
      final s  = gridToScreen(t.col.toDouble(), t.row.toDouble(), size, camera);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      if (px < minX || px > maxX) continue;
      if (py < minY || py > maxY) continue;
      FarmRenderer.drawTile(canvas, px, py, hw, hh, t.stage, t.growthProgress);
    }
  }

  // ── Yollar ────────────────────────────────────────────────────────────────
  // Tamamlanmış yollar full opacity + autotile mask; bekleyen orderlar yarı
  // saydam (0.3..0.85 progress'e göre) preview olarak çizilir.
  // Çizim sırası: zemin (grass) sonrası, sahne (NPC/bina) öncesi.
  void _drawRoads(Canvas canvas, Size size) {
    if (roadSystem.count == 0 && pendingRoadOrders.isEmpty) return;
    final hw = kTileW / 2;
    final hh = kTileH / 2;

    // Tamamlanmış yollar — cached Picture (ground gibi camera-bağımsız).
    // Zoom karşılaştırması tolerance'lı: ScaleUpdate.scale floating-point
    // mikro değişim yapıyor (1.0 → 1.000001) → her pan frame'inde Picture
    // rebuild oluyordu. 0.05 tolerance ile zoom kademe görsel olarak fark
    // edilmeyen aralıkta rebuild'i atlar, pan kasması biter.
    if (roadSystem.count > 0) {
      final zoomChanged = (_rcZoom - zoom).abs() > 0.05;
      if (_roadsCache == null ||
          _rcVersion != roadSystem.version ||
          _rcWidth   != size.width ||
          _rcHeight  != size.height ||
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
      for (final o in pendingRoadOrders) {
        if (o.completed) continue;
        final s  = gridToScreen(o.col.toDouble(), o.row.toDouble(), size, camera);
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        if (px < minX || px > maxX) continue;
        if (py < minY || py > maxY) continue;
        // Stabil hash (col, row) — RoadTile.hash ile aynı formül
        final hash = (o.col * 73856093) ^ (o.row * 19349663);
        final opacity = 0.3 + 0.55 * o.progress;
        RoadRenderer.drawRoadTile(canvas, px, py, hw, hh,
            o.surface, 0, hash, zoom: zoom, opacity: opacity);
      }
    }
  }

  void _buildRoadsCache(Size size) {
    final recorder = ui.PictureRecorder();
    final c = Canvas(recorder);
    const cam0 = Offset.zero;
    const hw = kTileW / 2;
    const hh = kTileH / 2;
    for (final t in roadSystem.all) {
      final s  = gridToScreen(t.col.toDouble(), t.row.toDouble(), size, cam0);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      final mask = roadSystem.neighborMask(t.col, t.row);
      RoadRenderer.drawRoadTile(c, px, py, hw, hh,
          t.surface, mask, t.hash, zoom: zoom);
    }
    _roadsCache?.dispose();
    _roadsCache = recorder.endRecording();
    _rcVersion = roadSystem.version;
    _rcWidth   = size.width;
    _rcHeight  = size.height;
    _rcZoom    = zoom;
  }

  // ── Tarla seçim önizlemesi ────────────────────────────────────────────────

  void _drawFarmSelection(Canvas canvas, Size size) {
    final (c1, r1, c2, r2) = farmSelection!;
    final hw = kTileW / 2;
    final hh = kTileH / 2;
    final minC = c1 < c2 ? c1 : c2;
    final maxC = c1 < c2 ? c2 : c1;
    final minR = r1 < r2 ? r1 : r2;
    final maxR = r1 < r2 ? r2 : r1;

    for (int c = minC; c <= maxC; c++) {
      for (int r = minR; r <= maxR; r++) {
        final s  = gridToScreen(c.toDouble(), r.toDouble(), size, camera);
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        _scratchPath
          ..reset()
          ..moveTo(px,      py)
          ..lineTo(px + hw, py + hh)
          ..lineTo(px,      py + hh * 2)
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
    final hw = kTileW / 2;
    final hh = kTileH / 2;
    final minC = c1 < c2 ? c1 : c2;
    final maxC = c1 < c2 ? c2 : c1;
    final minR = r1 < r2 ? r1 : r2;
    final maxR = r1 < r2 ? r2 : r1;

    for (int c = minC; c <= maxC; c++) {
      for (int r = minR; r <= maxR; r++) {
        final s  = gridToScreen(c.toDouble(), r.toDouble(), size, camera);
        final px = s.dx.roundToDouble();
        final py = s.dy.roundToDouble();
        _scratchPath
          ..reset()
          ..moveTo(px,      py)
          ..lineTo(px + hw, py + hh)
          ..lineTo(px,      py + hh * 2)
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
      canvas.drawLine(Offset(center.dx - r, center.dy - r),
                      Offset(center.dx + r, center.dy + r), _pTreeX);
      canvas.drawLine(Offset(center.dx + r, center.dy - r),
                      Offset(center.dx - r, center.dy + r), _pTreeX);
    }
  }

  // ── Maden seçim önizlemesi ────────────────────────────────────────────────

  void _drawMineSelection(Canvas canvas, Size size) {
    final (c1, r1, c2, r2) = mineSelection!;
    final hw   = kTileW / 2;
    final hh   = kTileH / 2;
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
      canvas.drawLine(Offset(center.dx - r, cy - r), Offset(center.dx + r, cy + r), _pMineX);
      canvas.drawLine(Offset(center.dx + r, cy - r), Offset(center.dx - r, cy + r), _pMineX);
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
    final ox = (size.width  / 2 + camera.dx);
    final oy = (size.height * 0.28 + camera.dy);

    // (sx, sy) screen-space anchor. Sprite uzantısına göre genişletilmiş aralık.
    bool inView(double gx, double gy, double up, double side) {
      final sx = ox + (gx - gy) * kTileW / 2;
      final sy = oy + (gx + gy) * kTileH / 2;
      return sx >= minX - side && sx <= maxX + side &&
             sy >= minY - up   && sy <= maxY + kTileH;
    }

    // Culling sınırları sprite tipine göre kalibre edilmiş — gevşek tutmak
    // ekran kenarında scrolling sırasında popping önler, ama her +1 ekstra
    // entity drawable allocation × sort cost demek.
    const upChar  = 72.0;     // karakter ~64 + margin
    const upTall  = 180.0;    // ağaç sprite ~118 + margin (eski 256 cömert)
    // Decor margin: jitter ±26px + drawW/2 max ~20 = ±46. 48 güvenli sınır.
    // (32 dene ANCAK fallen_log + jitter köşede pop edebilir.)
    const upSmall = 32.0;     // decor/lotus/reed üst kenar
    const sideS   = 48.0;     // decor küçük sprite + jitter
    const sideM   = 48.0;     // karakter sprite yan kenar
    const sideL   = 160.0;    // bina + scaffold

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
    int cMinB = ((tlG.$1 < trG.$1 ? tlG.$1 : trG.$1) < (brG.$1 < blG.$1 ? brG.$1 : blG.$1)
        ? (tlG.$1 < trG.$1 ? tlG.$1 : trG.$1)
        : (brG.$1 < blG.$1 ? brG.$1 : blG.$1)).floor() >> kBucket;
    int cMaxB = ((tlG.$1 > trG.$1 ? tlG.$1 : trG.$1) > (brG.$1 > blG.$1 ? brG.$1 : blG.$1)
        ? (tlG.$1 > trG.$1 ? tlG.$1 : trG.$1)
        : (brG.$1 > blG.$1 ? brG.$1 : blG.$1)).ceil() >> kBucket;
    int rMinB = ((tlG.$2 < trG.$2 ? tlG.$2 : trG.$2) < (brG.$2 < blG.$2 ? brG.$2 : blG.$2)
        ? (tlG.$2 < trG.$2 ? tlG.$2 : trG.$2)
        : (brG.$2 < blG.$2 ? brG.$2 : blG.$2)).floor() >> kBucket;
    int rMaxB = ((tlG.$2 > trG.$2 ? tlG.$2 : trG.$2) > (brG.$2 > blG.$2 ? brG.$2 : blG.$2)
        ? (tlG.$2 > trG.$2 ? tlG.$2 : trG.$2)
        : (brG.$2 > blG.$2 ? brG.$2 : blG.$2)).ceil() >> kBucket;
    cMinB--; cMaxB++; rMinB--; rMaxB++;

    // Decor bucket build (if topology değişti).
    if (_decorBucketsLen != decor.length) {
      _decorBuckets.clear();
      for (final d in decor) {
        final key = (d.col >> kBucket, d.row >> kBucket);
        (_decorBuckets[key] ??= []).add(d);
      }
      _decorBucketsLen = decor.length;
    }
    for (int by = rMinB; by <= rMaxB; by++) {
      for (int bx = cMinB; bx <= cMaxB; bx++) {
        final list = _decorBuckets[(bx, by)];
        if (list == null) continue;
        for (final d in list) {
          if (inView(d.col + 0.5, d.row + 0.5, upSmall, sideS)) {
            _sceneBuffer.add(_DecorDrawable(d));
          }
        }
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
          if (inView(r.col + 0.5, r.row + 0.5, upSmall, sideS)) {
            _sceneBuffer.add(_ReedDrawable(r, time));
          }
        }
      }
    }
    for (final b in resourceBoxes) {
      if (b.isDelivered || b.isBeingCarried) continue;
      if (inView(b.gridX, b.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_ResourceBoxDrawable(b, time));
      }
    }
    for (final h in hayEntities) {
      if (h.isDelivered || h.isBeingCarried) continue;
      if (inView(h.gridX, h.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_HayDrawable(h, time));
      }
    }
    for (final e in villagers) {
      if (e.isInsideBuilding) continue;
      if (inView(e.renderX, e.renderY, upChar, sideM)) {
        _sceneBuffer.add(_VillagerDrawable(e, time, dayLight));
      }
    }
    for (final f in farmers) {
      if (inView(f.renderX, f.renderY, upChar, sideM)) {
        _sceneBuffer.add(_FarmerDrawable(f));
      }
    }
    for (final b in builders) {
      if (inView(b.renderX, b.renderY, upChar, sideM)) {
        _sceneBuffer.add(_BuilderDrawable(b));
      }
    }
    for (final w in woodcutters) {
      if (inView(w.renderX, w.renderY, upChar, sideM)) {
        _sceneBuffer.add(_WoodcutterDrawable(w));
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

    // Madenci ocağın içindeyse gizlenir — daha önce drawable hiç yaratılmazdı,
    // şimdi de viewport culling sonrası bina-içi kontrolü uygulanır.
    for (final m in miners) {
      if (m.isMining) {
        bool inside = false;
        for (final mr in _mineRects) {
          if (m.gridX >= mr.$1 - 0.5 && m.gridX < mr.$1 + mr.$3 + 0.5 &&
              m.gridY >= mr.$2 - 0.5 && m.gridY < mr.$2 + mr.$4 + 0.5) {
            inside = true; break;
          }
        }
        if (inside) continue;
      }
      if (inView(m.renderX, m.renderY, upChar, sideM)) {
        _sceneBuffer.add(_MinerDrawable(m));
      }
    }
    for (final f in fishers) {
      if (inView(f.renderX, f.renderY, upChar, sideM)) {
        _sceneBuffer.add(_FisherDrawable(f));
      }
    }
    for (final fl in florists) {
      if (inView(fl.renderX, fl.renderY, upChar, sideM)) {
        _sceneBuffer.add(_FloristDrawable(fl));
      }
    }
    for (final sh in shepherds) {
      if (inView(sh.renderX, sh.renderY, upChar, sideM)) {
        _sceneBuffer.add(_ShepherdDrawable(sh));
      }
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
          bool hidden = false;
          for (final mr in _mineRects) {
            if (n.col >= mr.$1 && n.col < mr.$1 + mr.$3 &&
                n.row >= mr.$2 && n.row < mr.$2 + mr.$4) {
              hidden = true; break;
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
        _sceneBuffer.add(_BuildingDrawable(
            b, time, dayLight, rainIntensity, isBurning, perfMode));
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
          if (inView(t.col + 0.5, t.row + 0.5, upTall, sideS)) {
            _sceneBuffer.add(_TreeDrawable(t, time));
          }
        }
      }
    }

    _sceneBuffer.sort((a, b) => a.depth.compareTo(b.depth));
    for (final d in _sceneBuffer) {
      d.draw(canvas, size, camera);
    }
  }

  // ── Hayalet bina ────────────────────────────────────────────────────────────

  void _drawGhost(Canvas canvas, Size size) {
    final (gc, gr) = ghostTile!;
    final meta = kBuildingMeta[ghostType!]!;
    final (back, left, right, front) = _corners(gc, gr, meta.cols, meta.rows, size, camera);

    final tileFill   = ghostValid ? const Color(0x4400FF00) : const Color(0x44FF0000);
    final tileBorder = ghostValid ? const Color(0xCC00CC00) : const Color(0xCCCC0000);

    _scratchPath
      ..reset()
      ..moveTo(back.dx,  back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx,  left.dy)
      ..close();
    _pGhostFill.color   = tileFill;
    _pGhostBorder.color = tileBorder;
    canvas.drawPath(_scratchPath, _pGhostFill);
    canvas.drawPath(_scratchPath, _pGhostBorder);

    // Etki alanı halkası — bina effectRadius > 0 ise zemine yumuşak
    // isometric oval olarak çizilir. Oyuncu placement sırasında menzili görür.
    if (meta.effectRadius > 0) {
      _drawEffectRing(canvas, gc, gr, meta, size);
    }

    canvas.saveLayer(null, Paint()..color = const Color(0xAAFFFFFF));
    BuildingRenderer.draw(canvas, ghostType!, back, left, right, front);
    canvas.restore();
  }

  /// Bina etki alanı görselleştirme — yumuşak isometric oval, ghost rengi ile.
  void _drawEffectRing(Canvas canvas, int gc, int gr, BuildingMeta meta, Size size) {
    final cx = gc + meta.cols * 0.5;
    final cy = gr + meta.rows * 0.5;
    final centerScreen = gridToScreen(cx, cy, size, camera);
    // İzometrik 2:1 — radius tile → ekran: x = r * kTileW, y = r * kTileH
    final rx = meta.effectRadius * kTileW;
    final ry = meta.effectRadius * kTileH;
    final rect = Rect.fromCenter(
      center: centerScreen,
      width:  rx * 2,
      height: ry * 2,
    );
    final ringColor = ghostValid ? const Color(0x66FFD27A) : const Color(0x66FF8888);
    canvas.drawOval(rect, Paint()
      ..color = ringColor.withAlpha(0x22)
      ..isAntiAlias = true);
    canvas.drawOval(rect, Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..isAntiAlias = true);
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

    // (0) Ambient color grade — gece/şafak/altın saatte sahneyi tonlar.
    // Modulate olduğu için strength=0'da beyaza lerp ederiz → identity.
    _drawAmbientGrade(canvas, size);

    // Gündüz fast path — overlay bantları şeffaf, sadece kompozisyon vignette.
    if (overlayTop.a == 0 && overlayBottom.a == 0 && darkness < 0.05) {
      _drawDayVignette(canvas, size);
      return;
    }

    // PerfMode fast path — tek vertical gradient overlay, ışık cutout / halo
    // saveLayer × 3 + 7-stop gradient × N tamamen atlanır. Gece basit dark
    // overlay olur, sokak feneri/ateş ışığı yok. Görsel atmosfer feda, FPS
    // büyük kazanç.
    if (perfMode) {
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
      final topA  = (moonF * 78).round().clamp(0, 90);
      final botA  = (moonF * 30).round().clamp(0, 50);
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
      canvas.saveLayer(rect, Paint()
        ..blendMode = BlendMode.dstOut
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6));
      for (final l in _lightBuffer) {
        // Viewport reject — ekran dışı ışıkların gradient + drawCircle pahalı.
        // Core radius * 1.5 (gradient buffer'ı için biraz fazla margin).
        final rCheck = l.radius * 1.5;
        if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
        if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
        final coreA = (l.intensity * 130).round().clamp(0, 140);
        final r = l.radius * 0.45;
        _pLightMask
          ..maskFilter = null
          ..shader = ui.Gradient.radial(
            Offset(l.sx, l.sy),
            r,
            [
              Color.fromARGB(coreA, 0xFF, 0xFF, 0xFF),
              Color.fromARGB((coreA * 0.92).round(), 0xFF, 0xFF, 0xFF),
              Color.fromARGB((coreA * 0.71).round(), 0xFF, 0xFF, 0xFF),
              Color.fromARGB((coreA * 0.30).round(), 0xFF, 0xFF, 0xFF),
              Color.fromARGB((coreA * 0.08).round(), 0xFF, 0xFF, 0xFF),
              Color.fromARGB((coreA * 0.02).round(), 0xFF, 0xFF, 0xFF),
              const Color(0x00FFFFFF),
            ],
            const [0.0, 0.15, 0.30, 0.50, 0.70, 0.85, 1.0],
          );
        canvas.drawCircle(Offset(l.sx, l.sy), r, _pLightMask);
        _pLightMask.shader = null;
      }
      canvas.restore();
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
      canvas.saveLayer(rect, Paint()
        ..blendMode = BlendMode.plus
        ..isAntiAlias = true
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8));
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
        _pWarmWash
          ..maskFilter = null
          ..shader = ui.Gradient.radial(
            Offset(l.sx, l.sy),
            r,
            [
              Color.fromARGB(innerA, wr, wg, wb),
              Color.fromARGB((innerA * 0.92).round(), wr, wg, wb),
              Color.fromARGB((innerA * 0.71).round(), wr, wg, wb),
              Color.fromARGB((innerA * 0.30).round(), wr, wg, wb),
              Color.fromARGB((innerA * 0.08).round(), wr, wg, wb),
              Color.fromARGB((innerA * 0.02).round(), wr, wg, wb),
              Color.fromARGB(0, wr, wg, wb),
            ],
            const [0.0, 0.15, 0.30, 0.50, 0.70, 0.85, 1.0],
          );
        canvas.drawCircle(Offset(l.sx, l.sy), r, _pWarmWash);
        _pWarmWash.shader = null;
      }
      canvas.restore();
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
      canvas.saveLayer(rect, Paint()
        ..blendMode = BlendMode.plus
        ..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18));
      for (final l in _lightBuffer) {
        // Viewport reject (outer halo pass) — radius 2.5× drawing
        final rCheck = l.radius * 2.5;
        if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
        if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
        final haloAlpha =
            (l.intensity * darkness * 28).round().clamp(0, 35);
        if (haloAlpha < 3) continue;
        final wr = (l.warm.r * 255).round();
        final wg = (l.warm.g * 255).round();
        final wb = (l.warm.b * 255).round();
        _pWarmHalo
          ..maskFilter = null
          ..shader = ui.Gradient.radial(
            Offset(l.sx, l.sy),
            l.radius * 1.7,
            [
              Color.fromARGB(haloAlpha, wr, wg, wb),
              Color.fromARGB((haloAlpha * 0.92).round(), wr, wg, wb),
              Color.fromARGB((haloAlpha * 0.71).round(), wr, wg, wb),
              Color.fromARGB((haloAlpha * 0.30).round(), wr, wg, wb),
              Color.fromARGB((haloAlpha * 0.08).round(), wr, wg, wb),
              Color.fromARGB((haloAlpha * 0.02).round(), wr, wg, wb),
              Color.fromARGB(0, wr, wg, wb),
            ],
            const [0.0, 0.15, 0.30, 0.50, 0.70, 0.85, 1.0],
          );
        canvas.drawCircle(
            Offset(l.sx, l.sy), l.radius * 1.7, _pWarmHalo);
        _pWarmHalo.shader = null;
      }
      canvas.restore();
    }
  }

  /// Tüm binaların gölgesini tek pass'te çizer (sahne sprite'larından önce).
  /// Her bina için light vector aggregation ile yumuşak yön + drop-shadow.
  void _drawBuildingShadows(Canvas canvas, Size size) {
    if (buildings.isEmpty) return;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    final ox = size.width  / 2 + camera.dx;
    final oy = size.height * 0.28 + camera.dy;
    bool inView(double gx, double gy) {
      final sx = ox + (gx - gy) * kTileW / 2;
      final sy = oy + (gx + gy) * kTileH / 2;
      return sx >= minX - 160 && sx <= maxX + 160 &&
             sy >= minY - 256 && sy <= maxY + kTileH;
    }
    final shadowBoost = (1.0 - dayLight).clamp(0.0, 1.0);
    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      if (!inView(cx, cy)) continue;
      final corners = _corners(b.col, b.row, b.cols, b.rows, size, camera);
      final lightScr = _aggregateLightForBuilding(b, cx, cy, size);
      _drawBuildingShadow(canvas, corners.$1, corners.$2, corners.$3, corners.$4,
          lightScreen: lightScr, shadowBoost: shadowBoost);
    }
  }

  // Bina gölge yönü için ışık AGREGASYONU.
  //
  // En yakın tek ışığı seçmek yerine, etki alanındaki tüm güçlü ışıkların
  // vector-sum'ı alınır (ağırlık = intensity × inverse-square distance).
  // İki lamba eşit uzaklıkta ise gölge ortada birleşir; bir lamba söndüğünde
  // yön zıplamadan kayar. "Sanal light" pozisyonu = bina'dan ortalama yöne
  // 5 tile geri — `_drawBuildingShadow` lightScreen olarak bunu kullanır.
  Offset? _aggregateLightForBuilding(BuildingEntity b,
      double bcx, double bcy, Size size) {
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
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
        _pAmbientGrade);
  }

  // Gündüz hafif vignette — kompozisyon kontrastı.
  void _drawDayVignette(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    _pLighting.shader = ui.Gradient.radial(
      Offset(size.width / 2, size.height / 2),
      max(size.width, size.height) * 0.78,
      [const Color(0x00000000), const Color(0x18050810)],
    );
    canvas.drawRect(rect, _pLighting);
    _pLighting.shader = null;
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
      final flicker = 1.0
          + sin(time * 3.7 + phase) * 0.04
          + sin(time * 8.3 + phase * 1.7) * 0.02;
      final rScreen = l.radius * kPixelsPerTile * zoom;
      final dynIntensity = (l.intensity * flicker).clamp(0.0, 1.0);
      _lightBuffer.add(_LightInfo(p.dx, p.dy, rScreen, l.warm, dynIntensity));
    }
  }

  // ── Olay overlay'i (tint + partiküller) ─────────────────────────────────
  //
  // Aggregate tint, lighting pass üstüne yumuşak alpha çekilir. Sonra her
  // aktif EventFx için özelleştirilmiş partikül/animasyon pass'i.
  static final _pEventOverlay = Paint()..isAntiAlias = false;
  static final _pFxParticle   = Paint()..isAntiAlias = true;

  void _drawEventOverlay(Canvas canvas, Size size) {
    // Ekran tonu — gece overlay ve lighting üstüne hafif renk filmi.
    if (eventTint.a > 0) {
      _pEventOverlay.color = eventTint;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height),
          _pEventOverlay);
    }
    if (activeFx.isEmpty) return;
    // Sahnenin yapısına bağlı partikül pass'leri.
    if (activeFx.contains(EventFx.celebration)) _fxCelebration(canvas, size);
    if (activeFx.contains(EventFx.harvestSparkle)) _fxHarvestSparkle(canvas, size);
    if (activeFx.contains(EventFx.plagueAura)) _fxPlagueAura(canvas, size);
    // fireOutbreak artık sahne overlay'inde değil — gerçek bina drawable'da
    // sprite üstüne alev + duman çiziyor (_BuildingDrawable._drawBurningOverlay).
    if (activeFx.contains(EventFx.miracleLight)) _fxMiracleLight(canvas, size);
    if (activeFx.contains(EventFx.treasureGlow)) _fxTreasureGlow(canvas, size);
    if (activeFx.contains(EventFx.beastEyes)) _fxBeastEyes(canvas, size);
    if (activeFx.contains(EventFx.thiefDash)) _fxThiefDash(canvas, size);
    if (activeFx.contains(EventFx.visitorArrived)) _fxVisitorArrived(canvas, size);
  }

  // Şenlik — ateş yerinin etrafında yükselen kalp/nota partikülleri.
  void _fxCelebration(Canvas canvas, Size size) {
    // Tüm firepit'ler etrafında.
    for (final b in buildings) {
      if (b.type != BuildingType.firepit) continue;
      final base = _worldToScreen(b.col + 0.5, b.row + 0.5, size);
      for (int i = 0; i < 8; i++) {
        final phase = (time * 0.55 + i * 0.31 + b.col * 0.17) % 1.0;
        final ang   = (i * 0.785) + phase * 0.6;
        final dx    = sin(ang) * 26 * zoom;
        final dy    = -phase * 60 * zoom - 4;
        final pos   = base + Offset(dx, dy);
        final a     = ((1 - phase) * 230).round().clamp(0, 230);
        final symbolPick = (i + b.col + b.row) & 1;
        // Kalp şekli yerine basit pixel rosette
        _pFxParticle.color = symbolPick == 0
            ? Color.fromARGB(a, 0xFF, 0x70, 0x90)   // pembe kalp
            : Color.fromARGB(a, 0xFF, 0xE0, 0x60);  // sarı yıldız
        canvas.drawCircle(pos, 2.5 * zoom, _pFxParticle);
        _pFxParticle.color = Color.fromARGB((a * 0.5).round(), 0xFF, 0xFF, 0xFF);
        canvas.drawCircle(pos, 1.2 * zoom, _pFxParticle);
      }
    }
  }

  // Hasat — tarlaların üstünde altın yıldız parıltıları.
  void _fxHarvestSparkle(Canvas canvas, Size size) {
    final n = (farmTiles.length).clamp(0, 32);
    for (int i = 0; i < n; i++) {
      final t = farmTiles[i];
      final base = _worldToScreen(t.col + 0.5, t.row + 0.5, size);
      final phase = (time * 1.3 + i * 0.41) % 1.0;
      if (phase > 0.55) continue;
      final a = ((1 - phase / 0.55) * 220).round().clamp(0, 220);
      final r = 1.5 + (1 - phase / 0.55) * 1.8;
      _pFxParticle.color = Color.fromARGB(a, 0xFF, 0xE8, 0x6A);
      canvas.drawCircle(base + Offset(0, -2 * zoom), r * zoom, _pFxParticle);
    }
    // Yedek: balıkçı kulübeleri varsa onların üstünde de
    for (final b in buildings) {
      if (b.type != BuildingType.fisherCabin) continue;
      final p = _worldToScreen(b.col + 1, b.row + 1, size);
      final phase = (time * 1.1 + b.col * 0.3) % 1.0;
      if (phase > 0.5) continue;
      final a = ((1 - phase / 0.5) * 200).round().clamp(0, 200);
      _pFxParticle.color = Color.fromARGB(a, 0xFF, 0xE8, 0x6A);
      canvas.drawCircle(p, 2.0 * zoom, _pFxParticle);
    }
  }

  // Salgın — NPC'lerin üstünde küçük yeşil bulut partikülü.
  void _fxPlagueAura(Canvas canvas, Size size) {
    for (final v in villagers) {
      if (v.isInsideBuilding) continue;
      final p = _worldToScreen(v.renderX, v.renderY, size);
      final phase = (time * 0.8 + v.gridX * 0.31 + v.gridY * 0.17) % 1.0;
      final yOff = -16 - phase * 12;
      final a = ((1 - phase) * 180).round().clamp(0, 180);
      _pFxParticle.color = Color.fromARGB(a, 0x88, 0xC0, 0x60);
      canvas.drawCircle(p + Offset(0, yOff * zoom), 2.5 * zoom, _pFxParticle);
    }
  }

  // Mucize — ekranın üstünden köy meydanına inen ışın hüzmesi.
  void _fxMiracleLight(Canvas canvas, Size size) {
    // Firepit varsa orada, yoksa ekran merkezi
    Offset target = Offset(size.width / 2, size.height / 2);
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        target = _worldToScreen(b.col + 0.5, b.row + 0.5, size);
        break;
      }
    }
    final pulse = (sin(time * 1.5) * 0.5 + 0.5);
    final beamA = (60 + pulse * 50).round();
    _pFxParticle.shader = ui.Gradient.linear(
      Offset(target.dx, 0),
      Offset(target.dx, target.dy),
      [
        Color.fromARGB(0, 0xFF, 0xF8, 0xC0),
        Color.fromARGB(beamA, 0xFF, 0xF8, 0xC0),
      ],
    );
    _pFxParticle.blendMode = BlendMode.plus;
    canvas.drawRect(
      Rect.fromLTWH(target.dx - 24, 0, 48, target.dy),
      _pFxParticle,
    );
    _pFxParticle.shader = null;
    _pFxParticle.blendMode = BlendMode.srcOver;
  }

  // Hazine — köy merkezinde altın parıltı çemberi.
  void _fxTreasureGlow(Canvas canvas, Size size) {
    Offset target = Offset(size.width / 2, size.height / 2);
    for (final b in buildings) {
      if (b.type == BuildingType.townhall || b.type == BuildingType.firepit) {
        target = _worldToScreen(b.col + b.cols / 2.0, b.row + b.rows / 2.0, size);
        if (b.type == BuildingType.townhall) break;
      }
    }
    final pulse = (sin(time * 2.0) * 0.5 + 0.5);
    final r = (40 + pulse * 14) * zoom;
    final a = (60 + pulse * 80).round();
    _pFxParticle.color = Color.fromARGB(a, 0xFF, 0xD8, 0x40);
    _pFxParticle.blendMode = BlendMode.plus;
    canvas.drawCircle(target, r, _pFxParticle);
    _pFxParticle.blendMode = BlendMode.srcOver;
    // Etrafa fırlayan parlak noktalar
    for (int i = 0; i < 10; i++) {
      final ang = (i * 0.628 + time * 0.5);
      final d   = (8 + ((i + time * 2).floor() % 5) * 6.0) * zoom;
      final pos = target + Offset(cos(ang) * d, sin(ang) * d * 0.5);
      _pFxParticle.color = Color.fromARGB(200, 0xFF, 0xF0, 0x80);
      canvas.drawCircle(pos, 1.6 * zoom, _pFxParticle);
    }
  }

  // Hayvan baskını — gece firepit etrafında ağaç hattında kırmızı göz çiftleri.
  void _fxBeastEyes(Canvas canvas, Size size) {
    if (dayLight > 0.4) return;
    for (int i = 0; i < 4; i++) {
      // Stabil pozisyonlar — time/3 ile yavaşça kayar (kurtlar dolaşıyor).
      final seed = i * 41 + (time / 4).floor();
      final ang  = (seed * 1.234) % (2 * pi);
      final dist = 12.0 + (seed % 4) * 2.0;
      final gx   = kCols / 2 + cos(ang) * dist;
      final gy   = kRows / 2 + sin(ang) * dist;
      final p    = _worldToScreen(gx, gy, size);
      final blink = (sin(time * 3 + i) > 0.7) ? 0 : 1;
      if (blink == 0) continue;
      _pFxParticle.color = const Color(0xCCFF3020);
      canvas.drawCircle(p + Offset(-3 * zoom, 0), 1.6 * zoom, _pFxParticle);
      canvas.drawCircle(p + Offset(3 * zoom, 0), 1.6 * zoom, _pFxParticle);
    }
  }

  // Hırsız — ekran sağından sola koşan koyu silüet (kısa süre).
  void _fxThiefDash(Canvas canvas, Size size) {
    // 8 sn boyunca tek geçiş — time mod 8 (efekt duration ile uyumlu).
    final t = (time % 8) / 8;
    final x = size.width * (1.0 - t * 1.2) + 100;
    final y = size.height * 0.55 + sin(time * 8) * 4;
    _pFxParticle.color = const Color(0xDD181018);
    // Gövde
    canvas.drawRect(Rect.fromLTWH(x, y, 8 * zoom, 14 * zoom), _pFxParticle);
    // Kafa
    canvas.drawRect(
        Rect.fromLTWH(x + 1, y - 6 * zoom, 6 * zoom, 6 * zoom), _pFxParticle);
    // Altın torba
    _pFxParticle.color = const Color(0xCCC09020);
    canvas.drawRect(
        Rect.fromLTWH(x + 6 * zoom, y + 4 * zoom, 5 * zoom, 5 * zoom),
        _pFxParticle);
  }

  // Ziyaretçi — köy meydanına doğru yürüyen küçük silüet (lobby).
  void _fxVisitorArrived(Canvas canvas, Size size) {
    // 3 saniye boyunca sahnede tek "yolda" silüet
    final phase = (time % 20) / 20;
    if (phase > 0.6) return;
    // Pozisyon: ekranın solundan giriyor, meydana doğru
    Offset target = Offset(size.width / 2, size.height / 2);
    for (final b in buildings) {
      if (b.type == BuildingType.market || b.type == BuildingType.firepit) {
        target = _worldToScreen(b.col + b.cols / 2.0, b.row + b.rows / 2.0, size);
        if (b.type == BuildingType.market) break;
      }
    }
    final start = Offset(40, size.height * 0.45);
    final t2 = (phase / 0.6).clamp(0.0, 1.0);
    final pos = Offset.lerp(start, target, t2)!;
    final bob = sin(time * 5) * 1.5;
    _pFxParticle.color = const Color(0xDD3A2818);
    canvas.drawRect(
        Rect.fromLTWH(pos.dx, pos.dy + bob, 6 * zoom, 12 * zoom),
        _pFxParticle);
    _pFxParticle.color = const Color(0xFFD8A878);
    canvas.drawRect(
        Rect.fromLTWH(pos.dx, pos.dy - 5 * zoom + bob, 6 * zoom, 5 * zoom),
        _pFxParticle);
  }

  // ── Yağmur ────────────────────────────────────────────────────────────────
  // 3 parallax katman + ön katmanda motion-trail + sahnede dağıtık ground
  // splash + yoğun yağmurda hafif blue-grey atmosfer perdesi.
  //
  // Tasarım kararları:
  //  • Katmanlar: uzak (kısa/soluk/yavaş), orta (normal), ön (uzun/parlak/hızlı
  //    + soluk tail). Her katman kendi X/Y hash'i (örtüşmesin) ve scroll
  //    hızıyla → derinlik hissi.
  //  • Wind sway: tek global sin() — tüm katmanlara aynı oranda uygulanır
  //    ki yağmur "bir bütün" hissetsin, salınımlar farklı yöne gitmesin.
  //  • Ground splash: ekran uzayında sabit slot'lar, her slot kendi faz +
  //    periyoduyla tek-shot animasyon (crown + 2 droplet + iso ring). Yer
  //    sınırı yok (bazıları su tile üstüne düşer ama orada renderer'ın halkası
  //    zaten var, çakışma fark edilmez).

  void _drawRain(Canvas canvas, Size size) {
    if (rainIntensity <= 0) return;
    final intensity = rainIntensity.clamp(0.0, 1.0);

    // Wind salınımı — yavaş sin(), tüm katmanlara aynı oran. Damla uzunluğu
    // ile çarpılarak slant (x kayması) verir.
    final wind = sin(time * 0.35) * 0.10 + 0.06; // -0.04..0.16 (eğim oranı)

    // Arka katman — kısa, soluk, yavaş; çok damla → sürekli "perde" hissi
    _drawRainLayer(canvas, size,
        count: 130, speed: 0.34, length: 8.0,
        slant: wind * 8.0,
        r: 130, g: 165, b: 200, alpha: 0.22 * intensity,
        seed: 1731, bold: false);
    // Orta katman — yoğunluk asıl katman
    _drawRainLayer(canvas, size,
        count: 180, speed: 0.52, length: 14.0,
        slant: wind * 14.0,
        r: 190, g: 220, b: 245, alpha: 0.38 * intensity,
        seed: 4221, bold: false);
    // Ön katman — uzun, parlak + soluk arka iz; sayısı az tutulur ki
    // bireysel damlalar okunsun, perde değil hareket hissi versin.
    _drawRainLayer(canvas, size,
        count: 55, speed: 0.78, length: 22.0,
        slant: wind * 22.0,
        r: 225, g: 242, b: 255, alpha: 0.50 * intensity,
        seed: 8917, bold: true, withTail: true);

    // Yere çarpma — sahnede dağıtık periyodik splash slot'ları.
    _drawGroundSplashes(canvas, size, intensity);

    // Yoğun yağmurda hafif mavi-gri perde (atmosfer derinliği).
    if (intensity > 0.5) {
      final tintA = ((intensity - 0.5) * 0.30).clamp(0.0, 0.14);
      _pRainMist.color = Color.fromRGBO(150, 175, 200, tintA);
      canvas.drawRect(Offset.zero & size, _pRainMist);
    }
  }

  void _drawRainLayer(Canvas canvas, Size size, {
    required int count,
    required double speed,
    required double length,
    required double slant,
    required int r, required int g, required int b,
    required double alpha,
    required int seed,
    required bool bold,
    bool withTail = false,
  }) {
    final visible = (count * rainIntensity).round();
    if (visible == 0 || alpha < 0.01) return;

    final paint = bold ? _pRainBold : _pRain;
    paint.color = Color.fromRGBO(r, g, b, alpha.clamp(0.0, 1.0));

    // Y aralığı ekran dışına biraz uzar → kenarlarda damla "pop" etmez.
    final yRange = size.height + length * 2;

    for (int i = 0; i < visible; i++) {
      // Asal mod'lar → katmanlar arası örtüşmesiz dağıtım.
      final x = ((i * 1733 + seed + 97) % 997) / 997.0 * size.width;
      final yPhase = ((i * 619 + seed + 53) % 991) / 991.0;
      final y = ((yPhase + time * speed) % 1.0) * yRange - length;

      canvas.drawLine(
        Offset(x,         y),
        Offset(x + slant, y + length),
        paint,
      );

      if (withTail) {
        // Motion trail — damlanın arkasında yarım boy, ~%35 alpha çizgi.
        // Hızı görsel olarak çoğaltır; "damla şu an yağıyor" hissi verir.
        _pRainTail.color = Color.fromRGBO(r, g, b,
            (alpha * 0.38).clamp(0.0, 1.0));
        canvas.drawLine(
          Offset(x - slant * 0.55, y - length * 0.55),
          Offset(x,                y),
          _pRainTail,
        );
      }
    }
  }

  void _drawGroundSplashes(Canvas canvas, Size size, double intensity) {
    // Sahne genelinde sabit slot pozisyonları + her slot kendi faz/periyod.
    // count yoğunluğa lineer ölçek — zayıf yağmurda az splash, kuvvetlide çok.
    final count = (55 * intensity).round();
    if (count == 0) return;

    for (int i = 0; i < count; i++) {
      final px = ((i * 7919 + 137) % 997) / 997.0 * size.width;
      final py = ((i * 5717 + 281) % 991) / 991.0 * size.height;
      // Her slot 1.4–2.0 sn'de bir splash (period kişiye özel).
      final period = 1.4 + ((i * 41) % 100) / 100.0 * 0.6;
      final phaseOff = ((i * 3413 + 89) % 983) / 983.0 * period;
      final cycT = ((time + phaseOff) % period) / period;
      // İlk %22'lik dilim splash visible — uzun ömür ⇒ frame'ler arasında
      // damla sürekli hareket halindeymiş gibi okunur (pop yerine akış).
      if (cycT > 0.22) continue;
      final life = cycT / 0.22; // 0..1 splash içinde
      final invLife = 1.0 - life;
      // Görsel zarflama — ortada parlak, başta/sonda yumuşak yok ol.
      final envelope = (life < 0.18)
          ? life / 0.18                       // ease-in (pop yumuşatılır)
          : invLife * invLife;                // ease-out

      // Crown — kısa AA çizgi (yuvarlak cap), aniden patlamaz.
      if (life < 0.5) {
        final crownH = 3.2 * (1.0 - life * 1.8).clamp(0.0, 1.0);
        final cA = (envelope * 220 * intensity).toInt().clamp(0, 220);
        if (cA > 5 && crownH > 0.4) {
          _pSplash.color = Color.fromARGB(cA, 220, 240, 255);
          canvas.drawLine(
            Offset(px, py + 0.3),
            Offset(px, py - crownH),
            _pSplash..strokeWidth = 1.1..strokeCap = StrokeCap.round,
          );
          // _pSplash'ı sonraki droplet fill'i için fill moda döndür
          // (drawLine PaintingStyle değiştirmez ama strokeWidth state kalır).
        }
      }

      // 2 sıçrayan damlacık — yana uçar, hafif yukarı sonra düşer (arc).
      // AA daireler, rectangle yerine — kenar yumuşak, sub-pixel akar.
      final fly = life * 4.8;
      final arcY = -1.6 + life * 2.6;
      final dA = (envelope * 200 * intensity).toInt().clamp(0, 200);
      if (dA > 5) {
        _pSplash.color = Color.fromARGB(dA, 215, 235, 252);
        canvas.drawCircle(Offset(px - fly, py + arcY), 0.85, _pSplash);
        canvas.drawCircle(Offset(px + fly, py + arcY), 0.85, _pSplash);
      }

      // Genişleyen iso oval ring (2:1 squash — yer hissi).
      // Ring life boyu yaşar (en uzun ömürlü katman), envelope yerine
      // smooth invLife² → smooth fade.
      final ringW = 1.0 + life * 8.0;
      final ringH = ringW * 0.42;
      final rA = (invLife * invLife * 160 * intensity).toInt().clamp(0, 160);
      if (rA > 4) {
        _pSplashRing.color = Color.fromARGB(rA, 200, 225, 245);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(px, py + 1), width: ringW, height: ringH),
          _pSplashRing,
        );
      }
    }
  }

  @override
  bool shouldRepaint(VillageGamePainter old) =>
      old.camera          != camera          ||
      old.time            != time            ||
      old.ghostTile       != ghostTile       ||
      old.ghostType       != ghostType       ||
      old.ghostValid      != ghostValid      ||
      old.overlayTop      != overlayTop      ||
      old.overlayBottom   != overlayBottom   ||
      old.rainIntensity   != rainIntensity   ||
      old.nightClarity    != nightClarity    ||
      old.farmTiles       != farmTiles       ||
      old.farmers         != farmers         ||
      old.farmSelection   != farmSelection   ||
      old.lumberSelection != lumberSelection ||
      old.villagers       != villagers       ||
      old.buildings       != buildings       ||
      old.builders        != builders        ||
      old.pendingOrders   != pendingOrders   ||
      old.roadSystem      != roadSystem      ||
      old.pendingRoadOrders != pendingRoadOrders ||
      old.trees           != trees           ||
      old.woodcutters     != woodcutters     ||
      old.mineNodes       != mineNodes       ||
      old.miners          != miners          ||
      old.mineSelection   != mineSelection   ||
      old.waterTiles      != waterTiles      ||
      old.dayLight        != dayLight        ||
      old.lotuses         != lotuses         ||
      old.reeds           != reeds           ||
      old.decor           != decor           ||
      old.fishers         != fishers         ||
      old.florists        != florists        ||
      old.shepherds       != shepherds       ||
      old.cows            != cows            ||
      old.zoom            != zoom            ||
      old.resourceBoxes   != resourceBoxes   ||
      old.hayEntities     != hayEntities     ||
      old.groundVersion   != groundVersion   ||
      old.lightSources    != lightSources    ||
      old.ambientTint     != ambientTint     ||
      old.ambientStrength != ambientStrength ||
      old.eventTint       != eventTint       ||
      old.activeFx        != activeFx        ||
      old.burningBuildings != burningBuildings;
}
