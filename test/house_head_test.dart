import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/characters/life_stage.dart';
import 'package:village_sim/characters/villager_type.dart';
import 'package:village_sim/entities/villager_entity.dart';
import 'package:village_sim/systems/house_head.dart';

/// Divan masasında oturan yüzler GERÇEK hane reisleri olmalı — rastgele değil.
/// Bu testler seçim kuralını ve determinizmini kilitler.

VillagerEntity _v(String name,
    {required bool male, required double age, String surname = 'Demirhan'}) {
  return VillagerEntity(
    type: VillagerType.farmer,
    name: name,
    surname: surname,
    male: male,
    startCol: 0,
    startRow: 0,
    ageDays: age,
  );
}

void main() {
  group('headOfHouse', () {
    test('boş hane → reis yok', () {
      expect(headOfHouse([]), isNull);
    });

    test('en yaşlı yetişkin ERKEĞİ seçer (soy erkekten yürür)', () {
      final genc = _v('Genç', male: true, age: 5);
      final yasli = _v('Yaşlı', male: true, age: 40);
      final kadin = _v('Nine', male: false, age: 60); // daha yaşlı ama kadın
      expect(headOfHouse([genc, yasli, kadin])!.name, 'Yaşlı');
    });

    test('yetişkin erkek yoksa en yaşlı yetişkin kadın reis olur', () {
      final anne = _v('Anne', male: false, age: 30);
      final abla = _v('Abla', male: false, age: 12);
      final oglan = _v('Oğlan', male: true, age: 1); // çocuk → yetişkin değil
      expect(headOfHouse([abla, anne, oglan])!.name, 'Anne');
    });

    test('hiç yetişkin yoksa en yaşlı üye (öksüz hane) temsil eder', () {
      final a = _v('Küçük', male: true, age: 0.4);
      final b = _v('Büyük', male: false, age: 1.8);
      final head = headOfHouse([a, b])!;
      expect(head.lifeStage.hasProfession, isFalse, reason: 'ikisi de çocuk');
      expect(head.name, 'Büyük');
    });

    test('liste sırası değişse de AYNI reis (deterministik, rastgele değil)', () {
      final m = [
        _v('Ali', male: true, age: 20),
        _v('Veli', male: true, age: 35),
        _v('Ayşe', male: false, age: 50),
        _v('Can', male: true, age: 8),
      ];
      final expected = headOfHouse([...m])!.name;
      expect(expected, 'Veli');
      // Her permütasyonda aynı sonuç çıkmalı.
      for (var i = 0; i < m.length; i++) {
        final rotated = [...m.sublist(i), ...m.sublist(0, i)];
        expect(headOfHouse(rotated)!.name, expected);
      }
      expect(headOfHouse(m.reversed.toList())!.name, expected);
    });

    test('yaş eşitse ad alfabetik kırar → masadaki yüz zıplamaz', () {
      final a = _v('Zeki', male: true, age: 30);
      final b = _v('Ahmet', male: true, age: 30);
      expect(headOfHouse([a, b])!.name, 'Ahmet');
      expect(headOfHouse([b, a])!.name, 'Ahmet');
    });

    test('tek kişilik hane → o kişi reistir', () {
      final tek = _v('Yalnız', male: false, age: 22);
      expect(headOfHouse([tek])!.name, 'Yalnız');
    });
  });
}
