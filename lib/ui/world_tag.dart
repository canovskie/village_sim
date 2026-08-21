import 'package:flutter/widgets.dart';

import 'app_ui.dart';

/// Dünya-uzayı künye — imleci DEĞİL, hedefi takip eder.
///
/// Tasarım kuralı: kutu/çerçeve YOK. Sahnenin üstünde yüzen bir panel değil,
/// sahneye ait bir yazıt gibi durur; okunurluk gölgeden gelir (scrim/kart
/// arkaplanı göz yorar ve altındaki köyü saklar). İlk üç satır kimliktir:
///   1) ad (oyma kapital)
///   2) meslek · hane
///   3) ne yapıyor · ruh hâli
/// NPC hover'ında isteğe bağlı dördüncü satır etkileşim kısayolunu öğretir.
/// Altında uçlara doğru sönen ince ember çizgi künyeyi hedefe bağlar.
///
/// PERF: konumlandırma [FractionalTranslation] + [Transform.translate] ile
/// yapılır (ikisi de paint aşaması) — köylü yürürken her karede yeniden
/// LAYOUT olmaz, sadece kaydırılır. Metin değişmedikçe paragraf cache'i durur.
class WorldTag extends StatelessWidget {
  const WorldTag({
    super.key,
    required this.anchor,
    required this.title,
    required this.line2,
    required this.line3,
    required this.opacity,
    this.accent = AppUi.accent,
    this.hint = '',
  });

  /// Künyenin ALT-ORTA noktası (ekran uzayı) — hedefin başının biraz üstü.
  final Offset anchor;
  final String title;
  final String line2;
  final String line3;

  /// Yalnız etkileşimli hedeflerde gösterilen kısa kullanım ipucu.
  final String hint;

  /// 0→1 beliriş. Yükseliş kayması da bundan türer.
  final double opacity;

  /// Ayırıcı çizgi + ad vurgusu rengi (mezar/bina için değişebilir).
  final Color accent;

  // Kutu olmadığı için okunurluk tamamen gölgeden gelir: geniş yumuşak bir
  // karartma + sıkı bir kontur. Tek gölge yeterli değil (açık zemin/kar).
  static const _shadows = <Shadow>[
    Shadow(blurRadius: 8, color: Color(0xCC000000)),
    Shadow(blurRadius: 2.5, color: Color(0xE6000000)),
  ];

  @override
  Widget build(BuildContext context) {
    // Beliriş: sönerken hafifçe yukarı süzülür (aşağıdan gelmez — künye zaten
    // hedefin üstünde durur, aşağıdan çıkarsa sprite'ın içinden doğmuş olur).
    final rise = (1.0 - opacity) * 5.0;
    return Transform.translate(
      offset: Offset(anchor.dx, anchor.dy - rise),
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.0), // alt-orta hizala
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppUi.title.copyWith(
                  fontSize: 13,
                  letterSpacing: 1.6,
                  shadows: _shadows,
                ),
              ),
              if (line2.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    line2,
                    textAlign: TextAlign.center,
                    style: AppUi.body.copyWith(
                      fontSize: 11,
                      height: 1.15,
                      color: AppUi.textMid,
                      shadows: _shadows,
                    ),
                  ),
                ),
              if (line3.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    line3,
                    textAlign: TextAlign.center,
                    style: AppUi.body.copyWith(
                      fontSize: 10,
                      height: 1.15,
                      color: AppUi.textLo,
                      fontStyle: FontStyle.italic,
                      shadows: _shadows,
                    ),
                  ),
                ),
              if (hint.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: AppUi.label.copyWith(
                      fontSize: 9,
                      letterSpacing: 0.35,
                      color: AppUi.accentSoft,
                      shadows: _shadows,
                    ),
                  ),
                ),
              // Künyeyi hedefe bağlayan ince ember çizgi — uçlara doğru söner
              // ki kesik bir çubuk gibi durmasın.
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Container(
                  width: 54,
                  height: 1,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        accent.withValues(alpha: 0.0),
                        accent.withValues(alpha: 0.75),
                        accent.withValues(alpha: 0.0),
                      ],
                    ),
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

/// KÖYÜN SESİ — bir köylünün ağzından çıkan tek cümle, sahnenin üstünde.
///
/// [WorldTag] ile aynı dil: KUTU YOK. Çizgi roman baloncuğu sahneye
/// yapıştırılmış bir arayüz parçası gibi durur; burada okunurluk gölgeden
/// gelir, cümle sahneye ait bir yazıt gibi durur.
///
/// Baş üstü EMOJİ değil (bkz. feedback_event_animation): bu bir duygu ikonu
/// değil, birinin söylediği söz. Duygunun kendisi gövde dilinde kalır.
class WorldSpeech extends StatelessWidget {
  const WorldSpeech({
    super.key,
    required this.anchor,
    required this.name,
    required this.line,
    required this.opacity,
    this.maxWidth = 260,
  });

  /// Cümlenin ALT-ORTA noktası (ekran uzayı) — konuşanın başının üstü.
  final Offset anchor;
  final String name;
  final String line;
  final double opacity;
  final double maxWidth;

  static const _shadows = <Shadow>[
    Shadow(blurRadius: 9, color: Color(0xD9000000)),
    Shadow(blurRadius: 2.5, color: Color(0xF2000000)),
  ];

  @override
  Widget build(BuildContext context) {
    final rise = (1.0 - opacity) * 6.0;
    return Transform.translate(
      offset: Offset(anchor.dx, anchor.dy - rise),
      child: FractionalTranslation(
        translation: const Offset(-0.5, -1.0),
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  line,
                  textAlign: TextAlign.center,
                  style: AppUi.body.copyWith(
                    fontSize: 12.5,
                    height: 1.3,
                    color: AppUi.textHi,
                    shadows: _shadows,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '— $name',
                  textAlign: TextAlign.center,
                  style: AppUi.label.copyWith(
                    fontSize: 9.5,
                    letterSpacing: 0.6,
                    color: AppUi.accentSoft,
                    shadows: _shadows,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Hedefin ayağındaki soluk halka — künyenin kimi anlattığını kalabalıkta
/// tartışmaya bırakmaz. İzometrik zeminle uyum için basık elips.
class WorldTagRing extends StatelessWidget {
  const WorldTagRing({
    super.key,
    required this.feet,
    required this.radius,
    required this.opacity,
    this.color = AppUi.accent,
  });

  final Offset feet;
  final double radius;
  final double opacity;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: feet.dx - radius,
      top: feet.dy - radius * 0.5,
      width: radius * 2,
      height: radius,
      child: IgnorePointer(
        child: CustomPaint(
          painter: _RingPainter(color, opacity.clamp(0.0, 1.0)),
        ),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  const _RingPainter(this.color, this.opacity);

  final Color color;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0.01) return;
    final rect = Offset.zero & size;
    // Tek ince stroke — dolgu yok (dolgu zemin dokusunu boğar, "seçili" gibi
    // agresif okunur; bu yalnız bir işaret).
    canvas.drawOval(
      rect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = color.withValues(alpha: 0.30 * opacity),
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.opacity != opacity || old.color != color;
}
