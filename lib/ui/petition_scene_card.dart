import 'dart:math';
import 'package:flutter/material.dart';
import '../systems/petition_system.dart';
import 'app_ui.dart';

/// Dilekçe konusunu anlatan küçük 2B illüstrasyon kartı — modalın üstünde
/// sinematik bir "kare" gibi durur (oyunu DURDURMAZ; sadece modal süslemesi).
/// Prosedürel: ton paletli gökyüzü + tepe silüeti + konuya özel motif.
/// Açılış sinematiğiyle aynı dil, ama statik ve modal-içi.

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
  final Petition petition;
  final double height;
  const PetitionSceneCard({super.key, required this.petition, this.height = 92});

  @override
  Widget build(BuildContext context) {
    final accent = switch (petition.tone) {
      PetitionTone.warm => AppUi.sage,
      PetitionTone.solemn => AppUi.textMid,
      PetitionTone.ominous => AppUi.rust,
      PetitionTone.neutral => AppUi.accent,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppUi.radiusSm),
      child: Container(
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: accent.withValues(alpha: 0.5), width: 1),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
        ),
        child: CustomPaint(
          painter: _SceneCardPainter(
            scene: petitionSceneFor(petition),
            tone: petition.tone,
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _SceneCardPainter extends CustomPainter {
  final PetitionScene scene;
  final PetitionTone tone;
  _SceneCardPainter({required this.scene, required this.tone});

  // Ton → gökyüzü paleti (üst→ufuk).
  List<Color> get _sky => switch (tone) {
        PetitionTone.warm =>
          const [Color(0xFF3A2A50), Color(0xFF8A5570), Color(0xFFE8915A)],
        PetitionTone.solemn =>
          const [Color(0xFF2A3340), Color(0xFF4E5C6A), Color(0xFF8190A0)],
        PetitionTone.ominous =>
          const [Color(0xFF201618), Color(0xFF4A2E2A), Color(0xFF7A463A)],
        PetitionTone.neutral =>
          const [Color(0xFF7FB0D0), Color(0xFFBFDDEE), Color(0xFFE6F2FA)],
      };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas.clipRect(Offset.zero & size);

    // Gökyüzü.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: _sky,
          ).createShader(Offset.zero & size));

    // Tepe silüeti.
    _hills(canvas, size, h * 0.62, _shade(0.30), 3, h * 0.10);
    _hills(canvas, size, h * 0.74, _shade(0.18), 5, h * 0.13);
    // Zemin.
    canvas.drawRect(Rect.fromLTWH(0, h * 0.80, w, h * 0.20),
        Paint()..color = _shade(0.12));

    // Konu motifi.
    switch (scene) {
      case PetitionScene.fire:
        _fire(canvas, Offset(w * 0.5, h * 0.82), h * 0.34);
      case PetitionScene.herd:
        _animal(canvas, Offset(w * 0.36, h * 0.82), h * 0.16);
        _animal(canvas, Offset(w * 0.56, h * 0.86), h * 0.13);
        _animal(canvas, Offset(w * 0.72, h * 0.81), h * 0.15);
      case PetitionScene.field:
        for (int i = 0; i < 5; i++) {
          _wheat(canvas, Offset(w * (0.22 + i * 0.14), h * 0.84), h * 0.22);
        }
      case PetitionScene.market:
        _stall(canvas, Offset(w * 0.5, h * 0.80), w * 0.34, h * 0.30);
      case PetitionScene.shrine:
        _shrine(canvas, Offset(w * 0.5, h * 0.80), w * 0.20, h * 0.42);
      case PetitionScene.home:
        _house(canvas, Offset(w * 0.5, h * 0.80), w * 0.26, h * 0.34);
      case PetitionScene.gathering:
        _fire(canvas, Offset(w * 0.5, h * 0.84), h * 0.22);
        _figure(canvas, Offset(w * 0.34, h * 0.84), h * 0.20);
        _figure(canvas, Offset(w * 0.66, h * 0.84), h * 0.20);
      case PetitionScene.generic:
        _house(canvas, Offset(w * 0.38, h * 0.80), w * 0.18, h * 0.26);
        _house(canvas, Offset(w * 0.62, h * 0.82), w * 0.16, h * 0.22);
    }

    // Üst/alt yumuşak vinyet — kart sınırını yumuşatır.
    canvas.drawRect(
        Offset.zero & size,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: const [Color(0x33000000), Color(0x00000000), Color(0x44000000)],
            stops: const [0.0, 0.4, 1.0],
          ).createShader(Offset.zero & size));
  }

  Color _shade(double t) => Color.lerp(_sky.last, const Color(0xFF101018), 1 - t)!;

  void _hills(Canvas c, Size size, double baseY, Color col, int bumps, double amp) {
    final path = Path()..moveTo(0, size.height);
    path.lineTo(0, baseY);
    const steps = 36;
    for (int i = 0; i <= steps; i++) {
      final x = size.width * i / steps;
      final y = baseY - amp * (0.5 + 0.5 * sin(i / steps * pi * bumps + baseY));
      path.lineTo(x, y);
    }
    path.lineTo(size.width, size.height);
    path.close();
    c.drawPath(path, Paint()..color = col);
  }

  void _fire(Canvas c, Offset base, double s) {
    // Odunlar.
    final wood = Paint()..color = const Color(0xFF4A2E16);
    c.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: base, width: s * 0.9, height: s * 0.16),
            const Radius.circular(2)),
        wood);
    // Sıcak hâle.
    c.drawCircle(
        base.translate(0, -s * 0.3),
        s * 1.3,
        Paint()
          ..shader = RadialGradient(colors: [
            const Color(0xFFFFB24D).withValues(alpha: 0.6),
            const Color(0x00000000),
          ]).createShader(
              Rect.fromCircle(center: base.translate(0, -s * 0.3), radius: s * 1.3)));
    // Alev.
    final flame = Path()
      ..moveTo(base.dx, base.dy - s * 1.1)
      ..quadraticBezierTo(base.dx + s * 0.4, base.dy - s * 0.4, base.dx, base.dy - s * 0.1)
      ..quadraticBezierTo(base.dx - s * 0.4, base.dy - s * 0.4, base.dx, base.dy - s * 1.1)
      ..close();
    c.drawPath(flame, Paint()..color = const Color(0xFFFF9A3C));
    c.drawPath(
        flame,
        Paint()
          ..color = const Color(0xFFFFD06A)
          ..style = PaintingStyle.fill
          ..maskFilter = null);
  }

  void _animal(Canvas c, Offset base, double s) {
    final body = Paint()..color = const Color(0xFF1A1822);
    c.drawOval(
        Rect.fromCenter(center: base.translate(0, -s * 0.5), width: s * 1.6, height: s),
        body);
    c.drawCircle(base.translate(s * 0.8, -s * 0.7), s * 0.4, body);
    // Bacaklar.
    final leg = Paint()
      ..color = const Color(0xFF1A1822)
      ..strokeWidth = s * 0.18;
    c.drawLine(base.translate(-s * 0.4, -s * 0.1), base.translate(-s * 0.4, s * 0.3), leg);
    c.drawLine(base.translate(s * 0.4, -s * 0.1), base.translate(s * 0.4, s * 0.3), leg);
  }

  void _wheat(Canvas c, Offset base, double s) {
    final stalk = Paint()
      ..color = const Color(0xFFB98A2E)
      ..strokeWidth = s * 0.10;
    c.drawLine(base, base.translate(0, -s), stalk);
    c.drawOval(
        Rect.fromCenter(center: base.translate(0, -s), width: s * 0.4, height: s * 0.55),
        Paint()..color = const Color(0xFFD9B14A));
  }

  void _stall(Canvas c, Offset base, double w, double hh) {
    final post = Paint()..color = const Color(0xFF3A2A18);
    c.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - hh, w, hh), post);
    // Tente (şeritli üçgen çatı).
    final roof = Path()
      ..moveTo(base.dx - w * 0.62, base.dy - hh)
      ..lineTo(base.dx + w * 0.62, base.dy - hh)
      ..lineTo(base.dx + w * 0.5, base.dy - hh * 1.5)
      ..lineTo(base.dx - w * 0.5, base.dy - hh * 1.5)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFFB5482E));
  }

  void _shrine(Canvas c, Offset base, double w, double hh) {
    final wall = Paint()..color = const Color(0xFF20242E);
    c.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - hh * 0.7, w, hh * 0.7), wall);
    // Çatı.
    final roof = Path()
      ..moveTo(base.dx - w * 0.62, base.dy - hh * 0.7)
      ..lineTo(base.dx + w * 0.62, base.dy - hh * 0.7)
      ..lineTo(base.dx, base.dy - hh * 1.05)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF2C3340));
    // Haç/kule.
    final spire = Paint()
      ..color = const Color(0xFF2C3340)
      ..strokeWidth = w * 0.08;
    c.drawLine(base.translate(0, -hh * 1.05), base.translate(0, -hh * 1.35), spire);
    // Pencere ışığı.
    c.drawCircle(base.translate(0, -hh * 0.35), w * 0.12,
        Paint()..color = const Color(0xFFFFD27A));
  }

  void _house(Canvas c, Offset base, double w, double hh) {
    final wall = Paint()..color = const Color(0xFF2A2018);
    c.drawRect(Rect.fromLTWH(base.dx - w / 2, base.dy - hh * 0.66, w, hh * 0.66), wall);
    final roof = Path()
      ..moveTo(base.dx - w * 0.62, base.dy - hh * 0.66)
      ..lineTo(base.dx + w * 0.62, base.dy - hh * 0.66)
      ..lineTo(base.dx, base.dy - hh)
      ..close();
    c.drawPath(roof, Paint()..color = const Color(0xFF5A3A22));
    // Pencere.
    c.drawRect(
        Rect.fromCenter(
            center: base.translate(0, -hh * 0.28), width: w * 0.22, height: w * 0.22),
        Paint()..color = const Color(0xFFFFC766));
  }

  void _figure(Canvas c, Offset base, double s) {
    final col = Paint()..color = const Color(0xFF15131C);
    c.drawCircle(base.translate(0, -s * 1.05), s * 0.28, col); // baş
    final body = Path()
      ..moveTo(base.dx - s * 0.28, base.dy)
      ..lineTo(base.dx + s * 0.28, base.dy)
      ..lineTo(base.dx + s * 0.16, base.dy - s * 0.8)
      ..lineTo(base.dx - s * 0.16, base.dy - s * 0.8)
      ..close();
    c.drawPath(body, col);
  }

  @override
  bool shouldRepaint(covariant _SceneCardPainter old) =>
      old.scene != scene || old.tone != tone;
}
