part of 'main_menu_screen.dart';

// ANA MENÜ — şafak sahnesi (güneş, ufuk, sis, kuşlar, karşılayan)
// (Bu dosya main_menu_screen.dart bölünürken ayrıldı — sınıflar
//  aynen taşındı, tek satırı değişmedi.)

class _SunWithGlow extends StatelessWidget {
  final double time;
  const _SunWithGlow({required this.time});
  @override
  Widget build(BuildContext context) {
    final pulse = sin(time * 0.5) * 0.06 + 0.94;
    return SizedBox(
      width: 132,
      height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Geniş soluk şafak hâlesi
          Container(
            width: 132,
            height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.fromRGBO(255, 226, 178, 0.60 * pulse),
                  Color.fromRGBO(255, 190, 120, 0.22 * pulse),
                  const Color(0x00FFC080),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),
          // Dar parlak çekirdek — yeni doğan güneş sıcak-beyaz
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  Color.fromRGBO(255, 246, 224, 0.9 * pulse),
                  const Color(0x00FFE6BE),
                ],
              ),
            ),
          ),
          // Güneş diski — sert kare değil, sıcak-beyaz yumuşak disk
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [Color(0xFFFFFBF0), Color(0xFFFFE7C2)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Sürüklenen bulutlar ──────────────────────────────────────────────────────

class _DriftingClouds extends StatelessWidget {
  final double time;
  final double screenWidth;
  const _DriftingClouds({required this.time, required this.screenWidth});

  @override
  Widget build(BuildContext context) {
    final wrap = screenWidth + 120.0;
    final drift = (time * 6.0) % wrap;
    double cx(double base) => (base + drift) % wrap - 60;
    return Stack(
      children: [
        Positioned(
          left: cx(40),
          top: 70,
          child: const PixelCloud(scale: 1.1, parallax: 0.6),
        ),
        Positioned(
          left: cx(screenWidth * 0.35),
          top: 110,
          child: const PixelCloud(scale: 0.8, parallax: 0.4),
        ),
        Positioned(
          left: cx(screenWidth * 0.70),
          top: 50,
          child: const PixelCloud(scale: 1.3, parallax: 0.8),
        ),
        Positioned(
          left: cx(screenWidth * 0.92),
          top: 130,
          child: const PixelCloud(scale: 0.7, parallax: 0.35),
        ),
      ],
    );
  }
}

// ── Ufuk silüeti ─────────────────────────────────────────────────────────────

class _HorizonPainter extends CustomPainter {
  final double time;
  _HorizonPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // — UZAK SIRT: atmosferik perspektif → puslu, gökle neredeyse karışır.
    final farPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.40)
      ..quadraticBezierTo(w * 0.22, h * 0.20, w * 0.48, h * 0.34)
      ..quadraticBezierTo(w * 0.72, h * 0.46, w, h * 0.26)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(farPath, Paint()..color = const Color(0xFF8FB6AC));

    // — ORTA TEPE
    final midPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.55, h * 0.50)
      ..quadraticBezierTo(w * 0.80, h * 0.65, w, h * 0.40)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(midPath, Paint()..color = const Color(0xFF3D6B5E));

    // Sırt çizgisine güneş öpücüğü — tepe hattı ışığa doğru altın parlar.
    canvas.drawPath(
      midPath,
      Paint()
        ..color = const Color(0x66FFDDA0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // Binalar ekran genişliğiyle ölçeklenir — sabit piksel ebat geniş ekranda
    // köyü oyuncak gibi gösteriyordu.
    final s = (w / 900).clamp(0.9, 1.9);

    void building(
      double cx,
      double cy,
      double bw,
      double bh, {
      bool hasRoof = true,
      bool hasWindow = true,
    }) {
      // Gövde: siyah değil SICAK ARDUVAZ — sağ (güneş) yüzü belirgin açılır.
      canvas.drawRect(
        Rect.fromLTWH(cx - bw / 2, cy - bh, bw, bh),
        Paint()
          ..shader = ui.Gradient.linear(
            Offset(cx - bw / 2, 0),
            Offset(cx + bw / 2, 0),
            [const Color(0xFF23343C), const Color(0xFF44585C)],
          ),
      );
      if (hasRoof) {
        final roof = Path()
          ..moveTo(cx - bw / 2 - 2, cy - bh)
          ..lineTo(cx, cy - bh - bw * 0.45)
          ..lineTo(cx + bw / 2 + 2, cy - bh)
          ..close();
        // Kiremit — sabah güneşi çatıyı yakalar, terracotta ısınır.
        canvas.drawPath(
          roof,
          Paint()
            ..shader = ui.Gradient.linear(
              Offset(cx - bw / 2, 0),
              Offset(cx + bw / 2, 0),
              [const Color(0xFF6B4034), const Color(0xFFA8674A)],
            ),
        );
      }
      if (hasWindow) {
        // Sabah oldu: lambalar sönmek üzere, camlar artık çoğunlukla gökyüzünü
        // yansıtıyor — kor gibi yanan pencere geceye aitti.
        final flicker = (sin(time * 3.5 + cx) * 0.2 + 0.8).clamp(0.6, 1.0);
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy - bh * 0.55),
            width: bw * 0.22,
            height: bh * 0.22,
          ),
          Paint()
            ..color = Color.fromRGBO(
              255,
              214,
              150,
              (0.42 * flicker).clamp(0.15, 1.0),
            ),
        );
      }
    }

    // Köy ORTA TEPENİN eteğine kurulur; birazdan çizilecek yakın çayır
    // temellerini örtecek → derinlik. (Düz bir zemin çizgisine dizilmiş evler
    // ekranı boydan boya kesen çirkin bir yatay çizgi bırakıyordu.)
    final groundY = h * 0.74;
    building(w * 0.14, groundY + 6 * s, 38 * s, 32 * s);
    building(w * 0.24, groundY + 2 * s, 28 * s, 22 * s);
    building(w * 0.34, groundY + 8 * s, 44 * s, 40 * s);
    building(w * 0.62, groundY + 4 * s, 24 * s, 20 * s, hasWindow: false);
    building(w * 0.72, groundY + 9 * s, 36 * s, 36 * s);
    building(w * 0.86, groundY + 3 * s, 30 * s, 28 * s);

    // Kule merkezden UZAK: ortada menü paneli duruyor, w*0.44'te tamamen
    // gizleniyordu.
    final towerX = w * 0.29;
    final towerH = 64 * s, towerW = 16 * s;
    canvas.drawRect(
      Rect.fromLTWH(towerX - towerW / 2, groundY - towerH, towerW, towerH),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(towerX - towerW / 2, 0),
          Offset(towerX + towerW / 2, 0),
          [const Color(0xFF283A42), const Color(0xFF4E646A)],
        ),
    );
    // Çan katı — düz bir kapak, kuleyi fabrika bacasına benzetiyordu.
    final belfryY = groundY - towerH;
    canvas.drawRect(
      Rect.fromLTWH(towerX - 11 * s, belfryY - 16 * s, 22 * s, 16 * s),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(towerX - 11 * s, 0),
          Offset(towerX + 11 * s, 0),
          [const Color(0xFF2E434B), const Color(0xFF566E74)],
        ),
    );
    // Sivri kiremit külah
    canvas.drawPath(
      Path()
        ..moveTo(towerX - 14 * s, belfryY - 16 * s)
        ..lineTo(towerX, belfryY - 34 * s)
        ..lineTo(towerX + 14 * s, belfryY - 16 * s)
        ..close(),
      Paint()
        ..shader = ui.Gradient.linear(
          Offset(towerX - 14 * s, 0),
          Offset(towerX + 14 * s, 0),
          [const Color(0xFF6B4034), const Color(0xFFA8674A)],
        ),
    );
    // Çan boşluğu — kemerli, içinde sabah ışığı
    final towerFlicker = (sin(time * 2.0) * 0.15 + 0.85).clamp(0.6, 1.0);
    canvas.drawRRect(
      RRect.fromRectAndCorners(
        Rect.fromLTWH(towerX - 5 * s, belfryY - 12 * s, 10 * s, 11 * s),
        topLeft: Radius.circular(5 * s),
        topRight: Radius.circular(5 * s),
      ),
      Paint()
        ..color = Color.fromRGBO(
          255,
          228,
          170,
          (0.55 * towerFlicker).clamp(0.2, 1.0),
        ),
    );

    // Meydan ateşi — sabah oldu, sadece közü kaldı: soluk sıcak bir leke.
    final fireFlicker = (sin(time * 6.0) * 0.25 + 0.75).clamp(0.5, 1.0);
    canvas.drawCircle(
      Offset(w * 0.34, groundY - 4),
      30 * s,
      Paint()
        ..color = Color.fromRGBO(
          255,
          170,
          80,
          (0.18 * fireFlicker).clamp(0.05, 1.0),
        )
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // Sabah bacaları — evler uyanıyor, ocaklar tütüyor.
    void smoke(double cx, double topY) {
      final smk = Paint()
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      for (int i = 0; i < 5; i++) {
        final t = i / 4.0;
        final rise = t * 46 * s;
        final wob = sin(time * 0.9 + i * 0.8 + cx) * (5 + t * 10) * s;
        final a = (0.34 * (1 - t)).clamp(0.0, 1.0);
        smk.color = Color.fromRGBO(255, 251, 243, a);
        canvas.drawCircle(
          Offset(cx + wob, topY - rise),
          (3.0 + t * 5.0) * s,
          smk,
        );
      }
    }

    smoke(w * 0.14, groundY - 30 * s);
    smoke(w * 0.72, groundY - 32 * s);

    // — YAKIN ÇAYIR: dümdüz kesilmiş bir bant DEĞİL, yumuşak eğri bir sırt.
    // Köyün temellerini örter, sahneye üçüncü derinlik katmanını verir.
    final nearTop = h * 0.80;
    final nearPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, nearTop + 10)
      ..quadraticBezierTo(w * 0.20, nearTop - 16, w * 0.46, nearTop + 2)
      ..quadraticBezierTo(w * 0.74, nearTop + 22, w, nearTop - 8)
      ..lineTo(w, h)
      ..close();
    // Düz tek renk yerine dikey gradyan: sırt ışıkta, dip serin — çayır
    // düz bir yeşil leke olmaktan çıkar.
    canvas.drawPath(
      nearPath,
      Paint()
        ..shader = ui.Gradient.linear(Offset(0, nearTop - 16), Offset(0, h), [
          const Color(0xFF3E6B5F),
          const Color(0xFF224340),
        ]),
    );
    // Güneşten (sağ) çayıra düşen geniş, çok soluk ışık havuzu
    canvas.save();
    canvas.clipPath(nearPath);
    canvas.drawRect(
      Rect.fromLTWH(0, nearTop - 20, w, h - nearTop + 20),
      Paint()
        ..shader = ui.Gradient.radial(Offset(w * 0.78, nearTop + 6), w * 0.55, [
          const Color(0x30FFD79E),
          const Color(0x00FFD79E),
        ]),
    );
    canvas.restore();
    // Sırt hattına sabah ışığı — çayırın tepesi altın bir tel gibi parlar.
    canvas.drawPath(
      nearPath,
      Paint()
        ..color = const Color(0x5CFFD8A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.time != time;
}

// ─── Şafak gökyüzü ───────────────────────────────────────────────────────────

/// SABAHIN İLK SAATİ — güneş çoktan doğmuş, gök açılmış. Tepede berrak gök
/// mavisi, ortada turkuaz→soluk su yeşili, ufka doğru şeftali→sabah altını.
/// Mor/leylak bandı kasten YOK: o bant sahneyi bunaltıyordu (bkz. şafak öncesi
/// çivit sürümü). Aşağı inildikçe değer AÇILIR, koyulaşmaz — umut bu yönden gelir.
class _DawnSky extends StatelessWidget {
  const _DawnSky();
  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF4E8FC4), // açık gök mavisi
            Color(0xFF7FB9CE), // turkuaz
            Color(0xFFBBD9C0), // soluk su yeşili
            Color(0xFFF6C98E), // şeftali
            Color(0xFFFFD98A), // ufuk altını
          ],
          stops: [0.0, 0.26, 0.50, 0.76, 1.0],
        ),
      ),
      child: SizedBox.expand(),
    );
  }
}

