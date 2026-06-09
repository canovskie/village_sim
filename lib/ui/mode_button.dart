import 'package:flutter/material.dart';
import 'cozy_theme.dart';

/// HUD altındaki mod butonu (Tarla / Kes / Kaz). Deri sekme stili —
/// pasifken solgun ikon + etiket, aktifken accent renk halosu.
class ModeButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: active
                ? [
                    Color.alphaBlend(accentColor.withValues(alpha: 0.45),
                        const Color(0xFF1A0E04)),
                    Color.alphaBlend(accentColor.withValues(alpha: 0.18),
                        const Color(0xFF120804)),
                  ]
                : const [Color(0xFF5A3416), CozyUi.leather],
          ),
          borderRadius: BorderRadius.circular(5),
          border: Border.all(
            color: active ? accentColor : const Color(0xFF1F0E04),
            width: active ? 1.6 : 1.4,
          ),
          boxShadow: active
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.50),
                    blurRadius: 8,
                  ),
                ]
              : const [
                  BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1)),
                ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon,
                style: TextStyle(
                  fontSize: 18,
                  color: active
                      ? accentColor
                      : const Color(0xFFE5C58A).withValues(alpha: 0.75),
                )),
            const SizedBox(height: 1),
            Text(label,
                style: TextStyle(
                  color: active
                      ? accentColor
                      : const Color(0xFFE5C58A).withValues(alpha: 0.75),
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                  fontFamily: 'monospace',
                  shadows: const [
                    Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 1)),
                  ],
                )),
          ],
        ),
      ),
    );
  }
}
