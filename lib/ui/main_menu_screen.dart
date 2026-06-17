import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'about_screen.dart';
import 'cozy_theme.dart';
import 'settings_screen.dart';
import 'sky_widgets.dart';

/// Açılış ekranı — atmosferik akşam gökyüzü + iplerle asılı oyma ahşap tabela
/// (oyun başlığı) + el yapımı ahşap menü plakaları. Oyun-içi CozyUi dilinin
/// aynısı: ahşap, parşömen, demir, oyma kapital.
class MainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  const MainMenuScreen({super.key, required this.onNewGame});

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;

  // Akşam tonları — sıcak ve davetkâr
  static const _skyTop = Color(0xFF241640);
  static const _skyMid = Color(0xFFE0883C);

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      setState(() => _time += dt);
    })..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF160C28),
      body: Stack(
        children: [
          // ── Atmosfer katmanları ──────────────────────────────────────────
          const PixelSky(topColor: _skyTop, midColor: _skyMid),
          Positioned.fill(child: StarField(opacity: 0.42, time: _time)),

          // Yavaşça batan güneş — ufka yakın, soluk hâle ile
          Positioned(
            right: size.width * 0.16,
            top: size.height * 0.30,
            child: _SunWithGlow(time: _time),
          ),

          _DriftingClouds(time: _time, screenWidth: size.width),

          // Ufuk köy silüeti + yanan pencereler + şenlik ateşi
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: CustomPaint(
              size: Size(size.width, size.height * 0.46),
              painter: _HorizonPainter(time: _time),
            ),
          ),

          // Alt-orta sıcak ateş parıltısı — sahneye derinlik & odak
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: size.height * 0.5,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, 1.0),
                    radius: 0.9,
                    colors: [Color(0x33FF8A3A), Color(0x00FF8A3A)],
                    stops: [0.0, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // Kenar karartması (vignette) — gözü merkeze topla
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.1,
                    colors: [Color(0x00000000), Color(0x66000000)],
                    stops: [0.62, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── İçerik ────────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.085),
                  _HangingSign(time: _time),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 344),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MenuPlank(
                          label: 'YENİ KÖY',
                          glyph: _Glyph.flame,
                          primary: true,
                          onTap: widget.onNewGame,
                        ),
                        const SizedBox(height: 13),
                        _MenuPlank(
                          label: 'AYARLAR',
                          glyph: _Glyph.gear,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                        ),
                        const SizedBox(height: 13),
                        _MenuPlank(
                          label: 'HAKKINDA',
                          glyph: _Glyph.scroll,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AboutScreen()),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('sürüm 0.1.0',
                      style: CozyUi.inkMuted.copyWith(
                        color: const Color(0x88E8D5A3),
                        fontSize: 10,
                        letterSpacing: 2.0,
                      )),
                  const SizedBox(height: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Asılı oyma ahşap tabela (başlık) ───────────────────────────────────────

class _HangingSign extends StatelessWidget {
  final double time;
  const _HangingSign({required this.time});

  @override
  Widget build(BuildContext context) {
    // Hafif sarkaç sallanması — üst noktadan dönerek
    final sway = sin(time * 0.7) * 0.013;
    return Transform(
      alignment: Alignment.topCenter,
      transform: Matrix4.rotationZ(sway),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // İki demir halka + ip (tabelayı tepedeki çiviye bağlar)
          SizedBox(
            height: 26,
            width: 240,
            child: CustomPaint(painter: _RopePainter()),
          ),
          _SignBoard(),
          const SizedBox(height: 12),
          // Alt parşömen şeridi — alt başlık
          Transform.rotate(
            angle: -0.02,
            child: ParchmentPanel(
              pinned: false,
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 7),
              child: Text(
                'ateşi yak · köyü kur · halkı yönet',
                style: CozyUi.inkMuted.copyWith(
                  fontSize: 11.5,
                  letterSpacing: 1.0,
                  color: CozyUi.parchmentInk,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oyma kapital başlığın işlendiği ahşap pano.
class _SignBoard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(34, 18, 34, 22),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [CozyUi.woodLight, CozyUi.woodMid, CozyUi.woodDark],
              stops: [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: const Color(0xFF1C0D03), width: 2.2),
            boxShadow: const [
              BoxShadow(
                  color: Color(0xAA000000), blurRadius: 22, offset: Offset(0, 12)),
              BoxShadow(color: Color(0x55E5B074), blurRadius: 1, offset: Offset(0, -1)),
            ],
          ),
          child: CustomPaint(
            painter: _BoardGrainPainter(),
            child: const _EngravedTitle(),
          ),
        ),
        // 4 köşe çivisi
        const Positioned(top: 7, left: 9, child: NailHead(size: 8)),
        const Positioned(top: 7, right: 9, child: NailHead(size: 8)),
        const Positioned(bottom: 7, left: 9, child: NailHead(size: 8)),
        const Positioned(bottom: 7, right: 9, child: NailHead(size: 8)),
      ],
    );
  }
}

/// "VILLAGE SIM" — ahşaba oyulmuş altın kapital.
class _EngravedTitle extends StatelessWidget {
  const _EngravedTitle();
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Oyma gölgesi (içe çökük) — koyu, hafif aşağı
        Text('VILLAGE SIM',
            style: CozyUi.displayTitle.copyWith(
              fontSize: 44,
              color: const Color(0xCC150A02),
              shadows: const [],
            )),
        // Altın yüzey — yukarıdan ışıklı gradient
        Positioned.fill(
          child: ShaderMask(
            shaderCallback: (r) => const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFFFFE9B0),
                Color(0xFFF1B65C),
                Color(0xFFC9842F),
              ],
              stops: [0.0, 0.55, 1.0],
            ).createShader(r),
            child: Text('VILLAGE SIM',
                style: CozyUi.displayTitle.copyWith(
                  fontSize: 44,
                  color: Colors.white,
                  shadows: const [
                    Shadow(
                        color: Color(0x99000000),
                        blurRadius: 0,
                        offset: Offset(0, 1.5)),
                  ],
                )),
          ),
        ),
      ],
    );
  }
}

