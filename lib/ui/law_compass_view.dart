import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../systems/law_compass.dart';
import '../systems/regime.dart';
import 'app_ui.dart';

/// POLİTİK PUSULA'nın görünen yüzü — Kanunname'nin başına konan pirinç kadran.
///
/// Kimlik bir menüden SEÇİLMEZ, mühürlerle kazanılır. Ama kazanılan şey
/// görünmezse oyuncu için yoktur: bu kadran defterin oyuncuya NE YAPTIĞINI
/// tek bakışta söyler — köy şu an nerede duruyor, hangi kutba kayıyor, ve
/// bir sonraki mühür ibreyi nereye itecek.
///
/// İki yüzey:
///   • [LawCompassCard] — Kanunname sekmesinin başındaki tam kart (kadran +
///     rejim adı + o rejimin OYUNCUYU nasıl bağladığı).
///   • [LawCompassNudge] — mühür ritüelinde tek satır önizleme: "bu ferman
///     seni şuraya iter", kimlik değişecekse eski → yeni.
///
/// Kadranın okunuşu: yatay eksen İKTİSAT (sol Ortakçı, sağ Mülkçü), dikey
/// eksen OTORİTE (yukarı Hür, aşağı Baskı — baskı aşağı BASTIRIR). Ortadaki
/// soluk halka ölü banttır: içindeyken köy henüz bir şey olmamıştır. Dıştaki
/// altın yay imanın ağırlığı.

/// Rejimin rengi — kadran kadranı, rozet ve ibre aynı dili konuşsun.
Color regimeColor(VillageRegime r) => switch (r) {
      VillageRegime.commune => AppUi.sage,
      VillageRegime.market => AppUi.gold,
      VillageRegime.ironTable => AppUi.info,
      VillageRegime.sealedHand => AppUi.rust,
      VillageRegime.moderate => AppUi.textLo,
    };

/// Kanunname'nin başındaki kimlik kartı: kadran + rejim + oyuncuya etkisi.
class LawCompassCard extends StatelessWidget {
  /// Mühürlü ferman id'leri — konum bundan hesaplanır.
  final Set<String> sealed;

  /// Defterdeki toplam ferman sayısı (sayaç için).
  final int totalLaws;

  /// Rejimin oyuncuya verdiği yetki + köyün huzursuzluğu. null = rejim sistemi
  /// bağlanmamış yüzey (harness/preview) — kart eski hâlini çizer.
  final RegimeRule? rule;
  final double unrest;

  /// Köy yemin etmiş mi (etmişse hangi rejime).
  final VillageRegime? sworn;

  /// Yemin edilebiliyorsa çağrılır — null ise düğme çizilmez.
  final VoidCallback? onSwearOath;

  const LawCompassCard({
    super.key,
    required this.sealed,
    required this.totalLaws,
    this.rule,
    this.unrest = 0,
    this.sworn,
    this.onSwearOath,
  });

