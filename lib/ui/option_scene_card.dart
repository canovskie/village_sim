import 'dart:math';
import 'package:flutter/material.dart';
import '../systems/petition_system.dart';

/// Bir KARARIN eylemini canlandıran küçük 2B sahne — dilekçe/yargı modalındaki
/// yatay seçenek kartlarının tepesinde durur. Dilekçe hero'suyla (petition_
/// scene_card) aynı prosedürel dil: atmosferik gök + ufuk parıltısı + tepe
/// silüetleri + vinyet; farkı, motifin KONUYU değil EYLEMİ göstermesi
/// (bağışla → açık el + uçan kuş, idam → darağacı, kürek → zincirli mahkûm).
///
/// Ton eylemin ağırlığından türer: merhamet sıcak, teşhir ağırbaşlı, sürgün/
/// idam kara. Böylece oyuncu kartı okumadan önce kararın havasını görür.

enum OptionScene {
  pardon, // bağışla — merhamet
  punish, // meydanda cezalandır — teşhir
  exile, // köyden sür
  execute, // idam
  labor, // kürek cezası (NİZAM)
  accept, // genel olumlu karar (kabul/ver/kur)
  refuse, // genel ret/geçiştir
  generic, // eşlenemeyen karar
}

/// Bir seçeneği eylemine göre bir sahneye eşler. Suç hükümleri fx'ten kesin
/// çözülür; genel seçenekler etkinin YÖNÜNDEN (moral/kaynak/zümre) sezilir.
OptionScene optionSceneFor(PetitionOption o) {
  switch (o.fx) {
    case PetitionFx.crimePardon:
    case PetitionFx.feudPeace:
      return OptionScene.pardon;
    case PetitionFx.crimePunish:
      return OptionScene.punish;
    case PetitionFx.crimeExile:
    case PetitionFx.feudExile:
      return OptionScene.exile;
    case PetitionFx.crimeExecute:
    case PetitionFx.feudExecute:
      return OptionScene.execute;
    case PetitionFx.crimeLabor:
      return OptionScene.labor;
    default:
      break;
  }
  // Genel seçenek: etkinin yönünden bir hava seç. Somut kaynak veren/moral
  // yükselten karar "kabul"; moral düşüren/reddeden "ret"; ikisi de yoksa nötr.
  final givesResource = o.goldDelta < 0 ||
      o.foodDelta < 0 ||
      o.woodDelta < 0 ||
      o.stoneDelta < 0;
  if (o.moraleAmount > 0 || givesResource) return OptionScene.accept;
  if (o.moraleAmount < 0) return OptionScene.refuse;
  return OptionScene.generic;
}

/// Sahnenin duygu tonu — kartın gök paletini ve parıltısını belirler.
PetitionTone _toneOf(OptionScene s) => switch (s) {
      OptionScene.pardon => PetitionTone.warm,
      OptionScene.accept => PetitionTone.warm,
      OptionScene.punish => PetitionTone.solemn,
      OptionScene.exile => PetitionTone.solemn,
      OptionScene.refuse => PetitionTone.solemn,
      OptionScene.execute => PetitionTone.ominous,
      OptionScene.labor => PetitionTone.ominous,
      OptionScene.generic => PetitionTone.neutral,
    };

class OptionSceneCard extends StatelessWidget {
  final OptionScene scene;
  final double height;
  const OptionSceneCard({super.key, required this.scene, this.height = 84});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _OptionScenePainter(scene: scene, tone: _toneOf(scene)),
        size: Size.infinite,
      ),
    );
  }
}

