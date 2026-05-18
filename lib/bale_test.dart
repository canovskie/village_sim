import 'package:flutter/material.dart';

void main() => runApp(const BaleTestApp());

class BaleTestApp extends StatelessWidget {
  const BaleTestApp({super.key});
  @override
  Widget build(BuildContext context) => const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: BaleTestPage(),
      );
}

class BaleTestPage extends StatefulWidget {
  const BaleTestPage({super.key});
  @override
  State<BaleTestPage> createState() => _BaleTestPageState();
}

class _BaleTestPageState extends State<BaleTestPage> {
  // Bale pozisyonu: tile içinde 0.0–1.0 aralığında (u=col, v=row)
  double baleU = 0.1;
  double baleV = 0.1;
  // Bale boyutu: tile genişliğine oranla (0.0–1.0)
  double baleSize = 0.5;

  static const double kTileW = 200.0;
  static const double kTileH = 100.0;

  // İzometrik tile merkezden offset
  Offset tileOrigin(Size sz) =>
      Offset(sz.width / 2, sz.height * 0.35);

  // Tile-local (u,v) → ekran koordinatı
  Offset uvToScreen(double u, double v, Size sz) {
    final o = tileOrigin(sz);
    return Offset(
      o.dx + (u - v) * kTileW / 2,
      o.dy + (u + v) * kTileH / 2,
    );
  }

