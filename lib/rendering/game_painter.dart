import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'character_renderer.dart';
import '../entities/villager_entity.dart';
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
import 'nature_renderer.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../systems/lighting_system.dart';
import '../systems/event_system.dart';
import 'flame_renderer.dart';
import 'water_shimmer_renderer.dart';
import 'particle_renderer.dart';
import 'smoke_renderer.dart';
import '../farm/farm_tile.dart';
import '../entities/farm_farmer.dart';
import '../farm/farm_renderer.dart';
import '../entities/fisher_entity.dart';
import '../entities/shepherd_entity.dart';
import '../world/animal_entity.dart';
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
// Üst üste binen ışıklar toplanmaz, MAX alpha kalır → "parlak patlama" yok.
final _pLightMask  = Paint()..blendMode = BlendMode.lighten..isAntiAlias = true;
// Sıcak halo paint — saveLayer içinde lighten ile birleştirilir, dış
// saveLayer plus blend ile sahneye uygulanır → halo da overlap'te max kalır.
final _pWarmHalo   = Paint()..blendMode = BlendMode.lighten..isAntiAlias = true;

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

// Rain — alpha her frame değişir, paint havuzlu.
final _pRain = Paint()
  ..strokeWidth = 1.0
  ..isAntiAlias = false;

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

