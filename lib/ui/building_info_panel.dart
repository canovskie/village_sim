import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_function.dart';
import '../buildings/building_renderer.dart';
import '../buildings/building_type.dart';
import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../core/resources.dart';
import '../entities/villager_entity.dart';
import '../entities/miner_entity.dart';
import '../rendering/asset_style.dart';
import '../systems/building_system.dart';
import 'game_theme.dart';

/// Bir binaya tıklanınca açılan zengin yönetim/detay paneli.
/// Binanın rolüne göre farklı gövde gösterir; satış aksiyonunu [onSell] ile
/// üst katmana iletir.
class BuildingInfoPanel extends StatelessWidget {
  final BuildingEntity building;
  final List<VillagerEntity> residents;
  final List<MinerEntity> activeMiners;
  final ResourceBundle stockpile;
  final VillageStats stats;

  /// Köyün toplam nüfusu ve ev tavanı (belediye gövdesi için).
  final int population;
  final int populationCap;

  final VoidCallback onClose;
  final void Function(ResourceKind kind) onSell;

  const BuildingInfoPanel({
    super.key,
    required this.building,
    required this.residents,
    required this.activeMiners,
    required this.stockpile,
    required this.stats,
    required this.population,
    required this.populationCap,
    required this.onClose,
    required this.onSell,
  });

