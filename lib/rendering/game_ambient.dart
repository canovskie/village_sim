part of 'game_painter.dart';

/// ─── AMBİYANS PARTİKÜLLERİ ──────────────────────────────────────────────────
///
/// Köyün "yaşıyor" hissini veren ama hiçbir şeye DOKUNMAYAN katman: kenar tülü,
/// ateşböcekleri, polen, mevsim partikülleri (kar/yaprak), kuş sürüleri, arılar.
///
/// SÖZLEŞME: tamamen dekoratiftir — simülasyon durumu okumaz/yazmaz, tıklama
/// almaz, derinlik sıralamasına girmez. Perf modunda ilk kapatılan katman
/// budur; bu yüzden hepsi tek yerde durur.
///
/// Statik Paint havuzları bilinçli olarak metotların yanında tutuldu (her biri
/// yalnız kendi katmanınca kullanılır).
extension _PainterAmbient on VillageGamePainter {
  // ── Çok hafif kenar tülü (reveal = zoom kısıtının atmosferik çerçevesi) ──────
  static final Paint _pEdgeHaze = Paint()..isAntiAlias = true;

  void _drawEdgeHaze(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final band = min(w, h) * 0.17; // tül bandı genişliği (ekran kenarı)
    // İnci/şafak tonu — şafak/alacakaranlıkta hafif sıcak, gündüz nötr-parlak.
    final warm = (1.0 - dayLight).clamp(0.0, 1.0);
    final cr = (0xE4 + 0x14 * warm).round().clamp(0, 255);
    final cg = (0xE8).clamp(0, 255);
    final cb = (0xEC - 0x16 * warm).round().clamp(0, 255);
    const maxA = 0.11; // tek kenar tepe opaklığı (çok hafif)
    final edge = Color.fromRGBO(cr, cg, cb, maxA);
    final clear = Color.fromRGBO(cr, cg, cb, 0.0);

    void side(Rect rect, Offset from, Offset to) {
      _pEdgeHaze.shader = ui.Gradient.linear(
        from,
        to,
        [edge, clear],
        const [0.0, 1.0],
      );
      canvas.drawRect(rect, _pEdgeHaze);
    }

    side(Rect.fromLTWH(0, 0, w, band), Offset(0, 0), Offset(0, band)); // üst
    side(
      Rect.fromLTWH(0, h - band, w, band),
      Offset(0, h),
      Offset(0, h - band),
    ); // alt
    side(Rect.fromLTWH(0, 0, band, h), Offset(0, 0), Offset(band, 0)); // sol
    side(
      Rect.fromLTWH(w - band, 0, band, h),
      Offset(w, 0),
      Offset(w - band, 0),
    ); // sağ
  }

