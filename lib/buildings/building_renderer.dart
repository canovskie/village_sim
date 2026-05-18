import 'dart:math' show sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'building_type.dart';
import '../rendering/asset_style.dart';

class BuildingRenderer {
  // ── Sprite önbelleği ────────────────────────────────────────────────────────
  static final Map<BuildingType, ui.Image> _cache = {};

  /// Panel thumbnail'leri — yükleme sırasında 48px genişliğe küçültülmüş
  static final Map<BuildingType, ui.Image> thumbnails = {};

  // ── Static Paint havuzu ────────────────────────────────────────────────────
  // Sprite paint AssetStyle'dan — merkezi yumuşaklık konfigürasyonu.
  static final _pSprite = AssetStyle.paint();
  static final _pGlow1   = Paint()..isAntiAlias = true;
  static final _pGlow2   = Paint()..isAntiAlias = true;
  static final _pGlow3   = Paint()..isAntiAlias = true;
  static final _pDust    = Paint()..isAntiAlias = true;

  // Tüm bina sprite'larını asenkron yükle. main.dart initState'te çağrılır.
  static Future<void> loadAll() async {
    await _loadSprite(BuildingType.woodenHouse, 'assets/buildings/minihouse.png');
    await _loadSprite(BuildingType.mill,        'assets/buildings/mill.png');
    await _loadSprite(BuildingType.stable,      'assets/buildings/stable.png');
    await _loadSprite(BuildingType.well,        'assets/buildings/well.png');
    await _loadSprite(BuildingType.market,      'assets/buildings/market.png');
    await _loadSprite(BuildingType.townhall,    'assets/buildings/townhall.png');
    await _loadSprite(BuildingType.tavern,      'assets/buildings/tavern.png');
    await _loadSprite(BuildingType.fisherCabin, 'assets/buildings/fishercabin.png');
    await _loadSprite(BuildingType.warehouse,   'assets/buildings/warehouse.png');
    await _loadSprite(BuildingType.firepit,      'assets/buildings/firepit.png');
    await _loadSprite(BuildingType.lumberCamp,   'assets/buildings/lumberjack.png');
    await _loadSprite(BuildingType.mineBuilding, 'assets/buildings/mine.png');
  }

  static Future<void> _loadSprite(BuildingType type, String path) async {
    try {
      final data = await rootBundle.load(path);
      final raw  = data.buffer.asUint8List();

      // Tam boyut sprite — yükleme anında bir kez yumuşatılır
      final codec = await ui.instantiateImageCodec(raw);
      final frame = await codec.getNextFrame();
      _cache[type] = await AssetStyle.softenAtLoad(frame.image);

      // 32px thumbnail (panel preview için) — bu da yumuşatılır
      final thumbCodec = await ui.instantiateImageCodec(raw, targetWidth: 32);
      final thumbFrame = await thumbCodec.getNextFrame();
      thumbnails[type] = await AssetStyle.softenAtLoad(thumbFrame.image);
    } catch (e) {
      debugPrint('BuildingRenderer: $path yüklenemedi — $e');
    }
  }

  // ── Ana çizim ───────────────────────────────────────────────────────────────
  static void draw(Canvas canvas, BuildingType type,
      Offset back, Offset left, Offset right, Offset front,
      {double time = 0, int seed = 0, double dayLight = 1.0, bool isActive = false}) {
    final img  = _cache[type];
    final meta = kBuildingMeta[type];
    if (img == null || meta == null) return;

    _drawAmbientGlow(canvas, type, img, left, right, front, meta, dayLight, time, seed);
    _drawSprite(canvas, img, left, right, front, meta.groundY, meta.groundXCenter, meta.spriteScale);
    _drawLights(canvas, type, img, left, right, front, meta, dayLight, time, seed);

    final chimneys = kBuildingChimneys[type];
    if (chimneys != null && chimneys.isNotEmpty) {
      _drawChimneySmoke(canvas, img, left, right, front, meta, time, seed, chimneys, dayLight);
    }

    if (isActive) {
      _drawActiveSmoke(canvas, img, left, right, front, meta, time, seed);
    }
  }

  // ── Baca dumanı ──────────────────────────────────────────────────────────────
  // Her baca için density'ye orantılı sayıda partikül; sin sallanması + yükselme.
  // Gece alpha boost — kontrast yüksek.
  static void _drawChimneySmoke(
      Canvas canvas, ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta, double time, int seed,
      List<BuildingChimney> chimneys, double dayLight) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;

