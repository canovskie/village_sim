import 'package:flutter/material.dart';

// ─── Harita & izometri ───────────────────────────────────────────────────────
const int kCols = 72;
const int kRows = 54;
const double kTileW = 64.0;   // piksel sanatı için 2:1 standart (64x32)
const double kTileH = 32.0;
const double kCharScale = 0.34;

// ─── İşçi hızları (tile / sn) ────────────────────────────────────────────────
// Tek yerde toplandı; balance tuning için buradan değiştirin.
const double kBuilderSpeed       = 2.2;
const double kBuilderWanderSpeed = 1.0;
const double kWoodcutterSpeed    = 2.2;
const double kLumberCampSpeed    = 2.2;
const double kMinerSpeed         = 2.0;
const double kFisherSpeed        = 2.5;
const double kFarmerSpeed        = 3.5;

// ─── Çalışma süreleri (saniye) ───────────────────────────────────────────────
const double kChopDuration         = 18.0; // woodcutter + lumberCamp ortak — huzurlu tempo
const double kFishDuration         = 7.0;
/// Tavuk kümesi başına bir yumurta (1 food) üretim aralığı (saniye).
/// Balıkçı bir tutuşta ~7 sn'de 1 food üretir; kümes pasif olduğu için biraz
/// daha yavaş — 3-4 tavuk birlikte ~ortalama bir balıkçıya yakın çıktı verir.
const double kEggInterval          = 32.0;
/// Arı kovanı baz bal üretim aralığı (saniye) — çiçeksiz, tek başına yavaş.
/// Menzildeki her çiçek üretim hızını çarpar (bkz. scene_tick bal döngüsü),
/// florist'in yanına kovan koymak ödüllendirilir. Bal lüks/moral kaynağı,
/// hayatta kalma zorunluluğu değil → bilinçli yavaş.
const double kHoneyInterval        = 50.0;
const double kFarmHarvestDuration  = 4.0;
const double kFarmWaterFetchTime   = 1.5;
const double kFarmWaterTime        = 1.2;
const double kFarmWaterCooldown    = 18.0;

// ─── Sulama mekaniği (kuyu → tarla hızlandırıcı) ──────────────────────────────
// Kuyu varsa çiftçi oradan su taşır, ekin yamasını sular → sulanan ekin 2x
// büyür (bkz. FarmTile.update / boostGrowth). Kuyu yoksa ekin baz hızda büyür.
const double kFarmWaterBoostDuration = 9.0; // sulamanın 2x bonus süresi (sn)
const double kFarmWaterSplashRadius  = 1.8; // bir kovanın suladığı yarıçap (tile)
const double kFarmWellMaxDistance    = 14.0; // bundan uzak kuyuya gidilmez (tile)

// ─── Ev su deposu (kuyu → ev) ─────────────────────────────────────────────────
// Her evin 0..1 su deposu var. Sakinler tüketir, kuyular doldurur. Susuz evler
// köy moralini düşürür (→ nüfus büyümesi yavaşlar). Kuyu yoksa depo boşalır.
const double kHouseWaterDrainPerOccupant = 0.012; // /sn, sakin başına tüketim
const double kWellWaterRefill            = 0.05;  // /sn, kuyu başına ev doldurma

// Köy morali — PASİF GÖSTERGE süzülme hızı (1/sn). _morale her tick hedefe
// `dt * kMoraleEaseRate` oranında yaklaşır; ~%6.7/sn → görünür ama yumuşak.
const double kMoraleEaseRate = 0.067;

// Sürekli baseline canlılık — köy çapında ~bu aralıkta bir rastgele NPC kısa
// bir gövde refleksi verir (huzur/merak). Ortam hiç durağan kalmasın diye.
const double kSpontaneousLifeMin = 2.0; // sn
const double kSpontaneousLifeMax = 4.0; // sn

