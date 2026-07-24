import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';

import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../rendering/portrait_renderer.dart';
import '../systems/estate_system.dart' show EstateMoodTier;
import '../systems/house_system.dart';
import 'app_ui.dart';

/// Bir köylünün defter satırı için önceden hesaplanmış görünüm modeli — barınma
/// bilgisi sahnede (kBuildingMeta erişimiyle) türetilip buraya taşınır, panel
/// bina katmanına bağımlı olmaz.
class VillagerStatRow {
  final VillagerEntity v;

  /// Ev kademesi etiketi — "Konak" / "Taş Ev" / "Ahşap Ev" / "Çadır" / "Evsiz".
  final String housingLabel;

  /// Ev kademesi sıralama anahtarı: 0 evsiz · 1 çadır · 2 ahşap · 3 taş · 4 konak.
  final int housingTier;

  const VillagerStatRow(this.v, this.housingLabel, this.housingTier);
}

enum _SortKey { wealth, morale, house, profession, name }

/// NÜFUS — köylüleri kim/hangi hane/ne iş/ne kadar varlıklı/ne kadar mutlu
/// olduklarıyla topluca gösteren defter bölümü. İki sekme:
///   • Köylüler — sıralanabilir tekil liste (portre + hane + meslek + servet
///     çubuğu + moral).
///   • Haneler  — soyada göre gruplu; her hane başlığı hâl (mood) + nüfuz +
///     üye sayısı + baskınlık taşır, altında üyeleri.
///
/// GÖMÜLEBİLİR: kendi modal çerçevesi/scrim'i YOKTUR — [VillageLedger]'ın gövde
/// alanını doldurur (eskiden ayrı tam-ekran modaldı; köy içi yüzeyler tek kapı
/// altında toplanınca çerçeve deftere devredildi). Sınırlı yükseklik ister
/// (içinde Expanded + ListView var).
/// Salt-okunur; bir satıra dokununca [onSelect] ile o köylünün detay paneli açılır.
class VillagerRosterView extends StatefulWidget {
  final List<VillagerStatRow> rows;
  final List<HouseSnapshot> houses;
  final void Function(VillagerEntity)? onSelect;

  /// Açılışta gösterilecek sekme: 0 = Köylüler, 1 = Haneler.
  final int initialTab;

  const VillagerRosterView({
    super.key,
    required this.rows,
    required this.houses,
    this.onSelect,
    this.initialTab = 0,
  });

  @override
  State<VillagerRosterView> createState() => _VillagerRosterViewState();
}

class _VillagerRosterViewState extends State<VillagerRosterView> {
  late int _tab = widget.initialTab; // 0 = Köylüler, 1 = Haneler
  _SortKey _sort = _SortKey.wealth;

  // Her sekmenin kendi scroll controller'ı — Scrollbar'a bağlanır (görünür +
  // sürüklenebilir thumb). Masaüstünde fare-sürükleme [_dragScroll] ile açılır.
  final ScrollController _villagerScroll = ScrollController();
  final ScrollController _houseScroll = ScrollController();

  @override
  void dispose() {
    _villagerScroll.dispose();
    _houseScroll.dispose();
    super.dispose();
  }

  // ── Türetilen ölçekler ──────────────────────────────────────────────────────
  double get _maxWealth {
    var m = 1.0;
    for (final r in widget.rows) {
      if (r.v.wealth > m) m = r.v.wealth;
    }
    return m;
  }

