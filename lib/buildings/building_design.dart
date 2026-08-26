import 'building_type.dart';

/// Bir binanın işlevinden bağımsız görsel tasarımı.
///
/// [BuildingType] maliyet, ayak izi ve üretimi belirler; bu enum yalnız sprite
/// seçer. Böylece aynı ev farklı görünebilir ama hâlâ aynı ev olarak davranır.
enum BuildingDesign { original, terracotta, garden, artisan }

const Map<BuildingType, List<BuildingDesign>> kBuildingDesigns = {
  BuildingType.woodenHouse: [
    BuildingDesign.original,
    BuildingDesign.terracotta,
    BuildingDesign.garden,
    BuildingDesign.artisan,
  ],
};

List<BuildingDesign> buildingDesignsFor(BuildingType type) =>
    kBuildingDesigns[type] ?? const [BuildingDesign.original];

BuildingDesign normalizeBuildingDesign(
  BuildingType type,
  BuildingDesign design,
) {
  final designs = buildingDesignsFor(type);
  return designs.contains(design) ? design : BuildingDesign.original;
}

/// Yeni kurulumlarda karışık ama tekrar üretilebilir seçim.
///
/// Gerçek RNG kullanmıyoruz: kayıt yüklenince ya da placement paneli yeniden
/// açılınca evin görünüşü zıplamamalı. Tür + kurulum sırası hash'lenir; komşu
/// sıralar aynı varyanta düşerse ikinci bir adımla ayrılır. Sonuç, bariz
/// `Klasik → Kiremitli → ...` döngüsü olmadan doğal bir sokak siluetidir.
BuildingDesign automaticBuildingDesign(BuildingType type, int ordinal) {
  final designs = buildingDesignsFor(type);
  if (designs.length < 2) return designs.first;

  final safeOrdinal = ordinal.abs();
  int pick(int n) {
    var x = (type.index * 0x9E3779B1 + n * 0x85EBCA6B) & 0x7FFFFFFF;
    x ^= x >> 16;
    x = (x * 0x45D9F3B) & 0x7FFFFFFF;
    x ^= x >> 16;
    return x % designs.length;
  }

  // Önceki SONUCU da hesaba kat: önceki ham hash çakışmamış görünse bile o
  // sonuç bir önceki çakışmada kaydırılmış olabilir. Kurulum sayıları köy
  // ölçeğinde küçük; bu kısa yürüyüş depolama alanı eklemekten daha güvenli.
  var previous = -1;
  var index = 0;
  for (var i = 0; i <= safeOrdinal; i++) {
    index = pick(i);
    if (index == previous) {
      // Aynı çatı yan yana iki kez gelmesin; sıçrama yine hash'ten beslensin.
      index =
          (index + 1 + (pick(i + 97) % (designs.length - 1))) % designs.length;
    }
    previous = index;
  }
  return designs[index];
}

BuildingDesign nextBuildingDesign(BuildingType type, BuildingDesign current) {
  final designs = buildingDesignsFor(type);
  if (designs.length < 2) return designs.first;
  final index = designs.indexOf(normalizeBuildingDesign(type, current));
  return designs[(index + 1) % designs.length];
}

extension BuildingDesignLabel on BuildingDesign {
  String get label => switch (this) {
    BuildingDesign.original => 'Klasik',
    BuildingDesign.terracotta => 'Kiremitli',
    BuildingDesign.garden => 'Bahçeli',
    BuildingDesign.artisan => 'Usta Evi',
  };
}
