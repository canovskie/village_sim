import 'package:flutter/material.dart';
import '../systems/objective_tracker.dart';
import 'cozy_theme.dart';

/// Köyün gelişim adımları — parşömen şeklinde "dilek listesi". Tamamlananlar
/// ✓ ile mürekkep solar; aktif hedef ember rengi vurgu + el yazısı ipucu;
/// tümü tamamlanınca panel daralır.
class ObjectivePanel extends StatelessWidget {
  final List<ObjectiveState> objectives;
  final bool collapsed;
  final VoidCallback onToggleCollapse;

  const ObjectivePanel({
    super.key,
    required this.objectives,
    required this.collapsed,
    required this.onToggleCollapse,
  });

  @override
  Widget build(BuildContext context) {
    final activeIdx = objectives.indexWhere((o) => o.active);
    final allDone = activeIdx == -1;
    final doneCount = objectives.where((o) => o.completed).length;

    return SizedBox(
      width: 218,
      child: ParchmentPanel(
        pinned: true,
        padding: const EdgeInsets.fromLTRB(11, 9, 11, 11),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _header(doneCount, objectives.length, allDone),
            if (!collapsed) ...[
              const SizedBox(height: 5),
              for (int i = 0; i < objectives.length; i++)
                _row(objectives[i]),
              if (activeIdx >= 0) ...[
                const SizedBox(height: 6),
                _hintBar(objectives[activeIdx]),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _header(int done, int total, bool allDone) {
    final color = allDone ? CozyUi.sage : CozyUi.ember;
    return GestureDetector(
      onTap: onToggleCollapse,
      child: Row(
        children: [
          Text(allDone ? '✓' : '🎯',
              style: TextStyle(fontSize: 13, color: color)),
          const SizedBox(width: 6),
          Text(allDone ? 'KÖY KURULDU' : 'HEDEFLER',
              style: CozyUi.inkTitle.copyWith(
                color: color,
                fontSize: 11,
                letterSpacing: 1.8,
              )),
          const Spacer(),
          Text('$done/$total',
              style: CozyUi.inkLabel.copyWith(fontSize: 10)),
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

  Widget _row(ObjectiveState s) {
    Color labelColor;
    Color iconColor;
    FontStyle italic = FontStyle.normal;
    if (s.completed) {
      labelColor = CozyUi.parchmentInk2;
      iconColor  = CozyUi.sage;
    } else if (s.active) {
      labelColor = CozyUi.parchmentInk;
      iconColor  = CozyUi.ember;
    } else {
      labelColor = CozyUi.parchmentInk2.withValues(alpha: 0.55);
      iconColor  = CozyUi.parchmentInk2.withValues(alpha: 0.55);
      italic = FontStyle.italic;
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.5),
      child: Row(
        children: [
          SizedBox(
            width: 16,
            child: Text(s.completed ? '✓' : s.obj.icon,
                style: TextStyle(
                  fontSize: s.completed ? 13 : 11,
                  color: iconColor,
                )),
          ),
          const SizedBox(width: 5),
          Expanded(
            child: Text(s.obj.label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: s.active ? FontWeight.w800 : FontWeight.w600,
                  fontStyle: italic,
                  decoration: s.completed ? TextDecoration.lineThrough : null,
                  decorationColor: CozyUi.parchmentInk2,
                )),
          ),
        ],
      ),
    );
  }

  Widget _hintBar(ObjectiveState active) {
    return Container(
      margin: const EdgeInsets.only(top: 2),
      padding: const EdgeInsets.fromLTRB(8, 5, 8, 5),
      decoration: BoxDecoration(
        color: CozyUi.ember.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: CozyUi.ember.withValues(alpha: 0.40), width: 1),
      ),
      child: Text(active.obj.hint,
          style: CozyUi.inkMuted.copyWith(
            color: CozyUi.parchmentInk,
            fontSize: 9.5,
            height: 1.4,
          )),
    );
  }
}
