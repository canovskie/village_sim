import 'dart:math';

enum AnimalKind { cow }

/// Ağıla bağlı serbest dolaşan hayvan. Hunger ↗ zaman; otladıkça (= hareket
/// ettikçe) düşer. Doyduğunda milkProgress birikir. milkProgress≥1 olunca
/// çoban gelir, isBeingMilked aktif, bitince ürün spawn edilir.
///
/// İzometri/render için WorkerEntity ile aynı alanları taklit eder
/// (gridX/Y, renderX/Y, depth, walkPhase, facingRight) — char_renderer
/// uyumu için.
class AnimalEntity {
  final AnimalKind kind;
  final int barnCol;
  final int barnRow;

  double gridX;
  double gridY;
  double renderX;
  double renderY;
  bool   facingRight = true;
  double walkPhase   = 0.0;
  bool   isWalking   = false;

  /// 0 = tamamen tok, 1 = aç. Yürürken otladığı varsayılır.
  double hunger = 0.0;
  /// 0..1 — doyduğunda dolar; sağılınca sıfırlanır.
  double milkProgress = 0.0;
  /// Çoban tarafından şu anda sağılıyor.
  bool isBeingMilked = false;

  // ── Wander state ──────────────────────────────────────────────────────────
  double _wanderTargetX = -1;
  double _wanderTargetY = -1;
  double _wanderTimer   = 0;

  AnimalEntity({
    required this.kind,
    required this.barnCol,
    required this.barnRow,
    required double startCol,
    required double startRow,
  }) : gridX   = startCol,
       gridY   = startRow,
       renderX = startCol,
       renderY = startRow;

  static const double _wanderRadius = 3.5;
  static const double _walkSpeed    = 0.9;          // tile/sn, sakin
  static const double _hungerRate   = 1.0 / 70.0;   // 70 sn'de aç
  static const double _grazeRate    = 1.0 / 30.0;   // 30 sn yürüyüşle doyar
  static const double _milkRate     = 1.0 / 45.0;   // dolu kalınca 45 sn'de hazır

  bool get readyToMilk => milkProgress >= 1.0 && !isBeingMilked;
  double get depth => gridX + gridY;

  void update(double dt, Random rng,
      {Set<(int, int)> waterTiles = const {}}) {
    if (isBeingMilked) {
      isWalking = false;
      walkPhase += dt * 1.2;
      _smoothRender(dt);
      return;
    }

    // Hunger / milk metabolizması
    hunger += dt * _hungerRate;
    if (hunger > 1.0) hunger = 1.0;
    if (isWalking && hunger > 0.0) {
      hunger -= dt * _grazeRate;
      if (hunger < 0.0) hunger = 0.0;
    }
    if (hunger < 0.3 && milkProgress < 1.0) {
      milkProgress += dt * _milkRate;
      if (milkProgress > 1.0) milkProgress = 1.0;
    }

    // Yürüyüş
    _wanderTimer -= dt;
    if (_wanderTimer <= 0 ||
        (gridX - _wanderTargetX).abs() < 0.15 &&
            (gridY - _wanderTargetY).abs() < 0.15) {
      _pickWanderTarget(rng, waterTiles);
      _wanderTimer = 2.5 + rng.nextDouble() * 4.0;
    }

    final dx   = _wanderTargetX - gridX;
    final dy   = _wanderTargetY - gridY;
    final dist = sqrt(dx * dx + dy * dy);
    if (dist > 0.05) {
      final step = (_walkSpeed * dt).clamp(0.0, dist);
      gridX += dx / dist * step;
      gridY += dy / dist * step;
      facingRight = dx >= 0;
      isWalking = true;
      walkPhase += dt * 6.0;
    } else {
      isWalking = false;
      walkPhase += dt * 1.0;
    }
    walkPhase %= 2 * pi;

    _smoothRender(dt);
  }

  void _pickWanderTarget(Random rng, Set<(int, int)> waterTiles) {
    final cx = barnCol + 1.5;
    final cy = barnRow + 1.0;
    for (int i = 0; i < 8; i++) {
      final a = rng.nextDouble() * 2 * pi;
      final r = rng.nextDouble() * _wanderRadius;
      final tx = cx + cos(a) * r;
      final ty = cy + sin(a) * r;
      if (waterTiles.contains((tx.round(), ty.round()))) continue;
      _wanderTargetX = tx;
      _wanderTargetY = ty;
      return;
    }
    _wanderTargetX = cx;
    _wanderTargetY = cy;
  }

  void _smoothRender(double dt) {
    final k = 1 - exp(-dt * 12.0);
    renderX += (gridX - renderX) * k;
    renderY += (gridY - renderY) * k;
  }

  /// Çoban sağmayı tamamladı: bir "yiyecek" birimi üretir, milk sıfırlanır,
  /// hunger geri yükselmeye başlar (bir kova süt = belli enerji).
  void onMilked() {
    isBeingMilked = false;
    milkProgress = 0.0;
    hunger = (hunger + 0.15).clamp(0.0, 1.0);
  }
}
