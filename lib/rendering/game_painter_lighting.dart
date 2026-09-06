part of 'game_painter.dart';

/// IŞIK GEÇİŞİ — ocak sıcaklığı halkaları, etki halkası, 3 katmanlı ışık (KİLİTLİ), bina gölgeleri, gün atmosferi.
extension _LightingPass on VillageGamePainter {

  /// Ocağın ısıttığı bölge — çadır yerleştirilirken zemine iki izometrik oval:
  /// içteki dolu/sıcak alan (çadır kışı atlatır), dıştaki soluk sınır (ötesinde
  /// ocağın hiçbir faydası kalmaz). Arası yumuşak bant.
  void _drawHearthWarmthRings(Canvas canvas, int gc, int gr, Size size) {
    BuildingEntity? fire;
    for (final b in buildings) {
      if (b.type == BuildingType.firepit) {
        fire = b;
        break;
      }
    }
    if (fire == null) return; // ocak yoksa gösterilecek sıcak da yok

    final fx = fire.col + fire.cols * 0.5;
    final fy = fire.row + fire.rows * 0.5;
    final center = gridToScreen(fx, fy, size, camera);

    // Hayaletin durduğu yer sıcak mı — halkanın rengi bunu söyler.
    final warm =
        hearthWarmth(dx: (gc + 0.5) - fx, dy: (gr + 0.5) - fy, burning: true) >=
        kColdShelterThreshold;
    final tint = warm ? const Color(0xFFFFC062) : const Color(0xFF9FB6C8);

    Rect ovalFor(double r) => Rect.fromCenter(
      center: center,
      width: r * kTileW * 2,
      height: r * kTileH * 2,
    );

    // İç bölge: ocağın tam ısıttığı mahalle.
    canvas.drawOval(
      ovalFor(kHearthWarmRadius),
      Paint()
        ..color = tint.withAlpha(warm ? 0x2A : 0x18)
        ..isAntiAlias = true,
    );
    canvas.drawOval(
      ovalFor(kHearthWarmRadius),
      Paint()
        ..color = tint.withAlpha(0xAA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..isAntiAlias = true,
    );
    // Dış sınır: buradan sonrası kışın soğuk.
    canvas.drawOval(
      ovalFor(kHearthColdRadius),
      Paint()
        ..color = tint.withAlpha(0x55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0
        ..isAntiAlias = true,
    );
  }

  /// Bina etki alanı görselleştirme — yumuşak isometric oval, ghost rengi ile.
  void _drawEffectRing(
    Canvas canvas,
    int gc,
    int gr,
    BuildingMeta meta,
    Size size,
  ) {
    final cx = gc + meta.cols * 0.5;
    final cy = gr + meta.rows * 0.5;
    final centerScreen = gridToScreen(cx, cy, size, camera);
    // İzometrik 2:1 — radius tile → ekran: x = r * kTileW, y = r * kTileH
    final rx = meta.effectRadius * kTileW;
    final ry = meta.effectRadius * kTileH;
    final rect = Rect.fromCenter(
      center: centerScreen,
      width: rx * 2,
      height: ry * 2,
    );
    final ringColor = ghostValid
        ? const Color(0x66FFD27A)
        : const Color(0x66FF8888);
    canvas.drawOval(
      rect,
      Paint()
        ..color = ringColor.withAlpha(0x22)
        ..isAntiAlias = true,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = ringColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..isAntiAlias = true,
    );
  }

  // ── Lighting pass ────────────────────────────────────────────────────────
  // Sahnenin üstüne çizilir. Beş katman, sırasıyla:
  //   (0) Ambient color grade — fullscreen modulate; her sprite günün rengini
  //       içer (gece soğuk mavi mehtap, altın saat amber, öğle ~beyaz).
  //   (1) Karanlık vertical gradient + vignette (saveLayer içinde)
  //   (2) Lokal ışık delikleri (BlendMode.dstOut → karanlığı eritir)
  //   (3) Per-light warm wash — saveLayer + plus radial: lit area'daki
  //       sprite'lar gerçekten "sıcak" görünür (ambient modulate'in soğuğunu
  //       lokal olarak iptal eder).
  //   (4) Sıcak halo (BlendMode.plus → dış atmosferik parlama)
  // Gündüz tam aydınlıkta sadece ambient grade + hafif vignette çizilir.
  void _drawLightingPass(Canvas canvas, Size size) {
    final darkness = (1.0 - dayLight).clamp(0.0, 1.0);

    // PerfMode fast path — tek vertical gradient overlay, ışık cutout / halo
    // saveLayer × 3 + 7-stop gradient × N tamamen atlanır. Gece basit dark
    // overlay olur, gündüz ise tam ekran atmosfer katmanları tamamen atlanır.
    // Bu kontrol gündüz fast path'inden ÖNCE olmalı; aksi halde performans modu
    // fullscreen'da dört ayrı tam-ekran blend pass'i çizmeye devam eder.
    if (perfMode) {
      if (overlayTop.a == 0 && overlayBottom.a == 0 && darkness < 0.05) {
        return;
      }
      final rect = Rect.fromLTWH(0, 0, size.width, size.height);
      _pLighting.shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [overlayTop, overlayBottom],
      );
      canvas.drawRect(rect, _pLighting);
      _pLighting.shader = null;
      return;
    }

    // (0) Ambient color grade — gece/şafak/altın saatte sahneyi tonlar.
    // Modulate olduğu için strength=0'da beyaza lerp ederiz → identity.
    _drawAmbientGrade(canvas, size);

    // Gündüz fast path — overlay bantları şeffaf, tam aydınlık. Gündüz
    // atmosfer pass'i (güneş formu + hava perspektifi + bloom + sıcak vignette).
    if (overlayTop.a == 0 && overlayBottom.a == 0 && darkness < 0.05) {
      _drawDayAtmosphere(canvas, size);
      return;
    }

    _projectLights(size);

    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    // saveLayer offscreen buffer → içerideki BlendMode.dstOut sadece bu
    // katmanı etkiler, sahnenin altındaki çizimleri silmez.
    canvas.saveLayer(rect, Paint());

    // (1a) Vertical gradient karanlık.
    _pLighting.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height),
      [overlayTop, overlayBottom],
    );
    canvas.drawRect(rect, _pLighting);
    _pLighting.shader = null;

