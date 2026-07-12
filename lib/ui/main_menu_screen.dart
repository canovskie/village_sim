import 'dart:math';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../save/save_manager.dart';
import '../tools/light_editor_main.dart';
import '../tools/placement_editor_main.dart';
import 'about_screen.dart';
import 'app_ui.dart';
import 'save_slots_screen.dart';
import 'settings_screen.dart';
import 'sky_widgets.dart';

/// Açılış ekranı — atmosferik ŞAFAK sahnesi (yeni köy = yeni başlangıç) +
/// zarif altın başlık + temiz koyu menü paneli. Ön planda karşılayıcı köylü
/// silüeti seni bekler. Diegetik-lite: sahne sıcaklığı verir, UI modern kalır.
class MainMenuScreen extends StatefulWidget {
  final VoidCallback onNewGame;
  final void Function(SaveSlotMeta) onContinue;
  const MainMenuScreen({
    super.key,
    required this.onNewGame,
    required this.onContinue,
  });

  @override
  State<MainMenuScreen> createState() => _MainMenuScreenState();
}

class _MainMenuScreenState extends State<MainMenuScreen>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;
  bool _hasSaves = false;

  // Sahnedeki güneşin ekran-uzayı merkezi (ışınlar + hâle bundan türetilir).
  Offset _sunCenter(Size size) =>
      Offset(size.width * 0.72, size.height * 0.44 + 62);

  @override
  void initState() {
    super.initState();
    _refreshHasSaves();
    _ticker = createTicker((elapsed) {
      final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.1);
      _last = elapsed;
      setState(() => _time += dt);
    })..start();
  }

  Future<void> _refreshHasSaves() async {
    final has = await SaveManager.instance.hasAnySave();
    if (mounted) setState(() => _hasSaves = has);
  }

  Future<void> _openSlots() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => SaveSlotsScreen(onContinue: (meta) {
        Navigator.of(context).pop();
        widget.onContinue(meta);
      }),
    ));
    _refreshHasSaves();
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
          // ── Atmosfer (ŞAFAK) ──────────────────────────────────────────────
          const _DawnSky(),
          // Sönmekte olan yıldızlar — sabaha karşı sadece en parlaklar kalır.
          Positioned.fill(child: StarField(opacity: 0.18, time: _time)),
          // Uyanan kuşlar — yüksekte gevşek V, yavaş süzülür.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _WakingBirdsPainter(time: _time),
              ),
            ),
          ),
          // Yükselen güneş (tepelerin ardından doğar — horizon onu kısmen örter).
          Positioned(
            left: _sunCenter(size).dx - 66,
            top: _sunCenter(size).dy - 66,
            child: _SunWithGlow(time: _time),
          ),
          // Güneşten köye uzanan yumuşak sabah ışınları.
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _LightRaysPainter(time: _time, sun: _sunCenter(size)),
              ),
            ),
          ),
          _DriftingClouds(time: _time, screenWidth: size.width),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: CustomPaint(
              size: Size(size.width, size.height * 0.46),
              painter: _HorizonPainter(time: _time),
            ),
          ),
          // Tepelerin eteğinde sürüklenen sabah sisi.
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: CustomPaint(
                size: Size(size.width, size.height * 0.42),
                painter: _MorningMistPainter(time: _time),
              ),
            ),
          ),
          // Güneşe doğru yoğunlaşan alt sıcak parıltı (şafak altını).
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: IgnorePointer(
              child: Container(
                height: size.height * 0.5,
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0.42, 1.0),
                    radius: 1.0,
                    colors: [Color(0x3AFFB25A), Color(0x00FFB25A)],
                  ),
                ),
              ),
            ),
          ),
          // Karşılayıcı köylü — ön planda, şafakla arkadan aydınlanır.
          Positioned(
            left: size.width * 0.05,
            bottom: -4,
            child: IgnorePointer(
              child: _WelcomerVillager(time: _time),
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
                          hasSaves: _hasSaves,
                          onContinue: _openSlots,
                          onSettings: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const SettingsScreen()),
                          ),
                          onAbout: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const AboutScreen()),
                          ),
                          onLightEditor: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const LightEditorScreen()),
                          ),
                          onPlacementEditor: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const PlacementEditorScreen()),
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
        // Oyma altın-ember başlık — ahşap pano yok, gün batımına oturan sıcak
        // tipografi (uzay/çelik değil).
        ShaderMask(
          shaderCallback: (r) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFFF7EFDF), Color(0xFFF1C588), Color(0xFFE0913F)],
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
                      Color(0x00E49139),
                      Color(0xCCE49139),
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
                      Color(0xCCE49139),
                      Color(0x00E49139),
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
  final VoidCallback onNewGame, onSettings, onAbout, onContinue, onLightEditor,
      onPlacementEditor;
  final bool hasSaves;
  const _MenuCard({
    required this.onNewGame,
    required this.onContinue,
    required this.hasSaves,
    required this.onSettings,
    required this.onAbout,
    required this.onLightEditor,
    required this.onPlacementEditor,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.all(14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasSaves) ...[
            _MenuRow(
              icon: GameIconData.home,
              label: 'DEVAM ET',
              primary: true,
              onTap: onContinue,
            ),
            const SizedBox(height: 9),
          ],
          _MenuRow(
            icon: GameIconData.flame,
            label: 'YENİ KÖY',
            primary: !hasSaves,
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
          const SizedBox(height: 9),
          _MenuRow(
            icon: GameIconData.bolt,
            label: 'IŞIK EDİTÖRÜ',
            onTap: onLightEditor,
          ),
          const SizedBox(height: 9),
          _MenuRow(
            icon: GameIconData.hammer,
            label: 'EBAT EDİTÖRÜ',
            onTap: onPlacementEditor,
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
      width: 132, height: 132,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Geniş soluk şafak hâlesi
          Container(
            width: 132, height: 132,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.fromRGBO(255, 226, 178, 0.60 * pulse),
                Color.fromRGBO(255, 190, 120, 0.22 * pulse),
                const Color(0x00FFC080),
              ], stops: const [0.0, 0.45, 1.0]),
            ),
          ),
          // Dar parlak çekirdek — yeni doğan güneş sıcak-beyaz
          Container(
            width: 54, height: 54,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color.fromRGBO(255, 246, 224, 0.9 * pulse),
                const Color(0x00FFE6BE),
              ]),
            ),
          ),
          // Güneş diski — sert kare değil, sıcak-beyaz yumuşak disk
          Container(
            width: 30, height: 30,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                Color(0xFFFFFBF0),
                Color(0xFFFFE7C2),
              ]),
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

    // Sabah bacaları — evler uyanıyor, ocaklar tütüyor.
    void smoke(double cx, double topY) {
      final smk = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
      for (int i = 0; i < 5; i++) {
        final t = i / 4.0;
        final rise = t * 46;
        final wob = sin(time * 0.9 + i * 0.8 + cx) * (5 + t * 10);
        final a = (0.20 * (1 - t)).clamp(0.0, 1.0);
        smk.color = Color.fromRGBO(226, 214, 224, a);
        canvas.drawCircle(
            Offset(cx + wob, topY - rise), 3.0 + t * 5.0, smk);
      }
    }
    smoke(w * 0.18, groundY - 34);
    smoke(w * 0.68, groundY - 36);
  }

  @override
  bool shouldRepaint(_HorizonPainter old) => old.time != time;
}

