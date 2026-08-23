import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../core/resources.dart';
import '../rendering/asset_style.dart';
import '../text/voice.dart';
import 'app_ui.dart';
import 'guide_spotlight.dart';
import 'mobile_ui.dart';

/// İnşa katalogu — alt araç çubuğundaki bina seçim menüsü. Her bina temiz koyu
/// bir kart; seçilince ember kenar+halo, karşılanamayan maliyet kırmızı.
class BuildingPanel extends StatelessWidget {
  final ResourceBundle stockpile;
  final BuildingType? selected;

  /// Seçim sahne tarafından kabul edildiyse true döner. Mobil katalog yalnız
  /// bu gerçek başarı sonucunda kapanır; widget kaynak durumunu ikinci kez
  /// tahmin etmez.
  final bool Function(BuildingType) onSelect;
  final bool hasFirepit;

  /// Sahne maliyetleri gerçekten uygulamıyorsa kart da aynı kabul durumunu
  /// göstermeli. GodMode gibi politikalar widget içinde yeniden tahmin edilmez.
  final bool bypassCosts;

  /// Yalnız bu kategorideki binalar gösterilir (null = hepsi). Ateş yoksa
  /// kategori yok sayılır — sadece ateş yeri kartı çıkar.
  final BuildCategory? category;

  /// Kuruluş modu gibi sıralı akışlarda katalogu tek anlamlı karara
  /// indirir. null ise normal kategori filtresi kullanılır.
  final BuildingType? onlyType;

  /// Köyün zanaat kilidi — false dönen bina menüde HİÇ görünmez (açılınca
  /// belirir). null = filtre yok (hepsi görünür).
  final bool Function(BuildingType)? isUnlocked;

  /// ŞU ANKİ ADIMIN istediği kart (bkz. Quest.buildTarget) — sakin bir halka
  /// ile işaretlenir. Yönlendirmenin arayüz ayağı: dünyadaki işaret "nereye"yi,
  /// bu "neye tıklayacağım"ı gösterir. null = işaretlenecek kart yok.
  final BuildingType? hintType;

  /// Katalog başka bir yüzeyin (komuta çubuğundaki birleşik inşa kabuğu gibi)
  /// içinde çiziliyorsa ikinci bir [AppPanel] açma. Bağımsız kullanımda false
  /// kalır ve panel kendi yüzeyini taşır.
  final bool embedded;

  const BuildingPanel({
    super.key,
    required this.stockpile,
    required this.selected,
    required this.onSelect,
    this.hasFirepit = false,
    this.bypassCosts = false,
    this.category,
    this.onlyType,
    this.isUnlocked,
    this.hintType,
    this.embedded = false,
  });

  @override
  Widget build(BuildContext context) {
    final types = onlyType != null
        ? [onlyType!]
        : !hasFirepit
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
      final expanded = MobileCatalogScope.expandedOf(context);
      if (expanded) {
        // Tam ekran katalog kalan yüksekliği bütünüyle kullanır. Eski sabit
        // %52 yükseklik, özellikle küçük kategorilerde altta boş bir duvar;
        // kalabalık kategorilerde ise gereksiz dar bir pencere bırakıyordu.
        return LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final columns = width >= 720
                ? 4
                : width >= 500
                ? 3
                : 2;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 18),
              itemCount: types.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 9,
                mainAxisSpacing: 9,
                mainAxisExtent: 124,
              ),
              itemBuilder: (_, index) {
                final type = types[index];
                return GuideTarget(
                  id: GuideAnchors.build(type.name),
                  child: _BuildingTile(
                    hinted: type == hintType,
                    type: type,
                    selected: selected == type,
                    stockpile: stockpile,
                    bypassCosts: bypassCosts,
                    compact: true,
                    expanded: true,
                    onTap: () => onSelect(type),
                  ),
                );
              },
            );
          },
        );
      }
      return SizedBox(
        height: 70,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          itemCount: types.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, index) {
            final type = types[index];
            return GuideTarget(
              id: GuideAnchors.build(type.name),
              child: _BuildingTile(
                hinted: type == hintType,
                type: type,
                selected: selected == type,
                stockpile: stockpile,
                bypassCosts: bypassCosts,
                compact: true,
                onTap: () => onSelect(type),
              ),
            );
          },
        ),
      );
    }

    final rail = SizedBox(
      height: 124,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        itemCount: types.length,
        separatorBuilder: (_, _) => const SizedBox(width: 7),
        itemBuilder: (_, index) {
          final type = types[index];
          return GuideTarget(
            id: GuideAnchors.build(type.name),
            child: _BuildingTile(
              type: type,
              hinted: type == hintType,
              selected: selected == type,
              stockpile: stockpile,
              bypassCosts: bypassCosts,
              compact: false,
              onTap: () => onSelect(type),
            ),
          );
        },
      ),
    );
    if (embedded) return rail;

    // Standalone katalog kuruluşta tek kart taşıyabilir. Komuta çubuğunun
    // kullanılabilir bütün genişliğini koyu boş yüzeyle doldurmak yerine içerik
    // kadar büyür; kart sayısı arttığında ise mevcut viewport'ta kayar.
    final preferredWidth =
        20.0 + types.length * 116.0 + (types.length - 1) * 7.0;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.hasBoundedWidth
            ? preferredWidth.clamp(0.0, constraints.maxWidth)
            : preferredWidth;
        return AppPanel(width: width, padding: EdgeInsets.zero, child: rail);
      },
    );
  }
}