  // Ekran → tile-local (u,v)
  (double, double) screenToUV(Offset pos, Size sz) {
    final o = tileOrigin(sz);
    final dx = pos.dx - o.dx;
    final dy = pos.dy - o.dy;
    final u = (dx / (kTileW / 2) + dy / (kTileH / 2)) / 2;
    final v = (dy / (kTileH / 2) - dx / (kTileW / 2)) / 2;
    return (u.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1e2e1e),
      appBar: AppBar(
        backgroundColor: const Color(0xFF111e11),
        title: const Text('Bale Editor', style: TextStyle(color: Colors.white70)),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('pos: (${baleU.toStringAsFixed(2)}, ${baleV.toStringAsFixed(2)})',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
                Text('size: ${baleSize.toStringAsFixed(2)}',
                    style: const TextStyle(color: Colors.white54, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: LayoutBuilder(builder: (ctx, box) {
              final sz = Size(box.maxWidth, box.maxHeight);
              return GestureDetector(
                onPanUpdate: (d) {
                  final (u, v) = screenToUV(d.localPosition, sz);
                  setState(() {
                    baleU = (u - baleSize / 2).clamp(0.0, 1.0 - baleSize);
                    baleV = (v - baleSize / 2).clamp(0.0, 1.0 - baleSize);
                  });
                },
                child: CustomPaint(
                  painter: _TilePainter(baleU, baleV, baleSize, sz),
                  size: sz,
                ),
              );
            }),
          ),
          // Boyut slider
          Container(
            color: const Color(0xFF111e11),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              children: [
                const Text('Boyut:', style: TextStyle(color: Colors.white70)),
                Expanded(
                  child: Slider(
                    value: baleSize,
                    min: 0.1,
                    max: 1.0,
                    onChanged: (v) => setState(() => baleSize = v),
                    activeColor: const Color(0xFFD4A017),
                  ),
                ),
                SizedBox(
                  width: 40,
                  child: Text('${(baleSize * 100).round()}%',
                      style: const TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TilePainter extends CustomPainter {
  final double baleU, baleV, baleSize;
  final Size sz;
  _TilePainter(this.baleU, this.baleV, this.baleSize, this.sz);

  static const kTileW = 200.0;
  static const kTileH = 100.0;

  Offset g(double u, double v) {
    final ox = sz.width / 2;
    final oy = sz.height * 0.35;
    return Offset(ox + (u - v) * kTileW / 2, oy + (u + v) * kTileH / 2);
  }

  Path diamond(double u, double v, double w, double h) => Path()
    ..moveTo(g(u, v).dx, g(u, v).dy)
    ..lineTo(g(u + w, v).dx, g(u + w, v).dy)
    ..lineTo(g(u + w, v + h).dx, g(u + w, v + h).dy)
    ..lineTo(g(u, v + h).dx, g(u, v + h).dy)
    ..close();

  @override
  void paint(Canvas canvas, Size size) {
    // ── Ana tile ──────────────────────────────────────────────────────────────
    canvas.drawPath(diamond(0, 0, 1, 1),
        Paint()..color = const Color(0xFF4a7c4e));
    canvas.drawPath(
        diamond(0, 0, 1, 1),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0);

    // ── Alt kılavuz: 4 çeyrek ────────────────────────────────────────────────
    final pGuide = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawPath(diamond(0, 0, 0.5, 0.5), pGuide);
    canvas.drawPath(diamond(0.5, 0, 0.5, 0.5), pGuide);
    canvas.drawPath(diamond(0, 0.5, 0.5, 0.5), pGuide);
    canvas.drawPath(diamond(0.5, 0.5, 0.5, 0.5), pGuide);

    // ── Bale footprint (zemin) ────────────────────────────────────────────────
    final bu = baleU;
    final bv = baleV;
    final bs = baleSize;

    canvas.drawPath(
        diamond(bu, bv, bs, bs),
        Paint()..color = const Color(0xFFD4A017).withValues(alpha: 0.5));

    // ── Bale kutu (3D illüzyon) ───────────────────────────────────────────────
    const h = 28.0;
    final top   = g(bu,      bv);
    final right = g(bu + bs, bv);
    final front = g(bu + bs, bv + bs);
    final left  = g(bu,      bv + bs);

    // Sol yüz
    canvas.drawPath(
      Path()
        ..moveTo(left.dx, left.dy)
        ..lineTo(front.dx, front.dy)
        ..lineTo(front.dx, front.dy - h)
        ..lineTo(left.dx, left.dy - h)
        ..close(),
      Paint()..color = const Color(0xFFAA7D10),
    );
    // Sağ yüz
    canvas.drawPath(
      Path()
        ..moveTo(front.dx, front.dy)
        ..lineTo(right.dx, right.dy)
        ..lineTo(right.dx, right.dy - h)
        ..lineTo(front.dx, front.dy - h)
        ..close(),
      Paint()..color = const Color(0xFFC49215),
    );
    // Üst yüz
    canvas.drawPath(
      Path()
        ..moveTo(top.dx, top.dy - h)
        ..lineTo(right.dx, right.dy - h)
        ..lineTo(front.dx, front.dy - h)
        ..lineTo(left.dx, left.dy - h)
        ..close(),
      Paint()..color = const Color(0xFFE8B820),
    );

    // Kenar çizgileri
    final edge = Paint()
      ..color = const Color(0xFF6B4F08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawPath(diamond(bu, bv, bs, bs), edge);
    for (final pt in [top, right, front, left]) {
      canvas.drawLine(pt, pt.translate(0, -h), edge);
    }
    final topEdge = Paint()
      ..color = const Color(0xFF6B4F08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawLine(top.translate(0, -h), right.translate(0, -h), topEdge);
    canvas.drawLine(right.translate(0, -h), front.translate(0, -h), topEdge);
    canvas.drawLine(front.translate(0, -h), left.translate(0, -h), topEdge);
    canvas.drawLine(left.translate(0, -h), top.translate(0, -h), topEdge);

    // ── Koordinat etiketi ─────────────────────────────────────────────────────
    final tp = TextPainter(
      text: TextSpan(
        text: 'u=${bu.toStringAsFixed(2)}, v=${bv.toStringAsFixed(2)}'
              '  size=${bs.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.white70, fontSize: 13),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(sz.width / 2 - tp.width / 2, sz.height * 0.85));
  }

  @override
  bool shouldRepaint(_TilePainter old) => true;
}