  @override
  Widget build(BuildContext context) {
    final pos = LawCompass.positionOf(sealed);
    final id = LawCompass.identify(pos);
    final tint = regimeColor(id.regime);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _CompassDial(pos: pos, tint: tint, size: 132),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(children: [
                  Text('KÖYÜN YÖNÜ',
                      style: AppUi.label.copyWith(
                          fontSize: 8, color: tint, letterSpacing: 1.6)),
                  const Spacer(),
                  Text('${sealed.length}/$totalLaws',
                      style: AppUi.number
                          .copyWith(fontSize: 10.5, color: AppUi.textLo)),
                ]),
                const SizedBox(height: 5),
                Row(children: [
                  Text(id.icon, style: const TextStyle(fontSize: 15)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(id.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.title
                            .copyWith(fontSize: 16, color: AppUi.gold)),
                  ),
                ]),
                const SizedBox(height: 5),
                Text(id.tagline,
                    style: AppUi.body.copyWith(
                        fontSize: 11,
                        height: 1.4,
                        color: AppUi.textMid,
                        fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                Container(height: 1, color: AppUi.line),
                const SizedBox(height: 7),
                // SİSTEMİN KALBİ: rejim yalnız bir rozet değil, oyuncunun
                // elini bağlayan/açan şey. Kart bunu açıkça yazar.
                Text(id.agencyNote,
                    style: AppUi.body.copyWith(
                        fontSize: 10.5, height: 1.45, color: AppUi.textLo)),
                if (id.regime != VillageRegime.moderate) ...[
                  const SizedBox(height: 8),
                  Wrap(spacing: 5, runSpacing: 5, children: [
                    _tag(id.committed ? 'KÖKLEŞTİ' : 'EĞİLİM',
                        id.committed ? tint : AppUi.textLo),
                    if (id.religious) _tag('☾ DİNÎ', AppUi.accent),
                    if (sworn != null) _tag('⚑ YEMİNLİ', AppUi.gold),
                    if (rule != null && rule!.powerTitle.isNotEmpty)
                      _tag(rule!.powerTitle, tint),
                  ]),
                ],
                if (rule != null) ...[
                  const SizedBox(height: 9),
                  _unrestBar(tint),
                ],
                if (onSwearOath != null) ...[
                  const SizedBox(height: 9),
                  _oathButton(id, tint),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Köyün sabrı — rejimin kendi çürümesi. Merkez'de (birikim yokken) hiç
  /// çizilmez: ılımlı köyün ödemediği bir bedeli göstermek yanıltıcı olur.
  Widget _unrestBar(Color tint) {
    if (rule!.unrestPerDay <= 0 && unrest <= 0.02) {
      return Text('Ilımlı köy: rejimin bedeli yok.',
          style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo));
    }
    final hot = unrest >= Regime.kCrisis
        ? AppUi.rust
        : unrest >= Regime.kStir
            ? AppUi.accent
            : tint;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Text('KÖYÜN SABRI',
              style: AppUi.label.copyWith(
                  fontSize: 7.5, color: AppUi.textLo, letterSpacing: 1.4)),
          const Spacer(),
          Text(Regime.unrestLabel(unrest),
              style: AppUi.body.copyWith(fontSize: 9.5, color: hot)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: SizedBox(
            height: 5,
            child: Stack(children: [
              Container(color: AppUi.surface2),
              FractionallySizedBox(
                widthFactor: unrest.clamp(0.0, 1.0),
                child: Container(color: hot.withValues(alpha: 0.85)),
              ),
            ]),
          ),
        ),
      ],
    );
  }

  /// KÖYÜN YEMİNİ — opt-in radikal ilan. Sinsi kayma seni ele verir, yemin
  /// seni mühürler: rejim fermanları açılır, yetki keskinleşir, geri dönüş
  /// pahalılaşır. Kart bunu süslemeden söyler.
  Widget _oathButton(RegimeIdentity id, Color tint) {
    final (title, _) = Regime.oathText(id);
    return GestureDetector(
      onTap: onSwearOath,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 10),
        decoration: BoxDecoration(
          color: tint.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: tint.withValues(alpha: 0.45)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title.isEmpty ? 'KÖYÜN YEMİNİ' : title,
                style: AppUi.label
                    .copyWith(fontSize: 9.5, color: tint, letterSpacing: 1.3)),
            const SizedBox(height: 4),
            Text(
                'Köy kendini ilan eder: ${id.title} fermanları deftere açılır, '
                'yetkin keskinleşir — ama bu yoldan dönüş pahalı olur.',
                style: AppUi.body
                    .copyWith(fontSize: 10, height: 1.4, color: AppUi.textMid)),
          ],
        ),
      ),
    );
  }

  Widget _tag(String text, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: c.withValues(alpha: 0.35)),
        ),
        child: Text(text,
            style: AppUi.label
                .copyWith(fontSize: 7.5, color: c, letterSpacing: 1.0)),
      );
}

/// Mühür ritüelindeki önizleme: "bu ferman ibreyi şuraya iter". Yasa pusulayı
/// oynatmıyorsa hiç çizilmez (nötr fermanla oyuncuyu meşgul etme).
class LawCompassNudge extends StatelessWidget {
  final Set<String> sealed;
  final String lawId;

  const LawCompassNudge({
    super.key,
    required this.sealed,
    required this.lawId,
  });

  @override
  Widget build(BuildContext context) {
    final nudge = LawCompass.nudgeOf(lawId);
    if (nudge == null) return const SizedBox.shrink();

    final now = LawCompass.positionOf(sealed);
    final next = LawCompass.preview(sealed, lawId);
    final shift = LawCompass.regimeShift(sealed, lawId);
    final tint = regimeColor(LawCompass.identify(next).regime);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 9, 12, 9),
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(
            color: shift != null
                ? tint.withValues(alpha: 0.45)
                : AppUi.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CompassDial(pos: now, preview: next, tint: tint, size: 68),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('PUSULA',
                    style: AppUi.label.copyWith(
                        fontSize: 7.5, color: AppUi.textLo, letterSpacing: 1.6)),
                const SizedBox(height: 4),
                Text(nudge,
                    style: AppUi.body.copyWith(
                        fontSize: 11.5, height: 1.35, color: AppUi.textMid)),
                if (shift != null) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Flexible(
                      child: Text(shift.$1,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.body.copyWith(
                              fontSize: 11, color: AppUi.textLo)),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      child: Icon(Icons.arrow_forward, size: 12, color: tint),
                    ),
                    Flexible(
                      child: Text(shift.$2,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.title.copyWith(fontSize: 12.5, color: tint)),
                    ),
                  ]),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Kadran ───────────────────────────────────────────────────────────────────

