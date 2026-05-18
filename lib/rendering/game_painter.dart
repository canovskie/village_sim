import 'dart:math';
import 'package:flutter/material.dart';
import 'character_renderer.dart';
import '../entities/villager_entity.dart';
import '../entities/builder_entity.dart';
import '../entities/build_order.dart';
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
import '../farm/farm_tile.dart';
import '../entities/farm_farmer.dart';
import '../farm/farm_renderer.dart';
import '../entities/fisher_entity.dart';
import '../world/resource_box.dart';
import '../world/hay_entity.dart';
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

// Scaffold
final _pScaffGround = Paint()..color = const Color(0xFFD4B896)..isAntiAlias = false;
final _pScaffBorder = Paint()
  ..color = const Color(0xFF7A5810)..style = PaintingStyle.stroke
  ..strokeWidth = 1..isAntiAlias = false;

// Day/night overlay
final _pOverlay = Paint()..isAntiAlias = false;

// Map border
final _pMapBorder = Paint()
  ..color = const Color(0xFF1E4820)..style = PaintingStyle.stroke
  ..strokeWidth = 2..isAntiAlias = false;

// Ghost
final _pGhostFill   = Paint()..isAntiAlias = false;
final _pGhostBorder = Paint()..style = PaintingStyle.stroke..strokeWidth = 2..isAntiAlias = false;

// Rain — alpha her frame değişir, paint havuzlu.
final _pRain = Paint()
  ..strokeWidth = 1.0
  ..isAntiAlias = false;

// Gölgeler — karakter/ağaç için yumuşak eliptik, bina için diamond.
// Bina gölgesi MaskFilter ile hafif blur (yükseklik hissi).
final _pShadow         = Paint()..color = const Color(0x77000000)..isAntiAlias = true;
final _pBuildingShadow = Paint()
  ..color      = const Color(0x55000000)
  ..isAntiAlias = true
  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);

