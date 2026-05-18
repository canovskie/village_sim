import 'package:flutter/material.dart';

// ─── Harita & izometri ───────────────────────────────────────────────────────
const int kCols = 48;
const int kRows = 36;
const double kTileW = 64.0;   // piksel sanatı için 2:1 standart (64x32)
const double kTileH = 32.0;
const double kCharScale = 0.46;

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
const double kChopDuration         = 10.0; // woodcutter + lumberCamp ortak
const double kFishDuration         = 5.0;
const double kFarmHarvestDuration  = 2.2;
const double kFarmWaterFetchTime   = 1.5;
const double kFarmWaterTime        = 1.2;
const double kFarmWaterCooldown    = 30.0;

// ─── Gece / gündüz eşikleri ──────────────────────────────────────────────────
// dayLight bu eşiklerin altına düşünce "gece"; üstüne çıkınca "gündüz".
// Histerez için iki ayrı değer — flicker önler.
const double kNightThreshold = 0.15;
const double kDawnThreshold  = 0.25;

// ─── NPC ayrışma (separation) ────────────────────────────────────────────────
const double kSeparationRadius   = 0.80; // minimum tile mesafesi
const double kSeparationStrength = 3.5;  // itme gücü (tile/sn²)

// ─── Taşıyıcı atama döngüsü ──────────────────────────────────────────────────
const double kCarrierAssignInterval = 3.0; // saniye

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
