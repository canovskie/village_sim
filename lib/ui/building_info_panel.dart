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
import '../entities/shepherd_entity.dart';
import '../world/animal_entity.dart';
import '../rendering/asset_style.dart';
import '../scene/scene_data.dart';
import '../systems/building_system.dart';
import 'app_ui.dart';

/// Bir binaya tıklanınca açılan yönetim kartı. Modern koyu panel: başlık +
/// portre, animasyonlu durum çubukları, vektör ikonlu aksiyon butonları.
/// Stat dump değil — bir karar masası gibi reaktif davranır.
class BuildingInfoPanel extends StatelessWidget {
  final BuildingEntity building;
  final List<VillagerEntity> residents;
  final List<MinerEntity> activeMiners;
  final List<AnimalEntity> barnCows;
  final ShepherdEntity? barnShepherd;
  final ResourceBundle stockpile;
  final VillageStats stats;

  final int population;
  final int populationCap;

  final VoidCallback onClose;
  final void Function(ResourceKind kind) onSell;

  final VoidCallback? onFestival;
  final VoidCallback? onDemolish;
  /// Taşı — binayı söküp aynı türü yeniden yerleştirmeye sokar (tam iade,
  /// bedava taşıma). Yık'ın kardeşi.
  final VoidCallback? onMove;
  final VoidCallback? onTogglePaused;
  final VoidCallback? onCollectTax;
  final VoidCallback? onRefillWater;
  /// Ahır/kümes hayvan satın alma — bina boş kurulur, sürü buradan kurulur.
  final void Function(AnimalKind kind)? onBuyAnimal;

  final int festivalFoodCost;
  final int festivalGoldCost;

  final PopulationPlanning? planning;

  /// Divan'ı aç — YÖNETİŞİM (Karar Defteri + hane nabzı) 2026-07-13'te bu
  /// panelden Divan'a taşındı; belediye yönetişimin koltuğu olduğu için burada
  /// yalnızca oraya açılan bir kapı kalır. null = kapı gösterilmez.
  final VoidCallback? onOpenDivan;

  const BuildingInfoPanel({
    super.key,
    required this.building,
    required this.residents,
    required this.activeMiners,
    this.barnCows = const [],
    this.barnShepherd,
    required this.stockpile,
    required this.stats,
    required this.population,
    required this.populationCap,
    required this.onClose,
    required this.onSell,
    this.onFestival,
    this.onDemolish,
    this.onMove,
    this.onTogglePaused,
    this.onCollectTax,
    this.onRefillWater,
    this.onBuyAnimal,
    this.festivalFoodCost = 8,
    this.festivalGoldCost = 5,
    this.planning,
    this.onOpenDivan,
  });