    // (1b) Vignette — kenarları yumuşakça karartır. Mantıklı seviyede;
    // ışık delikleriyle birleşince aşırı kontrast yapmasın diye düşük tut.
    final vA = (darkness * 70 + 22).round().clamp(0, 110);
    _pLighting.shader = ui.Gradient.radial(
      Offset(size.width / 2, size.height / 2),
      max(size.width, size.height) * 0.70,
      [const Color(0x00000000), Color.fromARGB(vA, 0x05, 0x08, 0x18)],
    );
    canvas.drawRect(rect, _pLighting);
    _pLighting.shader = null;

    // (1c) Mehtap dolgusu — gece, dark overlay'in üstüne soğuk-mavi plus.
    // Düz siyah/lacivert yerine ATMOSFERIK moonlight (yukarıdan gelen ay
    // ışığı hissi). saveLayer içinde olduğu için dstOut ışık delikleri
    // moonfill'i de eritir → sıcak puddle vs soğuk mehtap kontrastı tam çıkar.
    // 0.30 darkness eşiğinin altında atlanır (alacakaranlıkta lüzumsuz).
    if (darkness > 0.30) {
      final moonF = ((darkness - 0.30) / 0.70).clamp(0.0, 1.0);
      final topA = (moonF * 78).round().clamp(0, 90);
      final botA = (moonF * 30).round().clamp(0, 50);
      _pMoonFill.shader = ui.Gradient.linear(
        const Offset(0, 0),
        Offset(0, size.height),
        [
          Color.fromARGB(topA, 0x68, 0x86, 0xC2), // üst — açık mehtap mavi
          Color.fromARGB(botA, 0x3A, 0x52, 0x90), // alt — derinleşmiş zemin
        ],
      );
      canvas.drawRect(rect, _pMoonFill);
      _pMoonFill.shader = null;
    }

