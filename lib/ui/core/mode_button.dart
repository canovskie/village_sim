import 'package:flutter/material.dart';
import 'app_ui.dart';
import 'mobile_ui.dart';
import 'semantic_icon.dart';

/// HUD altındaki mod butonu (Tarla / Kes / Kaz). Koyu rafine sekme —
/// pasifken solgun ikon + etiket, aktifken accent renkli halo + kenar.
class ModeButton extends StatefulWidget {
  final String icon;
  final String label;
  final bool active;
  final Color accentColor;
  final VoidCallback onTap;

  const ModeButton({
    super.key,
    required this.icon,
    required this.label,
    required this.active,
    required this.accentColor,
    required this.onTap,
  });

  @override
  State<ModeButton> createState() => _ModeButtonState();
}

class _ModeButtonState extends State<ModeButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final compact = useCompactGameUi(context);
    final tint = widget.accentColor;
    final active = widget.active;
    final hot = _hover || active;

    final fg = active ? tint : (_hover ? AppUi.textHi : AppUi.textMid);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: () {
          widget.onTap();
          if (useCompactGameUi(context)) {
            const BuildCatalogCloseNotification().dispatch(context);
          }
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          constraints: compact
              ? const BoxConstraints(minWidth: 38, minHeight: 44)
              : null,
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 5 : 12,
            vertical: compact ? 3 : 6,
          ),
          decoration: BoxDecoration(
            color: active
                ? Color.alphaBlend(tint.withValues(alpha: 0.24), AppUi.surface2)
                : (hot ? AppUi.surface3 : AppUi.surface1),
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: active ? tint : AppUi.line,
              width: active ? 1.5 : 1,
            ),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: tint.withValues(alpha: 0.4),
                      blurRadius: 10,
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SemanticIcon(
                widget.icon,
                size: compact ? 16 : 18,
                color: fg,
                fallback: GameIconData.hammer,
              ),
              const SizedBox(height: 2),
              Text(
                widget.label.toUpperCase(),
                style: AppUi.label.copyWith(
                  fontSize: compact ? 8 : 9,
                  letterSpacing: compact ? 0.45 : 1.0,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