  BuildingFunction? get _fn => building.fn;
  Color get _accent => _accentFor(_fn);

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[building.type]!;
    return GestureDetector(
      onTap: () {},
      behavior: HitTestBehavior.opaque,
      child: AppReveal(
        child: SizedBox(
          width: 326,
          child: AppPanel(
            accent: _accent,
            padding: EdgeInsets.zero,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _header(meta.label),
                Container(height: 1, color: AppUi.line),
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ..._vital(_fn),
                        if (_actions().isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _actionStrip(),
                        ],
                        if (_fn?.summary.isNotEmpty == true) ...[
                          const SizedBox(height: 12),
                          Text(_fn!.summary,
                              style: AppUi.body.copyWith(
                                  color: AppUi.textLo,
                                  fontStyle: FontStyle.italic)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── Başlık ───────────────────────────────────────────────────────────────

  Widget _header(String label) {
    final thumb = BuildingRenderer.thumbnails[building.type];
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          // Portre
          Container(
            width: 46,
            height: 38,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppUi.surface0,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppUi.line, width: 1),
            ),
            child: thumb != null
                ? CustomPaint(painter: _ThumbPainter(thumb))
                : Center(
                    child: GameIcon(GameIconData.home,
                        size: 20, color: AppUi.textMid)),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: AppUi.title.copyWith(fontSize: 15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 5),
                _roleTag(),
              ],
            ),
          ),
          const SizedBox(width: 6),
          AppIconButton(
            icon: GameIconData.close,
            size: 26,
            onTap: onClose,
          ),
        ],
      ),
    );
  }

  Widget _roleTag() {
    final label = _roleLabel(_fn);
    if (label.isEmpty) return const SizedBox.shrink();
    return AppChip(label: label.toUpperCase(), color: _accent);
  }

  // ─── Vital ──────────────────────────────────────────────────────────────

  List<Widget> _vital(BuildingFunction? fn) {
    if (fn == null) {
      return [_row('Boyut', '${building.cols}×${building.rows}')];
    }
    switch (fn.role) {
      case BuildingRole.housing:
        return _housingVital(fn);
      case BuildingRole.gathering:
        return _gatheringVital();
      case BuildingRole.processing:
        return _processingVital();
      case BuildingRole.trade:
        return _tradeVital(fn);
      case BuildingRole.storage:
        return _storageVital(fn);
      case BuildingRole.civic:
        return _civicVital(fn);
      case BuildingRole.none:
        return [_row('Boyut', '${building.cols}×${building.rows}')];
    }
  }

  List<Widget> _housingVital(BuildingFunction fn) {
    final water = building.waterLevel.clamp(0.0, 1.0);
    final occ = residents.length / fn.housingCapacity.clamp(1, 99);
    return [
      AppStatBar(
        label: 'SAKİNLER',
        value: occ,
        trailing: '${residents.length}/${fn.housingCapacity}',
        color: residents.length >= fn.housingCapacity ? AppUi.sage : AppUi.accent,
      ),
      const SizedBox(height: 8),
      AppStatBar(
        label: 'SU DEPOSU',
        value: water,
        trailing: '${(water * 100).round()}%',
        color: water > 0.5
            ? AppUi.info
            : water > 0.25
                ? AppUi.accentSoft
                : AppUi.rust,
      ),
      if (residents.isNotEmpty) ...[
        const SizedBox(height: 12),
        _residentRow(),
      ],
    ];
  }

  List<Widget> _gatheringVital() {
    final isMine = building.type == BuildingType.mineBuilding;
    final isBarn = building.type == BuildingType.barn;
    final isCoop = building.type == BuildingType.chickenCoop;
    final out = <Widget>[_statusRow(building.isActive)];
    if (isMine && activeMiners.isNotEmpty) {
      out.add(_row('Madenci', '${activeMiners.length} içeride'));
    }
    if (isBarn) out.addAll(_barnVital());
    if (isCoop) out.addAll(_coopVital());
    return out;
  }

  /// Bu binadaki yaşayan hayvan sayısı (tür bazlı).
  int _countKind(AnimalKind k) =>
      barnCows.where((c) => !c.isDying && c.kind == k).length;

  List<Widget> _barnVital() {
    final cows = barnCows.where((c) => c.kind == AnimalKind.cow).toList();
    final out = <Widget>[
      const SizedBox(height: 6),
      _row('İnek', '${_countKind(AnimalKind.cow)} baş'),
      _row('Koyun', '${_countKind(AnimalKind.sheep)} baş'),
    ];
    if (cows.isNotEmpty) {
      final avgFull =
          1.0 - (cows.fold<double>(0, (s, c) => s + c.hunger) / cows.length);
      final readyCount = cows.where((c) => c.readyToMilk).length;
      out.addAll([
        const SizedBox(height: 6),
        AppStatBar(
            label: 'TOKLUK',
            value: avgFull,
            trailing: '${(avgFull * 100).round()}%',
            color: AppUi.sage),
        const SizedBox(height: 6),
        _row('Sağıma hazır', '$readyCount'),
      ]);
    }
    out.addAll(_buyButtons(const [AnimalKind.cow, AnimalKind.sheep]));
    return out;
  }

  List<Widget> _coopVital() {
    final hens = barnCows
        .where((c) => c.kind == AnimalKind.chicken && !c.isMale && !c.isDying)
        .length;
    return [
      const SizedBox(height: 6),
      _row('Tavuk', '${_countKind(AnimalKind.chicken)}'),
      _row('Yumurtlayan', '$hens'),
      ..._buyButtons(const [AnimalKind.chicken]),
    ];
  }

  /// Hayvan satın alma butonları — bina boş kurulur, sürü buradan kurulur.
  /// Maliyet/kapasite gösterilir; dolu/yetersizse buton soluk (yine de basınca
  /// sahne nedeni bildirir).
  List<Widget> _buyButtons(List<AnimalKind> kinds) {
    if (onBuyAnimal == null) return const [];
    final out = <Widget>[const SizedBox(height: 10)];
    for (final k in kinds) {
      final count = _countKind(k);
      final cap = kAnimalBarnCap[k] ?? 5;
      final cost = kAnimalGoldCost[k] ?? 5;
      final full = count >= cap;
      final afford = stockpile.gold >= cost;
      out.add(Padding(
        padding: const EdgeInsets.only(top: 6),
        child: AppButton(
          label: full
              ? '${animalKindLabel(k)} dolu ($count/$cap)'
              : '${animalKindLabel(k)} al · $cost★   ($count/$cap)',
          kind: (full || !afford) ? AppButtonKind.ghost : AppButtonKind.tonal,
          onTap: (full || !afford) ? null : () => onBuyAnimal!(k),
        ),
      ));
    }
    return out;
  }

  List<Widget> _processingVital() => [
        _statusRow(building.isActive),
        const SizedBox(height: 6),
        _row('Balya verimi', '+2 yem / balya', icon: GameIconData.wheat),
      ];

  List<Widget> _tradeVital(BuildingFunction fn) => [
        _row('Kasa', '${stockpile.gold}',
            icon: GameIconData.coin, accent: true),
        const SizedBox(height: 6),
        _row('Pasif gelir',
            '+${fn.civicValue.round()} / ${kMarketIncomeInterval.toStringAsFixed(0)}sn'),
      ];

  List<Widget> _storageVital(BuildingFunction fn) {
    return [
      _row('Bu deponun katkısı', '+${fn.storageCapacity}'),
      const SizedBox(height: 6),
      _row('Köy kapasitesi', '${stats.stockCapacity}/kaynak', accent: true),
      const SizedBox(height: 12),
      _CapacityBars(stockpile: stockpile, cap: stats.stockCapacity),
    ];
  }

  List<Widget> _civicVital(BuildingFunction fn) {
    switch (fn.civicEffect) {
      case CivicEffect.populationGrowth:
        final p = planning;
        if (p == null) return [_row('Nüfus', '$population')];
        final total = p.children + p.adults + p.elders;
        final foodColor = p.daysOfFoodLeft >= 6.0
            ? AppUi.sage
            : p.daysOfFoodLeft >= 3.0
                ? AppUi.accent
                : AppUi.rust;
        return [
          Text('Köyünde $total kişi yaşıyor.',
              style: AppUi.bodyHi.copyWith(fontSize: 14, height: 1.25)),
          const SizedBox(height: 14),
          _miniSection('YAŞ', [
            _ledgerRow('Yetişkin', '${p.adults}'),
            _ledgerRow('Çocuk', '${p.children}'),
            _ledgerRow('Yaşlı', '${p.elders}'),
          ]),
          _miniSection('AİLE', [
            _ledgerRow('Çift', '${p.couples}'),
            if (p.pregnantSoon > 0)
              _ledgerRow('Yakında bebek', '${p.pregnantSoon}',
                  accent: AppUi.accent),
          ]),
          _miniSection('KONUT', [
            _ledgerRow('Dolu', '${p.housedSlots} / ${p.totalHousing}',
                accent: p.housedSlots < p.totalHousing ? null : AppUi.rust),
          ]),
          _miniSection('YİYECEK', [
            _ledgerRow('Günlük tüketim', p.foodPerDay.toStringAsFixed(0)),
            _ledgerRow(
                'Stok yeter',
                p.daysOfFoodLeft.isFinite
                    ? '${p.daysOfFoodLeft.toStringAsFixed(1)} gün'
                    : '∞',
                accent: foodColor),
          ]),
          const SizedBox(height: 10),
          AppStatBar(
              label: 'MORAL',
              value: stats.morale,
              trailing: '${(stats.morale * 100).round()}%',
              color: stats.morale > 0.6 ? AppUi.sage : foodColor),
          // Yönetişim (KARAR DEFTERİ + hane nabzı) 2026-07-13'te DİVAN'a taşındı
          // — bu panel yalnızca binanın kendi işini anlatır. Belediye yönetişimin
          // koltuğu olduğundan buradan Divan'a bir kapı bırakıyoruz.
          if (onOpenDivan != null) ...[
            const SizedBox(height: 16),
            _divanLink(),
          ],
        ];
      case CivicEffect.morale:
        return [
          _row('Moral katkısı', '+${(fn.civicValue * 100).round()}%',
              accent: true),
          const SizedBox(height: 6),
          _row('Köy morali', '${(stats.morale * 100).round()}%'),
        ];
      case CivicEffect.carrierSpeed:
        return [
          _row('Bu ahırın katkısı', '+${(fn.civicValue * 100).round()}%'),
          const SizedBox(height: 6),
          _row('Taşıyıcı hızı',
              '×${stats.carrierSpeedMultiplier.toStringAsFixed(2)}',
              accent: true),
        ];
      case CivicEffect.none:
        return [_row('Boyut', '${building.cols}×${building.rows}')];
    }
  }

  /// Divan'a açılan kapı — belediye yönetişimin koltuğu; yasalar/gündem/Meclis
  /// artık Divan'da toplu duruyor (bu panel kalabalıklaşmasın).
  Widget _divanLink() {
    return GestureDetector(
      onTap: onOpenDivan,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.fromLTRB(11, 10, 12, 10),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            Color.alphaBlend(
                AppUi.accent.withValues(alpha: 0.16), AppUi.surface1),
            AppUi.surface0,
          ]),
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: AppUi.accent.withValues(alpha: 0.55)),
        ),
        child: Row(
          children: [
            const Text('⚖', style: TextStyle(fontSize: 17)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('DİVAN\'I AÇ',
                      style: AppUi.title.copyWith(
                          fontSize: 12.5, letterSpacing: 1.0)),
                  const SizedBox(height: 2),
                  Text('Gündem · Meclis · Karar Defteri',
                      style: AppUi.body
                          .copyWith(fontSize: 10, color: AppUi.textLo)),
                ],
              ),
            ),
            const GameIcon(GameIconData.chevron,
                size: 15, color: AppUi.accent),
          ],
        ),
      ),
    );
  }

  // ─── Aksiyonlar ───────────────────────────────────────────────────────────

  List<_Action> _actions() {
    final fn = _fn;
    final out = <_Action>[];

    if (fn?.role == BuildingRole.trade) {
      for (final e in kMarketSellRates.entries) {
        final enabled = stockpile.get(e.key) >= e.value.$1;
        out.add(_Action(
          icon: _resIcon(e.key) ?? GameIconData.coin,
          label: '${e.value.$1}→${e.value.$2}◆',
          tint: AppUi.gold,
          onTap: enabled ? () => onSell(e.key) : null,
        ));
      }
    }

    if (onFestival != null) {
      final role = fn?.role;
      final ok = role == BuildingRole.housing ||
          (role == BuildingRole.civic &&
              (fn?.civicEffect == CivicEffect.morale ||
                  fn?.civicEffect == CivicEffect.populationGrowth));
      if (ok) {
        final canAfford = stockpile.food >= festivalFoodCost &&
            stockpile.gold >= festivalGoldCost;
        out.add(_Action(
          icon: GameIconData.festival,
          label: 'Şenlik',
          tint: AppUi.accent,
          kind: AppButtonKind.filled,
          sub: '$festivalFoodCost yem · $festivalGoldCost altın',
          onTap: canAfford ? onFestival : null,
        ));
      }
    }

    if (onRefillWater != null &&
        fn?.role == BuildingRole.civic &&
        fn?.civicEffect == CivicEffect.morale &&
        building.type == BuildingType.well) {
      out.add(_Action(
        icon: GameIconData.drop,
        label: 'Su Servisi',
        tint: AppUi.info,
        onTap: onRefillWater,
      ));
    }

    if (onCollectTax != null &&
        fn?.civicEffect == CivicEffect.populationGrowth) {
      out.add(_Action(
        icon: GameIconData.tax,
        label: 'Vergi',
        tint: AppUi.gold,
        onTap: onCollectTax,
      ));
    }

    if (onTogglePaused != null &&
        (fn?.role == BuildingRole.gathering ||
            fn?.role == BuildingRole.processing)) {
      out.add(_Action(
        icon: building.userPaused ? GameIconData.play : GameIconData.pause,
        label: building.userPaused ? 'Sürdür' : 'Durdur',
        tint: AppUi.accentSoft,
        onTap: onTogglePaused,
      ));
    }

    if (onMove != null) {
      out.add(_Action(
        icon: GameIconData.hammer,
        label: 'Taşı',
        tint: AppUi.info,
        onTap: onMove,
      ));
    }

    if (onDemolish != null) {
      out.add(_Action(
        icon: GameIconData.demolish,
        label: 'Yık',
        tint: AppUi.rust,
        kind: AppButtonKind.danger,
        onTap: onDemolish,
      ));
    }

    return out;
  }

  Widget _actionStrip() {
    final actions = _actions();
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: [
        for (final a in actions)
          AppButton(
            label: a.label,
            sub: a.sub,
            icon: a.icon,
            tint: a.tint,
            kind: a.kind,
            onTap: a.onTap,
          ),
      ],
    );
  }

  // ─── Parçacıklar ──────────────────────────────────────────────────────────

  GameIconData? _resIcon(ResourceKind k) => switch (k) {
        ResourceKind.wood => GameIconData.wood,
        ResourceKind.stone => GameIconData.stone,
        ResourceKind.iron => GameIconData.iron,
        ResourceKind.coal => GameIconData.coal,
        ResourceKind.food => GameIconData.wheat,
        ResourceKind.gold => GameIconData.coin,
        ResourceKind.honey => GameIconData.honey,
        ResourceKind.reed => GameIconData.reed,
      };

  Widget _row(String label, String value,
          {bool accent = false, GameIconData? icon}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            if (icon != null) ...[
              GameIcon(icon, size: 13, color: AppUi.textLo),
              const SizedBox(width: 6),
            ],
            Text(label, style: AppUi.label.copyWith(letterSpacing: 0.6)),
            const Spacer(),
            Text(value,
                style: AppUi.number.copyWith(
                    fontSize: 13,
                    color: accent ? AppUi.gold : AppUi.textHi)),
          ],
        ),
      );

  Widget _statusRow(bool active) {
    final (label, color, icon) = active
        ? ('Çalışıyor', AppUi.sage, GameIconData.cog)
        : building.userPaused
            ? ('Duruşta', AppUi.accentSoft, GameIconData.pause)
            : ('Boşta', AppUi.textLo, GameIconData.cog);
    return Row(
      children: [
        Text('DURUM', style: AppUi.label.copyWith(letterSpacing: 0.6)),
        const Spacer(),
        GameIcon(icon, size: 12, color: color),
        const SizedBox(width: 5),
        Text(label, style: AppUi.bodyHi.copyWith(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _miniSection(String label, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [AppSectionLabel(label), ...rows, const SizedBox(height: 8)],
      ),
    );
  }

  Widget _ledgerRow(String label, String value, {Color? accent}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            Text(label, style: AppUi.body),
            const Spacer(),
            Text(value,
                style: AppUi.number
                    .copyWith(fontSize: 13, color: accent ?? AppUi.textHi)),
          ],
        ),
      );

  Widget _residentRow() => Wrap(
        spacing: 5,
        runSpacing: 5,
        children: residents.map(_residentChip).toList(),
      );

  Widget _residentChip(VillagerEntity v) {
    final stage = v.lifeStage;
    final role = v.hasProfession ? v.type.displayName : stage.label;
    final lines = <String>['${v.name} — $role'];
    if (v.parents.isNotEmpty) {
      lines.add('Ebeveynler: ${v.parents.map((p) => p.name).join(', ')}');
    }
    if (v.children.isNotEmpty) {
      lines.add('Çocuklar: ${v.children.map((c) => c.name).join(', ')}');
    }
    return Tooltip(
      message: lines.join('\n'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AppUi.surface0,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: AppUi.line, width: 1),
        ),
        child: Text(v.name,
            style: AppUi.body.copyWith(color: AppUi.textMid, fontSize: 11)),
      ),
    );
  }
}

