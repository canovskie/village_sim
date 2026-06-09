import 'dart:math';
import '../core/constants.dart';
import '../world/decor_entity.dart';
import 'worker_entity.dart';

enum FloristState { idle, walkingToFlower, watering }

/// Çiçekçi kulübesi NPC'si — kulübenin etki alanı içindeki çiçek dekorlarını
/// gezerek "sular". Sulama görsel etki ve uzun süreli moral katkısı sağlar.
///
/// State machine (FisherEntity pattern'ı):
///   idle           : kulübenin yakınında dolaş, periyodik olarak sulanacak
///                    bir çiçek hedefi seç (effectRadius içindeki random çiçek)
///   walkingToFlower: hedefe yürü
///   watering       : kısa süre yerinde dur, watering can animasyonu, sonra idle
class FloristEntity extends WorkerEntity {
  FloristState state = FloristState.idle;
  /// 0..2π — watering can sallanma fazı.
  double waterPhase = 0.0;

  /// Kulübenin ana köşe (col, row). Idle wander merkezi olarak kullanılır.
  final int cottageCol;
  final int cottageRow;
  /// Hedef seçimi için yarıçap (kulübe meta'sından gelir).
  final double effectRadius;

  /// Şu an sulanan çiçek dekoru (target). null → hedef yok.
  DecorEntity? _targetFlower;
  /// Sulama tile koordinatı (target flower'ın col/row).
  double _targetCol = -1;
  double _targetRow = -1;
  double _waterTimer = 0.0;

  /// Kısa süreli görsel "fresh bloom" — flower sulandığında set edilir,
  /// renderer ışıltı/parıltı animasyonu için query edebilir. Şu an sadece
  /// sulanan flower id'lerini takip eder ki painter "az önce sulandı" ışıltı
  /// gösterebilsin (faz 2'de eklenecek).
  DecorEntity? lastWateredFlower;
  double sinceLastWatered = 999.0;

  FloristEntity({
    required super.startCol,
    required super.startRow,
    required this.cottageCol,
    required this.cottageRow,
    required this.effectRadius,
  });

  @override
  double get speed => kFarmerSpeed * 0.85; // çiftçiye yakın, sakin

  @override
  double get idleSpeedFactor => 0.6;

  @override
  (double, double) get idleIntervalRange => (1.5, 3.5);

  /// Idle wander merkezi — kulübenin önü.
  @override
  double get wanderOriginX => cottageCol + 1.0;
  @override
  double get wanderOriginY => cottageRow + 2.4; // bina footprint güneyi
  @override
  double get wanderRadius => effectRadius;

  bool get isWatering => state == FloristState.watering;

  /// Watering süresi (sn) — fishing'e benzer kısa loop.
  static const double _wateringDuration = 1.6;
  /// Çiçek hedefi seçme cooldown (idle iken). Çok sık yeni hedef seçmesin.
  static const double _retargetCooldown = 4.0;

  double _retargetTimer = 0.0;

  void update(double dt, Random rng, {
    required List<DecorEntity> decor,
    Set<(int, int)> waterTiles = const {},
    Set<(int, int)> softObstacles = const {},
  }) {
    sinceLastWatered += dt;

    switch (state) {
      case FloristState.idle:
        idleWander(dt, rng, waterTiles, softObstacles);
        _retargetTimer -= dt;
        if (_retargetTimer <= 0) {
          _retargetTimer = _retargetCooldown;
          final target = _pickFlowerTarget(decor, rng);
          if (target != null) {
            _targetFlower = target;
            _targetCol = target.col + 0.5;
            _targetRow = target.row + 0.7; // çiçeğin önünde dur
            state = FloristState.walkingToFlower;
          }
        }

      case FloristState.walkingToFlower:
        // Hedef çiçek bu sırada başka şekilde silinmiş olabilir
        if (_targetFlower == null || !decor.contains(_targetFlower)) {
          state = FloristState.idle;
          break;
        }
        if (moveTowards(_targetCol, _targetRow, dt, arriveD: 0.15)) {
          gridX = _targetCol;
          gridY = _targetRow;
          state = FloristState.watering;
          _waterTimer = 0;
          waterPhase = 0;
          // Çiçeğe yüzünü dön
          final dx = _targetFlower!.col - gridX;
          facingRight = dx >= 0;
        }

      case FloristState.watering:
        _waterTimer += dt;
        waterPhase = (waterPhase + dt * 2 * pi * 1.2) % (2 * pi);
        if (_waterTimer >= _wateringDuration) {
          lastWateredFlower = _targetFlower;
          sinceLastWatered = 0.0;
          _targetFlower = null;
          state = FloristState.idle;
          _retargetTimer = _retargetCooldown * 0.4; // hemen yeni hedef ara
        }
    }

    isWalking = state == FloristState.walkingToFlower;
    walkPhase = (walkPhase + dt * (isWalking ? 6.0 : 1.2)) % (2 * pi);
  }

  /// Etki alanı içindeki çiçek dekorlarından birini random seç.
  /// Çok yakın olanları filtreler ki sürekli aynı çiçeği sulamasın.
  DecorEntity? _pickFlowerTarget(List<DecorEntity> decor, Random rng) {
    final originX = wanderOriginX;
    final originY = wanderOriginY;
    final r2 = effectRadius * effectRadius;
    final candidates = <DecorEntity>[];
    for (final d in decor) {
      // Sadece çiçek demetlerini hedefle (mantar/kütük/taşı atla)
      switch (d.kind) {
        case DecorKind.daisy:
        case DecorKind.poppy:
        case DecorKind.buttercup:
        case DecorKind.lavender:
        case DecorKind.clover:
          break;
        default:
          continue;
      }
      final dx = (d.col + 0.5) - originX;
      final dy = (d.row + 0.5) - originY;
      if (dx * dx + dy * dy > r2) continue;
      // Az önce suladığı çiçek değilse
      if (d == lastWateredFlower && sinceLastWatered < 8.0) continue;
      candidates.add(d);
    }
    if (candidates.isEmpty) return null;
    return candidates[rng.nextInt(candidates.length)];
  }
}