class _BuildingTile extends StatefulWidget {
  final BuildingType type;

  /// Şu anki adımın istediği kart mı — nefes alan bir halka ile işaretlenir.
  final bool hinted;
  final bool selected;
  final ResourceBundle stockpile;
  final bool bypassCosts;
  final bool compact;
  final bool expanded;
  final bool Function() onTap;

  const _BuildingTile({
    required this.type,
    this.hinted = false,
    required this.selected,
    required this.stockpile,
    required this.bypassCosts,
    required this.compact,
    this.expanded = false,
    required this.onTap,
  });

  @override
  State<_BuildingTile> createState() => _BuildingTileState();
}

class _BuildingTileState extends State<_BuildingTile>
    with SingleTickerProviderStateMixin {
  bool _hover = false;

  /// Nabız YALNIZ işaretli kartta döner — panelde onlarca kart var, hepsine
  /// dönen ticker takmak boşuna kare üretimi olurdu. İşaret kalkınca DURUR
  /// (dispose edilmez: SingleTicker bir State'te ikinci ticker'a izin vermez,
  /// işaret gidip gelince yeniden yaratmak assert'e düşerdi). Duran ticker
  /// kare üretmediği için maliyet aynı kapıya çıkar.
  AnimationController? _pulse;

  @override
  void initState() {
    super.initState();
    if (widget.hinted) _syncPulse();
  }

  @override
  void didUpdateWidget(_BuildingTile old) {
    super.didUpdateWidget(old);
    if (widget.hinted != old.hinted) _syncPulse();
  }

  void _syncPulse() {
    if (widget.hinted) {
      final c = _pulse ??= AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 1500),
      );
      if (!c.isAnimating) c.repeat(reverse: true);
    } else {
      _pulse?.stop();
    }
  }

  @override
  void dispose() {
    _pulse?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[widget.type]!;
    final canAfford =
        widget.bypassCosts || widget.stockpile.canAfford(meta.cost);
    final thumb = BuildingRenderer.thumbnails[widget.type];
    final sel = widget.selected;
    final hot = _hover || sel;
    final compact = widget.compact;
    final expanded = widget.expanded;
    final voice = VoiceCtx(
      seed: widget.type.index,
      extra: {
        'bina': meta.label,
        'boyut': '${meta.cols} çarpı ${meta.rows}',
        'eksik': widget.stockpile.formatMissing(meta.cost),
      },
    );
    final semanticsLabel = Voice.say(
      canAfford
          ? const [
              '{bina}, {boyut}; inşa edilebilir',
              '{bina}, {boyut}; kurulabilir',
            ]
          : const [
              '{bina}, {boyut}; kaynak eksik',
              '{bina}, {boyut}; malzeme eksik',
            ],
      voice,
    );
    final tooltipMessage = Voice.say(
      canAfford
          ? const ['{bina} seç', '{bina} yapısını seç']
          : const ['{bina}: {eksik} eksik', '{bina} için eksik: {eksik}'],
      voice.copyWith(seed: widget.type.index + 31),
    );

    final base = sel
        ? Color.alphaBlend(AppUi.accent.withValues(alpha: 0.18), AppUi.surface2)
        : hot
        ? AppUi.surface3
        : AppUi.surface1;
    final bottom = sel
        ? Color.alphaBlend(AppUi.accent.withValues(alpha: 0.10), AppUi.surface1)
        : AppUi.surface0;

    final card = AnimatedContainer(
      key: ValueKey('building_tile_${widget.type.name}'),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: expanded ? double.infinity : (compact ? 132 : 116),
      height: expanded ? double.infinity : (compact ? 64 : 108),
      transform: _hover && !sel
          ? Matrix4.translationValues(0, -2, 0)
          : Matrix4.identity(),
      transformAlignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [base, bottom],
        ),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(
          color: sel ? AppUi.accent : AppUi.line,
          width: sel ? 1.6 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          compact && !expanded
              ? _compactBody(meta, thumb, sel)
              : _catalogBody(meta, thumb, sel, expanded),
          Positioned(
            left: 6,
            top: 6,
            child: KeyedSubtree(
              key: ValueKey('building_state_${widget.type.name}'),
              child: _BuildingStateBadge(
                selected: sel,
                canAfford: canAfford,
                compact: compact && !expanded,
                expanded: expanded,
              ),
            ),
          ),
        ],
      ),
    );

    final tile = Semantics(
      button: true,
      selected: sel,
      label: semanticsLabel,
      child: Tooltip(
        message: tooltipMessage,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              final accepted = widget.onTap();
              // Tam ekran katalog yalnız sahne seçimi gerçekten kabul ettiyse
              // kapanır. Kaynak yetersizliği gibi retlerde oyuncu başka bir
              // kart seçebilmek için katalogda kalır.
              if (useCompactGameUi(context) && accepted) {
                const MobileCatalogCloseNotification().dispatch(context);
              }
            },
            child: card,
          ),
        ),
      ),
    );

    final p = _pulse;
    // Halka İŞARETE bağlı, controller'ın varlığına değil: işaret geçtikten
    // sonra controller duruyor ama hayatta kalıyor.
    if (!widget.hinted || p == null) return tile;

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
        return Stack(
          clipBehavior: Clip.none,
          fit: StackFit.passthrough,
          children: [
            child!,
            Positioned(
              left: -3,
              top: -3,
              right: -3,
              bottom: -3,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(AppUi.radiusSm + 3),
                    border: Border.all(
                      color: AppUi.accent.withValues(alpha: 0.35 + 0.45 * t),
                      width: 1.6,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      child: tile,
    );
  }

  Widget _catalogBody(
    BuildingMeta meta,
    ui.Image? thumb,
    bool selected,
    bool expanded,
  ) {
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: expanded ? 65 : 54,
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [AppUi.surface2, AppUi.surface0],
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    expanded ? 18 : 12,
                    expanded ? 8 : 6,
                    expanded ? 18 : 12,
                    4,
                  ),
                  child: thumb != null
                      ? CustomPaint(painter: _ThumbPainter(thumb))
                      : Center(
                          child: GameIcon(
                            GameIconData.home,
                            size: expanded ? 27 : 23,
                            color: AppUi.textMid,
                          ),
                        ),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  expanded ? 9 : 7,
                  expanded ? 5 : 3,
                  expanded ? 9 : 7,
                  expanded ? 5 : 3,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      meta.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.left,
                      style: AppUi.body.copyWith(
                        fontSize: expanded ? 12 : 11,
                        height: 1,
                        fontWeight: FontWeight.w700,
                        color: selected ? AppUi.accentSoft : AppUi.textHi,
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: _CostStrip(
                        cost: meta.cost,
                        stockpile: widget.stockpile,
                        bypassCosts: widget.bypassCosts,
                        compact: expanded,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        if (selected)
          Positioned(
            left: 18,
            top: 0,
            right: 18,
            child: Container(
              height: 2,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0x00E49139), AppUi.accent, Color(0x00E49139)],
                ),
              ),
            ),
          ),
        Positioned(
          right: 6,
          top: 6,
          child: _FootprintBadge(
            cols: meta.cols,
            rows: meta.rows,
            expanded: expanded,
          ),
        ),
      ],
    );
  }

  Widget _compactBody(BuildingMeta meta, ui.Image? thumb, bool selected) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(6, 4, 7, 4),
      child: Row(
        children: [
          SizedBox(
            width: 42,
            height: 48,
            child: thumb != null
                ? CustomPaint(painter: _ThumbPainter(thumb))
                : const Center(
                    child: GameIcon(
                      GameIconData.home,
                      size: 19,
                      color: AppUi.textMid,
                    ),
                  ),
          ),
          const SizedBox(width: 7),
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
                    fontSize: 11,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    color: selected ? AppUi.accentSoft : AppUi.textHi,
                  ),
                ),
                const SizedBox(height: 4),
                _CostStrip(
                  cost: meta.cost,
                  stockpile: widget.stockpile,
                  bypassCosts: widget.bypassCosts,
                  compact: true,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FootprintBadge extends StatelessWidget {
  final int cols;
  final int rows;
  final bool expanded;

  const _FootprintBadge({
    required this.cols,
    required this.rows,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: expanded ? 6 : 5,
      vertical: expanded ? 3 : 2,
    ),
    decoration: BoxDecoration(
      color: AppUi.surface0.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(5),
      border: Border.all(color: AppUi.line),
    ),
    child: Text(
      '$cols×$rows',
      style: AppUi.number.copyWith(
        fontSize: expanded ? 11 : 9.5,
        height: 1,
        color: AppUi.textMid,
      ),
    ),
  );
}

class _BuildingStateBadge extends StatelessWidget {
  final bool selected;
  final bool canAfford;
  final bool compact;
  final bool expanded;

  const _BuildingStateBadge({
    required this.selected,
    required this.canAfford,
    required this.compact,
    required this.expanded,
  });

  @override
  Widget build(BuildContext context) {
    final (label, tone) = selected
        ? (compact ? 'SEÇ' : 'SEÇİLİ', AppUi.accent)
        : canAfford
        ? ('HAZIR', AppUi.sage)
        : ('EKSİK', AppUi.rust);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: expanded ? 6 : (compact ? 4 : 5),
        vertical: expanded ? 3 : 2,
      ),
      decoration: BoxDecoration(
        color: Color.alphaBlend(tone.withValues(alpha: 0.20), AppUi.surface0),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: tone.withValues(alpha: 0.72)),
      ),
      child: Text(
        label,
        maxLines: 1,
        style: AppUi.label.copyWith(
          fontSize: expanded ? 11 : (compact ? 8 : 8.5),
          height: 1,
          letterSpacing: expanded ? 0.7 : 0.5,
          color: tone,
        ),
      ),
    );
  }
}

/// Bina maliyeti — kompakt ikon+sayı şeridi; karşılanamayan kaynak kırmızı.
class _CostStrip extends StatelessWidget {
  final ResourceCost cost;
  final ResourceBundle stockpile;
  final bool bypassCosts;
  final bool compact;
  const _CostStrip({
    required this.cost,
    required this.stockpile,
    this.bypassCosts = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (cost.isFree) {
      return Text(
        'Ücretsiz',
        style: AppUi.button.copyWith(
          fontSize: compact ? 11 : 10.5,
          color: AppUi.sage,
        ),
      );
    }
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: compact ? 5 : 4,
      runSpacing: 2,
      children: [
        for (final (kind, amount) in cost.entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              GameIcon(
                _resIcon(kind),
                size: compact ? 12 : 11,
                color: AppUi.textLo,
              ),
              const SizedBox(width: 1.5),
              Text(
                '$amount',
                style: AppUi.number.copyWith(
                  fontSize: compact ? 11 : 10.5,
                  color: bypassCosts || stockpile.get(kind) >= amount
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
  ResourceKind.wool => GameIconData.wool,
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
