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

  /// Köyün zanaat kilidi — false dönen bina menüde HİÇ görünmez (açılınca
  /// belirir). null = filtre yok (hepsi görünür).
  final bool Function(BuildingType)? isUnlocked;

  /// ŞU ANKİ ADIMIN istediği kart (bkz. Quest.buildTarget) — sakin bir halka
  /// ile işaretlenir. Yönlendirmenin arayüz ayağı: dünyadaki işaret "nereye"yi,
  /// bu "neye tıklayacağım"ı gösterir. null = işaretlenecek kart yok.
  final BuildingType? hintType;

  const BuildingPanel({
    super.key,
    required this.stockpile,
    required this.selected,
    required this.onSelect,
    this.hasFirepit = false,
    this.category,
    this.isUnlocked,
    this.hintType,
  });

  @override
  Widget build(BuildContext context) {
    final types = !hasFirepit
        ? [BuildingType.firepit]
        : BuildingType.values
              .where(
                (t) =>
                    kBuildingMeta.containsKey(t) &&
                    (category == null || kBuildingCategory[t] == category) &&
                    (isUnlocked == null || isUnlocked!(t)),
              )
              .toList();
    if (types.isEmpty) return const SizedBox.shrink();

    if (useCompactGameUi(context)) {
      return SizedBox(
        height: 64,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
          itemCount: types.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, index) {
            final type = types[index];
            return _BuildingTile(
              hinted: type == hintType,
              type: type,
              selected: selected == type,
              stockpile: stockpile,
              compact: true,
              onTap: () => onSelect(type),
            );
          },
        ),
      );
    }

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
                hinted: type == hintType,
                selected: selected == type,
                stockpile: stockpile,
                compact: false,
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
  /// Şu anki adımın istediği kart mı — nefes alan bir halka ile işaretlenir.
  final bool hinted;
  final bool selected;
  final ResourceBundle stockpile;
  final bool compact;
  final VoidCallback onTap;

  const _BuildingTile({
    required this.type,
    this.hinted = false,
    required this.selected,
    required this.stockpile,
    required this.compact,
    required this.onTap,
  });

  @override
  State<_BuildingTile> createState() => _BuildingTileState();
}

