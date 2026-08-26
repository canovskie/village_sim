import 'dart:math' show pi, sin;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../rendering/asset_style.dart';
import '../rendering/flame_renderer.dart';
import '../rendering/smoke_renderer.dart';
import '../rendering/water_shimmer_renderer.dart';
import '../world/season.dart';
import 'building_design.dart';
import 'building_type.dart';

class BuildingRenderer {
  // ── Sprite önbelleği ────────────────────────────────────────────────────────
  static final Map<BuildingType, ui.Image> _cache = {};
  static final Map<BuildingType, ui.Image> _winterCache = {};
  static final Map<(BuildingType, BuildingDesign), ui.Image> _designCache = {};
  static final Map<(BuildingType, BuildingDesign), ui.Image> _designThumbnails =
      {};

  /// Değirmen iki katmanlıdır: kanatsız gövde normal bina cache'inde, rotor
  /// merkez etrafında ayrı döner. Yüklenemezse eski tek-parça mill.png güvenli
  /// fallback olarak cache'te kalır.
  static ui.Image? _millRotor;

  /// Panel önizlemeleri. Ayrı, düşük çözünürlüklü kopya üretmek yerine zaten
  /// bellekte olan tam çözünürlüklü yumuşatılmış sprite'ı paylaşır. Böylece
  /// büyük katalog kartlarında 32px görsel büyütülüp bulanıklaştırılmaz; ek
  /// texture belleği ve ikinci decode/blur geçişi de oluşmaz.
  static final Map<BuildingType, ui.Image> thumbnails = {};

  static ui.Image? thumbnailFor(
    BuildingType type, [
    BuildingDesign design = BuildingDesign.original,
  ]) =>
      _designThumbnails[(type, normalizeBuildingDesign(type, design))] ??
      thumbnails[type];

  /// Katalog/portre kırpımları, normalize kaynak koordinatlarında. Yalnız
  /// gerçekten fazla şeffaf tuval taşıyan sprite'lar burada; uzun ve ince ama
  /// içeriği dolu binalar (çan kulesi/fener gibi) yapay biçimde büyütülmez.
  /// Dünya renderer'ı bu rect'leri kullanmaz, dolayısıyla sahnedeki footprint
  /// ve groundY hizaları değişmez.
  static const Map<BuildingType, Rect> _thumbnailCrops = {
    BuildingType.beehive: Rect.fromLTRB(0.03, 0.07, 0.97, 0.93),
    BuildingType.belltower: Rect.fromLTRB(0.07, 0.02, 0.93, 0.98),
    BuildingType.caravanserai: Rect.fromLTRB(0.025, 0.19, 0.975, 0.81),
    BuildingType.shrine: Rect.fromLTRB(0.06, 0.025, 0.94, 0.975),
    BuildingType.tailor: Rect.fromLTRB(0.025, 0.02, 0.975, 0.99),
    BuildingType.mill: Rect.fromLTRB(0.0, 0.0, 0.90, 1.0),
  };

  static Rect thumbnailSourceRect(BuildingType type, ui.Image image) {
    final n = _thumbnailCrops[type] ?? const Rect.fromLTRB(0, 0, 1, 1);
    return Rect.fromLTRB(
      n.left * image.width,
      n.top * image.height,
      n.right * image.width,
      n.bottom * image.height,
    );
  }

  // ── Static Paint havuzu ────────────────────────────────────────────────────
  // Sprite paint AssetStyle'dan — merkezi yumuşaklık konfigürasyonu.
  static final _pSprite = AssetStyle.paint();
  static final _pGlow1 = Paint()..isAntiAlias = true;
  static final _pGlow2 = Paint()..isAntiAlias = true;
  static final _pGlow3 = Paint()..isAntiAlias = true;

