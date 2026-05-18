import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../buildings/building_type.dart';
import '../buildings/building_renderer.dart';
import '../core/resources.dart';
import '../rendering/asset_style.dart';
import 'game_theme.dart';

class BuildingPanel extends StatelessWidget {
  final ResourceBundle stockpile;
  final BuildingType? selected;
  final void Function(BuildingType) onSelect;
  final bool hasFirepit;

  const BuildingPanel({
    super.key,
    required this.stockpile,
    required this.selected,
    required this.onSelect,
    this.hasFirepit = false,
  });

  @override
  Widget build(BuildContext context) {
    final types = hasFirepit
        ? BuildingType.values.where((t) => kBuildingMeta.containsKey(t)).toList()
        : [BuildingType.firepit];
    if (types.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: MedievalTheme.panelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MedievalTheme.rivet(),
          const SizedBox(width: 4),
          ...types.map((type) {
            final meta       = kBuildingMeta[type]!;
            final canAfford  = stockpile.canAfford(meta.cost);
            final isSelected = selected == type;
            final thumb      = BuildingRenderer.thumbnails[type];

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: GestureDetector(
                onTap: () => onSelect(type),
                child: Container(
                  width: 64,
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: MedievalTheme.chipDecoration(
                    selected: isSelected,
                    disabled: !canAfford,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Thumbnail veya fallback ikon
                      SizedBox(
                        height: 38,
                        child: thumb != null
                            ? Opacity(
                                opacity: canAfford ? 1.0 : 0.35,
                                child: CustomPaint(
                                  size: const Size(54, 38),
                                  painter: _ThumbPainter(thumb),
                                ),
                              )
                            : Text('⌂',
                                style: TextStyle(
                                  color: canAfford
                                      ? MedievalTheme.textPrimary
                                      : MedievalTheme.textDim,
                                  fontSize: 22,
                                )),
                      ),
                      const SizedBox(height: 2),
                      Text(meta.label,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: TextStyle(
                            color: canAfford
                                ? (isSelected ? MedievalTheme.textAccent : MedievalTheme.textPrimary)
                                : MedievalTheme.textDim,
                            fontSize: 8,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'monospace',
                          )),
                      const SizedBox(height: 2),
                      _CostStrip(cost: meta.cost, stockpile: stockpile),
                    ],
                  ),
                ),
              ),
            );
          }),
          const SizedBox(width: 4),
          MedievalTheme.rivet(),
        ],
      ),
    );
  }
}

/// Bina maliyetini iki satırlık kompakt bir şerit halinde gösterir.
/// Karşılanamayan kaynaklar kırmızı renkle vurgulanır.
class _CostStrip extends StatelessWidget {
  final ResourceCost cost;
  final ResourceBundle stockpile;
  const _CostStrip({required this.cost, required this.stockpile});

  @override
  Widget build(BuildContext context) {
    if (cost.isFree) {
      return const Text('Ücretsiz',
          style: TextStyle(
            color: MedievalTheme.successColor,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
          ));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 1,
      children: [
        for (final (kind, amount) in cost.entries)
          _CostBit(
            kind: kind,
            amount: amount,
            has: stockpile.get(kind),
          ),
      ],
    );
  }
}

class _CostBit extends StatelessWidget {
  final ResourceKind kind;
  final int amount;
  final int has;
  const _CostBit({required this.kind, required this.amount, required this.has});

  @override
  Widget build(BuildContext context) {
    final ok = has >= amount;
    return Text('${kind.icon}$amount',
        style: TextStyle(
          color: ok ? MedievalTheme.textAccent : MedievalTheme.dangerColor,
          fontSize: 9,
          fontWeight: FontWeight.bold,
          fontFamily: 'monospace',
        ));
  }
}

/// Pre-scaled thumbnail'ı orijinal oranıyla çizen hafif painter
class _ThumbPainter extends CustomPainter {
  final ui.Image img;
  _ThumbPainter(this.img);

  static final _paint = AssetStyle.paint();

  @override
  void paint(Canvas canvas, Size size) {
    final sw = img.width.toDouble();
    final sh = img.height.toDouble();
    // Contain: genişlik veya yükseklikten hangisi sınırlıyorsa ona göre ölçekle
    final scale = (sw / sh > size.width / size.height)
        ? size.width / sw
        : size.height / sh;
    final w = sw * scale;
    final h = sh * scale;
    final left = (size.width - w) / 2;  // yatay ortala
    final top  = size.height - h;        // alta hizala
    canvas.drawImageRect(
      img,
      Rect.fromLTWH(0, 0, sw, sh),
      Rect.fromLTWH(left, top, w, h),
      _paint,
    );
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.img != img;
}
