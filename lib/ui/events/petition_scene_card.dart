import 'dart:math';
import 'package:flutter/material.dart';
import '../systems/petition_system.dart';
import 'app_ui.dart';

/// Dilekçe konusunu anlatan 2B illüstrasyon panosu — modalın tepesinde
/// sinematik bir "boyalı olay karesi" gibi durur (Total War ikilem panosu
/// hissi; oyunu DURDURMAZ). Tamamen prosedürel: atmosferik gökyüzü + güneş/ay
/// diski + ufuk parıltısı + hava-perspektifli tepe katmanları + ön-plan silüet
/// çerçevesi (derinlik) + yükselen kor/zerre + konuya özel motif + sinematik
/// vinyet. Açılış sinematiğiyle aynı dil, ama statik ve modal-içi.

enum PetitionScene { fire, herd, field, market, shrine, home, gathering, generic }

/// Dilekçeyi konusuna göre bir sahneye eşler (id öncelikli, sonra zümre/ton).
PetitionScene petitionSceneFor(Petition p) {
  final id = p.id.toLowerCase();
  if (id.contains('fire') || id.contains('ate')) return PetitionScene.fire;
  if (id.contains('herd') || id.contains('animal') || id.contains('fodder')) {
    return PetitionScene.herd;
  }
  if (id.contains('harvest') || id.contains('crop') || id.contains('farm') ||
      id.contains('blight')) {
    return PetitionScene.field;
  }
  if (id.contains('market') || id.contains('artisan') || id.contains('trade')) {
    return PetitionScene.market;
  }
  if (id.contains('church') || id.contains('faith') || id.contains('cult') ||
      id.contains('vigil') || id.contains('remembr')) {
    return PetitionScene.shrine;
  }
  if (id.contains('house') || id.contains('home') || id.contains('hearth')) {
    return PetitionScene.home;
  }
  if (id.contains('festival') || id.contains('wedding') ||
      id.contains('gather') || id.contains('story')) {
    return PetitionScene.gathering;
  }
  // Zümre ipucu.
  return switch (p.estate?.name) {
    'laborers' => PetitionScene.field,
    'artisans' => PetitionScene.market,
    'faithful' => PetitionScene.shrine,
    'hearth' => PetitionScene.home,
    _ => PetitionScene.generic,
  };
}

class PetitionSceneCard extends StatelessWidget {
  /// Dilekçeden türeyen sahne (klasik kullanım). null ise [scene]+[tone] verilir.
  final Petition? petition;

  /// Doğrudan sahne/ton (dilekçe olmadan — ör. Divan hero'su `gathering`). Bunlar
  /// verilince [petition] yok sayılır.
  final PetitionScene? scene;
  final PetitionTone tone;

  final double height;

  /// Kenarlığı kart kendi çizer mi — hero olarak kullanılınca modal altın
  /// çerçeveyi üstten geçirir, o yüzden kapatılır (çift kenar olmasın).
  final bool drawBorder;

  const PetitionSceneCard({
    super.key,
    required this.petition,
    this.height = 92,
    this.drawBorder = true,
  })  : scene = null,
        tone = PetitionTone.neutral;

  /// Dilekçesiz doğrudan sahne — Divan/toplanma hero'su gibi bağlamlar için.
  const PetitionSceneCard.custom({
    super.key,
    required PetitionScene this.scene,
    this.tone = PetitionTone.neutral,
    this.height = 92,
    this.drawBorder = true,
  }) : petition = null;

  @override
  Widget build(BuildContext context) {
    final resolvedScene = scene ?? petitionSceneFor(petition!);
    final resolvedTone = scene != null ? tone : petition!.tone;
    final accent = switch (resolvedTone) {
      PetitionTone.warm => AppUi.sage,
      PetitionTone.solemn => AppUi.textMid,
      PetitionTone.ominous => AppUi.rust,
      PetitionTone.neutral => AppUi.accent,
    };
    final card = SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SceneCardPainter(
          scene: resolvedScene,
          tone: resolvedTone,
        ),
        size: Size.infinite,
      ),
    );
    // Hero modunda (drawBorder=false) köşeleri dış altın çerçeve yuvarlar —
    // kart tam dikdörtgen kalır (köşe çentiği olmasın). Aksi hâlde kendi
    // ton-aksanlı kenarı + yumuşatılmış köşesiyle bağımsız bir kart.
    if (!drawBorder) return card;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUi.radiusSm),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
        ),
        child: card,
      ),
    );
  }
}