class _CompassDial extends StatelessWidget {
  final CompassPosition pos;
  final CompassPosition? preview;
  final Color tint;
  final double size;

  const _CompassDial({
    required this.pos,
    required this.tint,
    required this.size,
    this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      // İbre yumuşak kayar — mühür basıldığında zıplamaz, "kayar" (sinsi kayma
      // hissi görsel olarak da böyle okunur).
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.0, end: 1.0),
        duration: const Duration(milliseconds: 520),
        curve: Curves.easeOutCubic,
        builder: (_, t, _) => CustomPaint(
          painter: _DialPainter(
            pos: pos,
            preview: preview,
            tint: tint,
            reveal: t,
            labels: size >= 100,
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  final CompassPosition pos;
  final CompassPosition? preview;
  final Color tint;
  final double reveal;
  final bool labels;

  _DialPainter({
    required this.pos,
    required this.preview,
    required this.tint,
    required this.reveal,
    required this.labels,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final rim = size.width / 2 - 5;
    // Konum yarıçapı rim'den içeride: kalan halka eksen ADLARININ yatağı
    // (etiketler dışarı taşarsa kart genişliğini yer — hep içeride dururlar).
    // Pay cömert olmalı: uçtaki ibre (|konum| = 1) adın üstüne binmesin.
    final r = rim - (labels ? 19 : 5);

    _plate(canvas, c, rim);
    _quadrants(canvas, c, r);
    _grid(canvas, c, r);
    _faithArc(canvas, c, rim);
    if (labels) _labels(canvas, c, rim, size);

    final p = Offset(c.dx + pos.economy * r, c.dy + pos.authority * r);
    final target = preview;
    if (target != null) {
      final q = Offset(c.dx + target.economy * r, c.dy + target.authority * r);
      _dashed(canvas, p, Offset.lerp(p, q, reveal)!,
          tint.withValues(alpha: 0.7));
      _ghost(canvas, q, tint);
    }
    _needle(canvas, c, p);
  }

  /// Kadran gövdesi — oyulmuş koyu çukur + pirinç halka.
  void _plate(Canvas canvas, Offset c, double rim) {
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..shader = RadialGradient(
          colors: const [Color(0xFF15171B), Color(0xFF0C0D10)],
        ).createShader(Rect.fromCircle(center: c, radius: rim)),
    );
    canvas.drawCircle(
      c,
      rim,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = AppUi.gold.withValues(alpha: 0.26),
    );
    canvas.drawCircle(
      c,
      rim - 3.5,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = AppUi.gold.withValues(alpha: 0.10),
    );
  }

  /// Dört rejim bölgesi — çok soluk renk yatakları (nereye gidersen ne olursun).
  void _quadrants(Canvas canvas, Offset c, double r) {
    // Flutter açısı: 0 = sağ, pozitif saat yönü (y aşağı).
    const q = math.pi / 2;
    final beds = <(double, Color)>[
      (0, AppUi.rust), //      sağ-aşağı : Baskı + Mülkçü  (Mühürlü El)
      (q, AppUi.info), //      sol-aşağı : Baskı + Ortakçı (Demir Sofra)
      (2 * q, AppUi.sage), //  sol-yukarı: Hür + Ortakçı   (Ortak Ocak)
      (3 * q, AppUi.gold), //  sağ-yukarı: Hür + Mülkçü    (Açık Pazar)
    ];
    final rect = Rect.fromCircle(center: c, radius: r + 3);
    for (final (start, color) in beds) {
      canvas.drawArc(rect, start, q, true,
          Paint()..color = color.withValues(alpha: 0.055));
    }
  }

  /// Artı eksen + ölü bant halkası + yarım-yol tikleri.
  void _grid(Canvas canvas, Offset c, double r) {
    final axis = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.10);
    canvas.drawLine(Offset(c.dx - r, c.dy), Offset(c.dx + r, c.dy), axis);
    canvas.drawLine(Offset(c.dx, c.dy - r), Offset(c.dx, c.dy + r), axis);

    // Ölü bant: içindeyken köy henüz teşekkül etmemiştir.
    canvas.drawCircle(
      c,
      LawCompass.kBand * r,
      Paint()..color = Colors.white.withValues(alpha: 0.035),
    );
    canvas.drawCircle(
      c,
      LawCompass.kBand * r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8
        ..color = Colors.white.withValues(alpha: 0.14),
    );

    final tick = Paint()
      ..strokeWidth = 1
      ..color = Colors.white.withValues(alpha: 0.13);
    for (final s in const [-0.5, 0.5]) {
      canvas.drawLine(Offset(c.dx + s * r, c.dy - 2.5),
          Offset(c.dx + s * r, c.dy + 2.5), tick);
      canvas.drawLine(Offset(c.dx - 2.5, c.dy + s * r),
          Offset(c.dx + 2.5, c.dy + s * r), tick);
    }
  }

  /// İman — dış halkada tepeden saat yönüne büyüyen altın yay (overlay, eksen
  /// değil; o yüzden kadranın İÇİNDE değil KENARINDA durur).
  void _faithArc(Canvas canvas, Offset c, double rim) {
    if (pos.faith <= 0.01) return;
    // Yay ASLA tam halka olmaz (0.86 tur ile kesilir): kapanan bir halka
    // kadranın kendi pirinç çemberi gibi okunup ölçü olmaktan çıkıyor —
    // açık uç "bu bir gösterge" der. Alpha da kısık: iman bir boya, ana
    // okuma (ibre) onun altında kalmamalı.
    final f = pos.faith.clamp(0.0, 1.0);
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: rim + 3),
      -math.pi / 2,
      f * 0.86 * 2 * math.pi * reveal,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.8
        ..color = AppUi.accent.withValues(alpha: 0.20 + 0.28 * f),
    );
  }

