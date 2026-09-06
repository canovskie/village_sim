import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../buildings/craft.dart';
import '../core/resources.dart';
import '../rendering/asset_style.dart';
import '../text/voice.dart';
import 'app_ui.dart';
import 'guide_spotlight.dart';
import 'mobile_ui.dart';

const _desktopRailHeight = 164.0;
const _desktopTileWidth = 164.0;
const _desktopTileHeight = 148.0;
const _compactRailHeight = 74.0;
const _compactTileWidth = 170.0;
const _compactTileHeight = 68.0;
const _expandedTileHeight = 104.0;

/// İnşa katalogu — masaüstünde görsel öncelikli yapı kartları, telefonda
/// okunabilir yatay seçim kayıtları.
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

  /// Köyün zanaat kilidi — false dönen bina katalogda soluk ve gerekçeli
  /// görünür, seçilemez. null = kilit yok (hepsi kurulabilir).
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
                    (category == null || kBuildingCategory[t] == category),
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
            // Mobil katalog ikon ızgarası değil, okunabilir yatay kayıtlar
            // kullanır. iPhone 11 yatayda iki sütun; gerçekten dar bir
            // viewport'ta tek sütun.
            final columns = width >= 620 ? 2 : 1;
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
              itemCount: types.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                crossAxisSpacing: 10,
                mainAxisSpacing: 8,
                mainAxisExtent: _expandedTileHeight,
              ),
              itemBuilder: (_, index) {
                final type = types[index];
                final unlocked = isUnlocked?.call(type) ?? true;
                return GuideTarget(
                  id: GuideAnchors.build(type.name),
                  child: _BuildingTile(
                    hinted: type == hintType,
                    type: type,
                    selected: selected == type,
                    stockpile: stockpile,
                    bypassCosts: bypassCosts,
                    unlocked: unlocked,
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
        height: _compactRailHeight,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
          itemCount: types.length,
          separatorBuilder: (_, _) => const SizedBox(width: 6),
          itemBuilder: (_, index) {
            final type = types[index];
            final unlocked = isUnlocked?.call(type) ?? true;
            return GuideTarget(
              id: GuideAnchors.build(type.name),
              child: _BuildingTile(
                hinted: type == hintType,
                type: type,
                selected: selected == type,
                stockpile: stockpile,
                bypassCosts: bypassCosts,
                unlocked: unlocked,
                compact: true,
                onTap: () => onSelect(type),
              ),
            );
          },
        ),
      );
    }

    final rail = SizedBox(
      height: _desktopRailHeight,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
        itemCount: types.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final type = types[index];
          final unlocked = isUnlocked?.call(type) ?? true;
          return GuideTarget(
            id: GuideAnchors.build(type.name),
            child: _BuildingTile(
              type: type,
              hinted: type == hintType,
              selected: selected == type,
              stockpile: stockpile,
              bypassCosts: bypassCosts,
              unlocked: unlocked,
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
        20.0 + types.length * _desktopTileWidth + (types.length - 1) * 8.0;
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
  final bool unlocked;
  final bool compact;
  final bool expanded;
  final bool Function() onTap;

  const _BuildingTile({
    required this.type,
    this.hinted = false,
    required this.selected,
    required this.stockpile,
    required this.bypassCosts,
    this.unlocked = true,
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
    final hasResources =
        widget.bypassCosts || widget.stockpile.canAfford(meta.cost);
    final unlocked = widget.unlocked;
    final canAfford = unlocked && hasResources;
    final craft = kBuildingCraft[widget.type];
    final lockReason = craft == null
        ? 'Henüz açılmadı'
        : '${Craft.displayName(craft)} gerekli';
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
      !unlocked
          ? ['{bina}, {boyut}; $lockReason']
          : canAfford
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
      !unlocked
          ? ['$lockReason · ${meta.label}']
          : canAfford
          ? const ['{bina} seç', '{bina} yapısını seç']
          : const ['{bina}: {eksik} eksik', '{bina} için eksik: {eksik}'],
      voice.copyWith(seed: widget.type.index + 31),
    );

    final stateTone = sel
        ? AppUi.accent
        : !unlocked
        ? AppUi.textLo
        : !hasResources
        ? AppUi.rust
        : null;
    final base = sel
        ? Color.alphaBlend(
            AppUi.accent.withValues(alpha: 0.075),
            AppUi.surface2,
          )
        : !unlocked
        ? AppUi.surface0
        : !hasResources
        ? Color.alphaBlend(AppUi.rust.withValues(alpha: 0.025), AppUi.surface1)
        : hot
        ? AppUi.surface3
        : AppUi.surface1;
    final bottom = sel
        ? Color.alphaBlend(AppUi.accent.withValues(alpha: 0.04), AppUi.surface1)
        : AppUi.surface0;

    final card = AnimatedContainer(
      key: ValueKey('building_tile_${widget.type.name}'),
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      width: expanded
          ? double.infinity
          : (compact ? _compactTileWidth : _desktopTileWidth),
      height: expanded
          ? double.infinity
          : (compact ? _compactTileHeight : _desktopTileHeight),
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
          color: stateTone?.withValues(alpha: sel ? 0.92 : 0.58) ?? AppUi.line,
          width: sel ? 1.4 : 1,
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          compact && !expanded
              ? _compactBody(
                  meta,
                  thumb,
                  hasResources,
                  sel,
                  unlocked,
                  lockReason,
                )
              : expanded
              ? _catalogBody(
                  meta,
                  thumb,
                  hasResources,
                  sel,
                  unlocked,
                  lockReason,
                )
              : _desktopBody(
                  meta,
                  thumb,
                  hasResources,
                  sel,
                  unlocked,
                  lockReason,
                ),
          // Durum, yuvarlatılmış dekorasyona non-uniform Border vermeden
          // ayrı bir yapısal şeritle okunur. Metinsel karşılığı bilgi
          // sütunundadır; renk tek başına anlam taşımaz.
          if (stateTone != null && (compact || expanded))
            Positioned(
              left: 0,
              top: 10,
              bottom: 10,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: stateTone,
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(2),
                  ),
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
              final accepted = unlocked && widget.onTap();
              // Tam ekran katalog yalnız sahne seçimi gerçekten kabul ettiyse
              // kapanır. Kaynak yetersizliği gibi retlerde oyuncu başka bir
              // kart seçebilmek için katalogda kalır.
              if (accepted) {
                const BuildCatalogCloseNotification().dispatch(context);
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
    bool canAfford,
    bool selected,
    bool unlocked,
    String lockReason,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 108,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, 0.18),
                radius: 0.92,
                colors: [AppUi.surface3, AppUi.surface1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
              child: Opacity(
                opacity: unlocked && canAfford
                    ? 1
                    : selected
                    ? 0.68
                    : 0.46,
                child: thumb != null
                    ? CustomPaint(painter: _ThumbPainter(thumb, widget.type))
                    : const Center(
                        child: GameIcon(
                          GameIconData.home,
                          size: 30,
                          color: AppUi.textMid,
                        ),
                      ),
              ),
            ),
          ),
        ),
        Container(
          width: 1,
          color: selected ? AppUi.accent.withValues(alpha: 0.42) : AppUi.line,
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(11, 8, 11, 8),
            child: _CatalogInfo(
              type: widget.type,
              meta: meta,
              selected: selected,
              canAfford: canAfford,
              unlocked: unlocked,
              lockReason: lockReason,
              stockpile: widget.stockpile,
              bypassCosts: widget.bypassCosts,
              roomy: true,
            ),
          ),
        ),
      ],
    );
  }

  /// Masaüstü kartı bir veri satırı değil, küçük bir yapı vitrini gibi okur:
  /// silüet üstte nefes alır; ad ve maliyet tek sakin bilgi bandında kalır.
  Widget _desktopBody(
    BuildingMeta meta,
    ui.Image? thumb,
    bool canAfford,
    bool selected,
    bool unlocked,
    String lockReason,
  ) {
    final tone = selected
        ? AppUi.accent
        : !unlocked
        ? AppUi.textLo
        : canAfford
        ? AppUi.textLo
        : AppUi.rust;
    return Stack(
      fit: StackFit.expand,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0.35),
                        radius: 0.88,
                        colors: selected
                            ? [
                                Color.alphaBlend(
                                  AppUi.accent.withValues(alpha: 0.13),
                                  AppUi.surface3,
                                ),
                                AppUi.surface1,
                              ]
                            : [AppUi.surface3, AppUi.surface1],
                      ),
                    ),
                  ),
                  Positioned(
                    left: 20,
                    right: 20,
                    bottom: 8,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.transparent,
                            tone.withValues(alpha: selected ? 0.42 : 0.18),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 13, 22, 8),
                    child: Opacity(
                      opacity: unlocked && canAfford
                          ? 1
                          : selected
                          ? 0.68
                          : 0.42,
                      child: thumb != null
                          ? CustomPaint(
                              painter: _ThumbPainter(thumb, widget.type),
                            )
                          : const Center(
                              child: GameIcon(
                                GameIconData.home,
                                size: 30,
                                color: AppUi.textMid,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 64,
              padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
              decoration: BoxDecoration(
                color: selected
                    ? Color.alphaBlend(
                        AppUi.accent.withValues(alpha: 0.07),
                        AppUi.surface0,
                      )
                    : AppUi.surface0,
                border: const Border(top: BorderSide(color: AppUi.line)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    meta.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                      fontSize: 11.5,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: selected ? AppUi.accentSoft : AppUi.textHi,
                    ),
                  ),
                  const Spacer(),
                  if (unlocked)
                    _CostStrip(
                      cost: meta.cost,
                      stockpile: widget.stockpile,
                      bypassCosts: widget.bypassCosts,
                    )
                  else
                    Text(
                      lockReason,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.label.copyWith(
                        fontSize: 8,
                        color: AppUi.textLo,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        Positioned(
          top: 8,
          right: 8,
          child: _FootprintPill(cols: meta.cols, rows: meta.rows),
        ),
        if (selected || !canAfford || !unlocked)
          Positioned(
            top: 8,
            left: 8,
            child: KeyedSubtree(
              key: ValueKey('building_state_${widget.type.name}'),
              child: _DesktopStatePill(
                selected: selected,
                insufficient: unlocked && !canAfford,
                locked: !unlocked,
              ),
            ),
          ),
      ],
    );
  }

  Widget _compactBody(
    BuildingMeta meta,
    ui.Image? thumb,
    bool canAfford,
    bool selected,
    bool unlocked,
    String lockReason,
  ) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 58,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                colors: [AppUi.surface3, AppUi.surface1],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 7, 8, 6),
              child: Opacity(
                opacity: unlocked && canAfford
                    ? 1
                    : selected
                    ? 0.68
                    : 0.46,
                child: thumb != null
                    ? CustomPaint(painter: _ThumbPainter(thumb, widget.type))
                    : const Center(
                        child: GameIcon(
                          GameIconData.home,
                          size: 20,
                          color: AppUi.textMid,
                        ),
                      ),
              ),
            ),
          ),
        ),
        Container(width: 1, color: AppUi.line),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 6, 7, 6),
            child: _CatalogInfo(
              type: widget.type,
              meta: meta,
              selected: selected,
              canAfford: canAfford,
              unlocked: unlocked,
              lockReason: lockReason,
              stockpile: widget.stockpile,
              bypassCosts: widget.bypassCosts,
              compact: true,
            ),
          ),
        ),
      ],
    );
  }
}

