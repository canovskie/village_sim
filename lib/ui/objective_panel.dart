import 'package:flutter/material.dart';
import '../systems/quest_book.dart';
import 'cozy_theme.dart';

/// Köy Defteri — köyün kimlik kademesi (başlık) + akan görev listesi.
/// Parşömen tarzı: başlıkta kademe adı + ✓ tamamlanan sayısı; aktif görev
/// ember vurgu + el yazısı ipucu; altta bir sonraki kademe ipucu.
/// Ödüller görseldir (kutlama + köyün çiçeklenmesi) — burada sayı/kaynak yok.
class ObjectivePanel extends StatelessWidget {
  /// Açık (tamamlanmamış) görevler — ilki `active`.
  final List<QuestState> quests;
  final int tierIndex;
  final String tierName;
  final String tierIcon;
  final int completedCount;
  final int totalCount;
  /// Bir sonraki kademe (varsa) — ilerleme ipucu.
  final CharterTier? next;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  const ObjectivePanel({
    super.key,
    required this.quests,
    required this.tierIndex,
    required this.tierName,
    required this.tierIcon,
    required this.completedCount,
    required this.totalCount,
    required this.next,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final activeIdx = quests.indexWhere((q) => q.active);

    return SizedBox(
      width: 218,
      child: ParchmentPanel(
        pinned: true,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(),
            if (!collapsed) ...[
              const SizedBox(height: 5),
              if (quests.isEmpty)
                _allClear()
              else
                for (final q in quests) _row(q),
              if (activeIdx >= 0) ...[
                const SizedBox(height: 6),
                _hintBar(quests[activeIdx]),
              ],
              if (next != null) ...[
                const SizedBox(height: 6),
                _nextTierBar(next!),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return GestureDetector(
      onTap: onToggleCollapse,
      child: Row(
        children: [
          Text(tierIcon, style: const TextStyle(fontSize: 13)),
          const SizedBox(width: 6),
          Expanded(
            child: Text(tierName.toUpperCase(),
                overflow: TextOverflow.ellipsis,
                style: CozyUi.inkTitle.copyWith(
                  color: CozyUi.ember,
                  fontSize: 11,
                  letterSpacing: 1.4,
                )),
          ),
          Text('✓$completedCount',
              style: CozyUi.inkLabel.copyWith(fontSize: 10, color: CozyUi.sage)),
          const SizedBox(width: 4),
          Icon(
            collapsed ? Icons.expand_more : Icons.expand_less,
            size: 14,
            color: CozyUi.parchmentInk2,
          ),
        ],
      ),
    );
  }

  Widget _row(QuestState s) {
    final active = s.active;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(s.quest.icon,
                style: TextStyle(
                  fontSize: 11,
                  color: active ? CozyUi.ember : CozyUi.parchmentInk2,
                )),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(s.quest.label,
                style: TextStyle(
                  color: active
                      ? CozyUi.parchmentInk
                      : CozyUi.parchmentInk2.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                )),
          ),
        ],
      ),
    );
  }

  Widget _hintBar(QuestState active) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: CozyUi.ember.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: CozyUi.ember.withValues(alpha: 0.40), width: 1),
      ),
      child: Text(active.quest.hint,
          style: CozyUi.inkMuted.copyWith(
            color: CozyUi.parchmentInk,
            fontSize: 9.5,
            height: 1.4,
          )),
    );
  }

  Widget _nextTierBar(CharterTier n) {
    return Text(
      '→ Sonraki: ${n.icon} ${n.name}  (${n.minPolicies} berat · ${n.minQuests} görev)',
      style: CozyUi.inkMuted.copyWith(fontSize: 8.5, height: 1.3),
    );
  }

  Widget _allClear() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('Bu kademe tamam — yeni berat çıkar, köy ilerlesin.',
          style: CozyUi.inkMuted.copyWith(
            color: CozyUi.sage,
            fontSize: 9.5,
            height: 1.4,
          )),
    );
  }
}
