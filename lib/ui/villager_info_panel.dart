import 'package:flutter/material.dart';
import '../characters/life_stage.dart';
import '../characters/villager_type.dart';
import '../entities/villager_entity.dart';
import '../rendering/portrait_renderer.dart';
import 'game_theme.dart';

/// Bir köylüye tıklanınca açılan kişi paneli. İsim, meslek, yaş, ev, durum
/// ve aile bağlarını gösterir. Aile chip'lerine tıklayınca o köylünün
/// paneline geçer (onSelect callback ile).
class VillagerInfoPanel extends StatelessWidget {
  final VillagerEntity villager;
  final String? homeLabel;
  final VoidCallback onClose;
  /// Aile chip'inden başka köylüye atlama. Null ise chip'ler statik metin.
  final void Function(VillagerEntity)? onSelect;

  const VillagerInfoPanel({
    super.key,
    required this.villager,
    required this.onClose,
    this.homeLabel,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final stage = villager.lifeStage;
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      decoration: MedievalTheme.panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(stage),
          MedievalTheme.divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _row('Yaş', '${villager.ageDays.toStringAsFixed(1)} gün'),
                _row('Ev', homeLabel ?? 'Evsiz'),
                _row('Durum', _stateLabel()),
              ],
            ),
          ),
          if (villager.parents.isNotEmpty || villager.children.isNotEmpty) ...[
            MedievalTheme.divider(),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 9),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (villager.parents.isNotEmpty)
                    _familyGroup('Ebeveynler', villager.parents),
                  if (villager.parents.isNotEmpty &&
                      villager.children.isNotEmpty)
                    const SizedBox(height: 6),
                  if (villager.children.isNotEmpty)
                    _familyGroup('Çocuklar', villager.children),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Header ───────────────────────────────────────────────────────────────

  Widget _header(LifeStage stage) {
    final genderIcon = villager.isMale ? '♂' : '♀';
    final profession = villager.hasProfession
        ? '$genderIcon  ${villager.type.displayName}'
        : '$genderIcon  ${stage.label}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [MedievalTheme.panelBgLight, MedievalTheme.panelBg],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border(
          bottom: BorderSide(color: MedievalTheme.panelHighlight, width: 1),
        ),
      ),
      child: Row(
        children: [
          // NPC surat portresi — NpcVisual'dan prosedürel.
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: MedievalTheme.chipBg,
              border: Border.all(color: MedievalTheme.chipBorder, width: 1),
            ),
            child: CustomPaint(
              painter: PortraitPainter(
                visual:        villager.visual,
                stage:         stage,
                type:          villager.type,
                hasProfession: villager.hasProfession,
              ),
            ),
          ),
          const SizedBox(width: 9),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(villager.name,
                    style: MedievalTheme.titleStyle,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                        const Color(0x33D08840), MedievalTheme.chipBg),
                    border: Border.all(
                        color: const Color(0xAAD08840), width: 1),
                  ),
                  child: Text(profession,
                      style: const TextStyle(
                        color: MedievalTheme.textPrimary,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'monospace',
                      )),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: MedievalTheme.chipDecoration(),
              child: const Text('✕',
                  style: TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  )),
            ),
          ),
        ],
      ),
    );
  }

  // ── Body parçaları ──────────────────────────────────────────────────────

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            SizedBox(
              width: 60,
              child: Text(label,
                  style: const TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 9.5,
                    fontFamily: 'monospace',
                  )),
            ),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                    color: MedievalTheme.textPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'monospace',
                  )),
            ),
          ],
        ),
      );

  Widget _familyGroup(String label, List<VillagerEntity> members) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
              color: MedievalTheme.textSecondary,
              fontSize: 9,
              fontFamily: 'monospace',
            )),
        const SizedBox(height: 3),
        Wrap(
          spacing: 4,
          runSpacing: 4,
          children: members.map(_familyChip).toList(),
        ),
      ],
    );
  }

  Widget _familyChip(VillagerEntity v) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: MedievalTheme.chipDecoration(),
      child: Text('${v.lifeStage.icon} ${v.name}',
          style: const TextStyle(
            color: MedievalTheme.textPrimary,
            fontSize: 9,
            fontFamily: 'monospace',
          )),
    );
    if (onSelect == null) return chip;
    return GestureDetector(onTap: () => onSelect!(v), child: chip);
  }

  String _stateLabel() {
    if (villager.isSleeping) return 'uyuyor';
    if (villager.isCarrying) return 'yük taşıyor';
    if (villager.isWalking) return 'yürüyor';
    return 'boşta';
  }
}