  BuildingFunction? get _fn => building.fn;
  Color get _accent => _accentFor(_fn);

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[building.type]!;
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: MedievalTheme.panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(meta.label),
          if (_fn != null && _fn!.summary.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 7, 12, 3),
              child: Text(
                _fn!.summary,
                style: const TextStyle(
                  color: MedievalTheme.textSecondary,
                  fontSize: 9.5,
                  height: 1.3,
                  fontFamily: 'monospace',
                ),
              ),
            ),
          MedievalTheme.divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(2, 2, 2, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: _body(_fn),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Başlık ────────────────────────────────────────────────────────────────

  Widget _header(String label) {
    final thumb = BuildingRenderer.thumbnails[building.type];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MedievalTheme.panelBgLight, MedievalTheme.panelBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: MedievalTheme.panelHighlight, width: 1),
        ),
      ),
      child: Row(
        children: [
          // Bina portresi — çerçeveli kutu
          Container(
            width: 42,
            height: 32,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: MedievalTheme.chipBg,
              border: Border.all(color: MedievalTheme.chipBorder, width: 1),
            ),
            child: thumb != null
                ? CustomPaint(painter: _ThumbPainter(thumb))
                : const Center(
                    child: Text('⌂',
                        style: TextStyle(fontSize: 20, color: MedievalTheme.textPrimary)),
                  ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: MedievalTheme.titleStyle, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                _roleTag(),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: MedievalTheme.chipDecoration(),
              child: const Text('✕',
                  style: TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleTag() {
    final (label, _) = _roleLabel(_fn);
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: Color.alphaBlend(_accent.withValues(alpha: 0.18), MedievalTheme.chipBg),
        border: Border.all(color: _accent.withValues(alpha: 0.6), width: 1),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
            color: _accent,
            fontSize: 8,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            letterSpacing: 1.0,
          )),
    );
  }

  // ─── Role özgü gövde ─────────────────────────────────────────────────────────

  List<Widget> _body(BuildingFunction? fn) {
    if (fn == null) return [_stat('Boyut', '${building.cols}×${building.rows}')];
    switch (fn.role) {
      case BuildingRole.housing:
        return _housingBody(fn);
      case BuildingRole.gathering:
        return _gatheringBody();
      case BuildingRole.processing:
        return _processingBody(fn);
      case BuildingRole.trade:
        return _tradeBody(fn);
      case BuildingRole.storage:
        return _storageBody(fn);
      case BuildingRole.civic:
        return _civicBody(fn);
      case BuildingRole.none:
        return [_stat('Boyut', '${building.cols}×${building.rows}')];
    }
  }

  // ── Ev ──
  List<Widget> _housingBody(BuildingFunction fn) {
    final water = building.waterLevel.clamp(0.0, 1.0);
    return [
      _stat('Sakinler', '${residents.length} / ${fn.housingCapacity}',
          valueColor: residents.length >= fn.housingCapacity
              ? MedievalTheme.successColor
              : MedievalTheme.textPrimary),
      if (residents.isNotEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 4),
          child: Wrap(
            spacing: 5,
            runSpacing: 4,
            children: residents.map(_residentChip).toList(),
          ),
        )
      else
        _hint('Boş — belediye yeni köylüler yerleştirecek.'),
      _sectionLabel('Su deposu'),
      _progress(
        water,
        water > 0.66
            ? 'Su deposu dolu'
            : water > 0.25
                ? 'Su azalıyor — kuyu gerekli'
                : 'Susuz — sakinler mutsuz, moral düşer',
        color: const Color(0xFF5BA6D8),
      ),
    ];
  }

  // ── Toplama (oduncu / maden / balıkçı) ──
  List<Widget> _gatheringBody() {
    final isMine = building.type == BuildingType.mineBuilding;
    return [
      _statusRow(building.isActive),
      if (isMine && activeMiners.isNotEmpty)
        _stat('Madenci', '${activeMiners.length} içeride'),
      _hint(switch (building.type) {
        BuildingType.lumberCamp => 'Bölgesindeki ağaçları odun olarak toplar.',
        BuildingType.mineBuilding => 'Damardan taş / demir / kömür çıkarır.',
        BuildingType.fisherCabin => 'Sudan balık tutar, yiyecek üretir.',
        _ => '',
      }),
    ];
  }

  // ── İşleme (değirmen) — tarladan gelen balyaların verimini artırır. ──
  List<Widget> _processingBody(BuildingFunction fn) => [
        _statusRow(true),
        _stat('Balya verimi', '+1${ResourceKind.food.icon} / balya',
            valueColor: MedievalTheme.successColor),
        _hint('Tarladan depoya gelen her balya öğütülür → +1 fazla yiyecek.'),
      ];

  // ── Ticaret (pazar) ──
  List<Widget> _tradeBody(BuildingFunction fn) {
    return [
      _stat('Kasa', '${stockpile.gold} ${ResourceKind.gold.icon}',
          valueColor: MedievalTheme.textAccent),
      _stat('Pasif gelir',
          '+${fn.civicValue.round()}${ResourceKind.gold.icon} / ${kMarketIncomeInterval.toStringAsFixed(0)}sn'),
      _sectionLabel('Kaynak sat'),
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 2, 8, 5),
        child: Wrap(
          spacing: 5,
          runSpacing: 5,
          children: [
            for (final e in kMarketSellRates.entries)
              _SellButton(
                kind: e.key,
                batch: e.value.$1,
                gold: e.value.$2,
                enabled: stockpile.get(e.key) >= e.value.$1,
                onTap: () => onSell(e.key),
              ),
          ],
        ),
      ),
    ];
  }

  // ── Depo ──
  List<Widget> _storageBody(BuildingFunction fn) {
    return [
      _stat('Bu deponun katkısı', '+${fn.storageCapacity}'),
      _stat('Köy kapasitesi', '${stats.stockCapacity} / kaynak',
          valueColor: MedievalTheme.textAccent),
      _sectionLabel('Doluluk'),
      Padding(
        padding: const EdgeInsets.fromLTRB(10, 2, 10, 5),
        child: _CapacityBars(stockpile: stockpile, cap: stats.stockCapacity),
      ),
    ];
  }

  // ── Civic (belediye / kuyu / taverna / ahır) ──
  List<Widget> _civicBody(BuildingFunction fn) {
    switch (fn.civicEffect) {
      case CivicEffect.populationGrowth:
        final ready = stockpile.food >= kPopulationGrowthFoodFloor;
        final hasRoom = population < populationCap;
        return [
          _stat('Nüfus', '$population / $populationCap',
              valueColor: hasRoom ? MedievalTheme.textPrimary : MedievalTheme.dangerColor),
          _stat('Köy morali', '${(stats.morale * 100).round()}%',
              valueColor: stats.morale >= 0.6
                  ? MedievalTheme.successColor
                  : MedievalTheme.textPrimary),
          _stat('Köylü maliyeti', '$kPopulationGrowthFoodCost${ResourceKind.food.icon}'),
          _progress(
            building.growthProgress.clamp(0.0, 1.0),
            !hasRoom
                ? 'Ev gerekli — büyüme durdu'
                : !ready
                    ? 'Yiyecek gerekli ($kPopulationGrowthFoodFloor${ResourceKind.food.icon})'
                    : 'Yeni köylü yetişiyor…',
          ),
        ];
      case CivicEffect.morale:
        return [
          _stat('Moral katkısı', '+${(fn.civicValue * 100).round()}%',
              valueColor: MedievalTheme.successColor),
          _stat('Köy morali', '${(stats.morale * 100).round()}%'),
          if (building.type == BuildingType.well)
            _hint('Evlerin su deposunu doldurur, çiftçiler ekinleri sular.'),
          _progress(stats.morale, 'Mutlu köy daha hızlı büyür'),
        ];
      case CivicEffect.carrierSpeed:
        return [
          _stat('Bu ahrın katkısı', '+${(fn.civicValue * 100).round()}%'),
          _stat('Taşıyıcı hızı', '×${stats.carrierSpeedMultiplier.toStringAsFixed(2)}',
              valueColor: MedievalTheme.successColor),
          _hint('Köylüler kaynakları daha hızlı taşır.'),
        ];
      case CivicEffect.none:
        return [_stat('Boyut', '${building.cols}×${building.rows}')];
    }
  }

  // ─── Ortak küçük widgetlar ────────────────────────────────────────────────────

  /// İkon + etiket + değer satırı; zebra bantlı arka plan.
  Widget _stat(String label, String value, {Color? valueColor}) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1.5),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: MedievalTheme.chipBg.withValues(alpha: 0.45),
          border: Border(left: BorderSide(color: _accent.withValues(alpha: 0.5), width: 2)),
        ),
        child: Row(
          children: [
            Text(label,
                style: const TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace')),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? MedievalTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ],
        ),
      );

  Widget _statusRow(bool active) => _stat(
        'Durum',
        active ? '⚙ Çalışıyor' : '💤 Boşta',
        valueColor: active ? MedievalTheme.successColor : MedievalTheme.textSecondary,
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(11, 6, 10, 1),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                color: MedievalTheme.textDim,
                fontSize: 8,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
                fontFamily: 'monospace')),
      );

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(11, 3, 11, 4),
        child: Text(text,
            style: const TextStyle(
                color: MedievalTheme.textDim,
                fontSize: 9,
                fontStyle: FontStyle.italic,
                fontFamily: 'monospace')),
      );

  Widget _progress(double value, String label, {Color? color}) => Padding(
        padding: const EdgeInsets.fromLTRB(10, 4, 10, 5),
        child: _ProgressBar(value: value, color: color ?? _accent, label: label),
      );

  Widget _residentChip(VillagerEntity v) {
    final stage = v.lifeStage;
    final label = v.hasProfession ? v.type.displayName : stage.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: MedievalTheme.chipDecoration(),
      child: Text('${stage.icon} $label',
          style: const TextStyle(
              color: MedievalTheme.textPrimary,
              fontSize: 9,
              fontFamily: 'monospace')),
    );
  }
}

