import 'package:flutter/material.dart';

import '../../core/resources.dart';
import '../../world/season.dart';
import '../core/app_ui.dart';

enum VillageTesterWeather { clear, rain, storm, snow }

/// Canlı tester'ın yalnız-okunur köy özeti. Tester dünyayı kendi kurmaz;
/// sahnenin o anki gerçek state'ini bu küçük veri paketiyle gösterir.
class VillageTesterSnapshot {
  final int day;
  final int villagers;
  final int buildings;
  final int pendingOrders;
  final int homeless;
  final int food;
  final int wood;
  final int stone;
  final int iron;
  final double timeOfDay;
  final double speed;
  final double rainIntensity;
  final bool snowing;
  final bool godMode;
  final Season season;
  final List<String> warnings;

  const VillageTesterSnapshot({
    required this.day,
    required this.villagers,
    required this.buildings,
    required this.pendingOrders,
    required this.homeless,
    required this.food,
    required this.wood,
    required this.stone,
    required this.iron,
    required this.timeOfDay,
    required this.speed,
    required this.rainIntensity,
    required this.snowing,
    required this.godMode,
    required this.season,
    this.warnings = const [],
  });
}

/// Hazır köy üretmeyen, mevcut doğal koşuyu anlık sınamak için küçük araç.
/// Uzun içerik katalogları burada yoktur: izleme, koşul değiştirme ve dünyada
/// görülebilen birkaç davranış tetikleyicisi üç kısa sekmeye ayrılır.
class VillageTesterPanel extends StatefulWidget {
  final VillageTesterSnapshot snapshot;
  final VoidCallback onHide;
  final ValueChanged<double> onSetSpeed;
  final ValueChanged<double> onSetTime;
  final ValueChanged<VillageTesterWeather> onSetWeather;
  final void Function(ResourceKind kind, int amount) onAddResource;
  final VoidCallback onToggleGod;
  final VoidCallback onSpawnVillager;
  final VoidCallback onWakeAll;
  final VoidCallback onStartChat;
  final VoidCallback onStartDance;
  final VoidCallback onStartConflict;
  final VoidCallback onStartCrime;
  final VoidCallback onSpawnCaravan;
  final VoidCallback onSpawnTraveler;
  final VoidCallback onSpawnStranger;
  final VoidCallback onClearActivities;
  final VoidCallback onClearEffects;
  final VoidCallback? onFreshRun;

  const VillageTesterPanel({
    super.key,
    required this.snapshot,
    required this.onHide,
    required this.onSetSpeed,
    required this.onSetTime,
    required this.onSetWeather,
    required this.onAddResource,
    required this.onToggleGod,
    required this.onSpawnVillager,
    required this.onWakeAll,
    required this.onStartChat,
    required this.onStartDance,
    required this.onStartConflict,
    required this.onStartCrime,
    required this.onSpawnCaravan,
    required this.onSpawnTraveler,
    required this.onSpawnStranger,
    required this.onClearActivities,
    required this.onClearEffects,
    this.onFreshRun,
  });

  @override
  State<VillageTesterPanel> createState() => _VillageTesterPanelState();
}

class _VillageTesterPanelState extends State<VillageTesterPanel> {
  int _tab = 0;
  ResourceKind _resource = ResourceKind.wood;

