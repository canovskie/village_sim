import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'about_screen.dart';
import 'game_theme.dart';
import 'settings_screen.dart';
import 'sky_widgets.dart';

/// Uygulamanın ilk açılış ekranı — başlık + atmosferik gökyüzü + menü düğmeleri.
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
  static const _skyTop = Color(0xFF2A1B4A);
  static const _skyMid = Color(0xFFE08838);

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
      backgroundColor: const Color(0xFF1A0F30),
      body: Stack(
        children: [
          const PixelSky(topColor: _skyTop, midColor: _skyMid),
          Positioned.fill(
            child: StarField(opacity: 0.45, time: _time),
          ),

          // Yavaşça batan güneş — ufka yakın, dekoratif
          Positioned(
            right: size.width * 0.18,
            top: size.height * 0.30,
            child: const PixelSun(color: Color(0xFFFFB060)),
          ),

          // Sürüklenen bulutlar
          _DriftingClouds(time: _time, screenWidth: size.width),

          // Ufuk silüeti — köy görünümü
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: CustomPaint(
              size: Size(size.width, size.height * 0.42),
              painter: _HorizonPainter(time: _time),
            ),
          ),

          // Başlık + buton listesi
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: size.height * 0.08),
                  const _Title(),
                  const SizedBox(height: 6),
                  const _Subtitle(),
                  const Spacer(),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 340),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _MenuButton(
                          label: 'YENİ OYUN',
                          accent: const Color(0xFFFFD944),
                          primary: true,
                          onTap: widget.onNewGame,
                        ),
                        const SizedBox(height: 10),
                        _MenuButton(
                          label: 'AYARLAR',
                          accent: const Color(0xFFCCA030),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SettingsScreen(),
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        _MenuButton(
                          label: 'HAKKINDA',
                          accent: const Color(0xFFCCA030),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AboutScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text('v0.1.0',
                      style: TextStyle(
                        color: MedievalTheme.textDim,
                        fontSize: 9,
                        fontFamily: 'monospace',
                        letterSpacing: 1.5,
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

// ── Başlık ───────────────────────────────────────────────────────────────────

class _Title extends StatelessWidget {
  const _Title();
  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: const [
        // Gölge
        Positioned(
          top: 4,
          child: Text('VILLAGE SIM',
              style: TextStyle(
                color: Color(0xCC1A0E06),
                fontSize: 38,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 6.0,
              )),
        ),
        Text('VILLAGE SIM',
            style: TextStyle(
              color: MedievalTheme.textAccent,
              fontSize: 38,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace',
              letterSpacing: 6.0,
            )),
      ],
    );
  }
}

class _Subtitle extends StatelessWidget {
  const _Subtitle();
  @override
  Widget build(BuildContext context) {
    return const Text('☼  ateşi yak, köyü kur  ☼',
        style: TextStyle(
          color: MedievalTheme.textPrimary,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
          letterSpacing: 2.5,
        ));
  }
}

// ── Menü butonu ──────────────────────────────────────────────────────────────

class _MenuButton extends StatefulWidget {
  final String label;
  final Color accent;
  final bool primary;
  final VoidCallback onTap;
  const _MenuButton({
    required this.label,
    required this.accent,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final active = _hover || _pressed || widget.primary;
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
          duration: const Duration(milliseconds: 120),
          padding: EdgeInsets.symmetric(
            vertical: widget.primary ? 16 : 13,
          ),
          decoration: MedievalTheme.buttonDecoration(
            active: active,
            accentColor: widget.accent,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: TextStyle(
                color: active ? widget.accent : widget.accent.withValues(alpha: 0.65),
                fontSize: widget.primary ? 14 : 12,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
                letterSpacing: 3.0,
              ),
            ),
          ),
        ),
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
      Positioned(left: cx(40), top: 70, child: const PixelCloud()),
      Positioned(left: cx(screenWidth * 0.35), top: 110, child: const PixelCloud()),
      Positioned(left: cx(screenWidth * 0.70), top: 50, child: const PixelCloud()),
      Positioned(left: cx(screenWidth * 0.92), top: 130, child: const PixelCloud()),
    ]);
  }
}

// ── Ufuk silüeti ─────────────────────────────────────────────────────────────
// Birkaç piksel-bina + tepe + ateş ışıltısı.

class _HorizonPainter extends CustomPainter {
  final double time;
  _HorizonPainter({required this.time});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Arka tepe
    final hill = Paint()..color = const Color(0xFF1F1024);
    final hillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.55, h * 0.50)
      ..quadraticBezierTo(w * 0.80, h * 0.65, w, h * 0.40)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hillPath, hill);

    // Ön zemin
    final ground = Paint()..color = const Color(0xFF120814);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), ground);

    // Köy silüeti — birkaç ev + kule
    void building(double cx, double cy, double bw, double bh,
        {bool hasRoof = true, bool hasWindow = true}) {
      final bodyR = Rect.fromLTWH(cx - bw / 2, cy - bh, bw, bh);
      canvas.drawRect(bodyR, Paint()..color = const Color(0xFF0A0510));
      if (hasRoof) {
        final roof = Path()
          ..moveTo(cx - bw / 2 - 2, cy - bh)
          ..lineTo(cx, cy - bh - bw * 0.45)
          ..lineTo(cx + bw / 2 + 2, cy - bh)
          ..close();
        canvas.drawPath(roof, Paint()..color = const Color(0xFF1A0E0A));
      }
      if (hasWindow) {
        // Yanan pencere — sıcak ışık
        final flicker = (sin(time * 3.5 + cx) * 0.2 + 0.8).clamp(0.6, 1.0);
        final glow = Color.fromRGBO(
          255, 180, 80,
          (0.55 * flicker).clamp(0.2, 1.0),
        );
        final wW = bw * 0.22;
        final wH = bh * 0.22;
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy - bh * 0.55),
            width: wW, height: wH,
          ),
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

    // Kule (ortaçağ feneri)
    final towerX = w * 0.50;
    canvas.drawRect(
      Rect.fromLTWH(towerX - 8, groundY - 64, 16, 64),
      Paint()..color = const Color(0xFF0A0510),
    );
    canvas.drawRect(
      Rect.fromLTWH(towerX - 12, groundY - 70, 24, 8),
      Paint()..color = const Color(0xFF1A0E0A),
    );
    // Kule tepesi parlama
    final towerFlicker = (sin(time * 2.0) * 0.15 + 0.85).clamp(0.6, 1.0);
    canvas.drawCircle(
      Offset(towerX, groundY - 68),
      6,
      Paint()
        ..color = Color.fromRGBO(255, 200, 100, (0.6 * towerFlicker).clamp(0.2, 1.0))
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Ateş ışığı — ortada büyük
    final fireFlicker = (sin(time * 6.0) * 0.25 + 0.75).clamp(0.5, 1.0);
    final fireGlow = Paint()
      ..color = Color.fromRGBO(255, 140, 40, (0.30 * fireFlicker).clamp(0.1, 1.0))
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18);
    canvas.drawCircle(Offset(w * 0.42, groundY - 8), 32, fireGlow);
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.time != time;
}