    // Gündüz 0.55 → Gece 0.90 alpha çarpanı
    final alphaScale = 0.55 + (1.0 - dayLight) * 0.35;

    for (int c = 0; c < chimneys.length; c++) {
      final cm = chimneys[c];
      final cx = dstL + cm.nx * spriteW;
      final cy = dstT + cm.ny * spriteH;
      final n  = (5 * cm.density).round().clamp(2, 12);

      for (int i = 0; i < n; i++) {
        // Lifecycle 0..1 — partikül başına farklı offset → akış sürekliliği
        final phase = (time * 0.42 * cm.rate
                       + seed * 0.07
                       + c * 0.31
                       + i / n) % 1.0;
        final rise = phase * spriteH * 0.5;
        // Hafif sin sway — partikülden partiküle faz farkı
        final sway = sin(time * 1.1 + i * 1.7 + seed * 0.11 + c * 0.9) * 7.0 * phase;
        // Yükseldikçe büyür
        final radius = 2.5 + phase * 6.5;
        // Alpha: 0..0.22 ramp up, 0.22..1 fade out
        final a = phase < 0.22 ? phase / 0.22 : 1.0 - (phase - 0.22) / 0.78;
        final alpha = (a * 130 * alphaScale).toInt().clamp(0, 130);
        if (alpha < 6) continue;
        _pDust.color = Color.fromARGB(alpha, 195, 190, 180);
        canvas.drawCircle(Offset(cx + sway, cy - rise), radius, _pDust);
      }
    }
  }

  // ── Aktif maden animasyonu: baca dumanı ──────────────────────────────────────
  static void _drawActiveSmoke(
      Canvas canvas, ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta, double time, int seed) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;

    // 4 duman parçacığı — baca pozisyonuna göre
    const smokePts = [(0.38, 0.08), (0.42, 0.06), (0.36, 0.05), (0.44, 0.09)];
    for (int i = 0; i < smokePts.length; i++) {
      final (nx, ny) = smokePts[i];
      final phase    = (time * 0.7 + seed * 0.09 + i * 0.55) % 1.0;
      final rise     = phase * spriteH * 0.35;
      final sway     = sin(time * 1.2 + i * 1.7 + seed * 0.05) * 5.0;
      final alpha    = ((1.0 - phase) * 100).toInt().clamp(0, 100);
      final radius   = 3.0 + phase * 8.0;

      _pDust.color = Color.fromARGB(alpha, 200, 190, 170);
      canvas.drawCircle(
        Offset(dstL + nx * spriteW + sway, dstT + ny * spriteH - rise),
        radius, _pDust,
      );
    }
  }

  // ── İnşaat animasyonu: tabandan yukarı açılır ────────────────────────────────
  static void drawConstruction(Canvas canvas, BuildingType type,
      Offset left, Offset right, Offset front, double progress) {
    final img  = _cache[type];
    final meta = kBuildingMeta[type];
    if (img == null || meta == null) return;

    final spriteW  = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH  = spriteW * img.height / img.width;
    final bottom   = (front.dy).roundToDouble();
    final top      = (front.dy - spriteH * meta.groundY).roundToDouble();
    final clipTop  = (bottom - (bottom - top) * progress).roundToDouble();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-9999, clipTop, 9999, bottom + 1));
    _drawSprite(canvas, img, left, right, front,
        meta.groundY, meta.groundXCenter, meta.spriteScale);
    canvas.restore();
  }

  // ── Çevre aydınlatması ────────────────────────────────────────────────────
  // Sprite çizilmeden ÖNCE çağrılır → hale zemin üstüne, sprite altına düşer.
  // Sadece fener tipi noktalar ambient ışık yayar.
  static void _drawAmbientGlow(
      Canvas canvas,
      BuildingType type,
      ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta,
      double dayLight,
      double time,
      int seed) {
    final lights = kBuildingLights[type];
    if (lights == null || lights.isEmpty) return;

    final nightness = 1.0 - dayLight;
    if (nightness < 0.02) return;

    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;

    for (int i = 0; i < lights.length; i++) {
      final lt = lights[i];
      if (lt.kind != LightKind.lantern) continue;

      final lx      = dstL + lt.nx * spriteW;
      final ly      = dstT + lt.ny * spriteH;
      final flicker = sin(time * 3.7 + seed * 0.17 + i * 2.1) * 0.15 + 0.85;
      final pos     = Offset(lx, ly);

      // Üç katman — dıştan içe doğru artan yoğunluk
      final a1 = (nightness * flicker * 35).toInt().clamp(0, 35);
      final a2 = (nightness * flicker * 55).toInt().clamp(0, 55);
      final a3 = (nightness * flicker * 80).toInt().clamp(0, 80);

      _pGlow1.color = Color.fromARGB(a1, 255, 130, 10);
      _pGlow2.color = Color.fromARGB(a2, 255, 155, 30);
      _pGlow3.color = Color.fromARGB(a3, 255, 190, 60);
      canvas.drawCircle(pos, 72, _pGlow1);
      canvas.drawCircle(pos, 44, _pGlow2);
      canvas.drawCircle(pos, 22, _pGlow3);
    }
  }

  // ── Gece ışık efektleri ────────────────────────────────────────────────────
  // Sprite'ın dst rect'ini yeniden hesaplayarak ışık noktalarını dünya
  // koordinatına dönüştürür; katmanlı dairelerle yumuşak parlama çizer.
  static void _drawLights(
      Canvas canvas,
      BuildingType type,
      ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta,
      double dayLight,
      double time,
      int seed) {
    final lights = kBuildingLights[type];
    if (lights == null || lights.isEmpty) return;

    final nightness = 1.0 - dayLight;
    if (nightness < 0.02) return; // tam gündüz — ışık yok

    // Sprite rect (buildingMeta bağımlı — _drawSprite ile aynı hesap)
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;

    for (int i = 0; i < lights.length; i++) {
      final lt = lights[i];
      final lx = dstL + lt.nx * spriteW;
      final ly = dstT + lt.ny * spriteH;

      double brightness;
      double radius;
      int r, g, b;

      if (lt.kind == LightKind.lantern) {
        // Titreşim efekti
        final flicker = sin(time * 3.7 + seed * 0.17 + i * 2.1) * 0.15 + 0.85;
        brightness = flicker;
        radius     = 6.0;
        r = 255; g = 150; b = 30;
      } else {
        // Pencere — hafif nabız
        final pulse = sin(time * 0.8 + seed * 0.13 + i * 1.7) * 0.05 + 0.95;
        brightness = pulse;
        radius     = 3.5;
        r = 255; g = 210; b = 90;
      }

      final base = (nightness * brightness * 210).toInt().clamp(0, 210);
      if (base < 6) continue;

      final pos = Offset(lx, ly);

      // Dış hale (geniş, şeffaf)
      _pGlow1.color = Color.fromARGB((base * 0.12).toInt(), r, g, b);
      _pGlow2.color = Color.fromARGB((base * 0.30).toInt(), r, g, b);
      _pGlow3.color = Color.fromARGB(base, 255, 240, 180);
      canvas.drawCircle(pos, radius * 2.8, _pGlow1);
      canvas.drawCircle(pos, radius * 1.6, _pGlow2);
      canvas.drawCircle(pos, radius * 0.55, _pGlow3);
    }
  }

  // ── Sprite konumlandırma ────────────────────────────────────────────────────
  // Sprite genişliği = tile footprint genişliği (left → right arası px).
  // Ön köşe (front) → sprite içindeki taban merkezi (groundXCenter, groundY)
  // noktasına sabitlenir.
  static void _drawSprite(
      Canvas canvas, ui.Image img,
      Offset left, Offset right, Offset front,
      double groundY, double groundXCenter, double spriteScale) {

    final spriteW = (right.dx - left.dx).abs() * spriteScale;
    final spriteH = spriteW * img.height / img.width;

    // Sprite'ın taban merkezi (groundXCenter, groundY) → front tile köşesi
    final dst = Rect.fromLTWH(
      (front.dx - spriteW * groundXCenter).roundToDouble(),
      (front.dy - spriteH * groundY).roundToDouble(),
      spriteW.roundToDouble(),
      spriteH.roundToDouble(),
    );

    final src = Rect.fromLTWH(
      0, 0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    canvas.drawImageRect(img, src, dst, _pSprite);
  }
}
