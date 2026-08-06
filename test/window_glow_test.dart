// PENCERE IŞIĞI — "köy yattı" sinyalinin görünen yarısı.
//
// Gece kurulmadan önce bütün evler sabaha kadar aynı parlaklıkta yanıyordu:
// köylüler yatsa da köy hep uyanık görünüyordu. Artık evin camı sakinlerinin
// UYANIK oranından türüyor ([BuildingEntity.windowGlow]).
//
// Bu testin derdi tek bir regresyon: alan yazılıp TÜKETİCİYE BAĞLANMAMASI.
// Değer sim tarafında hesaplanıp ışık toplayıcısı onu okumazsa hiçbir şey
// değişmez ve kimse fark etmez — bu projede "bağlanmayan alan" tam olarak
// bu yüzden yasak.

import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_entity.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/systems/lighting_system.dart';

/// Konut ışığının sıcak rengi — toplayıcı ateş/fener/işyeri ışıklarını da
/// döndürüyor, ev ışığını renginden ayırıyoruz.
const _kHousingWarm = 0xFFFFC868;

BuildingEntity _house(double glow) => BuildingEntity(
      type: BuildingType.woodenHouse,
      col: 5,
      row: 5,
    )
      ..occupants = 2
      ..windowGlow = glow;

List<LightSource> _housingLights(double glow) => LightingSystem.collect(
      buildings: [_house(glow)],
      villagers: [],
      dayLight: 0.0, // tam gece
    ).where((l) => l.warm.toARGB32() == _kHousingWarm).toList();

void main() {
  group('pencere ışığı sakinin uyanıklığından türer', () {
    test('uyanık ev tam yanar', () {
      final lights = _housingLights(1.0);
      expect(lights, hasLength(1));
      expect(lights.first.intensity, greaterThan(0.9));
    });

    test('yarısı uyuyan ev yarı parlar', () {
      expect(_housingLights(0.35).first.intensity, closeTo(0.35, 0.02));
    });

    test('herkes uyuduğunda ışık büsbütün söner', () {
      // Sönük ışık kaynağı listeye HİÇ girmemeli: 0 yoğunluklu kaynak,
      // gece ışığı geçişinde bedava değil (her kaynak bir saveLayer dairesi).
      expect(_housingLights(0.0), isEmpty);
    });

    test('boş evin camı yanmaz — sakini olmayan ev ışık kaynağı değil', () {
      final empty = _house(1.0)..occupants = 0;
      final lights = LightingSystem.collect(
        buildings: [empty],
        villagers: [],
        dayLight: 0.0,
      ).where((l) => l.warm.toARGB32() == _kHousingWarm);
      expect(lights, isEmpty);
    });
  });
}