  static const _tabs = [
    (Icons.monitor_heart_outlined, 'İzle'),
    (Icons.tune_outlined, 'Dünya'),
    (Icons.bolt_outlined, 'Eylem'),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 700;
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const ValueKey('village-tester-panel'),
        width: compact ? 292 : 326,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height - (compact ? 16 : 24),
        ),
        decoration: BoxDecoration(
          color: const Color(0xF2161B20),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppUi.accent.withValues(alpha: 0.72)),
          boxShadow: const [
            BoxShadow(
              color: Color(0x77000000),
              blurRadius: 22,
              offset: Offset(0, 7),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _header(),
            _summaryStrip(),
            _tabBar(),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 13),
                child: switch (_tab) {
                  0 => _observeTab(),
                  1 => _worldTab(),
                  _ => _actionTab(context),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header() => Padding(
    padding: const EdgeInsets.fromLTRB(13, 9, 7, 8),
    child: Row(
      children: [
        const Icon(Icons.science_outlined, size: 19, color: AppUi.accentSoft),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'CANLI KÖY TESTER',
                style: AppUi.label.copyWith(
                  color: AppUi.accentSoft,
                  letterSpacing: 0.9,
                ),
              ),
              Text(
                'Doğal koşu · hazır köy yok',
                style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
              ),
            ],
          ),
        ),
        IconButton(
          key: const ValueKey('village-tester-hide'),
          tooltip: 'Tester panelini gizle',
          visualDensity: VisualDensity.compact,
          onPressed: widget.onHide,
          icon: const Icon(
            Icons.keyboard_double_arrow_right,
            size: 19,
            color: AppUi.textMid,
          ),
        ),
      ],
    ),
  );

  Widget _summaryStrip() {
    final s = widget.snapshot;
    return Container(
      color: AppUi.surface0.withValues(alpha: 0.72),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
      child: Row(
        children: [
          _metric('GÜN', '${s.day}'),
          _metric('NPC', '${s.villagers}'),
          _metric('YAPI', '${s.buildings}'),
          const Spacer(),
          Container(
            key: const ValueKey('village-tester-speed'),
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: s.speed <= 0
                  ? AppUi.rust.withValues(alpha: 0.18)
                  : AppUi.sage.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              s.speed <= 0 ? 'DURDU' : '${s.speed.toStringAsFixed(0)}×',
              style: AppUi.label.copyWith(
                fontSize: 9,
                color: s.speed <= 0 ? AppUi.rust : AppUi.sage,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) => Padding(
    padding: const EdgeInsets.only(right: 13),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$label ', style: AppUi.label.copyWith(fontSize: 8.5)),
        Text(value, style: AppUi.number.copyWith(fontSize: 11)),
      ],
    ),
  );

  Widget _tabBar() => Container(
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: AppUi.line)),
    ),
    child: Row(
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Expanded(
            child: InkWell(
              key: ValueKey('village-tester-tab-$i'),
              onTap: () => setState(() => _tab = i),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: _tab == i ? AppUi.accent : Colors.transparent,
                      width: 2,
                    ),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _tabs[i].$1,
                      size: 14,
                      color: _tab == i ? AppUi.accentSoft : AppUi.textLo,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _tabs[i].$2,
                      style: AppUi.label.copyWith(
                        color: _tab == i ? AppUi.accentSoft : AppUi.textLo,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    ),
  );

  Widget _observeTab() {
    final s = widget.snapshot;
    final hour = s.timeOfDay * 24;
    return Column(
      key: const ValueKey('village-tester-observe'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('KOŞUNUN DURUMU'),
        _infoRow('Takvim', '${s.season.icon} ${s.season.label} · gün ${s.day}'),
        _infoRow('Saat', _clock(hour)),
        _infoRow('Şantiye', '${s.pendingOrders} bekleyen'),
        _infoRow('Barınma', '${s.homeless} evsiz'),
        const SizedBox(height: 10),
        _sectionTitle('STOK'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _stockChip('🌾', s.food),
            _stockChip('🪵', s.wood),
            _stockChip('🪨', s.stone),
            _stockChip('⚙', s.iron),
          ],
        ),
        const SizedBox(height: 11),
        _sectionTitle('CANLI TEŞHİS'),
        if (s.warnings.isEmpty)
          _diagnostic(
            Icons.check_circle_outline,
            'Belirgin bir darboğaz yok',
            AppUi.sage,
          )
        else
          for (final warning in s.warnings)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _diagnostic(
                Icons.warning_amber_rounded,
                warning,
                AppUi.accent,
              ),
            ),
        const SizedBox(height: 9),
        Text(
          'Bu ekran yalnız gerçek köy state’ini okur. Değişiklik yapmak için '
          'Dünya veya Eylem sekmesini kullan.',
          style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textLo),
        ),
      ],
    );
  }

  Widget _worldTab() {
    final s = widget.snapshot;
    return Column(
      key: const ValueKey('village-tester-world'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('SİMÜLASYON HIZI'),
        Row(
          children: [
            for (final speed in const [0.0, 1.0, 4.0, 12.0]) ...[
              Expanded(
                child: _choiceButton(
                  speed == 0 ? '⏸' : '${speed.toInt()}×',
                  (s.speed - speed).abs() < 0.1,
                  () => widget.onSetSpeed(speed),
                ),
              ),
              if (speed != 12.0) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _sectionTitle('GÜNÜN SAATİ'),
        Row(
          children: [
            for (final item in const [
              (0.22, 'Şafak'),
              (0.50, 'Öğle'),
              (0.78, 'Akşam'),
              (0.92, 'Gece'),
            ]) ...[
              Expanded(
                child: _choiceButton(
                  item.$2,
                  (s.timeOfDay - item.$1).abs() < 0.035,
                  () => widget.onSetTime(item.$1),
                ),
              ),
              if (item.$1 != 0.92) const SizedBox(width: 5),
            ],
          ],
        ),
        const SizedBox(height: 12),
        _sectionTitle('HAVA'),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _smallAction('Açık', Icons.wb_sunny_outlined, () {
              widget.onSetWeather(VillageTesterWeather.clear);
            }),
            _smallAction('Yağmur', Icons.water_drop_outlined, () {
              widget.onSetWeather(VillageTesterWeather.rain);
            }),
            _smallAction('Fırtına', Icons.thunderstorm_outlined, () {
              widget.onSetWeather(VillageTesterWeather.storm);
            }),
            _smallAction('Kar', Icons.ac_unit, () {
              widget.onSetWeather(VillageTesterWeather.snow);
            }),
          ],
        ),
        const SizedBox(height: 12),
        _sectionTitle('KAYNAK ENJEKSİYONU'),
        Container(
          padding: const EdgeInsets.fromLTRB(10, 4, 5, 4),
          decoration: BoxDecoration(
            color: AppUi.surface0,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: AppUi.line),
          ),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ResourceKind>(
                    key: const ValueKey('village-tester-resource-picker'),
                    value: _resource,
                    dropdownColor: AppUi.surface2,
                    style: AppUi.bodyHi.copyWith(fontSize: 11.5),
                    isDense: true,
                    items: [
                      for (final kind in ResourceKind.values)
                        DropdownMenuItem(
                          value: kind,
                          child: Text('${kind.icon} ${kind.label}'),
                        ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _resource = value);
                    },
                  ),
                ),
              ),
              _resourceButton('−10', -10),
              _resourceButton('+10', 10),
              _resourceButton('+50', 50),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Değerler doğrudan bu koşuya uygulanır; yeni köy kurulmaz.',
          style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
        ),
      ],
    );
  }

  Widget _actionTab(BuildContext context) => Column(
    key: const ValueKey('village-tester-actions'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _sectionTitle('KÖYLÜLER'),
      _actionGrid([
        ('Köylü ekle', Icons.person_add_alt, widget.onSpawnVillager),
        ('Herkesi uyandır', Icons.wb_sunny_outlined, widget.onWakeAll),
      ]),
      const SizedBox(height: 12),
      _sectionTitle('DAVRANIŞ SAHNESİ'),
      _actionGrid([
        ('Sohbet', Icons.forum_outlined, widget.onStartChat),
        ('Dans', Icons.music_note_outlined, widget.onStartDance),
        ('Kavga', Icons.sports_mma_outlined, widget.onStartConflict),
        ('Suç', Icons.visibility_off_outlined, widget.onStartCrime),
      ]),
      const SizedBox(height: 12),
      _sectionTitle('DIŞ DÜNYA'),
      _actionGrid([
        ('Kervan', Icons.local_shipping_outlined, widget.onSpawnCaravan),
        ('Yolcu', Icons.hiking_outlined, widget.onSpawnTraveler),
        ('Yabancı', Icons.person_search_outlined, widget.onSpawnStranger),
      ]),
      const SizedBox(height: 6),
      Text(
        'Yeni seçim mevcut test ziyaretçi grubunun yerini alır.',
        style: AppUi.body.copyWith(fontSize: 10, color: AppUi.textLo),
      ),
      const SizedBox(height: 12),
      _sectionTitle('KOŞU ARAÇLARI'),
      _actionGrid([
        (
          widget.snapshot.godMode ? 'God mode açık' : 'God mode',
          Icons.shield_outlined,
          widget.onToggleGod,
        ),
        (
          'Aktiviteyi temizle',
          Icons.cleaning_services,
          widget.onClearActivities,
        ),
        (
          'Efektleri temizle',
          Icons.layers_clear_outlined,
          widget.onClearEffects,
        ),
      ]),
      if (widget.onFreshRun != null) ...[
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            key: const ValueKey('village-tester-fresh-run'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppUi.rust,
              side: BorderSide(color: AppUi.rust.withValues(alpha: 0.7)),
            ),
            onPressed: () => _confirmFreshRun(context),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('YENİ DOĞAL KOŞU'),
          ),
        ),
      ],
    ],
  );

  Future<void> _confirmFreshRun(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppUi.surface1,
        title: const Text('Yeni doğal koşu', style: AppUi.title),
        content: const Text(
          'Bu geçici tester köyü bırakılıp başka bir rastgele dünyada normal '
          'kuruluş başlatılacak.',
          style: AppUi.body,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('VAZGEÇ'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('YENİDEN BAŞLAT'),
          ),
        ],
      ),
    );
    if (confirmed == true) widget.onFreshRun?.call();
  }

  Widget _sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Text(
      text,
      style: AppUi.label.copyWith(color: AppUi.textMid, letterSpacing: 0.7),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 5),
    child: Row(
      children: [
        Expanded(child: Text(label, style: AppUi.body)),
        Text(value, style: AppUi.bodyHi.copyWith(fontSize: 11.5)),
      ],
    ),
  );

  Widget _stockChip(String icon, int value) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
    decoration: BoxDecoration(
      color: AppUi.surface0,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppUi.line),
    ),
    child: Text('$icon $value', style: AppUi.number.copyWith(fontSize: 11)),
  );

  Widget _diagnostic(IconData icon, String text, Color color) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: 0.35)),
    ),
    child: Row(
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: AppUi.body.copyWith(fontSize: 10.5, color: AppUi.textMid),
          ),
        ),
      ],
    ),
  );

  Widget _choiceButton(String label, bool selected, VoidCallback onTap) =>
      SizedBox(
        height: 34,
        child: Material(
          color: selected
              ? AppUi.accent.withValues(alpha: 0.18)
              : AppUi.surface0,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: onTap,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: selected ? AppUi.accent : AppUi.line),
              ),
              child: Text(
                label,
                style: AppUi.label.copyWith(
                  color: selected ? AppUi.accentSoft : AppUi.textMid,
                ),
              ),
            ),
          ),
        ),
      );

  Widget _smallAction(String label, IconData icon, VoidCallback onTap) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppUi.textMid,
          side: const BorderSide(color: AppUi.line),
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
          visualDensity: VisualDensity.compact,
        ),
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: AppUi.label),
      );

  Widget _resourceButton(String label, int amount) => TextButton(
    style: TextButton.styleFrom(
      minimumSize: const Size(42, 32),
      padding: const EdgeInsets.symmetric(horizontal: 5),
      visualDensity: VisualDensity.compact,
    ),
    onPressed: () => widget.onAddResource(_resource, amount),
    child: Text(label, style: AppUi.label.copyWith(color: AppUi.accentSoft)),
  );

  Widget _actionGrid(List<(String, IconData, VoidCallback)> actions) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [
      for (final action in actions)
        SizedBox(
          width: 140,
          child: _smallAction(action.$1, action.$2, action.$3),
        ),
    ],
  );

  String _clock(double hour) {
    final h = hour.floor() % 24;
    final m = ((hour - hour.floor()) * 60).round() % 60;
    return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';
  }
}