/// Pano üzeri dikey damar + birkaç budak — _WoodGrainPainter'ın dikey eşi.
class _BoardGrainPainter extends CustomPainter {
  static final _rng = Random(31337);
  static final List<double> _ys =
      List.generate(11, (_) => _rng.nextDouble());
  static final List<bool> _light = List.generate(11, (_) => _rng.nextBool());

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    for (int i = 0; i < _ys.length; i++) {
      final y = _ys[i] * size.height;
      p.color = _light[i]
          ? CozyUi.woodHi.withValues(alpha: 0.08)
          : CozyUi.woodGrain.withValues(alpha: 0.22);
      final path = Path()..moveTo(0, y);
      for (double x = 0; x <= size.width; x += 4) {
        path.lineTo(x, y + sin(x / size.width * pi * 2 + i) * 1.1);
      }
      canvas.drawPath(path, p);
    }
  }

  @override
  bool shouldRepaint(_BoardGrainPainter old) => false;
}

/// İki ip + demir halka — tabelayı tepeden asar.
class _RopePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rope = Paint()
      ..color = const Color(0xFF6E4A24)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..isAntiAlias = true;
    final ropeHi = Paint()
      ..color = const Color(0x66D2A062)
      ..strokeWidth = 1.2
      ..isAntiAlias = true;
    // Sol & sağ ip — tepe orta noktadan panonun köşelerine
    for (final dir in [-1.0, 1.0]) {
      final topX = w / 2 + dir * 6;
      final botX = w / 2 + dir * (w * 0.32);
      canvas.drawLine(Offset(topX, 2), Offset(botX, h - 2), rope);
      canvas.drawLine(Offset(topX, 2), Offset(botX, h - 2), ropeHi);
      // Alt uçta demir halka
      canvas.drawCircle(
        Offset(botX, h - 2),
        3.4,
        Paint()
          ..color = const Color(0xFF2A1B0C)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // Tepe çivisi
    canvas.drawCircle(
        Offset(w / 2, 2),
        3.2,
        Paint()..shader = const RadialGradient(colors: [
              Color(0xFFD2B57E),
              Color(0xFF1A1108),
            ]).createShader(Rect.fromCircle(center: Offset(w / 2, 2), radius: 3.2)));
  }

  @override
  bool shouldRepaint(_RopePainter old) => false;
}

// ─── Menü plakası ───────────────────────────────────────────────────────────

enum _Glyph { flame, gear, scroll }

