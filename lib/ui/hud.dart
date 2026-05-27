import 'package:flutter/material.dart';
import '../core/resources.dart';
import 'game_theme.dart';

class GameHUD extends StatelessWidget {
  // Ekonomi — köy stoğu (depoda + ateşte teslim edilmiş malzeme)
  final ResourceBundle stockpile;

  // Yolda olan / yerde duran kaynaklar (henüz teslim edilmemiş)
  final int woodInTransit;
  final int stoneInTransit;
  final int ironInTransit;
  final int coalInTransit;
  final int foodInTransit;

  // Nüfus & İşçiler
  final int villagerCount;
  final int farmerCount;
  final int woodcutterCount;
  final int minerCount;
  final int fisherCount;
  final int builderCount;
  final int busyBuilders;

  // Saat & Hava
  final double timeOfDay;
  final double rainIntensity;
  final double dayLight;

  // Bina
  final int buildingCount;
  final int pendingOrderCount;

  // Köy sağlığı
  final double morale;     // 0..1
  final bool   lowWater;   // dolu bir evin su deposu kritik seviyede mi
  final bool   starving;   // yiyecek stoğu kritik — açlık başladı

  // Diğer
  final VoidCallback onNewMap;

  const GameHUD({
    super.key,
    required this.stockpile,
    required this.woodInTransit,
    required this.stoneInTransit,
    required this.ironInTransit,
    required this.coalInTransit,
    required this.foodInTransit,
    required this.villagerCount,
    required this.farmerCount,
    required this.woodcutterCount,
    required this.minerCount,
    required this.fisherCount,
    required this.builderCount,
    required this.busyBuilders,
    required this.timeOfDay,
    required this.rainIntensity,
    required this.dayLight,
    required this.buildingCount,
    required this.pendingOrderCount,
    required this.morale,
    required this.lowWater,
    required this.starving,
    required this.onNewMap,
  });

  /// Moral rengi — yeşil (mutlu) → sarı → kırmızı (mutsuz).
  Color get _moraleColor => morale >= 0.6
      ? MedievalTheme.successColor
      : morale >= 0.4
          ? const Color(0xFFDDBB44)
          : MedievalTheme.dangerColor;