class _BuildingTileState extends State<_BuildingTile>
    with SingleTickerProviderStateMixin {
  bool _hover = false;

  /// Nabız YALNIZ işaretli kartta döner — panelde onlarca kart var, hepsine
  /// ticker takmak boşuna kare üretimi olurdu. İşaret kalkınca durur.
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.hinted) _startPulse();
  }

  @override
  void didUpdateWidget(_BuildingTile old) {
    super.didUpdateWidget(old);
    if (widget.hinted && _pulse == null) _startPulse();
    if (!widget.hinted && _pulse != null) {
      _pulse!.dispose();
      _pulse = null;
    }
  }

  void _startPulse() {
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[widget.type]!;
    final canAfford = widget.stockpile.canAfford(meta.cost);
    final thumb = BuildingRenderer.thumbnails[widget.type];
    final sel = widget.selected;
    final hot = _hover || sel;
    final compact = widget.compact;

    final tile = MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 130),
          curve: Curves.easeOut,
          // Mobil kart 142×68'di; katalog tek başına ekranın yarısını yiyordu.
          // Yükseklik thumbnail'dan geliyordu (52px) — asıl kısılan orası.
          width: compact ? 126 : 66,
          height: compact ? 58 : null,
          padding: compact
              ? const EdgeInsets.fromLTRB(6, 4, 7, 4)
              : const EdgeInsets.fromLTRB(5, 6, 5, 6),
          transform: _hover && !sel
              ? Matrix4.translationValues(0, -2, 0)
              : Matrix4.identity(),
          decoration: BoxDecoration(
            color: sel
                ? Color.alphaBlend(
                    AppUi.accent.withValues(alpha: 0.22),
                    AppUi.surface2,
                  )
                : hot
                ? AppUi.surface3
                : AppUi.surface0,
            borderRadius: BorderRadius.circular(AppUi.radiusSm),
            border: Border.all(
              color: sel ? AppUi.accent : AppUi.line,
              width: sel ? 1.6 : 1,
            ),
            // Seçili kart artık ember HALO ile değil, net ember KENAR + hafif
            // ember-tint dolguyla ayrışır (Flash ışıması göz yormasın).
          ),
          child: Opacity(
            opacity: canAfford ? 1.0 : 0.5,
            child: compact
                ? Row(
                    children: [
                      SizedBox(
                        width: 40,
                        height: 42,
                        child: thumb != null
                            ? CustomPaint(
                                size: const Size(40, 42),
                                painter: _ThumbPainter(thumb),
                              )
                            : Center(
                                child: GameIcon(
                                  GameIconData.home,
                                  size: 19,
                                  color: canAfford
                                      ? AppUi.textMid
                                      : AppUi.textLo,
                                ),
                              ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              meta.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppUi.body.copyWith(
                                fontSize: 10.5,
                                height: 1.0,
                                fontWeight: FontWeight.w700,
                                color: sel
                                    ? AppUi.accentSoft
                                    : canAfford
                                    ? AppUi.textHi
                                    : AppUi.textLo,
                              ),
                            ),
                            const SizedBox(height: 3),
                            _CostStrip(
                              cost: meta.cost,
                              stockpile: widget.stockpile,
                              compact: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  )
                : Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        height: 38,
                        child: thumb != null
                            ? CustomPaint(
                                size: const Size(54, 38),
                                painter: _ThumbPainter(thumb),
                              )
                            : Center(
                                child: GameIcon(
                                  GameIconData.home,
                                  size: 22,
                                  color: canAfford
                                      ? AppUi.textMid
                                      : AppUi.textLo,
                                ),
                              ),
                      ),
                      const SizedBox(height: 3),
                      SizedBox(
                        height: 20,
                        child: Center(
                          child: Text(
                            meta.label,
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
                            ),
                          ),
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

    final p = _pulse;
    if (p == null) return tile;

    // ADIM İŞARETİ — kartın ETRAFINDA nefes alan bir halka.
    //
    // Kartın kendi kenarına dokunulmuyor: seçili kartın ember kenarı zaten bir
    // anlam taşıyor ("bunu seçtin"), işaret onun yerine geçerse iki farklı
    // durum aynı görünürdü. Halka DIŞARIDA duruyor → "önce şunu seç" ile
    // "şu an seçili" ayrı ayrı okunuyor.
    //
    // Kartın kendisi büyümüyor/zıplamıyor: satırdaki diğer kartların yerini
    // oynatan bir işaret, aradığı şeyi bulmaya çalışan oyuncunun elini
    // titretir.
    return AnimatedBuilder(
      animation: p,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(p.value);
        return Container(
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppUi.radiusSm + 3),
            border: Border.all(
              color: AppUi.accent.withValues(alpha: 0.35 + 0.45 * t),
              width: 1.6,
            ),
          ),
          child: child,
        );
      },
      child: tile,
    );
  }
}

/// Bina maliyeti — kompakt ikon+sayı şeridi; karşılanamayan kaynak kırmızı.
class _CostStrip extends StatelessWidget {
  final ResourceCost cost;
  final ResourceBundle stockpile;
  final bool compact;
  const _CostStrip({
    required this.cost,
    required this.stockpile,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cost.isFree) {
      return Text(
        'Ücretsiz',
        style: AppUi.button.copyWith(
          fontSize: compact ? 11 : 8,
          color: AppUi.sage,
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 4 : 5,
      runSpacing: 2,
      children: [
        for (final (kind, amount) in cost.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(
                _resIcon(kind),
                size: compact ? 11 : 10,
                color: AppUi.textLo,
              ),
              const SizedBox(width: 1.5),
              Text(
                '$amount',
                style: AppUi.number.copyWith(
                  fontSize: compact ? 11 : 9,
                  color: stockpile.get(kind) >= amount
                      ? AppUi.textMid
                      : AppUi.rust,
                ),
              ),
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
