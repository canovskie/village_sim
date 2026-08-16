import '../buildings/building_type.dart';
import '../core/constants.dart';

class BuildOrder {
  final BuildingType type;
  final int col;
  final int row;

  bool completed = false; // building has been placed

  double progress = 0.0; // 0..1 during construction

  /// Bu şantiyede kaç el gerekiyor — GÖVDE ANCAK KADRO TAM OLUNCA yükselir.
  /// Küçük yapı tek kişilik, ev iki, büyük yapı üç.
  final int requiredWorkers;

  /// Siparişi üstlenmiş inşaatçı sayısı (yolda olanlar dahil), [requiredWorkers]
  /// tavanı. Eski tek-kişilik `assigned` bayrağının yerini alır.
  int crew = 0;

  /// Şantiyede ŞU AN çekiç sallayan el sayısı — bir önceki karede sayıldı.
  /// [_arrivals] bu karede birikir, tick başında buraya devredilir.
  int workersAtSite = 0;
  int arrivals = 0;

  /// Bu kare ilerleme yazıldı mı (sahne zamanı damgası) — kadrodaki her el ayrı
  /// ayrı ilerletirse bina kişi sayısı kadar hızlı çıkardı.
  double tickStamp = -1;

  /// Kadro eksikken beklenen süre (sn). Küçük köyde 2 el isteyen şantiyeye
  /// verecek ikinci adam olmayabilir; bina sonsuza dek beklemesin diye sabır
  /// dolunca eldeki el işe tek başına başlar.
  double waited = 0;

  /// Şantiyenin gerçekten başladığına dair bildirimin tek-atışlık kilidi.
  /// Simülasyon kuralı değildir; oyuncunun "emri verdim, kimse takmadı mı?"
  /// boşluğunu kapatan görünür karşılıktır.
  bool startAnnounced = false;

  BuildOrder({required this.type, required this.col, required this.row})
    : requiredWorkers = buildWorkersFor(type);

  bool get assigned => crew > 0;

  /// Gövde yükselebilir mi — kadro tam VEYA (köy o kadar el veremiyorsa)
  /// sabır dolmuş ve şantiyede en az bir el var.
  bool get crewReady =>
      workersAtSite >= requiredWorkers ||
      (workersAtSite >= 1 && waited >= kBuildCrewPatience);
}

/// Şantiyenin istediği el sayısı — footprint'ten. 1×1/2×1 kulübe tek kişilik,
/// 2×2 ev iki, 3×3 görkemli yapı üç el bekler.
int buildWorkersFor(BuildingType t) {
  final meta = kBuildingMeta[t];
  if (meta == null) return 1;
  final tiles = meta.cols * meta.rows;
  if (tiles >= 9) return 3;
  if (tiles >= 4) return 2;
  return 1;
}