// ─── Sabah ışınları ──────────────────────────────────────────────────────────

/// Yükselen güneşten köye doğru açılan yumuşak yelpaze ışınları. Çok düşük
/// alfa + additive harman → göz almadan "sabah ferahlığı" hissi.
class _LightRaysPainter extends CustomPainter {
  final double time;
  final Offset sun;
  _LightRaysPainter({required this.time, required this.sun});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(sun.dx, sun.dy);
    const n = 7;
    final len = size.height * 0.95;
    for (int i = 0; i < n; i++) {
      // Aşağıya doğru açılan yelpaze + nazik salınım
      final a =
          pi / 2 + (i - (n - 1) / 2) * 0.19 + sin(time * 0.25 + i) * 0.025;
      final width = 42.0 + (i % 3) * 22.0;
      final alpha = i.isEven ? 0.028 : 0.016;
      final ex = cos(a) * len, ey = sin(a) * len;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(ex - width, ey)
        ..lineTo(ex + width, ey)
        ..close();
      final shader = ui.Gradient.linear(Offset.zero, Offset(ex, ey), [
        Color.fromRGBO(255, 224, 160, alpha),
        const Color(0x00FFE0A0),
      ]);
      canvas.drawPath(
        path,
        Paint()
          ..shader = shader
          ..blendMode = BlendMode.plus
          // Kenarları yumuşat: keskin üçgenler "ışın" değil "üçgen" okunuyordu.
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_LightRaysPainter o) => o.time != time || o.sun != sun;
}

// ─── Sabah sisi ──────────────────────────────────────────────────────────────

class _MorningMistPainter extends CustomPainter {
  final double time;
  _MorningMistPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final p = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 24);
    // Sis YUKARIDA, tepe eteğinde kalır: aşağı indikçe hızla söner. Ön plandaki
    // köylüyü sarmalayan sis "korku filmi" hissinin yarısıydı.
    for (int i = 0; i < 4; i++) {
      final y = h * (0.34 + i * 0.11);
      final drift = sin(time * 0.14 + i * 1.3) * w * 0.05;
      final a = (0.15 - i * 0.038).clamp(0.0, 1.0);
      p.color = Color.fromRGBO(246, 252, 250, a);
      final rect = Rect.fromCenter(
        center: Offset(w * 0.5 + drift, y),
        width: w * 1.25,
        height: 26 + i * 8.0,
      );
      canvas.drawRRect(RRect.fromRectXY(rect, 60, 60), p);
    }
  }

  @override
  bool shouldRepaint(_MorningMistPainter o) => o.time != time;
}