  List<VillagerStatRow> get _sortedRows {
    final list = [...widget.rows];
    int byName(VillagerStatRow a, VillagerStatRow b) =>
        a.v.name.toLowerCase().compareTo(b.v.name.toLowerCase());
    switch (_sort) {
      case _SortKey.wealth:
        list.sort((a, b) => b.v.wealth.compareTo(a.v.wealth));
      case _SortKey.morale:
        list.sort((a, b) => b.v.morale.compareTo(a.v.morale));
      case _SortKey.house:
        list.sort((a, b) {
          final c = a.v.surname.compareTo(b.v.surname);
          return c != 0 ? c : byName(a, b);
        });
      case _SortKey.profession:
        list.sort((a, b) {
          final c =
              a.v.type.displayName.compareTo(b.v.type.displayName);
          return c != 0 ? c : byName(a, b);
        });
      case _SortKey.name:
        list.sort(byName);
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _tabBar(),
        Container(height: 1, color: AppUi.line),
        _kpiStrip(),
        Container(height: 1, color: AppUi.line),
        Expanded(child: _tab == 0 ? _villagerTab() : _houseTab()),
      ],
    );
  }

  // ── Sekmeler (başlık defterin hero'sunda; burada yalnız iç sekme) ──────────
  Widget _tabBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 11),
      child: Row(children: [
        _tabButton('KÖYLÜLER', 0),
        const SizedBox(width: 8),
        _tabButton('HANELER', 1),
      ]),
    );
  }

  Widget _tabButton(String label, int idx) {
    final on = _tab == idx;
    return GestureDetector(
      onTap: () => setState(() => _tab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        decoration: BoxDecoration(
          color: on ? AppUi.accent.withValues(alpha: 0.16) : AppUi.surface0,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
              color: on ? AppUi.accent.withValues(alpha: 0.7) : AppUi.line,
              width: 1),
        ),
        child: Text(label,
            style: AppUi.button.copyWith(
              fontSize: 10.5,
              letterSpacing: 1.2,
              color: on ? AppUi.textHi : AppUi.textLo,
            )),
      ),
    );
  }

  // ── KPI özet şeridi ─────────────────────────────────────────────────────────
  Widget _kpiStrip() {
    final rows = widget.rows;
    final pop = rows.length;
    final houses = widget.houses.length;
    final avgMorale = rows.isEmpty
        ? 0.0
        : rows.map((r) => r.v.morale).reduce((a, b) => a + b) / rows.length;
    final wealthSum =
        rows.fold<double>(0, (s, r) => s + r.v.wealth);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      child: Row(
        children: [
          _kpi(GameIconData.people, 'NÜFUS', '$pop', AppUi.info),
          _kpiDiv(),
          _kpi(GameIconData.home, 'HANE', '$houses', AppUi.accent),
          _kpiDiv(),
          _kpi(GameIconData.heart, 'ORT. MORAL',
              '${(avgMorale * 100).round()}%', _moraleColor(avgMorale)),
          _kpiDiv(),
          _kpi(GameIconData.coin, 'TOPLAM VARLIK',
              wealthSum.round().toString(), AppUi.gold),
        ],
      ),
    );
  }

  Widget _kpi(GameIconData icon, String label, String value, Color color) {
    return Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(mainAxisSize: MainAxisSize.min, children: [
            GameIcon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Text(value,
                style: AppUi.number.copyWith(fontSize: 15, color: AppUi.textHi)),
          ]),
          const SizedBox(height: 3),
          Text(label,
              style: AppUi.label.copyWith(fontSize: 8.5, color: AppUi.textLo)),
        ],
      ),
    );
  }

  Widget _kpiDiv() =>
      Container(width: 1, height: 26, color: AppUi.line);

  // ── Sekme 1: Köylüler ───────────────────────────────────────────────────────
  Widget _villagerTab() {
    final rows = _sortedRows;
    final maxW = _maxWealth;
    return Column(
      children: [
        _sortBar(),
        Container(height: 1, color: AppUi.lineSoft),
        Expanded(
          child: rows.isEmpty
              ? _empty('Köyde henüz kimse yok.')
              : _scrollable(
                  _villagerScroll,
                  ListView.separated(
                    controller: _villagerScroll,
                    padding: const EdgeInsets.fromLTRB(12, 10, 14, 14),
                    itemCount: rows.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 7),
                    itemBuilder: (_, i) => _villagerRow(rows[i], maxW),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _sortBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
      child: Row(children: [
        Text('SIRALA', style: AppUi.label.copyWith(color: AppUi.textLo)),
        const SizedBox(width: 9),
        _sortChip('Servet', _SortKey.wealth),
        _sortChip('Moral', _SortKey.morale),
        _sortChip('Hane', _SortKey.house),
        _sortChip('Meslek', _SortKey.profession),
        _sortChip('Ad', _SortKey.name),
      ]),
    );
  }

  Widget _sortChip(String label, _SortKey key) {
    final on = _sort == key;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: () => setState(() => _sort = key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
          decoration: BoxDecoration(
            color: on ? AppUi.accent.withValues(alpha: 0.18) : AppUi.surface0,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: on ? AppUi.accent.withValues(alpha: 0.7) : AppUi.line,
                width: 1),
          ),
          child: Text(label,
              style: AppUi.button.copyWith(
                fontSize: 9.5,
                letterSpacing: 0.8,
                color: on ? AppUi.textHi : AppUi.textLo,
              )),
        ),
      ),
    );
  }

  Widget _villagerRow(VillagerStatRow r, double maxW) {
    final v = r.v;
    final stage = v.lifeStage;
    final job = v.hasProfession ? v.type.displayName : stage.label;
    final wf = (v.wealth / maxW).clamp(0.0, 1.0);
    return GestureDetector(
      onTap: widget.onSelect == null ? null : () => widget.onSelect!(v),
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 8, 11, 8),
        decoration: BoxDecoration(
          color: AppUi.surface0,
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          border: Border.all(color: AppUi.line, width: 0.8),
        ),
        child: Row(
          children: [
            // Portre
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppUi.surface1,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: AppUi.line, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: CustomPaint(
                  painter: PortraitPainter(
                    visual: v.visual,
                    stage: stage,
                    type: v.type,
                    hasProfession: v.hasProfession,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // İsim + hane + meslek/ev
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(children: [
                    Flexible(
                      child: Text(v.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppUi.bodyHi.copyWith(fontSize: 13)),
                    ),
                    if (v.isFavorite) ...[
                      const SizedBox(width: 5),
                      const GameIcon(GameIconData.heart,
                          size: 10, color: AppUi.rust),
                    ],
                  ]),
                  const SizedBox(height: 2),
                  Text(
                    v.surname.isEmpty ? 'Hanesiz' : '${v.surname} Hanesi',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppUi.body.copyWith(
                        fontSize: 10.5, color: AppUi.textLo),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    _miniChip(job, _profColor(v.type), _profIcon(v.type)),
                    const SizedBox(width: 6),
                    _miniChip(r.housingLabel, _housingColor(r.housingTier),
                        GameIconData.home),
                  ]),
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Servet + moral
            SizedBox(
              width: 118,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    const GameIcon(GameIconData.coin,
                        size: 11, color: AppUi.gold),
                    const SizedBox(width: 4),
                    Text(v.wealth.round().toString(),
                        style: AppUi.number
                            .copyWith(fontSize: 12, color: AppUi.gold)),
                    const SizedBox(width: 5),
                    Text(_wealthWord(wf),
                        style: AppUi.label
                            .copyWith(fontSize: 8, color: AppUi.textLo)),
                  ]),
                  const SizedBox(height: 5),
                  _thinBar(wf, AppUi.gold),
                  const SizedBox(height: 5),
                  _thinBar(v.morale.clamp(0.0, 1.0), _moraleColor(v.morale),
                      icon: GameIconData.heart),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sekme 2: Haneler ────────────────────────────────────────────────────────
  Widget _houseTab() {
    // Soyad → üyeler (defter satırlarından). Salience-sıralı haneleri kullan;
    // hane snapshot'ında olmayan (ör. yeni/tek kişilik) soyları da yakala.
    final byName = <String, List<VillagerStatRow>>{};
    for (final r in widget.rows) {
      final key = r.v.surname.isEmpty ? '' : r.v.surname;
      byName.putIfAbsent(key, () => []).add(r);
    }
    // Snapshot sırasını taban al, kalan soyları (üyeli ama snapshot'sız) ekle.
    final ordered = <String>[];
    for (final h in widget.houses) {
      if (byName.containsKey(h.surname)) ordered.add(h.surname);
    }
    for (final k in byName.keys) {
      if (k.isNotEmpty && !ordered.contains(k)) ordered.add(k);
    }
    if (byName.containsKey('')) ordered.add(''); // hanesizler en sonda
    final snapByName = {for (final h in widget.houses) h.surname: h};

    if (ordered.isEmpty) return _empty('Henüz hane yok.');

    return _scrollable(
      _houseScroll,
      ListView.separated(
        controller: _houseScroll,
        padding: const EdgeInsets.fromLTRB(12, 12, 14, 14),
        itemCount: ordered.length,
        separatorBuilder: (_, _) => const SizedBox(height: 9),
        itemBuilder: (_, i) {
          final key = ordered[i];
          final members = byName[key] ?? const [];
          return _houseCard(key, snapByName[key], members);
        },
      ),
    );
  }

  /// Bir scroll listesini görünür Scrollbar + masaüstünde fare-sürükleme ile
  /// sarar (Flutter desktop varsayılanı fareyle sürüklemeyi kapatır; oyuncular
  /// listeyi sürükleyebilsin diye [PointerDeviceKind.mouse] eklenir).
  Widget _scrollable(ScrollController ctrl, Widget child) {
    return ScrollConfiguration(
      behavior: ScrollConfiguration.of(context).copyWith(
        scrollbars: false,
        dragDevices: {
          PointerDeviceKind.touch,
          PointerDeviceKind.mouse,
          PointerDeviceKind.trackpad,
          PointerDeviceKind.stylus,
        },
      ),
      child: ScrollbarTheme(
        data: ScrollbarThemeData(
          thumbVisibility: WidgetStateProperty.all(true),
          thickness: WidgetStateProperty.all(6),
          radius: const Radius.circular(3),
          thumbColor: WidgetStateProperty.resolveWith((states) =>
              states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)
                  ? AppUi.accent.withValues(alpha: 0.9)
                  : AppUi.textLo.withValues(alpha: 0.55)),
        ),
        child: Scrollbar(
          controller: ctrl,
          child: child,
        ),
      ),
    );
  }

  Widget _houseCard(
      String surname, HouseSnapshot? snap, List<VillagerStatRow> members) {
    final hanesiz = surname.isEmpty;
    final label = hanesiz ? 'Hanesizler' : '$surname Hanesi';
    final mood = snap?.mood ?? 0.55;
    final sway = snap?.swayShare ?? 0.0;
    final ascendant = snap?.ascendant ?? false;
    final wealthSum = members.fold<double>(0, (s, r) => s + r.v.wealth);
    return Container(
      decoration: BoxDecoration(
        color: AppUi.surface0,
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(
            color: ascendant
                ? AppUi.gold.withValues(alpha: 0.55)
                : AppUi.line,
            width: ascendant ? 1.2 : 0.8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Hane başlığı
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
            child: Row(
              children: [
                if (ascendant) ...[
                  const GameIcon(GameIconData.star,
                      size: 14, color: AppUi.gold),
                  const SizedBox(width: 7),
                ],
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppUi.title.copyWith(fontSize: 14)),
                ),
                if (!hanesiz)
                  _miniChip(_moodWord(snap?.tier), _moraleColor(mood), null),
              ],
            ),
          ),
          if (!hanesiz)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Row(children: [
                Expanded(
                  child: AppStatBar(
                    label: 'HÂL',
                    value: mood,
                    trailing: '${(mood * 100).round()}%',
                    color: _moraleColor(mood),
                    labelWidth: 34,
                  ),
                ),
                const SizedBox(width: 14),
                _stat('${members.length}', 'ÜYE'),
                const SizedBox(width: 12),
                _stat('${(sway * 100).round()}%', 'NÜFUZ'),
                const SizedBox(width: 12),
                _stat(wealthSum.round().toString(), 'VARLIK',
                    color: AppUi.gold),
              ]),
            ),
          Container(height: 1, color: AppUi.lineSoft),
          // Üyeler
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
            child: Column(
              children: [
                for (final r in members) _memberLine(r),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _memberLine(VillagerStatRow r) {
    final v = r.v;
    final job = v.hasProfession ? v.type.displayName : v.lifeStage.label;
    return GestureDetector(
      onTap: widget.onSelect == null ? null : () => widget.onSelect!(v),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 3),
        child: Row(children: [
          GameIcon(_profIcon(v.type), size: 12, color: _profColor(v.type)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(v.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppUi.body.copyWith(fontSize: 12, color: AppUi.textHi)),
          ),
          Text(job,
              style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo)),
          const SizedBox(width: 10),
          const GameIcon(GameIconData.coin, size: 10, color: AppUi.gold),
          const SizedBox(width: 3),
          SizedBox(
            width: 34,
            child: Text(v.wealth.round().toString(),
                textAlign: TextAlign.right,
                style: AppUi.number.copyWith(fontSize: 11, color: AppUi.gold)),
          ),
        ]),
      ),
    );
  }

  // ── Küçük yapı taşları ──────────────────────────────────────────────────────
  Widget _stat(String value, String label, {Color? color}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value,
            style: AppUi.number
                .copyWith(fontSize: 13, color: color ?? AppUi.textHi)),
        Text(label,
            style: AppUi.label.copyWith(fontSize: 7.5, color: AppUi.textLo)),
      ],
    );
  }

  Widget _miniChip(String label, Color color, GameIconData? icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.55), width: 0.9),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        if (icon != null) ...[
          GameIcon(icon, size: 9, color: color),
          const SizedBox(width: 4),
        ],
        Text(label,
            style: AppUi.button.copyWith(
                fontSize: 9, letterSpacing: 0.5, color: AppUi.textHi)),
      ]),
    );
  }

  Widget _thinBar(double value, Color color, {GameIconData? icon}) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      if (icon != null) ...[
        GameIcon(icon, size: 8, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 4),
      ],
      SizedBox(
        width: icon == null ? 100 : 92,
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: AppUi.surface1,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: AppUi.line, width: 0.7),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: Align(
              alignment: Alignment.centerLeft,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: value.clamp(0.0, 1.0)),
                duration: const Duration(milliseconds: 420),
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => FractionallySizedBox(
                  widthFactor: v,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        color.withValues(alpha: 0.75),
                        color,
                      ]),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    ]);
  }

  Widget _empty(String msg) => Center(
        child: Text(msg,
            style: AppUi.body.copyWith(color: AppUi.textLo)),
      );

  // ── Renk / etiket eşlemeleri ────────────────────────────────────────────────
  Color _moraleColor(double m) => m >= 0.6
      ? AppUi.sage
      : m >= 0.4
          ? AppUi.gold
          : AppUi.rust;

  String _wealthWord(double f) => f >= 0.66
      ? 'VARLIKLI'
      : f >= 0.4
          ? 'HÂLLİ'
          : f >= 0.18
              ? 'ORTA'
              : 'DAR';

  String _moodWord(EstateMoodTier? t) => switch (t) {
        EstateMoodTier.content => 'HOŞNUT',
        EstateMoodTier.neutral => 'DENGELİ',
        EstateMoodTier.uneasy => 'HUZURSUZ',
        EstateMoodTier.sullen => 'KÜSKÜN',
        null => 'DENGELİ',
      };

  Color _housingColor(int tier) => switch (tier) {
        4 => AppUi.gold, // konak
        3 => AppUi.info, // taş ev
        2 => AppUi.sage, // ahşap ev
        1 => const Color(0xFFB09A7C), // çadır
        _ => AppUi.rust, // evsiz
      };

  Color _profColor(VillagerType t) => switch (t) {
        VillagerType.farmer => AppUi.sage,
        VillagerType.merchant => AppUi.gold,
        VillagerType.blacksmith => AppUi.rust,
        VillagerType.guard => AppUi.info,
        VillagerType.priest => const Color(0xFF8E9AC4),
        VillagerType.miner => const Color(0xFFB09A7C),
        VillagerType.fisher => const Color(0xFF6FA8C7),
        VillagerType.shepherd => const Color(0xFFCFC3A8),
        VillagerType.hunter => const Color(0xFF6E9B6A),
        VillagerType.miller => const Color(0xFFDDD6C4),
        VillagerType.innkeeper => const Color(0xFFC07A6A),
      };

  GameIconData _profIcon(VillagerType t) => switch (t) {
        VillagerType.farmer => GameIconData.wheat,
        VillagerType.merchant => GameIconData.coin,
        VillagerType.blacksmith => GameIconData.hammer,
        VillagerType.guard => GameIconData.axe,
        VillagerType.priest => GameIconData.church,
        VillagerType.miner => GameIconData.pickaxe,
        VillagerType.fisher => GameIconData.fish,
        VillagerType.shepherd => GameIconData.herd,
        VillagerType.hunter => GameIconData.bow,
        VillagerType.miller => GameIconData.mill,
        VillagerType.innkeeper => GameIconData.tankard,
      };
}
