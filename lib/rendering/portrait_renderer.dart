import 'package:flutter/material.dart';
import '../characters/life_stage.dart';
import '../characters/npc_visual.dart';
import '../characters/villager_type.dart';

/// Büyük portrelerde kullanılabilen hafif yüz ifadeleri. Varsayılan [neutral]
/// olduğu için bilgi paneli gibi mevcut PortraitPainter kullanıcıları aynı
/// görünmeye devam eder; Divan portresi ise karar anında bunları canlandırır.
enum PortraitExpression {
  neutral,
  curious,
  worried,
  happy,
  angry,
  surprised,
  yawn,
}

/// NPC kimliğinden büyük ölçekli surat portresi üretir — panel başlığı için.
/// CharacterRenderer'ın sprite çizimini KULLANMAZ; bu özelleşmiş kafa/omuz
/// kompozisyonu paneldeki kareye düzgün yerleşir.
///
/// NpcVisual'ın tüm field'larını yansıtır: ten, saç (stil), göz rengi, sakal
/// (stil), kıyafet (tip + clothingShift). LifeStage'e göre kafa ölçeği,
/// elder'da saç kırlanır, çocukta yanak daha pembe + sakal yok.
class PortraitPainter extends CustomPainter {
  final NpcVisual visual;
  final LifeStage stage;
  final VillagerType type;
  final bool hasProfession;
  final Offset lookOffset;
  final PortraitExpression expression;
  final bool blink;

  const PortraitPainter({
    required this.visual,
    required this.stage,
    required this.type,
    required this.hasProfession,
    this.lookOffset = Offset.zero,
    this.expression = PortraitExpression.neutral,
    this.blink = false,
  });

  static final _p = Paint()..isAntiAlias = false;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final isElder = stage == LifeStage.elder;
    final isChild = stage == LifeStage.child;
    final isFemale = !visual.isMale;
    final hair = isElder
        ? Color.lerp(visual.hair, const Color(0xFFDAD8D0), 0.72)!
        : visual.hair;
    final beard = visual.hasBeard && !isChild;
    final clothing = tintCloth(
      _baseClothFor(type, hasProfession),
      visual.clothingShift,
    );