// ─── Uyanan kuşlar ───────────────────────────────────────────────────────────

/// Yüksekte gevşek V düzeninde, kanat çırparak yavaşça süzülen sabah kuşları.
class _WakingBirdsPainter extends CustomPainter {
  final double time;
  _WakingBirdsPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final baseX = (time * 10.0) % (w + 160) - 80;
    final baseY = size.height * 0.20;
    final stroke = Paint()
      ..color = const Color(0x5C2C4A5A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const offsets = [
      Offset(0, 0),
      Offset(-22, 10),
      Offset(22, 10),
      Offset(-44, 22),
      Offset(44, 22),
    ];
    for (int i = 0; i < offsets.length; i++) {
      final cx = baseX + offsets[i].dx;
      final cy = baseY + offsets[i].dy + sin(time * 0.3 + i) * 3;
      final flap = sin(time * 6.0 + i * 1.1) * 3.5;
      final path = Path()
        ..moveTo(cx - 7, cy + flap)
        ..quadraticBezierTo(cx, cy - 3, cx, cy)
        ..quadraticBezierTo(cx, cy - 3, cx + 7, cy + flap);
      canvas.drawPath(path, stroke);
    }
  }

  @override
  bool shouldRepaint(_WakingBirdsPainter o) => o.time != time;
}

