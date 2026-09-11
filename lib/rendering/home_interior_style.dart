part of 'home_interior_painter.dart';

/// Renkten bağımsız biçim varyantları furnishings/decor part'larında yaşar.
class _InteriorPalette {
  final Color wall, wood, darkWood, textile, accent, linen, ceramic;
  const _InteriorPalette(
    this.wall,
    this.wood,
    this.darkWood,
    this.textile,
    this.accent,
    this.linen,
    this.ceramic,
  );
}

extension _InteriorStyling on HomeInteriorPainter {
  _InteriorPalette get _palette => switch (style) {
    InteriorStyle.cottage => const _InteriorPalette(
      Color(0xFFBEC1A3),
      Color(0xFFB88B53),
      Color(0xFF795535),
      Color(0xFF587A80),
      Color(0xFFAD684D),
      Color(0xFFE1D4B3),
      Color(0xFFAB7254),
    ),
    InteriorStyle.botanical => const _InteriorPalette(
      Color(0xFFBCCBB4),
      Color(0xFFA49165),
      Color(0xFF636348),
      Color(0xFF6D8455),
      Color(0xFFBE9860),
      Color(0xFFE9DFC2),
      Color(0xFF698E86),
    ),
    InteriorStyle.woven => const _InteriorPalette(
      Color(0xFFD2BFA8),
      Color(0xFF8E6652),
      Color(0xFF574A42),
      Color(0xFF925954),
      Color(0xFF537C87),
      Color(0xFFE5CFA7),
      Color(0xFFBE8F60),
    ),
  };

  /// Yatay elipsin izometrik yüzeydeki karşılığı, daire masası ve hasır için.
  List<Offset> _ovalPlane(double x, double y, double w, double d, double z) => [
    for (int i = 0; i < 48; i++)
      HomeInteriorPainter.project(
        x + w * (1 + cos(i * pi / 24)) / 2,
        y + d * (1 + sin(i * pi / 24)) / 2,
        z,
      ),
  ];

  void _ovalSlab(
    Canvas c,
    double x,
    double y,
    double w,
    double d,
    double z,
    double thickness,
    Color color,
  ) {
    final top = _ovalPlane(x, y, w, d, z);
    final bottom = _ovalPlane(x, y, w, d, z - thickness);
    polygon(c, bottom, _palette.darkWood);
    for (int i = 0; i < 48; i++) {
      final j = (i + 1) % 48;
      polygon(c, [top[i], bottom[i], bottom[j], top[j]], _palette.darkWood);
    }
    polygon(c, top, color, outline: Color.lerp(color, Colors.white, .2));
  }
}