    // Arkaplan — derin koyu, çerçeve hissi.
    _p.color = const Color(0xFF1A140C);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), _p);

    // Omuzlar + kıyafet (alt kısım, trapez).
    // Erkek omuz geniş, kadın omuz dar — silüet farkı.
    _p.color = clothing;
    final shoulderL = isFemale ? 0.20 : 0.10;
    final shoulderR = isFemale ? 0.80 : 0.90;
    final neckL = isFemale ? 0.25 : 0.18;
    final neckR = isFemale ? 0.75 : 0.82;
    final path = Path()
      ..moveTo(w * shoulderL, h)
      ..lineTo(w * neckL, h * 0.78)
      ..lineTo(w * neckR, h * 0.78)
      ..lineTo(w * shoulderR, h)
      ..close();
    canvas.drawPath(path, _p);
    // Kıyafet yaka detayı — biraz koyu V
    _p.color = darker(clothing, 0.25);
    final v = Path()
      ..moveTo(w * 0.42, h * 0.78)
      ..lineTo(w * 0.50, h * 0.88)
      ..lineTo(w * 0.58, h * 0.78)
      ..close();
    canvas.drawPath(v, _p);

    // Boyun
    _p.color = darker(visual.skin, 0.10);
    canvas.drawRect(Rect.fromLTWH(w * 0.42, h * 0.64, w * 0.16, h * 0.16), _p);

    // Kafa (oval/yumurta) — çocukta daha büyük relative
    final headScale = isChild ? 1.08 : 1.00;
    final headW = w * 0.58 * headScale;
    final headH = h * 0.62 * headScale;
    final headCx = w * 0.50;
    final headCy = h * 0.40;
    final headRect = Rect.fromCenter(
      center: Offset(headCx, headCy),
      width: headW,
      height: headH,
    );

    _p.color = visual.skin;
    canvas.drawOval(headRect, _p);
    // Yüz gölgesi — sağ yarıda hafif koyu band (light from upper-left)
    _p.color = darker(visual.skin, 0.10);
    canvas.drawOval(
      Rect.fromLTWH(
        headCx + headW * 0.10,
        headCy - headH * 0.10,
        headW * 0.42,
        headH * 0.55,
      ),
      _p,
    );

    // Saç — stile göre kafanın çevresine
    _drawHair(
      canvas,
      w,
      h,
      headCx,
      headCy,
      headW,
      headH,
      hair,
      visual.hairStyle,
      isElder,
    );

    // Kaş — ifadeye göre birkaç piksel oynar; kafa sabit kaldığı için hareket
    // dikkat dağıtmadan yüzün niyetini değiştirir.
    final browY = headCy - headH * 0.05;
    final browDx = headW * 0.16;
    _p.color = darker(hair, 0.15);
    _drawBrows(canvas, headCx, browY, browDx, isElder);

    // Göz — sclera + iris pixel-art
    final eyeY = headCy + headH * 0.05;
    final eyeDx = headW * 0.16;
    _drawEyes(canvas, headCx, eyeY, eyeDx);

    // Elder: göz altı koyu nokta (kırışıklık)
    if (isElder) {
      _p.color = darker(visual.skin, 0.25);
      canvas.drawRect(Rect.fromLTWH(headCx - eyeDx - 2, eyeY + 4, 4, 1), _p);
      canvas.drawRect(Rect.fromLTWH(headCx + eyeDx - 1, eyeY + 4, 4, 1), _p);
    }

    // Burun — küçük dikey çizgi (gölgeli skin)
    _p.color = darker(visual.skin, 0.18);
    canvas.drawRect(Rect.fromLTWH(headCx - 1, headCy + headH * 0.12, 2, 4), _p);

    // Yanak — çocukta belirgin pembe, yetişkin kadında hafif pembe vurgu.
    if (isChild) {
      _p.color = Color.alphaBlend(const Color(0x55E08070), visual.skin);
      canvas.drawOval(Rect.fromLTWH(headCx - eyeDx - 6, eyeY + 6, 7, 4), _p);
      canvas.drawOval(Rect.fromLTWH(headCx + eyeDx - 1, eyeY + 6, 7, 4), _p);
    } else if (isFemale && !isElder) {
      _p.color = Color.alphaBlend(const Color(0x28E08070), visual.skin);
      canvas.drawOval(Rect.fromLTWH(headCx - eyeDx - 5, eyeY + 5, 6, 3), _p);
      canvas.drawOval(Rect.fromLTWH(headCx + eyeDx - 1, eyeY + 5, 6, 3), _p);
    }

    // Sakal — yetişkin/yaşlı erkek
    if (beard) {
      _drawBeard(
        canvas,
        w,
        h,
        headCx,
        headCy,
        headW,
        headH,
        hair,
        visual.beardStyle,
      );
    }

    // Sakal ağız çevresini temizlediği için ifade en son çizilir.
    _drawMouth(canvas, headCx, headCy + headH * 0.25);

    // Frame ince ışık + gölge
    _p.color = const Color(0x33FFE6A0);
    canvas.drawRect(Rect.fromLTWH(0, 0, w, 1), _p);
    _p.color = const Color(0x33000000);
    canvas.drawRect(Rect.fromLTWH(0, h - 1, w, 1), _p);
  }

  void _drawBrows(Canvas canvas, double cx, double y, double dx, bool elder) {
    final stroke = elder ? 2.0 : 1.5;
    _p
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.square;

    void brow(double x1, double y1, double x2, double y2) {
      canvas.drawLine(Offset(x1, y1), Offset(x2, y2), _p);
    }

    switch (expression) {
      case PortraitExpression.curious:
        brow(cx - dx - 4, y - 2, cx - dx + 3, y - 3);
        brow(cx + dx - 3, y + 1, cx + dx + 4, y);
      case PortraitExpression.worried:
        brow(cx - dx - 4, y, cx - dx + 3, y - 2);
        brow(cx + dx - 3, y - 2, cx + dx + 4, y);
      case PortraitExpression.happy:
        brow(cx - dx - 4, y + 1, cx - dx + 3, y);
        brow(cx + dx - 3, y, cx + dx + 4, y + 1);
      case PortraitExpression.angry:
        brow(cx - dx - 4, y - 2, cx - dx + 3, y + 1);
        brow(cx + dx - 3, y + 1, cx + dx + 4, y - 2);
      case PortraitExpression.surprised:
        brow(cx - dx - 4, y - 4, cx - dx + 3, y - 4);
        brow(cx + dx - 3, y - 4, cx + dx + 4, y - 4);
      case PortraitExpression.yawn:
        brow(cx - dx - 4, y + 1, cx - dx + 3, y + 2);
        brow(cx + dx - 3, y + 2, cx + dx + 4, y + 1);
      case PortraitExpression.neutral:
        brow(cx - dx - 4, y, cx - dx + 3, y);
        brow(cx + dx - 3, y, cx + dx + 4, y);
    }
    _p
      ..style = PaintingStyle.fill
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.butt;
  }

  void _drawEyes(Canvas canvas, double cx, double y, double dx) {
    final eyesClosed =
        blink ||
        expression == PortraitExpression.happy ||
        expression == PortraitExpression.yawn;
    if (eyesClosed) {
      _p
        ..color = const Color(0xFF382016)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(cx - dx - 3, y + 2),
        Offset(cx - dx + 2, y + 2),
        _p,
      );
      canvas.drawLine(
        Offset(cx + dx - 2, y + 2),
        Offset(cx + dx + 3, y + 2),
        _p,
      );
      _p
        ..style = PaintingStyle.fill
        ..strokeWidth = 1;
      return;
    }

    final surprised = expression == PortraitExpression.surprised;
    final eyeH = surprised ? 5.0 : 3.0;
    final eyeTop = surprised ? y - 1 : y;
    final lookX = lookOffset.dx.clamp(-1.0, 1.0) * 1.25;
    final lookY = lookOffset.dy.clamp(-1.0, 1.0) * .65;

    _p.color = const Color(0xFFEEE3CC);
    canvas.drawRect(Rect.fromLTWH(cx - dx - 3, eyeTop, 5, eyeH), _p);
    canvas.drawRect(Rect.fromLTWH(cx + dx - 2, eyeTop, 5, eyeH), _p);

    _p.color = visual.eyes;
    canvas.drawRect(
      Rect.fromLTWH(cx - dx - 2 + lookX, y + .5 + lookY, 2, 2),
      _p,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + dx - 1 + lookX, y + .5 + lookY, 2, 2),
      _p,
    );

    _p.color = const Color(0xFF080604);
    canvas.drawRect(
      Rect.fromLTWH(cx - dx - 1.5 + lookX, y + 1 + lookY, 1, 1),
      _p,
    );
    canvas.drawRect(
      Rect.fromLTWH(cx + dx - .5 + lookX, y + 1 + lookY, 1, 1),
      _p,
    );
  }

  void _drawMouth(Canvas canvas, double cx, double y) {
    _p.color = const Color(0xFF6A2818);
    switch (expression) {
      case PortraitExpression.happy:
        final smile = Path()
          ..moveTo(cx - 5, y)
          ..lineTo(cx - 2, y + 2.5)
          ..lineTo(cx + 2, y + 2.5)
          ..lineTo(cx + 5, y);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawPath(smile, _p);
        _p
          ..style = PaintingStyle.fill
          ..strokeWidth = 1;
      case PortraitExpression.angry:
        final frown = Path()
          ..moveTo(cx - 5, y + 2)
          ..lineTo(cx - 2, y)
          ..lineTo(cx + 2, y)
          ..lineTo(cx + 5, y + 2);
        _p
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawPath(frown, _p);
        _p
          ..style = PaintingStyle.fill
          ..strokeWidth = 1;
      case PortraitExpression.surprised:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, y + 2), width: 5, height: 7),
          _p,
        );
      case PortraitExpression.yawn:
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, y + 3), width: 10, height: 10),
          _p,
        );
        _p.color = const Color(0xFFC76562);
        canvas.drawOval(
          Rect.fromCenter(center: Offset(cx, y + 6), width: 6, height: 3),
          _p,
        );
      case PortraitExpression.curious:
        canvas.drawRect(Rect.fromLTWH(cx - 3, y, 7, 1.5), _p);
      case PortraitExpression.worried:
        canvas.drawRect(Rect.fromLTWH(cx - 4, y + 1, 8, 1.5), _p);
      case PortraitExpression.neutral:
        canvas.drawRect(Rect.fromLTWH(cx - 4, y, 8, 1.5), _p);
    }
  }

  void _drawHair(
    Canvas canvas,
    double w,
    double h,
    double cx,
    double cy,
    double headW,
    double headH,
    Color hair,
    HairStyle style,
    bool elder,
  ) {
    _p.color = hair;
    switch (style) {
      case HairStyle.bald:
        // Saç yok — sadece üst kafa hafif koyu shadow (cilt başlığı)
        _p.color = darker(visual.skin, 0.08);
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.40,
            cy - headH * 0.40,
            headW * 0.80,
            headH * 0.30,
          ),
          _p,
        );
      case HairStyle.short:
        // Saç tepe + kenarlar
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.45,
            cy - headH * 0.55,
            headW * 0.90,
            headH * 0.55,
          ),
          _p,
        );
        // Alın çizgisi (hafif)
        _p.color = darker(hair, 0.15);
        canvas.drawRect(
          Rect.fromLTWH(cx - headW * 0.35, cy - headH * 0.22, headW * 0.70, 2),
          _p,
        );
      case HairStyle.medium:
        // Tepe + yan örtü kulağa kadar
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.50,
            cy - headH * 0.55,
            headW * 1.00,
            headH * 0.70,
          ),
          _p,
        );
        // Yanak yan kıvrımı — overlay
        _p.color = visual.skin;
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.42,
            cy - headH * 0.25,
            headW * 0.84,
            headH * 0.55,
          ),
          _p,
        );
        _p.color = hair;
      case HairStyle.long:
        // Tepe + omuza kadar inen örtü
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.55,
            cy - headH * 0.55,
            headW * 1.10,
            headH * 0.85,
          ),
          _p,
        );
        // İki yana inen tutamlar
        canvas.drawRect(
          Rect.fromLTWH(
            cx - headW * 0.55,
            cy - headH * 0.10,
            headW * 0.18,
            headH * 0.85,
          ),
          _p,
        );
        canvas.drawRect(
          Rect.fromLTWH(
            cx + headW * 0.37,
            cy - headH * 0.10,
            headW * 0.18,
            headH * 0.85,
          ),
          _p,
        );
        // Yüz açık kalsın
        _p.color = visual.skin;
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.42,
            cy - headH * 0.20,
            headW * 0.84,
            headH * 0.60,
          ),
          _p,
        );
        _p.color = hair;
      case HairStyle.messy:
        // Tepe + birkaç dağınık tutam (küçük dikdörtgenler)
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.48,
            cy - headH * 0.55,
            headW * 0.96,
            headH * 0.55,
          ),
          _p,
        );
        // Dağınık tutamlar
        canvas.drawRect(
          Rect.fromLTWH(cx - headW * 0.45, cy - headH * 0.55, 3, 6),
          _p,
        );
        canvas.drawRect(
          Rect.fromLTWH(cx + headW * 0.20, cy - headH * 0.62, 4, 7),
          _p,
        );
        canvas.drawRect(
          Rect.fromLTWH(cx - headW * 0.10, cy - headH * 0.65, 3, 6),
          _p,
        );
    }
    if (elder && style != HairStyle.bald) {
      // Yaşlıda saç biraz seyrek — alın açık tutmak için ekstra ten band
      _p.color = visual.skin;
      canvas.drawRect(
        Rect.fromLTWH(cx - headW * 0.20, cy - headH * 0.32, headW * 0.40, 3),
        _p,
      );
    }
  }

  void _drawBeard(
    Canvas canvas,
    double w,
    double h,
    double cx,
    double cy,
    double headW,
    double headH,
    Color hair,
    BeardStyle style,
  ) {
    _p.color = hair;
    switch (style) {
      case BeardStyle.none:
        break;
      case BeardStyle.stubble:
        _p.color = darker(hair, 0.10);
        canvas.drawRect(
          Rect.fromLTWH(
            cx - headW * 0.25,
            cy + headH * 0.20,
            headW * 0.50,
            headH * 0.15,
          ),
          _p,
        );
      case BeardStyle.full:
        // Çene + yanak boyunca tam sakal
        canvas.drawOval(
          Rect.fromLTWH(
            cx - headW * 0.38,
            cy + headH * 0.10,
            headW * 0.76,
            headH * 0.45,
          ),
          _p,
        );
        // Ağız bölgesi temiz
        _p.color = visual.skin;
        canvas.drawRect(Rect.fromLTWH(cx - 5, cy + headH * 0.22, 10, 3), _p);
      case BeardStyle.goatee:
        canvas.drawRect(
          Rect.fromLTWH(
            cx - headW * 0.12,
            cy + headH * 0.25,
            headW * 0.24,
            headH * 0.20,
          ),
          _p,
        );
    }
  }

  Color _baseClothFor(VillagerType t, bool prof) {
    if (!prof) return const Color(0xFFB89D6C); // peasant linen
    switch (t) {
      case VillagerType.farmer:
        return const Color(0xFFB89D6C);
      case VillagerType.merchant:
        return const Color(0xFF4A5030);
      case VillagerType.blacksmith:
        return const Color(0xFF5A3818);
      case VillagerType.guard:
        return const Color(0xFFB8A878);
      case VillagerType.priest:
        return const Color(0xFF3E4560);
      case VillagerType.miner:
        return const Color(0xFF4A4840);
      case VillagerType.fisher:
        return const Color(0xFF5A7888);
      case VillagerType.shepherd:
        return const Color(0xFFCFC3A8);
      case VillagerType.hunter:
        return const Color(0xFF2E4632);
      case VillagerType.miller:
        return const Color(0xFF8A8577);
      case VillagerType.innkeeper:
        return const Color(0xFF6A3A3A);
    }
  }

  @override
  bool shouldRepaint(PortraitPainter old) =>
      old.visual != visual ||
      old.stage != stage ||
      old.type != type ||
      old.hasProfession != hasProfession ||
      old.lookOffset != lookOffset ||
      old.expression != expression ||
      old.blink != blink;
}