class _OptionScenePainter extends CustomPainter {
  final OptionScene scene;
  final PetitionTone tone;
  _OptionScenePainter({required this.scene, required this.tone});

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
            Color(0xFF35506A),
            Color(0xFF4E7290),
            Color(0xFF89AEC6),
            Color(0xFFC5DCEA),
          ],
      };

  Color get _glow => switch (tone) {
        PetitionTone.warm => const Color(0xFFFFB870),
        PetitionTone.solemn => const Color(0xFFB9C6D6),
        PetitionTone.ominous => const Color(0xFFE0633A),
        PetitionTone.neutral => const Color(0xFFFFF4D6),
      };

  Color _haze(double t) =>
      Color.lerp(const Color(0xFF0F0E14), _sky[2], t * 0.55)!;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.clipRect(Offset.zero & size);
    final horizon = h * 0.68;

    // Gökyüzü.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _sky,
            stops: const [0.0, 0.34, 0.74, 1.0],
          ).createShader(Offset.zero & size));

    // Gök cismi + ufuk parıltısı.
    final celestial = Offset(w * 0.72, horizon - h * 0.10);
    canvas.drawCircle(
        celestial,
        h * 0.44,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(colors: [
            _glow.withValues(alpha: 0.38),
            _glow.withValues(alpha: 0.0),
          ]).createShader(Rect.fromCircle(center: celestial, radius: h * 0.44)));
    canvas.drawCircle(
        celestial,
        h * 0.13,
        Paint()
          ..shader = RadialGradient(colors: [
            Color.lerp(_glow, Colors.white, 0.45)!,
            _glow.withValues(alpha: 0.85),
          ]).createShader(Rect.fromCircle(center: celestial, radius: h * 0.13)));

    // Tepe katmanları (hava perspektifi).
    _hills(canvas, size, horizon + h * 0.02, _haze(0.5), 4, h * 0.10);
    _hills(canvas, size, horizon + h * 0.12, _haze(0.26), 6, h * 0.09);
    canvas.drawRect(Rect.fromLTWH(0, h * 0.84, w, h * 0.16),
        Paint()..color = _haze(0.14));

    // ── Eylem motifi ─────────────────────────────────────────────────────────
    final gy = h * 0.88;
    switch (scene) {
      case OptionScene.pardon:
        // Merhamet: serbest figür (kollar hafif açık) + yukarı uçan kuş.
        _figure(canvas, Offset(w * 0.42, gy), h * 0.34, arms: _Arms.open);
        _bird(canvas, Offset(w * 0.66, gy - h * 0.40), h * 0.12);
        _bird(canvas, Offset(w * 0.78, gy - h * 0.52), h * 0.09);
      case OptionScene.punish:
        // Teşhir: direğe bağlı diz çökmüş figür + ayakta bir bekçi.
        _post(canvas, Offset(w * 0.44, gy), h * 0.52);
        _figure(canvas, Offset(w * 0.44, gy), h * 0.24, kneel: true);
        _figure(canvas, Offset(w * 0.68, gy), h * 0.32);
      case OptionScene.exile:
        // Sürgün: geride köy silüeti, sırtı dönük giden figür, uzun gölge.
        _house(canvas, Offset(w * 0.24, gy), w * 0.16, h * 0.30);
        _gate(canvas, Offset(w * 0.44, gy), h * 0.34);
        _figure(canvas, Offset(w * 0.72, gy), h * 0.34, walkAway: true);
      case OptionScene.execute:
        // İdam: darağacı + diz çökmüş mahkûm + toplanmış tanıklar.
        _gallows(canvas, Offset(w * 0.40, gy), h * 0.62);
        _figure(canvas, Offset(w * 0.40, gy), h * 0.22, kneel: true);
        _figure(canvas, Offset(w * 0.66, gy), h * 0.24);
        _figure(canvas, Offset(w * 0.80, gy + h * 0.01), h * 0.20);
      case OptionScene.labor:
        // Kürek: eğilmiş zincirli mahkûm + kırılacak taş bloğu.
        _figure(canvas, Offset(w * 0.40, gy), h * 0.30, bent: true);
        _chain(canvas, Offset(w * 0.46, gy - h * 0.16), Offset(w * 0.56, gy));
        _rock(canvas, Offset(w * 0.62, gy), h * 0.20);
        _rock(canvas, Offset(w * 0.76, gy + h * 0.01), h * 0.14);
      case OptionScene.accept:
        // Kabul: ateş etrafında iki figür (sıcak, bereketli karar).
        _fire(canvas, Offset(w * 0.5, gy), h * 0.30);
        _figure(canvas, Offset(w * 0.30, gy), h * 0.30);
        _figure(canvas, Offset(w * 0.70, gy), h * 0.30);
      case OptionScene.refuse:
        // Ret: sönük ocak + sırtı dönük tek figür (soğuk karar).
        _emberPile(canvas, Offset(w * 0.56, gy), h * 0.16);
        _figure(canvas, Offset(w * 0.34, gy), h * 0.32, walkAway: true);
      case OptionScene.generic:
        _house(canvas, Offset(w * 0.40, gy), w * 0.18, h * 0.28);
        _house(canvas, Offset(w * 0.64, gy + h * 0.02), w * 0.14, h * 0.20);
    }

    // Ön-plan silüet çerçevesi (derinlik) + vinyet.
    _foreground(canvas, size);
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = RadialGradient(
            center: const Alignment(0.0, -0.1),
            radius: 1.25,
            colors: const [Color(0x00000000), Color(0x73000000)],
            stops: const [0.55, 1.0],
          ).createShader(Offset.zero & size));
  }

  // ── Atmosfer primitifleri ──────────────────────────────────────────────────

  void _hills(
      Canvas c, Size size, double baseY, Color col, int bumps, double amp) {
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(0, baseY);
    const steps = 40;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final t = i / steps;
      final y = baseY -
          amp * (0.5 + 0.5 * sin(t * pi * bumps + baseY)) -
          amp * 0.3 * sin(t * pi * (bumps * 2.2) + baseY * 0.7);
      path.lineTo(x, y);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    c.drawPath(path, Paint()..color = col);
  }

  void _foreground(Canvas c, Size size) {
    final w = size.width, h = size.height;
    const dark = Color(0xFF080709);
    void clump(double bx, double dir, double sc, int blades) {
      for (int i = 0; i < blades; i++) {
        final t = i / (blades - 1);
        final x = bx + dir * (t - 0.5) * w * 0.14;
        final tall = h * (0.26 + 0.20 * sin(i * 1.7 + bx));
        final p = Path()
          ..moveTo(x, h + 2)
          ..quadraticBezierTo(
              x + dir * sc * 5, h - tall * 0.5, x + dir * sc * 12, h - tall);
        c.drawPath(
            p,
            Paint()
              ..color = dark.withValues(alpha: 0.92)
              ..style = PaintingStyle.stroke
              ..strokeWidth = sc * 2.0
              ..strokeCap = StrokeCap.round);
      }
    }

    clump(w * 0.05, -1, 1.3, 5);
    clump(w * 0.96, 1, 1.4, 6);
  }

  // ── Figür + eyleme özel motifler ───────────────────────────────────────────

  static const _silhouette = Color(0xFF0D0B12);

  void _figure(Canvas c, Offset base, double s,
      {_Arms arms = _Arms.none,
      bool kneel = false,
      bool walkAway = false,
      bool bent = false}) {
    final col = Paint()..color = _silhouette;
    if (kneel) {
      // Diz çökmüş: alçak gövde + öne eğik baş.
      c.drawCircle(base.translate(0, -s * 0.62), s * 0.24, col);
      final body = Path()
        ..moveTo(base.dx - s * 0.26, base.dy)
        ..lineTo(base.dx + s * 0.26, base.dy)
        ..lineTo(base.dx + s * 0.14, base.dy - s * 0.5)
        ..lineTo(base.dx - s * 0.14, base.dy - s * 0.5)
        ..close();
      c.drawPath(body, col);
      return;
    }
    if (bent) {
      // Eğilmiş (kürekte): baş öne, sırt yatay.
      c.drawCircle(base.translate(s * 0.34, -s * 0.5), s * 0.22, col);
      final body = Path()
        ..moveTo(base.dx - s * 0.24, base.dy)
        ..lineTo(base.dx + s * 0.10, base.dy)
        ..lineTo(base.dx + s * 0.40, base.dy - s * 0.42)
        ..lineTo(base.dx + s * 0.10, base.dy - s * 0.5)
        ..lineTo(base.dx - s * 0.20, base.dy - s * 0.38)
        ..close();
      c.drawPath(body, col);
      return;
    }
    // Ayakta.
    c.drawCircle(base.translate(0, -s * 1.05), s * 0.26, col);
    final body = Path()
      ..moveTo(base.dx - s * 0.28, base.dy)
      ..lineTo(base.dx + s * 0.28, base.dy)
      ..lineTo(base.dx + s * 0.15, base.dy - s * 0.82)
      ..lineTo(base.dx - s * 0.15, base.dy - s * 0.82)
      ..close();
    c.drawPath(body, col);
    if (arms == _Arms.open) {
      final arm = Paint()
        ..color = _silhouette
        ..strokeWidth = s * 0.14
        ..strokeCap = StrokeCap.round;
      c.drawLine(base.translate(-s * 0.12, -s * 0.72),
          base.translate(-s * 0.5, -s * 0.95), arm);
      c.drawLine(base.translate(s * 0.12, -s * 0.72),
          base.translate(s * 0.5, -s * 0.95), arm);
    }
    if (walkAway) {
      // Uzayan gölge — gidişin ağırlığı.
      c.drawPath(
          Path()
            ..moveTo(base.dx - s * 0.2, base.dy)
            ..lineTo(base.dx + s * 1.4, base.dy + s * 0.06)
            ..lineTo(base.dx - s * 0.2, base.dy + s * 0.12)
            ..close(),
          Paint()..color = Colors.black.withValues(alpha: 0.28));
    }
  }

  void _bird(Canvas c, Offset o, double s) {
    final p = Paint()
      ..color = _silhouette.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.16
      ..strokeCap = StrokeCap.round;
    c.drawLine(o.translate(-s * 0.5, 0), o.translate(0, -s * 0.24), p);
    c.drawLine(o.translate(0, -s * 0.24), o.translate(s * 0.5, 0), p);
  }

  void _post(Canvas c, Offset base, double hh) {
    final wood = Paint()..color = const Color(0xFF241608);
    // Teşhir direği: tek dikey kazık + tepesinde kısa bir askı çıkıntısı
    // (haç DEĞİL — çapraz kol tepede ve tek yöne, boyunduruk hissi).
    c.drawRect(
        Rect.fromLTWH(base.dx - hh * 0.03, base.dy - hh, hh * 0.06, hh), wood);
    c.drawRect(
        Rect.fromLTWH(base.dx - hh * 0.02, base.dy - hh, hh * 0.20, hh * 0.05),
        wood);
    // Boyunduruk halkası (mahkûmun başı hizasında).
    c.drawCircle(
        base.translate(0, -hh * 0.5),
        hh * 0.07,
        Paint()
          ..color = const Color(0xFF241608)
          ..style = PaintingStyle.stroke
          ..strokeWidth = hh * 0.03);
  }

  void _gate(Canvas c, Offset base, double hh) {
    final wood = Paint()..color = const Color(0xFF1C1408);
    c.drawRect(
        Rect.fromLTWH(base.dx - hh * 0.22, base.dy - hh, hh * 0.06, hh), wood);
    c.drawRect(
        Rect.fromLTWH(base.dx + hh * 0.16, base.dy - hh, hh * 0.06, hh), wood);
    c.drawRect(
        Rect.fromLTWH(base.dx - hh * 0.22, base.dy - hh, hh * 0.44, hh * 0.08),
        wood);
  }

  void _gallows(Canvas c, Offset base, double hh) {
    final wood = Paint()..color = const Color(0xFF160F06);
    // Dikey direk + üst kiriş + ilmek ipi.
    c.drawRect(
        Rect.fromLTWH(base.dx - hh * 0.03, base.dy - hh, hh * 0.06, hh), wood);
    c.drawRect(
        Rect.fromLTWH(base.dx - hh * 0.03, base.dy - hh, hh * 0.42, hh * 0.06),
        wood);
    final rope = Paint()
      ..color = const Color(0xFF3A2A16)
      ..strokeWidth = hh * 0.03;
    c.drawLine(base.translate(hh * 0.34, -hh + hh * 0.06),
        base.translate(hh * 0.34, -hh * 0.62), rope);
    c.drawCircle(base.translate(hh * 0.34, -hh * 0.58), hh * 0.05,
        Paint()..color = const Color(0xFF3A2A16));
  }

  void _chain(Canvas c, Offset a, Offset b) {
    final p = Paint()
      ..color = const Color(0xFF5A6472)
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final n = 5;
    for (int i = 0; i < n; i++) {
      final t0 = i / n, t1 = (i + 0.6) / n;
      c.drawLine(Offset.lerp(a, b, t0)!, Offset.lerp(a, b, t1)!, p);
    }
  }

  void _rock(Canvas c, Offset base, double s) {
    final rock = Paint()..color = const Color(0xFF3B3540);
    final p = Path()
      ..moveTo(base.dx - s * 0.6, base.dy)
      ..lineTo(base.dx - s * 0.4, base.dy - s * 0.7)
      ..lineTo(base.dx + s * 0.15, base.dy - s * 0.9)
      ..lineTo(base.dx + s * 0.6, base.dy - s * 0.5)
      ..lineTo(base.dx + s * 0.5, base.dy)
      ..close();
    c.drawPath(p, rock);
    // Üst yüz vurgusu.
    c.drawPath(
        Path()
          ..moveTo(base.dx - s * 0.4, base.dy - s * 0.7)
          ..lineTo(base.dx + s * 0.15, base.dy - s * 0.9)
          ..lineTo(base.dx + s * 0.05, base.dy - s * 0.6)
          ..lineTo(base.dx - s * 0.28, base.dy - s * 0.52)
          ..close(),
        Paint()..color = const Color(0xFF4E4753));
  }

  void _house(Canvas c, Offset base, double w, double hh) {
    final wall = Paint()..color = const Color(0xFF1C150E);
    c.drawRect(
        Rect.fromLTWH(base.dx - w / 2, base.dy - hh * 0.66, w, hh * 0.66), wall);
    final roof = Path()
      ..moveTo(base.dx - w * 0.64, base.dy - hh * 0.66)
      ..lineTo(base.dx + w * 0.64, base.dy - hh * 0.66)
      ..lineTo(base.dx, base.dy - hh)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF3E2716));
    c.drawRect(
        Rect.fromCenter(
            center: base.translate(0, -hh * 0.28),
            width: w * 0.22,
            height: w * 0.22),
        Paint()..color = const Color(0xFFE0A354).withValues(alpha: 0.7));
  }

  void _fire(Canvas c, Offset base, double s) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base, width: s * 0.9, height: s * 0.16),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF3A240F));
    final glowC = base.translate(0, -s * 0.3);
    c.drawCircle(
        glowC,
        s * 1.5,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFB24D).withValues(alpha: 0.5),
            const Color(0x00000000),
          ]).createShader(Rect.fromCircle(center: glowC, radius: s * 1.5)));
    Path flame(double k) => Path()
      ..moveTo(base.dx, base.dy - s * 1.1 * k)
      ..quadraticBezierTo(base.dx + s * 0.4 * k, base.dy - s * 0.38 * k,
          base.dx, base.dy - s * 0.1)
      ..quadraticBezierTo(base.dx - s * 0.4 * k, base.dy - s * 0.38 * k,
          base.dx, base.dy - s * 1.1 * k)
      ..close();
    c.drawPath(flame(1.0), Paint()..color = const Color(0xFFFF8A2E));
    c.drawPath(flame(0.6), Paint()..color = const Color(0xFFFFD66A));
  }

  void _emberPile(Canvas c, Offset base, double s) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(
                center: base, width: s * 1.0, height: s * 0.2),
            const Radius.circular(2)),
        Paint()..color = const Color(0xFF2A1A0C));
    // Sönmekte olan birkaç kor.
    for (final dx in const [-0.2, 0.05, 0.25]) {
      c.drawCircle(base.translate(s * dx, -s * 0.06), s * 0.06,
          Paint()..color = const Color(0xFFB4501E).withValues(alpha: 0.8));
    }
  }

  @override
  bool shouldRepaint(covariant _OptionScenePainter old) =>
      old.scene != scene || old.tone != tone;
}

enum _Arms { none, open }