class _SceneCardPainter extends CustomPainter {
  final PetitionScene scene;
  final PetitionTone tone;
  _SceneCardPainter({required this.scene, required this.tone});

  // Ton → gökyüzü paleti (zenit→ufuk, 4 kademe → daha derin atmosfer).
  List<Color> get _sky => switch (tone) {
        PetitionTone.warm => const [
            Color(0xFF221334),
            Color(0xFF3A2A50),
            Color(0xFF8A5570),
            Color(0xFFE8915A),
          ],
        PetitionTone.solemn => const [
            Color(0xFF19202A),
            Color(0xFF2A3340),
            Color(0xFF4E5C6A),
            Color(0xFF8B98A6),
          ],
        PetitionTone.ominous => const [
            Color(0xFF140D0F),
            Color(0xFF20161B),
            Color(0xFF4A2A2A),
            Color(0xFF85483A),
          ],
        PetitionTone.neutral => const [
            Color(0xFF5C94BC),
            Color(0xFF7FB0D0),
            Color(0xFFBFDDEE),
            Color(0xFFEAF4FB),
          ],
      };

  // Ufuktaki sıcak/soğuk parıltı ve gök cisminin (güneş/ay) rengi.
  Color get _glow => switch (tone) {
        PetitionTone.warm => const Color(0xFFFFB870),
        PetitionTone.solemn => const Color(0xFFB9C6D6),
        PetitionTone.ominous => const Color(0xFFE0633A),
        PetitionTone.neutral => const Color(0xFFFFF4D6),
      };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.clipRect(Offset.zero & size);
    final horizon = h * 0.66;

