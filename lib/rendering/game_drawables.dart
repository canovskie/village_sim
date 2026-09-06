part of 'game_painter.dart';

/// ─── SAHNE VARLIKLARI (DRAWABLE) ────────────────────────────────────────────
///
/// Derinlik sıralı çizim listesine giren her şey: köylü, hayvan, bina, şantiye,
/// ağaç, dekor, mezar, saz, maden düğümü, kutu, yumurta, saman.
///
/// SÖZLEŞME: her drawable tek bir `depth` skaleri verir (painter's algorithm,
/// bkz. [_Drawable]) ve yalnız KENDİNİ çizer — kamera/ışık/atmosfer painter'ın
/// işidir. Yeni bir varlık türü eklerken buraya bir sınıf yaz, `_drawScene`
/// içinde tampona ekle; başka hiçbir yeri değiştirmen gerekmez.
///
/// Paint havuzu ve gölge yardımcıları `game_painter.dart`'ta durur (aynı
/// kütüphane → private erişim serbest).

// ─── DRAWABLE ABSTRACTION ────────────────────────────────────────────────────

abstract class _Drawable {
  double get depth;
  void draw(Canvas canvas, Size size, Offset camera);

  /// Stabil sort tie-break — buffer'daki ekleme sırası (her frame atanır).
  /// Eşit depth'te bu deterministik sıra kullanılır → titreme/rastgele örtme yok.
  int sortIndex = 0;

  /// Bu drawable bir "aktör" (NPC/işçi) ise wrapped entity; değilse null.
  /// Occlusion silhouette pass'i aktörleri buradan bulur. Bina içindeyken null.
  WorkerEntity? get actor => null;

  /// Bu drawable bir bina ise wrapped entity; değilse null. Occlusion testinde
  /// "önde çizilen örten" listesi buradan kurulur.
  BuildingEntity? get building => null;
}

/// Temporary timber defenses remain at the chosen posts when troops advance.
class _BattleBarricadeDrawable extends _Drawable {
  final double x, y;
  _BattleBarricadeDrawable(this.x, this.y);
  @override
  double get depth => x + y;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final p = gridToScreen(x, y, size, camera);
    final timber = Paint()
      ..color = const Color(0xFF69462D)
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final edge = Paint()
      ..color = const Color(0xFFBB9360)
      ..strokeWidth = 1.5;
    canvas.drawOval(
      Rect.fromCenter(center: p, width: 39, height: 12),
      Paint()..color = const Color(0x44000000),
    );
    for (final offset in [-12.0, 0.0, 12.0]) {
      final foot = p + Offset(offset, offset * .3);
      canvas.drawLine(foot, foot + const Offset(4, -20), timber);
      canvas.drawLine(
        foot + const Offset(1, -2),
        foot + const Offset(5, -20),
        edge,
      );
    }
    canvas.drawLine(
      p + const Offset(-17, -14),
      p + const Offset(18, -4),
      timber,
    );
  }
}

/// Kervan liderinin hareket ankrajına bağlı at arabası. İnsan sprite'ından
/// ayrı drawable olduğu için büyük silüet binalar/NPC'lerle doğru derinlikte
/// örtüşür ve occlusion aktörü olarak da tanınır.
class _HorseCartDrawable extends _Drawable {
  final MerchantEntity e;
  _HorseCartDrawable(this.e);

  @override
  double get depth => e.depth;

  @override
  WorkerEntity? get actor => e;

  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(e.renderX, e.renderY, size, camera);
    VehicleRenderer.drawHorseCart(
      canvas,
      s,
      direction: VehicleRenderer.directionForGridVelocity(
        e.travelHeadingX,
        e.travelHeadingY,
      ),
      walkPhase: e.walkPhase,
      isMoving: e.moveIntensity > 0.12,
    );
  }
}

class _CowDrawable extends _Drawable {
  final AnimalEntity a;
  _CowDrawable(this.a);
  @override
  double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawCow(
      canvas,
      s,
      facing: a.facing4,
      walkPhase: a.walkPhase,
      isWalking: a.isWalking,
      scale: a.renderScale * (a.isDying ? (1 - 0.25 * a.deathProgress) : 1.0),
      alpha: a.isDying ? (1 - a.deathProgress) : 1.0,
    );
  }
}