class _CatalogInfo extends StatelessWidget {
  final BuildingType type;
  final BuildingMeta meta;
  final bool selected;
  final bool canAfford;
  final bool unlocked;
  final String lockReason;
  final ResourceBundle stockpile;
  final bool bypassCosts;
  final bool roomy;
  final bool compact;

  const _CatalogInfo({
    required this.type,
    required this.meta,
    required this.selected,
    required this.canAfford,
    required this.unlocked,
    required this.lockReason,
    required this.stockpile,
    required this.bypassCosts,
    this.roomy = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasState = selected || !canAfford || !unlocked;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (hasState)
              Expanded(
                child: KeyedSubtree(
                  key: ValueKey('building_state_${type.name}'),
                  child: _BuildingStateLabel(
                    selected: selected,
                    insufficient: unlocked && !canAfford,
                    locked: !unlocked,
                    compact: compact,
                    roomy: roomy,
                  ),
                ),
              )
            else
              const Spacer(),
            const SizedBox(width: 6),
            _FootprintLabel(cols: meta.cols, rows: meta.rows, roomy: roomy),
          ],
        ),
        SizedBox(height: compact ? 3 : 5),
        Text(
          meta.label,
          maxLines: compact ? 1 : 2,
          overflow: TextOverflow.ellipsis,
          style: AppUi.body.copyWith(
            fontSize: roomy ? 13 : (compact ? 10.5 : 11.5),
            height: 1.04,
            fontWeight: FontWeight.w700,
            color: selected ? AppUi.accentSoft : AppUi.textHi,
          ),
        ),
        const Spacer(),
        Align(
          alignment: Alignment.bottomLeft,
          child: unlocked
              ? _CostStrip(
                  cost: meta.cost,
                  stockpile: stockpile,
                  bypassCosts: bypassCosts,
                  compact: roomy || compact,
                )
              : Text(
                  lockReason,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppUi.label.copyWith(
                    fontSize: roomy ? 9 : 8,
                    color: AppUi.textLo,
                  ),
                ),
        ),
      ],
    );
  }
}

