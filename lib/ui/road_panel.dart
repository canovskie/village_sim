import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../world/road_surface.dart';
import 'game_theme.dart';

/// Yol döşeme paneli — 3 surface chip (toprak / taş / köprü).
/// Bir chip seçilince road placement mode aktif olur; main.dart taraf
/// gesture handler tap+drag ile döşer.
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: MedievalTheme.panelDecoration(),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          MedievalTheme.rivet(),
          const SizedBox(width: 4),
          for (final s in RoadSurface.values) ...[
            _Chip(
              surface:   s,
              selected:  selected == s,
              canAfford: stockpile.canAfford(s.cost),
              stockpile: stockpile,
              onTap:     () => onSelect(s),
            ),
            const SizedBox(width: 2),
          ],
          MedievalTheme.rivet(),
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
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: MedievalTheme.chipDecoration(
          selected: selected,
          disabled: !canAfford,
        ),
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
                        ? (selected ? MedievalTheme.textAccent : MedievalTheme.textPrimary)
                        : MedievalTheme.textDim,
                    fontSize: 8,
                    height: 1.15,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            _CostLine(cost: cost, stockpile: stockpile),
          ],
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
            color: MedievalTheme.successColor,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
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
                    ? MedievalTheme.textAccent
                    : MedievalTheme.dangerColor,
                fontSize: 9,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              )),
      ],
    );
  }
}