// ─── Renk + etiket eşlemeleri ──────────────────────────────────────────────────

Color _accentFor(BuildingFunction? fn) {
  if (fn == null) return MedievalTheme.panelHighlight;
  switch (fn.role) {
    case BuildingRole.housing:
      return const Color(0xFF88BB55);
    case BuildingRole.gathering:
      return const Color(0xFFD08840);
    case BuildingRole.processing:
      return const Color(0xFFDDAA22);
    case BuildingRole.trade:
      return const Color(0xFFE0C040);
    case BuildingRole.storage:
      return const Color(0xFFB08850);
    case BuildingRole.civic:
      return switch (fn.civicEffect) {
        CivicEffect.populationGrowth => const Color(0xFF6ABB44),
        CivicEffect.morale => const Color(0xFFE08855),
        CivicEffect.carrierSpeed => const Color(0xFF66A0CC),
        CivicEffect.none => MedievalTheme.panelHighlight,
      };
    case BuildingRole.none:
      return MedievalTheme.panelHighlight;
  }
}

(String, Color) _roleLabel(BuildingFunction? fn) {
  if (fn == null) return ('', MedievalTheme.panelHighlight);
  final c = _accentFor(fn);
  switch (fn.role) {
    case BuildingRole.housing:
      return ('Ev', c);
    case BuildingRole.gathering:
      return ('Üretim', c);
    case BuildingRole.processing:
      return ('İşleme', c);
    case BuildingRole.trade:
      return ('Ticaret', c);
    case BuildingRole.storage:
      return ('Depo', c);
    case BuildingRole.civic:
      return switch (fn.civicEffect) {
        CivicEffect.populationGrowth => ('Yönetim', c),
        CivicEffect.morale => ('Moral', c),
        CivicEffect.carrierSpeed => ('Lojistik', c),
        CivicEffect.none => ('', c),
      };
    case BuildingRole.none:
      return ('', c);
  }
}

