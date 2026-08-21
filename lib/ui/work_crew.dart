import 'package:flutter/material.dart';

import '../entities/villager_entity.dart';
import '../entities/villager_job.dart';
import '../entities/work_site.dart';
import '../rendering/portrait_renderer.dart';
import '../systems/job_feedback.dart';
import 'app_ui.dart';
import 'semantic_icon.dart';

/// KADRO — bir iş yerinin oyuncuya bakan yüzü.
///
/// Bu bölüm, iş vermenin kişiden yere taşınmasının bütün etkileşimidir.
/// Eskiden köylü kartında on bir rol rozeti vardı; oyuncu bir insan seçip ona
/// meslek giydiriyordu. Şimdi tersi: bir YERE bakıyor ve o yerin kaç el
/// istediğini görüyor. Boş yuvaya dokunmak "buraya bir el" demektir — kimin
/// geleceğine köy karar verir (en yakın uygun köylü), çünkü oyuncu bir işveren
/// değil, bir köyün sahibi.
///
/// Yuva sayısı [WorkSite.slots]'tan gelir: köyün istediği kadar yuva, ARTI hep
/// bir tane fazla. O fazlalık bilinçli — köyün istediğinden çok el vermek
/// (üç oduncu tek kampa) geçerli bir karardır ve hep öyleydi.
class WorkCrewSection extends StatelessWidget {
  final WorkSite site;

  /// Boş yuvaya dokunuldu — en yakın uygun köylü işe koşulur.
  final VoidCallback? onAddHand;

  /// Dolu yuvadan el çekildi.
  final void Function(VillagerEntity) onRemoveHand;

  /// Yuvadaki isme dokunuldu — o köylünün kartına geç.
  final void Function(VillagerEntity)? onSelect;

  const WorkCrewSection({
    super.key,
    required this.site,
    required this.onRemoveHand,
    this.onAddHand,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final crew = site.crew;
    final slots = site.slots;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _heading(),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            for (int i = 0; i < slots; i++)
              if (i < crew.length)
                _FilledSlot(
                  villager: crew[i],
                  extra: site.isExtraSlot(i),
                  accent: _accent,
                  onRemove: () => onRemoveHand(crew[i]),
                  onSelect: onSelect == null ? null : () => onSelect!(crew[i]),
                )
              else
                _emptySlot(i),
          ],
        ),
        if (crew.isNotEmpty && feedbackFor(crew.first).result.isNotEmpty) ...[
          const SizedBox(height: 7),
          _note(feedbackFor(crew.first).result, AppUi.textLo),
        ],
        if (site.idleReason != null) ...[
          const SizedBox(height: 7),
          _note(site.idleReason!, AppUi.gold),
        ],
      ],
    );
  }

  Color get _accent => site.starving ? AppUi.rust : AppUi.accent;

  Widget _heading() {
    final crew = site.crew.length;
    final tone = site.starving
        ? AppUi.rust
        : site.staffed
        ? AppUi.sage
        : AppUi.gold;
    return Row(
      children: [
        SemanticIcon(
          site.role.icon,
          size: 12,
          color: tone,
          fallback: GameIconData.hammer,
        ),
        const SizedBox(width: 6),
        Text(
          site.role.label.toUpperCase(),
          style: AppUi.label.copyWith(letterSpacing: 0.6),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1, color: AppUi.line)),
        const SizedBox(width: 8),
        // Sayı köyün cümlesidir: "2/1" fazladan el demek, "0/1" aç bir yer.
        Text(
          site.wanted == 0 ? '$crew el' : '$crew/${site.wanted} el',
          style: AppUi.label.copyWith(color: tone, letterSpacing: 0.4),
        ),
      ],
    );
  }

  Widget _note(String text, Color color) => Text(
    text,
    style: AppUi.body.copyWith(fontSize: 11, height: 1.3, color: color),
  );

  /// Boş yuva. ÖĞRETİCİ BURAYA ARTIK DOKUNMAZ: kadro köyün kendi refleksi
  /// (bkz. scene_jobs), yuva oyuncunun isteğe bağlı müdahalesi. Öğretilecek
  /// bir zorunluluk kalmayınca öğreten işaret de kalktı.
  Widget _emptySlot(int index) {
    final extra = site.isExtraSlot(index);
    return _EmptySlot(
      // Köyün İSTEDİĞİ yuva çağırır (ember çeper), fazladan yuva yalnız
      // durur (soluk) — ikisi aynı görünürse "kaç el gerek" okunmaz olur.
      calling: !extra && onAddHand != null,
      enabled: onAddHand != null,
      onTap: onAddHand,
    );
  }
}