  String get _clockText {
    final hours = (timeOfDay * 24).floor() % 24;
    final minutes = ((timeOfDay * 24 - hours) * 60).floor();
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  String get _weatherIcon {
    if (rainIntensity > 0.5) return '☔';
    if (rainIntensity > 0.0) return '🌧';
    if (dayLight > 0.7) return '☀';
    if (dayLight > 0.3) return '🌅';
    return '🌙';
  }

  int get _totalPop =>
      villagerCount + farmerCount + woodcutterCount +
      minerCount + fisherCount + builderCount;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0, left: 0, right: 0,
      child: Container(
        decoration: BoxDecoration(
          color: MedievalTheme.panelBg,
          border: const Border(
            bottom: BorderSide(color: MedievalTheme.panelHighlight, width: 2),
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 10, offset: Offset(0, 3)),
          ],
        ),
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Satır 1: Nüfus, İşçi sayıları, İnşaat, Saat ──
                Row(
                  children: [
                    MedievalTheme.rivet(),
                    const SizedBox(width: 6),
                    _HudChip(icon: '♟', value: '$_totalPop', color: MedievalTheme.textPrimary),
                    const SizedBox(width: 5),
                    Tooltip(
                      message: 'Köy morali — kuyu/taverna yükseltir, '
                          'susuz evler düşürür',
                      child: _HudChip(
                        icon: '♥',
                        value: '${(morale * 100).round()}%',
                        color: _moraleColor,
                      ),
                    ),
                    const SizedBox(width: 5),
                    if (lowWater) ...[
                      Tooltip(
                        message: 'Evlerin su deposu boşalıyor — kuyu yapın',
                        child: _HudChip(
                          icon: '💧',
                          value: 'Susuz!',
                          color: MedievalTheme.dangerColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (starving) ...[
                      Tooltip(
                        message: 'Yiyecek tükeniyor — tarla/balıkçı üretimi artırın',
                        child: _HudChip(
                          icon: '🍞',
                          value: 'Açlık!',
                          color: MedievalTheme.dangerColor,
                        ),
                      ),
                      const SizedBox(width: 5),
                    ],
                    if (farmerCount > 0)
                      _MiniStat('⚘', farmerCount, const Color(0xFF88CC44)),
                    if (woodcutterCount > 0)
                      _MiniStat('⚒', woodcutterCount, const Color(0xFFCC8844)),
                    if (minerCount > 0)
                      _MiniStat('⛏', minerCount, const Color(0xFFAAAADD)),
                    if (fisherCount > 0)
                      _MiniStat('⚓', fisherCount, const Color(0xFF44AACC)),
                    const Spacer(),
                    if (pendingOrderCount > 0) ...[
                      _HudChip(
                        icon: '🔨',
                        value: '$busyBuilders/$pendingOrderCount',
                        color: const Color(0xFFFFAA44),
                      ),
                      const SizedBox(width: 5),
                    ],
                    _HudChip(icon: _weatherIcon, value: _clockText, color: const Color(0xFFAABBCC)),
                    const SizedBox(width: 6),
                    MedievalTheme.rivet(),
                  ],
                ),
                MedievalTheme.divider(),
                // ── Satır 2: Stockpile (tüm kaynaklar) + başlık + harita butonu ──
                Row(
                  children: [
                    const SizedBox(width: 6),
                    _ResStockChip(
                      kind: ResourceKind.wood,
                      stored: stockpile.wood,
                      inTransit: woodInTransit,
                      color: const Color(0xFFBB8844),
                    ),
                    _ResStockChip(
                      kind: ResourceKind.stone,
                      stored: stockpile.stone,
                      inTransit: stoneInTransit,
                      color: const Color(0xFFAAAAAA),
                    ),
                    _ResStockChip(
                      kind: ResourceKind.iron,
                      stored: stockpile.iron,
                      inTransit: ironInTransit,
                      color: const Color(0xFFCCCCEE),
                    ),
                    _ResStockChip(
                      kind: ResourceKind.coal,
                      stored: stockpile.coal,
                      inTransit: coalInTransit,
                      color: const Color(0xFF888888),
                    ),
                    _ResStockChip(
                      kind: ResourceKind.food,
                      stored: stockpile.food,
                      inTransit: foodInTransit,
                      color: const Color(0xFFDDAA22),
                    ),
                    _ResStockChip(
                      kind: ResourceKind.gold,
                      stored: stockpile.gold,
                      inTransit: 0,
                      color: MedievalTheme.textAccent,
                    ),
                    const Spacer(),
                    const Text('VILLAGE SIM', style: MedievalTheme.titleStyle),
                    const Spacer(),
                    GestureDetector(
                      onTap: onNewMap,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: MedievalTheme.buttonDecoration(),
                        child: const Text('↺ HARİTA', style: MedievalTheme.smallStyle),
                      ),
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ── Alt widgetlar ────────────────────────────────────────────────────────────

class _HudChip extends StatelessWidget {
  final String icon;
  final String value;
  final Color color;
  const _HudChip({required this.icon, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: MedievalTheme.chipDecoration(),
      child: Text('$icon $value',
          style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String icon;
  final int count;
  final Color color;
  const _MiniStat(this.icon, this.count, this.color);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Text('$icon$count',
          style: TextStyle(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.bold,
              fontFamily: 'monospace')),
    );
  }
}

/// Stoktaki kaynak + yolda olan miktar.
/// Stok = ana sayı, yoldaki miktar varsa "+N" şeklinde küçük gösterilir.
class _ResStockChip extends StatelessWidget {
  final ResourceKind kind;
  final int stored;
  final int inTransit;
  final Color color;
  const _ResStockChip({
    required this.kind,
    required this.stored,
    required this.inTransit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final isEmpty = stored == 0 && inTransit == 0;
    final textColor = stored > 0
        ? color
        : (inTransit > 0 ? color.withValues(alpha: 0.55) : color.withValues(alpha: 0.25));
    return Tooltip(
      message: '${kind.label}'
          '${inTransit > 0 ? '\nYolda: $inTransit' : ''}'
          '\nStokta: $stored',
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              kind.icon,
              style: TextStyle(
                fontSize: 12,
                color: isEmpty ? textColor.withValues(alpha: 0.4) : null,
              ),
            ),
            const SizedBox(width: 2),
            Text('$stored',
                style: TextStyle(
                  color: textColor,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace',
                )),
            if (inTransit > 0)
              Padding(
                padding: const EdgeInsets.only(left: 1),
                child: Text('+$inTransit',
                    style: TextStyle(
                      color: color.withValues(alpha: 0.55),
                      fontSize: 8,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'monospace',
                    )),
              ),
          ],
        ),
      ),
    );
  }
}