// ─── Karşılayıcı köylü ───────────────────────────────────────────────────────

/// Ön planda seni bekleyen köylü. Kasten SİLÜET DEĞİL: kukuletasız, yüzü
/// görünen, giysisi renkli, sabah ışığını yiyen bir insan. (Önceki sürüm
/// kapkara cübbeli + kukuletalı + yüzsüz + fenerli + sisin içindeydi — hepsi
/// birebir korku ikonografisi; birlikte "hoş geldin" değil "kaç" diyorlardı.)
/// Elinde fener yerine ekmek sepeti var: karşılamanın nesnesi ışık değil, ikram.
class _WelcomerVillager extends StatelessWidget {
  final double time;

  /// Ekran yüksekliği — figür sabit pikselde kalırsa geniş ekranda kaybolur;
  /// ön plan olduğunu hissettirmesi için yükseklikle ölçeklenir.
  final double screenHeight;
  const _WelcomerVillager({required this.time, required this.screenHeight});

  static const _base = Size(172, 236);

  @override
  Widget build(BuildContext context) {
    final scale = (screenHeight * 0.30 / _base.height).clamp(0.78, 1.7);
    return CustomPaint(
      size: Size(_base.width * scale, _base.height * scale),
      painter: _WelcomerPainter(time: time, scale: scale),
    );
  }
}

