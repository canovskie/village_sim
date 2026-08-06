part of 'main_menu_screen.dart';

// ANA MENÜ — ilkbahar arka planı (ağaç salınımı + ambiyans)
// (Bu dosya main_menu_screen.dart bölünürken ayrıldı — sınıflar
//  aynen taşındı, tek satırı değişmedi.)

class _MenuSpringBackground extends StatelessWidget {
  final bool touch;
  final bool wideMobile;
  final double time;
  const _MenuSpringBackground({
    required this.touch,
    required this.wideMobile,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    final asset = wideMobile
        ? 'assets/ui/menu_spring_mobile.webp'
        : 'assets/ui/menu_spring_desktop.webp';

    return Positioned.fill(
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                asset,
                fit: BoxFit.cover,
                alignment: Alignment.center,
                filterQuality: FilterQuality.high,
              ),
              _TreeSwayLayer(asset: asset, wideMobile: wideMobile, time: time),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: touch
                        ? const [
                            Color(0x24101A14),
                            Color(0x12101A14),
                            Color(0x06101A14),
                          ]
                        : const [
                            Color(0xE60B100D),
                            Color(0xC90B100D),
                            Color(0x70101812),
                            Color(0x10101812),
                          ],
                    stops: touch
                        ? const [0.0, 0.52, 1.0]
                        : const [0.0, 0.25, 0.48, 0.72],
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: touch
                        ? const [
                            Color(0x4A08120D),
                            Color(0x00101812),
                            Color(0x99101812),
                          ]
                        : const [
                            Color(0x1408120D),
                            Color(0x00101812),
                            Color(0x38101812),
                          ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              CustomPaint(
                painter: _SpringAmbientPainter(
                  time: time,
                  wideMobile: wideMobile,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aynı arkaplanın yalnız ağaç tacı bölgelerini birkaç piksel kaydırır.
/// Gövdeler ve binalar sabit kalır; hareket rüzgâr alan yapraklarda toplanır.
class _TreeSwayLayer extends StatelessWidget {
  final String asset;
  final bool wideMobile;
  final double time;

  const _TreeSwayLayer({
    required this.asset,
    required this.wideMobile,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    // Tek sinüs mekanik sallanır; iki yavaş frekans birbirine binince ağaç
    // bazen durulur, bazen hafif bir rüzgâr alır. Gövde sabit, yalnız taç oynar.
    final sway = sin(time * 0.72) * 2.2 + sin(time * 0.19 + 0.8) * 1.1;
    final lift = cos(time * 0.51) * 0.55 + sin(time * 0.27) * 0.25;
    return ClipPath(
      clipper: _TreeCanopyClipper(wideMobile),
      clipBehavior: Clip.antiAlias,
      child: Transform.translate(
        offset: Offset(sway, lift),
        child: Image.asset(
          asset,
          fit: BoxFit.cover,
          alignment: Alignment.center,
          filterQuality: FilterQuality.high,
        ),
      ),
    );
  }
}

class _TreeCanopyClipper extends CustomClipper<Path> {
  final bool wideMobile;
  const _TreeCanopyClipper(this.wideMobile);

  @override
  Path getClip(Size size) {
    final w = size.width, h = size.height;
    final path = Path();
    if (wideMobile) {
      path
        ..addOval(Rect.fromLTWH(-w * 0.04, h * 0.10, w * 0.18, h * 0.52))
        ..addOval(Rect.fromLTWH(w * 0.07, h * 0.15, w * 0.15, h * 0.40));
    } else {
      path
        ..addOval(Rect.fromLTWH(-w * 0.04, h * 0.04, w * 0.20, h * 0.31))
        ..addOval(Rect.fromLTWH(w * 0.13, h * 0.12, w * 0.20, h * 0.30))
        ..addOval(Rect.fromLTWH(w * 0.80, h * 0.12, w * 0.15, h * 0.23));
    }
    return path;
  }

  @override
  bool shouldReclip(_TreeCanopyClipper oldClipper) =>
      oldClipper.wideMobile != wideMobile;
}

/// Su, çiçek, rüzgâr yaprakları, polen/toz ve ateş hareketlerini tek
/// hafif CustomPaint pass'inde toplar.
class _SpringAmbientPainter extends CustomPainter {
  final double time;
  final bool wideMobile;

  _SpringAmbientPainter({required this.time, required this.wideMobile});

  static final _water = Paint()
    ..blendMode = BlendMode.plus
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static final _petal = Paint()..isAntiAlias = true;
  static final _leaf = Paint()..isAntiAlias = true;
  static final _leafVein = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;
  static final _dust = Paint()
    ..blendMode = BlendMode.plus
    ..isAntiAlias = true;
  static final _stone = Paint()
    ..color = const Color(0xCC65584A)
    ..isAntiAlias = true;
  static final _emberGround = Paint()
    ..color = const Color(0x660F1712)
    ..isAntiAlias = true;
  static final _log = Paint()
    ..color = const Color(0xFF6B3E22)
    ..strokeWidth = 3.2
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  @override
  void paint(Canvas canvas, Size size) {
    _drawWater(canvas, size);
    _drawDust(canvas, size);
    _drawPetals(canvas, size);
    _drawWindLeaves(canvas, size);
    _drawFire(canvas, size);
  }

  /// Her parçacığın rotası kareden kareye değişmesin diye sabit,
  /// ucuz bir 0..1 hash. `Random` yaratmak ya da liste tutmak gerektirmez.
  double _unit(int seed) {
    final value = sin(seed * 12.9898 + 78.233) * 43758.5453;
    return value - value.floorToDouble();
  }

  /// Güneşli orta/sağ vadide havada asılı polen ve toz zerreleri. Noktalar
  /// aşağı düşmez; yavaşça yükselip yana süzülür. Bu katman hareketi
  /// uzaktan hissettirir, menü metninin altına kar yağdırmaz.
  void _drawDust(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final count = wideMobile ? 22 : 38;
    final scale = (size.shortestSide / 700).clamp(0.68, 1.55);

    for (var i = 0; i < count; i++) {
      final speed = 0.018 + _unit(i * 17 + 3) * 0.018;
      final phase = (time * speed + _unit(i * 29 + 11)) % 1.0;
      final baseX = wideMobile
          ? w * (0.08 + _unit(i * 41 + 5) * 0.84)
          : w * (0.38 + _unit(i * 41 + 5) * 0.58);
      final baseY = h * (0.18 + _unit(i * 53 + 7) * 0.60);
      final x =
          baseX +
          phase * w * (0.035 + _unit(i * 13 + 2) * 0.045) +
          sin(time * 0.42 + i * 1.9) * 7 * scale;
      final y =
          baseY -
          phase * h * (0.035 + _unit(i * 31 + 9) * 0.055) +
          sin(time * 0.31 + i * 2.3) * 5 * scale;
      final breathe = pow(sin(phase * pi).clamp(0.0, 1.0), 1.4).toDouble();
      final alpha = breathe * (0.10 + _unit(i * 67 + 1) * 0.28);
      final radius = (0.65 + _unit(i * 73 + 4) * 1.15) * scale;

      _dust.color = const Color(0xFFFFE6A8).withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, _dust);

      // Seyrek iri zerre güneşi yakalayıp bir anlık parıldar. Haç değil,
      // iki kısa ışık çizgisi; masalsı ama göze bağırmaz.
      if (i % 11 == 0 && alpha > 0.16) {
        _dust
          ..strokeWidth = 0.65 * scale
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          Offset(x - radius * 2.2, y),
          Offset(x + radius * 2.2, y),
          _dust,
        );
        canvas.drawLine(
          Offset(x, y - radius * 1.7),
          Offset(x, y + radius * 1.7),
          _dust,
        );
      }
    }
  }

  void _drawWater(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final left = Path();
    if (wideMobile) {
      left
        ..moveTo(w * 0.29, h * 0.46)
        ..cubicTo(w * 0.26, h * 0.57, w * 0.20, h * 0.68, w * 0.17, h * 0.80)
        ..cubicTo(w * 0.13, h * 0.91, w * 0.09, h * 0.95, w * 0.06, h * 1.03);
    } else {
      left
        ..moveTo(w * 0.42, h * 0.36)
        ..cubicTo(w * 0.37, h * 0.44, w * 0.32, h * 0.48, w * 0.30, h * 0.53)
        ..cubicTo(w * 0.25, h * 0.61, w * 0.17, h * 0.69, w * 0.10, h * 0.75)
        ..cubicTo(w * 0.06, h * 0.79, w * 0.02, h * 0.82, -w * 0.02, h * 0.85);
    }
    _flowAlong(canvas, left, size.shortestSide * 0.008, 0);

    if (!wideMobile) {
      final mill = Path()
        ..moveTo(w * 0.66, h * 0.30)
        ..cubicTo(w * 0.65, h * 0.40, w * 0.67, h * 0.48, w * 0.73, h * 0.56);
      _flowAlong(canvas, mill, size.shortestSide * 0.006, 17);
    }
  }

  void _flowAlong(Canvas canvas, Path path, double dash, int phase) {
    for (final metric in path.computeMetrics()) {
      final count = (metric.length / (dash * 3.8)).clamp(8, 24).round();
      for (var i = 0; i < count; i++) {
        final t = (time * 0.075 + i / count + phase * 0.013) % 1.0;
        final tangent = metric.getTangentForOffset(metric.length * t);
        if (tangent == null) continue;
        final pulse = sin(t * pi).clamp(0.0, 1.0);
        _water
          ..color = Color.fromRGBO(190, 232, 255, 0.05 + pulse * 0.17)
          ..strokeWidth = 0.55 + pulse * 0.75;
        final unit = tangent.vector / tangent.vector.distance;
        canvas.drawLine(
          tangent.position - unit * dash * 0.45,
          tangent.position + unit * dash * 0.45,
          _water,
        );
      }
    }
    _water.blendMode = BlendMode.plus;
  }

  void _drawPetals(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final originX = wideMobile ? w * 0.08 : w * 0.18;
    final spreadX = wideMobile ? w * 0.17 : w * 0.19;
    final originY = wideMobile ? h * 0.18 : h * 0.13;
    final fallH = wideMobile ? h * 0.54 : h * 0.40;
    final scale = (size.shortestSide / 700).clamp(0.7, 1.5);
    for (var i = 0; i < 16; i++) {
      final phase = (time * (0.035 + i % 3 * 0.006) + i * 0.071) % 1.0;
      final x =
          originX +
          ((i * 37) % 101) / 100 * spreadX +
          sin(time * 0.9 + i * 1.7) * 8 * scale;
      final y = originY + phase * fallH;
      final alpha = sin(phase * pi).clamp(0.0, 1.0) * 0.72;
      _petal.color =
          (i % 3 == 0 ? const Color(0xFFFFD8E4) : const Color(0xFFFFF1E2))
              .withValues(alpha: alpha);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(sin(time * 1.3 + i) * 0.8);
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset.zero,
          width: 2.8 * scale,
          height: 1.5 * scale,
        ),
        _petal,
      );
      canvas.restore();
    }
  }

  /// Ağaçlardan kopup sahneyi çapraz geçen yapraklar. Ufaktakiler orta
  /// planda, her beşinci yaprak daha büyük/yumuşak çizilerek kameraya yakın
  /// okunur; böylece tek bir düz partikül düzlemi yerine derinlik oluşur.
  void _drawWindLeaves(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final count = wideMobile ? 14 : 24;
    final scale = (size.shortestSide / 700).clamp(0.70, 1.6);
    const colors = [
      Color(0xFF8BAA59), // taze yeşil
      Color(0xFF6F8C46),
      Color(0xFFC6A052), // güneş vurmuş yaprak
      Color(0xFFB87542),
      Color(0xFFD5B969),
    ];

    for (var i = 0; i < count; i++) {
      final near = i % 5 == 0;
      final speed = 0.045 + _unit(i * 19 + 6) * 0.035;
      final phase = (time * speed + _unit(i * 43 + 8)) % 1.0;
      final lane = _unit(i * 61 + 4);
      final startX = -w * 0.10 + _unit(i * 71 + 3) * w * 0.82;
      final travel = w * (0.34 + _unit(i * 23 + 9) * 0.44);
      final wrap = w * 1.18;
      final x = (startX + phase * travel + w * 0.10) % wrap - w * 0.10;
      final y =
          h * (0.08 + lane * 0.48) +
          phase * h * (0.16 + _unit(i * 37 + 7) * 0.23) +
          sin(time * (0.75 + _unit(i * 11) * 0.55) + i * 1.8) *
              (8 + 10 * lane) *
              scale;

      final life = sin(phase * pi).clamp(0.0, 1.0);
      // Masaüstünde sol tarafta logo/menü var: yaprak oradan geçebilir ama
      // metni kirletmeden neredeyse silinir. Sağdaki açık sahnede belirginleşir.
      final readingFade = !wideMobile && x < w * 0.42 ? 0.22 : 1.0;
      final alpha = life * readingFade * (near ? 0.48 : 0.62);
      if (alpha < 0.015) continue;

      final length =
          (near ? 10.0 : 5.8) * (0.76 + _unit(i * 47 + 2) * 0.55) * scale;
      final width = length * (0.38 + _unit(i * 79 + 1) * 0.12);
      final color = colors[i % colors.length].withValues(alpha: alpha);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(
        time * (0.75 + _unit(i * 83 + 2) * 1.4) +
            i * 0.91 +
            sin(time * 0.6 + i) * 0.8,
      );
      final path = Path()
        ..moveTo(-length * 0.52, 0)
        ..quadraticBezierTo(0, -width, length * 0.52, 0)
        ..quadraticBezierTo(0, width, -length * 0.52, 0)
        ..close();
      _leaf
        ..color = color
        ..maskFilter = near
            ? MaskFilter.blur(BlurStyle.normal, 0.55 * scale)
            : null;
      canvas.drawPath(path, _leaf);

      if (near) {
        _leafVein
          ..color = const Color(0xFF4C5E31).withValues(alpha: alpha * 0.65)
          ..strokeWidth = 0.55 * scale;
        canvas.drawLine(
          Offset(-length * 0.36, 0),
          Offset(length * 0.38, 0),
          _leafVein,
        );
      }
      canvas.restore();
    }
    _leaf.maskFilter = null;
  }

  void _drawFire(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final cx = wideMobile ? w * 0.245 : w * 0.305;
    final cy = wideMobile ? h * 0.68 : h * 0.70;
    final scale = (size.shortestSide / 650).clamp(0.72, 1.45);
    final glow = Paint()
      ..shader = ui.Gradient.radial(
        Offset(cx, cy - 5 * scale),
        32 * scale,
        [
          const Color(0x66FF9A38),
          const Color(0x20FFBE61),
          const Color(0x00FFBE61),
        ],
        [0.0, 0.45, 1.0],
      )
      ..blendMode = BlendMode.plus;
    canvas.drawCircle(Offset(cx, cy - 5 * scale), 32 * scale, glow);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, cy + 1.5 * scale),
        width: 25 * scale,
        height: 8 * scale,
      ),
      _emberGround,
    );
    _log.strokeWidth = 3.2 * scale;
    canvas.drawLine(
      Offset(cx - 7 * scale, cy + 1.5 * scale),
      Offset(cx + 7 * scale, cy - 2.5 * scale),
      _log,
    );
    canvas.drawLine(
      Offset(cx - 7 * scale, cy - 2.5 * scale),
      Offset(cx + 7 * scale, cy + 1.5 * scale),
      _log,
    );

    for (var i = 0; i < 7; i++) {
      final a = i / 7 * pi * 2;
      canvas.drawCircle(
        Offset(cx + cos(a) * 9 * scale, cy + sin(a) * 3.2 * scale),
        2.4 * scale,
        _stone,
      );
    }
    FlameRenderer.draw(canvas, cx, cy, 1.45 * scale, time, 41, intensity: 0.9);
  }

  @override
  bool shouldRepaint(_SpringAmbientPainter oldDelegate) =>
      oldDelegate.time != time || oldDelegate.wideMobile != wideMobile;
}

// ─── Başlık bloğu ────────────────────────────────────────────────────────────