  /// Dünya (grid) noktasını, paint()'teki zoom dönüşümüyle aynı biçimde ekran
  /// koordinatına çevirir. Gece overlay'inin ÜSTÜNE çizilen efektler için.
  Offset _worldToScreen(double gx, double gy, Size size) {
    final s = gridToScreen(gx, gy, size, camera);
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
      final h = i * 73856093;
      final baseC = (h % 1000) / 1000.0 * kCols;
      final baseR = ((h ~/ 1000) % 1000) / 1000.0 * kRows;
      final gx = baseC + sin(time * 0.18 + i * 1.3) * 1.4;
      final gy = baseR + cos(time * 0.15 + i * 2.1) * 1.1;
      final p = _worldToScreen(gx, gy, size);
      if (p.dx < -20 ||
          p.dx > size.width + 20 ||
          p.dy < -20 ||
          p.dy > size.height + 20) {
        continue;
      }
      final tw = sin(time * 2.3 + i * 4.7) * 0.5 + 0.5;
      final a = (strength * tw * tw * 205).round().clamp(0, 220);
      if (a < 8) continue;
      final r = (1.6 + tw * 1.4) * zoom;
      // Blur yerine 2 katman concentric: dış soluk geniş, iç parlak çekirdek.
      _pFireflyGlow.color = Color.fromARGB(
        (a * 0.20).round(),
        0xC8,
        0xFF,
        0x9A,
      );
      canvas.drawCircle(p, r * 2.6, _pFireflyGlow);
      _pFireflyGlow.color = Color.fromARGB(
        (a * 0.40).round(),
        0xC8,
        0xFF,
        0x9A,
      );
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
      final h = i * 40503;
      final bc = (h % 1000) / 1000.0 * kCols;
      final br = (h ~/ 1000 % 1000) / 1000.0 * kRows;
      final gx =
          bc + sin(time * 0.35 + i * 1.1) * 1.6 + sin(time * 0.13 + i) * 0.9;
      final gy = br + cos(time * 0.30 + i * 1.7) * 1.1;
      final p = _worldToScreen(gx, gy, size);
      if (p.dx < -10 ||
          p.dx > size.width + 10 ||
          p.dy < -10 ||
          p.dy > size.height + 10) {
        continue;
      }
      final tw = sin(time * 1.3 + i * 2.3) * 0.5 + 0.5;
      final a = (strength * (0.35 + tw * 0.65) * 95).round().clamp(0, 110);
      if (a < 6) continue;
      final r = (0.8 + tw * 0.9) * zoom;
      _pPollen.color = Color.fromARGB(a, 0xFF, 0xF2, 0xC8);
      canvas.drawCircle(p, r, _pPollen);
    }
  }

  // ── Mevsim partikülleri (kar / yaprak) ─────────────────────────────────────
  // Ekran uzayında, lighting pass üstünde çizilen prosedürel atmosfer. Kış:
  // yavaşça süzülen kar; sonbahar: tumbling sürüklenen yaprak. Durumsuz —
  // konum index + time'dan türer. Pure atmosfer, game state'i etkilemez.
  void _drawSeasonParticles(Canvas canvas, Size size) {
    // Yoğun olay efektleri kendi partikül dilini kullanır; üzerine kar/yaprak
    // bindirmek hem okunurluğu hem de frame maliyetini gereksiz artırır.
    if (activeFx.contains(EventFx.festival) ||
        activeFx.contains(EventFx.meteorShower)) {
      return;
    }
    // DEV zorlaması mevsim switch'inden ÖNCE: kar yalnız kış dalında
    // çiziliyordu, yani yazın düğmeye basınca hiçbir şey olmuyordu.
    if (kDevForceSnowfall) {
      if (snowfallVisible(season: season, zoom: zoom)) _drawSnow(canvas, size);
      return;
    }
    switch (season) {
      case Season.winter:
        // Kapı SAF bir kuralda (bkz. winter.snowfallVisible): painter'ın içine
        // gömülü bir koşul yalnız kare çekerek sınanabilir, yani sessizce
        // bozulabilir. Zoom eşiği de orada — burada ikinci bir eşik tutmuyoruz.
        if (snowfallVisible(
          season: season,
          zoom: zoom,
          festival: activeFx.contains(EventFx.festival),
          meteorShower: activeFx.contains(EventFx.meteorShower),
          storm: activeFx.contains(EventFx.storm),
        )) {
          _drawSnow(canvas, size);
        }
      case Season.autumn:
        _drawLeaves(canvas, size);
      case Season.spring:
      case Season.summer:
        break;
    }
  }

  /// Kar tanesi ÇİZİMİ — nerede/ne kadar sorusu [SnowField]'ın (saf, testli);
  /// burası yalnız o taneleri boyar.
  ///
  /// İki bilinçli karar:
  ///  1) KRİSTAL KOL YOK. 2-3 px'lik bir taneye artı/yıldız kolları çizmek onu
  ///     kar tanesi değil, sahnenin üstünde duran keskin bir çizim hatası gibi
  ///     gösteriyordu. Bu ölçekte gerçek kar yumuşak bir noktadır; kristal
  ///     ancak makro çekimde okunur.
  ///  2) TANE SABİT BEYAZ DEĞİL. Kışın sahnenin arkası da neredeyse beyaz
  ///     (kar tile'ının ortalaması ~#DBE6F2), yani beyaz tane beyaz zeminde
  ///     yok oluyor; kar yalnız koyu bir çatıya/ağaca denk geldiğinde
  ///     görünüyordu. "Kar seyrek yağıyor" hissinin yarısı yoğunluk değil,
  ///     tam olarak buydu. Çözüm renkte: tane rengi hem GÜN IŞIĞINA hem
  ///     DERİNLİĞE göre soğuk gri-mavi ↔ kar beyazı arasında gezer, böylece
  ///     parlak karda koyu / karanlık sahnede açık kalır.
  ///
  /// Yumuşaklık ise blur yerine iç içe iki daire ile gelir (ateş böceklerinin
  /// ucuz numarası): soluk soğuk hale + üstünde çekirdek.
  void _drawSnow(Canvas canvas, Size size) {
    final lit = dayLight.clamp(0.0, 1.0);
    // Beyaz uç — gece mehtap mavisine kayar, gündüz saf kar beyazı.
    final wr = (0xDA + 0x20 * lit).round().clamp(0, 255);
    final wg = (0xE6 + 0x16 * lit).round().clamp(0, 255);
    final wb = (0xF6 + 0x09 * lit).round().clamp(0, 255);
    // Soğuk uç — hem hale rengi hem uzak tanelerin kendi rengi. Gece fazla
    // koyu kalmasın diye o da ışıkla açılır.
    final kr = (0x74 + 0x22 * lit).round().clamp(0, 255);
    final kg = (0x8A + 0x22 * lit).round().clamp(0, 255);
    final kb = (0xAE + 0x1A * lit).round().clamp(0, 255);
    // GÜNDÜZ TANE BEYAZ DEĞİLDİR. Sahnenin arkası kışın neredeyse tamamen
    // parlak kar; beyaz tane beyaz zeminde yalnız halesiyle görünüyor, yani
    // kar tanesi değil sabun köpüğü gibi okunuyordu. Gündüz çekirdek soğuk
    // ara tona çekilir (parlak kardan koyu, koyu ağaç/çatıdan açık — ikisinde
    // de okunur), gece sahne karardıkça beyaza döner.
    final toneLit = 0.32 + 0.68 * (1.0 - lit);
    // Hale artık kontrastın kendisi değil, yalnız kenar yumuşatması.
    const haloA = 0.26;
    // Gece görünürlük çarpanı — tam karanlıkta %58'e iner.
    final vis = 0.58 + 0.42 * lit;

    SnowField.forEach(
      (x, y, r, a, halo, tone) {
        final core = (a * vis * 255).round().clamp(0, 255);
        if (core < 3) return;
        final center = Offset(x, y);
        if (halo > 0) {
          _pSnow.color = Color.fromARGB(
            (core * haloA).round().clamp(0, 255),
            kr,
            kg,
            kb,
          );
          canvas.drawCircle(center, halo, _pSnow);
        }
        final t = tone * toneLit;
        _pSnow.color = Color.fromARGB(
          core,
          (kr + (wr - kr) * t).round().clamp(0, 255),
          (kg + (wg - kg) * t).round().clamp(0, 255),
          (kb + (wb - kb) * t).round().clamp(0, 255),
        );
        canvas.drawCircle(center, r, _pSnow);
      },
      size: size,
      time: time,
      zoom: zoom,
      perfMode: perfMode,
    );
  }

  // Sonbahar yaprakları — kardan az, daha geniş salınımlı + tumbling rotasyon.
  static const List<int> _leafColors = [
    0xFFD98A3D, // amber
    0xFFC4602A, // turuncu-pas
    0xFFB5471F, // kızıl
    0xFFE0A53A, // altın
    0xFF8A5A2B, // kahve
  ];

  void _drawLeaves(Canvas canvas, Size size) {
    if (zoom < 0.35) return;
    final count = perfMode ? 14 : (zoom < 0.6 ? 22 : 34);
    final yRange = size.height + 16;
    final lw = (5.5 * zoom).clamp(3.5, 8.0);
    final lh = (3.2 * zoom).clamp(2.0, 5.0);
    for (int i = 0; i < count; i++) {
      final baseX = ((i * 1733 + 311) % 997) / 997.0 * size.width;
      final yPhase = ((i * 619 + 131) % 991) / 991.0;
      final speed = 0.045 + (i % 5) * 0.011;
      final y = ((yPhase + time * speed) % 1.0) * yRange - 8;
      final x = baseX + sin(time * 0.5 + i * 1.7) * (22 + (i % 4) * 8);
      if (x < -12 || x > size.width + 12) continue;
      final tw = sin(time * 0.9 + i * 1.4) * 0.5 + 0.5;
      final a = (0.82 * (0.65 + tw * 0.35) * 255).round().clamp(0, 255);
      _pLeaf.color = Color(_leafColors[i % _leafColors.length]).withAlpha(a);
      canvas.save();
      canvas.translate(x, y);
      // Tumbling — düşerken kendi ekseninde döner (yaprak hissi).
      canvas.rotate(time * (1.0 + (i % 3) * 0.4) + i * 2.1);
      final leafPath = Path()
        ..moveTo(0, -lh)
        ..quadraticBezierTo(lw, -lh * 0.35, 0, lh)
        ..quadraticBezierTo(-lw, -lh * 0.35, 0, -lh)
        ..close();
      canvas.drawPath(leafPath, _pLeaf);
      // İnce damar, yakın yapraklarda şekli oval partikülden ayırır.
      if (zoom > 0.55) {
        _pLeafVein
          ..color = Color.fromARGB((a * 0.45).round(), 0x7A, 0x3E, 0x20)
          ..strokeWidth = (0.55 * zoom).clamp(0.45, 0.9);
        canvas.drawLine(
          Offset(0, -lh * 0.72),
          Offset(0, lh * 0.72),
          _pLeafVein,
        );
      }
      canvas.restore();
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

        if (p.dx < -30 ||
            p.dx > size.width + 30 ||
            p.dy < -30 ||
            p.dy > size.height + 30) {
          continue;
        }

        // Kanat çırpış — sin, ~4.5 Hz; her kuş kendi faz offset'iyle desync.
        final wing = sin(time * 9.0 + bird.wingPhaseOffset);
        final wingLen = 5.5 * zoom;
        // Wing tip Y: aşağı (positive) ↔ yukarı (negative) salınımı.
        final tipDy = wing * 2.2 * zoom;
        final leftTip = Offset(p.dx - wingLen, p.dy + tipDy);
        final rightTip = Offset(p.dx + wingLen, p.dy + tipDy);

        wingPaint.color = Color.fromARGB(fa, 0x33, 0x2E, 0x28);
        canvas.drawLine(leftTip, p, wingPaint);
        canvas.drawLine(p, rightTip, wingPaint);
        bodyPaint.color = Color.fromARGB(fa, 0x22, 0x1E, 0x18);
        canvas.drawCircle(p, 1.4 * zoom, bodyPaint);
      }
    }
  }

  // ── Ambient arı sürüleri ────────────────────────────────────────────────────
  // Her arı kovanı etrafında orbit eden küçük arılar. Hızlı kanat çırpışı
  // (buzz) + amber gövde. Gündüz görünür, gece kovana çekilip fade olur.
  void _drawBeeSwarms(Canvas canvas, Size size) {
    if (beeSwarms.isEmpty) return;
    // Gündüz görünür, alacakaranlıkta da hafif görünür kalsın (0.15'ten başlar).
    final dayFade = ((dayLight - 0.15) / 0.35).clamp(0.0, 1.0);
    final rainFade = (1.0 - (rainIntensity / 0.5)).clamp(0.0, 1.0);
    final visibility = dayFade * rainFade;
    if (visibility < 0.05) return;

    final bodyPaint = Paint();
    final wingPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.3 * zoom;

    for (final sw in beeSwarms) {
      for (final bee in sw.bees) {
        final (wx, wy) = sw.beeWorldPos(bee);
        final ground = _worldToScreen(wx, wy, size);
        final p = Offset(ground.dx, ground.dy + sw.beeBob(bee) * zoom);

        if (p.dx < -20 ||
            p.dx > size.width + 20 ||
            p.dy < -20 ||
            p.dy > size.height + 20) {
          continue;
        }

        final fa = (visibility * 255).round().clamp(0, 255);
        // Çok hızlı kanat çırpışı — ~5 Hz görsel buzz, her arı desync.
        final wing = sin(time * 30.0 + bee.wingPhase);
        final wlen = 2.8 * zoom;
        final tipDy = wing * 1.1 * zoom;
        wingPaint.color = Color.fromARGB((fa * 0.55).round(), 0xF0, 0xF0, 0xD0);
        canvas.drawLine(Offset(p.dx - wlen, p.dy - tipDy), p, wingPaint);
        canvas.drawLine(p, Offset(p.dx + wlen, p.dy - tipDy), wingPaint);
        // Gövde: koyu çekirdek + parlak amber halka — net okunur nokta.
        bodyPaint.color = Color.fromARGB(fa, 0x2A, 0x1C, 0x08);
        canvas.drawCircle(p, 2.6 * zoom, bodyPaint);
        bodyPaint.color = Color.fromARGB(fa, 0xFF, 0xC8, 0x48);
        canvas.drawCircle(p, 1.7 * zoom, bodyPaint);
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
    final hw = size.width / 2;
    final hh = size.height / 2;
    return (
      hw * (1.0 - inv) - kTileW, // minX
      hw * (1.0 + inv) + kTileW, // maxX
      hh * (1.0 - inv) - kTileH * 2, // minY
      hh * (1.0 + inv) + kTileH * 2, // maxY
    );
  }

  // ── Zemin ──────────────────────────────────────────────────────────────────
  // 1) Çim + kum + border = static layer → Picture cache (camera-bağımsız).
  // 2) Su tile'ları animasyonlu → her frame ayrı çizilir.
}
