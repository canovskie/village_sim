part of 'game_painter.dart';

/// ─── OLAY EFEKTLERİ & HAVA ──────────────────────────────────────────────────
///
/// Tam ekran (ekran-uzayı) geçişler: olayın kendi bespoke gösterisi
/// (şenlik/mahsul lekesi/mum töreni/ayin/meteor/düğün/bereket/canavar gözü) ve
/// yağmur katmanları.
///
/// SÖZLEŞME: bunlar sahnenin ÜSTÜNE çizilir, hiçbir varlığın konumunu ya da
/// derinliğini değiştirmez. Yeni bir olay efekti eklerken: EventFx'e bir değer,
/// buraya bir `_fxAd()` metodu, `paint()` içindeki aktif-fx dağıtımına bir satır.
///
/// Painter'ın alanlarına (time, activeFx, rainIntensity…) extension üzerinden
/// erişilir — aynı kütüphane olduğu için private erişim serbesttir.
// Bu iki havuz yalnız olay efektlerinde kullanılır — painter sınıfının statik
// alanı olmaktan çıkıp buraya, kullanıldıkları yere taşındı.
final _pEventOverlay = Paint()..isAntiAlias = false;
final _pFxParticle = Paint()..isAntiAlias = true;

extension _PainterFx on VillageGamePainter {
  void _drawEventOverlay(Canvas canvas, Size size) {
    // Ekran tonu — gece overlay ve lighting üstüne hafif renk filmi.
    if (eventTint.a > 0) {
      _pEventOverlay.color = eventTint;
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height),
        _pEventOverlay,
      );
    }
    if (activeFx.isEmpty) return;
    // Sahnenin yapısına bağlı partikül pass'leri.
    if (activeFx.contains(EventFx.festival)) _fxFestival(canvas, size);
    if (activeFx.contains(EventFx.cropBlight)) _fxCropBlight(canvas, size);
    if (activeFx.contains(EventFx.vigil)) _fxVigil(canvas, size);
    if (activeFx.contains(EventFx.cultRite)) _fxCultRite(canvas, size);
    if (activeFx.contains(EventFx.meteorShower)) _fxMeteorShower(canvas, size);
    if (activeFx.contains(EventFx.wedding)) _fxWedding(canvas, size);
    if (activeFx.contains(EventFx.harvestBounty)) {
      _fxHarvestBounty(canvas, size);
    }
    // fireOutbreak artık sahne overlay'inde değil — gerçek bina drawable'da
    // sprite üstüne alev + duman çiziyor (_BuildingDrawable._drawBurningOverlay).
    if (activeFx.contains(EventFx.beastEyes)) _fxBeastEyes(canvas, size);
    if (activeFx.contains(EventFx.storm) && season == Season.winter) {
      _drawSnowStorm(canvas, size);
    }
  }

  /// Kış fırtınası: normal karın üstüne binmeyen, rüzgârlı çapraz kar perdesi.
  /// Sabit slot/hash kullanır; her frame yeni liste oluşturmaz.
  void _drawSnowStorm(Canvas canvas, Size size) {
    final intensity = rainIntensity.clamp(0.55, 1.0);
    final count = perfMode ? 70 : 135;
    final wind = 24.0 + sin(time * 0.8) * 10.0;
    final p = _pRainBold;
    p.color = Color.fromRGBO(242, 249, 255, 0.62 * intensity);
    p.strokeWidth = perfMode ? 1.1 : 1.45;
    for (int i = 0; i < count; i++) {
      final x = ((i * 3571 + 911) % 997) / 997.0 * size.width;
      final phase = ((i * 619 + 73) % 991) / 991.0;
      final y = ((phase + time * (0.22 + (i % 5) * 0.018)) % 1.0) *
          (size.height + 40) - 20;
      final len = 7.0 + (i % 6) * 2.2;
      canvas.drawLine(
        Offset(x, y),
        Offset(x + wind * len / 18.0, y + len),
        p,
      );
    }
    final veil = ((intensity - 0.55) * 0.16).clamp(0.0, 0.08);
    _pRainMist.color = Color.fromRGBO(190, 215, 235, veil);
    canvas.drawRect(Offset.zero & size, _pRainMist);
  }

  // ── BESPOKE Şenlik ──────────────────────────────────────────────────────────
  // Üç imza katman: (1) ateşten komşu binalara gerilen, sarkan + sallanan flama
  // ipleri (üçgen bayraklar), (2) köy üstüne süzülen renkli konfeti, (3) ateşten
  // yükselen sıcak fenerler. Dilekçeyle "Hasat Şenliği" onaylanınca tetiklenir;
  // NPC'ler de ateşe toplanır + dans eder (sahne tarafı). Gerçek bir bayram.
  void _fxFestival(Canvas canvas, Size size) {
    const palette = [
      Color(0xFFE8554E), // kırmızı
      Color(0xFFF2A93B), // turuncu
      Color(0xFFF4D03F), // sarı
      Color(0xFF6FBE4A), // yeşil
      Color(0xFF4FA8D8), // mavi
      Color(0xFFB07BD0), // mor
    ];

    BuildingEntity? fire;
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        fire = b;
        break;
      }
    }

    if (fire != null) {
      final fireB = fire; // closure'larda non-null kullanım için
      final fx0 = _worldToScreen(fireB.col + 0.5, fireB.row + 0.5, size);
      final anchorTop =
          fx0 + Offset(0, -34 * zoom); // direk tepesi gibi yüksek nokta

      // (1) FLAMA İPLERİ — ateşten en yakın ~5 binaya.
      final others =
          buildings
              .where(
                (b) => !identical(b, fireB) && b.type != BuildingType.firepit,
              )
              .toList()
            ..sort((a, b) {
              int d2(BuildingEntity x) =>
                  (x.col - fireB.col) * (x.col - fireB.col) +
                  (x.row - fireB.row) * (x.row - fireB.row);
              return d2(a).compareTo(d2(b));
            });
      final cordPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4 * zoom
        ..isAntiAlias = true
        ..color = const Color(0xCC4A3520);
      final flagPaint = Paint()..isAntiAlias = true;
      final n = others.length < 5 ? others.length : 5;
      for (int k = 0; k < n; k++) {
        final b = others[k];
        final end =
            _worldToScreen(b.col + b.cols / 2.0, b.row + 0.1, size) +
            Offset(0, -26 * zoom);
        final mid = Offset(
          (anchorTop.dx + end.dx) / 2,
          (anchorTop.dy + end.dy) / 2,
        );
        final sag = (24 + sin(time * 1.3 + k) * 4) * zoom; // sallanan sarkma
        final ctrl = Offset(mid.dx, mid.dy + sag);
        canvas.drawPath(
          Path()
            ..moveTo(anchorTop.dx, anchorTop.dy)
            ..quadraticBezierTo(ctrl.dx, ctrl.dy, end.dx, end.dy),
          cordPaint,
        );
        // İp boyunca üçgen bayraklar.
        const flags = 6;
        for (int f = 1; f <= flags; f++) {
          final t = f / (flags + 1);
          final omt = 1 - t;
          final px =
              omt * omt * anchorTop.dx + 2 * omt * t * ctrl.dx + t * t * end.dx;
          final py =
              omt * omt * anchorTop.dy + 2 * omt * t * ctrl.dy + t * t * end.dy;
          final sway = sin(time * 3.0 + f * 0.7 + k) * 1.6 * zoom;
          final w = 3.6 * zoom, h = 7.0 * zoom;
          flagPaint.color = palette[(f + k) % palette.length];
          canvas.drawPath(
            Path()
              ..moveTo(px - w, py)
              ..lineTo(px + w, py)
              ..lineTo(px + sway, py + h)
              ..close(),
            flagPaint,
          );
        }
      }

      // (3) YÜKSELEN FENERLER — ateşten 4 sıcak küre, yavaş yükselir + flicker.
      for (int i = 0; i < 4; i++) {
        final phase = (time * 0.13 + i * 0.27) % 1.0;
        final ly = fx0.dy - phase * 200 * zoom - 6 * zoom;
        final lx =
            fx0.dx +
            sin(time * 0.6 + i * 1.7) * 16 * zoom +
            (i - 1.5) * 9 * zoom;
        final flick = 0.8 + sin(time * 9 + i) * 0.2;
        final a = ((1 - phase).clamp(0.0, 1.0) * flick * 220).round().clamp(
          0,
          220,
        );
        canvas.drawCircle(
          Offset(lx, ly),
          7 * zoom,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = Color.fromARGB((a * 0.5).round(), 0xFF, 0x9E, 0x3C),
        );
        canvas.drawCircle(
          Offset(lx, ly),
          3.3 * zoom,
          Paint()..color = Color.fromARGB(a, 0xFF, 0xE4, 0x9E),
        );
      }
    }

    // (2) KONFETİ — köy üstüne süzülen renkli kağıtlar (ekran-uzayı, döner).
    const confettiCount = 54;
    final confPaint = Paint()..isAntiAlias = true;
    for (int i = 0; i < confettiCount; i++) {
      final seedX = ((i * 73) % 100) / 100.0;
      final fall = (time * (0.10 + (i % 5) * 0.015) + i * 0.13) % 1.0;
      final x = seedX * size.width + sin(time * 1.6 + i) * 12;
      final y = fall * (size.height + 40) - 20;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(time * 2.2 + i);
      confPaint.color = palette[i % palette.length].withValues(alpha: 0.85);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset.zero,
          width: 3.2 * zoom,
          height: 5.4 * zoom,
        ),
        confPaint,
      );
      canvas.restore();
    }
  }

  // ── BESPOKE Hasat Mantarı (blight) ──────────────────────────────────────────
  // Tarlalara yayılan hastalık: sırayla enfekte olan tile'larda hastalıklı
  // mor-gri leke + pörtleyip büyüyen mantar şapkaları + yukarı süzülen yeşil
  // sporlar. Şenlikten tamamen farklı görünüm + farklı etki (ürün çürür).
  void _fxCropBlight(Canvas canvas, Size size) {
    if (farmTiles.isEmpty) return;
    final p = Paint()..isAntiAlias = true;
    for (int i = 0; i < farmTiles.length; i++) {
      final t = farmTiles[i];
      // Yayılma: tile'lar index sırasına göre kademeli enfekte olur.
      final infect = ((time * 0.22) - i * 0.07).clamp(0.0, 1.0);
      if (infect <= 0) continue;
      final base = _worldToScreen(t.col + 0.5, t.row + 0.5, size);

      // 1) Hastalıklı leke — tile üstünde mor-gri oval (büyüyerek koyulaşır).
      final blotchA = (infect * 95).round().clamp(0, 95);
      p.color = Color.fromARGB(blotchA, 0x5E, 0x42, 0x66);
      canvas.drawOval(
        Rect.fromCenter(
          center: base,
          width: 26 * zoom * (0.5 + infect * 0.5),
          height: 14 * zoom * (0.5 + infect * 0.5),
        ),
        p,
      );

      // 2) Mantar şapkaları — büyüdükçe daha çok kapak (max 4).
      final caps = (infect * 4).round();
      for (int c = 0; c < caps; c++) {
        final ang = i * 1.3 + c * 1.7;
        final grow = ((infect - c * 0.2).clamp(0.0, 1.0));
        final mx = base.dx + cos(ang) * 8 * zoom;
        final my = base.dy + sin(ang) * 4.5 * zoom;
        // sap
        p.color = const Color(0xFFCDBFA0);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(mx, my),
            width: 1.5 * zoom,
            height: 3.0 * zoom * grow,
          ),
          p,
        );
        // şapka
        p.color = const Color(0xFF7E5A3C);
        canvas.drawCircle(
          Offset(mx, my - 2.2 * zoom * grow),
          2.6 * zoom * grow,
          p,
        );
        p.color = const Color(0xFF9A7350);
        canvas.drawCircle(
          Offset(mx - 0.6 * zoom, my - 2.6 * zoom * grow),
          1.1 * zoom * grow,
          p,
        );
      }

      // 3) Spor — yukarı süzülen yeşilimsi nokta (hastalık havada).
      final sp = (time * 0.65 + i * 0.33) % 1.0;
      final spA = ((1 - sp) * infect * 130).round().clamp(0, 130);
      p.color = Color.fromARGB(spA, 0x9C, 0xBA, 0x58);
      canvas.drawCircle(
        Offset(
          base.dx + sin(time * 2 + i) * 5 * zoom,
          base.dy - sp * 22 * zoom,
        ),
        1.5 * zoom,
        p,
      );
    }
  }

  // ── BESPOKE Bereketli Hasat (harvestBounty) ─────────────────────────────────
  // Mantarın pozitif karşıtı: tarlalar kademeli olarak altın bir ışıltıyla
  // olgunlaşır — sıcak hale + dalgalanan başak demetleri + yukarı süzülen
  // bereket zerreleri (altın toz). Cömert, ferah, hasat sevinci.
  void _fxHarvestBounty(Canvas canvas, Size size) {
    if (farmTiles.isEmpty) return;
    final p = Paint()..isAntiAlias = true;
    for (int i = 0; i < farmTiles.length; i++) {
      final t = farmTiles[i];
      // Olgunlaşma dalgası — tile'lar sırayla "altına döner".
      final ripe = ((time * 0.30) - i * 0.06).clamp(0.0, 1.0);
      if (ripe <= 0) continue;
      final base = _worldToScreen(t.col + 0.5, t.row + 0.5, size);

      // 1) Sıcak altın hale — tile üstünde yumuşak nabız atan ışıltı (additive).
      final pulse = 0.7 + sin(time * 2.2 + i * 0.5) * 0.3;
      final haloA = (ripe * pulse * 70).round().clamp(0, 70);
      p
        ..blendMode = BlendMode.plus
        ..color = Color.fromARGB(haloA, 0xF6, 0xC8, 0x4A);
      canvas.drawOval(
        Rect.fromCenter(
          center: base,
          width: 30 * zoom * (0.6 + ripe * 0.4),
          height: 16 * zoom * (0.6 + ripe * 0.4),
        ),
        p,
      );
      p.blendMode = BlendMode.srcOver;

      // 2) Olgun başak demetleri — büyüdükçe daha çok sap, hafifçe rüzgârda sallanır.
      final stalks = (ripe * 4).round();
      for (int s = 0; s < stalks; s++) {
        final ang = i * 1.1 + s * 1.6;
        final grow = ((ripe - s * 0.18).clamp(0.0, 1.0));
        if (grow <= 0) continue;
        final sway = sin(time * 1.8 + i + s) * 1.4 * zoom;
        final sx = base.dx + cos(ang) * 8 * zoom;
        final sy = base.dy + sin(ang) * 4.5 * zoom;
        final topY = sy - 7.0 * zoom * grow;
        // sap
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2 * zoom
          ..color = const Color(0xFFB98C3A);
        canvas.drawLine(Offset(sx, sy), Offset(sx + sway, topY), p);
        // başak başı — altın damla
        p
          ..style = PaintingStyle.fill
          ..color = const Color(0xFFF2CE5C);
        canvas.drawCircle(Offset(sx + sway, topY), 2.0 * zoom * grow, p);
        p.color = const Color(0xFFFCEBA0);
        canvas.drawCircle(
          Offset(sx + sway - 0.5 * zoom, topY - 0.5 * zoom),
          0.9 * zoom * grow,
          p,
        );
      }

      // 3) Bereket zerresi — yukarı süzülen altın toz (havada ışıldayan bolluk).
      final mt = (time * 0.5 + i * 0.4) % 1.0;
      final mA = ((1 - mt) * ripe * 150).round().clamp(0, 150);
      p
        ..blendMode = BlendMode.plus
        ..color = Color.fromARGB(mA, 0xFF, 0xE6, 0x9C);
      canvas.drawCircle(
        Offset(
          base.dx + sin(time * 1.6 + i) * 6 * zoom,
          base.dy - mt * 24 * zoom,
        ),
        1.4 * zoom,
        p,
      );
      p.blendMode = BlendMode.srcOver;
    }
  }

  // ── BESPOKE Matem (vigil) ───────────────────────────────────────────────────
  // Ateş çevresinde yere dizilmiş, tek tek titreyen mum halkası + her mumdan
  // yavaşça yükselen soluk "ruh" kıvılcımı. Dingin, hüzünlü — şenliğin tersi.
  void _fxVigil(Canvas canvas, Size size) {
    BuildingEntity? fire;
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        fire = b;
        break;
      }
    }
    if (fire == null) return;
    final c0 = _worldToScreen(fire.col + 0.5, fire.row + 0.5, size);
    final glow = Paint()..blendMode = BlendMode.plus;
    final core = Paint()..isAntiAlias = true;
    const candles = 12;
    for (int i = 0; i < candles; i++) {
      final ang = i * (2 * pi / candles);
      // İzometrik yassı halka (y ekseni 0.55).
      final cx = c0.dx + cos(ang) * 40 * zoom;
      final cy = c0.dy + sin(ang) * 22 * zoom;
      final flick = 0.75 + sin(time * 7.0 + i * 1.7) * 0.25;
      // Mum tabanı (küçük koyu çubuk)
      core.color = const Color(0xFF2A2018);
      canvas.drawRect(
        Rect.fromCenter(
          center: Offset(cx, cy),
          width: 1.6 * zoom,
          height: 3.2 * zoom,
        ),
        core,
      );
      // Alev halesi + çekirdek
      glow.color = Color.fromARGB((flick * 90).round(), 0xFF, 0x9A, 0x3A);
      canvas.drawCircle(Offset(cx, cy - 3 * zoom), 5.5 * zoom * flick, glow);
      core.color = Color.fromARGB((flick * 235).round(), 0xFF, 0xE6, 0xB0);
      canvas.drawCircle(Offset(cx, cy - 3 * zoom), 1.5 * zoom, core);
      // Yükselen soluk ruh kıvılcımı
      final sp = (time * 0.4 + i * 0.5) % 1.0;
      final a = ((1 - sp) * 90).round().clamp(0, 90);
      core.color = Color.fromARGB(a, 0xCF, 0xD8, 0xE6);
      canvas.drawCircle(
        Offset(cx, cy - 4 * zoom - sp * 34 * zoom),
        1.3 * zoom,
        core,
      );
    }
  }

  // ── BESPOKE Ayin / Din (cultRite) ───────────────────────────────────────────
  // Ateş çevresinde yere çizilmiş, nabız atan parlak çember + üstünde dönen
  // okült rünler (küçük geometrik glifler) + merkezde tuhaf mor-teal ışıltı.
  void _fxCultRite(Canvas canvas, Size size) {
    BuildingEntity? fire;
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        fire = b;
        break;
      }
    }
    // Firepit varsa onun üstünde; yoksa köy MERKEZİNE world-anchor (ekran
    // merkezine sabitlersek kamera pan'inde ayin çemberi kayardı — ucuz görünür).
    final c0 = fire != null
        ? _worldToScreen(fire.col + 0.5, fire.row + 0.5, size)
        : _worldToScreen(kCols / 2, kRows / 2, size);

    final pulse = sin(time * 1.6) * 0.5 + 0.5;
    final ringR = 46 * zoom;

    // Yere çizilmiş izometrik çember (nabız atan teal-mor).
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = (1.4 + pulse * 1.2) * zoom
      ..blendMode = BlendMode.plus
      ..color = Color.fromARGB((70 + pulse * 90).round(), 0x9A, 0x6C, 0xE0);
    canvas.drawOval(
      Rect.fromCenter(center: c0, width: ringR * 2, height: ringR * 1.1),
      ring,
    );
    // İkinci iç çember (teal).
    ring.color = Color.fromARGB((50 + pulse * 70).round(), 0x4C, 0xC8, 0xC0);
    canvas.drawOval(
      Rect.fromCenter(center: c0, width: ringR * 1.3, height: ringR * 0.72),
      ring,
    );

    // Merkez okült ışıltı.
    canvas.drawCircle(
      c0,
      (10 + pulse * 8) * zoom,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Color.fromARGB((60 + pulse * 70).round(), 0x8A, 0x60, 0xD8),
    );

    // Dönen rünler — 6 küçük geometrik glif çember üstünde.
    final rune = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3 * zoom
      ..blendMode = BlendMode.plus
      ..isAntiAlias = true;
    const runes = 6;
    for (int i = 0; i < runes; i++) {
      final ang = time * 0.6 + i * (2 * pi / runes);
      final rx = c0.dx + cos(ang) * ringR * 0.92;
      final ry = c0.dy + sin(ang) * ringR * 0.5;
      final bob = sin(time * 3 + i) * 2 * zoom;
      final p = Offset(rx, ry + bob);
      final a = (150 + sin(time * 4 + i) * 60).round().clamp(0, 230);
      rune.color = Color.fromARGB(a, 0xC8, 0xB0, 0xF0);
      final s = 3.2 * zoom;
      // Glif türü i'ye göre: üçgen / artı / baklava.
      switch (i % 3) {
        case 0:
          canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - s)
              ..lineTo(p.dx + s, p.dy + s)
              ..lineTo(p.dx - s, p.dy + s)
              ..close(),
            rune,
          );
        case 1:
          canvas.drawLine(Offset(p.dx - s, p.dy), Offset(p.dx + s, p.dy), rune);
          canvas.drawLine(Offset(p.dx, p.dy - s), Offset(p.dx, p.dy + s), rune);
        default:
          canvas.drawPath(
            Path()
              ..moveTo(p.dx, p.dy - s)
              ..lineTo(p.dx + s, p.dy)
              ..lineTo(p.dx, p.dy + s)
              ..lineTo(p.dx - s, p.dy)
              ..close(),
            rune,
          );
      }
    }
  }

  // ── BESPOKE Göktaşı yağmuru (meteorShower) ──────────────────────────────────
  // Ekran-uzayında gökyüzünü çaprazlama geçen küçük kayan yıldızlar (parlak baş
  // + sönen kuyruk) + periyodik olarak kratere doğru süzülen büyük bir meteor ve
  // ardından çarpma flaşı. Additive — gece göz alıcı, gündüz daha hafif.
  void _fxMeteorShower(Canvas canvas, Size size) {
    final glow = Paint()
      ..isAntiAlias = true
      ..blendMode = BlendMode.plus;
    final night = (1 - dayLight).clamp(0.0, 1.0);
    final vis = 0.45 + night * 0.55; // gece daha parlak

    const dirx = 0.82, diry = 0.57; // çapraz yön (sağ-aşağı)

    // Küçük kayan yıldızlar — üst gökyüzü bandında akar.
    const stars = 16;
    for (int i = 0; i < stars; i++) {
      final speed = 0.5 + (i % 5) * 0.12;
      final ph = (time * speed + i * 0.137) % 1.0;
      final sx = ((i * 137.0) % size.width) - size.width * 0.15;
      final sy = (i * 53.0) % (size.height * 0.55) - size.height * 0.1;
      final travel = size.width * 0.5;
      final hx = sx + dirx * travel * ph;
      final hy = sy + diry * travel * ph;
      final fade = sin(ph * pi).clamp(0.0, 1.0); // uçlarda doğal fade
      final a = (fade * 200 * vis).round().clamp(0, 230);
      if (a <= 0) continue;
      final tailLen = 26.0 * zoom;
      final tx = hx - dirx * tailLen, ty = hy - diry * tailLen;
      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = 1.6 * zoom
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(Offset(tx, ty), Offset(hx, hy), [
            const Color(0x00FFFFFF),
            Color.fromARGB(a, 0xCF, 0xE4, 0xFF),
          ]),
      );
      glow.color = Color.fromARGB(a, 0xFF, 0xFF, 0xF2);
      canvas.drawCircle(Offset(hx, hy), 1.8 * zoom, glow);
    }

    // Büyük bolid — ara sıra gökyüzünü baştan başa geçen parlak, yavaş meteor.
    // Düşme/çarpma yok: sadece göz alıcı, uzun kuyruklu bir geçiş (cozy).
    final bp = (time * 0.16) % 1.0;
    if (bp < 0.6) {
      final t = bp / 0.6;
      final hx = -size.width * 0.1 + dirx * size.width * 1.2 * t;
      final hy = size.height * 0.06 + diry * size.width * 1.2 * t;
      final fade = sin(t * pi).clamp(0.0, 1.0);
      final a = (fade * 235 * vis).round().clamp(0, 245);
      const tailLen = 70.0;
      final tx = hx - dirx * tailLen * zoom, ty = hy - diry * tailLen * zoom;
      canvas.drawLine(
        Offset(tx, ty),
        Offset(hx, hy),
        Paint()
          ..blendMode = BlendMode.plus
          ..strokeWidth = 2.8 * zoom
          ..strokeCap = StrokeCap.round
          ..shader = ui.Gradient.linear(Offset(tx, ty), Offset(hx, hy), [
            const Color(0x00FFD9A0),
            Color.fromARGB(a, 0xFF, 0xE0, 0xB0),
          ]),
      );
      glow.color = Color.fromARGB(a, 0xFF, 0xF4, 0xDC);
      canvas.drawCircle(Offset(hx, hy), 3.2 * zoom, glow);
    }
  }

  // ── BESPOKE Düğün (wedding) ─────────────────────────────────────────────────
  // Ateş başında yükselen kalpler + tepeden süzülen renkli yaprak/konfeti + sıcak
  // bir taban parıltısı. Şenliğin küçük, sıcak kardeşi (çift dansı NPC tarafında).
  void _fxWedding(Canvas canvas, Size size) {
    BuildingEntity? fire;
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        fire = b;
        break;
      }
    }
    if (fire == null) return;
    final c0 = _worldToScreen(fire.col + 0.5, fire.row + 0.5, size);
    final fill = Paint()..isAntiAlias = true;

    // 1) Sıcak taban parıltısı (nabız atan).
    final pulse = 0.7 + sin(time * 2.2) * 0.3;
    canvas.drawCircle(
      Offset(c0.dx, c0.dy),
      30 * zoom * pulse,
      Paint()
        ..blendMode = BlendMode.plus
        ..color = Color.fromARGB((26 * pulse).round(), 0xFF, 0xC8, 0xD8),
    );

    // 2) Yükselen kalpler — ateş çevresinden çıkıp süzülerek yukarı kaybolur.
    const hearts = 10;
    for (int i = 0; i < hearts; i++) {
      final sp = (time * 0.5 + i * 0.617) % 1.0;
      final baseAng = i * (2 * pi / hearts);
      final spreadX = cos(baseAng) * 30 * zoom;
      final hx = c0.dx + spreadX + sin(time * 2 + i) * 5 * zoom;
      final hy = c0.dy + 4 * zoom - sp * 60 * zoom;
      final a = (sin(sp * pi) * 220).round().clamp(0, 220);
      if (a <= 0) continue;
      final s = (2.0 + (i % 3) * 0.7) * zoom * (0.7 + sp * 0.5);
      fill.color = Color.fromARGB(a, 0xFF, 0x6E, 0x8C);
      _drawHeart(canvas, Offset(hx, hy), s, fill);
    }

    // 3) Süzülen yaprak/konfeti — tepeden ateş çevresine yavaşça düşer.
    const petals = 16;
    const cols = [
      Color(0xFFF6C5D8),
      Color(0xFFF7E59B),
      Color(0xFFBFE3C0),
      Color(0xFFBFD4F2),
      Color(0xFFF2B6A0),
    ];
    for (int i = 0; i < petals; i++) {
      final sp = (time * 0.35 + i * 0.41) % 1.0;
      final px =
          c0.dx + cos(i * 1.7) * 46 * zoom + sin(time * 1.6 + i) * 9 * zoom;
      final py = c0.dy - 46 * zoom + sp * 70 * zoom;
      final a = (sin(sp * pi) * 200).round().clamp(0, 200);
      if (a <= 0) continue;
      fill.color = cols[i % cols.length].withValues(alpha: a / 255);
      // ince eğik oval yaprak
      canvas.save();
      canvas.translate(px, py);
      canvas.rotate(sin(time * 2 + i) * 0.9);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 3.4 * zoom,
          height: 1.6 * zoom,
        ),
        fill,
      );
      canvas.restore();
    }
  }

  /// Küçük dolu kalp — [c] merkez, [s] yarı-genişlik. _fxWedding için.
  void _drawHeart(Canvas canvas, Offset c, double s, Paint p) {
    canvas.drawCircle(Offset(c.dx - s * 0.5, c.dy - s * 0.3), s * 0.55, p);
    canvas.drawCircle(Offset(c.dx + s * 0.5, c.dy - s * 0.3), s * 0.55, p);
    canvas.drawPath(
      Path()
        ..moveTo(c.dx - s, c.dy - s * 0.1)
        ..lineTo(c.dx, c.dy + s)
        ..lineTo(c.dx + s, c.dy - s * 0.1)
        ..close(),
      p,
    );
  }

  // Hayvan baskını — gece firepit etrafında ağaç hattında kızıl göz çiftleri.
  // Gözler SÜREKLİ yavaşça gezinir (adım-atlama YOK: eski `(time/4).floor()`
  // her 4 sn ışınlıyordu) ve YUMUŞAK parıldayıp kırpışır (alpha lerp; eski ikili
  // aç-kapa pat söndürüyordu). Kavram (gövdesiz parlayan gözler) kasıtlı.
  void _fxBeastEyes(Canvas canvas, Size size) {
    if (dayLight > 0.4) return;
    for (int i = 0; i < 4; i++) {
      // Stabil taban (seed=i) + zamana bağlı sürekli ağır drift (kurtlar dolaşır).
      final baseAng = i * 1.7;
      final ang = baseAng + sin(time * 0.13 + i) * 0.35;
      final dist = 13.0 + (i % 3) * 2.0 + sin(time * 0.09 + i * 2.1) * 1.2;
      final gx = kCols / 2 + cos(ang) * dist;
      final gy = kRows / 2 + sin(ang) * dist;
      final p = _worldToScreen(gx, gy, size);
      // Yumuşak parıltı + ara sıra kısa kırpışma (alpha, pat söner-yanar DEĞİL).
      final glow = 0.45 + 0.30 * sin(time * 0.9 + i * 1.3);
      final blink = (sin(time * 2.1 + i * 2.7) < -0.85) ? 0.15 : 1.0;
      final a = (glow * blink * 255).round().clamp(0, 210);
      if (a <= 4) continue;
      _pFxParticle.color = Color.fromARGB(a, 0xFF, 0x30, 0x20);
      canvas.drawCircle(p + Offset(-3 * zoom, 0), 1.6 * zoom, _pFxParticle);
      canvas.drawCircle(p + Offset(3 * zoom, 0), 1.6 * zoom, _pFxParticle);
    }
  }

  // ── Yağmur ────────────────────────────────────────────────────────────────
  // 3 parallax katman + ön katmanda motion-trail + sahnede dağıtık ground
  // splash + yoğun yağmurda hafif blue-grey atmosfer perdesi.
  //
  // Tasarım kararları:
  //  • Katmanlar: uzak (kısa/soluk/yavaş), orta (normal), ön (uzun/parlak/hızlı
  //    + soluk tail). Her katman kendi X/Y hash'i (örtüşmesin) ve scroll
  //    hızıyla → derinlik hissi.
  //  • Wind sway: tek global sin() — tüm katmanlara aynı oranda uygulanır
  //    ki yağmur "bir bütün" hissetsin, salınımlar farklı yöne gitmesin.
  //  • Ground splash: ekran uzayında sabit slot'lar, her slot kendi faz +
  //    periyoduyla tek-shot animasyon (crown + 2 droplet + iso ring). Yer
  //    sınırı yok (bazıları su tile üstüne düşer ama orada renderer'ın halkası
  //    zaten var, çakışma fark edilmez).

  void _drawRain(Canvas canvas, Size size) {
    // Kış yağışı kar katmanına dönüşür; iki tam ekran partikül sistemi aynı
    // anda çalışmaz. Festival konfeti de yağmurla üst üste bindirilmez.
    if (rainIntensity <= 0 ||
        season == Season.winter ||
        activeFx.contains(EventFx.festival)) {
      return;
    }
    final intensity = rainIntensity.clamp(0.0, 1.0);

    // Wind salınımı — yavaş sin(), tüm katmanlara aynı oran. Damla uzunluğu
    // ile çarpılarak slant (x kayması) verir.
    final wind = sin(time * 0.35) * 0.10 + 0.06; // -0.04..0.16 (eğim oranı)

    // PERF: damla sayıları düşürüldü (AA kapalı arka/orta + kısılmış sayı →
    // per-frame drawLine maliyeti ~3× azaldı). perfMode'da daha da agresif.
    // Arka katman — kısa, soluk, yavaş; çok damla → sürekli "perde" hissi
    _drawRainLayer(
      canvas,
      size,
      count: perfMode ? 0 : 70,
      speed: 0.34,
      length: 8.0,
      slant: wind * 8.0,
      r: 130,
      g: 165,
      b: 200,
      alpha: 0.22 * intensity,
      seed: 1731,
      bold: false,
    );
    // Orta katman — yoğunluk asıl katman
    _drawRainLayer(
      canvas,
      size,
      count: perfMode ? 60 : 110,
      speed: 0.52,
      length: 14.0,
      slant: wind * 14.0,
      r: 190,
      g: 220,
      b: 245,
      alpha: 0.38 * intensity,
      seed: 4221,
      bold: false,
    );
    // Ön katman — uzun, parlak + soluk arka iz; sayısı az tutulur ki
    // bireysel damlalar okunsun, perde değil hareket hissi versin.
    _drawRainLayer(
      canvas,
      size,
      count: perfMode ? 30 : 50,
      speed: 0.78,
      length: 22.0,
      slant: wind * 22.0,
      r: 225,
      g: 242,
      b: 255,
      alpha: 0.50 * intensity,
      seed: 8917,
      bold: true,
      withTail: !perfMode,
    );

    // Yere çarpma — sahnede dağıtık periyodik splash slot'ları. perfMode'da atla.
    if (!perfMode) _drawGroundSplashes(canvas, size, intensity);

    // Yoğun yağmurda hafif mavi-gri perde (atmosfer derinliği).
    if (intensity > 0.5) {
      final tintA = ((intensity - 0.5) * 0.30).clamp(0.0, 0.14);
      _pRainMist.color = Color.fromRGBO(150, 175, 200, tintA);
      canvas.drawRect(Offset.zero & size, _pRainMist);
    }
  }

  void _drawRainLayer(
    Canvas canvas,
    Size size, {
    required int count,
    required double speed,
    required double length,
    required double slant,
    required int r,
    required int g,
    required int b,
    required double alpha,
    required int seed,
    required bool bold,
    bool withTail = false,
  }) {
    final visible = (count * rainIntensity).round();
    if (visible == 0 || alpha < 0.01) return;

    final paint = bold ? _pRainBold : _pRain;
    paint.color = Color.fromRGBO(r, g, b, alpha.clamp(0.0, 1.0));

    // Y aralığı ekran dışına biraz uzar → kenarlarda damla "pop" etmez.
    final yRange = size.height + length * 2;

    for (int i = 0; i < visible; i++) {
      // Asal mod'lar → katmanlar arası örtüşmesiz dağıtım.
      final x = ((i * 1733 + seed + 97) % 997) / 997.0 * size.width;
      final yPhase = ((i * 619 + seed + 53) % 991) / 991.0;
      final y = ((yPhase + time * speed) % 1.0) * yRange - length;

      canvas.drawLine(Offset(x, y), Offset(x + slant, y + length), paint);

      if (withTail) {
        // Motion trail — damlanın arkasında yarım boy, ~%35 alpha çizgi.
        // Hızı görsel olarak çoğaltır; "damla şu an yağıyor" hissi verir.
        _pRainTail.color = Color.fromRGBO(
          r,
          g,
          b,
          (alpha * 0.38).clamp(0.0, 1.0),
        );
        canvas.drawLine(
          Offset(x - slant * 0.55, y - length * 0.55),
          Offset(x, y),
          _pRainTail,
        );
      }
    }
  }

  void _drawGroundSplashes(Canvas canvas, Size size, double intensity) {
    // Sahne genelinde sabit slot pozisyonları + her slot kendi faz/periyod.
    // count yoğunluğa lineer ölçek — zayıf yağmurda az splash, kuvvetlide çok.
    // PERF: 55→38 (her splash ~4 AA op; toplam çarpan).
    final count = (38 * intensity).round();
    if (count == 0) return;

    for (int i = 0; i < count; i++) {
      final px = ((i * 7919 + 137) % 997) / 997.0 * size.width;
      final py = ((i * 5717 + 281) % 991) / 991.0 * size.height;
      // Her slot 1.4–2.0 sn'de bir splash (period kişiye özel).
      final period = 1.4 + ((i * 41) % 100) / 100.0 * 0.6;
      final phaseOff = ((i * 3413 + 89) % 983) / 983.0 * period;
      final cycT = ((time + phaseOff) % period) / period;
      // İlk %22'lik dilim splash visible — uzun ömür ⇒ frame'ler arasında
      // damla sürekli hareket halindeymiş gibi okunur (pop yerine akış).
      if (cycT > 0.22) continue;
      final life = cycT / 0.22; // 0..1 splash içinde
      final invLife = 1.0 - life;
      // Görsel zarflama — ortada parlak, başta/sonda yumuşak yok ol.
      final envelope = (life < 0.18)
          ? life /
                0.18 // ease-in (pop yumuşatılır)
          : invLife * invLife; // ease-out

      // Crown — kısa AA çizgi (yuvarlak cap), aniden patlamaz.
      if (life < 0.5) {
        final crownH = 3.2 * (1.0 - life * 1.8).clamp(0.0, 1.0);
        final cA = (envelope * 220 * intensity).toInt().clamp(0, 220);
        if (cA > 5 && crownH > 0.4) {
          _pSplash.color = Color.fromARGB(cA, 220, 240, 255);
          canvas.drawLine(
            Offset(px, py + 0.3),
            Offset(px, py - crownH),
            _pSplash
              ..strokeWidth = 1.1
              ..strokeCap = StrokeCap.round,
          );
          // _pSplash'ı sonraki droplet fill'i için fill moda döndür
          // (drawLine PaintingStyle değiştirmez ama strokeWidth state kalır).
        }
      }

      // 2 sıçrayan damlacık — yana uçar, hafif yukarı sonra düşer (arc).
      // AA daireler, rectangle yerine — kenar yumuşak, sub-pixel akar.
      final fly = life * 4.8;
      final arcY = -1.6 + life * 2.6;
      final dA = (envelope * 200 * intensity).toInt().clamp(0, 200);
      if (dA > 5) {
        _pSplash.color = Color.fromARGB(dA, 215, 235, 252);
        canvas.drawCircle(Offset(px - fly, py + arcY), 0.85, _pSplash);
        canvas.drawCircle(Offset(px + fly, py + arcY), 0.85, _pSplash);
      }

      // Genişleyen iso oval ring (2:1 squash — yer hissi).
      // Ring life boyu yaşar (en uzun ömürlü katman), envelope yerine
      // smooth invLife² → smooth fade.
      final ringW = 1.0 + life * 8.0;
      final ringH = ringW * 0.42;
      final rA = (invLife * invLife * 160 * intensity).toInt().clamp(0, 160);
      if (rA > 4) {
        _pSplashRing.color = Color.fromARGB(rA, 200, 225, 245);
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(px, py + 1),
            width: ringW,
            height: ringH,
          ),
          _pSplashRing,
        );
      }
    }
  }
}
