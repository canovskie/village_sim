import 'package:flutter/material.dart';

import 'app_ui.dart';

/// Dünyada doğan küçük, oyuncuyu zorla durdurmayan hikâyenin işareti.
///
/// 44dp dokunma alanı korunur; görünen yüz bilerek küçüktür. İşaret bir
/// rehber oku değil, köylünün o an söyleyecek bir sözü olduğunu anlatır.
class VillagePulseMarker extends StatefulWidget {
  final String icon;
  final bool urgent;
  final VoidCallback onTap;

  const VillagePulseMarker({
    super.key,
    required this.icon,
    required this.urgent,
    required this.onTap,
  });

  @override
  State<VillagePulseMarker> createState() => _VillagePulseMarkerState();
}

class _VillagePulseMarkerState extends State<VillagePulseMarker>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1500),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tint = widget.urgent ? AppUi.rust : AppUi.accent;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      child: SizedBox.square(
        dimension: 44,
        child: Center(
          child: AnimatedBuilder(
            animation: _pulse,
            builder: (_, child) => Transform.translate(
              offset: Offset(0, -2.5 * _pulse.value),
              child: Container(
                width: 31,
                height: 31,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Color.alphaBlend(
                    tint.withValues(alpha: 0.18 + _pulse.value * 0.05),
                    AppUi.surface1,
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: tint.withValues(alpha: 0.72),
                    width: 1.3,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.12),
                      blurRadius: 8 + _pulse.value * 4,
                    ),
                  ],
                ),
                child: child,
              ),
            ),
            child: Text(widget.icon, style: const TextStyle(fontSize: 15)),
          ),
        ),
      ),
    );
  }
}

/// Köy Nabzı'nın tek cümle + iki karar kartı.
///
/// Modal değildir: arka planı kapatmaz, simülasyonu durdurmaz ve kart kapatılırsa
/// dünyadaki işarete geri döner. Süre dolunca köylü kendi kararını verir.
class VillagePulseCard extends StatelessWidget {
  final String icon;
  final String actor;
  final String title;
  final String body;
  final String primaryLabel;
  final String? primarySub;
  final bool primaryEnabled;
  final String secondaryLabel;
  final String? secondarySub;
  final double remainingFraction;
  final int secondsLeft;
  final VoidCallback onPrimary;
  final VoidCallback onSecondary;
  final VoidCallback onClose;

  const VillagePulseCard({
    super.key,
    required this.icon,
    required this.actor,
    required this.title,
    required this.body,
    required this.primaryLabel,
    this.primarySub,
    required this.primaryEnabled,
    required this.secondaryLabel,
    this.secondarySub,
    required this.remainingFraction,
    required this.secondsLeft,
    required this.onPrimary,
    required this.onSecondary,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: AppPanel(
        accent: AppUi.accent,
        padding: const EdgeInsets.fromLTRB(15, 12, 12, 13),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(icon, style: const TextStyle(fontSize: 19)),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'KÖY NABZI · ${actor.toUpperCase()}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppUi.label.copyWith(
                          color: AppUi.accentSoft,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(title, style: AppUi.title.copyWith(fontSize: 15)),
                    ],
                  ),
                ),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onClose,
                  child: SizedBox.square(
                    dimension: 44,
                    child: Center(
                      child: Text(
                        '×',
                        style: AppUi.title.copyWith(color: AppUi.textLo),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(body, style: AppUi.body.copyWith(color: AppUi.textMid)),
            const SizedBox(height: 11),
            LayoutBuilder(
              builder: (_, c) {
                final buttons = [
                  AppButton(
                    label: primaryLabel,
                    sub: primarySub,
                    kind: AppButtonKind.filled,
                    expand: true,
                    onTap: primaryEnabled ? onPrimary : null,
                  ),
                  AppButton(
                    label: secondaryLabel,
                    sub: secondarySub,
                    kind: AppButtonKind.tonal,
                    expand: true,
                    onTap: onSecondary,
                  ),
                ];
                if (c.maxWidth < 390) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buttons[0],
                      const SizedBox(height: 7),
                      buttons[1],
                    ],
                  );
                }
                return Row(
                  children: [
                    Expanded(child: buttons[0]),
                    const SizedBox(width: 8),
                    Expanded(child: buttons[1]),
                  ],
                );
              },
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                minHeight: 2,
                value: remainingFraction.clamp(0.0, 1.0),
                backgroundColor: AppUi.surface3,
                valueColor: AlwaysStoppedAnimation(
                  secondsLeft <= 6 ? AppUi.rust : AppUi.accent,
                ),
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Karar vermezsen $actor ${secondsLeft}s sonra kendi yolunu seçer.',
              style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
            ),
          ],
        ),
      ),
    );
  }
}
