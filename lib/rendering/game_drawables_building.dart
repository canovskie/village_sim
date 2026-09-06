part of 'game_painter.dart';

/// BİNA DRAWABLE — binanın sahnedeki çizimi: uyku/uyanma/kapı nabzı, iş ipuçları, hasar ve yangın katmanı.
class _BuildingDrawable extends _Drawable {
  final BuildingEntity b;
  final double time;
  final double dayLight;
  final double rainIntensity;
  final Season season;

  /// fireOutbreak event'inde bu bina yanıyor mu — sprite üstüne alev + duman.
  final bool burning;
  final bool perfMode;
  _BuildingDrawable(
    this.b,
    this.time,
    this.dayLight,
    this.rainIntensity,
    this.season,
    this.burning,
    this.perfMode,
  );
  // Painter's algorithm: bina ön-en (frontmost) tile'ının diagonal sum'ı.
  // (col+cols-1, row+rows-1) bina footprint'inin güney-doğu (ön) tile'ı.
  // Eski formül (col+row + (cols+rows)/2 = orta) → bina arkasındaki NPC önde
  // görünebiliyordu. Ön-tile sort'u izometride doğru z-order verir.
  @override
  double get depth => (b.col + b.cols - 1.0) + (b.row + b.rows - 1.0);
  @override
  BuildingEntity? get building => b;
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

    void drawSprite() {
      BuildingRenderer.draw(
        canvas,
        b.type,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        time: time,
        seed: b.col * 17 + b.row * 31,
        dayLight: dayLight,
        rainIntensity: rainIntensity,
        isActive: b.isActive,
        activityLevel: b.visibleActivityLevel,
        perfMode: perfMode,
        fireFuel: b.fireFuel,
        millRotorAngle: b.millRotorAngle,
        deliveryPulse: b.deliveryPulse,
        deliveryTally: b.deliveryTally,
        season: season,
        design: b.design,
        householdDecor: b.occupants > 0 && !burning && b.damage < 0.35,
        windowGlow: b.windowGlow,
      );
    }

    if (popping) {
      final t = age / 0.6;
      final scale = 1.0 + 0.06 * (1.0 - t) * (1.0 - t);
      final fx = corners.$4.dx;
      final fy = corners.$4.dy;
      canvas.save();
      canvas.translate(fx, fy);
      canvas.scale(scale, scale);
      canvas.translate(-fx, -fy);
      drawSprite();
      canvas.restore();
    } else {
      drawSprite();
    }

    if (rainIntensity > 0.12 && _buildingHasRainRoof(b.type)) {
      _drawRoofDrips(canvas, corners);
    }

    // Toz bulutu — ilk 0.4 sn footprint kenarlarında 3 partikül. Açık bej ton.
    if (b.spawnTime > 0 && age >= 0 && age < 0.4) {
      final dust = 1.0 - age / 0.4;
      final midY = (corners.$2.dy + corners.$3.dy) * 0.5 + 2;
      final fw = (corners.$3.dx - corners.$2.dx).abs();
      final dustScale = 0.35 + fw / 200.0; // büyük bina ~ daha geniş toz
      const dustTint = Color(0xFFE8DCC4);
      SmokeRenderer.draw(
        canvas,
        corners.$2.dx + 4,
        midY,
        dustScale,
        time,
        b.col * 31 + b.row * 7,
        tint: dustTint,
        intensity: dust,
      );
      SmokeRenderer.draw(
        canvas,
        corners.$4.dx,
        corners.$4.dy - 1,
        dustScale,
        time,
        b.col * 31 + b.row * 11,
        tint: dustTint,
        intensity: dust,
      );
      SmokeRenderer.draw(
        canvas,
        corners.$3.dx - 4,
        midY,
        dustScale,
        time,
        b.col * 31 + b.row * 13,
        tint: dustTint,
        intensity: dust,
      );
    }

    if (b.damage > 0.02) {
      _drawDamageOverlay(
        canvas,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        b.damage,
      );
    }

    if (b.fn?.role == BuildingRole.housing && b.doorPulseUntil > time) {
      _drawHouseDoorPulse(canvas, corners);
    }

