part of 'game_painter.dart';

/// ZEMİN GEÇİŞİ — çamur, zemin önbelleği, su, sınır, tarla, harman, yol, seçim vurguları ve zemin florası.
extension _GroundPass on VillageGamePainter {

  // Yağmur sonrası çim üzerinde kalan küçük, dünya-uzaylı çamur izleri.
  // Kar mevsiminde çizilmez; kış zemini kar katmanıyla temiz kalır.
  void _drawMud(Canvas canvas, Size size) {
    // Çamur kaplaması zemin/çim ayrımını bozduğu için tamamen kaldırıldı.
    // Yağmur simülasyonu ve diğer hava efektleri çalışmaya devam eder.
    return;
  }

  static final Paint _pMudFootprint = Paint()..isAntiAlias = true;

  void _drawMudFootprints(Canvas canvas, Size size) {
    if (season == Season.winter) return;
    for (final villager in villagers) {
      for (final trace in villager.mudFootprints) {
        final fade = (1.0 - trace.age / MudFootprintTrace.lifetime).clamp(
          0.0,
          1.0,
        );
        if (fade <= 0.01) continue;
        final center = gridToScreen(trace.gridX, trace.gridY, size, camera);
        final sx = (trace.dirX - trace.dirY) * kTileW * 0.5;
        final sy = (trace.dirX + trace.dirY) * kTileH * 0.5;
        final angle = atan2(sy, sx);
        _pMudFootprint.color = const Color(
          0xFF4D3728,
        ).withValues(alpha: 0.52 * fade * fade);
        canvas.save();
        canvas.translate(center.dx, center.dy);
        canvas.rotate(angle);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(0, trace.leftFoot ? -0.7 : 0.7),
            width: 4.2,
            height: 2.0,
          ),
          _pMudFootprint,
        );
        canvas.restore();
      }
    }
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
    final bounty = fxPlayback[EventFx.harvestBounty];
    final blight = fxPlayback[EventFx.cropBlight];
    final treatment = blight != null
        ? FarmFxTreatment.blight
        : bounty != null
        ? FarmFxTreatment.bounty
        : FarmFxTreatment.none;
    final playback = blight ?? bounty;
    var diagMin = 0;
    var diagMax = 0;
    if (playback != null && farmTiles.isNotEmpty) {
      diagMin = farmTiles.first.col + farmTiles.first.row;
      diagMax = diagMin;
      for (final tile in farmTiles.skip(1)) {
        final diagonal = tile.col + tile.row;
        if (diagonal < diagMin) diagMin = diagonal;
        if (diagonal > diagMax) diagMax = diagonal;
      }
    }
    for (final t in farmTiles) {
      final s = gridToScreen(t.col.toDouble(), t.row.toDouble(), size, camera);
      final px = s.dx.roundToDouble();
      final py = s.dy.roundToDouble();
      if (px < minX || px > maxX) continue;
      if (py < minY || py > maxY) continue;
      // Ekilmemiş / nadastaki tarla çıplak toprak (stage 0, progress yok) —
      // büyüyen ekinin cross-fade'i tetiklenmesin.
      final showProgress = t.needsSowing ? 0.0 : t.growthProgress;
      var treatmentStrength = 0.0;
      if (playback != null && !t.needsSowing && t.stage > 0) {
        final diagonal = (t.col + t.row - diagMin).toDouble();
        final span = (diagMax - diagMin + 1).toDouble();
        final revealSeconds = min(5.0, max(1.5, playback.duration * 0.28));
        final front =
            (playback.elapsed / revealSeconds).clamp(0.0, 1.0) * (span + 2.0);
        treatmentStrength =
            _smoothUnit((front - diagonal) / 2.0) * playback.fadeOut(1.2);
      }
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
        treatment: treatment,
        treatmentStrength: treatmentStrength,
      );
      if (treatment == FarmFxTreatment.blight && treatmentStrength > 0.42) {
        final hash = t.col * 92821 + t.row * 68917;
        DecorRenderer.drawFxSprite(
          canvas,
          Offset(px + ((hash & 3) - 1.5) * 4, py + hh + 2),
          hash.isEven ? DecorKind.mushroomBrown : DecorKind.mushroomRed,
          variant: (hash >> 3) & 1,
          height: 11 + ((hash >> 5) & 3).toDouble(),
          alpha: treatmentStrength,
        );
      }
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

      // Düz kahverengi karolar yalnızca yükleme başarısız olursa görünen
      // zemin/fallback olarak kalır. Asıl harman; alçak çit, tahıl rafı ve
      // açık çalışma alanıyla tek bir 2×2 izometrik asset'tir.
      final front = gridToScreen(
        site.col + HarmanSite.size.toDouble(),
        site.row + HarmanSite.size.toDouble(),
        size,
        camera,
      );
      ResourceRenderer.drawHarmanYard(
        canvas,
        front.dx,
        front.dy,
        width: kTileW * HarmanSite.size,
      );
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
      for (final o in pendingRoadOrders) {
        if (!o.completed || o.completionCue <= 0) continue;
        _drawRoadCompletionCue(canvas, size, o);
      }
    }
  }

  static final Paint _pRoadFinishStone = Paint()..isAntiAlias = false;
  static final Paint _pRoadFinishDust = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;

  void _drawRoadCompletionCue(Canvas canvas, Size size, RoadOrder order) {
    final age = RoadOrder.completionCueDuration - order.completionCue;
    final t = (age / RoadOrder.completionCueDuration).clamp(0.0, 1.0);
    final settle = 1.0 - pow(1.0 - (t / 0.48).clamp(0.0, 1.0), 3).toDouble();
    final tile = gridToScreen(
      order.col.toDouble(),
      order.row.toDouble(),
      size,
      camera,
    );
    final center = Offset(tile.dx, tile.dy + kTileH * 0.5);
    final material = switch (order.surface) {
      RoadSurface.dirt => const Color(0xFF6D4A30),
      RoadSurface.stone => const Color(0xFFA9A39B),
      RoadSurface.woodBridge => const Color(0xFFAA8050),
    };
    _pRoadFinishStone.color = material.withValues(
      alpha: (order.completionCue / 0.22).clamp(0.0, 1.0),
    );
    canvas.save();
    canvas.translate(center.dx, center.dy - (1.0 - settle) * 11.0);
    canvas.rotate(-0.24 + settle * 0.24);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset.zero,
          width: order.surface == RoadSurface.woodBridge ? 12 : 8,
          height: order.surface == RoadSurface.woodBridge ? 3 : 5,
        ),
        const Radius.circular(1),
      ),
      _pRoadFinishStone,
    );
    canvas.restore();

    if (t < 0.72) {
      final dust = sin((t / 0.72) * pi).clamp(0.0, 1.0);
      _pRoadFinishDust
        ..color = const Color(0xFFB7A385).withValues(alpha: dust * 0.48)
        ..strokeWidth = 1.1;
      final half = 5.0 + t * 17.0;
      canvas.drawLine(
        center.translate(-half, 3),
        center.translate(half, 3),
        _pRoadFinishDust,
      );
      for (int i = 0; i < 4; i++) {
        final side = i.isEven ? -1.0 : 1.0;
        canvas.drawCircle(
          center.translate(side * (4 + t * (8 + i * 2)), 1 - i * 0.8),
          1.0 + dust * 0.7,
          _pRoadFinishDust,
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
}
