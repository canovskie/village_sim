import 'package:flutter/material.dart';
import '../core/resources.dart';
import '../world/road_surface.dart';
import 'app_ui.dart';
import 'semantic_icon.dart';

/// Yol rafı — 3 surface chip (toprak / taş / köprü) + SİLGİ. Modern koyu panel;
/// bir chip seçilince yol modu aktif, accent (ember) vurgu çevreliyor.
///
/// Silgi ayrı bir chip: yanlış döşenmiş yolun tek geri dönüşü. Öncesinde
/// döşenen yol hiçbir şekilde kaldırılamıyordu — hata kalıcıydı.
class RoadPanel extends StatelessWidget {
  final ResourceBundle stockpile;
  final RoadSurface? selected;
  final void Function(RoadSurface) onSelect;
  final bool eraseSelected;
  final VoidCallback onSelectErase;

  const RoadPanel({
    super.key,
    required this.stockpile,
    required this.selected,
    required this.onSelect,
    this.eraseSelected = false,
    required this.onSelectErase,
  });

  @override
  Widget build(BuildContext context) {
    return AppPanel(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final s in RoadSurface.values)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: _Chip(
                surface: s,
                selected: selected == s,
                canAfford: stockpile.canAfford(s.cost),
                stockpile: stockpile,
                onTap: () => onSelect(s),
              ),
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _EraseChip(
              selected: eraseSelected,
              onTap: onSelectErase,
            ),
          ),
        ],
      ),
    );
  }
}

/// Yol silgisi chip'i — surface chip'leriyle aynı ölçüde, ayrı renkte (sönük
/// kırmızı) ki "döşe" ile "sil" gözle karışmasın.
class _EraseChip extends StatelessWidget {
  final bool selected;
  final VoidCallback onTap;
  const _EraseChip({required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    const tint = Color(0xFFCC6655);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 58,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(tint.withValues(alpha: 0.20), AppUi.surface2)
              : AppUi.surface1,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
            color: selected ? tint : AppUi.line,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 9)]
              : null,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              height: 26,
              child: Center(
                child: GameIcon(GameIconData.demolish,
                    size: 20, color: AppUi.rust),
              ),
            ),
            const SizedBox(height: 3),
            SizedBox(
              height: 22,
              child: Center(
                child: Text(
                  'Yolu Sil',
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                  style: AppUi.body.copyWith(
                    fontSize: 8.5,
                    height: 1.15,
                    fontWeight: FontWeight.w700,
                    color: selected ? tint : AppUi.textMid,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text('yarı iade',
                style: AppUi.body.copyWith(
                  fontSize: 8,
                  color: AppUi.textLo,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
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
    const tint = AppUi.accent;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: 58,
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 6),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(tint.withValues(alpha: 0.20), AppUi.surface2)
              : AppUi.surface1,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(
            color: selected ? tint : AppUi.line,
            width: selected ? 1.6 : 1,
          ),
          boxShadow: selected
              ? [BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 9)]
              : null,
        ),
        child: Opacity(
          opacity: canAfford ? 1.0 : 0.5,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 26,
                child: Center(
                  child: SemanticIcon(surface.icon,
                      size: 20, color: tint, fallback: GameIconData.map),
                ),
              ),
              const SizedBox(height: 3),
              SizedBox(
                height: 22,
                child: Center(
                  child: Text(
                    surface.label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    maxLines: 2,
                    style: AppUi.body.copyWith(
                      fontSize: 8.5,
                      height: 1.15,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? AppUi.accentSoft
                          : (canAfford ? AppUi.textMid : AppUi.textLo),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 3),
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
      return Text('Ücretsiz',
          style: AppUi.body.copyWith(
            color: AppUi.sage,
            fontSize: 8.5,
            fontWeight: FontWeight.w700,
          ));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 4,
      runSpacing: 1,
      children: [
        for (final (kind, amount) in cost.entries)
          _ResourceCost(kind: kind, amount: amount, available: stockpile.get(kind)),
      ],
    );
  }
}

class _ResourceCost extends StatelessWidget {
  const _ResourceCost({required this.kind, required this.amount, required this.available});
  final ResourceKind kind;
  final int amount;
  final int available;

  @override
  Widget build(BuildContext context) {
    final color = available >= amount ? AppUi.textMid : AppUi.rust;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SemanticIcon(kind.icon,
            size: 10, color: color, fallback: GameIconData.star),
        const SizedBox(width: 2),
        Text('$amount',
            style: AppUi.body.copyWith(
              color: color,
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
            )),
      ],
    );
  }
}
