// Kanunname harness'ları için "olgun köy" bağlamı.
//
// Hükümler artık köyün HÂLİNE göre kademe kademe açılıyor (bkz. law_book.dart
// dünya kapıları). Preview harness'larında sahne yok — bağlam boş verilirse
// defter neredeyse tamamen kapalı çıkar ve UI'ı göremeyiz. Bu yüzden görsel
// doğrulama koşuları "her kapıyı açan" tek bir olgun köy bağlamı kullanır.
// OYUN KODU DEĞİL, yalnız capture/preview içindir.
import '../buildings/building_type.dart';
import '../buildings/craft.dart';
import '../systems/law_book.dart';

const LawContext kDemoLawContext = LawContext(
  population: 18,
  dayCount: 41,
  villageMorale: 0.62,
  households: 4,
  children: 3,
  elders: 2,
  farmTiles: 6,
  animals: 7,
  deaths: 2,
  crimesSeen: 4,
  knownCrafts: {
    Craft.carpentry,
    Craft.farming,
    Craft.husbandry,
    Craft.faith,
    Craft.milling,
  },
  buildings: {
    BuildingType.well,
    BuildingType.warehouse,
    BuildingType.barn,
    BuildingType.lumberCamp,
    BuildingType.church,
  },
);
