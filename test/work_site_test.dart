import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/entities/villager_job.dart';
import 'package:village_sim/entities/work_site.dart';

/// İŞ YERİ SÖZLEŞMESİ.
///
/// İş verme kişiden yere taşındığında (rol rozetleri → kadro yuvaları) bütün
/// etkileşim tek bir sayıya bağlandı: bir iş yerinin kaç yuva göstereceği.
/// Bu dosya o sayının sözleşmesini korur — yuva sayısı bozulursa oyuncu ya
/// köye fazladan el veremez ya da kaç el gerektiğini okuyamaz hâle gelir.
void main() {
  VillagerEntity mk(String name) => VillagerEntity(
    name: name,
    type: VillagerType.farmer,
    male: true,
    startCol: 0,
    startRow: 0,
  );

  WorkSite site({
    required int wanted,
    List<VillagerEntity> crew = const [],
    String? idleReason,
  }) => WorkSite(
    id: 'b:1,1:miner',
    kind: WorkSiteKind.building,
    role: JobRole.miner,
    label: 'Maden Ocağı',
    wanted: wanted,
    cx: 1,
    cy: 1,
    crew: crew,
    idleReason: idleReason,
  );

  group('yuva sayısı', () {
    test('boş iş yeri köyün istediği kadar yuva gösterir', () {
      expect(site(wanted: 1).slots, 1);
      expect(site(wanted: 3).slots, 3);
    });

    test('kadro dolduğunda HEP bir boş yuva daha kalır', () {
      // Sözleşmenin kalbi: köyün istediğinden fazla el vermek (üç oduncu tek
      // kampa) geçerli bir karardır ve rozet döneminde de mümkündü. Yuva
      // sayısını `wanted`a kilitlemek o kararı sessizce elden alırdı.
      final s = site(wanted: 1, crew: [mk('Mehmet')]);
      expect(s.slots, 2);
      expect(s.staffed, isTrue);
    });

    test('fazladan el verilse bile bir sonraki yuva açık kalır', () {
      final s = site(wanted: 1, crew: [mk('a'), mk('b'), mk('c')]);
      expect(s.slots, 4);
    });

    test('köyün istemediği yuvalar "fazladan" işaretlenir', () {
      final s = site(wanted: 2, crew: [mk('a')]);
      expect(s.isExtraSlot(0), isFalse, reason: 'ilk el köyün istediği');
      expect(s.isExtraSlot(1), isFalse, reason: 'ikinci el de istenen');
      expect(s.isExtraSlot(2), isTrue, reason: 'üçüncüsü fazladan');
    });

    test('köyün hiç istemediği yer (wanted 0) yine de bir yuva açar', () {
      // Kışın donan göl, mevsimi geçmiş tezgâh: iş bugün yürümüyor ama yuva
      // kapanmaz. Kapatsaydık oyuncunun verdiği karar mevsim dönünce
      // kendiliğinden silinirdi.
      final s = site(wanted: 0, idleReason: 'Göl dondu.');
      expect(s.slots, 1);
      expect(s.starving, isFalse, reason: 'istemiyorsa aç da değildir');
    });
  });

  group('kadro hâli', () {
    test('isteyip kimseyi bulamayan yer AÇ sayılır', () {
      expect(site(wanted: 1).starving, isTrue);
      expect(site(wanted: 1).staffed, isFalse);
    });

    test('bir el gelince açlık düşer', () {
      final s = site(wanted: 1, crew: [mk('Mehmet')]);
      expect(s.starving, isFalse);
      expect(s.staffed, isTrue);
    });

    test('eksik kadro ne aç ne tam — arada bir hâl', () {
      final s = site(wanted: 3, crew: [mk('a')]);
      expect(s.starving, isFalse, reason: 'kimse yok değil');
      expect(s.staffed, isFalse, reason: 'ama yeterli de değil');
    });
  });

  test('her JobRole bir etiket ve ikon taşır — yeni rol eklenince burası çöker',
      () {
    // Yuva başlığı role.icon + role.label ile çizilir; biri boş kalırsa
    // panelde adsız bir yuva belirir.
    for (final r in JobRole.values) {
      expect(r.icon, isNotEmpty, reason: '${r.name} ikonsuz');
      if (r == JobRole.none) continue;
      expect(r.label, isNotEmpty, reason: '${r.name} etiketsiz');
    }
  });
}