// ─── İlerleme çubuğu (gradient) ────────────────────────────────────────────────

class _ProgressBar extends StatelessWidget {
  final double value; // 0..1
  final Color color;
  final String label;
  const _ProgressBar({required this.value, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 10,
          decoration: BoxDecoration(
            color: MedievalTheme.chipBg,
            border: Border.all(color: MedievalTheme.chipBorder, width: 1),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: value.clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [
                  Color.lerp(color, Colors.black, 0.25)!,
                  color,
                  Color.lerp(color, Colors.white, 0.35)!,
                ]),
              ),
            ),
          ),
        ),
        const SizedBox(height: 3),
        Text(label,
            style: const TextStyle(
                color: MedievalTheme.textDim,
                fontSize: 8.5,
                fontFamily: 'monospace')),
      ],
    );
  }
}

// ─── Kapasite çubukları (depo) ──────────────────────────────────────────────────

class _CapacityBars extends StatelessWidget {
  final ResourceBundle stockpile;
  final int cap;
  const _CapacityBars({required this.stockpile, required this.cap});

  @override
  Widget build(BuildContext context) {
    const kinds = [
      (ResourceKind.wood, Color(0xFFBB8844)),
      (ResourceKind.stone, Color(0xFFAAAAAA)),
      (ResourceKind.iron, Color(0xFFCCCCEE)),
      (ResourceKind.coal, Color(0xFF888888)),
      (ResourceKind.food, Color(0xFFDDAA22)),
    ];
    return Column(
      children: [
        for (final (kind, color) in kinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 3),
            child: Row(
              children: [
                SizedBox(width: 16, child: Text(kind.icon, style: const TextStyle(fontSize: 11))),
                Expanded(
                  child: Container(
                    height: 7,
                    decoration: BoxDecoration(
                      color: MedievalTheme.chipBg,
                      border: Border.all(color: MedievalTheme.chipBorder, width: 1),
                    ),
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: (stockpile.get(kind) / cap).clamp(0.0, 1.0),
                      child: Container(color: color),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 30,
                  child: Text('${stockpile.get(kind)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          color: MedievalTheme.textSecondary,
                          fontSize: 9,
                          fontFamily: 'monospace')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Satış butonu (pazar) ─────────────────────────────────────────────────────

class _SellButton extends StatelessWidget {
  final ResourceKind kind;
  final int batch;
  final int gold;
  final bool enabled;
  final VoidCallback onTap;
  const _SellButton({
    required this.kind,
    required this.batch,
    required this.gold,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: MedievalTheme.buttonDecoration(
            active: enabled,
            accentColor: const Color(0xFFE0C040),
          ),
          child: Text('$batch${kind.icon} → $gold${ResourceKind.gold.icon}',
              style: const TextStyle(
                  color: MedievalTheme.textPrimary,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'monospace')),
        ),
      ),
    );
  }
}

// ─── Thumbnail painter (başlık) ────────────────────────────────────────────────

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
