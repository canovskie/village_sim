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
  /// nameVillage kapısı onaylanınca girilen ad (host kimliğe/günceye işler).
  final void Function(String name)? onNameChosen;
  const CutscenePlayer({
    super.key,
    required this.cutscene,
    required this.onDone,
    this.onNameChosen,
  });

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

  // Mini-aksiyon (gate) durumu.
  bool _gateSatisfied = false;   // mevcut çekimin kapısı geçildi mi
  double _gateSatisfiedAt = 0;   // ignite flash için zaman damgası
  final _nameCtrl = TextEditingController();

  // Tempo sabitleri — sakin, sinematik (aceleci kayma yok).
  static const double _charTime = 0.032; // sn/harf (daktilo)
  static const double _lineHold = 2.1;   // satır tam okununca bekleme
  static const double _shotTail = 1.0;   // çekim sonu boşluk
  static const double _actorMove = 4.0;  // aktör fromX→toX (yürüyüp oturur)
  static const double _fadeIn = 0.7;     // çekim başı karadan açılma

  CutsceneShot get _shot => widget.cutscene.shots[_shotIndex];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  bool get _gated => _shot.gate != CutsceneGate.none && !_gateSatisfied;

  void _onTick(Duration elapsed) {
    final dt = ((elapsed - _last).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _time += dt;
    if (_gated) {
      // Kapı: replikler oynasın (Maple konuşsun) ama satırlar bitince DURSUN;
      // sonra kapı UI'ı (ad kutusu / ateş ipucu) belirir.
      _shotElapsed = min(_shotElapsed + dt, _gateReadyAt());
    } else {
      _shotElapsed += dt;
      if (_shotElapsed >= _shotEnd()) _advanceShot();
    }
    setState(() {});
  }

  /// Kapılı çekimde repliklerin tam yazıldığı an — kapı UI'ı bundan sonra çıkar.
  double _gateReadyAt() {
    if (_shot.lines.isEmpty) return _fadeIn;
    final starts = _lineStarts();
    final last = _shot.lines.length - 1;
    return starts[last] + _reveal(last);
  }

  bool get _gateReady => _gated && _shotElapsed >= _gateReadyAt() - 0.001;

  void _satisfyGate() {
    if (_gateSatisfied) return;
    setState(() {
      _gateSatisfied = true;
      _gateSatisfiedAt = _time;
    });
  }

  void _submitName() {
    final name = _nameCtrl.text.trim();
    widget.onNameChosen?.call(name.isEmpty ? 'Köy' : name);
    _satisfyGate();
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
    _gateSatisfied = false; // yeni çekimin kapısı tazelenir
  }

  void _finish() {
    if (_done) return;
    _done = true;
    widget.onDone();
  }

  void _onTap() {
    // Kapı bekliyorsa: önce daktiloyu bitir; sonra ateş→dokun yakar,
    // ad→giriş alanı yönetir (base no-op).
    if (_gated) {
      if (_shotElapsed < _gateReadyAt()) {
        _shotElapsed = _gateReadyAt();
        return;
      }
      if (_shot.gate == CutsceneGate.tapToIgnite) _satisfyGate();
      return;
    }
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

    final igniteShot = _shot.gate == CutsceneGate.tapToIgnite;
    final nameShot = _shot.gate == CutsceneGate.nameVillage;
    final ignited = !igniteShot || _gateSatisfied;
    final igniteElapsed = _gateSatisfied ? (_time - _gateSatisfiedAt) : -1.0;

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
                // Aktör: fadeIn sonrası başlar, _actorMove'da varır.
                actorP: ((_shotElapsed - _fadeIn) / _actorMove).clamp(0.0, 1.0),
                // Kamera: çekim boyunca yayılır, sonunda oturur (drift yok).
                camT: (_shotElapsed / _shotEnd()).clamp(0.0, 1.0),
                ignited: ignited,
                igniteElapsed: igniteElapsed,
              ),
            ),
          ),
          // Diyalog kutusu.
          if (shown.isNotEmpty) _dialogueBox(line!, shown),
          // "▸ Devam" göstergesi — satır tam yazıldığında, kapı yokken belirir.
          // Böylece ilerlemenin ekrana dokunmakla olduğu NET (rastgele değil).
          if (_showContinueHint(line, shown)) _continueHint(),
          // Ateşi yak ipucu (replikler bitti, kapı bekliyor).
          if (igniteShot && _gateReady) _igniteHint(),
          // Köye ad ver girişi (replikler bitti, kapı bekliyor).
          if (nameShot && _gateReady) _nameInput(),
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

  /// Satır tam yazıldı + kapı yok → "devam" ipucu gösterilebilir.
  bool _showContinueHint(CutsceneLine? line, String shown) =>
      line != null && !_gated && shown == line.text;

  /// "▸ Devam" — sağ altta nabız atan ipucu; ilerlemenin dokunmakla
  /// olduğunu netleştirir (rastgele tıklama hissini giderir).
  Widget _continueHint() {
    final pulse = 0.45 + 0.35 * sin(_time * 3.2);
    return Positioned(
      right: 22,
      bottom: 30,
      child: IgnorePointer(
        child: Opacity(
          opacity: pulse,
          child: Text('dokun ▸',
              style: AppUi.button.copyWith(color: AppUi.textHi)),
        ),
      ),
    );
  }

  /// "Ateşi yakmak için dokun" ipucu — nabız atan, ateşin üstünde.
  Widget _igniteHint() {
    final pulse = 0.55 + 0.45 * sin(_time * 3.0);
    return Align(
      alignment: const Alignment(0, 0.30),
      child: IgnorePointer(
        child: Opacity(
          opacity: pulse,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
            decoration: BoxDecoration(
              color: const Color(0x66000000),
              borderRadius: BorderRadius.circular(AppUi.radiusSm),
              border: Border.all(color: AppUi.accent.withValues(alpha: 0.7)),
            ),
            child: Text('✦  Ateşi yakmak için dokun',
                style: AppUi.button.copyWith(color: AppUi.accentSoft)),
          ),
        ),
      ),
    );
  }

  /// Köye ad ver girişi — metin alanı + onay. Onaylanınca kapı geçilir.
  Widget _nameInput() {
    return Align(
      alignment: const Alignment(0, 0.2),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 380),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
          decoration: BoxDecoration(
            color: const Color(0xF21A130B),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(color: AppUi.accent.withValues(alpha: 0.6)),
            boxShadow: AppUi.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('BU YUVAYA BİR AD VER',
                  style: AppUi.label.copyWith(color: AppUi.accent)),
              const SizedBox(height: 12),
              TextField(
                controller: _nameCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                maxLength: 22,
                onSubmitted: (_) => _submitName(),
                style: AppUi.bodyHi.copyWith(fontSize: 16),
                cursorColor: AppUi.accent,
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'örn. Pınarköy',
                  hintStyle: AppUi.body.copyWith(color: AppUi.textLo),
                  filled: true,
                  fillColor: AppUi.surface0,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    borderSide: const BorderSide(color: AppUi.line),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    borderSide: const BorderSide(color: AppUi.accent),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: _submitName,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppUi.accent,
                      borderRadius: BorderRadius.circular(AppUi.radiusSm),
                    ),
                    child: Text('Adını koy ▸',
                        style: AppUi.button
                            .copyWith(color: const Color(0xFF1A0E04))),
                  ),
                ),
              ),
            ],
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
  final double camT;   // 0→1 kamera ilerlemesi (state çekim süresine bağlar)
  final bool ignited;  // tapToIgnite: ateş yandı mı (yanmadan glow çizilmez)
  final double igniteElapsed; // yandıktan sonra geçen süre (flash); <0 = yok
  _CutscenePainter({
    required this.shot,
    required this.time,
    required this.shotElapsed,
    required this.fade,
    required this.actorP,
    required this.camT,
    this.ignited = true,
    this.igniteElapsed = -1.0,
  });

  double _lerp(double a, double b, double t) => a + (b - a) * t;
  double _ease(double t) => t * t * (3 - 2 * t);

  @override
  void paint(Canvas canvas, Size size) {
    // Kamera: pan/zoom çekim boyunca KASITLI ilerler ve sonunda oturur
    // (sonsuz drift yok). camT state'te shotEnd'e göre normalize edilir.
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
        // Odun yığını her zaman; ateş+hâle yanma seviyesine (fireLevel) göre.
        _logs(canvas, Offset(size.width * 0.5, size.height * 0.80),
            size.height * 0.10);
        // Yanma seviyesi: gate (dokun) ise yanınca ramp; gate yoksa oto-bloom.
        double fireLevel;
        if (shot.gate == CutsceneGate.tapToIgnite) {
          fireLevel = ignited ? (igniteElapsed / 0.6).clamp(0.0, 1.0) : 0.0;
        } else {
          fireLevel = (shotElapsed / 1.3).clamp(0.0, 1.0);
        }
        if (fireLevel > 0.02) {
          _fireGlow(canvas, size, const Offset(0.5, 0.80), fireLevel);
        }
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

  /// Yakılmamış odun yığını — ateş yanmadan önce görünür (dokun ipucu hedefi).
  void _logs(Canvas canvas, Offset base, double s) {
    final wood = Paint()..color = const Color(0xFF3A2412);
    canvas.save();
    canvas.translate(base.dx, base.dy);
    for (final a in [-0.5, 0.0, 0.5]) {
      canvas.save();
      canvas.rotate(a);
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              Rect.fromCenter(center: Offset.zero, width: s * 1.4, height: s * 0.22),
              const Radius.circular(2)),
          wood);
      canvas.restore();
    }
    canvas.restore();
  }

  /// [level] 0..1 — yanma şiddeti (oto-bloom / dokunma rampası). Boyut+alfa ölçer.
  void _fireGlow(Canvas canvas, Size size, Offset norm, [double level = 1.0]) {
    final c = Offset(norm.dx * size.width, norm.dy * size.height);
    final flick = 0.85 + 0.15 * sin(time * 9) + 0.08 * sin(time * 17);
    final r = size.width * 0.30 * flick * (0.45 + 0.55 * level);
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFB24D).withValues(alpha: 0.55 * flick * level),
            const Color(0xFFE9742E).withValues(alpha: 0.18 * level),
            const Color(0x00000000),
          ], stops: const [0.0, 0.45, 1.0])
              .createShader(Rect.fromCircle(center: c, radius: r)));
    // Köz çekirdeği.
    canvas.drawCircle(
        c, 7 * flick * level, Paint()..color = const Color(0xFFFFD27A));
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
      final arrived = a.fromX == a.toX || p >= 1.0;
      final nx = _lerp(a.fromX, a.toX, arrived ? 1.0 : p);
      final x = nx * size.width;
      final y = a.y * size.height;
      final targetH = size.height * 0.30 * a.scale;
      final s = targetH / 90.0;
      // Yürüme animasyonu YALNIZ hareket ederken; varınca durur (yerinde
      // yürüme yok). facing yön: sağa giderken flip yok, dururken a.flip.
      final moving = a.walk && !arrived;
      final wp = moving ? time * 8.0 : 0.0;
      final mi = moving ? 1.0 : 0.0;
      final flip = moving ? false : a.flip;

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
        flipX: flip,
        walkPhase: wp,
        moveIntensity: mi,
        visual: a.visual ?? NpcVisual.fromSeed(a.seed),
        time: time,
        stage: LifeStage.adult,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(covariant _CutscenePainter old) => true;
}