class _Action {
  final GameIconData icon;
  final String label;
  final String? sub;
  final Color tint;
  final AppButtonKind kind;
  final VoidCallback? onTap;
  _Action({
    required this.icon,
    required this.label,
    required this.tint,
    this.onTap,
    this.sub,
    this.kind = AppButtonKind.tonal,
  });
}

// ─── Renk + etiket eşlemeleri ──────────────────────────────────────────────

Color _accentFor(BuildingFunction? fn) {
  if (fn == null) return AppUi.accentSoft;
  switch (fn.role) {
    case BuildingRole.housing:
      return AppUi.sage;
    case BuildingRole.gathering:
      return AppUi.accent;
    case BuildingRole.processing:
      return AppUi.gold;
    case BuildingRole.trade:
      return AppUi.gold;
    case BuildingRole.storage:
      return AppUi.accentSoft;
    case BuildingRole.civic:
      return switch (fn.civicEffect) {
        CivicEffect.populationGrowth => AppUi.sage,
        CivicEffect.morale => AppUi.accentSoft,
        CivicEffect.carrierSpeed => AppUi.info,
        CivicEffect.none => AppUi.accentSoft,
      };
    case BuildingRole.none:
      return AppUi.accentSoft;
  }
}

String _roleLabel(BuildingFunction? fn) {
  if (fn == null) return '';
  switch (fn.role) {
    case BuildingRole.housing:
      return 'Ev';
    case BuildingRole.gathering:
      return 'Üretim';
    case BuildingRole.processing:
      return 'İşleme';
    case BuildingRole.trade:
      return 'Ticaret';
    case BuildingRole.storage:
      return 'Depo';
    case BuildingRole.civic:
      return switch (fn.civicEffect) {
        CivicEffect.populationGrowth => 'Yönetim',
        CivicEffect.morale => 'Moral',
        CivicEffect.carrierSpeed => 'Lojistik',
        CivicEffect.none => '',
      };
    case BuildingRole.none:
      return '';
  }
}