    // ── Gökyüzü ──────────────────────────────────────────────────────────────
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _sky,
            stops: const [0.0, 0.34, 0.74, 1.0],
          ).createShader(Offset.zero & size));

    // ── Gök cismi (güneş/ay) — tona göre konum/parlaklık ─────────────────────
    _celestial(canvas, size, horizon);

    // ── Ufuk parıltısı — gök cisminin tabanından yayılan yatay ışık bandı ────
    final glowRect = Rect.fromLTWH(0, horizon - h * 0.34, w, h * 0.40);
    canvas.drawRect(
        glowRect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(
            center: const Alignment(0.0, 0.6),
            radius: 1.1,
            colors: [
              _glow.withValues(alpha: tone == PetitionTone.neutral ? 0.34 : 0.40),
              _glow.withValues(alpha: 0.0),
            ],
          ).createShader(glowRect));

    // ── Tepe katmanları — hava perspektifi (uzak hazlı→yakın koyu) ───────────
    _hills(canvas, size, horizon - h * 0.05, _haze(0.78), 3, h * 0.085);
    _hills(canvas, size, horizon + h * 0.04, _haze(0.50), 5, h * 0.12);
    _hills(canvas, size, horizon + h * 0.13, _haze(0.26), 7, h * 0.10);

    // ── Zemin ────────────────────────────────────────────────────────────────
    canvas.drawRect(Rect.fromLTWH(0, h * 0.82, w, h * 0.18),
        Paint()..color = _haze(0.14));

    // ── Konu motifi ──────────────────────────────────────────────────────────
    final groundY = h * 0.86;
    switch (scene) {
      case PetitionScene.fire:
        _fire(canvas, Offset(w * 0.5, groundY), h * 0.34);
        _figure(canvas, Offset(w * 0.32, groundY), h * 0.17);
        _figure(canvas, Offset(w * 0.68, groundY), h * 0.17);
      case PetitionScene.herd:
        _animal(canvas, Offset(w * 0.34, groundY), h * 0.15);
        _animal(canvas, Offset(w * 0.52, groundY + h * 0.03), h * 0.12);
        _animal(canvas, Offset(w * 0.70, groundY - h * 0.01), h * 0.14);
        _figure(canvas, Offset(w * 0.86, groundY), h * 0.16);
      case PetitionScene.field:
        for (int i = 0; i < 9; i++) {
          _wheat(canvas, Offset(w * (0.12 + i * 0.085), groundY + h * 0.02),
              h * 0.20);
        }
        _figure(canvas, Offset(w * 0.5, groundY - h * 0.02), h * 0.18);
      case PetitionScene.market:
        _stall(canvas, Offset(w * 0.36, groundY), w * 0.26, h * 0.26);
        _stall(canvas, Offset(w * 0.66, groundY + h * 0.02), w * 0.22, h * 0.22);
        _figure(canvas, Offset(w * 0.51, groundY + h * 0.02), h * 0.15);
      case PetitionScene.shrine:
        _shrine(canvas, Offset(w * 0.5, groundY), w * 0.20, h * 0.42);
        _figure(canvas, Offset(w * 0.31, groundY), h * 0.15);
        _figure(canvas, Offset(w * 0.69, groundY), h * 0.15);
      case PetitionScene.home:
        _house(canvas, Offset(w * 0.5, groundY), w * 0.26, h * 0.34);
        _house(canvas, Offset(w * 0.78, groundY + h * 0.02), w * 0.18, h * 0.24);
      case PetitionScene.gathering:
        _fire(canvas, Offset(w * 0.5, groundY), h * 0.24);
        _figure(canvas, Offset(w * 0.30, groundY), h * 0.19);
        _figure(canvas, Offset(w * 0.70, groundY), h * 0.19);
        _figure(canvas, Offset(w * 0.18, groundY + h * 0.02), h * 0.15);
        _figure(canvas, Offset(w * 0.82, groundY + h * 0.02), h * 0.15);
      case PetitionScene.generic:
        _house(canvas, Offset(w * 0.34, groundY), w * 0.18, h * 0.26);
        _shrine(canvas, Offset(w * 0.56, groundY - h * 0.01), w * 0.12, h * 0.30);
        _house(canvas, Offset(w * 0.74, groundY + h * 0.02), w * 0.15, h * 0.20);
    }

    // ── Ön-plan silüet çerçevesi — kenarlarda flu otlar/dallar (derinlik) ─────
    _foreground(canvas, size);

    // ── Atmosfer zerresi — yükselen kor / süzülen toz (tona göre) ────────────
    _particles(canvas, size, horizon);

    // ── Sinematik vinyet — köşe karartma + film hissi ────────────────────────
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(0.0, -0.15),
            radius: 1.25,
            colors: [Color(0x00000000), Color(0x66000000)],
            stops: [0.62, 1.0],
          ).createShader(Offset.zero & size));
    // Üst letterbox + alt taban karartma (başlık/portre okunaklılığı için zemin).
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0x4A000000),
              Color(0x00000000),
              Color(0x00000000),
              Color(0x59000000),
            ],
            stops: [0.0, 0.22, 0.72, 1.0],
          ).createShader(Offset.zero & size));
  }

  // Sky paletini koyu zemine doğru karıştırarak tepe/zemin tonu üretir.
  // t büyüdükçe daha açık (gök rengine yakın → uzak hava perspektifi).
  Color _haze(double t) =>
      Color.lerp(const Color(0xFF0F0E14), _sky[2], t * 0.55)!;

  void _celestial(Canvas c, Size size, double horizon) {
    final w = size.width, h = size.height;
    // Tona göre konum: sıcak/ominous alçak (gün batımı), solemn/neutral yüksek.
    final (cx, cy, r, bright) = switch (tone) {
      PetitionTone.warm => (w * 0.70, horizon - h * 0.06, h * 0.13, 0.95),
      PetitionTone.solemn => (w * 0.26, h * 0.26, h * 0.10, 0.70),
      PetitionTone.ominous => (w * 0.64, horizon - h * 0.02, h * 0.12, 0.80),
      PetitionTone.neutral => (w * 0.74, h * 0.24, h * 0.11, 1.0),
    };
    final center = Offset(cx, cy);
    // Geniş atmosferik hâle.
    c.drawCircle(
        center,
        r * 3.4,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(colors: [
            _glow.withValues(alpha: 0.42 * bright),
            _glow.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: center, radius: r * 3.4)));
    // Disk.
    c.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(_glow, Colors.white, 0.5 * bright)!,
            _glow.withValues(alpha: 0.85),
          ]).createShader(Rect.fromCircle(center: center, radius: r)));
    // Ay ise hafif gölge hilali (solemn).
    if (tone == PetitionTone.solemn) {
      c.drawCircle(center.translate(r * 0.42, -r * 0.28), r * 0.92,
          Paint()..color = _sky[1].withValues(alpha: 0.85));
    }
  }

  void _hills(Canvas c, Size size, double baseY, Color col, int bumps, double amp) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseY);
    const steps = 48;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final t = i / steps;
      // İki frekanslı dalga → daha organik sırt.
      final y = baseY -
          amp * (0.5 + 0.5 * sin(t * pi * bumps + baseY)) -
          amp * 0.35 * sin(t * pi * (bumps * 2.3) + baseY * 0.7);
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    c.drawPath(path, Paint()..color = col);
  }

  void _foreground(Canvas c, Size size) {
    final w = size.width, h = size.height;
    const dark = Color(0xFF080709);
    // Sol-alt ve sağ-alt köşede flu ot/saz kümeleri — "içinden bakma" derinliği.
    void clump(double bx, double dir, double sc, int blades) {
      for (int i = 0; i < blades; i++) {
        final t = i / (blades - 1);
        final x = bx + dir * (t - 0.5) * w * 0.14;
        final tall = h * (0.30 + 0.22 * sin(i * 1.7 + bx));
        final p = Path()
          ..moveTo(x, h + 2)
          ..quadraticBezierTo(
              x + dir * sc * 6, h - tall * 0.5, x + dir * sc * 14, h - tall);
        c.drawPath(
            p,
            Paint()
              ..color = dark.withValues(alpha: 0.92)
              ..style = PaintingStyle.stroke
              ..strokeWidth = sc * 2.2
              ..strokeCap = StrokeCap.round);
      }
    }
    clump(w * 0.06, -1, 1.5, 6);
    clump(w * 0.95, 1, 1.6, 7);
  }

  void _particles(Canvas c, Size size, double horizon) {
    final w = size.width, h = size.height;
    final rng = Random(scene.index * 131 + tone.index * 17 + 7);
    final ember = tone == PetitionTone.warm || tone == PetitionTone.ominous;
    final col = ember ? const Color(0xFFFFC066) : const Color(0xFFCBD6E2);
    final n = ember ? 22 : 14;
    for (int i = 0; i < n; i++) {
      final x = rng.nextDouble() * w;
      final y = horizon - rng.nextDouble() * (h * 0.55) + h * 0.12;
      final s = (ember ? 0.7 : 0.5) + rng.nextDouble() * (ember ? 1.5 : 1.1);
      c.drawCircle(
          Offset(x, y),
          s,
          Paint()
            ..blendMode = BlendMode.plus
            ..color = col.withValues(alpha: 0.15 + rng.nextDouble() * 0.35));
    }
  }

  // ── Motif çizimleri ────────────────────────────────────────────────────────

  void _fire(Canvas c, Offset base, double s) {
    final wood = Paint()..color = const Color(0xFF3A240F);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base, width: s * 0.95, height: s * 0.16),
            const Radius.circular(2)),
        wood);
    // Sıcak yer hâlesi.
    final glowC = base.translate(0, -s * 0.3);
    c.drawCircle(
        glowC,
        s * 1.6,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFB24D).withValues(alpha: 0.55),
            const Color(0x00000000),
          ]).createShader(Rect.fromCircle(center: glowC, radius: s * 1.6)));
    // Alev — dış (turuncu) + iç (sarı).
    Path flame(double k) => Path()
      ..moveTo(base.dx, base.dy - s * 1.15 * k)
      ..quadraticBezierTo(
          base.dx + s * 0.42 * k, base.dy - s * 0.4 * k, base.dx, base.dy - s * 0.1)
      ..quadraticBezierTo(
          base.dx - s * 0.42 * k, base.dy - s * 0.4 * k, base.dx, base.dy - s * 1.15 * k)
      ..close();
    c.drawPath(flame(1.0), Paint()..color = const Color(0xFFFF8A2E));
    c.drawPath(flame(0.6), Paint()..color = const Color(0xFFFFD66A));
  }

  void _animal(Canvas c, Offset base, double s) {
    final body = Paint()..color = const Color(0xFF14121A);
    c.drawOval(
        Rect.fromCenter(
            center: base.translate(0, -s * 0.5), width: s * 1.7, height: s),
        body);
    c.drawCircle(base.translate(s * 0.85, -s * 0.7), s * 0.42, body);
    final leg = Paint()
      ..color = const Color(0xFF14121A)
      ..strokeWidth = s * 0.18;
    c.drawLine(
        base.translate(-s * 0.45, -s * 0.1), base.translate(-s * 0.45, s * 0.32), leg);
    c.drawLine(
        base.translate(s * 0.45, -s * 0.1), base.translate(s * 0.45, s * 0.32), leg);
  }

  void _wheat(Canvas c, Offset base, double s) {
    final stalk = Paint()
      ..color = const Color(0xFF9C7426)
      ..strokeWidth = s * 0.10
      ..strokeCap = StrokeCap.round;
    c.drawLine(base, base.translate(0, -s), stalk);
    c.drawOval(
        Rect.fromCenter(
            center: base.translate(0, -s), width: s * 0.42, height: s * 0.58),
        Paint()..color = const Color(0xFFD9B14A));
  }

  void _stall(Canvas c, Offset base, double w, double hh) {
    final post = Paint()..color = const Color(0xFF2E2012);
    c.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - hh, w, hh), post);
    final roof = Path()
      ..moveTo(base.dx - w * 0.64, base.dy - hh)
      ..lineTo(base.dx + w * 0.64, base.dy - hh)
      ..lineTo(base.dx + w * 0.5, base.dy - hh * 1.5)
      ..lineTo(base.dx - w * 0.5, base.dy - hh * 1.5)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFB5482E));
    // Tente şeridi.
    c.drawRect(Rect.fromLTWH(base.dx - w * 0.18, base.dy - hh * 1.46, w * 0.14, hh * 0.46),
        Paint()..color = const Color(0xFFE9C552).withValues(alpha: 0.65));
  }

  void _shrine(Canvas c, Offset base, double w, double hh) {
    final wall = Paint()..color = const Color(0xFF1C2029);
    c.drawRect(
        Rect.fromLTWH(base.dx - w / 2, base.dy - hh * 0.7, w, hh * 0.7), wall);
    final roof = Path()
      ..moveTo(base.dx - w * 0.64, base.dy - hh * 0.7)
      ..lineTo(base.dx + w * 0.64, base.dy - hh * 0.7)
      ..lineTo(base.dx, base.dy - hh * 1.05)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF283040));
    final spire = Paint()
      ..color = const Color(0xFF283040)
      ..strokeWidth = w * 0.08;
    c.drawLine(
        base.translate(0, -hh * 1.05), base.translate(0, -hh * 1.4), spire);
    // Pencere ışığı (sıcak).
    c.drawCircle(base.translate(0, -hh * 0.34), w * 0.13,
        Paint()..color = const Color(0xFFFFD27A));
  }

  void _house(Canvas c, Offset base, double w, double hh) {
    final wall = Paint()..color = const Color(0xFF241B13);
    c.drawRect(
        Rect.fromLTWH(base.dx - w / 2, base.dy - hh * 0.66, w, hh * 0.66), wall);
    final roof = Path()
      ..moveTo(base.dx - w * 0.64, base.dy - hh * 0.66)
      ..lineTo(base.dx + w * 0.64, base.dy - hh * 0.66)
      ..lineTo(base.dx, base.dy - hh)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF53341E));
    // Pencere (sıcak ev ışığı).
    c.drawRect(
        Rect.fromCenter(
            center: base.translate(0, -hh * 0.28), width: w * 0.24, height: w * 0.24),
        Paint()..color = const Color(0xFFFFC766));
  }

  void _figure(Canvas c, Offset base, double s) {
    final col = Paint()..color = const Color(0xFF100E16);
    c.drawCircle(base.translate(0, -s * 1.05), s * 0.28, col); // baş
    final body = Path()
      ..moveTo(base.dx - s * 0.30, base.dy)
      ..lineTo(base.dx + s * 0.30, base.dy)
      ..lineTo(base.dx + s * 0.16, base.dy - s * 0.82)
      ..lineTo(base.dx - s * 0.16, base.dy - s * 0.82)
      ..close();
    c.drawPath(body, col);
  }

  @override
  bool shouldRepaint(covariant _SceneCardPainter old) =>
      old.scene != scene || old.tone != tone;
}
