/// Suda yüzen lotus (tek tile üzerinde).
class LotusEntity {
  final int col, row;
  final int variant; // 0 = beyaz, 1 = sarı

  const LotusEntity({required this.col, required this.row, required this.variant});

  double get depth => (col + row).toDouble() + 0.3;
}

/// Göl kenarında 2 kare kaplayan saz kümesi.
/// Biçilebilir: olgunken (growth>=1) evsizler biçer, saz toplar. Biçilince
/// growth 0'a düşer (anız) ve su kenarında yavaşça yeniden büyür.
class ReedClump {
  final int col,  row;   // 1. tile
  final int col2, row2;  // 2. tile (yan yana)

  /// 0 = yeni biçilmiş (anız), 1 = olgun/biçilebilir.
  double growth;

  ReedClump({
    required this.col,  required this.row,
    required this.col2, required this.row2,
    this.growth = 1.0,
  });

  bool get harvestable => growth >= 1.0;

  /// Biç — sazı al, anıza dön.
  void harvest() => growth = 0.0;

  /// Yeniden büyüme — [regrowSeconds] sürede 0→1.
  void tickRegrow(double dt, double regrowSeconds) {
    if (growth < 1.0) {
      growth = (growth + dt / regrowSeconds).clamp(0.0, 1.0);
    }
  }

  // Derinlik: ikinci tile'ın önde olan ucunu kullan
  double get depth => (col + col2 + row + row2) / 2.0 + 0.5;
}

/// Böğürtlen çalısı — tek tile, toplanır ve yeniden meyve verir.
///
/// Köyün BİNASIZ tek üretim kaynağı. Kuruluşun ilk dakikalarında ne tarla var
/// ne oduncu kulübesi; bir insanın hiçbir şey inşa etmeden yiyecek getirebildiği
/// tek yol bu. Erken oyunun "elimde yapacak bir şey yok" boşluğunu doğrudan bu
/// döngü kapatıyor (bkz. [JobRole.forager]).
///
/// [ReedClump] ile aynı hasat-yenilenme deseni: olgunken toplanır, `ripeness`
/// 0'a düşer, zamanla geri dolar. Kışın yenilenmez — mevsim erken oyunda da
/// gerçek bir kısıt olsun (bkz. [[project_seasons]]).
class BerryBush {
  final int col, row;

  /// Görsel varyasyon (0..2) — aynı çalıdan tarla olmasın.
  final int variant;

  /// 0 = toplanmış (çıplak çalı), 1 = olgun/toplanabilir.
  double ripeness;

  /// Bir toplayıcı bu çalıyı üstlendi mi — iki kişinin aynı çalıya gidip
  /// birinin eli boş dönmesini engeller (claim bayrağı; kaydedilmez).
  bool isBeingPicked = false;

  BerryBush({
    required this.col,
    required this.row,
    this.variant = 0,
    this.ripeness = 1.0,
  });

  bool get harvestable => ripeness >= 1.0;

  /// Topla — meyveyi al, çıplak çalıya dön.
  void harvest() => ripeness = 0.0;

  /// Yeniden meyvelenme — [regrowSeconds] sürede 0→1. [frozen] ise (kış)
  /// hiç ilerlemez.
  void tickRegrow(double dt, double regrowSeconds, {bool frozen = false}) {
    if (frozen || ripeness >= 1.0) return;
    ripeness = (ripeness + dt / regrowSeconds).clamp(0.0, 1.0);
  }

  double get depth => (col + row).toDouble() + 0.5;
}