    // ÇALIŞAN BİNA — uzaktan yalnız `isActive` panel satırı kalmasın. Her
    // üretim yapısı kendi malzemesiyle küçük, sürekli bir hareket bırakır.
    final activityLevel = b.visibleActivityLevel;
    if (activityLevel > 0.02) {
      final bounds = Rect.fromLTRB(
        corners.$2.dx - 40,
        corners.$1.dy - 50,
        corners.$3.dx + 40,
        corners.$4.dy + 30,
      );
      _pActivityFade.color = Colors.white.withValues(alpha: activityLevel);
      canvas.saveLayer(bounds, _pActivityFade);
      _drawActiveBuildingCue(canvas, corners);
      canvas.restore();
    }
    if (b.deliveryFeedbackUntil > time) {
      _drawDeliveryFeedback(canvas, corners.$4);
    }

    // Alev ve duman is katmanının üstünde kalmalı: yangın sürerken okunur,
    // söndüğünde altta kalan kalıcı hasar tek başına görünür.
    if (burning) {
      _drawBurningOverlay(
        canvas,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
      );
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

    // Yas işareti — bu evden biri öldüğünde çatının üstünde kısa süre görünür.
    // Dünya işareti metin bildirimini tamamlar: oyuncu hangi ocağın sustuğunu
    // kamerayı çevirmeden de seçebilir.
    if (b.deathMarkerUntil > time && b.fn?.role == BuildingRole.housing) {
      final left = b.deathMarkerUntil - time;
      final fade = left < 1.5 ? (left / 1.5).clamp(0.0, 1.0) : 1.0;
      final pulse = 0.5 + 0.5 * sin(time * 4.0 + b.col * 0.7);
      final alpha = (fade * (0.78 + pulse * 0.16) * 255).round().clamp(0, 255);
      final cx = (corners.$1.dx + corners.$4.dx) * 0.5;
      final cy = corners.$1.dy - 34 - pulse * 2.0;
      final markerPaint = Paint()..color = Color.fromARGB(alpha, 35, 24, 28);
      final clothPaint = Paint()..color = Color.fromARGB(alpha, 139, 31, 43);
      canvas.drawLine(
        Offset(cx, cy + 16),
        Offset(cx, cy - 13),
        markerPaint..strokeWidth = 2.0,
      );
      final flag = Path()
        ..moveTo(cx + 1, cy - 12)
        ..lineTo(cx + 17, cy - 8)
        ..lineTo(cx + 1, cy - 2)
        ..close();
      canvas.drawPath(flag, clothPaint);
      canvas.drawCircle(Offset(cx, cy + 18), 3.5, markerPaint);
      final glyph = TextPainter(
        text: TextSpan(
          text: '✝',
          style: TextStyle(
            color: Color.fromARGB(alpha, 245, 226, 193),
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      glyph.paint(canvas, Offset(cx - glyph.width / 2, cy - 10));
      if (b.deathMarkerCount > 1) {
        final count = TextPainter(
          text: TextSpan(
            text: '${b.deathMarkerCount}',
            style: TextStyle(
              color: Color.fromARGB(alpha, 255, 245, 220),
              fontSize: 8,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        count.paint(canvas, Offset(cx + 10, cy - 3));
      }
    }

    // EV UYKUSU — sakin gerçekten içeri girip uyuduğunda çatının üstünden
    // küçük Z'ler yükselir. Dışarıda uyuyan köylüyle aynı parçacığı kullanır;
    // böylece uyku dili evin içinde/dışında değişmez. Yatağa yürüyen sakin
    // `awakeOccupants` içinde kaldığından işaret kapıya varmadan belirmez.
    if (b.fn?.role == BuildingRole.housing && b.sleepingOccupants > 0) {
      _drawHouseSleepZzz(canvas, corners);
    }
    if (b.fn?.role == BuildingRole.housing && b.wakePuffUntil > time) {
      _drawHouseWakePuff(canvas, corners);
    }
  }

  void _drawHouseSleepZzz(
    Canvas canvas,
    (Offset, Offset, Offset, Offset) corners,
  ) {
    final meta = kBuildingMeta[b.type]!;
    final sprite = BuildingRenderer.thumbnailFor(b.type, b.design);
    final spriteW = (corners.$3.dx - corners.$2.dx).abs() * meta.spriteScale;

    // Sprite yüklenmişse gerçek en-boy oranından çatı tepesini bul. İlk yükleme
    // karesindeki fallback de footprint'in arka kenarının biraz üstünde durur.
    final double roofTop;
    final double centerX;
    if (sprite != null) {
      final spriteH = spriteW * sprite.height / sprite.width;
      roofTop = corners.$4.dy - spriteH * meta.groundY;
      final spriteLeft = corners.$4.dx - spriteW * meta.groundXCenter;
      centerX = spriteLeft + spriteW * 0.5;
    } else {
      roofTop = corners.$1.dy - 20.0;
      centerX = (corners.$1.dx + corners.$4.dx) * 0.5;
    }

    final seed = b.type.index * 97 + b.col * 31 + b.row * 17;
    for (int i = 0; i < 3; i++) {
      ParticleRenderer.drawSleepZzz(
        canvas,
        centerX + (i - 1) * 5.0,
        roofTop + 12.0 - i * 2.0,
        time,
        seed + i * 17,
      );
    }
  }

  void _drawDeliveryFeedback(Canvas canvas, Offset front) {
    final remaining = b.deliveryFeedbackUntil - time;
    final age = BuildingEntity.deliveryFeedbackDuration - remaining;
    final fadeIn = (age / 0.16).clamp(0.0, 1.0);
    final fadeOut = (remaining / 0.42).clamp(0.0, 1.0);
    final alpha = fadeIn * fadeOut;
    if (alpha <= 0.01 || b.deliveryFeedback.isEmpty) return;
    final rise = age * 12.0;
    final painter = TextPainter(
      text: TextSpan(
        text: b.deliveryFeedback,
        style: TextStyle(
          color: const Color(0xFFFFE4A3).withValues(alpha: alpha),
          fontSize: 10,
          fontWeight: FontWeight.w700,
          shadows: [
            Shadow(
              color: const Color(0xFF2A1A10).withValues(alpha: alpha * 0.8),
              offset: const Offset(0, 1),
              blurRadius: 1,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      Offset(front.dx - painter.width * 0.5, front.dy - 22.0 - rise),
    );
  }

  bool _buildingHasRainRoof(BuildingType type) => switch (type) {
    BuildingType.placeholder ||
    BuildingType.well ||
    BuildingType.firepit ||
    BuildingType.lamppost ||
    BuildingType.beehive ||
    BuildingType.fountain ||
    BuildingType.monument => false,
    _ => true,
  };

  void _drawRoofDrips(Canvas canvas, (Offset, Offset, Offset, Offset) corners) {
    final meta = kBuildingMeta[b.type]!;
    final sprite = BuildingRenderer.thumbnailFor(b.type, b.design);
    final spriteW = (corners.$3.dx - corners.$2.dx).abs() * meta.spriteScale;
    final double left;
    final double eaveY;
    if (sprite != null) {
      final spriteH = spriteW * sprite.height / sprite.width;
      left = corners.$4.dx - spriteW * meta.groundXCenter;
      final top = corners.$4.dy - spriteH * meta.groundY;
      // Çatı saçağının ortak yaklaşık bandı. Damlaların farklı başlangıç
      // fazları küçük tasarım sapmalarını gizler; zemin köşesinden damlamaz.
      eaveY = top + spriteH * 0.48;
    } else {
      left = corners.$1.dx - spriteW * 0.5;
      eaveY = corners.$1.dy - 10.0;
    }

    final count = perfMode ? 3 : 6;
    final seed = b.type.index * 89 + b.col * 37 + b.row * 53;
    _pRoofDrip.strokeWidth = 0.9;
    _pRoofDrip.strokeCap = StrokeCap.round;
    for (int i = 0; i < count; i++) {
      final phase =
          (time * (1.7 + rainIntensity) + i * 0.31 + seed * 0.013) % 1.0;
      final x =
          left + spriteW * (0.16 + 0.68 * ((i * 0.37 + seed * 0.001) % 1.0));
      final fall = phase * (5.0 + rainIntensity * 8.0);
      final alpha = (sin(pi * phase) * rainIntensity * 175).round().clamp(
        0,
        175,
      );
      _pRoofDrip.color = Color.fromARGB(alpha, 151, 198, 218);
      canvas.drawLine(
        Offset(x, eaveY + fall),
        Offset(x + 0.5, eaveY + fall + 2.0 + rainIntensity * 2.0),
        _pRoofDrip,
      );
    }
  }

  void _drawHouseWakePuff(
    Canvas canvas,
    (Offset, Offset, Offset, Offset) corners,
  ) {
    final remaining = b.wakePuffUntil - time;
    if (remaining <= 0) return;
    final age = BuildingEntity.wakePuffDuration - remaining;
    final meta = kBuildingMeta[b.type]!;
    final sprite = BuildingRenderer.thumbnailFor(b.type, b.design);
    final chimneys = kBuildingChimneys[b.type];
    final chimney = chimneys == null || chimneys.isEmpty
        ? null
        : chimneys.first;

    final spriteW = (corners.$3.dx - corners.$2.dx).abs() * meta.spriteScale;
    final double puffX;
    final double puffY;
    if (sprite != null && chimney != null) {
      final spriteH = spriteW * sprite.height / sprite.width;
      final spriteLeft = corners.$4.dx - spriteW * meta.groundXCenter;
      final spriteTop = corners.$4.dy - spriteH * meta.groundY;
      puffX = spriteLeft + chimney.nx * spriteW;
      puffY = spriteTop + chimney.ny * spriteH;
    } else {
      puffX = (corners.$1.dx + corners.$4.dx) * 0.5;
      puffY = corners.$1.dy - 12.0;
    }

    // Hızlı belirir, sonra iki saniye içinde genişleyip solar. Ambient baca
    // dumanının üstüne yalnız tek sprite çizimi eklenir; sürekli yeni kaynak
    // üretmediği için sabah geçişi belirgin ama kalabalık değildir.
    final fadeIn = (age / 0.18).clamp(0.0, 1.0);
    final fadeOut = (remaining / 0.75).clamp(0.0, 1.0);
    final intensity = fadeIn * fadeOut;
    final scale = 1.15 + age * 0.22;
    final seed = b.type.index * 131 + b.col * 37 + b.row * 19;
    SmokeRenderer.draw(
      canvas,
      puffX,
      puffY,
      scale,
      age,
      seed,
      tint: const Color(0xFFD8C8AE),
      intensity: intensity,
    );
  }

  void _drawHouseDoorPulse(
    Canvas canvas,
    (Offset, Offset, Offset, Offset) corners,
  ) {
    final remaining = b.doorPulseUntil - time;
    final age = BuildingEntity.doorPulseDuration - remaining;
    final phase = (age / BuildingEntity.doorPulseDuration).clamp(0.0, 1.0);
    final open = sin(pi * phase).clamp(0.0, 1.0);
    if (open <= 0.02) return;

    // Sprite'ların kapı koordinatları tasarıma göre değişiyor; ortak ve stabil
    // ankraj footprint'in ön köşesi. Eşikteki sıcak ışık yarığı gerçek kapının
    // kısa açılıp kapanmasını bütün konut varyantlarında aynı dille anlatır.
    final front = corners.$4;
    final footprintW = (corners.$3.dx - corners.$2.dx).abs();
    final w = (footprintW * 0.13).clamp(8.0, 15.0) * open;
    final top = front.dy - (18.0 + footprintW * 0.025);
    _pDoorPulseDark.color = const Color(
      0xFF21170F,
    ).withValues(alpha: 0.72 * open);
    canvas.drawRect(
      Rect.fromLTWH(front.dx - w * 0.5, top, w, front.dy - top - 2.0),
      _pDoorPulseDark,
    );

    _doorPulsePath
      ..reset()
      ..moveTo(front.dx - w * 0.55, front.dy - 3.0)
      ..lineTo(front.dx + w * 0.55, front.dy - 3.0)
      ..lineTo(front.dx + w * 1.05, front.dy + 4.0)
      ..lineTo(front.dx - w * 1.05, front.dy + 4.0)
      ..close();
    _pDoorPulseLight.color = const Color(
      0xFFFFC36A,
    ).withValues(alpha: 0.42 * open * dayLight.clamp(0.15, 1.0));
    canvas.drawPath(_doorPulsePath, _pDoorPulseLight);
  }

  void _drawActiveBuildingCue(
    Canvas canvas,
    (Offset, Offset, Offset, Offset) corners,
  ) {
    final front = corners.$4;
    final width = (corners.$3.dx - corners.$2.dx).abs();
    final seed = b.type.index * 83 + b.col * 31 + b.row * 47;

    switch (b.type) {
      case BuildingType.mineBuilding:
        _drawMineWorkCue(canvas, front, width, seed);
      case BuildingType.lumberCamp:
        _drawLumberWorkCue(canvas, front, width, seed);
      case BuildingType.fisherCabin:
        _drawFisherWorkCue(canvas, front, width, seed);
      case BuildingType.barn:
        _drawBarnWorkCue(canvas, front, width, seed);
      default:
        break;
    }
  }

  void _drawMineWorkCue(Canvas canvas, Offset front, double width, int seed) {
    final origin = Offset(front.dx - width * 0.08, front.dy - 12.0);
    // Keskin tepe: sürekli parlamak yerine kazma temasında kısa aksan.
    final wave = (sin(time * 7.2 + seed * 0.13) + 1.0) * 0.5;
    final strike = pow(wave, 7).toDouble();
    final alpha = (55 + strike * 190).round().clamp(0, 245);
    _pActiveCue
      ..color = Color.fromARGB(alpha, 245, 190, 92)
      ..strokeWidth = 1.2;
    for (int i = 0; i < 4; i++) {
      final angle = -2.75 + i * 0.48;
      final reach = 3.0 + strike * (5.0 + (i.isEven ? 2.0 : 0.0));
      final start = Offset(
        origin.dx + cos(angle) * 2.0,
        origin.dy + sin(angle) * 2.0,
      );
      canvas.drawLine(
        start,
        Offset(origin.dx + cos(angle) * reach, origin.dy + sin(angle) * reach),
        _pActiveCue,
      );
    }
    for (int i = 0; i < 3; i++) {
      final phase = (time * 0.55 + i * 0.29 + seed * 0.017) % 1.0;
      _pActiveCueSoft.color = Color.fromARGB(
        (sin(phase * pi) * 95).round().clamp(0, 95),
        142,
        136,
        126,
      );
      canvas.drawCircle(
        Offset(
          origin.dx - 5 + i * 4 + sin(time + i) * 1.5,
          origin.dy + 8 - phase * 9,
        ),
        1.3 + phase,
        _pActiveCueSoft,
      );
    }
  }

  void _drawLumberWorkCue(Canvas canvas, Offset front, double width, int seed) {
    final origin = Offset(front.dx + width * 0.10, front.dy - 7.0);
    _pActiveCue.strokeWidth = 1.1;
    for (int i = 0; i < 5; i++) {
      final phase = (time * 0.72 + i * 0.19 + seed * 0.011) % 1.0;
      final alpha = (sin(phase * pi) * 175).round().clamp(0, 175);
      _pActiveCue.color = Color.fromARGB(alpha, 205, 157, 82);
      final dir = i.isEven ? -1.0 : 1.0;
      final x = origin.dx + dir * phase * (7 + i);
      final y = origin.dy - sin(phase * pi) * (4 + i % 3) + phase * 2;
      canvas.drawLine(
        Offset(x - dir * 1.5, y - 0.5),
        Offset(x + dir * 1.5, y + 0.5),
        _pActiveCue,
      );
    }
  }

  void _drawFisherWorkCue(Canvas canvas, Offset front, double width, int seed) {
    final water = Offset(front.dx + width * 0.13, front.dy - 1.0);
    for (int i = 0; i < 4; i++) {
      final phase = (time * 0.9 + i * 0.23 + seed * 0.019) % 1.0;
      final alpha = (sin(phase * pi) * 165).round().clamp(0, 165);
      _pActiveCueSoft.color = Color.fromARGB(alpha, 132, 190, 211);
      final side = i.isEven ? -1.0 : 1.0;
      final x = water.dx + side * (3 + phase * (4 + i));
      final y = water.dy - sin(phase * pi) * (6 + i) + phase * 3;
      canvas.drawCircle(Offset(x, y), 1.0 + phase * 0.8, _pActiveCueSoft);
    }
    final ripple = (sin(time * 2.8 + seed) + 1.0) * 0.5;
    _pActiveCue
      ..color = Color.fromARGB(
        (65 + ripple * 70).round().clamp(0, 140),
        105,
        170,
        194,
      )
      ..strokeWidth = 0.9;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(water.dx, water.dy + 1),
        width: 8 + ripple * 7,
        height: 2.5 + ripple * 1.5,
      ),
      _pActiveCue,
    );
  }

  void _drawBarnWorkCue(Canvas canvas, Offset front, double width, int seed) {
    final origin = Offset(front.dx - width * 0.09, front.dy - 5.0);
    _pActiveCue.strokeWidth = 1.0;
    for (int i = 0; i < 5; i++) {
      final phase = (time * 0.34 + i * 0.21 + seed * 0.007) % 1.0;
      final alpha = (sin(phase * pi) * 125).round().clamp(0, 125);
      _pActiveCue.color = Color.fromARGB(alpha, 218, 180, 88);
      final x = origin.dx + sin(time * 1.2 + i * 1.7) * (3 + phase * 5);
      final y = origin.dy - phase * 13;
      canvas.drawLine(
        Offset(x - 1.4, y),
        Offset(x + 1.4, y - 0.7),
        _pActiveCue,
      );
    }
  }

  // Yanan bina overlay'i — sprite çatısı/orta seviyesinde 2-3 alev + yukarı
  // kalkan koyu duman partikülleri + sıcak halo. Footprint köşelerinden
  // ortalanmış pozisyon hesabı.
  static final Paint _pBurnGlow = Paint()..isAntiAlias = true;
  static final Paint _pActivityFade = Paint();
  static final Paint _pRoofDrip = Paint()..isAntiAlias = true;
  static final Paint _pDoorPulseDark = Paint()..isAntiAlias = false;
  static final Paint _pDoorPulseLight = Paint()..isAntiAlias = true;
  static final Path _doorPulsePath = Path();
  static final Paint _pActiveCue = Paint()
    ..isAntiAlias = true
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _pActiveCueSoft = Paint()..isAntiAlias = true;
  static final Paint _pDamage = Paint()
    ..isAntiAlias = true
    ..strokeCap = StrokeCap.round;

  /// Kalıcı hasar izi: çatıya sinen is, iki kırık hat ve ağır hasarda kapıya
  /// çakılmış destek tahtaları. Geometri footprint'ten türediği için aynı
  /// katman kulübe, taş konut ve konakta da sprite'a özgü koordinat istemeden
  /// doğru yere oturur.
  void _drawDamageOverlay(
    Canvas canvas,
    Offset back,
    Offset left,
    Offset right,
    Offset front,
    double damage,
  ) {
    final d = damage.clamp(0.0, 1.0);
    final cx = (back.dx + front.dx) * 0.5;
    final roofY = (back.dy + left.dy) * 0.5 - 6;
    final width = (right.dx - left.dx).abs();
    final alpha = (45 + 105 * d).round().clamp(0, 160);
    _pDamage
      ..style = PaintingStyle.fill
      ..color = Color.fromARGB(alpha, 31, 24, 22);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, roofY),
        width: width * (0.42 + d * 0.22),
        height: 7 + d * 5,
      ),
      _pDamage,
    );

    _pDamage
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2 + d * 1.1
      ..color = Color.fromARGB(
        (80 + 115 * d).round().clamp(0, 195),
        58,
        38,
        30,
      );
    canvas.drawLine(
      Offset(cx - width * 0.16, roofY - 2),
      Offset(cx - width * 0.03, roofY + 4),
      _pDamage,
    );
    if (d > 0.35) {
      canvas.drawLine(
        Offset(cx + width * 0.10, roofY - 3),
        Offset(cx + width * 0.22, roofY + 3),
        _pDamage,
      );
    }
    if (d > 0.62) {
      _pDamage
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = const Color(0xFF765038);
      final boardY = front.dy - 8;
      canvas.drawLine(
        Offset(cx - width * 0.11, boardY - 3),
        Offset(cx + width * 0.08, boardY + 2),
        _pDamage,
      );
      canvas.drawLine(
        Offset(cx - width * 0.08, boardY + 3),
        Offset(cx + width * 0.11, boardY - 2),
        _pDamage,
      );
    }
  }

  void _drawBurningOverlay(
    Canvas canvas,
    Offset back,
    Offset left,
    Offset right,
    Offset front,
  ) {
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
      (140 * pulse).round().clamp(0, 200),
      0xFF,
      0x60,
      0x18,
    );
    canvas.drawCircle(Offset(cx, roofY), 30 * flameScale, _pBurnGlow);
    _pBurnGlow.blendMode = BlendMode.srcOver;

    // Birden fazla alev — çatıya yayılır
    for (int i = 0; i < 3; i++) {
      final fx = cx + (i - 1) * (10 * flameScale);
      final fy = roofY - (i == 1 ? 4 * flameScale : 0);
      FlameRenderer.draw(
        canvas,
        fx,
        fy,
        flameScale * 2.0,
        time + i * 0.41,
        b.col * 7 + i,
        intensity: 1.0,
        sparks: true,
      );
    }

    // Yangın dumanı — sprite-based, koyu siyah-gri tint, yoğun yüksek scale.
    // İki duman sütunu (çatının iki ucundan) → yangının büyüklüğünü vurgular.
    SmokeRenderer.draw(
      canvas,
      cx - 4 * flameScale,
      roofY,
      flameScale * 2.4,
      time,
      b.col * 17 + b.row * 31,
      tint: const Color(0xFF504842),
      intensity: 1.0,
    );
    SmokeRenderer.draw(
      canvas,
      cx + 4 * flameScale,
      roofY - 2,
      flameScale * 2.0,
      time + 0.7,
      b.col * 23 + b.row * 41 + 7,
      tint: const Color(0xFF504842),
      intensity: 0.9,
    );
  }
}