class _FootprintLabel extends StatelessWidget {
  final int cols;
  final int rows;
  final bool roomy;

  const _FootprintLabel({
    required this.cols,
    required this.rows,
    required this.roomy,
  });

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        'ALAN',
        maxLines: 1,
        style: AppUi.label.copyWith(
          fontSize: roomy ? 7.5 : 7,
          height: 1,
          letterSpacing: 0.55,
          color: AppUi.textLo,
        ),
      ),
      const SizedBox(width: 3),
      Text(
        '$cols×$rows',
        maxLines: 1,
        style: AppUi.number.copyWith(
          fontSize: roomy ? 10.5 : 9.5,
          height: 1,
          color: AppUi.textMid,
        ),
      ),
    ],
  );
}

class _FootprintPill extends StatelessWidget {
  final int cols;
  final int rows;

  const _FootprintPill({required this.cols, required this.rows});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
    decoration: BoxDecoration(
      color: AppUi.surface0.withValues(alpha: 0.86),
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: AppUi.line),
    ),
    child: Text(
      '$cols×$rows',
      style: AppUi.number.copyWith(
        fontSize: 9.5,
        height: 1,
        color: AppUi.textMid,
      ),
    ),
  );
}

class _DesktopStatePill extends StatelessWidget {
  final bool selected;
  final bool insufficient;
  final bool locked;

