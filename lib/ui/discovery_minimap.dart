import 'package:flutter/material.dart';
import '../core/constants.dart';
import 'app_ui.dart';

/// Keşif mini-haritası — sahnede sahip OLMADIĞIN orman sisle örtülü (görünmez),
/// ama burada üstten bakışla ÖĞRENİRSİN: sahip olunan açıklık + göl/su + maden
/// konumları belli olur. "Nereye genişlesem?" kararını verirsin, orman sahnede
/// gözükmeden. Su/maden fogda da işaretlenir (öğrenme kanalı).
class DiscoveryMinimap extends StatelessWidget {
  final Set<(int, int)> cleared;    // sahip olunan (açık) kara
  final Set<(int, int)> water;      // su/göl (tüm harita)
  final List<(int, int, Color)> oreMarkers; // (col,row,renk) maden düğümleri
  const DiscoveryMinimap({
    super.key,
    required this.cleared,
    required this.water,
    required this.oreMarkers,
  });

  static const double _w = 168.0;

  @override
  Widget build(BuildContext context) {
    final scale = _w / kCols;
    final h = kRows * scale;
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
      decoration: BoxDecoration(
        color: AppUi.surface1,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: AppUi.line, width: 1),
        boxShadow: AppUi.softShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 5, left: 1),
            child: Text('BİLİNEN TOPRAKLAR',
                style: AppUi.label.copyWith(letterSpacing: 1.6, fontSize: 9.5)),
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: CustomPaint(
              size: Size(_w, h),
              painter: _MiniPainter(cleared, water, oreMarkers),
            ),
          ),
        ],
      ),
    );
  }
}

class _MiniPainter extends CustomPainter {
  final Set<(int, int)> cleared;
  final Set<(int, int)> water;
  final List<(int, int, Color)> oreMarkers;
  _MiniPainter(this.cleared, this.water, this.oreMarkers);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / kCols;
    final cell = s + 0.6; // hafif overlap → boşluk çizgisi kalmasın
    final p = Paint()..isAntiAlias = false;

    // Sis tabanı (tüm bilinmeyen orman) — düz koyu.
    p.color = const Color(0xFF12181A);
    canvas.drawRect(Offset.zero & size, p);

    // Su/göl (tüm harita) — fogda bile belli (öğrenme).
    p.color = const Color(0xFF3C6E88);
    for (final (c, r) in water) {
      canvas.drawRect(Rect.fromLTWH(c * s, r * s, cell, cell), p);
    }

    // Sahip olunan açık kara — açık çim tonu.
    p.color = const Color(0xFF8BA968);
    for (final (c, r) in cleared) {
      canvas.drawRect(Rect.fromLTWH(c * s, r * s, cell, cell), p);
    }

    // Maden işaretleri — cevher rengi nokta (fogda da öğrenilir).
    final dot = Paint()..isAntiAlias = true;
    for (final (c, r, col) in oreMarkers) {
      dot.color = col;
      canvas.drawCircle(Offset((c + 0.5) * s, (r + 0.5) * s), 2.2, dot);
    }
  }

  @override
  bool shouldRepaint(_MiniPainter old) =>
      old.cleared.length != cleared.length ||
      old.oreMarkers.length != oreMarkers.length ||
      old.water.length != water.length;
}