class _SheepDrawable extends _Drawable {
  final AnimalEntity a;
  _SheepDrawable(this.a);
  @override
  double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawSheep(
      canvas,
      s,
      facing: a.facing4,
      walkPhase: a.walkPhase,
      isWalking: a.isWalking,
      scale: a.renderScale * (a.isDying ? (1 - 0.25 * a.deathProgress) : 1.0),
      alpha: a.isDying ? (1 - a.deathProgress) : 1.0,
    );
  }
}

class _ChickenDrawable extends _Drawable {
  final AnimalEntity a;
  _ChickenDrawable(this.a);
  @override
  double get depth => a.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(a.renderX, a.renderY, size, camera);
    AnimalRenderer.drawChicken(
      canvas,
      s,
      facing: a.facing4,
      walkPhase: a.walkPhase,
      isWalking: a.isWalking,
      scale: a.renderScale * (a.isDying ? (1 - 0.25 * a.deathProgress) : 1.0),
      alpha: a.isDying ? (1 - a.deathProgress) : 1.0,
    );
  }
}

class _DecorDrawable extends _Drawable {
  final DecorEntity d;
  final double time;
  _DecorDrawable(this.d, this.time);
  @override
  double get depth => d.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(
      d.col + 0.5 + d.jitterX,
      d.row + 0.5 + d.jitterY,
      size,
      camera,
    );
    DecorRenderer.draw(canvas, center, d, time: time);
  }
}

class _WorldLandmarkDrawable extends _Drawable {
  final WorldLandmark site;
  _WorldLandmarkDrawable(this.site);
  @override
  double get depth => site.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(site.col + 0.5, site.row + 0.5, size, camera);
    WorldLandmarkRenderer.draw(canvas, center, site);
  }
}

class _GraveDrawable extends _Drawable {
  final Grave g;
  _GraveDrawable(this.g);
  @override
  double get depth => g.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(
      g.col + 0.5 + g.jitterX,
      g.row + 0.5 + g.jitterY,
      size,
      camera,
    );
    GraveRenderer.draw(canvas, center, g);
  }
}

class _ReedBedDrawable extends _Drawable {
  final ReedBed b;
  _ReedBedDrawable(this.b);
  @override
  double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(b.gridX, b.gridY, size, camera);
    ReedBedRenderer.draw(
      canvas,
      center,
      seed: (b.gridX * 13 + b.gridY * 7).round(),
    );
  }
}

class _LotusDrawable extends _Drawable {
  final LotusEntity l;
  final double time;
  _LotusDrawable(this.l, this.time);
  @override
  double get depth => l.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(l.col + 0.5, l.row + 0.5, size, camera);
    NatureRenderer.drawLotus(
      canvas,
      center,
      variant: l.variant,
      time: time,
      seed: l.col * 23 + l.row * 37,
    );
  }
}

class _ReedDrawable extends _Drawable {
  final ReedClump r;
  final double time;
  _ReedDrawable(this.r, this.time);
  @override
  double get depth => r.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    // İki tile'ın üst köşelerinin ortası
    final s1 = gridToScreen(r.col.toDouble(), r.row.toDouble(), size, camera);
    final s2 = gridToScreen(r.col2.toDouble(), r.row2.toDouble(), size, camera);
    final cx = (s1.dx + s2.dx) / 2;
    final cy = (s1.dy + s2.dy) / 2 + kTileH / 2; // tile orta yüksekliğine in
    NatureRenderer.drawReeds(
      canvas,
      cx,
      cy,
      time: time,
      seed: r.col * 19 + r.row * 41,
      col: r.col.toDouble(),
      row: r.row.toDouble(),
      growth: r.growth,
    );
  }
}

