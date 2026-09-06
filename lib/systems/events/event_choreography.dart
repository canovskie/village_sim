/// Olay sahnelerinin saf zaman çizgisi.
///
/// Dünya/NPC bilgisi taşımaz. Sahne katmanı köylüleri seçer ve [signals]
/// üzerinden ilgili beat'e ait koreografiyi başlatır. Böylece olay dosyaları
/// birbirinden bağımsız kalır; yönetmen yalnız sıra, süre ve çakışmayı yönetir.
enum EventScenePhase { setup, gathering, action, resolution, dispersal }

enum EventSceneStartPolicy { replace, enqueue, ignoreIfBusy }

enum EventSceneSignalKind {
  started,
  beatEntered,
  beatExited,
  completed,
  cancelled,
}

class EventSceneBeat {
  final String id;
  final EventScenePhase phase;
  final double minimumSeconds;
  final double timeoutSeconds;
  final bool waitForCast;

  const EventSceneBeat({
    required this.id,
    required this.phase,
    this.minimumSeconds = 0,
    required this.timeoutSeconds,
    this.waitForCast = false,
  }) : assert(id != ''),
       assert(minimumSeconds >= 0),
       assert(timeoutSeconds >= minimumSeconds);
}

class EventScenePlan {
  final String eventId;
  final String variant;
  final String title;
  final List<EventSceneBeat> beats;

  const EventScenePlan({
    required this.eventId,
    this.variant = 'default',
    required this.title,
    required this.beats,
  }) : assert(eventId != ''),
       assert(variant != ''),
       assert(beats.length > 0);

  /// Eski vinyetleri hemen taşıyabilmek için güvenli beş-beat omurga.
  factory EventScenePlan.standard({
    required String eventId,
    String variant = 'default',
    required String title,
    double actionTimeout = 24,
  }) => EventScenePlan(
    eventId: eventId,
    variant: variant,
    title: title,
    beats: [
      const EventSceneBeat(
        id: 'setup',
        phase: EventScenePhase.setup,
        timeoutSeconds: 0.1,
      ),
      const EventSceneBeat(
        id: 'gather',
        phase: EventScenePhase.gathering,
        minimumSeconds: 0.4,
        timeoutSeconds: 1.2,
      ),
      EventSceneBeat(
        id: 'action',
        phase: EventScenePhase.action,
        minimumSeconds: 1,
        timeoutSeconds: actionTimeout,
        waitForCast: true,
      ),
      const EventSceneBeat(
        id: 'resolve',
        phase: EventScenePhase.resolution,
        timeoutSeconds: 0.5,
      ),
      const EventSceneBeat(
        id: 'disperse',
        phase: EventScenePhase.dispersal,
        timeoutSeconds: 0.2,
      ),
    ],
  );

  String get key => '$eventId:$variant';
}

class EventSceneSignal {
  final EventSceneSignalKind kind;
  final EventScenePlan plan;
  final EventSceneBeat? beat;

  const EventSceneSignal(this.kind, this.plan, [this.beat]);
}

class EventSceneRun {
  final EventScenePlan plan;
  int beatIndex = 0;
  double elapsed = 0;
  double beatElapsed = 0;

  EventSceneRun(this.plan);

  EventSceneBeat get beat => plan.beats[beatIndex];
}

/// Tek aktif sahne + isteğe bağlı kuyruk. Aynı anda iki koreografi aynı NPC'yi
/// sahiplenemez; bu karar tek yerde verilir.
class EventSceneDirector {
  EventSceneRun? _active;
  final List<EventScenePlan> _queue = [];

  EventSceneRun? get active => _active;
  List<EventScenePlan> get queued => List.unmodifiable(_queue);
  bool get isBusy => _active != null;

  List<EventSceneSignal> start(
    EventScenePlan plan, {
    EventSceneStartPolicy policy = EventSceneStartPolicy.replace,
  }) {
    final out = <EventSceneSignal>[];
    final current = _active;
    if (current != null) {
      switch (policy) {
        case EventSceneStartPolicy.ignoreIfBusy:
          return out;
        case EventSceneStartPolicy.enqueue:
          _queue.add(plan);
          return out;
        case EventSceneStartPolicy.replace:
          out.add(
            EventSceneSignal(EventSceneSignalKind.cancelled, current.plan),
          );
      }
    }
    _activate(plan, out);
    return out;
  }

  List<EventSceneSignal> tick(double dt, {required bool castIdle}) {
    if (dt <= 0 || _active == null) return const [];
    final out = <EventSceneSignal>[];
    var remaining = dt;
    // Sıfır/kısa beat'lerin tek karede güvenle ilerleyebilmesi için sınır.
    var guard = 0;
    while (remaining > 0 && _active != null && guard++ < 32) {
      final run = _active!;
      final beat = run.beat;
      final untilTimeout = beat.timeoutSeconds - run.beatElapsed;
      final step = remaining < untilTimeout ? remaining : untilTimeout;
      run.elapsed += step;
      run.beatElapsed += step;
      remaining -= step;

      final minimumMet = run.beatElapsed >= beat.minimumSeconds;
      final timedOut = run.beatElapsed >= beat.timeoutSeconds;
      final mayAdvance =
          timedOut || (beat.waitForCast && minimumMet && castIdle);
      if (!mayAdvance) break;
      _advance(out);
    }
    return out;
  }

  List<EventSceneSignal> advance() {
    if (_active == null) return const [];
    final out = <EventSceneSignal>[];
    _advance(out);
    return out;
  }

  List<EventSceneSignal> cancel({bool clearQueue = false}) {
    final run = _active;
    if (clearQueue) _queue.clear();
    if (run == null) return const [];
    final out = <EventSceneSignal>[
      EventSceneSignal(EventSceneSignalKind.cancelled, run.plan),
    ];
    _active = null;
    if (_queue.isNotEmpty) _activate(_queue.removeAt(0), out);
    return out;
  }

  void reset() {
    _active = null;
    _queue.clear();
  }

  void _activate(EventScenePlan plan, List<EventSceneSignal> out) {
    final run = EventSceneRun(plan);
    _active = run;
    out
      ..add(EventSceneSignal(EventSceneSignalKind.started, plan))
      ..add(EventSceneSignal(EventSceneSignalKind.beatEntered, plan, run.beat));
  }

  void _advance(List<EventSceneSignal> out) {
    final run = _active!;
    out.add(
      EventSceneSignal(EventSceneSignalKind.beatExited, run.plan, run.beat),
    );
    if (run.beatIndex + 1 < run.plan.beats.length) {
      run.beatIndex++;
      run.beatElapsed = 0;
      out.add(
        EventSceneSignal(EventSceneSignalKind.beatEntered, run.plan, run.beat),
      );
      return;
    }
    final completed = run.plan;
    _active = null;
    out.add(EventSceneSignal(EventSceneSignalKind.completed, completed));
    if (_queue.isNotEmpty) _activate(_queue.removeAt(0), out);
  }
}
