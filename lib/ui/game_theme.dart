import 'package:flutter/material.dart';

/// Retro Medieval UI tema sabitleri
abstract final class MedievalTheme {
  // ── Renkler ────────────────────────────────────────────────────────────────
  static const panelBg       = Color(0xF01A0E06);
  static const panelBgLight  = Color(0xF0281808);
  static const panelBorder   = Color(0xFF4A3018);
  static const panelHighlight = Color(0xFF6B4A20);

  static const textPrimary   = Color(0xFFE8D5A3);
  static const textSecondary = Color(0xFF9B8654);
  static const textAccent    = Color(0xFFFFD944);
  static const textDim       = Color(0xFF5A4428);

  static const chipBg        = Color(0xFF160C04);
  static const chipBorder    = Color(0xFF5A3C18);

  static const activeBg      = Color(0xFF3A2208);
  static const activeBorder  = Color(0xFFCCA030);

  static const dangerColor   = Color(0xFFCC4422);
  static const successColor  = Color(0xFF6ABB44);

  // ── Dekorasyon ─────────────────────────────────────────────────────────────

  /// Ana panel çerçevesi — çift kenarlıklı ortaçağ ahşap görünümü
  static BoxDecoration panelDecoration({bool active = false}) => BoxDecoration(
    color: panelBg,
    border: Border(
      top:    BorderSide(color: active ? activeBorder : panelHighlight, width: 2),
      left:   BorderSide(color: active ? activeBorder : panelHighlight, width: 2),
      right:  BorderSide(color: active ? activeBorder : panelBorder, width: 2),
      bottom: BorderSide(color: active ? activeBorder : panelBorder, width: 2),
    ),
    boxShadow: const [
      BoxShadow(color: Color(0x44000000), blurRadius: 8, offset: Offset(2, 3)),
    ],
  );

  /// Chip / küçük eleman çerçevesi
  static BoxDecoration chipDecoration({
    bool selected = false,
    bool disabled = false,
  }) => BoxDecoration(
    color: selected ? activeBg : chipBg,
    border: Border(
      top:    BorderSide(
        color: selected ? activeBorder : (disabled ? textDim : chipBorder),
        width: selected ? 2 : 1,
      ),
      left:   BorderSide(
        color: selected ? activeBorder : (disabled ? textDim : chipBorder),
        width: selected ? 2 : 1,
      ),
      right:  BorderSide(
        color: selected ? activeBorder : (disabled ? const Color(0xFF2A1808) : const Color(0xFF3A2410)),
        width: selected ? 2 : 1,
      ),
      bottom: BorderSide(
        color: selected ? activeBorder : (disabled ? const Color(0xFF2A1808) : const Color(0xFF3A2410)),
        width: selected ? 2 : 1,
      ),
    ),
  );

  /// Buton çerçevesi
  static BoxDecoration buttonDecoration({
    bool active = false,
    Color? accentColor,
  }) {
    final c = accentColor ?? panelHighlight;
    final ac = accentColor ?? activeBorder;
    return BoxDecoration(
      color: active ? Color.alphaBlend(ac.withValues(alpha: 0.2), chipBg) : chipBg,
      border: Border(
        top:    BorderSide(color: active ? ac : c, width: active ? 2 : 1),
        left:   BorderSide(color: active ? ac : c, width: active ? 2 : 1),
        right:  BorderSide(color: active ? ac : const Color(0xFF2A1808), width: active ? 2 : 1),
        bottom: BorderSide(color: active ? ac : const Color(0xFF2A1808), width: active ? 2 : 1),
      ),
    );
  }

  // ── Text Stilleri ──────────────────────────────────────────────────────────
  static const labelStyle = TextStyle(
    color: textPrimary,
    fontSize: 11,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
  );

  static const smallStyle = TextStyle(
    color: textSecondary,
    fontSize: 9,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
  );

  static const titleStyle = TextStyle(
    color: textAccent,
    fontSize: 13,
    fontWeight: FontWeight.bold,
    fontFamily: 'monospace',
    letterSpacing: 2.0,
  );

  // ── Yatay süsleme çizgisi ────────────────────────────────────────────────
  static Widget divider() => Container(
    height: 2,
    margin: const EdgeInsets.symmetric(vertical: 3),
    decoration: const BoxDecoration(
      gradient: LinearGradient(colors: [
        Color(0x00000000),
        Color(0xFF6B4A20),
        Color(0xFFAA8030),
        Color(0xFF6B4A20),
        Color(0x00000000),
      ]),
    ),
  );

  /// Köşe süsü (dekoratif çivi/perçin)
  static Widget rivet() => Container(
    width: 6, height: 6,
    decoration: const BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [
        Color(0xFFBB9944),
        Color(0xFF6B4A20),
      ]),
    ),
  );
}
