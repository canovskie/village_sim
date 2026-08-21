import 'dart:math';

import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';

/// İş panelinin salt-okunur cümlesi. Bütün değerler köylünün gerçekten yürüttüğü
/// state-machine'den türer; UI ayrı sayaç veya üretim tahmini tutmaz.
class JobFeedback {
  final String state;
  final String result;
  final double? etaSeconds;
  final double progress;

  const JobFeedback({
    required this.state,
    required this.result,
    required this.etaSeconds,
    required this.progress,
  });

  String get etaLabel {
    final eta = etaSeconds;
    if (eta == null) return '';
    if (eta < 1) return 'şimdi';
    return '${eta.ceil()} sn';
  }
}

JobFeedback feedbackFor(VillagerEntity v) {
  final job = v.job;
  if (job == null || job.role == JobRole.none) {
    return const JobFeedback(
      state: 'Sıradaki işi bekliyor',
      result: '',
      etaSeconds: null,
      progress: 0,
    );
  }

  final result = _resultFor(job.role);
  final deliveryEta = v.deliveryEtaSeconds;
  if (deliveryEta != null) {
    return JobFeedback(
      state: v.state == VillagerState.walkingToPickup
          ? 'Ürünü almaya gidiyor'
          : 'Ürünü ambara götürüyor',
      result: result,
      etaSeconds: deliveryEta,
      progress: 0,
    );
  }

  if (v.state == VillagerState.moving) {
    final dx = v.targetCol - v.gridX;
    final dy = v.targetRow - v.gridY;
    final pace = v.speed;
    final eta = pace <= 0.01 ? null : sqrt(dx * dx + dy * dy) / pace;
    return JobFeedback(
      state: 'İşyerine gidiyor',
      result: result,
      etaSeconds: eta,
      progress: 0,
    );
  }

  final active = job.working || job.harvesting || job.carryingWater;
  if (active) {
    final duration = job.cycleDuration;
    final progress = job.role == JobRole.builder && job.progress > 0
        ? job.progress
        : duration <= 0
        ? 0.0
        : (job.cycleElapsed / duration).clamp(0.0, 1.0);
    final eta = duration <= 0 ? null : max(0.0, duration - job.cycleElapsed);
    return JobFeedback(
      state: _actionFor(job.role),
      result: result,
      etaSeconds: eta,
      progress: progress,
    );
  }

  return JobFeedback(
    state: job.completedCycles > 0
        ? '${job.completedCycles} iş tamamladı'
        : 'İşini hazırlıyor',
    result: result,
    etaSeconds: null,
    progress: 0,
  );
}

String _actionFor(JobRole role) => switch (role) {
  JobRole.builder => 'İnşa ediyor',
  JobRole.farmer => 'Toprağı işliyor',
  JobRole.miner => 'Cevher çıkarıyor',
  JobRole.fisher => 'Balık tutuyor',
  JobRole.florist => 'Çiçekleri suluyor',
  JobRole.shepherd => 'Sürüyle ilgileniyor',
  JobRole.woodcutter => 'Ağacı kesiyor',
  JobRole.forager => 'Böğürtlen topluyor',
  JobRole.cook => 'Yemek pişiriyor',
  JobRole.weaver => 'Kışlık dokuyor',
  JobRole.none => 'Bekliyor',
};

String _resultFor(JobRole role) => switch (role) {
  JobRole.builder => 'Sonuç: yapı tamamlanır',
  JobRole.farmer => 'Sonuç: saman ve yiyecek',
  JobRole.miner => 'Sonuç: cevher sandığı',
  JobRole.fisher => 'Sonuç: yiyecek sepeti',
  JobRole.florist => 'Sonuç: canlı çiçekler',
  JobRole.shepherd => 'Sonuç: süt ve yiyecek',
  JobRole.woodcutter => 'Sonuç: kütükler',
  JobRole.forager => 'Sonuç: yiyecek sepeti',
  JobRole.cook => 'Sonuç: sıcak yemek',
  JobRole.weaver => 'Sonuç: kışlık giysi',
  JobRole.none => '',
};
