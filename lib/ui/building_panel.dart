import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../buildings/building_type.dart';
import '../buildings/building_renderer.dart';
import '../core/resources.dart';
import '../rendering/asset_style.dart';
import 'cozy_theme.dart';

/// Ahşap inşaat rafı — alt araç çubuğundaki bina seçim panosu. Her bina
/// kendi deri sekme tile'ı; seçilince ember halo, karşılanamayan maliyet
/// kırmızı oyma rakamlarla işaretlenir.
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

    return WoodPlankPanel(
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in types)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _BuildingTile(
                type: type,
                selected: selected == type,
                stockpile: stockpile,
                onTap: () => onSelect(type),
              ),
            ),
        ],
      ),
    );
  }
}

class _BuildingTile extends StatelessWidget {
  final BuildingType type;
  final bool selected;
  final ResourceBundle stockpile;
  final VoidCallback onTap;

  const _BuildingTile({
    required this.type,
    required this.selected,
    required this.stockpile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[type]!;
    final canAfford = stockpile.canAfford(meta.cost);
    final thumb = BuildingRenderer.thumbnails[type];

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 64,
        padding: const EdgeInsets.fromLTRB(4, 5, 4, 5),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: selected
                ? [
                    Color.alphaBlend(
                        CozyUi.ember.withValues(alpha: 0.40),
                        const Color(0xFF1A0E04)),
                    Color.alphaBlend(
                        CozyUi.ember.withValues(alpha: 0.18),
                        const Color(0xFF120804)),
                  ]
                : const [Color(0xCC1A0E04), Color(0xCC0A0502)],
          ),
          borderRadius: BorderRadius.circular(3),
          border: Border.all(
            color: selected ? CozyUi.ember : const Color(0xFF1F0E04),
            width: selected ? 1.6 : 1.2,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: CozyUi.ember.withValues(alpha: 0.50),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        child: Opacity(
          opacity: canAfford ? 1.0 : 0.55,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 38,
                child: thumb != null
                    ? CustomPaint(
                        size: const Size(54, 38),
                        painter: _ThumbPainter(thumb),
                      )
                    : Text('⌂',
                        style: TextStyle(
                          color: canAfford
                              ? const Color(0xFFE5C58A)
                              : const Color(0xFF6B5A40),
                          fontSize: 22,
                        )),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 20,
                child: Center(
                  child: Text(meta.label,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                      style: TextStyle(
                        color: canAfford
                            ? (selected
                                ? CozyUi.ember
                                : const Color(0xFFE5C58A))
                            : const Color(0xFF7A6240),
                        fontSize: 8,
                        height: 1.15,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        shadows: const [
                          Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 1)),
                        ],
                      )),
                ),
              ),
              const SizedBox(height: 2),
              _CostStrip(cost: meta.cost, stockpile: stockpile),
            ],
          ),
        ),
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
            color: CozyUi.sage,
            fontSize: 8,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            shadows: [
              Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 1)),
            ],
          ));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 1,
      children: [
        for (final (kind, amount) in cost.entries)
          Text('${kind.icon}$amount',
              style: TextStyle(
                color: stockpile.get(kind) >= amount
                    ? const Color(0xFFE5C58A)
                    : CozyUi.rust,
                fontSize: 9,
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace',
                shadows: const [
                  Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 1)),
                ],
              )),
      ],
    );
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
    final scale = (sw / sh > size.width / size.height)
        ? size.width / sw
        : size.height / sh;
    final w = sw * scale;
    final h = sh * scale;
    final left = (size.width - w) / 2;
    final top = size.height - h;
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
