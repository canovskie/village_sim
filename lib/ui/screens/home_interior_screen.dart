import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../entities/villager_entity.dart';
import '../../rendering/home_interior_painter.dart';
import '../../systems/npc/home_interior.dart';
import '../../text/voice.dart';
import '../core/app_ui.dart';

/// Aynı oda: oyunda gerçek sakinleri izler, tester'da senaryoları oynatır.
class HomeInteriorScreen extends StatefulWidget {
  final List<VillagerEntity> residents;
  final List<VillagerEntity> Function()? residentSource;
  final double Function()? daylightSource;
  final bool Function()? worldPaused;
  final bool demo;
  final int decorSeed;
  final VoidCallback? onClose, onManage;
  const HomeInteriorScreen({
    super.key,
    required this.residents,
    this.residentSource,
    this.daylightSource,
    this.worldPaused,
    this.demo = false,
    this.decorSeed = 0,
    this.onClose,
    this.onManage,
  });

  @override
  State<HomeInteriorScreen> createState() => _HomeInteriorScreenState();
}

class _HomeInteriorScreenState extends State<HomeInteriorScreen>
    with SingleTickerProviderStateMixin {
  late HomeInteriorSimulation simulation;
  late List<VillagerEntity> residents;
  late final Ticker _ticker;
  final _frame = ValueNotifier<int>(0);
  Duration? _last;
  double _hudAge = 0;
  bool _paused = false, _night = false;
  double _daylight = 1;
  double _speed = 1;
  InteriorFurniture? _selected;
  late InteriorStyle _style;

  @override
  void initState() {
    super.initState();
    residents = widget.residents;
    _style = InteriorStyle.fromSeed(widget.decorSeed);
    simulation = HomeInteriorSimulation(
      residents: residents.length,
      layout: HomeInteriorLayout.fromSeed(widget.decorSeed),
    );
    _daylight = widget.daylightSource?.call() ?? 1;
    _sync();
    _ticker = createTicker(_tick)..start();
  }

  void _sync() {
    if (widget.demo) return;
    final next = widget.residentSource?.call() ?? widget.residents;
    if (next.length != residents.length ||
        next.indexed.any((e) => !identical(e.$2, residents[e.$1]))) {
      simulation = HomeInteriorSimulation(
        residents: next.length,
        layout: simulation.layout,
      );
    }
    residents = next;
    for (int i = 0; i < simulation.actors.length; i++) {
      final v = residents[i];
      simulation.syncResident(
        i,
        present: v.isInsideBuilding && v.sleepIsHome && !v.isDying,
        sleeping: v.isSleeping,
      );
    }
  }

  void _tick(Duration elapsed) {
    final dt = _last == null
        ? 0.0
        : ((elapsed - _last!).inMicroseconds / 1e6).clamp(0.0, 0.1);
    _last = elapsed;
    _sync();
    if (!_paused && widget.worldPaused?.call() != true) {
      simulation.update(dt * _speed, automatic: widget.demo);
      final target = widget.demo
          ? (_night ? 0.12 : 1.0)
          : (widget.daylightSource?.call() ?? 1);
      _daylight += (target - _daylight) * (dt * 2.5).clamp(0.0, 1.0);
      _frame.value++;
    }
    _hudAge += dt;
    if (_hudAge > 0.25) {
      _hudAge = 0;
      setState(() {});
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _frame.dispose();
    super.dispose();
  }

  Widget _control(
    String text,
    IconData icon,
    VoidCallback action, {
    bool selected = false,
    Key? key,
  }) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: TextButton.icon(
      key: key,
      onPressed: action,
      icon: Icon(icon, size: 17),
      label: Text(text),
      style: TextButton.styleFrom(
        foregroundColor: selected ? AppUi.accentSoft : AppUi.textMid,
        backgroundColor: selected ? AppUi.surface3 : AppUi.surface2,
        minimumSize: const Size(48, 44),
        textStyle: AppUi.bodyHi,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
      ),
    ),
  );

  Widget _layoutControl() => _control(
    HomeInteriorVoice.layout(simulation.layout.planIndex),
    Icons.grid_view_outlined,
    () => setState(() {
      final previous = simulation;
      simulation =
          HomeInteriorSimulation(
              residents: residents.length,
              layout: HomeInteriorLayout.fromSeed(
                widget.decorSeed,
                plan: previous.layout.planIndex + 1,
              ),
            )
            ..time = previous.time
            ..setScenario(previous.scenario);
      _selected = null;
    }),
    key: const ValueKey('interior-layout'),
  );

  Widget _styleControl() => _control(
    HomeInteriorVoice.style(_style.index),
    Icons.chair_outlined,
    () => setState(() => _style = InteriorStyle.fromSeed(_style.index + 1)),
    key: const ValueKey('interior-style'),
    selected: true,
  );

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).height < 500;
    final narrow = MediaQuery.sizeOf(context).width < 640;
    return Material(
      color: AppUi.surface0,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, compact ? 4 : 14, 8, 6),
              child: Row(
                children: [
                  Container(
                    width: 3,
                    height: 30,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: AppUi.accent,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      widget.demo
                          ? HomeInteriorVoice.lab
                          : HomeInteriorVoice.title,
                      style: AppUi.title,
                    ),
                  ),
                  if (widget.onManage != null)
                    _control(
                      HomeInteriorVoice.manage,
                      Icons.info_outline,
                      widget.onManage!,
                    ),
                  if (widget.demo && !narrow) _layoutControl(),
                  if (widget.demo && !narrow) _styleControl(),
                  if (widget.onClose != null)
                    IconButton(
                      tooltip: widget.demo
                          ? HomeInteriorVoice.outside
                          : HomeInteriorVoice.close,
                      onPressed: widget.onClose,
                      color: AppUi.textMid,
                      icon: const Icon(Icons.close),
                      constraints: const BoxConstraints(
                        minWidth: 48,
                        minHeight: 48,
                      ),
                    ),
                ],
              ),
            ),
            if (widget.demo && narrow)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [_layoutControl(), _styleControl()],
                ),
              ),
            if (widget.demo)
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    for (final value in InteriorScenario.values)
                      _control(
                        [
                          HomeInteriorVoice.daily,
                          HomeInteriorVoice.supper,
                          HomeInteriorVoice.hearth,
                          HomeInteriorVoice.sleep,
                        ][value.index],
                        [
                          Icons.home_outlined,
                          Icons.restaurant,
                          Icons.local_fire_department_outlined,
                          Icons.bedtime_outlined,
                        ][value.index],
                        () => setState(() {
                          simulation.setScenario(value);
                          _selected = null;
                        }),
                        selected: simulation.scenario == value,
                        key: ValueKey('interior-${value.name}'),
                      ),
                    const SizedBox(width: 10),
                    _control(
                      _night ? HomeInteriorVoice.night : HomeInteriorVoice.day,
                      _night
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      () => setState(() => _night = !_night),
                      key: const ValueKey('interior-light'),
                    ),
                    _control(
                      _paused
                          ? HomeInteriorVoice.resume
                          : HomeInteriorVoice.pause,
                      _paused ? Icons.play_arrow : Icons.pause,
                      () => setState(() => _paused = !_paused),
                      key: const ValueKey('interior-pause'),
                    ),
                    _control(
                      '${_speed.toInt()}×',
                      Icons.speed,
                      () => setState(() => _speed = _speed == 1 ? 2 : 1),
                    ),
                    _control(
                      HomeInteriorVoice.reset,
                      Icons.replay,
                      () => setState(() {
                        simulation = HomeInteriorSimulation(
                          residents: residents.length,
                          layout: simulation.layout,
                        );
                        _paused = false;
                        _selected = null;
                      }),
                      key: const ValueKey('interior-reset'),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 2.5,
                boundaryMargin: const EdgeInsets.all(60),
                child: LayoutBuilder(
                  builder: (_, constraints) => GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (event) => setState(
                      () => _selected = HomeInteriorPainter.hitFurniture(
                        event.localPosition,
                        constraints.biggest,
                        layout: simulation.layout,
                      ),
                    ),
                    child: DecoratedBox(
                      decoration: const BoxDecoration(
                        gradient: RadialGradient(
                          center: Alignment(0, -0.1),
                          radius: 0.85,
                          colors: [
                            Color(0xFF293333),
                            Color(0xFF11171B),
                            AppUi.surface0,
                          ],
                        ),
                      ),
                      child: RepaintBoundary(
                        child: ListenableBuilder(
                          listenable: _frame,
                          builder: (_, _) => CustomPaint(
                            key: const ValueKey('home-interior-canvas'),
                            size: constraints.biggest,
                            painter: HomeInteriorPainter(
                              simulation: simulation,
                              residents: residents,
                              daylight: _daylight,
                              style: _style,
                              selected: _selected,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.fromLTRB(
                16,
                compact ? 4 : 10,
                16,
                compact ? 4 : 12,
              ),
              decoration: const BoxDecoration(
                color: AppUi.surface1,
                border: Border(top: BorderSide(color: AppUi.line)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Row(
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 18,
                      runSpacing: 4,
                      children: [
                        if (residents.isEmpty)
                          Text(HomeInteriorVoice.empty, style: AppUi.body),
                        for (
                          int i = 0;
                          i < residents.length && i < simulation.actors.length;
                          i++
                        )
                          Text(
                            '${residents[i].name} · ${simulation.actors[i].present ? HomeInteriorVoice.activity(simulation.actors[i].activity.index) : HomeInteriorVoice.away}',
                            style: AppUi.bodyHi,
                          ),
                      ],
                    ),
                  ),
                  if (!compact && !narrow)
                    Text(
                      _selected == null
                          ? HomeInteriorVoice.hint
                          : HomeInteriorVoice.furniture(_selected!.kind.index),
                      style: AppUi.body,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
