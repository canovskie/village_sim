import 'dart:math';
import '../characters/villager_type.dart';
import '../characters/life_stage.dart';
import 'villager_entity.dart';

/// Gezgin tüccarın ziyaret evresi. Köyün dışından gelir, pazarda/meydanda bir
/// süre oyalanır, sonra geldiği köşeden çekip gider.
///   - [entering] : giriş köşesinden köy içindeki gezinme merkezine yürür.
///   - [browsing] : merkez çevresinde amaçsız turlar atar (oyalanma).
///   - [leaving]  : çıkış köşesine yürür; varınca [finished] olur → sahne siler.
enum MerchantPhase { entering, browsing, leaving }

/// Köye arada bir uğrayıp giden gezgin tüccar. Görsel/animasyon olarak normal
/// bir [VillagerEntity] (tip: merchant) — bu yüzden mevcut karakter çizici onu
/// olduğu gibi çizer. Ama köyün NÜFUSU/sakini DEĞİL: ayrı bir listede tutulur,
/// `update()` çağrılmaz (yaşlanma/doğurganlık/iş yok), hareketini [step] sürer.
/// Geçici/ambiyans bir varlıktır (kuş sürüleri gibi) — kayda yazılmaz.
class MerchantEntity extends VillagerEntity {
  MerchantPhase phase = MerchantPhase.entering;

  /// Köy içindeki gezinme merkezi (pazar varsa onun, yoksa meydan).
  final double browseX;
  final double browseY;

  /// Çıkış köşesi — geldiği nokta. Ayrılırken buraya yürür.
  final double exitX;
  final double exitY;

  /// Ziyaretin geri kalan oyalanma süresi (sn). 0'a inince [leaving]'e geçer.
  double browseLeft;

  /// Gezinme alt-hedefi + sonraki hedefe kadar duraklama sayacı.
  double _wanderX = 0, _wanderY = 0;
  double _wanderDwell = 0;

  /// true → çıkışa vardı, sahne listeden çıkarmalı.
  bool finished = false;

  MerchantEntity({
    required super.startCol,
    required super.startRow,
    required this.browseX,
    required this.browseY,
    required this.exitX,
    required this.exitY,
    this.browseLeft = 90.0,
    super.name = 'Gezgin Tüccar',
  }) : super(
          type: VillagerType.merchant,
          male: true,
          ageDays: kAdultStartDay, // yetişkin görünüm; "çağrı" anı tetiklenmesin
        ) {
    _wanderX = browseX;
    _wanderY = browseY;
  }

  /// Sahne her tick çağırır — basit evre makinesi + hareket. [dt] sim-ölçekli.
  /// VillagerEntity.update'in aksine yaşlanma/AI yok; yalnız yürür ve oyalanır.
  void step(double dt, Random rng,
      {Set<(int, int)> waterTiles = const {},
      Set<(int, int)> softObstacles = const {},
      double dayLight = 1.0,
      double rainIntensity = 0.0}) {
    switch (phase) {
      case MerchantPhase.entering:
        isWalking = true;
        if (moveTowards(browseX, browseY, dt, arriveD: 0.6)) {
          phase = MerchantPhase.browsing;
          _wanderDwell = 0;
        }
      case MerchantPhase.browsing:
        browseLeft -= dt;
        _browseWander(dt, rng, waterTiles, softObstacles);
        if (browseLeft <= 0) phase = MerchantPhase.leaving;
      case MerchantPhase.leaving:
        isWalking = true;
        if (moveTowards(exitX, exitY, dt, arriveD: 0.5)) {
          isWalking = false;
          finished = true;
        }
    }
    smoothMotion(dt);
    // Gece dışarıda → meşale yansın (köyün içinde de gezse). finished olunca söner.
    tickTorch(dt, dayLight, rainIntensity, eligibleOverride: !finished);
  }

  /// Merkez çevresinde sakin turlar — pazarı dolaşan tüccar hissi. Bir hedefe
  /// yürür, varınca birkaç saniye oyalanır, sonra yeni nokta seçer.
  void _browseWander(double dt, Random rng, Set<(int, int)> waterTiles,
      Set<(int, int)> softObstacles) {
    if (_wanderDwell > 0) {
      _wanderDwell -= dt;
      isWalking = false;
      if (_wanderDwell <= 0) {
        final t = pickWanderTarget(browseX, browseY, 2.6, rng,
            waterTiles: waterTiles, softObstacles: softObstacles);
        if (t != null) {
          _wanderX = t.$1;
          _wanderY = t.$2;
        }
      }
      return;
    }
    isWalking = true;
    if (moveTowards(_wanderX, _wanderY, dt, arriveD: 0.25, speedScale: 0.55)) {
      _wanderDwell = 1.5 + rng.nextDouble() * 3.0; // varış → kısa oyalanma
      isWalking = false;
    }
  }
}