  // Tüm bina sprite'larını asenkron yükle. main.dart initState'te çağrılır.
  static Future<void> loadAll() async {
    await _loadSprite(
      BuildingType.woodenHouse,
      'assets/buildings/minihouse.png',
    );
    await _loadDesignSprite(
      BuildingType.woodenHouse,
      BuildingDesign.terracotta,
      'assets/buildings/minihouse_terracotta.png',
    );
    await _loadDesignSprite(
      BuildingType.woodenHouse,
      BuildingDesign.garden,
      'assets/buildings/minihouse_garden.png',
    );
    await _loadDesignSprite(
      BuildingType.woodenHouse,
      BuildingDesign.artisan,
      'assets/buildings/minihouse_artisan.png',
    );
    await _loadSprite(
      BuildingType.stoneHouseBlue,
      'assets/buildings/stonehouse_blue.png',
    );
    await _loadSprite(
      BuildingType.stoneHouseGreen,
      'assets/buildings/stonehouse_green.png',
    );
    await _loadSprite(BuildingType.manor, 'assets/buildings/manor.png');
    await _loadMillSprites();
    await _loadSprite(BuildingType.stable, 'assets/buildings/stable.png');
    await _loadSprite(BuildingType.well, 'assets/buildings/well.png');
    await _loadSprite(BuildingType.market, 'assets/buildings/market.png');
    await _loadSprite(BuildingType.townhall, 'assets/buildings/townhall.png');
    await _loadSprite(BuildingType.tavern, 'assets/buildings/tavern.png');
    await _loadSprite(
      BuildingType.fisherCabin,
      'assets/buildings/fishercabin.png',
    );
    await _loadSprite(BuildingType.warehouse, 'assets/buildings/warehouse.png');
    await _loadSprite(BuildingType.firepit, 'assets/buildings/firepit.png');
    await _loadSprite(
      BuildingType.lumberCamp,
      'assets/buildings/lumberjack.png',
    );
    await _loadSprite(BuildingType.mineBuilding, 'assets/buildings/mine.png');
    await _loadSprite(BuildingType.barn, 'assets/buildings/barn.png');
    await _loadSprite(
      BuildingType.floristCottage,
      'assets/buildings/floristcottage.png',
    );
    await _loadSprite(BuildingType.tailor, 'assets/buildings/tailor.png');
    await _loadSprite(
      BuildingType.chickenCoop,
      'assets/buildings/chickencoop.png',
    );
    await _loadSprite(BuildingType.lamppost, 'assets/buildings/lamppost.png');
    // beehive.png gelince procedurel skep yerine sprite çizilir; yoksa
    // _loadSprite sessizce başarısız olur, fallback devrede kalır.
    await _loadSprite(BuildingType.beehive, 'assets/buildings/beehive.png');
    // church.png gelince procedurel şapel yerine sprite çizilir; yoksa fallback.
    await _loadSprite(BuildingType.church, 'assets/buildings/church.png');
    // tent.png gelince procedurel çadır yerine sprite çizilir; yoksa fallback.
    await _loadSprite(BuildingType.tent, 'assets/buildings/tent.png');
    // Köy Meydanı & Kültür Mahallesi — PNG'leri GELDİ (eski "placeholder
    // bekleniyor" notu bayattı; prosedürel çizim artık yalnız yükleme hatası
    // fallback'i, bkz. _drawFallbackBox).
    await _loadSprite(BuildingType.fountain, 'assets/buildings/fountain.png');
    await _loadSprite(BuildingType.library, 'assets/buildings/library.png');
    await _loadSprite(BuildingType.bathhouse, 'assets/buildings/bathhouse.png');
    await _loadSprite(BuildingType.monument, 'assets/buildings/monument.png');
    // Liman & Ziyaret Mahallesi — PNG'leri GELDİ (aynı not).
    await _loadSprite(
      BuildingType.caravanserai,
      'assets/buildings/caravanserai.png',
    );
    await _loadSprite(BuildingType.shrine, 'assets/buildings/shrine.png');
    await _loadSprite(BuildingType.belltower, 'assets/buildings/belltower.png');
    await _loadWinterSprite(
      BuildingType.woodenHouse,
      'assets/buildings/minihouse_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.townhall,
      'assets/buildings/townhall_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.stoneHouseBlue,
      'assets/buildings/stonehouse_blue_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.stoneHouseGreen,
      'assets/buildings/stonehouse_green_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.manor,
      'assets/buildings/manor_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.mill,
      'assets/buildings/mill_base_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.stable,
      'assets/buildings/stable_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.tavern,
      'assets/buildings/tavern_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.church,
      'assets/buildings/church_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.library,
      'assets/buildings/library_winter.png',
    );
    // Kış varyantları — üretim/ticaret yapıları.
    await _loadWinterSprite(
      BuildingType.market,
      'assets/buildings/market_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.fisherCabin,
      'assets/buildings/fishercabin_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.warehouse,
      'assets/buildings/warehouse_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.lumberCamp,
      'assets/buildings/lumberjack_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.mineBuilding,
      'assets/buildings/mine_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.barn,
      'assets/buildings/barn_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.floristCottage,
      'assets/buildings/floristcottage_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.tailor,
      'assets/buildings/tailor_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.chickenCoop,
      'assets/buildings/chickencoop_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.bathhouse,
      'assets/buildings/bathhouse_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.caravanserai,
      'assets/buildings/caravanserai_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.shrine,
      'assets/buildings/shrine_winter.png',
    );
    await _loadWinterSprite(
      BuildingType.belltower,
      'assets/buildings/belltower_winter.png',
    );
  }