class _WelcomerPainter extends CustomPainter {
  final double time;
  final double scale;
  _WelcomerPainter({required this.time, required this.scale});

  // Sabah güneşi SAĞDAN geliyor (bkz. _sunCenter) → sağ kenarlar sıcak açılır,
  // sol kenarlar hafif serinler. Hiçbir yerde saf siyah yok.
  static const _skinLit = Color(0xFFFFD9A8);
  static const _skinShade = Color(0xFFCE9268);
  static const _linenLit = Color(0xFFFBF1DC);
  static const _linenShade = Color(0xFFD3C3A6);
  static const _vestLit = Color(0xFFE0A44E);
  static const _vestShade = Color(0xFFA96E2E);
  static const _trouserLit = Color(0xFF7E9184);
  static const _trouserShade = Color(0xFF4E6058);
  static const _leather = Color(0xFF8A5A34);
  static const _hair = Color(0xFF4A3328);
  static const _rim = Color(0xFFFFE9C0);

  /// Soldan sağa (gölge → ışık) yatay gradyan — figürün her parçası aynı
  /// ışık yönünü paylaşsın diye tek yerden üretilir.
  Paint _lit(double left, double right, Color shade, Color lit) => Paint()
    ..shader = ui.Gradient.linear(Offset(left, 0), Offset(right, 0), [
      shade,
      lit,
    ]);

