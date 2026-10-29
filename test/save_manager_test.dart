import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/save/save_manager.dart';
import 'package:village_sim/save/save_queue.dart';

Map<String, dynamic> save(String id, int day) => {
  'version': SaveManager.schemaVersion,
  'meta': SaveSlotMeta(
    id: id,
    name: 'Köy',
    savedAt: DateTime.fromMillisecondsSinceEpoch(1000 + day),
    day: day,
    population: 5,
    identity: 'Dengeli Köy',
  ).toJson(),
  'world': {'day': day},
};

void main() {
  late Directory dir;
  final manager = SaveManager.instance;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('village_saves_');
    manager.useDirectoryForTest(dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('a second write replaces the slot and leaves no temp file', () async {
    await manager.writeSlot('a', save('a', 1));
    await manager.writeSlot('a', save('a', 2));
    expect((await manager.readSlot('a'))!['world'], {'day': 2});
    expect(
      dir.listSync().whereType<File>().where((f) => f.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('a complete temp file is promoted when its slot is missing', () async {
    File(
      '${dir.path}/village_b.json.tmp',
    ).writeAsStringSync(jsonEncode(save('b', 7)));
    final slots = await manager.listSlots();
    expect(slots.map((s) => s.id), ['b']);
    expect((await manager.readSlot('b'))!['world'], {'day': 7});
  });

  test('a complete temp file replaces a damaged slot', () async {
    File('${dir.path}/village_c.json').writeAsStringSync('{"meta":');
    File(
      '${dir.path}/village_c.json.tmp',
    ).writeAsStringSync(jsonEncode(save('c', 9)));
    expect((await manager.readSlot('c'))!['world'], {'day': 9});
  });

  test('a half-written temp file never replaces a good slot', () async {
    await manager.writeSlot('d', save('d', 3));
    File(
      '${dir.path}/village_d.json.tmp',
    ).writeAsStringSync('{"meta":{"id":"d"},"wor');
    expect((await manager.readSlot('d'))!['world'], {'day': 3});
    expect((await manager.listSlots()).map((s) => s.id), ['d']);
  });

  test(
    'a save asked for during a write waits and captures the latest state',
    () async {
      final queue = SaveQueue();
      final gate = Completer<void>();
      var state = 1;
      final written = <int>[];
      final first = queue.run(() async {
        final seen = state;
        await gate.future;
        written.add(seen);
      });
      expect(queue.busy, isTrue);
      await Future<void>.delayed(Duration.zero); // the first write starts and captures state 1
      state = 2; // the village moves on while the first write is still running
      final second = queue.run(() async => written.add(state));
      await Future<void>.delayed(Duration.zero);
      expect(written, isEmpty, reason: 'the second save waits for the first');
      gate.complete();
      await Future.wait([first, second]);
      expect(written, [1, 2], reason: 'the later save wrote the newer state');
      expect(queue.busy, isFalse);
    },
  );

  test('a failed write does not stop the saves behind it', () async {
    final queue = SaveQueue();
    final failed = queue.run(() async => throw StateError('disk full'));
    var ran = false;
    final next = queue.run(() async => ran = true);
    await expectLater(failed, throwsStateError);
    await next;
    expect(ran, isTrue);
  });
}
