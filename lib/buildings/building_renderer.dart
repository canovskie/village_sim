import 'dart:math' show sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'building_type.dart';
import '../rendering/asset_style.dart';
import '../rendering/flame_renderer.dart';
import '../rendering/smoke_renderer.dart';

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
    // TODO: dedicated barn.png — şimdilik stable.png'yi paylaşır.
    await _loadSprite(BuildingType.barn,         'assets/buildings/stable.png');
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
      {double time = 0, int seed = 0, double dayLight = 1.0,
       double rainIntensity = 0.0, bool isActive = false}) {
    // Lamppost — asset yok, procedurel çizim.
    if (type == BuildingType.lamppost) {
      _drawLamppost(canvas, back, left, right, front, time, seed, dayLight);
      return;
    }

    final img  = _cache[type];
    final meta = kBuildingMeta[type];
    if (img == null || meta == null) return;

    _drawAmbientGlow(canvas, type, img, left, right, front, meta, dayLight, time, seed);
    _drawSprite(canvas, img, left, right, front, meta.groundY, meta.groundXCenter, meta.spriteScale);
    _drawLights(canvas, type, img, left, right, front, meta, dayLight, time, seed);

    final chimneys = kBuildingChimneys[type];
    if (chimneys != null && chimneys.isNotEmpty) {
      _drawChimneySmoke(canvas, img, left, right, front, meta, time, seed,
          chimneys, dayLight, rainIntensity: rainIntensity);
    }

    if (isActive) {
      _drawActiveSmoke(canvas, img, left, right, front, meta, time, seed);
    }

    // Firepit — yağmur yağmıyorsa animasyonlu alev. Yağmur şiddetli ise
    // (>0.3) ateş söner, sadece duman kalır.
    if (type == BuildingType.firepit && rainIntensity < 0.30) {
      final cx = (back.dx + front.dx) * 0.5;
      // Footprint y-merkezi alt zemini → biraz yukarı yer ayarı.
      final cy = (left.dy + right.dy) * 0.5 + 2;
      // Tile genişliği ile orantılı alev ölçeği.
      final tileW = (right.dx - left.dx).abs();
      final s = tileW / 22.0;
      // Yağmur azalırken alev de yumuşar — intensity 1.0 → 0 (rainIntensity 0 → 0.3).
      final intensity = (1.0 - rainIntensity / 0.30).clamp(0.0, 1.0);
      FlameRenderer.draw(canvas, cx, cy, s, time, seed, intensity: intensity);
    }
  }

  // ── Sokak feneri (procedurel) ───────────────────────────────────────────────
  // Asset yok, doğrudan piksel çizimi. Footprint merkezinden yükselen ahşap
  // direk + üstte demir kafesli lamba. Gece içeriden sıcak alev parlar
  // (lighting pass ayrıca büyük halo ekler).
  static final _pLampPostBase = Paint()..color = const Color(0xFF7A6E60)..isAntiAlias = false;
  static final _pLampPost     = Paint()..color = const Color(0xFF5A3E20)..isAntiAlias = false;
  static final _pLampCage     = Paint()..color = const Color(0xFF2A1A10)..isAntiAlias = false;

  static void _drawLamppost(Canvas canvas,
      Offset back, Offset left, Offset right, Offset front,
      double time, int seed, double dayLight) {
    // Tile merkezi (footprint orta noktası)
    final cx = (back.dx + front.dx) / 2;
    final cy = (back.dy + front.dy) / 2;

    // Boyut diğer 1×1 binalarla orantılı (well/firepit'e yakın)
    final tileW = (right.dx - left.dx).abs();
    final scale = tileW / 64.0; // 64 base width → ölçek katsayısı

    final postH = 36.0 * scale;
    final postW = 2.0  * scale;
    final baseW = 10.0 * scale;
    final baseH = 4.0  * scale;
    final lampW = 9.0  * scale;
    final lampH = 11.0 * scale;
    final armW  = 14.0 * scale;
    final armH  = 1.5  * scale;

    final groundY = cy + 1; // footprint zemin seviyesi

    // 1) Taş kaide
    canvas.drawRect(
      Rect.fromLTWH(cx - baseW / 2, groundY - baseH, baseW, baseH),
      _pLampPostBase);
    // Kaide gölgesi (sağa hafif düşer)
    canvas.drawRect(
      Rect.fromLTWH(cx - baseW / 2 + 1, groundY - baseH + 1, baseW, 1),
      _pLampPost);

    // 2) Ahşap direk
    canvas.drawRect(
      Rect.fromLTWH(cx - postW / 2, groundY - baseH - postH, postW, postH),
      _pLampPost);

    // 3) Üst yatay kol (estetik destek)
    canvas.drawRect(
      Rect.fromLTWH(cx - armW / 2, groundY - baseH - postH + 2 * scale, armW, armH),
      _pLampPost);

    // 4) Lamba kafesi (demir)
    final lampX = cx - lampW / 2;
    final lampY = groundY - baseH - postH - lampH + 2 * scale;
    canvas.drawRect(Rect.fromLTWH(lampX, lampY, lampW, lampH), _pLampCage);
    // Kafes üst kapağı (geniş)
    canvas.drawRect(
      Rect.fromLTWH(lampX - scale, lampY - 1.5 * scale, lampW + 2 * scale, 2 * scale),
      _pLampCage);

    // 5) Cam içi alev — gece prosedürel animasyonlu (FlameRenderer).
    // Lamba kafesinin içinde, scale küçük (1.2 civarı).
    final darkness = (1.0 - dayLight).clamp(0.0, 1.0);
    if (darkness > 0.05) {
      final flameCy = lampY + lampH * 0.85; // kafesin tabanı
      FlameRenderer.draw(canvas, cx, flameCy, scale * 1.0, time, seed,
          intensity: darkness, sparks: false);
    }
  }

  // ── Baca dumanı ──────────────────────────────────────────────────────────────
  // Her baca için density'ye orantılı sayıda partikül; sin sallanması + yükselme.
  // Gece alpha boost — kontrast yüksek.
  static void _drawChimneySmoke(
      Canvas canvas, ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta, double time, int seed,
      List<BuildingChimney> chimneys, double dayLight,
      {double rainIntensity = 0.0}) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;

    // Gündüz 0.55 → Gece 0.90 alpha çarpanı
    final alphaScale = 0.55 + (1.0 - dayLight) * 0.35;
    // Yağmurda duman yoğunlaşır + gri-mavi tona kayar (ıslak buhar hissi).
    final wet = rainIntensity.clamp(0.0, 1.0);
    final tintR = (200 - wet * 40).round().clamp(80, 220);
    final tintG = (192 - wet * 32).round().clamp(80, 220);
    final tintB = (178 + wet * 16).round().clamp(80, 220);
    final tint  = Color.fromARGB(255, tintR, tintG, tintB);

    for (int c = 0; c < chimneys.length; c++) {
      final cm = chimneys[c];
      final cx = dstL + cm.nx * spriteW;
      final cy = dstT + cm.ny * spriteH;
      // Sprite scale chimney density'siyle orantılı (firepit 2.0 → büyük
      // sütun, küçük ev 0.6 → ince izgar). Yağmurda hafif boost (+%20).
      final dScale = (0.6 + cm.density * 0.45) * (1.0 + wet * 0.20);
      // Intensity: gündüz/gece + chimney rate.
      final intensity = (alphaScale * (0.7 + cm.rate * 0.30)).clamp(0.0, 1.0);
      SmokeRenderer.draw(canvas, cx, cy, dScale, time, seed * 31 + c,
          tint: tint, intensity: intensity);
    }
  }

  // ── Aktif maden animasyonu: baca dumanı (sprite tabanlı) ────────────────────
  static void _drawActiveSmoke(
      Canvas canvas, ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta, double time, int seed) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;
    // Maden bacası — orta-gri ton, orta yoğunluk.
    final cx = dstL + 0.40 * spriteW;
    final cy = dstT + 0.07 * spriteH;
    SmokeRenderer.draw(canvas, cx, cy, 0.9, time, seed,
        tint: const Color(0xFFB0A898), intensity: 0.85);
  }

  // ── İnşaat animasyonu: tabandan yukarı açılır ────────────────────────────────
  // Smoothstep eğri ile başlangıç + son yumuşar (linear pop yerine). Clip
  // kenarında küçük sin jitter — "tahta yerleşirken sallanıyor" hissi.
  // Üst kenarda koyu kahve overlay (3-4 px) — yeni dökülen tahta gölgesi.
  static void drawConstruction(Canvas canvas, BuildingType type,
      Offset left, Offset right, Offset front, double progress, double time) {
    final img  = _cache[type];
    final meta = kBuildingMeta[type];
    if (img == null || meta == null) return;

    final spriteW  = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH  = spriteW * img.height / img.width;
    final bottom   = (front.dy).roundToDouble();
    final top      = (front.dy - spriteH * meta.groundY).roundToDouble();

    // smoothstep(3t² - 2t³) — başta ve sonda yumuşak, ortada hızlı reveal.
    final p = progress.clamp(0.0, 1.0);
    final eased = p * p * (3 - 2 * p);
    // Sallanan tahta jitter: yalnız aktif inşaatta (0 < progress < 1).
    final jitter = (progress > 0.02 && progress < 0.98)
        ? sin(time * 8.0) * 1.2
        : 0.0;
    final clipTop = (bottom - (bottom - top) * eased + jitter).roundToDouble();

    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-9999, clipTop, 9999, bottom + 1));
    _drawSprite(canvas, img, left, right, front,
        meta.groundY, meta.groundXCenter, meta.spriteScale);
    canvas.restore();

    // Clip kenarı koyu overlay — yalnız aktif inşaatta görsel sınır.
    if (progress > 0.02 && progress < 0.98) {
      final shade = Paint()
        ..color = const Color(0x553A2410)
        ..isAntiAlias = false;
      // Sprite genişliği boyunca (ortalanmış) 3 px kalın bant.
      final dstL = front.dx - spriteW * meta.groundXCenter;
      canvas.drawRect(
        Rect.fromLTWH(dstL.roundToDouble(), clipTop, spriteW, 3),
        shade,
      );
    }
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
