import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../buildings/building_type.dart';
import '../buildings/building_renderer.dart';
import '../core/resources.dart';
import '../rendering/asset_style.dart';
import 'app_ui.dart';

/// İnşa katalogu — alt araç çubuğundaki bina seçim menüsü. Her bina temiz koyu
/// bir kart; seçilince ember kenar+halo, karşılanamayan maliyet kırmızı.
class BuildingPanel extends StatelessWidget {
  final ResourceBundle stockpile;
  final BuildingType? selected;
  final void Function(BuildingType) onSelect;
  final bool hasFirepit;

  /// Yalnız bu kategorideki binalar gösterilir (null = hepsi). Ateş yoksa
  /// kategori yok sayılır — sadece ateş yeri kartı çıkar.
  final BuildCategory? category;

  const BuildingPanel({
    super.key,
    required this.stockpile,
    required this.selected,
    required this.onSelect,
    this.hasFirepit = false,
    this.category,
  });

  @override
  Widget build(BuildContext context) {
    final types = !hasFirepit
        ? [BuildingType.firepit]
        : BuildingType.values
            .where((t) =>
                kBuildingMeta.containsKey(t) &&
                (category == null || kBuildingCategory[t] == category))
            .toList();
    if (types.isEmpty) return const SizedBox.shrink();

    return AppPanel(
      padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final type in types)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
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

class _BuildingTile extends StatefulWidget {
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
  State<_BuildingTile> createState() => _BuildingTileState();
}

class _BuildingTileState extends State<_BuildingTile> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[widget.type]!;
    final canAfford = widget.stockpile.canAfford(meta.cost);
    final thumb = BuildingRenderer.thumbnails[widget.type];
    final sel = widget.selected;
    final hot = _hover || sel;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          width: 66,
          padding: const EdgeInsets.fromLTRB(5, 6, 5, 6),
          transform: _hover && !sel
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: sel
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.22), AppUi.surface2)
                : hot
                    ? AppUi.surface3
                    : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: sel ? AppUi.accent : AppUi.line,
              width: sel ? 1.6 : 1,
            ),
            boxShadow: sel
                ? [BoxShadow(color: AppUi.accent.withValues(alpha: 0.4), blurRadius: 10)]
                : null,
          ),
          child: Opacity(
            opacity: canAfford ? 1.0 : 0.5,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 38,
                  child: thumb != null
                      ? CustomPaint(
                          size: const Size(54, 38),
                          painter: _ThumbPainter(thumb))
                      : Center(
                          child: GameIcon(GameIconData.home,
                              size: 22,
                              color: canAfford ? AppUi.textMid : AppUi.textLo),
                        ),
                ),
                const SizedBox(height: 3),
                SizedBox(
                  height: 20,
                  child: Center(
                    child: Text(meta.label,
                        textAlign: TextAlign.center,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                        style: AppUi.body.copyWith(
                          fontSize: 8.5,
                          height: 1.12,
                          fontWeight: FontWeight.w700,
                          color: sel
                              ? AppUi.accentSoft
                              : canAfford
                                  ? AppUi.textMid
                                  : AppUi.textLo,
                        )),
                  ),
                ),
                const SizedBox(height: 3),
                _CostStrip(cost: meta.cost, stockpile: widget.stockpile),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bina maliyeti — kompakt ikon+sayı şeridi; karşılanamayan kaynak kırmızı.
class _CostStrip extends StatelessWidget {
  final ResourceCost cost;
  final ResourceBundle stockpile;
  const _CostStrip({required this.cost, required this.stockpile});

  @override
  Widget build(BuildContext context) {
    if (cost.isFree) {
      return Text('Ücretsiz',
          style: AppUi.button.copyWith(fontSize: 8, color: AppUi.sage));
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 5,
      runSpacing: 2,
      children: [
        for (final (kind, amount) in cost.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(_resIcon(kind), size: 10, color: AppUi.textLo),
              const SizedBox(width: 1.5),
              Text('$amount',
                  style: AppUi.number.copyWith(
                      fontSize: 9,
                      color: stockpile.get(kind) >= amount
                          ? AppUi.textMid
                          : AppUi.rust)),
            ],
          ),
      ],
    );
  }
}

GameIconData _resIcon(ResourceKind k) => switch (k) {
      ResourceKind.wood => GameIconData.wood,
      ResourceKind.stone => GameIconData.stone,
      ResourceKind.iron => GameIconData.iron,
      ResourceKind.coal => GameIconData.coal,
      ResourceKind.food => GameIconData.wheat,
      ResourceKind.gold => GameIconData.coin,
      ResourceKind.honey => GameIconData.honey,
      ResourceKind.reed => GameIconData.reed,
    };

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
    canvas.drawImageRect(img, Rect.fromLTWH(0, 0, sw, sh),
        Rect.fromLTWH(left, top, w, h), _paint);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.img != img;
}
