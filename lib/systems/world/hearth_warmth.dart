/// OCAĞIN SICAĞI — çadırın ateşe uzaklığı kışın gerçek bir bedele dönüşür.
///
/// Gerçek evin kendi ocağı vardır: duvar kalın, kapı kapanır, içerisi ısınır.
/// ÇADIRIN yoktur. Bezin altındaki tek sıcaklık köyün ateşinden gelendir. Bu
/// yüzden çadırın NEREYE kurulduğu kışın bir karardır: meydanın kenarına
/// kurulan çadır geceyi atlatır, köyün ucundaki çadır sabaha kadar üşür.
///
/// Saf/yan-etkisiz: yalnızca mesafeden bir sıcaklık (0..1) üretir. Kimin çadırda
/// yaşadığı, mevsimin ne olduğu, ocakta yakıt kalıp kalmadığı çağıranın işi.
/// Tüketiciler: moral (`villager_morale.coldShelter`), üşüme dürtüsü ve gece
/// titreyerek uyanma (`scene_shelter`), yerleştirme önizlemesi (`game_painter`).
library;

import 'dart:math';

/// Bu yarıçapa kadar (tile) ocak çadırı tam ısıtır. Ateş yerinin `effectRadius`
/// değeri (4.0) ışık/toplanma menzilidir; ısı ondan biraz geniş bir mahalleye
/// yayılır — ateşin çevresine dizilen çadırlar hep beraber ısınsın.
const double kHearthWarmRadius = 5.0;

/// Bu yarıçaptan sonra (tile) ocağın çadıra hiçbir faydası kalmaz.
///
/// Arada YUMUŞAK bant var, keskin çizgi değil: tek tile'lık bir kayma kaderi
/// değiştirseydi oyuncu görünmez bir sınıra karşı piksel avlardı. Bant sayesinde
/// "biraz uzak" ile "köyün ucunda" arasındaki fark da hissedilir.
const double kHearthColdRadius = 9.0;

/// Barınağın ocaktan aldığı sıcaklık, 0..1. [dx]/[dy] barınak merkezi ile ocak
/// merkezi arasındaki tile farkı. Ocak sönükse ([burning] false) sıcaklık yok —
/// kışın ateşin sönmesi çadır mahallesini topluca üşütür.
double hearthWarmth({
  required double dx,
  required double dy,
  required bool burning,
}) {
  if (!burning) return 0;
  final d = sqrt(dx * dx + dy * dy);
  if (d <= kHearthWarmRadius) return 1;
  if (d >= kHearthColdRadius) return 0;
  return 1 - (d - kHearthWarmRadius) / (kHearthColdRadius - kHearthWarmRadius);
}

/// Sıcaklığın altına düşünce barınak "soğuk" sayılır. Bandın ortasından biraz
/// aşağıda: yumuşak bandın ilk yarısı hâlâ idare eder.
const double kColdShelterThreshold = 0.45;

/// Bu barınak kışın üşütür mü? Üç koşul birden: derme çatma barınak (çadır) +
/// kış + ocağın sıcağının ulaşmaması. Evi olan ya da yazın çadırda yaşayan
/// köylünün böyle bir derdi yoktur.
bool shelterIsCold({
  required bool tent,
  required bool winter,
  required double warmth,
}) =>
    tent && winter && warmth < kColdShelterThreshold;

/// Çadır ocağın TAM ısıttığı mahallede mi — "ocak başında" sayılmanın koşulu.
/// Kışın üşümemek yetmez; asıl karşılığı (moralde `hearthWarmth`) ateşin
/// çevresine kurulmuş çadır alır. Arada kalan bant ne ödüllendirilir ne
/// cezalandırılır: idare eder.
bool shelterAtHearth(double warmth) => warmth >= 1.0;

/// Soğuk çadırın üşüme dürtüsünü ne kadar hızlandırdığı. Sıcaklık düştükçe
/// büyür (1.0 → 1.9): ocağın dibindeki çadırla köyün ucundaki çadır aynı
/// gecede aynı şeyi yaşamaz.
double coldShelterDriveMultiplier(double warmth) =>
    1.0 + (1.0 - warmth.clamp(0.0, 1.0)) * 0.9;