class _BerryBushDrawable extends _Drawable {
  final BerryBush b;
  final double time;
  _BerryBushDrawable(this.b, this.time);
  @override
  double get depth => b.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    // Tile merkezinin ALT yarısı — çalı zemine oturur, tile'ın ortasında
    // havada durmaz (sazla aynı hizalama mantığı).
    final s = gridToScreen(b.col + 0.5, b.row + 0.5, size, camera);
    NatureRenderer.drawBerryBush(
      canvas,
      s.dx,
      s.dy + kTileH * 0.18,
      ripeness: b.ripeness,
      variant: b.variant,
      seed: b.col * 29 + b.row * 47,
      time: time,
      col: b.col.toDouble(),
      row: b.row.toDouble(),
    );
  }
}

class _TreeDrawable extends _Drawable {
  final TreeEntity t;
  final double time;
  final Season season;
  _TreeDrawable(this.t, this.time, this.season);
  @override
  double get depth => t.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final center = gridToScreen(t.col + 0.5, t.row + 0.5, size, camera);
    // Çam gövdesi tabanında dar elips gölge
    _drawTreeShadow(
      canvas,
      center.dx,
      center.dy,
      28.0,
      t.growthScale,
      t.fellProgress,
      t.fallDirection,
    );
    TreeRenderer.draw(
      canvas,
      t.type,
      center,
      time: time,
      seed: t.col * 17 + t.row * 31,
      chopPhase: t.chopPhase,
      growthScale: t.growthScale,
      col: t.col + 0.5,
      row: t.row + 0.5,
      season: season,
      fellProgress: t.fellProgress,
      fallDirection: t.fallDirection,
    );
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
    final (back, left, right, front) = _corners(
      order.col,
      order.row,
      m.cols,
      m.rows,
      size,
      camera,
    );

    // ── 1) Zemin diamond — inşaat alanı (toprak/sıkıştırılmış renk) ──
    _scratchPath
      ..reset()
      ..moveTo(back.dx, back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(_scratchPath, _pScaffGround);
    canvas.drawPath(_scratchPath, _pScaffBorder);

    // ── 2) Bina sprite reveal (smoothstep + jitter + clip kenarı gölge) ──
    BuildingRenderer.drawConstruction(
      canvas,
      order.type,
      left,
      right,
      front,
      order.progress,
      time,
    );
  }
}

(Offset, Offset, Offset, Offset) _corners(
  int col,
  int row,
  int cols,
  int rows,
  Size size,
  Offset camera,
) {
  final back = gridToScreen(col.toDouble(), row.toDouble(), size, camera);
  final left = gridToScreen(
    col.toDouble(),
    (row + rows).toDouble(),
    size,
    camera,
  );
  final right = gridToScreen(
    (col + cols).toDouble(),
    row.toDouble(),
    size,
    camera,
  );
  final front = gridToScreen(
    (col + cols).toDouble(),
    (row + rows).toDouble(),
    size,
    camera,
  );
  return (back, left, right, front);
}

class _MineDrawable extends _Drawable {
  final MineNode n;
  _MineDrawable(this.n);
  @override
  double get depth => n.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(n.col.toDouble(), n.row.toDouble(), size, camera);
    MineRenderer.draw(
      canvas,
      s.dx,
      s.dy,
      type: n.type,
      chopPhase: n.chopPhase,
      seed: n.col * 13 + n.row * 29,
    );
  }
}