  @override
  void paint(Canvas canvas, Size size) {
    // Tüm geometri 172×236'lık taban kadraja göre yazıldı; ölçek tek yerden.
    canvas.save();
    canvas.scale(scale);
    final w = size.width / scale, h = size.height / scale;
    final breathe = sin(time * 1.3) * 1.4; // nefes bob'u
    final feetY = h - 10;
    final cx = w * 0.46;

    const headR = 14.0;
    final headC = Offset(cx, h * 0.20);
    final shoulderY = h * 0.30;
    final hipY = h * 0.585;

    canvas.save();
    canvas.translate(0, breathe);

    // ── Yer gölgesi (güneş sağdan → gölge sola düşer, sıcak-yeşil zemine)
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - 9, feetY + 3), width: 80, height: 16),
      Paint()
        ..color = const Color(0x4A16302C)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // ── Bacaklar + çizmeler
    for (final dx in const [-14.0, 3.0]) {
      canvas.drawRRect(
        RRect.fromRectXY(
          Rect.fromLTWH(cx + dx, hipY - 4, 12, feetY - hipY + 4),
          4,
          4,
        ),
        _lit(cx + dx, cx + dx + 12, _trouserShade, _trouserLit),
      );
      canvas.drawRRect(
        RRect.fromRectXY(Rect.fromLTWH(cx + dx - 1, feetY - 14, 14, 14), 3, 3),
        _lit(cx + dx - 1, cx + dx + 13, const Color(0xFF3E3128), _leather),
      );
    }

    // ── Gövde: keten gömlek (omuzlar yuvarlak, bele doğru hafif daralır)
    final shirt = Path()
      ..moveTo(cx - 22, shoulderY + 5)
      ..quadraticBezierTo(cx - 21, shoulderY - 4, cx - 11, shoulderY - 6)
      ..lineTo(cx + 11, shoulderY - 6)
      ..quadraticBezierTo(cx + 21, shoulderY - 4, cx + 22, shoulderY + 5)
      ..lineTo(cx + 19, hipY)
      ..lineTo(cx - 19, hipY)
      ..close();
    canvas.drawPath(shirt, _lit(cx - 22, cx + 22, _linenShade, _linenLit));

    // ── Ochre yelek: göğüste V açıklığı bırakan iki panel
    for (final s in const [-1.0, 1.0]) {
      final panel = Path()
        ..moveTo(cx + s * 4, shoulderY - 4)
        ..lineTo(cx + s * 16, shoulderY - 3)
        ..lineTo(cx + s * 15, hipY + 2)
        ..lineTo(cx + s * 4, hipY + 2)
        ..lineTo(cx + s * 4, shoulderY + 16)
        ..close();
      canvas.drawPath(panel, _lit(cx - 16, cx + 16, _vestShade, _vestLit));
    }

    // ── Kemer
    canvas.drawRRect(
      RRect.fromRectXY(
        Rect.fromCenter(center: Offset(cx, hipY - 3), width: 42, height: 7),
        2,
        2,
      ),
      _lit(cx - 21, cx + 21, const Color(0xFF6B4326), _leather),
    );

    // ── Sepeti tutan kol (sol, aşağı-dışa)
    final basketHand = Offset(cx - 33, hipY - 8);
    canvas.drawPath(
      Path()
        ..moveTo(cx - 19, shoulderY + 4)
        ..quadraticBezierTo(
          cx - 31,
          shoulderY + 28,
          basketHand.dx,
          basketHand.dy,
        ),
      Paint()
        ..color = _linenShade
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(basketHand, 5.5, Paint()..color = _skinShade);

    // ── Selam veren kol (sağ, yukarı) — yavaş, geniş, dostane salınım
    final wave = sin(time * 2.2) * 0.26;
    final shoulder = Offset(cx + 19, shoulderY + 4);
    final elbow = Offset(cx + 33, shoulderY + 20);
    final hand = Offset(
      elbow.dx + cos(-1.35 + wave) * 34,
      elbow.dy + sin(-1.35 + wave) * 34,
    );
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      Paint()
        ..color = _linenLit
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    // Açık el — parmaklar ayrık değil ama avuç bize dönük, "merhaba" jesti
    canvas.drawCircle(hand, 6.0, Paint()..color = _skinLit);

    // ── Boyun
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, headC.dy + headR - 1),
        width: 11,
        height: 10,
      ),
      Paint()..color = _skinShade,
    );

    // ── Baş
    canvas.drawCircle(
      headC,
      headR,
      _lit(headC.dx - headR, headC.dx + headR, _skinShade, _skinLit),
    );

    // ── Saç: tepeyi ve şakakları örten kısa kesim (kukuleta YOK)
    final hairPath = Path()
      ..moveTo(cx - headR, headC.dy + 1)
      ..quadraticBezierTo(
        cx - headR - 1,
        headC.dy - headR,
        cx,
        headC.dy - headR,
      )
      ..quadraticBezierTo(
        cx + headR + 1,
        headC.dy - headR,
        cx + headR,
        headC.dy + 1,
      )
      ..lineTo(cx + headR - 2, headC.dy - 2)
      ..quadraticBezierTo(cx, headC.dy - 9, cx - headR + 2, headC.dy - 2)
      ..close();
    canvas.drawPath(hairPath, Paint()..color = _hair);

    // ── Yüz: iki göz + yumuşak gülümseme + yanak allığı
    final eye = Paint()..color = const Color(0xFF3A2A22);
    canvas.drawCircle(Offset(cx - 5, headC.dy + 1.5), 1.7, eye);
    canvas.drawCircle(Offset(cx + 5, headC.dy + 1.5), 1.7, eye);
    canvas.drawArc(
      Rect.fromCenter(center: Offset(cx, headC.dy + 4.5), width: 11, height: 8),
      pi * 0.18,
      pi * 0.64,
      false,
      Paint()
        ..color = const Color(0xFF8A5138)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.7
        ..strokeCap = StrokeCap.round,
    );
    final blush = Paint()..color = const Color(0x4CE08A6A);
    canvas.drawCircle(Offset(cx - 8.5, headC.dy + 4), 2.6, blush);
    canvas.drawCircle(Offset(cx + 8.5, headC.dy + 4), 2.6, blush);

    // ── Ekmek sepeti (fenerin yerini alan nesne: ikram, ışık değil)
    final sway = sin(time * 1.4) * 1.6;
    final bx = basketHand.dx + sway, by = basketHand.dy + 20;
    final basket = Path()
      ..moveTo(bx - 15, by - 10)
      ..lineTo(bx + 15, by - 10)
      ..lineTo(bx + 11, by + 11)
      ..lineTo(bx - 11, by + 11)
      ..close();
    // Somunlar sepetin ağzından taşar
    for (final o in const [-7.0, 0.0, 7.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(bx + o, by - 13 + (o == 0 ? -2 : 0)),
          width: 11,
          height: 9,
        ),
        Paint()..color = const Color(0xFFE3B96E),
      );
    }
    canvas.drawPath(
      basket,
      _lit(bx - 15, bx + 15, const Color(0xFF8A5A2C), const Color(0xFFCE9450)),
    );
    // Örgü çizgileri
    final weave = Paint()
      ..color = const Color(0x593F2712)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (int i = 1; i <= 2; i++) {
      final t = i / 3.0;
      final yy = by - 10 + t * 21;
      final hw = 15 - t * 4;
      canvas.drawLine(Offset(bx - hw, yy), Offset(bx + hw, yy), weave);
    }
    // Sap
    canvas.drawArc(
      Rect.fromCenter(center: Offset(bx, by - 10), width: 26, height: 20),
      pi,
      pi,
      false,
      Paint()
        ..color = const Color(0xFF8A5A2C)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    // ── Rim-light: güneş sağdan, kenarları ince ve sıcak öper (abartısız)
    void rimStroke(Path p, double alpha, double width) => canvas.drawPath(
      p,
      Paint()
        ..color = _rim.withValues(alpha: alpha)
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..strokeCap = StrokeCap.round,
    );
    rimStroke(
      Path()..addArc(
        Rect.fromCircle(center: headC, radius: headR),
        -pi * 0.48,
        pi * 0.62,
      ),
      0.75,
      2.0,
    );
    rimStroke(
      Path()
        ..moveTo(cx + 22, shoulderY + 5)
        ..lineTo(cx + 19, hipY),
      0.45,
      1.8,
    );
    rimStroke(
      Path()
        ..moveTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      0.55,
      1.4,
    );

    canvas.restore(); // nefes bob'u
    canvas.restore(); // ölçek
  }

  @override
  bool shouldRepaint(_WelcomerPainter o) => o.time != time || o.scale != scale;
}