  static Future<void> _loadWinterSprite(BuildingType type, String path) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      _winterCache[type] = await AssetStyle.softenAtLoad(frame.image);
    } catch (e) {
      debugPrint('BuildingRenderer: kış sprite yüklenemedi — $path — $e');
    }
  }

  static Future<void> _loadSprite(BuildingType type, String path) async {
    try {
      final data = await rootBundle.load(path);
      final raw = data.buffer.asUint8List();

      // Tam boyut sprite — yükleme anında bir kez yumuşatılır
      final codec = await ui.instantiateImageCodec(raw);
      final frame = await codec.getNextFrame();
      final sprite = await AssetStyle.softenAtLoad(frame.image);
      _cache[type] = sprite;
      thumbnails[type] = sprite;
    } catch (e) {
      debugPrint('BuildingRenderer: $path yüklenemedi — $e');
    }
  }

  static Future<void> _loadDesignSprite(
    BuildingType type,
    BuildingDesign design,
    String path,
  ) async {
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      final sprite = await AssetStyle.softenAtLoad(frame.image);
      final key = (type, normalizeBuildingDesign(type, design));
      _designCache[key] = sprite;
      _designThumbnails[key] = sprite;
    } catch (e) {
      debugPrint('BuildingRenderer: tasarım sprite yüklenemedi — $path — $e');
    }
  }

  static Future<void> _loadMillSprites() async {
    // Önce eski birleşik sprite: panel thumbnail'i ikoniklik için kanatlı kalsın
    // ve yeni katmanlardan biri yüklenemezse oyunda eksik bina görünmesin.
    await _loadSprite(BuildingType.mill, 'assets/buildings/mill.png');
    try {
      final baseData = await rootBundle.load('assets/buildings/mill_base.png');
      final baseCodec = await ui.instantiateImageCodec(
        baseData.buffer.asUint8List(),
      );
      final baseFrame = await baseCodec.getNextFrame();
      final base = await AssetStyle.softenAtLoad(baseFrame.image);

      final rotorData = await rootBundle.load(
        'assets/buildings/mill_rotor.png',
      );
      final rotorCodec = await ui.instantiateImageCodec(
        rotorData.buffer.asUint8List(),
      );
      final rotorFrame = await rotorCodec.getNextFrame();
      final rotor = await AssetStyle.softenAtLoad(rotorFrame.image);

      // İki asset de başarıyla geldikten sonra atomik değiştir: yarım yüklenmiş
      // değirmen (gövde var/kanat yok) üretme.
      _cache[BuildingType.mill] = base;
      _millRotor = rotor;
    } catch (e) {
      _millRotor = null;
      debugPrint('BuildingRenderer: animasyonlu değirmen yüklenemedi — $e');
    }
  }

  // ── Ana çizim ───────────────────────────────────────────────────────────────
  static void draw(
    Canvas canvas,
    BuildingType type,
    Offset back,
    Offset left,
    Offset right,
    Offset front, {
    double time = 0,
    int seed = 0,
    double dayLight = 1.0,
    double rainIntensity = 0.0,
    bool isActive = false,
    bool perfMode = false,
    double fireFuel = 1.0,
    double millRotorAngle = 0.0,
    double deliveryPulse = 0.0,
    int deliveryTally = 0,
    Season season = Season.spring,
    BuildingDesign design = BuildingDesign.original,

    /// Pencere/fener ışığının kısılma çarpanı (bkz. [BuildingEntity.windowGlow]).
    /// Konutta sakinler uyudukça 0'a iner → evin camı söner. Konut olmayan
    /// binalar 1.0 geçer, davranışları değişmez.
    double windowGlow = 1.0,
  }) {
    final normalizedDesign = normalizeBuildingDesign(type, design);
    final designSprite = normalizedDesign == BuildingDesign.original
        ? null
        : _designCache[(type, normalizedDesign)];
    final img =
        designSprite ??
        (season == Season.winter ? _winterCache[type] : null) ??
        _cache[type];
    final meta = kBuildingMeta[type];
    // Genel güvenlik fallback'i: PNG yüklenememiş / bilinmeyen bina → basit
    // izometrik kutu placeholder (footprint'e oturur, türe göre renk + harf).
    // Tüm bina PNG'leri assets/buildings/ altında mevcut olduğundan bu dal
    // pratikte yalnız yükleme hatasında devreye girer.
    if (img == null) {
      _drawFallbackBox(canvas, type, back, left, right, front, time);
      return;
    }
    if (meta == null) return;

    // PerfMode: ambient glow ve light points atlanır — her bina × her ışık
    // noktası × 3 drawCircle inanılmaz pahalı (5 ev = 15+ ışık × 3 = 45/frame).
    if (!perfMode) {
      _drawAmbientGlow(
        canvas,
        type,
        img,
        left,
        right,
        front,
        meta,
        dayLight,
        time,
        seed,
        windowGlow,
      );
    }
    _drawSprite(
      canvas,
      img,
      left,
      right,
      front,
      meta.groundY,
      meta.groundXCenter,
      meta.spriteScale,
    );
    if (type == BuildingType.mill && _millRotor != null) {
      _drawMillRotor(
        canvas,
        img,
        _millRotor!,
        left,
        right,
        front,
        meta,
        millRotorAngle,
      );
    }
    // Su parlaması — şadırvan havuzu / hamam kanalı sprite üstüne işlenir.
    if (!perfMode) {
      _drawWaterShimmer(
        canvas,
        type,
        img,
        left,
        right,
        front,
        meta,
        dayLight,
        time,
        seed,
      );
    }
    if (!perfMode) {
      _drawLights(
        canvas,
        type,
        img,
        left,
        right,
        front,
        meta,
        dayLight,
        time,
        seed,
        windowGlow,
      );
    }

    // PerfMode: smoke partikül loop'ları atlanır (her chimney × N partikül).
    if (!perfMode) {
      final chimneys = kBuildingChimneys[type];
      if (chimneys != null && chimneys.isNotEmpty) {
        _drawChimneySmoke(
          canvas,
          img,
          left,
          right,
          front,
          meta,
          time,
          seed,
          chimneys,
          dayLight,
          rainIntensity: rainIntensity,
        );
      }

      // Değirmen kendi ÇOK hafif un tozunu alır (aşağıda); jenerik tepe dumanı
      // ondan çıkarılır — iki tepe efekti kalabalık olmasın (baca zaten ambient).
      if (isActive && type != BuildingType.mill) {
        _drawActiveSmoke(canvas, img, left, right, front, meta, time, seed);
      }
      if (isActive && type == BuildingType.mill) {
        _drawMillFlourDust(canvas, img, left, right, front, meta, time, seed);
      }
      if (isActive || deliveryPulse > 0 || deliveryTally > 0) {
        _drawWorkYard(
          canvas,
          type,
          left,
          right,
          front,
          time,
          seed,
          isActive: isActive,
          deliveryPulse: deliveryPulse,
          deliveryTally: deliveryTally,
        );
      }
    }

    // Firepit alev — perf mode'da bile çizilir (köy odak noktası, atlamayalım).
    // Yakıt bittiyse (fireFuel ~0) ateş söner: alev çizilmez.
    if (type == BuildingType.firepit &&
        rainIntensity < 0.30 &&
        fireFuel > 0.001) {
      final cx = (back.dx + front.dx) * 0.5;
      // Footprint y-merkezi alt zemini → biraz yukarı yer ayarı.
      final cy = (left.dy + right.dy) * 0.5 + 2;
      // Tile genişliği ile orantılı alev ölçeği.
      final tileW = (right.dx - left.dx).abs();
      final s = tileW / 22.0;
      // Yağmur azalırken alev yumuşar; yakıt son 1/3'te kısılır (sönüş telgrafı).
      final rainFactor = (1.0 - rainIntensity / 0.30).clamp(0.0, 1.0);
      final fuelFactor = (fireFuel * 3.0).clamp(0.0, 1.0);
      final intensity = rainFactor < fuelFactor ? rainFactor : fuelFactor;
      FlameRenderer.draw(canvas, cx, cy, s, time, seed, intensity: intensity);
    }
  }

  /// Üretimin binaya değdiği avlu katmanı. Sprite'ı değiştirmez; kapının
  /// önünde biriken 1-3 somut nesne ve kısa teslim oturuşu üretimin dünyada
  /// iz bırakmasını sağlar.
  static void _drawWorkYard(
    Canvas canvas,
    BuildingType type,
    Offset left,
    Offset right,
    Offset front,
    double time,
    int seed, {
    required bool isActive,
    required double deliveryPulse,
    required int deliveryTally,
  }) {
    final tileW = (right.dx - left.dx).abs();
    final p = (1.0 - deliveryPulse).clamp(0.0, 1.0);
    final settle = deliveryPulse > 0
        ? sin(p * pi * 3) * deliveryPulse * 2.2
        : 0.0;
    final cx = front.dx + tileW * 0.12;
    final cy = front.dy - 2 + settle;
    final outline = Paint()
      ..color = const Color(0xFF2A1A10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..isAntiAlias = false;
    final fill = Paint()..isAntiAlias = false;

    void crate(double x, double y, Color color) {
      fill.color = color;
      final r = Rect.fromLTWH(x - 5, y - 5, 10, 6);
      canvas.drawRect(r, fill);
      canvas.drawRect(r, outline);
      canvas.drawLine(Offset(x, y - 5), Offset(x, y + 1), outline);
    }

    final count = deliveryTally.clamp(0, 3);
    switch (type) {
      case BuildingType.warehouse:
        for (var i = 0; i < count; i++) {
          crate(
            cx + (i - 1) * 8.0,
            cy - (i.isOdd ? 3 : 0),
            const Color(0xFF9B6A38),
          );
        }
      case BuildingType.lumberCamp:
        if (isActive) {
          fill.color = const Color(0xFF875128);
          for (var i = 0; i < 3; i++) {
            final y = cy - i * 3.0;
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(cx - 11 + i * 2, y - 3, 22, 5),
                const Radius.circular(2),
              ),
              fill,
            );
          }
        }
      case BuildingType.mineBuilding:
        if (isActive) {
          fill.color = const Color(0xFF8F8A82);
          for (var i = 0; i < 5; i++) {
            final j = ((seed + i * 7) % 5).toDouble();
            canvas.drawCircle(Offset(cx - 8 + i * 4, cy - j), 2.2, fill);
          }
        }
      case BuildingType.fisherCabin:
        if (isActive || count > 0) {
          fill.color = const Color(0xFF8A673C);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy - 2), width: 16, height: 8),
            fill,
          );
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy - 2), width: 16, height: 8),
            outline,
          );
        }
      case BuildingType.barn:
        if (isActive || count > 0) {
          fill.color = const Color(0xFF9B835D);
          canvas.drawRect(Rect.fromLTWH(cx - 5, cy - 7, 10, 8), fill);
          canvas.drawRect(Rect.fromLTWH(cx - 5, cy - 7, 10, 8), outline);
        }
      case BuildingType.firepit:
        if (isActive || deliveryPulse > 0) {
          fill.color = const Color(0xFF3C3430);
          canvas.drawOval(
            Rect.fromCenter(center: Offset(cx, cy - 3), width: 16, height: 7),
            fill,
          );
          final steam = (sin(time * 3.2 + seed) + 1) * 0.5;
          fill.color = Color.fromARGB((80 + steam * 70).round(), 220, 214, 195);
          canvas.drawCircle(Offset(cx - 2, cy - 12 - steam * 3), 2.0, fill);
        }
      case BuildingType.mill:
        if (isActive) {
          crate(cx - 5, cy, const Color(0xFFC9B47D));
          crate(cx + 6, cy - 2, const Color(0xFFD8C897));
        }
      default:
        break;
    }
  }

  /// Ayrı rotor sprite'ını gövdenin ön yüzündeki mile bağlar. Normalize pivot
  /// değerleri üretilen mill_base.png üstünde kalibre edilmiştir; rotor asseti
  /// matematiksel merkezlidir, bu yüzden rotate sırasında yalpalamaz.
  static void _drawMillRotor(
    Canvas canvas,
    ui.Image base,
    ui.Image rotor,
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double angle,
  ) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * base.height / base.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;

    final pivot = Offset(dstL + spriteW * 0.421, dstT + spriteH * 0.407);
    final rotorW = spriteW * 0.74;
    final rotorH = rotorW * rotor.height / rotor.width;
    final dst = Rect.fromCenter(center: pivot, width: rotorW, height: rotorH);

    canvas.save();
    canvas.translate(pivot.dx, pivot.dy);
    canvas.rotate(angle);
    canvas.translate(-pivot.dx, -pivot.dy);
    canvas.drawImageRect(
      rotor,
      Rect.fromLTWH(0, 0, rotor.width.toDouble(), rotor.height.toDouble()),
      dst,
      _pSprite,
    );
    canvas.restore();
  }

  // ── Genel kutu fallback'i (prosedürel, SON ÇARE) ─────────────────────────
  // PNG'si yüklenememiş / bilinmeyen bina için son çare placeholder: footprint'e
  // oturan basit izometrik kutu (taban diamond → yukarı ekstrüzyon: 2 yan duvar +
  // üst yüz) + türe göre renk + ortada baş harf. Normalde tüm bina PNG'leri
  // mevcut olduğundan yalnız yükleme hatasında çizilir.
  static void _drawFallbackBox(
    Canvas canvas,
    BuildingType type,
    Offset back,
    Offset left,
    Offset right,
    Offset front,
    double time,
  ) {
    // Türe göre renk + etiket.
    final (Color roof, Color wall, String tag) = switch (type) {
      BuildingType.fountain => (
        const Color(0xFF5B86A6),
        const Color(0xFF8FB3C9),
        'Ş',
      ),
      BuildingType.library => (
        const Color(0xFF8A5A33),
        const Color(0xFFBE9468),
        'K',
      ),
      BuildingType.bathhouse => (
        const Color(0xFF3F8C86),
        const Color(0xFF77B6B0),
        'H',
      ),
      BuildingType.monument => (
        const Color(0xFF8C8470),
        const Color(0xFFBFB8A6),
        'A',
      ),
      BuildingType.caravanserai => (
        const Color(0xFF9C7B4A),
        const Color(0xFFC9A877),
        'H',
      ),
      BuildingType.shrine => (
        const Color(0xFF3F8C86),
        const Color(0xFF77B6B0),
        'T',
      ),
      BuildingType.belltower => (
        const Color(0xFF8C8470),
        const Color(0xFFBFB8A6),
        'Ç',
      ),
      BuildingType.tailor => (
        const Color(0xFF8A5A33),
        const Color(0xFFD2B48C),
        'T',
      ),
      _ => (const Color(0xFF777777), const Color(0xFFAAAAAA), '?'),
    };
    final tileW = (right.dx - left.dx).abs();
    final h = tileW * 0.55; // duvar yüksekliği (footprint ile orantılı)
    Offset up(Offset o) => Offset(o.dx, o.dy - h);

    // Zemin gölgesi (footprint diamond).
    final shadow = Path()
      ..moveTo(back.dx, back.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(left.dx, left.dy)
      ..close();
    canvas.drawPath(
      shadow,
      Paint()
        ..color = const Color(0x33000000)
        ..isAntiAlias = true,
    );

    final fill = Paint()..isAntiAlias = true;
    // Sol-ön duvar (left→front yüzü, gölgeli).
    fill.color = _shade(wall, 0.80);
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(front.dx, front.dy)
        ..lineTo(up(front).dx, up(front).dy)
        ..lineTo(up(left).dx, up(left).dy)
        ..close(),
      fill,
    );
    // Sağ-ön duvar (front→right yüzü, aydınlık).
    fill.color = wall;
    canvas.drawPath(
      Path()
        ..moveTo(front.dx, front.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(up(right).dx, up(right).dy)
        ..lineTo(up(front).dx, up(front).dy)
        ..close(),
      fill,
    );
    // Üst yüz (çatı diamond).
    fill.color = roof;
    final top = Path()
      ..moveTo(up(back).dx, up(back).dy)
      ..lineTo(up(right).dx, up(right).dy)
      ..lineTo(up(front).dx, up(front).dy)
      ..lineTo(up(left).dx, up(left).dy)
      ..close();
    canvas.drawPath(top, fill);
    // Üst kenar hairline.
    canvas.drawPath(
      top,
      Paint()
        ..color = _shade(roof, 1.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );

    // Baş harf — üst yüz merkezinde.
    final cx = (up(back).dx + up(front).dx) / 2;
    final cy = (up(left).dy + up(right).dy) / 2;
    final tp = TextPainter(
      text: TextSpan(
        text: tag,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.92),
          fontSize: h * 0.5,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));
    if (time < 0) {} // unused
  }

  /// Rengi [k] kadar aydınlat/karart (1.0 = aynı).
  static Color _shade(Color c, double k) => Color.fromARGB(
    255,
    (c.r * 255 * k).clamp(0, 255).round(),
    (c.g * 255 * k).clamp(0, 255).round(),
    (c.b * 255 * k).clamp(0, 255).round(),
  );

  // ── Baca dumanı ──────────────────────────────────────────────────────────────
  // Her baca için density'ye orantılı sayıda partikül; sin sallanması + yükselme.
  // Gece alpha boost — kontrast yüksek.
  static void _drawChimneySmoke(
    Canvas canvas,
    ui.Image img,
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double time,
    int seed,
    List<BuildingChimney> chimneys,
    double dayLight, {
    double rainIntensity = 0.0,
  }) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;

    // Gündüz 0.55 → Gece 0.90 alpha çarpanı
    final alphaScale = 0.55 + (1.0 - dayLight) * 0.35;
    // Yağmurda duman yoğunlaşır + gri-mavi tona kayar (ıslak buhar hissi).
    final wet = rainIntensity.clamp(0.0, 1.0);
    final tintR = (200 - wet * 40).round().clamp(80, 220);
    final tintG = (192 - wet * 32).round().clamp(80, 220);
    final tintB = (178 + wet * 16).round().clamp(80, 220);
    final tint = Color.fromARGB(255, tintR, tintG, tintB);

    for (int c = 0; c < chimneys.length; c++) {
      final cm = chimneys[c];
      final cx = dstL + cm.nx * spriteW;
      final cy = dstT + cm.ny * spriteH;
      // Sprite scale chimney density'siyle orantılı (firepit 2.0 → büyük
      // sütun, küçük ev 0.6 → ince izgar). Yağmurda hafif boost (+%20).
      final dScale = (0.6 + cm.density * 0.45) * (1.0 + wet * 0.20);
      // Intensity: gündüz/gece + chimney rate.
      final intensity = (alphaScale * (0.7 + cm.rate * 0.30)).clamp(0.0, 1.0);
      SmokeRenderer.draw(
        canvas,
        cx,
        cy,
        dScale,
        time,
        seed * 31 + c,
        tint: tint,
        intensity: intensity,
      );
    }
  }

  // ── Aktif maden animasyonu: baca dumanı (sprite tabanlı) ────────────────────
  static void _drawActiveSmoke(
    Canvas canvas,
    ui.Image img,
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double time,
    int seed,
  ) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;
    // Maden bacası — orta-gri ton, orta yoğunluk.
    final cx = dstL + 0.40 * spriteW;
    final cy = dstT + 0.07 * spriteH;
    SmokeRenderer.draw(
      canvas,
      cx,
      cy,
      0.9,
      time,
      seed,
      tint: const Color(0xFFB0A898),
      intensity: 0.85,
    );
  }

  // Değirmen öğütürken dipteki huni/değirmen taşı hizasından yükselen ÇOK hafif
  // un tozu. Yelkene dokunmaz; sadece "çalışıyor" hissini diegetik verir.
  // Kasıtlı olarak sönük: tepe alpha ~0.10, birkaç zerre.
  static void _drawMillFlourDust(
    Canvas canvas,
    ui.Image img,
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double time,
    int seed,
  ) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;
    // Huni/taş sağ-alt bölgede.
    final bx = dstL + 0.66 * spriteW;
    final by = dstT + 0.80 * spriteH;
    final paint = Paint()..isAntiAlias = true;
    const n = 4;
    for (int i = 0; i < n; i++) {
      // Deterministik per-zerre ofset — Random allocation'sız (hot-path).
      final off = ((seed * 2654435761 + i * 40503) & 0xFFFF) / 65536.0;
      final jx = (((seed ^ (i * 26699)) & 0xFF) / 255.0 - 0.5) * spriteW * 0.05;
      final phase = (time * 0.28 + off) % 1.0; // 0(dip) → 1(yukarı)
      final px = bx + jx + sin(time * 0.7 + i * 2.1) * spriteW * 0.015;
      final py = by - phase * spriteH * 0.11;
      // Parabolik sönme (0 uçlarda, ~0.10 ortada) — pi'siz.
      final a = 4.0 * phase * (1.0 - phase) * 0.10;
      if (a <= 0.008) continue;
      final ai = (a * 255).round().clamp(0, 255);
      paint.color = Color((ai << 24) | 0x00F1EBDC); // soluk un beji
      canvas.drawCircle(
        Offset(px, py),
        spriteW * (0.009 + 0.010 * phase),
        paint,
      );
    }
  }

  // ── İnşaat animasyonu: tabandan yukarı açılır ────────────────────────────────
  // Smoothstep eğri ile başlangıç + son yumuşar (linear pop yerine). Clip
  // kenarında küçük sin jitter — "tahta yerleşirken sallanıyor" hissi.
  // Üst kenarda koyu kahve overlay (3-4 px) — yeni dökülen tahta gölgesi.
  static void drawConstruction(
    Canvas canvas,
    BuildingType type,
    Offset left,
    Offset right,
    Offset front,
    double progress,
    double time,
  ) {
    final img = _cache[type];
    final meta = kBuildingMeta[type];
    if (img == null || meta == null) return;

    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final bottom = front.dy.roundToDouble();
    final top = (front.dy - spriteH * meta.groundY).roundToDouble();

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
    _drawSprite(
      canvas,
      img,
      left,
      right,
      front,
      meta.groundY,
      meta.groundXCenter,
      meta.spriteScale,
    );
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
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double dayLight,
    double time,
    int seed,
    double windowGlow,
  ) {
    final lights = kBuildingLights[type];
    if (lights == null || lights.isEmpty) return;

    final nightness = (1.0 - dayLight) * windowGlow;
    if (nightness < 0.02) return;

    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;

    for (int i = 0; i < lights.length; i++) {
      final lt = lights[i];
      if (lt.kind != LightKind.lantern) continue;

      final lx = dstL + lt.nx * spriteW;
      final ly = dstT + lt.ny * spriteH;
      final flicker = sin(time * 3.7 + seed * 0.17 + i * 2.1) * 0.15 + 0.85;
      final pos = Offset(lx, ly);

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

  // ── Su parlaması ────────────────────────────────────────────────────────────
  // Sprite dst rect'inden su bölgelerini dünya koordinatına çevirir; her bölgeye
  // WaterShimmerRenderer ile animasyonlu ışıltı işler.
  static void _drawWaterShimmer(
    Canvas canvas,
    BuildingType type,
    ui.Image img,
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double dayLight,
    double time,
    int seed,
  ) {
    final patches = kBuildingWater[type];
    if (patches == null || patches.isEmpty) return;

    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;

    for (final w in patches) {
      final cx = dstL + w.nx * spriteW;
      final cy = dstT + w.ny * spriteH;
      WaterShimmerRenderer.draw(
        canvas,
        cx,
        cy,
        w.hw * spriteW,
        w.hh * spriteH,
        time,
        seed,
        dayLight: dayLight,
        intensity: w.intensity,
      );
    }
  }

  // ── Gece ışık efektleri ────────────────────────────────────────────────────
  // Sprite'ın dst rect'ini yeniden hesaplayarak ışık noktalarını dünya
  // koordinatına dönüştürür; katmanlı dairelerle yumuşak parlama çizer.
  static void _drawLights(
    Canvas canvas,
    BuildingType type,
    ui.Image img,
    Offset left,
    Offset right,
    Offset front,
    BuildingMeta meta,
    double dayLight,
    double time,
    int seed,
    double windowGlow,
  ) {
    final lights = kBuildingLights[type];
    if (lights == null || lights.isEmpty) return;

    final nightness = (1.0 - dayLight) * windowGlow;
    if (nightness < 0.02) return; // tam gündüz — ışık yok

    // Sprite rect (buildingMeta bağımlı — _drawSprite ile aynı hesap)
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL = front.dx - spriteW * meta.groundXCenter;
    final dstT = front.dy - spriteH * meta.groundY;

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
        radius = 6.0;
        r = 255;
        g = 150;
        b = 30;
      } else {
        // Pencere — hafif nabız
        final pulse = sin(time * 0.8 + seed * 0.13 + i * 1.7) * 0.05 + 0.95;
        brightness = pulse;
        radius = 3.5;
        r = 255;
        g = 210;
        b = 90;
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
    Canvas canvas,
    ui.Image img,
    Offset left,
    Offset right,
    Offset front,
    double groundY,
    double groundXCenter,
    double spriteScale,
  ) {
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
      0,
      0,
      img.width.toDouble(),
      img.height.toDouble(),
    );

    canvas.drawImageRect(img, src, dst, _pSprite);
  }
}
