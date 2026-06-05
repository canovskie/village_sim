import 'package:flutter/material.dart';
import '../systems/objective_tracker.dart';
import 'game_theme.dart';

/// Hedef listesi — köyün gelişim adımları, ekranın sol alt köşesinde küçük
/// panel. Tamamlananlar ✓ ile soluk, aktif hedef vurgulu (amber border +
/// hint satırı). Tümü tamamlanınca panel daralır, "Köy kuruldu" özetiyle.
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

  static const _accent = Color(0xFFE9A23B);
  static const _success = Color(0xFF6FC07A);

  @override
  Widget build(BuildContext context) {
    final activeIdx = objectives.indexWhere((o) => o.active);
    final allDone = activeIdx == -1;
    final doneCount = objectives.where((o) => o.completed).length;

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: const Color(0xEE12161D),
        border: Border.all(
            color: allDone
                ? _success.withValues(alpha: 0.55)
                : _accent.withValues(alpha: 0.55),
            width: 1.5),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(doneCount, objectives.length, allDone),
          if (!collapsed) ...[
            const SizedBox(height: 2),
            for (int i = 0; i < objectives.length; i++)
              _row(objectives[i]),
            if (activeIdx >= 0) ...[
              const SizedBox(height: 4),
              _hintBar(objectives[activeIdx]),
            ],
            const SizedBox(height: 6),
          ],
        ],
      ),
    );
  }

  Widget _header(int done, int total, bool allDone) {
    return GestureDetector(
      onTap: onToggleCollapse,
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 7, 10, 7),
        decoration: BoxDecoration(
          color: (allDone ? _success : _accent).withValues(alpha: 0.12),
          border: Border(
            bottom: BorderSide(
                color: (allDone ? _success : _accent).withValues(alpha: 0.4),
                width: 1),
          ),
        ),
        child: Row(
          children: [
            Text(allDone ? '✓' : '🎯',
                style: TextStyle(
                  fontSize: 12,
                  color: allDone ? _success : _accent,
                )),
            const SizedBox(width: 6),
            Text(allDone ? 'KÖY KURULDU' : 'HEDEFLER',
                style: TextStyle(
                  color: allDone ? _success : _accent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontFamily: 'monospace',
                )),
            const Spacer(),
            Text('$done/$total',
                style: const TextStyle(
                  color: MedievalTheme.textSecondary,
                  fontSize: 10,
                  fontFamily: 'monospace',
                )),
            const SizedBox(width: 5),
            Icon(
              collapsed ? Icons.expand_more : Icons.expand_less,
              size: 14,
              color: MedievalTheme.textSecondary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(ObjectiveState s) {
    Color labelColor;
    Color iconColor;
    if (s.completed) {
      labelColor = MedievalTheme.textSecondary;
      iconColor  = _success;
    } else if (s.active) {
      labelColor = MedievalTheme.textPrimary;
      iconColor  = _accent;
    } else {
      labelColor = MedievalTheme.textDim;
      iconColor  = MedievalTheme.textDim;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 3, 10, 3),
      decoration: s.active
          ? BoxDecoration(color: _accent.withValues(alpha: 0.08))
          : null,
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
          const SizedBox(width: 4),
          Expanded(
            child: Text(s.obj.label,
                style: TextStyle(
                  color: labelColor,
                  fontSize: 10,
                  fontFamily: 'monospace',
                  fontWeight: s.active ? FontWeight.bold : FontWeight.w500,
                  decoration: s.completed ? TextDecoration.lineThrough : null,
                  decorationColor: MedievalTheme.textDim,
                )),
          ),
        ],
      ),
    );
  }

  Widget _hintBar(ObjectiveState active) {
    return Container(
      margin: const EdgeInsets.fromLTRB(10, 4, 10, 0),
      padding: const EdgeInsets.fromLTRB(7, 5, 7, 5),
      decoration: BoxDecoration(
        color: _accent.withValues(alpha: 0.10),
        border: Border.all(color: _accent.withValues(alpha: 0.30), width: 1),
      ),
      child: Text(active.obj.hint,
          style: const TextStyle(
            color: MedievalTheme.textPrimary,
            fontSize: 9,
            height: 1.4,
            fontFamily: 'monospace',
            fontStyle: FontStyle.italic,
          )),
    );
  }
}