/// Karakterin ayağı altında ince yatay elips. (sx, sy) = feet pozisyonu
/// (her character drawable'da gridToScreen sonucu).
void _drawCharShadow(Canvas canvas, double sx, double sy) {
  canvas.drawOval(
    Rect.fromCenter(center: Offset(sx, sy + 2), width: 20, height: 7),
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

/// Bina footprint'inin ÖN/SAĞ kenarlarına paralel hafif gölge — sprite
/// kenarından "düşmüş" gibi durur. front: ön köşe, right: sağ köşe.
void _drawBuildingShadow(Canvas canvas, Offset back, Offset left,
    Offset right, Offset front) {
  // Footprint'i biraz aşağı/sağa öteleyerek diamond shadow çiz.
  const dx = 4.0;
  const dy = 3.0;
  _scratchPath
    ..reset()
    ..moveTo(back.dx + dx,  back.dy + dy)
    ..lineTo(right.dx + dx, right.dy + dy)
    ..lineTo(front.dx + dx, front.dy + dy)
    ..lineTo(left.dx + dx,  left.dy + dy)
    ..close();
  canvas.drawPath(_scratchPath, _pBuildingShadow);
}

// Selection/ghost/scaffold/border için ortak Path havuzu.
// paint() synchronous — Path drawn anında canvas'a yazılır, sonra mutate edebiliriz.
final Path _scratchPath = Path();

// Sahne drawable buffer'ı — her frame clear edilip yeniden doldurulur.
// Spread/sort her frame allocate yapmasın diye top-level static.
final List<_Drawable> _sceneBuffer = [];

// ─── DRAWABLE ABSTRACTION ────────────────────────────────────────────────────

abstract class _Drawable {
  double get depth;
  void draw(Canvas canvas, Size size, Offset camera);
}

// "z z z" için static TextPainter havuzu
final _zPainters = List.generate(3, (i) {
  final tp = TextPainter(textDirection: TextDirection.ltr);
  return tp;
});
const _zTexts = ['z', 'z', 'Z'];
const _zOffsets = [Offset(6, -18), Offset(10, -26), Offset(15, -35)];

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

    // Gölge — ayak altında, torch glow'un da altında
    _drawCharShadow(canvas, s.dx, s.dy);

    // Draw torch glow BEFORE character (lower layer)
    final isWalkingAtNight = e.isWalking && dayLight < 0.4;
    if (isWalkingAtNight) {
      final seed = e.gridX.toInt() * 13 + e.gridY.toInt() * 7;
      ToolRenderer.drawTorchGlow(canvas, s.dx, s.dy, time, seed);
    }

    if (e.isSleeping && !e.isInsideBuilding) {
      // Yatay uyku pozu — yastık + battaniye + kapalı göz, hafif breath.
      canvas.save();
      canvas.translate(s.dx, s.dy);
      canvas.scale(kCharScale, kCharScale);
      CharacterRenderer.drawSleeping(canvas, e.type,
          walkPhase: e.walkPhase,
          flipX: !e.facingRight);
      canvas.restore();
      _drawZzz(canvas, s);
      return;
    }

    canvas.save();
    canvas.translate(s.dx, s.dy);
    canvas.scale(kCharScale, kCharScale);
    CharacterRenderer.draw(canvas, e.type,
        flipX:         !e.facingRight,
        walkPhase:     e.walkPhase,
        moveIntensity: e.moveIntensity,
        carrying:      e.isCarrying && e.carriedItem != null,
        torch:         isWalkingAtNight,
        visual:        e.visual,
        time:          time);
    canvas.restore();

    // Draw carried item above the villager
    if (e.carriedItem != null) {
      final item = e.carriedItem!;
      if (item is ResourceBox) {
        ResourceRenderer.drawCarriedBox(canvas, item, s.dx, s.dy);
      } else if (item is HayEntity) {
        ResourceRenderer.drawCarriedHay(canvas, item, s.dx, s.dy);
      }
    }
  }

  void _drawZzz(Canvas canvas, Offset base) {
    for (int i = 0; i < 3; i++) {
      final phase  = (time * 0.9 + i * 0.55) % 1.0;
      final alpha  = (phase < 0.5
          ? phase / 0.5
          : (1.0 - phase) / 0.5) * 200;
      final offset = _zOffsets[i] + Offset(0, -phase * 6);
      final tp     = _zPainters[i]
        ..text = TextSpan(
          text: _zTexts[i],
          style: TextStyle(
            color: Color.fromARGB(alpha.toInt().clamp(0, 200), 180, 210, 255),
            fontSize: 8.0 + i * 2,
            fontWeight: FontWeight.bold,
          ),
        )
        ..layout();
      tp.paint(canvas, base + offset);
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

    if (working && b.currentOrder != null) {
      _drawProgressBar(canvas, s, b.currentOrder!.progress);
    }
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
        harvestPhase:  f.harvestPhase);
    canvas.restore();
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
  }
}

class _FisherDrawable extends _Drawable {
  final FisherEntity f;
  _FisherDrawable(this.f);
  @override double get depth => f.depth;
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
        time: time, seed: r.col * 19 + r.row * 41);
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
        growthScale: t.growthScale);
  }
}

class _BuildingDrawable extends _Drawable {
  final BuildingEntity b;
  final double time;
  final double dayLight;
  _BuildingDrawable(this.b, this.time, this.dayLight);
  @override double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final corners = _corners(b.col, b.row, b.cols, b.rows, size, camera);
    // Footprint'in sağ/alt kayması — sprite ground'a basmış hissi
    _drawBuildingShadow(canvas, corners.$1, corners.$2, corners.$3, corners.$4);
    BuildingRenderer.draw(canvas, b.type, corners.$1, corners.$2, corners.$3, corners.$4,
        time: time, seed: b.col * 17 + b.row * 31, dayLight: dayLight,
        isActive: b.isActive);
  }
}

