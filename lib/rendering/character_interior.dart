part of 'character_renderer.dart';

/// Ev kıyafeti ve mobilya pozları; dış sahnenin meslek animasyonunu değiştirmez.
abstract final class InteriorCharacterRenderer {
  static void draw(
    Canvas c,
    NpcVisual visual, {
    required double time,
    double phase = 0,
    double moving = 0,
    double seated = 0,
    bool cooking = false,
    bool flipX = false,
  }) {
    CharacterRenderer.beginNpc();
    _accent = null;
    c.save();
    if (flipX) c.scale(-1, 1);
    c.scale(1 + (visual.build - 1) * 0.55, visual.build);
    final anim = _Anim.compute(phase, moving);
    if (seated <= 0 && !cooking) {
      _peasantNpc(c, anim, visual, time);
    } else {
      final cloth = _cloth(_linen, visual.clothingShift);
      final hose = _cloth(_woolBrown, visual.clothingShift * 0.6);
      if (seated > 0) {
        // Pelvis 36px iner, ayaklar taburenin 18px yüksekliğinde yerde kalır.
        for (final x in [-7.0, 4.0]) {
          _shadedRect(c, Rect.fromLTWH(x, -35 + 35 * seated, 8, 15), hose);
          _shadedRect(c, Rect.fromLTWH(x + 1, -20 + 32 * seated, 7, 13), hose);
          _shadedRect(c, Rect.fromLTWH(x, -7 + 29 * seated, 11, 5), _leatherDk);
        }
      } else {
        _shadedLeg(c, -6, anim.legL, hose, _leatherDk);
        _shadedLeg(c, 6, anim.legR, hose, _leatherDk);
      }
      c.save();
      c.translate(0, 36 * seated + sin(time * 1.4).abs() * -0.4);
      _shadedTunic(c, cloth);
      _shadedArm(c, -15, -0.12, cloth, visual.skin);
      final arm = cooking
          ? -0.60 + sin(time * 3.2) * 0.12
          : -0.25 - (sin(time * 1.8) * 0.5 + 0.5) * 0.5;
      _shadedArm(
        c,
        15,
        arm,
        cloth,
        visual.skin,
        cooking
            ? (hand) {
                hand.rotate(-0.4);
                _shadedRect(
                  hand,
                  const Rect.fromLTWH(-1, 20, 2.5, 19),
                  const Color(0xFF946A3E),
                );
                hand.drawOval(
                  const Rect.fromLTWH(-3, 35, 7, 5),
                  _f(const Color(0xFFBE965A)),
                );
              }
            : null,
      );
      _shadedHead(c, visual, time);
      c.restore();
    }
    c.restore();
  }

  static void sleepingHead(Canvas c, NpcVisual visual) {
    CharacterRenderer.beginNpc();
    _accent = null;
    // Blink'in kapalı karesini kullan: aynı saç/ten/sakal, şapkasız baş.
    _shadedHead(c, visual, (pi / 2 - visual.blinkPhase) / 0.78, y: 0);
  }
}
