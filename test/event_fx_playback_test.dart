import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/systems/events/event_system.dart';

void main() {
  test('olay efekti kendi süresinde sıfırdan bire ilerler', () {
    const start = EventFxPlayback(elapsed: 0, duration: 10, timeLeft: 10);
    const middle = EventFxPlayback(elapsed: 5, duration: 10, timeLeft: 5);
    const end = EventFxPlayback(elapsed: 10, duration: 10, timeLeft: 0);

    expect(start.progress, 0);
    expect(middle.progress, 0.5);
    expect(end.progress, 1);
  });

  test('giriş ve çıkış zarfı olay sınırlarında yumuşar', () {
    const entering = EventFxPlayback(elapsed: 0.5, duration: 10, timeLeft: 9.5);
    const settled = EventFxPlayback(elapsed: 4, duration: 10, timeLeft: 6);
    const leaving = EventFxPlayback(elapsed: 9.5, duration: 10, timeLeft: 0.5);

    expect(entering.envelope(enter: 1, exit: 1), closeTo(0.5, 0.0001));
    expect(settled.envelope(enter: 1, exit: 1), 1);
    expect(leaving.envelope(enter: 1, exit: 1), closeTo(0.5, 0.0001));
  });
}