/// Dolu yuva — portre + ad. Gövdeye dokunmak o köylünün kartını açar, sağdaki
/// çarpı eli çeker. İki eylem ayrı hedeflerde: tek hedefte toplasaydık
/// "kime baktığımı görmek" ile "işten almak" aynı dokunuş olurdu.
class _FilledSlot extends StatelessWidget {
  final VillagerEntity villager;
  final bool extra;
  final Color accent;
  final VoidCallback onRemove;
  final VoidCallback? onSelect;

  const _FilledSlot({
    required this.villager,
    required this.extra,
    required this.accent,
    required this.onRemove,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final pinned = villager.isPlayerAssigned;
    final tint = extra ? AppUi.textLo : accent;
    final feedback = feedbackFor(villager);
    return Container(
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppUi.radiusSm),
        border: Border.all(color: tint.withValues(alpha: 0.34)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(AppUi.radiusSm),
              ),
              onTap: onSelect,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(5, 5, 8, 5),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(5),
                      child: SizedBox(
                        width: 26,
                        height: 26,
                        child: CustomPaint(
                          painter: PortraitPainter(
                            visual: villager.visual,
                            stage: villager.lifeStage,
                            type: villager.type,
                            hasProfession: villager.hasProfession,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  villager.name,
                                  style: AppUi.body.copyWith(
                                    fontSize: 11.5,
                                    color: AppUi.textHi,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              // Oyuncunun mührü — köyün kendi yolladığı elden
                              // ayrılsın ki "bunu ben koydum" okunabilsin.
                              if (pinned) ...[
                                const SizedBox(width: 5),
                                Text(
                                  '•',
                                  style: AppUi.body.copyWith(
                                    fontSize: 12,
                                    color: tint,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 1),
                          Text(
                            feedback.etaLabel.isEmpty
                                ? feedback.state
                                : '${feedback.state} · ${feedback.etaLabel}',
                            style: AppUi.body.copyWith(
                              fontSize: 10,
                              color: feedback.progress > 0
                                  ? AppUi.sage
                                  : AppUi.textLo,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (feedback.progress > 0) ...[
                            const SizedBox(height: 3),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: SizedBox(
                                height: 2,
                                child: LinearProgressIndicator(
                                  value: feedback.progress,
                                  backgroundColor: AppUi.line,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    tint,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: const BorderRadius.horizontal(
                right: Radius.circular(AppUi.radiusSm),
              ),
              onTap: onRemove,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(3, 6, 7, 6),
                child: Text(
                  '×',
                  style: AppUi.body.copyWith(
                    fontSize: 13,
                    height: 1,
                    color: AppUi.textLo,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Boş yuva — kesikli çeper + artı. Köyün istediği yuva ember çağırır;
/// fazladan yuva soluk durur (basılabilir ama davet etmez).
class _EmptySlot extends StatelessWidget {
  final bool calling;
  final bool enabled;
  final VoidCallback? onTap;

  const _EmptySlot({required this.calling, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tint = calling ? AppUi.accent : AppUi.textLo;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppUi.radiusSm),
          onTap: onTap,
          child: CustomPaint(
            painter: _DashedBorderPainter(
              color: tint.withValues(alpha: calling ? 0.55 : 0.3),
              radius: AppUi.radiusSm,
            ),
            child: Container(
              height: 30,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '+',
                    style: AppUi.body.copyWith(
                      fontSize: 14,
                      height: 1,
                      color: tint,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    calling ? 'el ver' : 'fazladan',
                    style: AppUi.body.copyWith(fontSize: 11, color: tint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Kesikli çeper — boş yuvanın "burada bir şey eksik" dili. Dolu yuva düz
/// çizgiyle çevrilir; ikisi aynı çizgiyle çevrilseydi dolu/boş ayrımı yalnız
/// renge kalırdı.
class _DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  const _DashedBorderPainter({required this.color, required this.radius});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final rect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    const dash = 4.0, gap = 3.0;
    for (final metric in (Path()..addRRect(rect)).computeMetrics()) {
      double d = 0;
      while (d < metric.length) {
        final end = (d + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, end), paint);
        d = end + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