class _ScaffoldDrawable extends _Drawable {
  final BuildOrder order;
  _ScaffoldDrawable(this.order);
  @override
  double get depth {
    final m = kBuildingMeta[order.type]!;
    return (order.col + m.cols + order.row + m.rows).toDouble();
  }
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final m = kBuildingMeta[order.type]!;
    final (back, left, right, front) = _corners(order.col, order.row, m.cols, m.rows, size, camera);

    // Temel zemin (inşaat alanı)
    _scratchPath
      ..reset()
      ..moveTo(back.dx,  back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx,  left.dy)
      ..close();
    canvas.drawPath(_scratchPath, _pScaffGround);
    canvas.drawPath(_scratchPath, _pScaffBorder);

    // Bina tabandan yukarı açılır
    BuildingRenderer.drawConstruction(
        canvas, order.type, left, right, front, order.progress);
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
  _ResourceBoxDrawable(this.b);
  @override double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(b.gridX, b.gridY, size, camera);
    ResourceRenderer.drawBox(canvas, b, s.dx, s.dy);
  }
}

class _HayDrawable extends _Drawable {
  final HayEntity h;
  _HayDrawable(this.h);
  @override double get depth => h.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    if (h.isBale) {
      const bs = 0.5;
      final right = gridToScreen(h.gridX + bs, h.gridY,       size, camera);
      final left  = gridToScreen(h.gridX,      h.gridY + bs,  size, camera);
      final front = gridToScreen(h.gridX + bs, h.gridY + bs,  size, camera);
      final spriteW = (right.dx - left.dx).abs();
      ResourceRenderer.drawBale(canvas, front.dx, front.dy, spriteW);
    } else {
      final s = gridToScreen(h.gridX + 0.5, h.gridY + 0.5, size, camera);
      ResourceRenderer.drawHay(canvas, h, s.dx, s.dy);
    }
  }
}

// ─── PAINTER ─────────────────────────────────────────────────────────────────

class VillageGamePainter extends CustomPainter {
  final List<VillagerEntity> villagers;
  final List<BuildingEntity> buildings;
  final List<BuilderEntity>  builders;
  final List<BuildOrder>     pendingOrders;
  final Offset camera;
  final BuildingType? ghostType;
  final (int, int)?   ghostTile;
  final bool          ghostValid;
  final double        time;

  final Color  sceneOverlay;
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
  final double zoom;
  final List<ResourceBox> resourceBoxes;
  final List<HayEntity>   hayEntities;
  /// Suya yansıtılan gökyüzü tonu — _cycle.skyMid'den geçer.
  final Color skyReflection;

