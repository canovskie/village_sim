import 'dart:math' as math;

import '../world/decor_entity.dart';

/// Ambient decor sayılarının dengelendiği özgün harita alanı (48 x 36).
const int kAmbientFlowerBaseArea = 48 * 36;

/// Özgün haritadaki toplam ambient çiçek hedefi.
///
/// Yonca arı kovanı ve çiçek toplama sistemlerinde çiçek sayıldığı için bu
/// toplam dört çiçek türünün yanı sıra yoncanın da baz hedefini içerir.
const int kAmbientFlowerBaseCount = 44;

/// İki alçak bitkinin arasında bırakılan kare mesafe.
///
/// Chebyshev uzaklığı kullanılır; dolayısıyla çapraz komşu da komşudur.
const int kGroundFloraBreathingRadius = 1;

/// Ambient doğanın üstüne, gelişen köyün üretebileceği çiçekler için ayrılan
/// en küçük ve en büyük pay.
const int kVillageFlowerBudgetMin = 24;
const int kVillageFlowerBudgetMax = 64;

/// Geliştirilmiş her sekiz kare toplam köy payına bir çiçeklik yer açar.
const int kDevelopedTilesPerExtraFlower = 8;

/// Oyun sistemlerinde çiçek olarak davranan decor türleri.
///
/// Yonca görsel olarak yere yatık olsa da bal ve toplama sistemleri açısından
/// çiçektir; bu ortak sınıflama o sistemlerin birbirinden sapmasını önler.
bool isFlowerDecorKind(DecorKind kind) => switch (kind) {
  DecorKind.daisy ||
  DecorKind.poppy ||
  DecorKind.lavender ||
  DecorKind.buttercup ||
  DecorKind.clover => true,
  _ => false,
};

/// Karakterlerin ve hacimli objelerin arkasında, zemin katmanında kalması
/// gereken alçak flora.
bool isGroundFloraDecorKind(DecorKind kind) => isFlowerDecorKind(kind);

/// [candidate] karesi, [groundFloraTiles] içindeki bütün karelerden Chebyshev
/// ölçüsünde [radius]'tan daha uzaktaysa `true` döner.
///
/// Girdi yalnız koordinatlardan oluşur; bu yüzden dünya üretimi, köy içi
/// dikimler ve testler aynı saf yerleşim kuralını paylaşabilir.
bool hasGroundFloraBreathingRoom(
  (int, int) candidate,
  Iterable<(int, int)> groundFloraTiles, {
  int radius = kGroundFloraBreathingRadius,
}) {
  if (radius < 0) {
    throw ArgumentError.value(radius, 'radius', 'must not be negative');
  }

  final (col, row) = candidate;
  for (final (otherCol, otherRow) in groundFloraTiles) {
    final dx = (otherCol - col).abs();
    final dy = (otherRow - row).abs();
    if (math.max(dx, dy) <= radius) return false;
  }
  return true;
}

/// [baseCount]'ı dünya alanının kareköküyle ölçekler.
///
/// Alan dört katına çıktığında sayı iki katına çıkar; böylece büyük haritalar
/// çiçeksiz kalmaz ama doğrusal alan ölçeğinin oluşturduğu görsel istila da
/// geri dönmez.
int ambientFlowerCount(
  int baseCount,
  int worldArea, {
  int baseArea = kAmbientFlowerBaseArea,
}) {
  if (baseCount < 0) {
    throw ArgumentError.value(baseCount, 'baseCount', 'must not be negative');
  }
  if (worldArea < 0) {
    throw ArgumentError.value(worldArea, 'worldArea', 'must not be negative');
  }
  if (baseArea <= 0) {
    throw ArgumentError.value(baseArea, 'baseArea', 'must be positive');
  }
  if (baseCount == 0 || worldArea == 0) return 0;

  final scaled = (baseCount * math.sqrt(worldArea / baseArea)).round();
  return math.max(1, scaled);
}

/// Köy kaynaklı dikimler için, gelişmiş alanla kontrollü büyüyen ek pay.
int villageFlowerAllowance(int developedTiles) {
  final safeDevelopedTiles = math.max(0, developedTiles);
  return (kVillageFlowerBudgetMin +
          safeDevelopedTiles ~/ kDevelopedTilesPerExtraFlower)
      .clamp(kVillageFlowerBudgetMin, kVillageFlowerBudgetMax);
}

/// Ambient dünya çiçekleri ile köy kaynaklı çiçeklerin ortak üst sınırı.
int flowerPopulationBudget(int worldArea, {int developedTiles = 0}) =>
    ambientFlowerCount(kAmbientFlowerBaseCount, worldArea) +
    villageFlowerAllowance(developedTiles);

/// Mevcut sayı bütçeyi aşmış olsa bile negatif olmayan ekim kapasitesi.
int remainingFlowerCapacity({
  required int currentFlowerCount,
  required int worldArea,
  int developedTiles = 0,
}) {
  final budget = flowerPopulationBudget(
    worldArea,
    developedTiles: developedTiles,
  );
  return math.max(0, budget - math.max(0, currentFlowerCount));
}