// ─── Kapasite çubukları ──────────────────────────────────────────────────

class _CapacityBars extends StatelessWidget {
  final ResourceBundle stockpile;
  final int cap;
  const _CapacityBars({required this.stockpile, required this.cap});

  @override
  Widget build(BuildContext context) {
    const kinds = [
      (ResourceKind.wood, GameIconData.wood, Color(0xFFBB8844)),
      (ResourceKind.stone, GameIconData.stone, Color(0xFFAAAAAA)),
      (ResourceKind.iron, GameIconData.iron, Color(0xFFCCCCEE)),
      (ResourceKind.coal, GameIconData.coal, Color(0xFF999999)),
      (ResourceKind.food, GameIconData.wheat, AppUi.sage),
    ];
    return Column(
      children: [
        for (final (kind, icon, color) in kinds)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                GameIcon(icon, size: 13, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Container(
                    height: 6,
                    decoration: BoxDecoration(
                      color: AppUi.surface0,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: AppUi.line, width: 0.8),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (stockpile.get(kind) / cap).clamp(0.0, 1.0),
                        child: Container(color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 30,
                  child: Text('${stockpile.get(kind)}',
                      textAlign: TextAlign.right,
                      style: AppUi.number.copyWith(fontSize: 11)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ─── Thumbnail painter ────────────────────────────────────────────────────

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
