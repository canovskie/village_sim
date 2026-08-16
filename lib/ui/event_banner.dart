import 'package:flutter/material.dart';
import '../systems/event_system.dart';
import 'app_ui.dart';
import 'semantic_icon.dart';

/// Bir rastgele olay tetiklendiğinde ekranın üst-ortasında çıkan zengin
/// banner kartı. Kategoriye göre renklenir (pozitif sage, negatif rust,
/// nötr ember), etki kutucukları + countdown bar ile birlikte.
class EventBanner extends StatelessWidget {
  final EventOutcome event;

  /// Banner'ın ekranda toplam kalış süresi içinde geriye kalan saniye.
  final double timeLeft;

  /// Toplam görünme süresi (countdown bar oranı için).
  final double duration;
  final VoidCallback onClose;

  /// Olayın dünyadaki NPC sahnesinin kısa adı ("Kova zinciri"). null ise sahne
  /// yok/bitti → "İzle" düğmesi hiç çizilmez. Oyuncuya olmayan bir şeyi
  /// vaat etmemek için nullable: sahne kadro bulamazsa düğme de olmaz.
  final String? watchLabel;

  /// "İzle" — kamerayı sahnenin odağına kaydırır.
  final VoidCallback? onWatch;

  const EventBanner({
    super.key,
    required this.event,
    required this.timeLeft,
    required this.duration,
    required this.onClose,
    this.watchLabel,
    this.onWatch,
  });

  Color get _accent => switch (event.category) {
        EventCategory.positive => AppUi.sage,
        EventCategory.negative => AppUi.rust,
        EventCategory.neutral => AppUi.accent,
      };

  String get _categoryLabel => switch (event.category) {
        EventCategory.positive => 'OLUMLU',
        EventCategory.negative => 'OLUMSUZ',
        EventCategory.neutral => 'OLAY',
      };

  @override
  Widget build(BuildContext context) {
    final progress =
        duration <= 0 ? 0.0 : (timeLeft / duration).clamp(0.0, 1.0);
    final deltas = event.deltaSummary();
    return AppReveal(
      child: AppPanel(
        width: 360,
        accent: _accent,
        padding: EdgeInsets.zero,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Üst şerit: ikon + başlık + kategori + close
            Container(
              padding: const EdgeInsets.fromLTRB(12, 11, 10, 11),
              decoration: BoxDecoration(
                border: const Border(
                  bottom:
                      BorderSide(color: AppUi.line, width: 1),
                ),
                gradient: LinearGradient(
                  colors: [
                    _accent.withValues(alpha: 0.14),
                    _accent.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Row(
                children: [
                  // Büyük ikon kutusu
                  Container(
                    width: 44,
                    height: 44,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: AppUi.surface0,
                      borderRadius: BorderRadius.circular(AppUi.radiusSm),
                      border: Border.all(color: _accent, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: _accent.withValues(alpha: 0.3),
                            blurRadius: 8),
                      ],
                    ),
                    child: SemanticIcon(
                      event.icon,
                      size: 24,
                      color: _accent,
                      fallback: GameIconData.dice,
                      label: event.title,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(event.title,
                            style: AppUi.bodyHi.copyWith(
                              fontSize: 14,
                              color: _accent,
                            )),
                        const SizedBox(height: 3),
                        Text(_categoryLabel,
                            style: AppUi.label
                                .copyWith(color: AppUi.textLo)),
                      ],
                    ),
                  ),
                  AppIconButton(
                    icon: GameIconData.close,
                    size: 30,
                    tint: _accent,
                    onTap: onClose,
                  ),
                ],
              ),
            ),
            // Mesaj gövdesi
            Padding(
              padding: const EdgeInsets.fromLTRB(13, 10, 13, 9),
              child: Text(event.message,
                  style: AppUi.body.copyWith(height: 1.4)),
            ),
            // İZLE — olayın dünyadaki NPC sahnesine kamerayı götürür. Banner'ın
            // en önemli düğmesi: olayı okunan bir metin olmaktan çıkarıp
            // izlenen bir ana bağlayan tek bağ.
            if (watchLabel != null && onWatch != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 1, 11, 9),
                child: AppButton(
                  label: 'İzle',
                  sub: watchLabel,
                  icon: GameIconData.eye,
                  kind: AppButtonKind.tonal,
                  tint: _accent,
                  expand: true,
                  height: 40,
                  onTap: onWatch,
                ),
              ),
            // Etki kutucukları
            if (deltas.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(11, 0, 11, 10),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children:
                      deltas.map((d) => _deltaChip(d.$1, d.$2)).toList(),
                ),
              ),
            // Countdown bar
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(AppUi.radius - 1)),
              child: Container(
                height: 3,
                color: AppUi.surface0,
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: progress,
                  child: Container(color: _accent),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _deltaChip(String icon, String label) {
    // Renk delta işaretine göre rust/sage; moral chip her zaman ember.
    final isMoral = icon == '😊';
    final isNeg = label.startsWith('-');
    final color = isMoral
        ? AppUi.accent
        : (isNeg ? AppUi.rust : AppUi.sage);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SemanticIcon(
            icon,
            size: 12,
            color: color,
            fallback: isMoral ? GameIconData.heart : GameIconData.star,
          ),
          const SizedBox(width: 5),
          Text(label,
              style: AppUi.button.copyWith(
                fontSize: 10,
                letterSpacing: 0.4,
                color: color,
              )),
        ],
      ),
    );
  }
}
