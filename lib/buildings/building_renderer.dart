import 'dart:math' show sin;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'building_type.dart';
import '../rendering/asset_style.dart';
import '../rendering/flame_renderer.dart';
import '../rendering/smoke_renderer.dart';
import '../rendering/water_shimmer_renderer.dart';

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
    await _loadSprite(BuildingType.stoneHouseBlue,  'assets/buildings/stonehouse_blue.png');
    await _loadSprite(BuildingType.stoneHouseGreen, 'assets/buildings/stonehouse_green.png');
    await _loadSprite(BuildingType.manor,           'assets/buildings/manor.png');
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
    await _loadSprite(BuildingType.barn,         'assets/buildings/barn.png');
    await _loadSprite(BuildingType.floristCottage, 'assets/buildings/floristcottage.png');
    await _loadSprite(BuildingType.chickenCoop,    'assets/buildings/chickencoop.png');
    await _loadSprite(BuildingType.lamppost,       'assets/buildings/lamppost.png');
    // beehive.png gelince procedurel skep yerine sprite çizilir; yoksa
    // _loadSprite sessizce başarısız olur, fallback devrede kalır.
    await _loadSprite(BuildingType.beehive,        'assets/buildings/beehive.png');
    // church.png gelince procedurel şapel yerine sprite çizilir; yoksa fallback.
    await _loadSprite(BuildingType.church,         'assets/buildings/church.png');
    // tent.png gelince procedurel çadır yerine sprite çizilir; yoksa fallback.
    await _loadSprite(BuildingType.tent,           'assets/buildings/tent.png');
    // Köy Meydanı & Kültür Mahallesi — PNG gelene kadar prosedürel placeholder
    // (_drawCivicPlaceholder). Dosya yoksa _loadSprite sessizce başarısız olur.
    await _loadSprite(BuildingType.fountain,       'assets/buildings/fountain.png');
    await _loadSprite(BuildingType.library,        'assets/buildings/library.png');
    await _loadSprite(BuildingType.bathhouse,      'assets/buildings/bathhouse.png');
    await _loadSprite(BuildingType.monument,       'assets/buildings/monument.png');
    // Liman & Ziyaret Mahallesi — PNG gelene kadar prosedürel placeholder.
    await _loadSprite(BuildingType.dock,           'assets/buildings/dock.png');
    await _loadSprite(BuildingType.caravanserai,   'assets/buildings/caravanserai.png');
    await _loadSprite(BuildingType.shrine,         'assets/buildings/shrine.png');
    await _loadSprite(BuildingType.belltower,      'assets/buildings/belltower.png');
  }

  /// PNG'si henüz gelmemiş kültür mahallesi binaları için prosedürel kutu
  /// placeholder çizilir (footprint'e oturur, türe göre renk + harf).
  static const Set<BuildingType> _civicPlaceholders = {
    BuildingType.fountain,
    BuildingType.library,
    BuildingType.bathhouse,
    BuildingType.monument,
    BuildingType.dock,
    BuildingType.caravanserai,
    BuildingType.shrine,
    BuildingType.belltower,
  };

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
       double rainIntensity = 0.0, bool isActive = false,
       bool perfMode = false, double fireFuel = 1.0}) {
    // Lamppost — PNG yüklendiyse normal asset yolu; yoksa procedurel fallback.
    if (type == BuildingType.lamppost && !_cache.containsKey(type)) {
      _drawLamppost(canvas, back, left, right, front, time, seed, dayLight);
      return;
    }
    // Çiçekçi Kulübesi — PNG asset gelene kadar procedurel placeholder çizilir
    // (küçük ahşap kulübe + diamond planter). PNG yüklendiğinde _cache hit ile
    // bu dal otomatik atlanır.
    if (type == BuildingType.floristCottage && !_cache.containsKey(type)) {
      _drawFlowerGarden(canvas, back, left, right, front, time, seed);
      return;
    }
    // Arı Kovanı — PNG gelene kadar procedurel hasır skep fallback.
    if (type == BuildingType.beehive && !_cache.containsKey(type)) {
      _drawBeehive(canvas, back, left, right, front, time, seed);
      return;
    }
    // Kilise — church.png gelene kadar procedurel taş şapel + çan kulesi + haç.
    if (type == BuildingType.church && !_cache.containsKey(type)) {
      _drawChurch(canvas, back, left, right, front, time, seed);
      return;
    }
    // Çadır — tent.png gelene kadar procedurel A-frame bez çadır.
    if (type == BuildingType.tent && !_cache.containsKey(type)) {
      _drawTent(canvas, back, left, right, front, time, seed);
      return;
    }
    // Kültür mahallesi — PNG gelene kadar prosedürel kutu placeholder.
    if (_civicPlaceholders.contains(type) && !_cache.containsKey(type)) {
      _drawCivicPlaceholder(canvas, type, back, left, right, front, time);
      return;
    }

    final img  = _cache[type];
    final meta = kBuildingMeta[type];
    if (img == null || meta == null) return;

    // PerfMode: ambient glow ve light points atlanır — her bina × her ışık
    // noktası × 3 drawCircle inanılmaz pahalı (5 ev = 15+ ışık × 3 = 45/frame).
    if (!perfMode) {
      _drawAmbientGlow(canvas, type, img, left, right, front, meta, dayLight, time, seed);
    }
    _drawSprite(canvas, img, left, right, front, meta.groundY, meta.groundXCenter, meta.spriteScale);
    // Su parlaması — şadırvan havuzu / hamam kanalı sprite üstüne işlenir.
    if (!perfMode) {
      _drawWaterShimmer(canvas, type, img, left, right, front, meta, dayLight, time, seed);
    }
    if (!perfMode) {
      _drawLights(canvas, type, img, left, right, front, meta, dayLight, time, seed);
    }

    // PerfMode: smoke partikül loop'ları atlanır (her chimney × N partikül).
    if (!perfMode) {
      final chimneys = kBuildingChimneys[type];
      if (chimneys != null && chimneys.isNotEmpty) {
        _drawChimneySmoke(canvas, img, left, right, front, meta, time, seed,
            chimneys, dayLight, rainIntensity: rainIntensity);
      }

      // Değirmen kendi ÇOK hafif un tozunu alır (aşağıda); jenerik tepe dumanı
      // ondan çıkarılır — iki tepe efekti kalabalık olmasın (baca zaten ambient).
      if (isActive && type != BuildingType.mill) {
        _drawActiveSmoke(canvas, img, left, right, front, meta, time, seed);
      }
      if (isActive && type == BuildingType.mill) {
        _drawMillFlourDust(canvas, img, left, right, front, meta, time, seed);
      }
    }

    // Firepit alev — perf mode'da bile çizilir (köy odak noktası, atlamayalım).
    // Yakıt bittiyse (fireFuel ~0) ateş söner: alev çizilmez.
    if (type == BuildingType.firepit && rainIntensity < 0.30 && fireFuel > 0.001) {
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

  // ── Sokak feneri (procedurel) ───────────────────────────────────────────────
  // Asset yok, doğrudan piksel çizimi. Footprint merkezinden yükselen ahşap
  // direk + üstte demir kafesli lamba. Gece içeriden sıcak alev parlar
  // (lighting pass ayrıca büyük halo ekler).
  static final _pLampPostBase = Paint()..color = const Color(0xFF7A6E60)..isAntiAlias = false;
  static final _pLampPost     = Paint()..color = const Color(0xFF5A3E20)..isAntiAlias = false;
  static final _pLampCage     = Paint()..color = const Color(0xFF2A1A10)..isAntiAlias = false;

  // ── Çiçek bahçesi (procedurel) ──────────────────────────────────────────────
  // Küçük ahşap planter "kutu" — diamond izometri çerçevesinde. Üstünde
  // toprak + birkaç renkli çiçek noktası. Asıl çiçek demetleri scene'in
  // spawn ettiği gerçek DecorEntity'lerle çevreye serpilir.
  static final _pPlanterWood   = Paint()..color = const Color(0xFF7A5A32)..isAntiAlias = true;
  static final _pPlanterShade  = Paint()..color = const Color(0xFF5A3E20)..isAntiAlias = true;
  static final _pPlanterSoil   = Paint()..color = const Color(0xFF4A3018)..isAntiAlias = true;
  static final _pPlanterMoss   = Paint()..color = const Color(0xFF6B8A4A)..isAntiAlias = true;

  static void _drawFlowerGarden(Canvas canvas,
      Offset back, Offset left, Offset right, Offset front,
      double time, int seed) {
    // Izometrik diamond — 4 köşesi tile sınırına yakın küçültülmüş
    final cx = (back.dx + front.dx) / 2;
    final cy = (back.dy + front.dy) / 2;
    final tileW = (right.dx - left.dx).abs();
    final s = tileW / 64.0;
    // Planter boyut — tile'ın iç ~%65'i, yüksekliği isometric yarısı + kalınlık
    final halfW = tileW * 0.32;
    final halfH = halfW * 0.5; // 2:1 iso
    final depth = 4.0 * s; // ahşap kenar yüksekliği

    // Üst diamond (planter ağzı — toprak)
    final topPath = Path()
      ..moveTo(cx, cy - halfH)
      ..lineTo(cx + halfW, cy)
      ..lineTo(cx, cy + halfH)
      ..lineTo(cx - halfW, cy)
      ..close();
    // Alt diamond (depth ofsetli — gölgeli kenar)
    final botPath = Path()
      ..moveTo(cx, cy - halfH + depth)
      ..lineTo(cx + halfW, cy + depth)
      ..lineTo(cx, cy + halfH + depth)
      ..lineTo(cx - halfW, cy + depth)
      ..close();

    // 1) Ahşap "yan duvarlar" — front-left ve front-right yamuk
    final wallL = Path()
      ..moveTo(cx - halfW, cy)
      ..lineTo(cx, cy + halfH)
      ..lineTo(cx, cy + halfH + depth)
      ..lineTo(cx - halfW, cy + depth)
      ..close();
    final wallR = Path()
      ..moveTo(cx, cy + halfH)
      ..lineTo(cx + halfW, cy)
      ..lineTo(cx + halfW, cy + depth)
      ..lineTo(cx, cy + halfH + depth)
      ..close();
    canvas.drawPath(wallL, _pPlanterShade);
    canvas.drawPath(wallR, _pPlanterWood);

    // 2) Üst toprak (planter içi)
    canvas.drawPath(topPath, _pPlanterSoil);
    // Toprak üstüne hafif yeşil tüy (moss/grass)
    final mossPath = Path()
      ..moveTo(cx, cy - halfH * 0.7)
      ..lineTo(cx + halfW * 0.7, cy)
      ..lineTo(cx, cy + halfH * 0.7)
      ..lineTo(cx - halfW * 0.7, cy)
      ..close();
    canvas.drawPath(mossPath, _pPlanterMoss);

    // 3) Üst çerçeve hairline — diamond outline (ahşap üst kenar)
    final framePaint = Paint()
      ..color = const Color(0xFF8A6840)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 * s
      ..isAntiAlias = true;
    canvas.drawPath(topPath, framePaint);

    // 4) Birkaç çiçek noktası — seed bazlı renk varyantı
    final rng = (seed * 9973) & 0xFFFF;
    final colors = const [
      Color(0xFFD94833), // gelincik kırmızı
      Color(0xFFE6B54A), // buttercup sarı
      Color(0xFFB39AC9), // lavanta mor
      Color(0xFFF0E6D2), // papatya cream
    ];
    final dotR = 1.8 * s;
    // 4 simetrik konum + offset
    final dots = <Offset>[
      Offset(cx, cy - halfH * 0.35),
      Offset(cx + halfW * 0.35, cy),
      Offset(cx, cy + halfH * 0.35),
      Offset(cx - halfW * 0.35, cy),
    ];
    for (int i = 0; i < dots.length; i++) {
      final col = colors[(rng + i) % colors.length];
      canvas.drawCircle(dots[i], dotR, Paint()..color = col..isAntiAlias = true);
      // Hafif yaprak — küçük yeşil nokta yanda
      canvas.drawCircle(
          dots[i] + Offset(-2 * s, 1 * s),
          1.2 * s,
          Paint()..color = const Color(0xFF6B8A4A)..isAntiAlias = true);
    }
    // Suppress unused warnings
    if (botPath.getBounds().width < 0) canvas.drawPath(botPath, _pPlanterShade);
    if (time < 0) {} // tick unused
  }

  // ── Arı kovanı (procedurel hasır skep) ──────────────────────────────────────
  // Klasik örgü saman kovanı: tabandan tepeye daralan yatay bantlar (ellips
  // dilimleri), önde giriş deliği + iniş tahtası. PNG gelince _cache hit ile
  // bu dal atlanır.
  static final _pSkepBand  = Paint()..isAntiAlias = true;
  static final _pSkepShade = Paint()..color = const Color(0x33000000)..isAntiAlias = true;

  static void _drawBeehive(Canvas canvas,
      Offset back, Offset left, Offset right, Offset front,
      double time, int seed) {
    final cx = (back.dx + front.dx) / 2;
    final cyTile = (left.dy + right.dy) / 2;
    final tileW = (right.dx - left.dx).abs();
    final s = tileW / 64.0;

    // Zemin gölgesi
    final groundY = cyTile + 3 * s;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, groundY), width: 22 * s, height: 8 * s),
      _pSkepShade);

    // Skep gövdesi — alttan üste daralan bantlar. Renk koyu samandan açığa.
    const bands = 6;
    final baseHalfW = 11.0 * s;
    final bandH = 4.2 * s;
    final bodyBottom = groundY - 1 * s;
    for (int i = 0; i < bands; i++) {
      // 0 = en alt (geniş), bands-1 = tepe (dar)
      final t = i / (bands - 1);
      final halfW = baseHalfW * (1.0 - t * 0.62);
      final cyBand = bodyBottom - i * bandH;
      // Üstteki bant biraz daha açık → yumuşak hacim.
      final lum = (0.78 + t * 0.18).clamp(0.0, 1.0);
      _pSkepBand.color = Color.fromARGB(
        255,
        (200 * lum).round(),
        (158 * lum).round(),
        (86 * lum).round(),
      );
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cyBand), width: halfW * 2, height: bandH * 1.7),
        _pSkepBand);
      // Bant altı ince gölge çizgisi (örgü ayrımı)
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(cx, cyBand + bandH * 0.55),
            width: halfW * 1.9,
            height: bandH * 0.5),
        _pSkepShade);
    }

    // Tepe topuzu
    final topY = bodyBottom - (bands - 1) * bandH - bandH * 0.4;
    _pSkepBand.color = const Color(0xFFB89653);
    canvas.drawCircle(Offset(cx, topY), 2.2 * s, _pSkepBand);

    // Giriş deliği (ön-alt) + iniş tahtası
    final holeY = bodyBottom - bandH * 0.7;
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(cx, holeY), width: 5 * s, height: 3.2 * s),
      Paint()..color = const Color(0xFF3A2410)..isAntiAlias = true);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(cx, holeY + 2.4 * s), width: 7 * s, height: 1.4 * s),
      Paint()..color = const Color(0xFF8A6A3A)..isAntiAlias = true);

    if (time < 0 || seed < 0) {} // unused tick/seed
  }

  // ── Kilise (procedurel taş şapel) ───────────────────────────────────────────
  // church.png gelene kadar gösterilen placeholder: taş gövde + üçgen çatı +
  // solda çan kulesi (sivri külah + haç) + gül penceresi + kemerli kapı.
  // PNG yüklendiğinde _cache hit ile bu dal atlanır. (Tek seferlik çizim,
  // sahnede ~1 kilise olur — perf kritik değil.)
  static void _drawChurch(Canvas canvas,
      Offset back, Offset left, Offset right, Offset front,
      double time, int seed) {
    final cx     = (back.dx + front.dx) / 2;
    final cyTile = (left.dy + right.dy) / 2;
    final tileW  = (right.dx - left.dx).abs();
    final s      = tileW / 64.0;

    const stone      = Color(0xFFCBBEA8);
    const stoneShade = Color(0xFFA99B82);
    const stoneDark  = Color(0xFF7E7058);
    const roof       = Color(0xFF8A4B33);
    const roofDark   = Color(0xFF6E3A26);
    const wood       = Color(0xFF5A3A22);
    const glass      = Color(0xFFF2D98A);
    const cross      = Color(0xFFE8C766);

    final fill   = Paint()..isAntiAlias = true;
    final stroke = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0 * s
      ..color = stoneDark;

    // Zemin gölgesi
    final groundY = cyTile + 6 * s;
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, groundY), width: 74 * s, height: 22 * s),
      Paint()..color = const Color(0x44000000)..isAntiAlias = true);

    final baseY   = groundY - 1 * s;
    final towerW  = 18.0 * s;
    final towerH  = 52.0 * s;
    final navW    = 40.0 * s;
    final navH    = 30.0 * s;
    final tx      = cx - 29 * s;        // kule sol kenarı
    final nx0     = tx + towerW;        // nef sol kenarı
    final towerTop= baseY - towerH;
    final navTop  = baseY - navH;

    // 1) Nef gövdesi (taş) + sağ kenar gölgesi
    fill.color = stone;
    canvas.drawRect(Rect.fromLTWH(nx0, navTop, navW, navH), fill);
    fill.color = stoneShade;
    canvas.drawRect(Rect.fromLTWH(nx0 + navW - 7 * s, navTop, 7 * s, navH), fill);
    canvas.drawRect(Rect.fromLTWH(nx0, navTop, navW, navH), stroke);

    // 2) Nef üçgen çatısı
    final gable = Path()
      ..moveTo(nx0 - 3 * s, navTop + 1 * s)
      ..lineTo(nx0 + navW / 2, navTop - 18 * s)
      ..lineTo(nx0 + navW + 3 * s, navTop + 1 * s)
      ..close();
    fill.color = roof;
    canvas.drawPath(gable, fill);
    // çatı sağ yüzü gölge
    final gableShade = Path()
      ..moveTo(nx0 + navW / 2, navTop - 18 * s)
      ..lineTo(nx0 + navW + 3 * s, navTop + 1 * s)
      ..lineTo(nx0 + navW / 2, navTop + 1 * s)
      ..close();
    fill.color = roofDark;
    canvas.drawPath(gableShade, fill);

    // 3) Çan kulesi gövdesi (taş)
    fill.color = stone;
    canvas.drawRect(Rect.fromLTWH(tx, towerTop, towerW, towerH), fill);
    fill.color = stoneShade;
    canvas.drawRect(Rect.fromLTWH(tx + towerW - 5 * s, towerTop, 5 * s, towerH), fill);
    canvas.drawRect(Rect.fromLTWH(tx, towerTop, towerW, towerH), stroke);

    // 4) Çan kulesi sivri külahı
    final spire = Path()
      ..moveTo(tx - 2 * s, towerTop + 1 * s)
      ..lineTo(tx + towerW / 2, towerTop - 20 * s)
      ..lineTo(tx + towerW + 2 * s, towerTop + 1 * s)
      ..close();
    fill.color = roofDark;
    canvas.drawPath(spire, fill);

    // 5) Külah tepesinde haç
    final apexX = tx + towerW / 2;
    final apexY = towerTop - 20 * s;
    fill.color = cross;
    canvas.drawRect(
      Rect.fromCenter(center: Offset(apexX, apexY - 3 * s), width: 1.6 * s, height: 9 * s),
      fill);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(apexX, apexY - 5 * s), width: 5 * s, height: 1.6 * s),
      fill);

    // 6) Çan kulesi açıklığı (kemerli, koyu)
    final belfry = Rect.fromLTWH(tx + 5 * s, towerTop + 8 * s, towerW - 10 * s, 9 * s);
    fill.color = const Color(0xFF3A2E20);
    canvas.drawRRect(
      RRect.fromRectAndCorners(belfry,
          topLeft: Radius.circular(4 * s), topRight: Radius.circular(4 * s)),
      fill);

    // 7) Gül penceresi (yuvarlak vitray) — nef alnında
    final roseC = Offset(nx0 + navW / 2, navTop - 4 * s);
    fill.color = stoneDark;
    canvas.drawCircle(roseC, 5.2 * s, fill);
    fill.color = glass;
    canvas.drawCircle(roseC, 3.8 * s, fill);
    fill.color = stoneDark;
    canvas.drawRect(
      Rect.fromCenter(center: roseC, width: 7.6 * s, height: 0.9 * s), fill);
    canvas.drawRect(
      Rect.fromCenter(center: roseC, width: 0.9 * s, height: 7.6 * s), fill);

    // 8) Kemerli ana kapı (nef tabanı ortası)
    final doorW = 11.0 * s, doorH = 16.0 * s;
    final doorX = nx0 + navW / 2 - doorW / 2;
    final doorY = baseY - doorH;
    fill.color = wood;
    canvas.drawRRect(
      RRect.fromRectAndCorners(Rect.fromLTWH(doorX, doorY, doorW, doorH),
          topLeft: Radius.circular(doorW / 2), topRight: Radius.circular(doorW / 2)),
      fill);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(doorX + doorW / 2, doorY + doorH * 0.6),
          width: 0.9 * s, height: doorH * 0.7),
      Paint()..color = const Color(0xFF3A2414)..isAntiAlias = true);

    // 9) Nef yan pencereleri (uzun, kemerli vitray)
    fill.color = glass;
    for (final fx in [0.22, 0.78]) {
      final wx = nx0 + navW * fx - 2 * s;
      final wy = navTop + navH * 0.30;
      canvas.drawRRect(
        RRect.fromRectAndCorners(Rect.fromLTWH(wx, wy, 4 * s, 11 * s),
            topLeft: Radius.circular(2 * s), topRight: Radius.circular(2 * s)),
        fill);
    }

    if (time < 0 || seed < 0) {} // unused tick/seed
  }

  // ── Çadır (procedurel A-frame bez çadır) ───────────────────────────────────
  // İlkel barınak: iki eğik bez panel sırtta birleşir, önde koyu kapı yarığı,
  // tepede çapraz sırıklar + minik flama (rüzgârda sallanır). Işık soldan →
  // sol panel açık, sağ panel gölgeli. tent.png gelince _cache hit ile atlanır.
  static void _drawTent(Canvas canvas,
      Offset back, Offset left, Offset right, Offset front,
      double time, int seed) {
    final cx     = (back.dx + front.dx) / 2;
    final cyTile = (left.dy + right.dy) / 2;
    final tileW  = (right.dx - left.dx).abs();
    final s      = tileW / 64.0;

    const cloth      = Color(0xFFD9C9A6); // ham bez krem
    const clothShade = Color(0xFFB29A74); // gölge yüz
    const clothDark  = Color(0xFF8A7553); // taban/ek dikiş
    const pole       = Color(0xFF6E4E2E); // ahşap sırık
    const doorDark   = Color(0xFF2A2018); // kapı içi karanlık
    const flag       = Color(0xFFB5503A); // kiremit flama

    final fill = Paint()..isAntiAlias = true;

    final baseY = cyTile + 4 * s;        // zemin çizgisi (hafif aşağı)
    final halfW = 15.0 * s;              // taban yarı genişliği
    final height = 26.0 * s;             // sırt yüksekliği
    final ridgeX = cx + 2.0 * s;         // sırt hafif sağda (iso derinlik)
    final ridgeY = baseY - height;

    // Zemin gölgesi
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, baseY + 1 * s), width: 34 * s, height: 11 * s),
      Paint()..color = const Color(0x33000000)..isAntiAlias = true);

    // 1) Sağ (arka) bez yüzü — gölgeli, hafif derinlik için sağa kayık.
    final rightFace = Path()
      ..moveTo(ridgeX, ridgeY)
      ..lineTo(cx + halfW, baseY)
      ..lineTo(cx + halfW * 0.55, baseY)
      ..lineTo(ridgeX - 3 * s, ridgeY + 2 * s)
      ..close();
    fill.color = clothShade;
    canvas.drawPath(rightFace, fill);

    // 2) Sol (ön) bez yüzü — aydınlık ana panel (geniş üçgen).
    final leftFace = Path()
      ..moveTo(ridgeX, ridgeY)
      ..lineTo(cx - halfW, baseY)
      ..lineTo(cx + halfW, baseY)
      ..close();
    fill.color = cloth;
    canvas.drawPath(leftFace, fill);

    // 3) Taban dikiş bandı (koyu) — bezin yere oturduğu kalın kenar.
    canvas.drawRect(
      Rect.fromLTWH(cx - halfW, baseY - 1.5 * s, halfW * 2, 2.2 * s),
      Paint()..color = clothDark..isAntiAlias = true);

    // 4) Ön kapı yarığı — ortada, alttan yukarı daralan koyu üçgen.
    final door = Path()
      ..moveTo(cx, ridgeY + height * 0.30)
      ..lineTo(cx - 5 * s, baseY - 1 * s)
      ..lineTo(cx + 5 * s, baseY - 1 * s)
      ..close();
    fill.color = doorDark;
    canvas.drawPath(door, fill);
    // Kapı bezi kıvrımı (sol kapak hafif açık)
    final flapPaint = Paint()
      ..color = clothShade
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4 * s
      ..isAntiAlias = true;
    canvas.drawLine(Offset(cx, ridgeY + height * 0.30),
        Offset(cx - 5 * s, baseY - 1 * s), flapPaint);

    // 5) Sırt çizgisi (ridge hairline) — bezin tepe ek yeri.
    canvas.drawLine(Offset(ridgeX, ridgeY), Offset(cx, baseY - 1 * s),
        Paint()
          ..color = clothDark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0 * s
          ..isAntiAlias = true);

    // 6) Çapraz sırıklar — tepede X yapıp dışarı taşar.
    final polePaint = Paint()
      ..color = pole
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * s
      ..isAntiAlias = true;
    canvas.drawLine(Offset(ridgeX - 4 * s, ridgeY - 5 * s),
        Offset(cx - halfW * 0.7, baseY), polePaint);
    canvas.drawLine(Offset(ridgeX + 4 * s, ridgeY - 5 * s),
        Offset(ridgeX + 1 * s, baseY), polePaint);

    // 7) Minik flama — sırık tepesinde rüzgârda dalgalanır.
    final fx = ridgeX;
    final fy = ridgeY - 5 * s;
    final wave = sin(time * 2.3 + seed * 0.5) * 2.0 * s;
    final pennant = Path()
      ..moveTo(fx, fy)
      ..lineTo(fx + 9 * s + wave, fy + 1.5 * s)
      ..lineTo(fx, fy + 4 * s)
      ..close();
    fill.color = flag;
    canvas.drawPath(pennant, fill);
  }

  // ── Kültür mahallesi placeholder (prosedürel kutu) ──────────────────────────
  // PNG gelene kadar binayı footprint'e oturan basit izometrik kutu olarak çizer:
  // taban diamond → yukarı ekstrüzyon (2 yan duvar + üst yüz) + türe göre renk +
  // ortada baş harf. PNG yüklenince _cache hit ile bu dal atlanır.
  static void _drawCivicPlaceholder(Canvas canvas, BuildingType type,
      Offset back, Offset left, Offset right, Offset front, double time) {
    // Türe göre renk + etiket.
    final (Color roof, Color wall, String tag) = switch (type) {
      BuildingType.fountain  => (const Color(0xFF5B86A6), const Color(0xFF8FB3C9), 'Ş'),
      BuildingType.library   => (const Color(0xFF8A5A33), const Color(0xFFBE9468), 'K'),
      BuildingType.bathhouse => (const Color(0xFF3F8C86), const Color(0xFF77B6B0), 'H'),
      BuildingType.monument  => (const Color(0xFF8C8470), const Color(0xFFBFB8A6), 'A'),
      BuildingType.dock         => (const Color(0xFF6E4E2E), const Color(0xFF9A7A4E), 'İ'),
      BuildingType.caravanserai => (const Color(0xFF9C7B4A), const Color(0xFFC9A877), 'H'),
      BuildingType.shrine       => (const Color(0xFF3F8C86), const Color(0xFF77B6B0), 'T'),
      BuildingType.belltower    => (const Color(0xFF8C8470), const Color(0xFFBFB8A6), 'Ç'),
      _                      => (const Color(0xFF777777), const Color(0xFFAAAAAA), '?'),
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
    canvas.drawPath(shadow, Paint()..color = const Color(0x33000000)..isAntiAlias = true);

    final fill = Paint()..isAntiAlias = true;
    // Sol-ön duvar (left→front yüzü, gölgeli).
    fill.color = _shade(wall, 0.80);
    canvas.drawPath(Path()
      ..moveTo(left.dx, left.dy)
      ..lineTo(front.dx, front.dy)
      ..lineTo(up(front).dx, up(front).dy)
      ..lineTo(up(left).dx, up(left).dy)
      ..close(), fill);
    // Sağ-ön duvar (front→right yüzü, aydınlık).
    fill.color = wall;
    canvas.drawPath(Path()
      ..moveTo(front.dx, front.dy)
      ..lineTo(right.dx, right.dy)
      ..lineTo(up(right).dx, up(right).dy)
      ..lineTo(up(front).dx, up(front).dy)
      ..close(), fill);
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
    canvas.drawPath(top, Paint()
      ..color = _shade(roof, 1.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..isAntiAlias = true);

    // Baş harf — üst yüz merkezinde.
    final cx = (up(back).dx + up(front).dx) / 2;
    final cy = (up(left).dy + up(right).dy) / 2;
    final tp = TextPainter(
      text: TextSpan(text: tag, style: TextStyle(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: h * 0.5, fontWeight: FontWeight.bold)),
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

  // Değirmen öğütürken dipteki huni/değirmen taşı hizasından yükselen ÇOK hafif
  // un tozu. Yelkene dokunmaz; sadece "çalışıyor" hissini diegetik verir.
  // Kasıtlı olarak sönük: tepe alpha ~0.10, birkaç zerre.
  static void _drawMillFlourDust(
      Canvas canvas, ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta, double time, int seed) {
    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;
    // Huni/taş sağ-alt bölgede.
    final bx = dstL + 0.66 * spriteW;
    final by = dstT + 0.80 * spriteH;
    final paint = Paint()..isAntiAlias = true;
    const n = 4;
    for (int i = 0; i < n; i++) {
      // Deterministik per-zerre ofset — Random allocation'sız (hot-path).
      final off = ((seed * 2654435761 + i * 40503) & 0xFFFF) / 65536.0;
      final jx =
          (((seed ^ (i * 26699)) & 0xFF) / 255.0 - 0.5) * spriteW * 0.05;
      final phase = (time * 0.28 + off) % 1.0; // 0(dip) → 1(yukarı)
      final px = bx + jx + sin(time * 0.7 + i * 2.1) * spriteW * 0.015;
      final py = by - phase * spriteH * 0.11;
      // Parabolik sönme (0 uçlarda, ~0.10 ortada) — pi'siz.
      final a = 4.0 * phase * (1.0 - phase) * 0.10;
      if (a <= 0.008) continue;
      final ai = (a * 255).round().clamp(0, 255);
      paint.color = Color((ai << 24) | 0x00F1EBDC); // soluk un beji
      canvas.drawCircle(
          Offset(px, py), spriteW * (0.009 + 0.010 * phase), paint);
    }
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

  // ── Su parlaması ────────────────────────────────────────────────────────────
  // Sprite dst rect'inden su bölgelerini dünya koordinatına çevirir; her bölgeye
  // WaterShimmerRenderer ile animasyonlu ışıltı işler.
  static void _drawWaterShimmer(
      Canvas canvas,
      BuildingType type,
      ui.Image img,
      Offset left, Offset right, Offset front,
      BuildingMeta meta,
      double dayLight,
      double time,
      int seed) {
    final patches = kBuildingWater[type];
    if (patches == null || patches.isEmpty) return;

    final spriteW = (right.dx - left.dx).abs() * meta.spriteScale;
    final spriteH = spriteW * img.height / img.width;
    final dstL    = front.dx - spriteW * meta.groundXCenter;
    final dstT    = front.dy - spriteH * meta.groundY;

    for (final w in patches) {
      final cx = dstL + w.nx * spriteW;
      final cy = dstT + w.ny * spriteH;
      WaterShimmerRenderer.draw(
        canvas, cx, cy, w.hw * spriteW, w.hh * spriteH, time, seed,
        dayLight: dayLight, intensity: w.intensity,
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
