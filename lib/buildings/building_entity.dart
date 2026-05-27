import 'building_type.dart';
import 'building_function.dart';

class BuildingEntity {
  final BuildingType type;
  final int col;
  final int row;

  /// Maden ocağı gibi içeride çalışma olan binalar için
  bool isActive = false;

  // ── İşlevsel durum (building_system tarafından yönetilir) ──────────────────

  /// Nüfus büyüme ilerlemesi 0..1 (yalnızca belediye).
  double growthProgress = 0.0;

  /// Pazar pasif gelir zamanlayıcısı (saniye).
  double incomeTimer = 0.0;

  /// Konut su deposu 0..1 (yalnızca housing). Sakinler tüketir, kuyu doldurur.
  /// Boşalınca köy morali düşer. Yeni ev dolu başlar.
  double waterLevel = 1.0;

  /// Bu evde yaşayan köylü sayısı — main her tick günceller (su tüketimi için).
  int occupants = 0;

  BuildingEntity({required this.type, required this.col, required this.row});

  int get cols => kBuildingMeta[type]!.cols;
  int get rows => kBuildingMeta[type]!.rows;

  /// İşlevsel tanım (rol, kapasite, civic etki...). Tanımsızsa null.
  BuildingFunction? get fn => kBuildingFunctions[type];

  /// Depth for painter's algorithm: front corner col+row sum
  double get depth => (col + cols + row + rows).toDouble();
}
