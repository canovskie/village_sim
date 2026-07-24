import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/dev/dev_command.dart';

/// Senaryo kayıt/oynatmanın omurgası: kaydedilen adımlar diske yazılıp geri
/// okunduğunda BİREBİR aynı komut+argümanları vermeli. Bozulursa "aynı durumu
/// tekrar kur" vaadi sessizce çöker.
void main() {
  group('DevScript serileştirme', () {
    test('encode → decode round-trip argümanları korur', () {
      const script = DevScript('Politik Fırtına', [
        DevInvocation('feud.ignite'),
        DevInvocation('spawn.migrant', {'count': 3}),
        DevInvocation('time.set', {'phase': 'night'}),
      ]);

      final back = DevScript.tryDecode(script.encode());

      expect(back, isNotNull);
      expect(back!.name, 'Politik Fırtına');
      expect(back.steps.length, 3);
      expect(back.steps[1].commandId, 'spawn.migrant');
      expect(back.steps[1].args['count'], 3);
      expect(back.steps[2].args['phase'], 'night');
    });

    test('bozuk JSON null döner (çökme yok)', () {
      expect(DevScript.tryDecode('{bozuk'), isNull);
      expect(DevScript.tryDecode(''), isNull);
    });
  });

  group('DevRecorder', () {
    test('kayıt kapalıyken adım yakalamaz', () {
      final rec = DevRecorder();
      rec.capture('spawn.villager', {'count': 2});
      expect(rec.steps, isEmpty);
    });

    test('kayıt açıkken yakalar, freeze senaryoyu verip tamponu boşaltır', () {
      final rec = DevRecorder()..toggle();
      rec.capture('spawn.villager', {'count': 2});
      rec.capture('time.set', {'phase': 'dawn'});

      final s = rec.freeze('Testim');

      expect(s.name, 'Testim');
      expect(s.steps.length, 2);
      expect(s.builtin, isFalse);
      expect(rec.steps, isEmpty, reason: 'freeze tamponu boşaltmalı');
      expect(rec.recording, isFalse, reason: 'freeze kaydı kapatmalı');
    });

    test('yakalanan argümanlar kopyalanır (sonraki mutasyondan etkilenmez)', () {
      final rec = DevRecorder()..toggle();
      final live = <String, Object?>{'count': 1};
      rec.capture('spawn.villager', live);
      live['count'] = 99;

      expect(rec.steps.first.args['count'], 1);
    });
  });

  group('DevCommand parametreleri', () {
    test('defaultArgs tanımlı varsayılanları verir', () {
      final cmd = DevCommand(
        id: 'x',
        label: 'X',
        category: DevCat.digerleri,
        params: const [
          DevParam.integer('count', 'Adet', intDefault: 5),
          DevParam.choice('phase', 'Vakit', [('a', 'A'), ('b', 'B')],
              choiceDefault: 'b'),
        ],
        run: (_) {},
      );

      expect(cmd.hasParams, isTrue);
      expect(cmd.defaultArgs(), {'count': 5, 'phase': 'b'});
    });

    test('choiceDefault yoksa ilk seçenek varsayılan olur', () {
      const p = DevParam.choice('k', 'K', [('ilk', 'İlk'), ('son', 'Son')]);
      expect(p.defaultValue(), 'ilk');
    });
  });
}
