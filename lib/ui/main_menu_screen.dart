import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'about_screen.dart';
import 'app_ui.dart';
import 'settings_screen.dart';
import 'sky_widgets.dart';

/// Açılış ekranı — atmosferik akşam sahnesi + zarif altın başlık + temiz koyu
/// menü paneli. Diegetik-lite: sahne sıcaklığı verir, UI modern ve sade kalır.
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
          // ── Atmosfer ──────────────────────────────────────────────────────
          const PixelSky(topColor: _skyTop, midColor: _skyMid),
          Positioned.fill(child: StarField(opacity: 0.42, time: _time)),
          Positioned(
            right: size.width * 0.16,
            top: size.height * 0.28,
            child: _SunWithGlow(time: _time),
          ),
          _DriftingClouds(time: _time, screenWidth: size.width),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: CustomPaint(
              size: Size(size.width, size.height * 0.46),
              painter: _HorizonPainter(time: _time),
            ),
          ),
          // Alt sıcak parıltı + kenar vignette
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
                  ),
                ),
              ),
            ),
          ),
          const Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment.center,
                    radius: 1.15,
                    colors: [Color(0x00000000), Color(0x73000000)],
                    stops: [0.55, 1.0],
                  ),
                ),
              ),
            ),
          ),

          // ── İçerik ────────────────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: size.height * 0.06),
                      const AppReveal(child: _TitleBlock()),
                      SizedBox(height: size.height * 0.10),
                      AppReveal(
                        delay: const Duration(milliseconds: 120),
                        child: _MenuCard(
                          onNewGame: widget.onNewGame,
                          onSettings: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                          onAbout: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AboutScreen()),
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),
                      Text('sürüm 0.1.0',
                          style: AppUi.label.copyWith(
                              color: AppUi.textLo, letterSpacing: 2.2)),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Başlık bloğu ────────────────────────────────────────────────────────────

class _TitleBlock extends StatelessWidget {
  const _TitleBlock();
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Altın oyma başlık — ahşap pano yok, sadece zarif tipografi.
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFFFEEC2), Color(0xFFF1B65C), Color(0xFFC9842F)],
            stops: [0.0, 0.55, 1.0],
          ).createShader(r),
          child: const Text(
            'VILLAGE SIM',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: AppUi.fontDisplay,
              fontWeight: FontWeight.w700,
              fontSize: 42,
              height: 1.0,
              letterSpacing: 3.0,
              color: Colors.white,
              shadows: [
                Shadow(color: Color(0xCC000000), blurRadius: 12, offset: Offset(0, 4)),
                Shadow(color: Color(0x55000000), blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // İnce aksan kuralı — iki taraftan sönen ember çizgisi
        SizedBox(
          width: 180,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0x00E98A38),
                      Color(0xCCE98A38),
                    ]),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8),
                child: GameIcon(GameIconData.flame, size: 12, color: AppUi.accent),
              ),
              Expanded(
                child: Container(
                  height: 1,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(colors: [
                      Color(0xCCE98A38),
                      Color(0x00E98A38),
                    ]),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Text('ateşi yak · köyü kur · halkı yönet',
            style: AppUi.body.copyWith(
                color: AppUi.textMid,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5)),
      ],
    );
  }
}

// ─── Menü kartı ──────────────────────────────────────────────────────────────

class _MenuCard extends StatelessWidget {
  final VoidCallback onNewGame, onSettings, onAbout;
  const _MenuCard({
    required this.onNewGame,
    required this.onSettings,
    required this.onAbout,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _MenuRow(
            icon: GameIconData.flame,
            label: 'YENİ KÖY',
            primary: true,
            onTap: onNewGame,
          ),
          const SizedBox(height: 9),
          _MenuRow(
            icon: GameIconData.gear,
            label: 'AYARLAR',
            onTap: onSettings,
          ),
          const SizedBox(height: 9),
          _MenuRow(
            icon: GameIconData.scroll,
            label: 'HAKKINDA',
            onTap: onAbout,
          ),
        ],
      ),
    );
  }
}

class _MenuRow extends StatefulWidget {
  final GameIconData icon;
  final String label;
  final bool primary;
  final VoidCallback onTap;
  const _MenuRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_MenuRow> createState() => _MenuRowState();
}

class _MenuRowState extends State<_MenuRow> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final hot = _hover || _down;
    final lit = hot || widget.primary;
    final accent = AppUi.accent;
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _down = true),
        onTapUp: (_) => setState(() => _down = false),
        onTapCancel: () => setState(() => _down = false),
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          transform:
              _down ? Matrix4.translationValues(0, 1, 0) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: widget.primary
                ? Color.alphaBlend(
                    accent.withValues(alpha: hot ? 0.30 : 0.20), AppUi.surface2)
                : hot
                    ? AppUi.surface3
                    : AppUi.surface1,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
                color: lit ? accent.withValues(alpha: 0.85) : AppUi.line,
                width: lit ? 1.5 : 1),
            boxShadow: lit
                ? [BoxShadow(color: accent.withValues(alpha: 0.32), blurRadius: 14)]
                : null,
          ),
          child: Row(
            children: [
              // İkon madalyonu
              Container(
                width: 32, height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: lit
                      ? accent.withValues(alpha: 0.18)
                      : AppUi.surface0,
                  border: Border.all(
                      color: lit
                          ? accent.withValues(alpha: 0.7)
                          : AppUi.line,
                      width: 1),
                ),
                child: GameIcon(widget.icon,
                    size: 16,
                    color: lit ? AppUi.accentSoft : AppUi.textMid),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(widget.label,
                    style: TextStyle(
                      fontFamily: AppUi.fontDisplay,
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      letterSpacing: 2.0,
                      color: lit ? AppUi.textHi : AppUi.textMid,
                    )),
              ),
              GameIcon(GameIconData.chevron,
                  size: 14,
                  color: lit ? accent : AppUi.textLo.withValues(alpha: 0.6)),
            ],
          ),
        ),
      ),
    );
  }
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

    final hill = Paint()..color = const Color(0xFF231228);
    final hillPath = Path()
      ..moveTo(0, h)
      ..lineTo(0, h * 0.55)
      ..quadraticBezierTo(w * 0.30, h * 0.30, w * 0.55, h * 0.50)
      ..quadraticBezierTo(w * 0.80, h * 0.65, w, h * 0.40)
      ..lineTo(w, h)
      ..close();
    canvas.drawPath(hillPath, hill);

    final ground = Paint()..color = const Color(0xFF140916);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.78, w, h * 0.22), ground);

    void building(double cx, double cy, double bw, double bh,
        {bool hasRoof = true, bool hasWindow = true}) {
      canvas.drawRect(Rect.fromLTWH(cx - bw / 2, cy - bh, bw, bh),
          Paint()..color = const Color(0xFF0C0612));
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
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset(cx, cy - bh * 0.55),
            width: bw * 0.22, height: bh * 0.22),
          Paint()
            ..color = Color.fromRGBO(255, 180, 80, (0.6 * flicker).clamp(0.2, 1.0)),
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
