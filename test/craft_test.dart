import 'package:flutter_test/flutter_test.dart';
import 'package:village_sim/buildings/building_type.dart';
import 'package:village_sim/buildings/craft.dart';
import 'package:village_sim/characters/villager_type.dart';

/// Zanaat kilidi veri bütünlüğü — yeni bina/meslek eklenip eşleme unutulursa
/// (kBuildingCraft / kCallingCraft) burada patlar. Kilit sessizce "fail-open"
/// olmasın diye her gerçek bina bir zanaat kararına bağlı olmalı.
void main() {
  test('kBuildingMeta içindeki her bina kBuildingCraft ile eşlenmiş', () {
    for (final t in kBuildingMeta.keys) {
      expect(kBuildingCraft.containsKey(t), isTrue,
          reason: '$t için craft eşlemesi eksik (kBuildingCraft)');
    }
  });

  test('bina zanaat değerleri geçerli (null=ortak ya da Craft.all içinde)', () {
    kBuildingCraft.forEach((building, craft) {
      if (craft != null) {
        expect(Craft.all.contains(craft), isTrue,
            reason: '$building geçersiz zanaata bağlı: $craft');
      }
    });
  });

  test('her VillagerType kCallingCraft ile eşlenmiş', () {
    for (final t in VillagerType.values) {
      expect(kCallingCraft.containsKey(t), isTrue,
          reason: '$t için çağrı-zanaat eşlemesi eksik (kCallingCraft)');
    }
  });

  test('çağrı zanaat değerleri geçerli', () {
    kCallingCraft.forEach((type, craft) {
      if (craft != null) {
        expect(Craft.all.contains(craft), isTrue,
            reason: '$type geçersiz zanaata bağlı: $craft');
      }
    });
  });

  test('her zanaatın Türkçe adı var (anahtara düşmez)', () {
    for (final c in Craft.all) {
      expect(Craft.displayName(c), isNot(equals(c)),
          reason: '$c için displayName eksik');
    }
  });

  test('yapı zanaatları (birikim) çağrıdan gelmez', () {
    // Marangozluk/taş ustalığı yalnız birikimle doğar — hiçbir meslek onları
    // taşımamalı (aksi halde iki kanaldan çift açılır, tasarım ihlali).
    for (final craft in Craft.structural) {
      expect(kCallingCraft.values.contains(craft), isFalse,
          reason: '$craft bir mesleğe bağlanmış ama yapı zanaatı olmalı');
    }
  });
}
