import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../rendering/character_renderer.dart';
import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../ui/app_ui.dart';
import 'cutscene.dart';

/// Tam ekran 2B sinematik oynatıcı — [kOpeningCutscene] gibi storyline
/// "filmlerini" oynatır. Prosedürel arka plan + mevcut karakter sprite'ları
/// (CharacterRenderer, asset gerektirmez) aktör olarak. Kendi ticker'ı var;
/// oyun simülasyonundan bağımsız akar. Tıkla = ilerle, sağ üst = Atla.
class CutscenePlayer extends StatefulWidget {
  final Cutscene cutscene;
  final VoidCallback onDone;
  const CutscenePlayer({super.key, required this.cutscene, required this.onDone});

  @override
  State<CutscenePlayer> createState() => _CutscenePlayerState();
}

class _CutscenePlayerState extends State<CutscenePlayer>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _last = Duration.zero;
  double _time = 0;        // genel animasyon saati (yürüyüş/titreşim)
  double _shotElapsed = 0; // mevcut çekimde geçen süre
  int _shotIndex = 0;
  bool _done = false;

  // Tempo sabitleri.
  static const double _charTime = 0.030; // sn/harf (daktilo)
  static const double _lineHold = 1.6;   // satır tam okununca bekleme
  static const double _shotTail = 0.6;   // çekim sonu boşluk
  static const double _actorMove = 4.8;  // aktör fromX→toX süresi
  static const double _fadeIn = 0.55;    // çekim başı karadan açılma

  CutsceneShot get _shot => widget.cutscene.shots[_shotIndex];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time += dt;
    _shotElapsed += dt;
    if (_shotElapsed >= _shotEnd()) _advanceShot();
    setState(() {});
  }

  // ── Satır zamanlaması ──────────────────────────────────────────────────────
  double _reveal(int i) => _shot.lines[i].text.length * _charTime;
  double _lineDur(int i) => _reveal(i) + _lineHold;

  List<double> _lineStarts() {
    final starts = <double>[];
    double t = _fadeIn;
    for (int i = 0; i < _shot.lines.length; i++) {
      starts.add(t);
      t += _lineDur(i);
    }
    return starts;
  }

  double _contentEnd() {
    final lines = _shot.lines;
    if (lines.isEmpty) return _shot.actors.isNotEmpty ? _actorMove : 2.0;
    final starts = _lineStarts();
    return starts.last + _lineDur(lines.length - 1);
  }

  double _shotEnd() =>
      max(_contentEnd(), _shot.actors.isNotEmpty ? _actorMove : 0.0) + _shotTail;

  int _currentLine() {
    if (_shot.lines.isEmpty) return -1;
    final starts = _lineStarts();
    int idx = 0;
    for (int i = 0; i < starts.length; i++) {
      if (_shotElapsed >= starts[i]) idx = i;
    }
    return idx;
  }

  void _advanceShot() {
    if (_shotIndex >= widget.cutscene.shots.length - 1) {
      _finish();
      return;
    }
    _shotIndex++;
    _shotElapsed = 0;
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _onTap() {
    final lines = _shot.lines;
    if (lines.isEmpty) {
      _shotElapsed = _shotEnd();
      return;
    }
    final idx = _currentLine();
    final starts = _lineStarts();
    final revealEnd = starts[idx] + _reveal(idx);
    if (_shotElapsed < revealEnd) {
      _shotElapsed = revealEnd; // önce daktiloyu bitir
    } else if (idx < lines.length - 1) {
      _shotElapsed = starts[idx + 1]; // sonraki satır
    } else {
      _shotElapsed = _shotEnd(); // çekimi kapat
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _currentLine();
    final CutsceneLine? line = idx >= 0 ? _shot.lines[idx] : null;
    String shown = '';
    if (line != null) {
      final starts = _lineStarts();
      final le = _shotElapsed - starts[idx];
      final n = (le / _charTime).floor().clamp(0, line.text.length);
      shown = line.text.substring(0, n);
    }
    // Çekim başı karadan açılma katsayısı.
    final fade = (_shotElapsed / _fadeIn).clamp(0.0, 1.0);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _onTap,
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _CutscenePainter(
                shot: _shot,
                time: _time,
                shotElapsed: _shotElapsed,
                fade: fade,
                actorP: (_shotElapsed / _actorMove).clamp(0.0, 1.0),
              ),
            ),
          ),
          // Diyalog kutusu.
          if (shown.isNotEmpty) _dialogueBox(line!, shown),
          // Atla.
          Positioned(
            top: 0,
            right: 0,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: TextButton(
                  onPressed: _finish,
                  style: TextButton.styleFrom(
                    foregroundColor: AppUi.textMid,
                    backgroundColor: const Color(0x55000000),
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppUi.radiusSm)),
                  ),
                  child: Text('Atla ▸',
                      style: AppUi.button.copyWith(color: AppUi.textMid)),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dialogueBox(CutsceneLine line, String shown) {
    final isNarration = line.speaker == null;
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 620),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
                decoration: BoxDecoration(
                  color: const Color(0xF21A130B),
                  borderRadius: BorderRadius.circular(AppUi.radiusSm),
                  border: Border.all(color: AppUi.line, width: 1),
                  boxShadow: AppUi.softShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isNarration) ...[
                      Text(line.speaker!.toUpperCase(),
                          style: AppUi.label.copyWith(color: AppUi.accent)),
                      const SizedBox(height: 6),
                    ],
                    Text(
                      shown,
                      style: TextStyle(
                        fontFamily: AppUi.fontText,
                        fontStyle:
                            isNarration ? FontStyle.italic : FontStyle.normal,
                        fontWeight: FontWeight.w500,
                        fontSize: 16,
                        height: 1.4,
                        color: AppUi.textHi,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Prosedürel arka plan + aktör çizimi. CharacterRenderer origin'de çizer;
/// translate+scale ile sahneye yerleştirilir. Kamera pan/zoom tüm sahneye.
class _CutscenePainter extends CustomPainter {
  final CutsceneShot shot;
  final double time;
  final double shotElapsed;
  final double fade;   // 0→1 karadan açılma
  final double actorP; // 0→1 aktör ilerlemesi
  _CutscenePainter({
    required this.shot,
    required this.time,
    required this.shotElapsed,
    required this.fade,
    required this.actorP,
  });

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _ease(double t) => t * t * (3 - 2 * t);

  @override
  void paint(Canvas canvas, Size size) {
    // Kamera: çekim süresince pan/zoom — kabaca contentEnd üzerinden normalize.
    final dur = max(2.0, shotElapsed); // güvenli
    final camT = _ease((shotElapsed / (dur + 3.0)).clamp(0.0, 1.0));
    final pan = _lerp(shot.panFrom, shot.panTo, camT) * size.width;
    final zoom = _lerp(shot.zoomFrom, shot.zoomTo, camT);

    canvas.save();
    canvas.clipRect(Offset.zero & size);
    // Zoom (merkez etrafı) + pan.
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(zoom);
    canvas.translate(-size.width / 2, -size.height / 2);
    canvas.translate(-pan, 0);

    _paintBackground(canvas, size);
    _paintActors(canvas, size);

    canvas.restore();

    // Sinematik letterbox bantları (üst/alt) — film hissi.
    final barH = size.height * 0.10;
    final barPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, barH), barPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, size.height - barH, size.width, barH), barPaint);

    // Karadan açılma.
    if (fade < 1.0) {
      canvas.drawRect(Offset.zero & size,
          Paint()..color = Color.fromRGBO(0, 0, 0, 1.0 - fade));
    }
  }

  // ── Arka planlar (prosedürel) ──────────────────────────────────────────────
  void _paintBackground(Canvas canvas, Size size) {
    switch (shot.bg) {
      case CutsceneBg.valleyDawn:
        _sky(canvas, size, const [
          Color(0xFFF6C79E), Color(0xFFF9DDBE), Color(0xFFFBEFD6),
        ]);
        _sun(canvas, size, const Offset(0.72, 0.34), 30,
            const Color(0xFFFFE6B0));
        _hills(canvas, size, 0.62, const Color(0xFFB69FB0), 3, 0.05);
        _hills(canvas, size, 0.70, const Color(0xFF8FA07E), 5, 0.10);
        _ground(canvas, size, 0.78, const Color(0xFF6E7E54));
      case CutsceneBg.road:
        _sky(canvas, size, const [
          Color(0xFFAFD8EE), Color(0xFFCDE9F6), Color(0xFFEAF6FF),
        ]);
        _hills(canvas, size, 0.66, const Color(0xFF9FC089), 4, 0.06);
        _ground(canvas, size, 0.80, const Color(0xFF7C9A55));
        _path(canvas, size);
      case CutsceneBg.valleyDusk:
        _sky(canvas, size, const [
          Color(0xFF4A3A66), Color(0xFF9A5E72), Color(0xFFE8915A),
        ]);
        _sun(canvas, size, const Offset(0.5, 0.52), 36,
            const Color(0xFFFFCB6E));
        _hills(canvas, size, 0.64, const Color(0xFF5A4566), 3, 0.05);
        _hills(canvas, size, 0.72, const Color(0xFF3A3048), 5, 0.10);
        _ground(canvas, size, 0.80, const Color(0xFF2C2436));
      case CutsceneBg.fireNight:
        _sky(canvas, size, const [
          Color(0xFF0A1330), Color(0xFF142244), Color(0xFF1E3052),
        ]);
        _stars(canvas, size);
        _hills(canvas, size, 0.66, const Color(0xFF0E1A30), 4, 0.06);
        _ground(canvas, size, 0.80, const Color(0xFF0A1322));
        _fireGlow(canvas, size, const Offset(0.5, 0.80));
      case CutsceneBg.titleCard:
        canvas.drawRect(Offset.zero & size,
            Paint()..color = const Color(0xFF0C0A07));
        // Hafif radyal vinyet ışığı + uçuşan közler.
        final c = Offset(size.width * 0.5, size.height * 0.52);
        canvas.drawCircle(
            c,
            size.width * 0.4,
            Paint()
              ..shader = RadialGradient(colors: [
                AppUi.accent.withValues(alpha: 0.10),
                const Color(0x00000000),
              ]).createShader(Rect.fromCircle(center: c, radius: size.width * 0.4)));
        _embers(canvas, size);
    }
  }

  void _sky(Canvas canvas, Size size, List<Color> colors) {
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors,
          ).createShader(Offset.zero & size));
  }

  void _sun(Canvas canvas, Size size, Offset norm, double r, Color col) {
    final c = Offset(norm.dx * size.width, norm.dy * size.height);
    canvas.drawCircle(c, r * 2.4,
        Paint()..shader = RadialGradient(colors: [
          col.withValues(alpha: 0.5),
          col.withValues(alpha: 0.0),
        ]).createShader(Rect.fromCircle(center: c, radius: r * 2.4)));
    canvas.drawCircle(c, r, Paint()..color = col);
  }

  /// Tepe silüeti — birkaç sinüs tümseği, [baseY] normalize, [bumps] tümsek.
  void _hills(Canvas canvas, Size size, double baseY, Color col, int bumps,
      double amp) {
    final path = Path()..moveTo(0, size.height);
    final y0 = baseY * size.height;
    final a = amp * size.height;
    path.lineTo(0, y0);
    const steps = 48;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y = y0 - a * (0.5 + 0.5 * sin(i / steps * pi * bumps + baseY * 10));
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, Paint()..color = col);
  }

  void _ground(Canvas canvas, Size size, double topY, Color col) {
    canvas.drawRect(
        Rect.fromLTWH(0, topY * size.height, size.width,
            size.height * (1 - topY)),
        Paint()..color = col);
  }

  void _path(Canvas canvas, Size size) {
    final top = size.height * 0.80;
    final p = Path()
      ..moveTo(size.width * 0.46, top)
      ..lineTo(size.width * 0.54, top)
      ..lineTo(size.width * 0.72, size.height)
      ..lineTo(size.width * 0.28, size.height)
      ..close();
    canvas.drawPath(p, Paint()..color = const Color(0xFFCBB07A));
  }

  void _stars(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    for (int i = 0; i < 60; i++) {
      final x = ((i * 73) % 100) / 100 * size.width;
      final y = ((i * 37) % 100) / 100 * size.height * 0.62;
      final tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(time * 2 + i));
      canvas.drawCircle(
          Offset(x, y), 1.0, paint..color = Color.fromRGBO(255, 255, 255, tw * 0.8));
    }
  }

  void _fireGlow(Canvas canvas, Size size, Offset norm) {
    final c = Offset(norm.dx * size.width, norm.dy * size.height);
    final flick = 0.85 + 0.15 * sin(time * 9) + 0.08 * sin(time * 17);
    final r = size.width * 0.30 * flick;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFB24D).withValues(alpha: 0.55 * flick),
            const Color(0xFFE9742E).withValues(alpha: 0.18),
            const Color(0x00000000),
          ], stops: const [0.0, 0.45, 1.0])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    // Köz çekirdeği.
    canvas.drawCircle(c, 7 * flick, Paint()..color = const Color(0xFFFFD27A));
  }

  void _embers(Canvas canvas, Size size) {
    final paint = Paint();
    for (int i = 0; i < 26; i++) {
      final phase = (time * 0.25 + i * 0.137) % 1.0;
      final x = ((i * 53) % 100) / 100 * size.width +
          sin(time + i) * 12;
      final y = size.height * (0.95 - phase * 0.7);
      final a = (1 - phase) * 0.6;
      paint.color = Color.fromRGBO(233, 138, 56, a);
      canvas.drawCircle(Offset(x, y), 1.6, paint);
    }
  }

  // ── Aktörler ────────────────────────────────────────────────────────────────
  void _paintActors(Canvas canvas, Size size) {
    final p = _ease(actorP);
    for (final a in shot.actors) {
      final nx = _lerp(a.fromX, a.toX, a.fromX == a.toX ? 1.0 : p);
      final x = nx * size.width;
      final y = a.y * size.height;
      final targetH = size.height * 0.30 * a.scale;
      final s = targetH / 90.0;
      final wp = a.walk ? time * 8.0 : 0.0;
      final mi = a.walk ? 1.0 : 0.0;

      // Yumuşak zemin gölgesi.
      canvas.drawOval(
          Rect.fromCenter(
              center: Offset(x, y + 2), width: targetH * 0.5, height: targetH * 0.12),
          Paint()..color = const Color(0x33000000));

      canvas.save();
      canvas.translate(x, y);
      canvas.scale(s, s);
      CharacterRenderer.draw(
        canvas,
        a.type,
        flipX: a.flip,
        walkPhase: wp,
        moveIntensity: mi,
        visual: NpcVisual.fromSeed(a.seed),
        time: time,
        stage: LifeStage.adult,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CutscenePainter old) => true;
}