/// Oduncu kulübesinin otonom NPC'si. WoodcutterEntity'den ayrı bir tip
/// (LumberCampEntity) ama davranış/sprite birebir aynı → woodcutter sprite'ı
/// reuse. Önceden painter'a hiç geçirilmemişti — render edilmeden ağaç
/// kesiyordu (ağaç "kendi kendine düşüyor" bug'ı).
class _ResourceBoxDrawable extends _Drawable {
  final ResourceBox b;
  final double time;
  _ResourceBoxDrawable(this.b, this.time);
  @override
  double get depth {
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

class _EggDrawable extends _Drawable {
  final EggEntity e;
  final double time;
  _EggDrawable(this.e, this.time);
  @override
  double get depth => e.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(e.gridX, e.gridY, size, camera);
    // Drop animasyonu (ilk 0.4s yukarıdan iner).
    double y = s.dy - 3;
    final since = time - e.spawnTime;
    if (since < 0.4) {
      final t = since / 0.4;
      y -= (1 - t) * (1 - t) * 9;
    }
    // Çatlamaya yakın hafif sallanma (willHatch).
    double wob = 0;
    if (e.willHatch && e.age > e.resolveAt - 2.0) {
      wob = sin(time * 18 + e.gridX) * 1.3;
    }
    final c = Offset(s.dx + wob, y);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(s.dx, s.dy - 0.5), width: 7, height: 3.5),
      Paint()..color = const Color(0x33000000),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c, width: 6.5, height: 8.5),
      Paint()..color = const Color(0xFFF3E9D2),
    );
    canvas.drawOval(
      Rect.fromCenter(center: c.translate(-1, -1.6), width: 2.4, height: 3.4),
      Paint()..color = const Color(0xFFFFFDF5),
    );
  }
}

/// GÖMÜLÜ ZULA — eşelenmiş toprak öbeği.
///
/// PROSEDÜREL, PNG DEĞİL (Faz 3'ün prop kararıyla aynı gerekçe): sprite
/// beklenirse özellik görünmez kalır. Taze toprak koyu ve belirgindir, iz
/// kapandıkça soluklaşıp otla karışır — oyuncunun "geç kaldım" hissi bu
/// solmadan okunur, bir sayaçtan değil.
class _LootCacheDrawable extends _Drawable {
  final LootCache l;
  final double fade;
  _LootCacheDrawable(this.l, this.fade);
  @override
  double get depth => l.depth;
  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    final s = gridToScreen(l.gridX, l.gridY, size, camera);
    final trace = lootTrace(l.age, fade, witnessed: l.witnessed);
    // Kapanmış iz de tümüyle kaybolmaz — üstüne basan bulabilmeli, yani
    // görünür bir şey kalmalı. Taban 0.30, tazelikle 1.0'a çıkar.
    final vis = 0.30 + 0.70 * trace;

    // Çukurun gölgesi (hafif oval çöküntü).
    canvas.drawOval(
      Rect.fromCenter(center: s, width: 13, height: 6.5),
      Paint()..color = Color.fromRGBO(30, 22, 16, 0.30 * vis),
    );
    // Eşelenmiş toprak — taze kahve, solunca griye kayar.
    final soil = Color.lerp(
      const Color(0xFF5A4A3A),
      const Color(0xFF3E3A2E),
      1 - trace,
    )!;
    canvas.drawOval(
      Rect.fromCenter(center: s.translate(0, -1), width: 10.5, height: 5.0),
      Paint()..color = soil.withValues(alpha: vis),
    );
    // Üstte birkaç kesek — düz bir leke değil, kazılmış toprak.
    final clod = Paint()
      ..color = Color.lerp(
        const Color(0xFF6B5744),
        soil,
        1 - trace,
      )!.withValues(alpha: vis);
    canvas.drawOval(
      Rect.fromCenter(center: s.translate(-2.6, -2.4), width: 4.0, height: 2.4),
      clod,
    );
    canvas.drawOval(
      Rect.fromCenter(center: s.translate(1.9, -3.0), width: 3.2, height: 2.0),
      clod,
    );
  }
}

class _HayDrawable extends _Drawable {
  final HayEntity h;
  final double time;
  _HayDrawable(this.h, this.time);
  @override
  double get depth {
    if (h.isBale) return h.gridX + h.gridY + 1.0;
    final off = ResourcePlacement.offsetFor(h.slotIndex);
    return (h.gridX + off.$1) + (h.gridY + off.$2);
  }

  @override
  void draw(Canvas canvas, Size size, Offset camera) {
    if (h.isBale) {
      const bs = 0.5;
      final right = gridToScreen(h.gridX + bs, h.gridY, size, camera);
      final left = gridToScreen(h.gridX, h.gridY + bs, size, camera);
      final front = gridToScreen(h.gridX + bs, h.gridY + bs, size, camera);
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
