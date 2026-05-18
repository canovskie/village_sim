import 'package:flutter/material.dart';
import 'game_theme.dart';

/// HUD altındaki mod butonu (Tarla / Kes / Kaz).
/// İkon + etiket; aktifken accent renge döner.
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
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: MedievalTheme.buttonDecoration(
          active: active,
          accentColor: accentColor,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon,
                style: TextStyle(
                  fontSize: 18,
                  color: active ? accentColor : accentColor.withValues(alpha: 0.45),
                )),
            const SizedBox(height: 2),
            Text(label,
                style: TextStyle(
                  color: active ? accentColor : accentColor.withValues(alpha: 0.45),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                )),
          ],
        ),
      ),
    );
  }
}
