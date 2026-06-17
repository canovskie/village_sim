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
import '../systems/estate_system.dart';
import 'cozy_theme.dart';

/// Bir binaya tıklanınca açılan diegetic "köy defteri" sayfası.
/// Üstte ahşap başlık + portre, altta parşömen üstü hızlı veriler ve büyük
/// deri sekme aksiyon kuşağı (Şenlik / Sat / Yık / vb). Stat dump değil,
/// karar masası gibi davranır.
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

  /// Yeni aksiyonlar — null olabilir; null ise buton görünmez.
  final VoidCallback? onFestival;
  final VoidCallback? onDemolish;
  final VoidCallback? onTogglePaused;
  final VoidCallback? onCollectTax;
  final VoidCallback? onRefillWater;

  /// Şenlik maliyeti — buton üstündeki rozet için.
  final int festivalFoodCost;
  final int festivalGoldCost;

  /// Belediye nüfus planlama dashboard verisi — yalnız townhall seçili iken
  /// dolu gelir. Yaş dağılımı, çiftler, hamile sayımı, yiyecek tüketimi.
  final PopulationPlanning? planning;
  /// Belediye politikaları — toggle'lar üzerinden değiştirilir.
  final VillagePolicies? policies;
  /// Politika toggle callback'i — scene tarafı setState'ler.
  final void Function(String key)? onTogglePolicy;
  /// Aile planlaması mutex setter (radio).
  final void Function(FamilyPolicy fp)? onSetFamilyPolicy;
  /// Karar değişikliği cooldown'unda kalan saniye (0 = serbest).
  final double policyCooldownSec;

  /// Zümre nabzı — yalnız townhall'da dolu. Her zümrenin morali + nüfuz payı.
  final List<EstateSnapshot>? estates;
  /// Köyün şu anki kimlik adı (baskın zümreden) — "Dengeli Köy" vb.
  final String? villageIdentity;

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
    this.onTogglePaused,
    this.onCollectTax,
    this.onRefillWater,
    this.festivalFoodCost = 8,
    this.festivalGoldCost = 5,
    this.planning,
    this.policies,
    this.onTogglePolicy,
    this.onSetFamilyPolicy,
    this.policyCooldownSec = 0,
    this.estates,
    this.villageIdentity,
  });

  BuildingFunction? get _fn => building.fn;
  Color get _accent => _accentFor(_fn);

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[building.type]!;
    // Tap dışı backdrop paneli kapatır, ama panelin kendine tıklama bunu
    // tetiklemesin diye absorbing.
    return GestureDetector(
      onTap: () {}, // event'i absorb et
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(meta.label),
            // Başlık altına parşömen — overlap için negatif margin yok,
            // ahşap header parşömene bağlanmış gibi.
            Transform.translate(
              offset: const Offset(0, -2),
              child: ParchmentPanel(
                pinned: false,
                padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ..._vital(_fn),
                    if (_actions().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _actionStrip(),
                    ],
                    if (_fn?.summary.isNotEmpty == true) ...[
                      const SizedBox(height: 12),
                      Text(_fn!.summary, style: CozyUi.inkMuted),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Başlık (ahşap pano + portre) ────────────────────────────────────────

  Widget _header(String label) {
    final thumb = BuildingRenderer.thumbnails[building.type];
    return WoodPlankPanel(
      padding: const EdgeInsets.fromLTRB(11, 9, 9, 11),
      borderRadius: const BorderRadius.only(
        topLeft: Radius.circular(4),
        topRight: Radius.circular(4),
        bottomLeft: Radius.zero,
        bottomRight: Radius.zero,
      ),
      child: Row(
        children: [
          // Portre — koyu çerçeve içinde
          Container(
            width: 44,
            height: 36,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              color: const Color(0xFF1A0E04),
              border: Border.all(color: const Color(0xFF2E1A08), width: 1),
              boxShadow: const [
                BoxShadow(color: Color(0x88000000), blurRadius: 2, offset: Offset(0, 1)),
              ],
            ),
            child: thumb != null
                ? CustomPaint(painter: _ThumbPainter(thumb))
                : const Center(
                    child: Text('⌂',
                        style: TextStyle(fontSize: 22, color: Color(0xFFE5C58A))),
                  ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: CozyUi.carvedTitle.copyWith(
                        fontSize: 13, letterSpacing: 1.6, color: const Color(0xFFF1D89A)),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                _roleTag(),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Container(
              width: 22, height: 22,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF1A0E04),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: const Color(0xFF3A2410), width: 1),
                boxShadow: const [
                  BoxShadow(color: Color(0x88000000), blurRadius: 2, offset: Offset(0, 1)),
                ],
              ),
              child: const Text('✕',
                  style: TextStyle(
                    color: Color(0xFFD2B679),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1.5),
      decoration: BoxDecoration(
        color: Color.alphaBlend(_accent.withValues(alpha: 0.30), const Color(0xFF1A0E04)),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: _accent.withValues(alpha: 0.7), width: 1),
      ),
      child: Text(label.toUpperCase(),
          style: TextStyle(
            color: _accent,
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
            fontFamily: 'monospace',
            letterSpacing: 1.6,
            shadows: const [
              Shadow(color: Color(0xAA000000), blurRadius: 0, offset: Offset(0, 1)),
            ],
          )),
    );
  }

  // ─── Vital (parşömen üstü hızlı veriler) ─────────────────────────────────

  List<Widget> _vital(BuildingFunction? fn) {
    if (fn == null) {
      return [_inkRow('Boyut', '${building.cols}×${building.rows}')];
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
        return [_inkRow('Boyut', '${building.cols}×${building.rows}')];
    }
  }

  List<Widget> _housingVital(BuildingFunction fn) {
    final water = building.waterLevel.clamp(0.0, 1.0);
    final occ = residents.length / fn.housingCapacity.clamp(1, 99);
    return [
      _vitalBar('Sakinler', occ, '${residents.length}/${fn.housingCapacity}',
          color: residents.length >= fn.housingCapacity ? CozyUi.sage : CozyUi.ember),
      const SizedBox(height: 5),
      _vitalBar('Su deposu', water, '${(water * 100).round()}%',
          color: water > 0.5
              ? const Color(0xFF4A7AA8)
              : water > 0.25
                  ? CozyUi.emberSoft
                  : CozyUi.rust),
      if (residents.isNotEmpty) ...[
        const SizedBox(height: 7),
        _residentRow(),
      ],
    ];
  }

  List<Widget> _gatheringVital() {
    final isMine = building.type == BuildingType.mineBuilding;
    final isBarn = building.type == BuildingType.barn;
    final out = <Widget>[
      _statusRow(building.isActive),
    ];
    if (isMine && activeMiners.isNotEmpty) {
      out.add(_inkRow('Madenci', '${activeMiners.length} içeride'));
    }
    if (isBarn) {
      out.addAll(_barnVital());
    }
    return out;
  }

  List<Widget> _barnVital() {
    if (barnCows.isEmpty) {
      return [_inkRow('İnek', '0')];
    }
    final avgFull = 1.0 -
        (barnCows.fold<double>(0, (s, c) => s + c.hunger) / barnCows.length);
    final readyCount = barnCows.where((c) => c.readyToMilk).length;
    return [
      _inkRow('İnek', '${barnCows.length} baş'),
      _vitalBar('Tokluk', avgFull, '${(avgFull * 100).round()}%',
          color: CozyUi.sage),
      _inkRow('Sağıma hazır', '$readyCount'),
    ];
  }

  List<Widget> _processingVital() => [
        _statusRow(true),
        _inkRow('Balya verimi', '+1${ResourceKind.food.icon} / balya'),
      ];

  List<Widget> _tradeVital(BuildingFunction fn) => [
        _inkRow('Kasa', '${stockpile.gold} ${ResourceKind.gold.icon}',
            accent: true),
        _inkRow('Pasif gelir',
            '+${fn.civicValue.round()}${ResourceKind.gold.icon} / ${kMarketIncomeInterval.toStringAsFixed(0)}sn'),
      ];

  List<Widget> _storageVital(BuildingFunction fn) {
    return [
      _inkRow('Bu deponun katkısı', '+${fn.storageCapacity}'),
      _inkRow('Köy kapasitesi', '${stats.stockCapacity}/kaynak', accent: true),
      const SizedBox(height: 6),
      _CapacityBars(stockpile: stockpile, cap: stats.stockCapacity),
    ];
  }

  List<Widget> _civicVital(BuildingFunction fn) {
    switch (fn.civicEffect) {
      case CivicEffect.populationGrowth:
        // Köy defteri — yazı odaklı, sade. Headline + section'lar + tek moral bar.
        final p = planning;
        if (p == null) {
          return [_inkRow('Nüfus', '$population')];
        }
        final total = p.children + p.adults + p.elders;
        final foodColor = p.daysOfFoodLeft >= 6.0
            ? CozyUi.sage
            : p.daysOfFoodLeft >= 3.0
                ? CozyUi.ember
                : CozyUi.rust;
        return [
          // Headline — büyük, sakin tek cümle
          Text('Köyünde $total kişi yaşıyor.',
              style: TextStyle(
                  color: CozyUi.parchmentInk,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.25)),
          const SizedBox(height: 14),
          _section('YAŞ', [
            _ledgerRow('Yetişkin', '${p.adults}'),
            _ledgerRow('Çocuk', '${p.children}'),
            _ledgerRow('Yaşlı', '${p.elders}'),
          ]),
          _section('AİLE', [
            _ledgerRow(p.couples == 1 ? 'Çift' : 'Çift', '${p.couples}'),
            if (p.pregnantSoon > 0)
              _ledgerRow('Yakında bebek', '${p.pregnantSoon}',
                  accent: CozyUi.ember),
          ]),
          _section('KONUT', [
            _ledgerRow('Dolu', '${p.housedSlots} / ${p.totalHousing}',
                accent: p.housedSlots < p.totalHousing ? null : CozyUi.rust),
          ]),
          _section('YİYECEK', [
            _ledgerRow('Günlük tüketim',
                p.foodPerDay.toStringAsFixed(0)),
            _ledgerRow('Stok yeter',
                p.daysOfFoodLeft.isFinite
                    ? '${p.daysOfFoodLeft.toStringAsFixed(1)} gün'
                    : '∞',
                accent: foodColor),
          ]),
          const SizedBox(height: 6),
          _vitalBar('Moral', stats.morale,
              '${(stats.morale * 100).round()}%',
              color: stats.morale > 0.6 ? CozyUi.sage : foodColor),
          if (estates != null && estates!.isNotEmpty) ...[
            const SizedBox(height: 14),
            _estatePulse(estates!, villageIdentity),
          ],
          if (policies != null && onTogglePolicy != null) ...[
            const SizedBox(height: 14),
            _PolicyEditor(
              policies: policies!,
              onToggle: onTogglePolicy!,
              onSetFamily: onSetFamilyPolicy,
              cooldownSec: policyCooldownSec,
            ),
          ],
        ];
      case CivicEffect.morale:
        return [
          _inkRow('Moral katkısı',
              '+${(fn.civicValue * 100).round()}%', accent: true),
          _inkRow('Köy morali', '${(stats.morale * 100).round()}%'),
        ];
      case CivicEffect.carrierSpeed:
        return [
          _inkRow('Bu ahrın katkısı', '+${(fn.civicValue * 100).round()}%'),
          _inkRow('Taşıyıcı hızı',
              '×${stats.carrierSpeedMultiplier.toStringAsFixed(2)}',
              accent: true),
        ];
      case CivicEffect.none:
        return [_inkRow('Boyut', '${building.cols}×${building.rows}')];
    }
  }

  /// Zümre Nabzı — hibrit görünürlük: 4 zümrenin morali (yüz) + nüfuz payı
  /// (çizgi) + köyün kayan kimliği. Rakam yığını değil, tek bakışta his.
  Widget _estatePulse(List<EstateSnapshot> snap, String? identity) {
    Color moodColor(EstateMoodTier t) => switch (t) {
          EstateMoodTier.content => CozyUi.sage,
          EstateMoodTier.neutral => CozyUi.parchmentInk.withValues(alpha: 0.55),
          EstateMoodTier.uneasy => CozyUi.ember,
          EstateMoodTier.sullen => CozyUi.rust,
        };
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ZÜMRELER',
            style: TextStyle(
                color: CozyUi.inkLabel.color,
                fontSize: 8.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2)),
        const SizedBox(height: 4),
        Container(height: 0.6, color: CozyUi.parchmentEdge),
        const SizedBox(height: 5),
        if (identity != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('Köy bir yöne kayıyor:  $identity',
                style: TextStyle(
                    color: CozyUi.parchmentInk.withValues(alpha: 0.78),
                    fontSize: 10.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w600)),
          ),
        for (final s in snap)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              children: [
                Text(s.estate.icon, style: const TextStyle(fontSize: 13)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 84,
                  child: Text(s.estate.label,
                      style: TextStyle(
                          color: CozyUi.parchmentInk.withValues(
                              alpha: s.ascendant ? 0.95 : 0.72),
                          fontSize: 11,
                          fontWeight:
                              s.ascendant ? FontWeight.w800 : FontWeight.w500)),
                ),
                if (s.ascendant)
                  const Padding(
                    padding: EdgeInsets.only(right: 3),
                    child: Text('★',
                        style: TextStyle(color: Color(0xFFE0C040), fontSize: 10)),
                  ),
                // Nüfuz payı çizgisi — köyün o zümreye ne kadar kaydığı.
                Expanded(
                  child: Container(
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(2),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: s.swayShare.clamp(0.0, 1.0),
                          child: Container(
                            color: moodColor(s.tier).withValues(alpha: 0.85),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 7),
                Text(s.tier.face, style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
      ],
    );
  }

  // ─── Aksiyon kuşağı ──────────────────────────────────────────────────────

  /// Role özgü aksiyon listesi — null olanlar buton üretmez.
  List<_Action> _actions() {
    final fn = _fn;
    final out = <_Action>[];

    // Trade → mevcut market sell
    if (fn?.role == BuildingRole.trade) {
      for (final e in kMarketSellRates.entries) {
        final enabled = stockpile.get(e.key) >= e.value.$1;
        out.add(_Action(
          icon: e.key.icon,
          label: '${e.value.$1}→${e.value.$2}${ResourceKind.gold.icon}',
          tint: const Color(0xFFE0C040),
          onTap: enabled ? () => onSell(e.key) : null,
        ));
      }
    }

    // Festival — housing / civic-morale / civic-population
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
          icon: '🎉',
          label: 'Şenlik',
          tint: CozyUi.ember,
          sub: '$festivalFoodCost🌾 $festivalGoldCost★',
          onTap: canAfford ? onFestival : null,
        ));
      }
    }

    // Su servisi — well only
    if (onRefillWater != null &&
        fn?.role == BuildingRole.civic &&
        fn?.civicEffect == CivicEffect.morale &&
        building.type == BuildingType.well) {
      out.add(_Action(
        icon: '💧',
        label: 'Su Servisi',
        tint: const Color(0xFF4A7AA8),
        onTap: onRefillWater,
      ));
    }

    // Vergi — townhall
    if (onCollectTax != null &&
        fn?.civicEffect == CivicEffect.populationGrowth) {
      out.add(_Action(
        icon: '💰',
        label: 'Vergi',
        tint: const Color(0xFFB59030),
        onTap: onCollectTax,
      ));
    }

    // Pause/Resume — gathering/processing
    if (onTogglePaused != null &&
        (fn?.role == BuildingRole.gathering ||
            fn?.role == BuildingRole.processing)) {
      out.add(_Action(
        icon: building.userPaused ? '▶' : '⏸',
        label: building.userPaused ? 'Sürdür' : 'Durdur',
        tint: const Color(0xFFB59030),
        onTap: onTogglePaused,
      ));
    }

    // Demolish — universal son aksiyon
    if (onDemolish != null) {
      out.add(_Action(
        icon: '✕',
        label: 'Yık',
        tint: CozyUi.rust,
        onTap: onDemolish,
      ));
    }

    return out;
  }

  Widget _actionStrip() {
    final actions = _actions();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [for (final a in actions) _actionButton(a)],
    );
  }

  Widget _actionButton(_Action a) {
    final disabled = a.onTap == null;
    return Opacity(
      opacity: disabled ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: a.onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color.alphaBlend(a.tint.withValues(alpha: 0.20),
                    const Color(0xFF6B3E18)),
                CozyUi.leather,
              ],
            ),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(
              color: a.tint.withValues(alpha: 0.9),
              width: 1.4,
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x55000000), blurRadius: 3, offset: Offset(0, 1)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(a.icon, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(a.label,
                      style: TextStyle(
                        color: const Color(0xFFF1D89A),
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        fontFamily: 'monospace',
                        shadows: const [
                          Shadow(color: Color(0xCC000000), blurRadius: 0, offset: Offset(0, 1)),
                        ],
                      )),
                  if (a.sub != null)
                    Text(a.sub!,
                        style: TextStyle(
                          color: a.tint,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w700,
                          fontFamily: 'monospace',
                          shadows: const [
                            Shadow(color: Color(0xAA000000), blurRadius: 0, offset: Offset(0, 1)),
                          ],
                        )),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Parçacıklar ─────────────────────────────────────────────────────────

  Widget _inkRow(String label, String value, {bool accent = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 1.5),
        child: Row(
          children: [
            Text(label, style: CozyUi.inkLabel),
            const Spacer(),
            Text(value,
                style: CozyUi.inkBody.copyWith(
                  color: accent ? const Color(0xFF8A4A18) : CozyUi.parchmentInk,
                  fontWeight: FontWeight.w800,
                )),
          ],
        ),
      );

  Widget _statusRow(bool active) => _inkRow(
        'Durum',
        active ? '⚙ Çalışıyor' : building.userPaused ? '⏸ Duruşta' : '💤 Boşta',
        accent: active,
      );

  Widget _vitalBar(String label, double value, String tail, {required Color color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 78,
              child: Text(label, style: CozyUi.inkLabel),
            ),
            Expanded(
              child: Container(
                height: 8,
                decoration: BoxDecoration(
                  color: const Color(0x33000000),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(color: CozyUi.parchmentEdge, width: 0.6),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: value.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            color.withValues(alpha: 0.85),
                            color,
                            Color.lerp(color, Colors.white, 0.30)!,
                          ]),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 7),
            SizedBox(
              width: 42,
              child: Text(tail,
                  textAlign: TextAlign.right,
                  style: CozyUi.inkBody.copyWith(fontSize: 9.5)),
            ),
          ],
        ),
      );

  /// Köy defteri section — küçük başlık + içerik + ince ayraç.
  /// Border/box yok; sadece typografi ile hiyerarşi. Şık + sade tasarım.
  Widget _section(String label, List<Widget> rows) {
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: CozyUi.inkLabel.color,
                  fontSize: 8.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2)),
          const SizedBox(height: 4),
          // Hairline ayraç — neredeyse görünmez parşömen mürekkebi.
          Container(height: 0.6, color: CozyUi.parchmentEdge),
          const SizedBox(height: 4),
          ...rows,
        ],
      ),
    );
  }

  /// Sade defter satırı: solda etiket, sağda değer. Box yok.
  Widget _ledgerRow(String label, String value, {Color? accent}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2.5),
        child: Row(
          children: [
            Text(label,
                style: TextStyle(
                    color: CozyUi.parchmentInk.withValues(alpha: 0.75),
                    fontSize: 11,
                    fontWeight: FontWeight.w500)),
            const Spacer(),
            Text(value,
                style: TextStyle(
                    color: accent ?? CozyUi.parchmentInk,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ],
        ),
      );

  Widget _residentRow() => Wrap(
        spacing: 4,
        runSpacing: 4,
        children: residents.map(_residentChip).toList(),
      );

  Widget _residentChip(VillagerEntity v) {
    final stage = v.lifeStage;
    final role  = v.hasProfession ? v.type.displayName : stage.label;
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
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0x55000000),
          borderRadius: BorderRadius.circular(2),
          border: Border.all(color: CozyUi.parchmentEdge, width: 0.6),
        ),
        child: Text('${stage.icon} ${v.name}',
            style: const TextStyle(
                color: CozyUi.parchmentInk,
                fontSize: 9,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _Action {
  final String icon;
  final String label;
  final String? sub;
  final Color tint;
  final VoidCallback? onTap;
  _Action({required this.icon, required this.label, required this.tint, this.onTap, this.sub});
}

// ─── Renk + etiket eşlemeleri ──────────────────────────────────────────────

Color _accentFor(BuildingFunction? fn) {
  if (fn == null) return CozyUi.emberSoft;
  switch (fn.role) {
    case BuildingRole.housing:
      return CozyUi.sage;
    case BuildingRole.gathering:
      return CozyUi.ember;
    case BuildingRole.processing:
      return const Color(0xFFE0C040);
    case BuildingRole.trade:
      return const Color(0xFFE0C040);
    case BuildingRole.storage:
      return CozyUi.emberSoft;
    case BuildingRole.civic:
      return switch (fn.civicEffect) {
        CivicEffect.populationGrowth => CozyUi.sage,
        CivicEffect.morale => CozyUi.emberSoft,
        CivicEffect.carrierSpeed => const Color(0xFF66A0CC),
        CivicEffect.none => CozyUi.emberSoft,
      };
    case BuildingRole.none:
      return CozyUi.emberSoft;
  }
}

(String, Color) _roleLabel(BuildingFunction? fn) {
  if (fn == null) return ('', CozyUi.emberSoft);
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

// ─── Kapasite çubukları ──────────────────────────────────────────────────

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
                    height: 6,
                    decoration: BoxDecoration(
                      color: const Color(0x33000000),
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(color: CozyUi.parchmentEdge, width: 0.6),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: (stockpile.get(kind) / cap).clamp(0.0, 1.0),
                        child: Container(color: color),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                SizedBox(
                  width: 28,
                  child: Text('${stockpile.get(kind)}',
                      textAlign: TextAlign.right,
                      style: CozyUi.inkBody.copyWith(fontSize: 9.5)),
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

// ─── POLITIKA EDİTÖRÜ ──────────────────────────────────────────────────────
// Tab bar + custom ikonlu satırlar + aktif politika rozet stripi + dairesel
// cooldown indicator. Stateful — tab seçimi kendi state'inde tutulur, panel
// yeniden açılınca varsayılan AİLE tab'ine döner (kısa kullanıcı bağlamı).

class _PolicyEditor extends StatefulWidget {
  final VillagePolicies policies;
  final void Function(String key) onToggle;
  final void Function(FamilyPolicy fp)? onSetFamily;
  final double cooldownSec;
  const _PolicyEditor({
    required this.policies,
    required this.onToggle,
    required this.cooldownSec,
    this.onSetFamily,
  });

  @override
  State<_PolicyEditor> createState() => _PolicyEditorState();
}

class _PolicyEditorState extends State<_PolicyEditor> {
  PolicyCategory _tab = PolicyCategory.family;

  @override
  Widget build(BuildContext context) {
    final p = widget.policies;
    final cd = widget.cooldownSec;
    final locked = cd > 0;
    final cdFrac = (cd / 240.0).clamp(0.0, 1.0); // 1 oyun günü = 240sn

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Başlık + cooldown ring ─────────────────────────────────────────
        Row(
          children: [
            Text('KARAR DEFTERİ',
                style: TextStyle(
                    color: CozyUi.inkLabel.color,
                    fontSize: 8.5,
                    fontFamily: 'monospace',
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.6)),
            const Spacer(),
            if (locked) _cooldownRing(cdFrac, cd),
          ],
        ),
        const SizedBox(height: 6),

        // ── Aktif politika rozet stripi (size animate, chip eklenince yumuşak)
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topLeft,
          child: _activeChips(p),
        ),
        const SizedBox(height: 8),

        // ── Tab bar ────────────────────────────────────────────────────────
        _tabBar(),
        const SizedBox(height: 6),
        Container(height: 0.6, color: CozyUi.parchmentEdge),
        const SizedBox(height: 8),

        // ── Tab içeriği — fade + slide transition + size morph ────────────
        AnimatedSize(
          duration: const Duration(milliseconds: 230),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) {
              final slide = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(anim);
              return FadeTransition(
                opacity: anim,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: KeyedSubtree(
              key: ValueKey(_tab),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: _tabContent(p, locked),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _cooldownRing(double frac, double sec) {
    // TweenAnimationBuilder: yeni cooldown başlatıldığında progress 1.0'dan
    // hızla mevcut frac'a yumuşak iner; sonra panel her frame zaten yeniler.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: frac, end: frac),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
      builder: (context, value, _) => SizedBox(
        width: 22, height: 22,
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 22, height: 22,
            child: CircularProgressIndicator(
              value: value,
              strokeWidth: 2.4,
              valueColor: AlwaysStoppedAnimation(CozyUi.rust),
              backgroundColor: CozyUi.parchmentEdge,
            ),
          ),
          Text('${sec.ceil()}',
              style: TextStyle(
                  color: CozyUi.rust,
                  fontSize: 8.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800)),
        ]),
      ),
    );
  }

  Widget _activeChips(VillagePolicies p) {
    final active = <Widget>[];
    if (p.family != FamilyPolicy.open) {
      active.add(_chip('${_familyIcon(p.family)} ${p.family.label}'));
    }
    for (final def in kPolicyDefs) {
      if (p.isOn(def.id)) active.add(_chip('${def.icon} ${def.label}'));
    }
    if (active.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text('Henüz yürürlükte karar yok.',
            style: TextStyle(
                color: CozyUi.parchmentInk.withValues(alpha: 0.5),
                fontSize: 10,
                fontStyle: FontStyle.italic)),
      );
    }
    return Wrap(spacing: 4, runSpacing: 4, children: active);
  }

  Widget _chip(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: CozyUi.ember.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: CozyUi.ember.withValues(alpha: 0.55), width: 0.7),
        ),
        child: Text(text,
            style: TextStyle(
                color: CozyUi.parchmentInk,
                fontSize: 9.5,
                fontWeight: FontWeight.w700)),
      );

  Widget _tabBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (final c in PolicyCategory.values) _tabPill(c),
      ],
    );
  }

  Widget _tabPill(PolicyCategory c) {
    final selected = _tab == c;
    return InkWell(
      onTap: () => setState(() => _tab = c),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
        decoration: BoxDecoration(
          color: selected
              ? CozyUi.ember.withValues(alpha: 0.22)
              : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: selected ? CozyUi.ember : Colors.transparent,
              width: 1.6,
            ),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(c.icon, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 1),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOut,
              style: TextStyle(
                  color: selected
                      ? CozyUi.parchmentInk
                      : CozyUi.parchmentInk.withValues(alpha: 0.55),
                  fontSize: 7.5,
                  fontFamily: 'monospace',
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5),
              child: Text(c.label),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _tabContent(VillagePolicies p, bool locked) {
    final widgets = <Widget>[];
    // Aile sekmesi: mutex radyo + toggle politikalar bir arada
    if (_tab == PolicyCategory.family) {
      widgets.add(_subHeader('DOĞURGANLIK SINIRI'));
      for (final fp in FamilyPolicy.values) {
        widgets.add(_familyRadio(p, fp, locked));
      }
      widgets.add(const SizedBox(height: 6));
      widgets.add(_subHeader('BONUS'));
    }
    final defs = kPolicyDefs.where((d) => d.category == _tab).toList();
    for (final d in defs) {
      widgets.add(_policyTile(d, p.isOn(d.id), locked));
    }
    return widgets;
  }

  Widget _subHeader(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 3, top: 1),
        child: Text(label,
            style: TextStyle(
                color: CozyUi.parchmentInk.withValues(alpha: 0.5),
                fontSize: 7.5,
                fontFamily: 'monospace',
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0)),
      );

  Widget _policyTile(PolicyDef d, bool on, bool locked) {
    const dur = Duration(milliseconds: 240);
    const curve = Curves.easeOutCubic;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: locked ? null : () => widget.onToggle(d.id),
        borderRadius: BorderRadius.circular(4),
        child: AnimatedOpacity(
          duration: dur,
          opacity: locked ? 0.5 : 1.0,
          child: AnimatedContainer(
            duration: dur,
            curve: curve,
            padding: const EdgeInsets.fromLTRB(8, 7, 8, 7),
            margin: const EdgeInsets.symmetric(vertical: 1.5),
            decoration: BoxDecoration(
              color: on
                  ? CozyUi.ember.withValues(alpha: 0.10)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(4),
              border: Border(
                left: BorderSide(
                  color: on ? CozyUi.ember : Colors.transparent,
                  width: 2.5,
                ),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: dur,
                  curve: curve,
                  width: 26, height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: on
                        ? CozyUi.ember.withValues(alpha: 0.22)
                        : const Color(0x18000000),
                    boxShadow: on
                        ? [
                            BoxShadow(
                                color: CozyUi.ember.withValues(alpha: 0.45),
                                blurRadius: 6,
                                spreadRadius: 0)
                          ]
                        : null,
                  ),
                  child: Text(d.icon, style: const TextStyle(fontSize: 14)),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: dur,
                        style: TextStyle(
                            color: on
                                ? CozyUi.parchmentInk
                                : CozyUi.parchmentInk
                                    .withValues(alpha: 0.7),
                            fontSize: 11.5,
                            fontWeight:
                                on ? FontWeight.w800 : FontWeight.w600),
                        child: Text(d.label),
                      ),
                      const SizedBox(height: 1),
                      _consequenceLine('↑', d.benefit, CozyUi.sage),
                      if (d.cost != null)
                        _consequenceLine('↓', d.cost!, CozyUi.rust),
                      if (d.estateMood.isNotEmpty)
                        _estateEffectRow(d.estateMood),
                    ],
                  ),
                ),
                // Sağda slim switch çubuğu — dot animasyonlu sağdan/soldan kayar
                AnimatedContainer(
                  duration: dur,
                  curve: curve,
                  width: 18, height: 8,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: on
                        ? CozyUi.ember
                        : CozyUi.parchmentInk.withValues(alpha: 0.18),
                  ),
                  alignment:
                      on ? Alignment.centerRight : Alignment.centerLeft,
                  child: AnimatedAlign(
                    duration: dur,
                    curve: curve,
                    alignment:
                        on ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      width: 7, height: 7,
                      margin: const EdgeInsets.symmetric(horizontal: 0.5),
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: CozyUi.parchment,
                      ),
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

  Widget _familyRadio(VillagePolicies p, FamilyPolicy fp, bool locked) {
    const dur = Duration(milliseconds: 220);
    const curve = Curves.easeOutCubic;
    final selected = p.family == fp;
    final cb = widget.onSetFamily;
    return InkWell(
      onTap: (locked || cb == null) ? null : () => cb(fp),
      borderRadius: BorderRadius.circular(4),
      child: AnimatedOpacity(
        duration: dur,
        opacity: locked ? 0.5 : 1.0,
        child: AnimatedContainer(
          duration: dur,
          curve: curve,
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
          margin: const EdgeInsets.symmetric(vertical: 1),
          decoration: BoxDecoration(
            color: selected
                ? CozyUi.ember.withValues(alpha: 0.10)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
            border: Border(
              left: BorderSide(
                color: selected ? CozyUi.ember : Colors.transparent,
                width: 2.5,
              ),
            ),
          ),
          child: Row(
            children: [
              Text(_familyIcon(fp), style: const TextStyle(fontSize: 14)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: dur,
                      style: TextStyle(
                          color: selected
                              ? CozyUi.parchmentInk
                              : CozyUi.parchmentInk
                                  .withValues(alpha: 0.7),
                          fontSize: 11.5,
                          fontWeight: selected
                              ? FontWeight.w800
                              : FontWeight.w600),
                      child: Text(fp.label),
                    ),
                    const SizedBox(height: 1),
                    _consequenceLine('↑', fp.benefit, CozyUi.sage),
                    if (fp.cost != null)
                      _consequenceLine('↓', fp.cost!, CozyUi.rust),
                    if (familyPolicyEstateMood(fp).isNotEmpty)
                      _estateEffectRow(familyPolicyEstateMood(fp)),
                  ],
                ),
              ),
              // Radio button — scale-in dot when selected
              AnimatedContainer(
                duration: dur,
                curve: curve,
                width: 12, height: 12,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: selected
                          ? CozyUi.ember
                          : CozyUi.parchmentInk.withValues(alpha: 0.45),
                      width: 1.5),
                  color: selected ? CozyUi.ember : Colors.transparent,
                ),
                child: AnimatedScale(
                  duration: dur,
                  curve: Curves.easeOutBack,
                  scale: selected ? 1.0 : 0.0,
                  child: const Center(
                    child: Text('•',
                        style: TextStyle(
                            color: CozyUi.parchment,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            height: 0.7)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _familyIcon(FamilyPolicy fp) => switch (fp) {
        FamilyPolicy.open => '🌍',
        FamilyPolicy.oneChild => '1️⃣',
        FamilyPolicy.twoChild => '2️⃣',
      };

  /// Fermanın zümre etkisi — kimi sevindirir (▲ sage) / kimi küstürür (▼ rust).
  /// Politik dengeci için: bedelsiz ferman bile bir zümreyi diğerine yeğler.
  Widget _estateEffectRow(List<(Estate, double)> effects) => Padding(
        padding: const EdgeInsets.only(top: 3),
        child: Wrap(
          spacing: 7,
          runSpacing: 2,
          children: [
            for (final (e, d) in effects)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(e.icon, style: const TextStyle(fontSize: 9.5)),
                  const SizedBox(width: 1),
                  Text(d > 0 ? '▲' : '▼',
                      style: TextStyle(
                          color: d > 0 ? CozyUi.sage : CozyUi.rust,
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900)),
                ],
              ),
          ],
        ),
      );

  /// Fayda/bedel satırı — sol oka göre yeşil (↑ fayda) ya da rust (↓ bedel).
  /// Her politika bir bütün: ne kazanırsın + neyi feda edersin görünür.
  Widget _consequenceLine(String prefix, String text, Color color) => Padding(
        padding: const EdgeInsets.only(top: 1),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(prefix,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    height: 1.1)),
            const SizedBox(width: 4),
            Expanded(
              child: Text(text,
                  style: TextStyle(
                      color: color.withValues(alpha: 0.92),
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      height: 1.2)),
            ),
          ],
        ),
      );
}