    // (2) Işık kaynakları → karanlığı eritir. Inner draws BlendMode.lighten ile
    // RGB max alır ama alpha srcOver-stacked olur — overlap'te hafif birikme
    // (asimptotik 1.0). ColorFilter (alpha=R) ile MAX'a çevirmek denendi ama
    // ColorFilter.matrix unpremul ile çalışıyor; beyaz gradient için unpremul
    // R her zaman 1.0 → A'=1, dstOut TÜM gradient alanını full erase ediyor
    // (köy göz alır). Kabul edilebilir hafif stack olarak bırakıldı; kaynak
    // intensity'leri konservatif tutuluyor.
    if (_lightBuffer.isNotEmpty) {
      // Dış halo (4) atmosferik kapsamı veriyor → bu iç katman çekirdek
      // aydınlatma için sıkı tutuldu (radius 0.45×). Hâlâ blur ile yumuşak
      // sınır ama lit area kaynağın hemen çevresinde kalır.
      final coreBounds = _lightLayerBounds(
        size,
        radiusMultiplier: 0.45,
        blurSigma: 6,
      );
      if (coreBounds != null) {
        canvas.saveLayer(
          coreBounds,
          Paint()
            ..blendMode = BlendMode.dstOut
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 6, sigmaY: 6),
        );
        for (final l in _lightBuffer) {
          // Viewport reject — ekran dışı ışıkların gradient + drawCircle pahalı.
          // Core radius * 1.5 (gradient buffer'ı için biraz fazla margin).
          final rCheck = l.radius * 1.5;
          if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
          if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
          final coreA = (l.intensity * 130).round().clamp(0, 140);
          final r = l.radius * 0.45;
          _drawBakedLight(canvas, l.sx, l.sy, r, Colors.white, coreA);
        }
        canvas.restore();
      }
    }

    canvas.restore();

    // (3) Per-light warm wash — sprite hue ısıtma.
    // Mevcut dış halo (4) dış atmosferi tutturuyor ama sprite'a hu zar
    // dokunmuyor (3.5× geniş, alpha düşük). Bu pass daha dar (~1.5×) ve
    // sprite alanını gerçekten warm renge çeker. Modulate'in soğuk grading'i
    // ışık altında iptal olur → contrast = sıcak puddle vs soğuk mehtap.
    // saveLayer + lighten içinde drawn → üst üste binen ışıklar MAX alır
    // (parlama patlaması yok), sonra dış katmana plus ile aktarılır.
    if (_lightBuffer.isNotEmpty && darkness > 0.15) {
      // Warm wash sprite hue ısıtması için sıkı tutuldu (radius 0.55×):
      // sprite alanı warm renge çekilir, atmosferik yayılım dış halo (4)'de.
      final warmBounds = _lightLayerBounds(
        size,
        radiusMultiplier: 0.55,
        blurSigma: 8,
      );
      if (warmBounds != null) {
        canvas.saveLayer(
          warmBounds,
          Paint()
            ..blendMode = BlendMode.plus
            ..isAntiAlias = true
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        );
        for (final l in _lightBuffer) {
          // Viewport reject (warm wash pass)
          final rCheck = l.radius * 2.0;
          if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
          if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
          final innerA = (l.intensity * darkness * 55).round().clamp(0, 65);
          if (innerA < 4) continue;
          final wr = (l.warm.r * 255).round();
          final wg = (l.warm.g * 255).round();
          final wb = (l.warm.b * 255).round();
          final r = l.radius * 0.55;
          _drawBakedLight(
            canvas,
            l.sx,
            l.sy,
            r,
            Color.fromARGB(255, wr, wg, wb),
            innerA,
          );
        }
        canvas.restore();
      }
    }

    // (4) Sıcak halo — geniş atmosferik gauss. Sigma 1.05× core radius +
    // küçük solid çekirdek → ~3σ effective span ama amplitüd asimptotik
    // 0'a düşer (matematik 0-noktası yok = görünür kenar yok). Plus blend
    // ile sahneye additive → kaynakların warm renkleri ortamda fiziksel
    // ışık gibi yayılır. Kaynak türü ayrımı warm renk + radius farkı ile
    // doğal görünür (fire geniş turuncu, lamp dar sarı, ev soluk yanık).
    if (_lightBuffer.isNotEmpty && darkness > 0.20) {
      // Önceki: haloAlpha cap 115, radius 2.5×, sigma 32 — ortalanmış noktada
      // 3 katman birikip patladı. Düşürüldü: cap 35, radius 1.7×, sigma 18.
      final haloBounds = _lightLayerBounds(
        size,
        radiusMultiplier: 1.7,
        blurSigma: 18,
      );
      if (haloBounds != null) {
        canvas.saveLayer(
          haloBounds,
          Paint()
            ..blendMode = BlendMode.plus
            ..imageFilter = ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        );
        for (final l in _lightBuffer) {
          // Viewport reject (outer halo pass) — radius 2.5× drawing
          final rCheck = l.radius * 2.5;
          if (l.sx + rCheck < 0 || l.sx - rCheck > size.width) continue;
          if (l.sy + rCheck < 0 || l.sy - rCheck > size.height) continue;
          final haloAlpha = (l.intensity * darkness * 28).round().clamp(0, 35);
          if (haloAlpha < 3) continue;
          final wr = (l.warm.r * 255).round();
          final wg = (l.warm.g * 255).round();
          final wb = (l.warm.b * 255).round();
          _drawBakedLight(
            canvas,
            l.sx,
            l.sy,
            l.radius * 1.7,
            Color.fromARGB(255, wr, wg, wb),
            haloAlpha,
          );
        }
        canvas.restore();
      }
    }
  }

  /// Tüm binaların gölgesini tek pass'te çizer (sahne sprite'larından önce).
  /// Her bina için light vector aggregation ile yumuşak yön + drop-shadow.
  void _drawBuildingShadows(Canvas canvas, Size size) {
    if (buildings.isEmpty) return;
    final (minX, maxX, minY, maxY) = _visBounds(size);
    final ox = size.width / 2 + camera.dx;
    final oy = size.height * 0.28 + camera.dy;
    bool inView(double gx, double gy) {
      final sx = ox + (gx - gy) * kTileW / 2;
      final sy = oy + (gx + gy) * kTileH / 2;
      return sx >= minX - 160 &&
          sx <= maxX + 160 &&
          sy >= minY - 256 &&
          sy <= maxY + kTileH;
    }

    final shadowBoost = (1.0 - dayLight).clamp(0.0, 1.0);
    for (final b in buildings) {
      final cx = b.col + b.cols / 2.0;
      final cy = b.row + b.rows / 2.0;
      if (!inView(cx, cy)) continue;
      final corners = _corners(b.col, b.row, b.cols, b.rows, size, camera);
      final lightScr = _aggregateLightForBuilding(b, cx, cy, size);
      _drawBuildingShadow(
        canvas,
        corners.$1,
        corners.$2,
        corners.$3,
        corners.$4,
        lightScreen: lightScr,
        shadowBoost: shadowBoost,
      );
    }
  }

  // Bina gölge yönü için ışık AGREGASYONU.
  //
  // En yakın tek ışığı seçmek yerine, etki alanındaki tüm güçlü ışıkların
  // vector-sum'ı alınır (ağırlık = intensity × inverse-square distance).
  // İki lamba eşit uzaklıkta ise gölge ortada birleşir; bir lamba söndüğünde
  // yön zıplamadan kayar. "Sanal light" pozisyonu = bina'dan ortalama yöne
  // 5 tile geri — `_drawBuildingShadow` lightScreen olarak bunu kullanır.
  Offset? _aggregateLightForBuilding(
    BuildingEntity b,
    double bcx,
    double bcy,
    Size size,
  ) {
    if (lightSources.isEmpty || dayLight > 0.7) return null;
    final fpR = (b.cols * b.cols + b.rows * b.rows) * 0.25;
    double sumX = 0, sumY = 0;
    for (final l in lightSources) {
      if (l.intensity < 0.30) continue;
      final dx = bcx - l.gx;
      final dy = bcy - l.gy;
      final d2 = dx * dx + dy * dy;
      if (d2 < fpR) continue; // bina içinde — yön verme
      if (d2 > l.radius * l.radius * 2.25) continue;
      // Inverse-square weight × intensity → yakın güçlü ışık baskın.
      final w = l.intensity / (d2 + 0.5);
      sumX += dx * w;
      sumY += dy * w;
    }
    final mag2 = sumX * sumX + sumY * sumY;
    if (mag2 < 1e-4) return null;
    final mag = sqrt(mag2);
    final dirX = sumX / mag;
    final dirY = sumY / mag;
    // Sanal light pozisyonu — bina merkezinden ortalama yöne 5 tile uzaklık.
    return _worldToScreen(bcx - dirX * 5, bcy - dirY * 5, size);
  }

  // Sahnenin baz tonunu modüle eder. day_night_cycle ambientTint/Strength
  // sağlar → strength 0'da identity beyaza lerp ederek modulate atlanır.
  // Modulate fiziksel: az ışık = koyu+tinted, beyaz = nötr. SoftLight'a göre
  // gece atmosferik koyuluğu doğru taşır.
  void _drawAmbientGrade(Canvas canvas, Size size) {
    if (ambientStrength < 0.02) return;
    final s = ambientStrength.clamp(0.0, 1.0);
    // efektif = lerp(white, ambientTint, s). Strength=0 → beyaz → modulate
    // identity. Strength=1 → tint → kanalları tint oranında çarpar.
    final tr = (ambientTint.r * 255).round();
    final tg = (ambientTint.g * 255).round();
    final tb = (ambientTint.b * 255).round();
    final r = (255 - (255 - tr) * s).round().clamp(0, 255);
    final g = (255 - (255 - tg) * s).round().clamp(0, 255);
    final b = (255 - (255 - tb) * s).round().clamp(0, 255);
    _pAmbientGrade.color = Color.fromARGB(255, r, g, b);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      _pAmbientGrade,
    );
  }

  // Gündüz renk grade matrisi — kontrast (mid-gray pivot) + luminance-koruyan
  // doygunluk. t = dayGrade (0..1, öğlede 1). ColorFilter.matrix 0..255 ölçekte
  // çalışır; offset sütunu (5.) 0..255. A satırı identity (alfa korunur).
  List<double> _dayGradeMatrix(double t) {
    final s = 1.0 + 0.24 * t; // doygunluk: pastel → canlı
    final k = 1.0 + 0.13 * t; // kontrast: değer ayrımı (form okunur)
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final a = 1.0 - s;
    // Saturation matrisi satırları
    final rr = lr * a + s, rg = lg * a, rb = lb * a;
    final gr = lr * a, gg = lg * a + s, gb = lb * a;
    final br = lr * a, bg = lg * a, bb = lb * a + s;
    final off = 128.0 * (1.0 - k); // kontrast pivot offseti
    return <double>[
      k * rr,
      k * rg,
      k * rb,
      0,
      off,
      k * gr,
      k * gg,
      k * gb,
      0,
      off,
      k * br,
      k * bg,
      k * bb,
      0,
      off,
      0,
      0,
      0,
      1,
      0,
    ];
  }

  // Gündüz atmosfer pass'i — gündüz fast-path'inde çağrılır (overlay şeffaf,
  // tam aydınlık). Gece ışık katmanlarının gündüzdeki karşılığı: düz "boyama"
  // hissini güneş formu + hava perspektifi + bloom + sıcak vignette ile kırar.
  // Hepsi fullscreen blend (saveLayer yok) → ucuz. dayGrade ile ölçeklenir.
  void _drawDayAtmosphere(Canvas canvas, Size size) {
    final t = ((dayLight - 0.55) / 0.45).clamp(0.0, 1.0);
    if (t <= 0.01) return;
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final maxR = max(size.width, size.height);
    int a(int base) => (base * t).round().clamp(0, 255);

    // (a) Güneş yönü formu — sol-üst sıcak / sağ-alt nötr, BlendMode.overlay.
    // Overlay: >mid-gray açar+ısıtır, <mid-gray koyar → sahneye hacim+kontrast.
    _pDayGrade.blendMode = BlendMode.overlay;
    _pDayGrade.shader = ui.Gradient.linear(
      Offset(size.width * 0.28, 0),
      Offset(size.width * 0.78, size.height),
      [
        Color.fromARGB(a(255), 0x9C, 0x90, 0x74), // güneş tarafı — ılık açma
        Color.fromARGB(a(255), 0x6E, 0x6B, 0x68), // gölge tarafı — hafif koyu
      ],
    );
    canvas.drawRect(rect, _pDayGrade);

    // (b) Hava perspektifi — üst (izometrikte uzak) hafif serin pus, screen.
    _pDayGrade.blendMode = BlendMode.screen;
    _pDayGrade.shader = ui.Gradient.linear(
      const Offset(0, 0),
      Offset(0, size.height * 0.55),
      [
        Color.fromARGB(a(0x22), 0xB4, 0xC8, 0xDC),
        const Color.fromARGB(0, 0xB4, 0xC8, 0xDC),
      ],
    );
    canvas.drawRect(rect, _pDayGrade);

    // (c) Güneş bloom — üst-orta yumuşak altın saçılma, plus düşük alfa.
    _pDayGrade.blendMode = BlendMode.plus;
    _pDayGrade.shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.10),
      maxR * 0.62,
      [
        Color.fromARGB(a(0x16), 0xFF, 0xE8, 0xAC),
        const Color.fromARGB(0, 0xFF, 0xE8, 0xAC),
      ],
    );
    canvas.drawRect(rect, _pDayGrade);

    // (d) Sıcak vignette — kenarları YUMUŞAK sıcak-koyu (gece soğuğu DEĞİL).
    // multiply: merkez nötr (beyaz), kenar hafif sıcak-bej → güneşli his.
    _pDayGrade.blendMode = BlendMode.multiply;
    final edge = Color.lerp(
      const Color(0xFFFFFFFF),
      const Color(0xFFE6D7BC),
      t,
    )!;
    _pDayGrade.shader = ui.Gradient.radial(
      Offset(size.width * 0.5, size.height * 0.46),
      maxR * 0.74,
      [const Color(0xFFFFFFFF), edge],
    );
    canvas.drawRect(rect, _pDayGrade);

    _pDayGrade.shader = null;
    _pDayGrade.blendMode = BlendMode.srcOver;
  }

  // LightingSystem (world-space) listesi → screen-space _LightInfo buffer.
  // Flicker SADECE intensity (alpha) üzerinden uygulanır → ışık çemberinin
  // dış kenarı pulsating değil, sabit. Toplam parlaklık hafifçe nabız atar,
  // gözü yormaz.
  void _projectLights(Size size) {
    _lightBuffer.clear();
    for (final l in lightSources) {
      final p = _worldToScreen(l.gx, l.gy, size);
      final phase = l.gx * 0.4 + l.gy * 0.7;
      final flicker =
          1.0 +
          sin(time * 3.7 + phase) * 0.04 +
          sin(time * 8.3 + phase * 1.7) * 0.02;
      final rScreen = l.radius * kPixelsPerTile * zoom;
      final dynIntensity = (l.intensity * flicker).clamp(0.0, 1.0);
      _lightBuffer.add(_LightInfo(p.dx, p.dy, rScreen, l.warm, dynIntensity));
    }
  }

  /// Smallest on-screen buffer that can contain a light pass, including the
  /// visible 3σ extent of its Gaussian blur. The scene-wide darkness layer
  /// still covers the full viewport; only the three local-light intermediate
  /// buffers use this bound. This preserves the exact pixels while avoiding
  /// full-screen offscreen textures for lights clustered around the village.
  Rect? _lightLayerBounds(
    Size size, {
    required double radiusMultiplier,
    required double blurSigma,
  }) {
    var left = double.infinity;
    var top = double.infinity;
    var right = -double.infinity;
    var bottom = -double.infinity;
    for (final l in _lightBuffer) {
      final extent = l.radius * radiusMultiplier + blurSigma * 3.0;
      if (l.sx + extent < 0 ||
          l.sx - extent > size.width ||
          l.sy + extent < 0 ||
          l.sy - extent > size.height) {
        continue;
      }
      left = min(left, l.sx - extent);
      top = min(top, l.sy - extent);
      right = max(right, l.sx + extent);
      bottom = max(bottom, l.sy + extent);
    }
    if (!left.isFinite) return null;
    final viewport = Rect.fromLTWH(0, 0, size.width, size.height);
    final bounds = Rect.fromLTRB(left, top, right, bottom).intersect(viewport);
    return bounds.isEmpty ? null : bounds;
  }

  // ── Olay overlay'i (tint + partiküller) ─────────────────────────────────
  //
  // Aggregate tint, lighting pass üstüne yumuşak alpha çekilir. Sonra her
  // aktif EventFx için özelleştirilmiş partikül/animasyon pass'i.

}