// Maden binası dikdörtgenleri (col, row, cols, rows) — miner/mineNode gizleme
// kontrolü için frame başına bir kez doldurulur; her entity tüm binaları (ve
// kBuildingMeta lookup'ını) taramasın diye scratch.
final List<(int, int, int, int)> _mineRects = [];

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

    // Draw torch glow BEFORE character (lower layer)
    final isWalkingAtNight = e.isWalking && dayLight < 0.4;
    if (isWalkingAtNight) {
      final seed = e.gridX.toInt() * 13 + e.gridY.toInt() * 7;
      ToolRenderer.drawTorchGlow(canvas, s.dx, s.dy, time, seed);
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
    canvas.save();
    canvas.translate(s.dx, s.dy - danceBounce);
    if (danceSway != 0) canvas.rotate(danceSway);
    canvas.scale(charScale, charScale);
    CharacterRenderer.draw(canvas, e.type,
        flipX:         !e.facingRight,
        walkPhase:     e.walkPhase,
        moveIntensity: e.moveIntensity,
        carrying:      e.isCarrying && e.carriedItem != null,
        torch:         isWalkingAtNight,
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
    // Sohbet baloncuğu — sadece chat aktivitesinde (müzik/dans artık görsel
    // ipucuna sahip → baloncuk artıklığı yok).
    if (e.activity == VillagerActivity.chat &&
        e.chatBubbleTime > 0 && e.chatBubbleIcon.isNotEmpty) {
      _drawChatBubble(canvas, Offset(s.dx, s.dy - danceBounce),
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
    // 4 sn total varsayımıyla. timeLeft 0..5 arasında.
    double a;
    if (timeLeft > 4.6) {
      // Fade in: 5.0 → 4.6
      a = (5.0 - timeLeft) / 0.4;
    } else if (timeLeft < 0.6) {
      // Fade out
      a = timeLeft / 0.6;
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
    final working = b.state == BuilderState.building;
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawBuilder(canvas,
        flipX:         !b.facingRight,
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
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawFarmer(canvas,
        flipX:         !f.facingRight,
        walkPhase:     f.walkPhase,
        moveIntensity: f.moveIntensity,
        harvesting:    f.state == FarmerState.harvesting,
        harvestPhase:  f.harvestPhase,
        carryingWater: f.isHandlingWater);
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
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawMiner(canvas,
        flipX:         !m.facingRight,
        walkPhase:     m.walkPhase,
        moveIntensity: m.moveIntensity,
        mining:        m.isMining,
        chopPhase:     m.chopPhase);
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
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawWoodcutter(canvas,
        flipX:         !w.facingRight,
        walkPhase:     w.walkPhase,
        moveIntensity: w.moveIntensity,
        chopping:      w.isChopping,
        chopPhase:     w.chopPhase);
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
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawFisher(canvas,
        flipX:         !f.facingRight,
        walkPhase:     f.walkPhase,
        moveIntensity: f.moveIntensity,
        fishing:       f.isFishing,
        fishPhase:     f.fishPhase);
    canvas.restore();
    _maybeSplash(canvas, s.dx, s.dy);
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
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawShepherd(canvas,
        flipX:         !sh.facingRight,
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
    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.drawCow(canvas,
        flipX:        !a.facingRight,
        walkPhase:    a.walkPhase,
        isWalking:    a.isWalking,
        beingMilked:  a.isBeingMilked);
    canvas.restore();
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
  _BuildingDrawable(this.b, this.time, this.dayLight, this.rainIntensity,
      this.burning);
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
          isActive: b.isActive);
      canvas.restore();
    } else {
      BuildingRenderer.draw(canvas, b.type, corners.$1, corners.$2, corners.$3, corners.$4,
          time: time, seed: b.col * 17 + b.row * 31,
          dayLight: dayLight, rainIntensity: rainIntensity,
          isActive: b.isActive);
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
  final List<FisherEntity> fishers;
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
    this.fishers       = const [],
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
  });

  @override
  void paint(Canvas canvas, Size size) {
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
    _drawWaterShimmer(canvas, size);
    // Bina gölgeleri — sahne sprite'larından ÖNCE, zemin üstüne. Bu sayede
    // hiçbir bina gölgesi başka sprite'ın üstüne taşıyamaz.
    _drawBuildingShadows(canvas, size);
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
    _drawFireflies(canvas, size);
    _drawPollen(canvas, size);
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

  /// Su yüzeyi parıltısı — her görünür su tile'ında 5 sn cycle'da 1 sn
  /// shimmer canlı olur. Cycle phase deterministik (col*7 + row*13 hash) →
  /// tiles asenkron parıldar, doğal dağılım. Aynı anda ~%20 tile aktif.
  /// Foam'dan sonra, bina gölgesinden önce → suyun üstünde ama sahnenin
  /// altında kalır.
  void _drawWaterShimmer(Canvas canvas, Size size) {
    if (waterTiles.isEmpty) return;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    const cyclePeriod = 5.0;     // her tile 5 sn döngüde
    const activeWindow = 1.0;     // 1 sn boyunca shimmer görünür
    for (final (col, row) in waterTiles) {
      final s  = gridToScreen(col + 0.5, row + 0.5, size, camera);
      if (s.dx < minX - 32 || s.dx > maxX + 32) continue;
      if (s.dy < minY - 32 || s.dy > maxY + 32) continue;

      final seed = col * 7 + row * 13;
      final localT = (time + seed * 0.31) % cyclePeriod;
      if (localT > activeWindow) continue;

      // Tile içinde küçük deterministik offset — shimmer hep tam ortada
      // durmasın, kenara/içe rastgele dağılsın.
      final ox = ((seed * 17) % 23 - 11) / 11.0 * 8.0; // -8..8 px
      final oy = ((seed * 41) % 19 - 9)  / 9.0  * 4.0; // -4..4 px

      WaterShimmerRenderer.draw(canvas,
          s.dx + ox, s.dy + oy,
          0.55, localT, seed);
    }
  }

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
    final mistA = (0x6E - (0x6E - 0x1E) * dayLight.clamp(0.0, 1.0)).round();
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
    final (minX, maxX, minY, maxY) = _visBounds(size);

    // Tamamlanmış yollar
    for (final t in roadSystem.all) {
      final s  = gridToScreen(t.col.toDouble(), t.row.toDouble(), size, camera);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      if (px < minX || px > maxX) continue;
      if (py < minY || py > maxY) continue;
      final mask = roadSystem.neighborMask(t.col, t.row);
      RoadRenderer.drawRoadTile(canvas, px, py, hw, hh,
          t.surface, mask, t.hash, zoom: zoom);
    }

    // Bekleyen orderlar — preview
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

    const upChar  = 72.0;
    const upTall  = 256.0;
    const upSmall = 32.0;
    const sideS   = 48.0;
    const sideL   = 160.0;

    _sceneBuffer.clear();

    for (final l in lotuses) {
      if (inView(l.col + 0.5, l.row + 0.5, upSmall, sideS)) {
        _sceneBuffer.add(_LotusDrawable(l, time));
      }
    }
    for (final r in reeds) {
      if (inView(r.col + 0.5, r.row + 0.5, upSmall, sideS)) {
        _sceneBuffer.add(_ReedDrawable(r, time));
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
      if (inView(e.renderX, e.renderY, upChar, sideS)) {
        _sceneBuffer.add(_VillagerDrawable(e, time, dayLight));
      }
    }
    for (final f in farmers) {
      if (inView(f.renderX, f.renderY, upChar, sideS)) {
        _sceneBuffer.add(_FarmerDrawable(f));
      }
    }
    for (final b in builders) {
      if (inView(b.renderX, b.renderY, upChar, sideS)) {
        _sceneBuffer.add(_BuilderDrawable(b));
      }
    }
    for (final w in woodcutters) {
      if (inView(w.renderX, w.renderY, upChar, sideS)) {
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
      if (inView(m.renderX, m.renderY, upChar, sideS)) {
        _sceneBuffer.add(_MinerDrawable(m));
      }
    }
    for (final f in fishers) {
      if (inView(f.renderX, f.renderY, upChar, sideS)) {
        _sceneBuffer.add(_FisherDrawable(f));
      }
    }
    for (final sh in shepherds) {
      if (inView(sh.renderX, sh.renderY, upChar, sideS)) {
        _sceneBuffer.add(_ShepherdDrawable(sh));
      }
    }
    for (final c in cows) {
      if (inView(c.renderX, c.renderY, upChar, sideS)) {
        _sceneBuffer.add(_CowDrawable(c));
      }
    }
    for (final n in mineNodes) {
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
    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      if (inView(cx, cy, upTall, sideL)) {
        final isBurning = burningBuildings.contains(b);
        _sceneBuffer.add(_BuildingDrawable(
            b, time, dayLight, rainIntensity, isBurning));
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
    for (final t in trees) {
      if (inView(t.col + 0.5, t.row + 0.5, upTall, sideS)) {
        _sceneBuffer.add(_TreeDrawable(t, time));
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

    canvas.saveLayer(null, Paint()..color = const Color(0xAAFFFFFF));
    BuildingRenderer.draw(canvas, ghostType!, back, left, right, front);
    canvas.restore();
  }

  // ── Lighting pass ────────────────────────────────────────────────────────
  // Sahnenin üstüne çizilir. Üç katman:
  //   1) Karanlık + vignette (saveLayer içinde)
  //   2) Lokal ışık delikleri (BlendMode.dstOut → karanlığı eritir)
  //   3) Sıcak halo (BlendMode.plus → sahneye ışıma ekler)
  // Gündüz tam aydınlıkta sadece hafif vignette çizilir; gece/şafak/gün
  // batımında tam paket.
  void _drawLightingPass(Canvas canvas, Size size) {
    final darkness = (1.0 - dayLight).clamp(0.0, 1.0);

    // Gündüz fast path — overlay bantları şeffaf, sadece kompozisyon vignette.
    if (overlayTop.a == 0 && overlayBottom.a == 0 && darkness < 0.05) {
      _drawDayVignette(canvas, size);
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

    // (2) Işık kaynakları → karanlığı eritir. Önemli: cumulative dstOut
    // üst üste binen ışıklarda alpha'yı topluyor (parlama patlaması).
    // Bunun yerine ışık alpha'larını bir mask buffer'da BlendMode.lighten ile
    // birleştirip MAX alpha alıyoruz, sonra TEK SEFER dstOut ile dış katmana
    // uyguluyoruz → yan yana evler "alanı genişletir" ama parlamayı çarpmaz.
    if (_lightBuffer.isNotEmpty) {
      canvas.saveLayer(rect, Paint()..blendMode = BlendMode.dstOut);
      for (final l in _lightBuffer) {
        final coreA = (l.intensity * 190).round().clamp(0, 200);
        _pLightMask.shader = ui.Gradient.radial(
          Offset(l.sx, l.sy),
          l.radius,
          [
            Color.fromARGB(coreA, 0xFF, 0xFF, 0xFF),
            const Color(0x00FFFFFF),
          ],
        );
        canvas.drawCircle(Offset(l.sx, l.sy), l.radius, _pLightMask);
        _pLightMask.shader = null;
      }
      canvas.restore();
    }

    canvas.restore();

    // (3) Sıcak halo — saveLayer içinde lighten ile birleştirilir (overlap
    // MAX alır), restore'da plus blend ile sahneye additive eklenir.
    if (_lightBuffer.isNotEmpty && darkness > 0.20) {
      canvas.saveLayer(rect, Paint()..blendMode = BlendMode.plus);
      for (final l in _lightBuffer) {
        final r = l.radius * 1.05;
        final haloAlpha = (l.intensity * darkness * 90).round().clamp(0, 130);
        final inner = Color.fromARGB(
          haloAlpha,
          (l.warm.r * 255).round(),
          (l.warm.g * 255).round(),
          (l.warm.b * 255).round(),
        );
        _pWarmHalo.shader = ui.Gradient.radial(
          Offset(l.sx, l.sy),
          r,
          [inner, inner.withValues(alpha: 0)],
        );
        canvas.drawCircle(Offset(l.sx, l.sy), r, _pWarmHalo);
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

  void _drawRain(Canvas canvas, Size size) {
    if (rainIntensity <= 0) return;
    const kDrops = 240;
    const dropH  = 10.0;
    const dropDx = 2.0; // hafif sağa eğim
    const speedY = 0.55; // ekran boyu/sn

    final visible = (kDrops * rainIntensity.clamp(0.0, 1.0)).round();
    final alpha   = (rainIntensity * 0.55).clamp(0.0, 0.55);
    _pRain.color = Color.fromRGBO(190, 220, 255, alpha);

    for (int i = 0; i < visible; i++) {
      // Her damlanın sabit X'i ve bağımsız Y fazı — şerit oluşmaz
      final x      = ((i * 1731 + 97) % 1000) / 1000.0 * size.width;
      final yPhase = ((i * 617  + 53) % 1000) / 1000.0;
      final y      = ((yPhase + time * speedY) % 1.0) * size.height;
      canvas.drawLine(
        Offset(x,          y),
        Offset(x + dropDx, y + dropH),
        _pRain,
      );
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
      old.fishers         != fishers         ||
      old.shepherds       != shepherds       ||
      old.cows            != cows            ||
      old.zoom            != zoom            ||
      old.resourceBoxes   != resourceBoxes   ||
      old.hayEntities     != hayEntities     ||
      old.groundVersion   != groundVersion   ||
      old.lightSources    != lightSources    ||
      old.eventTint       != eventTint       ||
      old.activeFx        != activeFx        ||
      old.burningBuildings != burningBuildings;
}