// ─── Şafak gökyüzü ───────────────────────────────────────────────────────────

/// Çok katmanlı gün doğumu gradyanı: gecenin çivit tepesinden ufkun sıcak
/// altınına — arada leylak ve gül tonları erimeli geçiş yapar.
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
            Color(0xFF1C1B46), // şafak öncesi çivit
            Color(0xFF33285E), // koyu leylak
            Color(0xFF6E4470), // tozlu gül
            Color(0xFFC46C4E), // kehribar-gül
            Color(0xFFEFA451), // ufuk altını
          ],
          stops: [0.0, 0.30, 0.54, 0.76, 1.0],
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
      final a = pi / 2 + (i - (n - 1) / 2) * 0.19 + sin(time * 0.25 + i) * 0.025;
      final width = 30.0 + (i % 3) * 16.0;
      final alpha = i.isEven ? 0.040 : 0.024;
      final ex = cos(a) * len, ey = sin(a) * len;
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(ex - width, ey)
        ..lineTo(ex + width, ey)
        ..close();
      final shader = ui.Gradient.linear(
        Offset.zero,
        Offset(ex, ey),
        [Color.fromRGBO(255, 224, 160, alpha), const Color(0x00FFE0A0)],
      );
      canvas.drawPath(
          path,
          Paint()
            ..shader = shader
            ..blendMode = BlendMode.plus);
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
    for (int i = 0; i < 4; i++) {
      final y = h * (0.42 + i * 0.15);
      final drift = sin(time * 0.14 + i * 1.3) * w * 0.05;
      final a = (0.11 - i * 0.017).clamp(0.0, 1.0);
      p.color = Color.fromRGBO(242, 224, 214, a);
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
      ..color = const Color(0x66201830)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    const offsets = [
      Offset(0, 0), Offset(-22, 10), Offset(22, 10),
      Offset(-44, 22), Offset(44, 22),
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

/// Ön planda bekleyen köylü: şafak arkadan geldiği için gövde koyu silüet,
/// kenarlarda ince sıcak rim-light; elinde sallanan bir fener ışık gölü döker;
/// öbür eliyle usulca el sallar; hafif nefes salınımı var.
class _WelcomerVillager extends StatelessWidget {
  final double time;
  const _WelcomerVillager({required this.time});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(172, 236),
      painter: _WelcomerPainter(time: time),
    );
  }
}