// ─── Nüfus yiyecek tüketimi & açlık ───────────────────────────────────────────
// Her köylü zamanla yiyecek tüketir; üretim yetmezse stok azalır. Stok
// [kStarveRampFood] eşiğinin altına inince açlık başlar → köy görünür tedirgin
// olur (bir kerelik moral nudge + gövde dili reaksiyonu; formül değil).
const double kFoodPerVillagerPerDay = 8.0;  // köylü başına günlük tüketim
const int    kStarveRampFood        = 10;   // bu eşiğin altında açlık reaksiyonu

// ─── Rastgele olaylar ─────────────────────────────────────────────────────────
// Bir oyun günü = 240 sn. Olaylar NADİR ve özel olmalı — sürekli bombardıman
// değil. ~1.5 günde ilk olay, sonra her 3-6 günde bir (ort. ~4.5 gün).
const double kEventFirstDelay  = 360.0;  // kuruluştan ilk olaya kadar (~1.5 gün)
const double kEventMinInterval = 720.0;  // olaylar arası en kısa süre (3 gün)
const double kEventMaxInterval = 1440.0; // olaylar arası en uzun süre (6 gün)
const double kEventBannerDuration = 6.0; // banner kart ekranda kalma süresi

// ─── Gece / gündüz eşikleri ──────────────────────────────────────────────────
// dayLight bu eşiklerin altına düşünce "gece"; üstüne çıkınca "gündüz".
// Histerez için iki ayrı değer — flicker önler.
const double kNightThreshold = 0.15;
const double kDawnThreshold  = 0.25;

// ─── NPC ayrışma (separation) ────────────────────────────────────────────────
// Hafif itme yerine sert ayrışma — NPC'ler bir tile + tampon kadar uzakta
// durmak zorunda. Önceden (0.80, 3.5) iç içe geçmeye izin veriyordu; köyün
// ateş/kuyu/pazar gibi sosyal noktalarında görsel çakışma yaratıyordu.
const double kSeparationRadius   = 1.10; // minimum tile mesafesi (1 tile + 0.10 tampon)
const double kSeparationStrength = 7.0;  // itme gücü (tile/sn²)

// ─── Taşıyıcı atama döngüsü ──────────────────────────────────────────────────
const double kCarrierAssignInterval = 3.0; // saniye

// ─── Performans throttle'ları ────────────────────────────────────────────────
// Engel/kuyu/yasak tile set'leri her frame yeniden kurulmaz; bu aralıkta bir
// yenilenir (harita statik, maden/bina değişimi bu gecikmeyle yansır → görünmez).
const double kSpatialRebuildInterval = 0.3; // saniye
// Boştaki işçi her frame tüm hedef listesini taramasın; bu sıklıkta arar.
const double kWorkSearchInterval     = 0.4; // saniye

// ─── Lumber camp bölgesi ─────────────────────────────────────────────────────
const double kLumberTerritoryRadius   = 6.0; // tile yarıçapı
const int    kLumberTargetTrees       = 5;   // bölgede tutulan ağaç sayısı
const int    kLumberMaxMarked         = 2;   // eş zamanlı işaretli ağaç
const double kLumberManageMinInterval = 3.0; // saniye
const double kLumberManageMaxInterval = 5.0;

/// Grid → ekran (piksel snaplanmış).
Offset gridToScreen(double gx, double gy, Size size, Offset camera) {
  final ox = (size.width  / 2 + camera.dx).roundToDouble();
  final oy = (size.height * 0.28 + camera.dy).roundToDouble();
  return Offset(
    (ox + (gx - gy) * kTileW / 2).roundToDouble(),
    (oy + (gx + gy) * kTileH / 2).roundToDouble(),
  );
}

/// Ekran → kesirli grid koordinatları.
(double, double) screenToGrid(Offset screen, Size size, Offset camera) {
  if (size.width <= 0 || size.height <= 0) return (0, 0);
  final ox = size.width  / 2 + camera.dx;
  final oy = size.height * 0.28 + camera.dy;
  final dx = screen.dx - ox;
  final dy = screen.dy - oy;
  final a  = kTileW / 2;
  final b  = kTileH / 2;
  return ((dx / a + dy / b) / 2, (dy / b - dx / a) / 2);
}