  const _DesktopStatePill({
    required this.selected,
    required this.insufficient,
    required this.locked,
  });

  @override
  Widget build(BuildContext context) {
    final tone = locked
        ? AppUi.textLo
        : selected
        ? AppUi.accent
        : AppUi.rust;
    Text label(String text, Color color) => Text(
      text,
      maxLines: 1,
      style: AppUi.label.copyWith(
        fontSize: 7.5,
        height: 1,
        letterSpacing: 0.55,
        color: color,
      ),
    );
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: Color.alphaBlend(
          tone.withValues(alpha: 0.18),
          AppUi.surface0.withValues(alpha: 0.92),
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tone.withValues(alpha: 0.58)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (locked) label('KİLİTLİ', AppUi.textMid),
          if (!locked && selected) label('SEÇİLİ', AppUi.accentSoft),
          if (!locked && selected && insufficient) ...[
            const SizedBox(width: 4),
            label('EKSİK', AppUi.rust),
          ] else if (!locked && !selected)
            label('EKSİK', AppUi.rust),
        ],
      ),
    );
  }
}

class _BuildingStateLabel extends StatelessWidget {
  final bool selected;
  final bool insufficient;
  final bool locked;
  final bool compact;
  final bool roomy;

  const _BuildingStateLabel({
    required this.selected,
    required this.insufficient,
    required this.locked,
    required this.compact,
    required this.roomy,
  });

  @override
  Widget build(BuildContext context) {
    Text stateText(String label, Color tone) => Text(
      label,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppUi.label.copyWith(
        fontSize: compact ? 7.5 : 8,
        height: 1,
        letterSpacing: compact ? 0.5 : 0.65,
        color: tone,
      ),
    );

    if (locked) return stateText('KİLİTLİ', AppUi.textLo);
    if (!selected) return stateText('EKSİK', AppUi.rust);
    if (!insufficient) return stateText('SEÇİLİ', AppUi.accent);

    // Masaüstü bilgi sütunu dar; iki durum alt alta durur. Geniş mobil
    // kayıtta aynı iki sözcük tek satırda okunabilir.
    final states = [
      stateText('SEÇİLİ', AppUi.accent),
      stateText('EKSİK', AppUi.rust),
    ];
    if (roomy) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [states.first, const SizedBox(width: 6), states.last],
      );
    }
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [states.first, const SizedBox(height: 2), states.last],
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
      alignment: WrapAlignment.start,
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
                color: bypassCosts || stockpile.get(kind) >= amount
                    ? AppUi.textLo
                    : AppUi.rust,
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
  final BuildingType type;
  _ThumbPainter(this.img, this.type);

  static final _paint = AssetStyle.paint();

  @override
  void paint(Canvas canvas, Size size) {
    final src = BuildingRenderer.thumbnailSourceRect(type, img);
    final sw = src.width;
    final sh = src.height;
    final scale = (sw / sh > size.width / size.height)
        ? size.width / sw
        : size.height / sh;
    final w = sw * scale;
    final h = sh * scale;
    final left = (size.width - w) / 2;
    final top = size.height - h;
    canvas.drawImageRect(img, src, Rect.fromLTWH(left, top, w, h), _paint);
  }

  @override
  bool shouldRepaint(_ThumbPainter old) => old.img != img || old.type != type;
}