  const VillageGamePainter({
    required this.villagers,
    required this.buildings,
    required this.builders,
    required this.pendingOrders,
    required this.camera,
    this.ghostType,
    this.ghostTile,
    this.ghostValid    = false,
    this.time          = 0,
    this.sceneOverlay  = const Color(0x00000000),
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
    this.zoom          = 1.0,
    this.resourceBoxes = const [],
    this.hayEntities   = const [],
    this.skyReflection = const Color(0xFFA0C0E0),
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
    _drawDayNightOverlay(canvas, size);
    _drawRain(canvas, size);
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

  void _drawGround(Canvas canvas, Size size) {
    final (minX, maxX, minY, maxY) = _visBounds(size);

    // Görünür ekran köşelerini grid koordinatına çevir → sadece görünür
    // tile aralığını döngüye al. Tüm 6144 tile yerine yalnızca viewport'a
    // giren kısmı iterate eder (zoom=1'de ~600, zoom=0.25'te ~6144).
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

    for (int row = rowMin; row <= rowMax; row++) {
      for (int col = colMin; col <= colMax; col++) {
        final s = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
        _drawTile(canvas, s.dx, s.dy, col, row);
      }
    }
    _drawMapBorder(canvas, size);
  }

  void _drawTile(Canvas canvas, double x, double y, int col, int row) {
    final hw = kTileW / 2;
    final hh = kTileH / 2;
    final px = x.roundToDouble();
    final py = y.roundToDouble();
    if (waterTiles.contains((col, row))) {
      WaterRenderer.drawTile(canvas, px, py, hw, hh,
          time: time, seed: col * 17 + row * 31,
          dayLight: dayLight, rainIntensity: rainIntensity,
          zoom: zoom, skyTint: skyReflection);
    } else {
      TileRenderer.drawGrassTile(canvas, px, py, hw, hh, col, row);
      // Kıyı kum geçişi — su komşu sayısına göre
      int sides = 0;
      if (waterTiles.contains((col,     row - 1))) sides++;
      if (waterTiles.contains((col + 1, row    ))) sides++;
      if (waterTiles.contains((col,     row + 1))) sides++;
      if (waterTiles.contains((col - 1, row    ))) sides++;
      if (sides > 0) {
        TileRenderer.drawSandOverlay(canvas, px, py, hw, hh, sides);
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
        _sceneBuffer.add(_ResourceBoxDrawable(b));
      }
    }
    for (final h in hayEntities) {
      if (h.isDelivered || h.isBeingCarried) continue;
      if (inView(h.gridX, h.gridY, upSmall, sideS)) {
        _sceneBuffer.add(_HayDrawable(h));
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
    // Madenci ocağın içindeyse gizlenir — daha önce drawable hiç yaratılmazdı,
    // şimdi de viewport culling sonrası bina-içi kontrolü uygulanır.
    for (final m in miners) {
      if (m.isMining) {
        bool inside = false;
        for (final b in buildings) {
          if (b.type != BuildingType.mineBuilding) continue;
          final meta = kBuildingMeta[b.type]!;
          if (m.gridX >= b.col - 0.5 && m.gridX < b.col + meta.cols + 0.5 &&
              m.gridY >= b.row - 0.5 && m.gridY < b.row + meta.rows + 0.5) {
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
    for (final n in mineNodes) {
      if (n.isDepleted) continue;
      bool hidden = false;
      for (final b in buildings) {
        if (b.type != BuildingType.mineBuilding) continue;
        final meta = kBuildingMeta[b.type]!;
        if (n.col >= b.col && n.col < b.col + meta.cols &&
            n.row >= b.row && n.row < b.row + meta.rows) {
          hidden = true; break;
        }
      }
      if (hidden) continue;
      if (inView(n.col + 0.5, n.row + 0.5, upSmall, sideS)) {
        _sceneBuffer.add(_MineDrawable(n));
      }
    }
    for (final b in buildings) {
      // Bina merkezi viewport içinde mi? (sprite ön köşeden yukarı/sola yayılır)
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      if (inView(cx, cy, upTall, sideL)) {
        _sceneBuffer.add(_BuildingDrawable(b, time, dayLight));
      }
    }
    for (final o in pendingOrders) {
      if (o.completed) continue;
      final m = kBuildingMeta[o.type]!;
      final cx = o.col + m.cols / 2.0;
      final cy = o.row + m.rows / 2.0;
      if (inView(cx, cy, upTall, sideL)) {
        _sceneBuffer.add(_ScaffoldDrawable(o));
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

  // ── Gece/gündüz overlay ───────────────────────────────────────────────────

  void _drawDayNightOverlay(Canvas canvas, Size size) {
    if (sceneOverlay.alpha == 0) return;
    _pOverlay.color = sceneOverlay;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), _pOverlay);
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
      old.sceneOverlay    != sceneOverlay    ||
      old.rainIntensity   != rainIntensity   ||
      old.farmTiles       != farmTiles       ||
      old.farmers         != farmers         ||
      old.farmSelection   != farmSelection   ||
      old.lumberSelection != lumberSelection ||
      old.villagers       != villagers       ||
      old.buildings       != buildings       ||
      old.builders        != builders        ||
      old.pendingOrders   != pendingOrders   ||
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
      old.zoom            != zoom            ||
      old.resourceBoxes   != resourceBoxes   ||
      old.hayEntities     != hayEntities;
}