  /// Eksen adları — kadranın İÇİNDE, halkaya yaslı. anchorX: -1 sola yaslı,
  /// 0 ortalı, +1 sağa yaslı (yatay adlar kenardan taşmasın diye).
  void _labels(Canvas canvas, Offset c, double rim, Size size) {
    void put(String text, Offset at, {double anchorX = 0}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: AppUi.label.copyWith(
              fontSize: 7,
              color: AppUi.textLo.withValues(alpha: 0.75),
              letterSpacing: 1.0,
              height: 1),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        at.translate(-tp.width * (anchorX + 1) / 2, -tp.height / 2),
      );
    }

    put('HÜR', Offset(c.dx, c.dy - rim + 8));
    put('BASKI', Offset(c.dx, c.dy + rim - 8));
    // Yatay adlar eksen çizgisinin biraz üstünde durur — ibre çizgisiyle
    // üst üste binmesin.
    put('ORTAKÇI', Offset(c.dx - rim + 5, c.dy - 8), anchorX: -1);
    put('MÜLKÇÜ', Offset(c.dx + rim - 5, c.dy - 8), anchorX: 1);
  }

  /// İbre — merkezden konuma uzanan kıvılcım + parlayan uç.
  void _needle(Canvas canvas, Offset c, Offset p) {
    final tip = Offset.lerp(c, p, reveal)!;
    canvas.drawLine(
      c,
      tip,
      Paint()
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..color = tint.withValues(alpha: 0.45),
    );
    canvas.drawCircle(
      tip,
      7,
      Paint()
        ..color = tint.withValues(alpha: 0.22)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
    );
    canvas.drawCircle(tip, 4.2, Paint()..color = tint);
    canvas.drawCircle(
        tip, 1.7, Paint()..color = Colors.white.withValues(alpha: 0.8));
    canvas.drawCircle(c, 1.6, Paint()..color = AppUi.gold.withValues(alpha: 0.5));
  }

  /// Önizleme ucu — içi boş halka ("henüz olmadı").
  void _ghost(Canvas canvas, Offset q, Color color) {
    canvas.drawCircle(
      q,
      4.2,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = color.withValues(alpha: 0.85),
    );
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Color color) {
    final d = b - a;
    final len = d.distance;
    if (len < 0.5) return;
    final step = d / len;
    final paint = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    for (double t = 0; t < len; t += 5) {
      final s = a + step * t;
      final e = a + step * math.min(t + 2.6, len);
      canvas.drawLine(s, e, paint);
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) =>
      old.reveal != reveal ||
      old.pos.authority != pos.authority ||
      old.pos.economy != pos.economy ||
      old.pos.faith != pos.faith ||
      old.preview?.authority != preview?.authority ||
      old.preview?.economy != preview?.economy ||
      old.tint != tint;
}