class _WelcomerPainter extends CustomPainter {
  final double time;
  _WelcomerPainter({required this.time});

  static const _silhouette = Color(0xFF181019);
  static const _rim = Color(0xFFFFD79E);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final breathe = sin(time * 1.3) * 1.4; // nefes bob'u
    final feetY = h - 8;
    final cx = w * 0.46;

    final body = Paint()..color = _silhouette;
    final rim = Paint()
      ..color = _rim
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.save();
    canvas.translate(0, breathe);

    // — Yer gölgesi
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, feetY), width: 74, height: 15),
      Paint()
        ..color = const Color(0x552A1220)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );

    // — Fener ışık gölü (yerde, feneri tutan elin altında sola düşer)
    final flick = sin(time * 7.0) * 0.12 + 0.88;
    final lantX = cx - 40;
    final lantY = h * 0.52;
    canvas.drawCircle(
      Offset(lantX, feetY - 4),
      52,
      Paint()
        ..color = Color.fromRGBO(255, 176, 92, 0.28 * flick)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 18),
    );

    // — Bacaklar
    final legTop = h * 0.62;
    canvas.drawRRect(
        RRect.fromRectXY(Rect.fromLTWH(cx - 15, legTop, 12, feetY - legTop), 3, 3),
        body);
    canvas.drawRRect(
        RRect.fromRectXY(Rect.fromLTWH(cx + 3, legTop, 12, feetY - legTop), 3, 3),
        body);

    // — Cübbe / gövde (aşağı doğru genişleyen pelerin)
    final robe = Path()
      ..moveTo(cx - 20, h * 0.40)
      ..lineTo(cx + 20, h * 0.40)
      ..lineTo(cx + 30, feetY - 2)
      ..lineTo(cx - 30, feetY - 2)
      ..close();
    canvas.drawPath(robe, body);

    // — Omuz/başlık
    canvas.drawCircle(Offset(cx, h * 0.30), 20, body); // kukuleta/omuz kütlesi
    // — Baş
    canvas.drawCircle(Offset(cx + 1, h * 0.235), 12.5, body);

    // — Feneri tutan kol (sol, aşağı-dışa) + fener
    final handX = lantX + 6, handY = lantY + 2;
    canvas.drawPath(
      Path()
        ..moveTo(cx - 16, h * 0.44)
        ..quadraticBezierTo(cx - 30, h * 0.50, handX, handY),
      Paint()
        ..color = _silhouette
        ..style = PaintingStyle.stroke
        ..strokeWidth = 8
        ..strokeCap = StrokeCap.round,
    );
    // fener gövdesi
    final lanternSway = sin(time * 1.6) * 2.0;
    final lx = handX + lanternSway, ly = handY + 12;
    canvas.drawRRect(
        RRect.fromRectXY(Rect.fromCenter(center: Offset(lx, ly), width: 13, height: 17), 3, 3),
        Paint()..color = const Color(0xFF241016));
    // fener alevi/camı
    canvas.drawRRect(
      RRect.fromRectXY(Rect.fromCenter(center: Offset(lx, ly), width: 8, height: 11), 2, 2),
      Paint()
        ..color = Color.fromRGBO(255, 198, 110, flick)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5),
    );
    canvas.drawCircle(
      Offset(lx, ly),
      13,
      Paint()
        ..color = Color.fromRGBO(255, 180, 90, 0.5 * flick)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // — Sallayan kol (sağ, yukarı — nazik selam)
    final wave = sin(time * 3.0) * 0.30;
    final shoulder = Offset(cx + 16, h * 0.42);
    final elbow = Offset(cx + 30, h * 0.34);
    final hand = Offset(
      elbow.dx + cos(-1.2 + wave) * 26,
      elbow.dy + sin(-1.2 + wave) * 26,
    );
    canvas.drawPath(
      Path()
        ..moveTo(shoulder.dx, shoulder.dy)
        ..lineTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      Paint()
        ..color = _silhouette
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawCircle(hand, 5.5, body); // el

    // — Rim-light: şafak arkadan geldiği için sağ/üst kenarlar sıcak parlar
    canvas.drawPath(
      Path()
        ..addArc(Rect.fromCircle(center: Offset(cx + 1, h * 0.235), radius: 12.5),
            -pi * 0.85, pi * 0.9), // baş sağ-üst yayı
      rim,
    );
    canvas.drawPath(
      Path()
        ..moveTo(cx + 20, h * 0.40)
        ..lineTo(cx + 30, feetY - 2), // cübbe sağ kenarı
      rim..color = _rim.withValues(alpha: 0.55),
    );
    // sallayan kolun sıcak konturu
    canvas.drawPath(
      Path()
        ..moveTo(elbow.dx, elbow.dy)
        ..lineTo(hand.dx, hand.dy),
      Paint()
        ..color = _rim.withValues(alpha: 0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round,
    );

    canvas.restore();
  }

  @override
  bool shouldRepaint(_WelcomerPainter o) => o.time != time;
}
