import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/event_choreography.dart';

void main() {
  EventScenePlan plan(String id, {bool waitForCast = false}) => EventScenePlan(
    eventId: id,
    title: id,
    beats: [
      const EventSceneBeat(
        id: 'setup',
        phase: EventScenePhase.setup,
        timeoutSeconds: 1,
      ),
      EventSceneBeat(
        id: 'action',
        phase: EventScenePhase.action,
        minimumSeconds: 1,
        timeoutSeconds: 5,
        waitForCast: waitForCast,
      ),
    ],
  );

  test('beat sırası deterministik ilerler ve tamamlanır', () {
    final d = EventSceneDirector();
    expect(d.start(plan('harvest')).map((e) => e.kind), [
      EventSceneSignalKind.started,
      EventSceneSignalKind.beatEntered,
    ]);
    expect(d.active!.beat.id, 'setup');
    d.tick(1, castIdle: false);
    expect(d.active!.beat.id, 'action');
    final end = d.tick(5, castIdle: false);
    expect(end.last.kind, EventSceneSignalKind.completed);
    expect(d.isBusy, isFalse);
  });

  test('dt=0 aktif beat saatini ve sinyal akışını ilerletmez', () {
    final d = EventSceneDirector()..start(plan('still'));
    final run = d.active!;

    expect(d.tick(0, castIdle: true), isEmpty);
    expect(identical(d.active, run), isTrue);
    expect(run.beat.id, 'setup');
    expect(run.elapsed, 0);
    expect(run.beatElapsed, 0);
  });

  test('oyuncular bitince action timeout beklemeden geçer', () {
    final d = EventSceneDirector()..start(plan('fire', waitForCast: true));
    d.tick(1, castIdle: false);
    d.tick(0.5, castIdle: true);
    expect(d.isBusy, isTrue, reason: 'minimum süre dolmadan bitmemeli');
    final end = d.tick(0.5, castIdle: true);
    expect(end.last.kind, EventSceneSignalKind.completed);
  });

  test('replace iptal sinyali verir, enqueue sırayı korur', () {
    final d = EventSceneDirector()..start(plan('a'));
    expect(d.start(plan('b'), policy: EventSceneStartPolicy.enqueue), isEmpty);
    final replace = d.start(plan('c'));
    expect(replace.first.kind, EventSceneSignalKind.cancelled);
    expect(d.active!.plan.eventId, 'c');
    expect(d.queued.single.eventId, 'b');
  });

  test('enqueue planları FIFO sırasıyla başlatır', () {
    final d = EventSceneDirector()..start(plan('a'));
    d.start(plan('b'), policy: EventSceneStartPolicy.enqueue);
    d.start(plan('c'), policy: EventSceneStartPolicy.enqueue);

    final signals = d.tick(12, castIdle: false);
    final started = signals
        .where((e) => e.kind == EventSceneSignalKind.started)
        .map((e) => e.plan.eventId);
    final completed = signals
        .where((e) => e.kind == EventSceneSignalKind.completed)
        .map((e) => e.plan.eventId);

    expect(started, ['b', 'c']);
    expect(completed, ['a', 'b']);
    expect(d.active!.plan.eventId, 'c');
    expect(d.queued, isEmpty);
  });

  test('hard timeout boşta olmayan kadroyla da terminaldir', () {
    final d = EventSceneDirector()..start(plan('blocked', waitForCast: true));

    final signals = d.tick(6, castIdle: false);

    expect(signals.last.kind, EventSceneSignalKind.completed);
    expect(signals.last.plan.eventId, 'blocked');
    expect(d.isBusy, isFalse);
  });

  test('cancel kuyruğu koruyorsa sıradaki planı aktive eder', () {
    final d = EventSceneDirector()..start(plan('a'));
    d.start(plan('b'), policy: EventSceneStartPolicy.enqueue);

    final signals = d.cancel();

    expect(signals.map((e) => e.kind), [
      EventSceneSignalKind.cancelled,
      EventSceneSignalKind.started,
      EventSceneSignalKind.beatEntered,
    ]);
    expect(d.active!.plan.eventId, 'b');
    expect(d.queued, isEmpty);
  });

  test('reset aktif sahneyi ve kuyruğu birlikte temizler', () {
    final d = EventSceneDirector()..start(plan('a'));
    d.start(plan('b'), policy: EventSceneStartPolicy.enqueue);
    d.reset();
    expect(d.active, isNull);
    expect(d.queued, isEmpty);
  });
}
