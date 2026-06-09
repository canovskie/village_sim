import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../world/road_surface.dart';
import 'cozy_theme.dart';

/// Yol döşeme rafı — 3 surface chip (toprak / taş / köprü). Ahşap pano +
/// deri sekme tile'lar; building rack ile aynı dil. Bir chip seçilince road
/// placement mode aktif, ember halo çevreliyor.
class RoadPanel extends StatelessWidget {
  final ResourceBundle stockpile;
  final RoadSurface? selected;
  final void Function(RoadSurface) onSelect;

  const RoadPanel({
    super.key,
    required this.stockpile,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return WoodPlankPanel(
      padding: const EdgeInsets.fromLTRB(7, 6, 7, 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in RoadSurface.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1),
              child: _Chip(
                surface:   s,
                selected:  selected == s,
                canAfford: stockpile.canAfford(s.cost),
                stockpile: stockpile,
                onTap:     () => onSelect(s),
              ),
            ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final RoadSurface surface;
  final bool selected;
  final bool canAfford;
  final ResourceBundle stockpile;
  final VoidCallback onTap;

  const _Chip({
    required this.surface,
    required this.selected,
    required this.canAfford,
    required this.stockpile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cost = surface.cost;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 56,
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
                height: 26,
                child: Center(
                  child: Text(surface.icon, style: const TextStyle(fontSize: 20)),
                ),
              ),
              const SizedBox(height: 2),
              SizedBox(
                height: 20,
                child: Center(
                  child: Text(
                    surface.label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: TextStyle(
                      color: canAfford
                          ? (selected ? CozyUi.ember : const Color(0xFFE5C58A))
                          : const Color(0xFF7A6240),
                      fontSize: 8,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace',
                      shadows: const [
                        Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 1)),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 2),
              _CostLine(cost: cost, stockpile: stockpile),
            ],
          ),
        ),
      ),
    );
  }
}

class _CostLine extends StatelessWidget {
  final ResourceCost cost;
  final ResourceBundle stockpile;
  const _CostLine({required this.cost, required this.stockpile});

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
      spacing: 3,
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