class _MenuPlank extends StatefulWidget {
  final String label;
  final _Glyph glyph;
  final bool primary;
  final VoidCallback onTap;
  const _MenuPlank({
    required this.label,
    required this.glyph,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_MenuPlank> createState() => _MenuPlankState();
}

class _MenuPlankState extends State<_MenuPlank> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _pressed;
    final accent = CozyUi.ember;
    final lit = active || widget.primary;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 110),
          transform: _pressed
              ? Matrix4.translationValues(0, 1.5, 0)
              : Matrix4.identity(),
          height: widget.primary ? 60 : 54,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: lit
                  ? const [Color(0xFFB87A45), CozyUi.woodMid, CozyUi.woodDark]
                  : const [Color(0xFF8E5C34), CozyUi.woodMid, Color(0xFF35190A)],
              stops: const [0.0, 0.5, 1.0],
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(
              color: lit ? accent.withValues(alpha: 0.9) : const Color(0xFF1C0D03),
              width: lit ? 1.8 : 1.5,
            ),
            boxShadow: [
              if (lit)
                BoxShadow(
                    color: accent.withValues(alpha: 0.45),
                    blurRadius: 16,
                    spreadRadius: 0.5),
              const BoxShadow(
                  color: Color(0x88000000), blurRadius: 8, offset: Offset(0, 4)),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: CustomPaint(
              painter: _BoardGrainPainter(),
              child: Stack(
                children: [
                  // Üst kenar cila vurgusu
                  Positioned(
                    top: 0, left: 0, right: 0,
                    child: Container(
                      height: 1.5,
                      color: const Color(0x55E5B074),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      children: [
                        // Demir madalyon + oyma sigil
                        Container(
                          width: 30, height: 30,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: const RadialGradient(
                              center: Alignment(-0.3, -0.4),
                              colors: [Color(0xFF4A3018), Color(0xFF160C04)],
                            ),
                            border: Border.all(
                                color: lit
                                    ? accent.withValues(alpha: 0.8)
                                    : const Color(0xFF5A3C18),
                                width: 1.2),
                          ),
                          child: CustomPaint(
                            painter: _GlyphPainter(
                              widget.glyph,
                              lit ? CozyUi.emberSoft : const Color(0xFFB59560),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            widget.label,
                            style: TextStyle(
                              fontFamily: CozyUi.fontDisplay,
                              fontSize: widget.primary ? 19 : 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 2.4,
                              color: lit
                                  ? const Color(0xFFFFEFC8)
                                  : const Color(0xFFE8CF9A),
                              shadows: const [
                                Shadow(
                                    color: Color(0xCC150A02),
                                    blurRadius: 0,
                                    offset: Offset(0, 1.5)),
                              ],
                            ),
                          ),
                        ),
                        // Sağ ok süsü
                        Text('›',
                            style: TextStyle(
                              fontFamily: CozyUi.fontDisplay,
                              fontSize: 22,
                              color: lit
                                  ? accent
                                  : const Color(0x66B59560),
                            )),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Demir madalyon içine oyulmuş basit sigil (alev / dişli / parşömen).
class _GlyphPainter extends CustomPainter {
  final _Glyph glyph;
  final Color color;
  _GlyphPainter(this.glyph, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.30;
    final p = Paint()
      ..color = color
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeJoin = StrokeJoin.round;
    final fill = Paint()..color = color..isAntiAlias = true;

    switch (glyph) {
      case _Glyph.flame:
        final path = Path()
          ..moveTo(c.dx, c.dy - r * 1.3)
          ..quadraticBezierTo(c.dx + r * 1.1, c.dy - r * 0.1, c.dx + r * 0.5, c.dy + r)
          ..quadraticBezierTo(c.dx, c.dy + r * 1.5, c.dx - r * 0.5, c.dy + r)
          ..quadraticBezierTo(c.dx - r * 1.1, c.dy - r * 0.1, c.dx, c.dy - r * 1.3)
          ..close();
        canvas.drawPath(path, fill);
        break;
      case _Glyph.gear:
        const teeth = 8;
        for (int i = 0; i < teeth; i++) {
          final a = i / teeth * pi * 2;
          final o = Offset(c.dx + cos(a) * r * 1.25, c.dy + sin(a) * r * 1.25);
          canvas.drawCircle(o, 1.6, fill);
        }
        canvas.drawCircle(c, r, p);
        canvas.drawCircle(c, r * 0.38, p);
        break;
      case _Glyph.scroll:
        final rect = Rect.fromCenter(
            center: c, width: r * 1.7, height: r * 2.2);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)), p);
        for (int i = 0; i < 3; i++) {
          final y = c.dy - r * 0.6 + i * r * 0.6;
          canvas.drawLine(
              Offset(c.dx - r * 0.55, y), Offset(c.dx + r * 0.55, y), p..strokeWidth = 1.1);
        }
        break;
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.glyph != glyph || old.color != color;
}

// ─── Güneş + hâle ───────────────────────────────────────────────────────────

class _SunWithGlow extends StatelessWidget {
  final double time;
  const _SunWithGlow({required this.time});
  @override
  Widget build(BuildContext context) {
    final pulse = sin(time * 0.5) * 0.06 + 0.94;
    return SizedBox(
      width: 120, height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 120, height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.fromRGBO(255, 190, 110, 0.55 * pulse),
                const Color(0x00FFB060),
              ]),
            ),
          ),
          const PixelSun(color: Color(0xFFFFC070)),
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
    return Stack(children: [
      Positioned(left: cx(40), top: 70, child: const PixelCloud(scale: 1.1, parallax: 0.6)),
      Positioned(left: cx(screenWidth * 0.35), top: 110, child: const PixelCloud(scale: 0.8, parallax: 0.4)),
      Positioned(left: cx(screenWidth * 0.70), top: 50, child: const PixelCloud(scale: 1.3, parallax: 0.8)),
      Positioned(left: cx(screenWidth * 0.92), top: 130, child: const PixelCloud(scale: 0.7, parallax: 0.35)),
    ]);
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

    // Arka tepe
    final hill = Paint()..color = const Color(0xFF231228);
    final hillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.55, h * 0.50)
      ..quadraticBezierTo(w * 0.80, h * 0.65, w, h * 0.40)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hillPath, hill);

    // Ön zemin
    final ground = Paint()..color = const Color(0xFF140916);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), ground);

    void building(double cx, double cy, double bw, double bh,
        {bool hasRoof = true, bool hasWindow = true}) {
      final bodyR = Rect.fromLTWH(cx - bw / 2, cy - bh, bw, bh);
      canvas.drawRect(bodyR, Paint()..color = const Color(0xFF0C0612));
      if (hasRoof) {
        final roof = Path()
          ..moveTo(cx - bw / 2 - 2, cy - bh)
          ..lineTo(cx, cy - bh - bw * 0.45)
          ..lineTo(cx + bw / 2 + 2, cy - bh)
          ..close();
        canvas.drawPath(roof, Paint()..color = const Color(0xFF1C100C));
      }
      if (hasWindow) {
        final flicker = (sin(time * 3.5 + cx) * 0.2 + 0.8).clamp(0.6, 1.0);
        final glow = Color.fromRGBO(255, 180, 80, (0.6 * flicker).clamp(0.2, 1.0));
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy - bh * 0.55),
            width: bw * 0.22, height: bh * 0.22),
          Paint()..color = glow,
        );
      }
    }

    final groundY = h * 0.82;
    building(w * 0.18, groundY, 38, 32);
    building(w * 0.30, groundY, 28, 22);
    building(w * 0.42, groundY, 44, 40);
    building(w * 0.55, groundY, 24, 20, hasWindow: false);
    building(w * 0.68, groundY, 36, 36);
    building(w * 0.82, groundY, 30, 28);

    // Kule
    final towerX = w * 0.50;
    canvas.drawRect(Rect.fromLTWH(towerX - 8, groundY - 64, 16, 64),
        Paint()..color = const Color(0xFF0C0612));
    canvas.drawRect(Rect.fromLTWH(towerX - 12, groundY - 70, 24, 8),
        Paint()..color = const Color(0xFF1C100C));
    final towerFlicker = (sin(time * 2.0) * 0.15 + 0.85).clamp(0.6, 1.0);
    canvas.drawCircle(
      Offset(towerX, groundY - 68),
      6,
      Paint()
        ..color = Color.fromRGBO(255, 200, 100, (0.6 * towerFlicker).clamp(0.2, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Şenlik ateşi parıltısı
    final fireFlicker = (sin(time * 6.0) * 0.25 + 0.75).clamp(0.5, 1.0);
    canvas.drawCircle(
      Offset(w * 0.42, groundY - 8),
      34,
      Paint()
        ..color = Color.fromRGBO(255, 140, 40, (0.32 * fireFlicker).clamp(0.1, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.time != time;
}
