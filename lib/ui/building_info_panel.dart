import 'package:flutter/material.dart';
import '../buildings/building_entity.dart';
import '../buildings/building_type.dart';
import '../core/resources.dart';
import '../entities/villager_entity.dart';
import '../entities/miner_entity.dart';
import 'game_theme.dart';

class BuildingInfoPanel extends StatelessWidget {
  final BuildingEntity building;
  final List<VillagerEntity> residents;
  final List<MinerEntity> activeMiners;
  final VoidCallback onClose;

  const BuildingInfoPanel({
    super.key,
    required this.building,
    required this.residents,
    required this.activeMiners,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final meta = kBuildingMeta[building.type]!;
    final isMine = building.type == BuildingType.mineBuilding;

    return Container(
      constraints: const BoxConstraints(maxWidth: 260),
      decoration: MedievalTheme.panelDecoration(),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Başlık çubuğu ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: const BoxDecoration(
              color: MedievalTheme.panelBgLight,
              border: Border(
                bottom: BorderSide(color: MedievalTheme.panelHighlight, width: 1),
              ),
            ),
            child: Row(
              children: [
                MedievalTheme.rivet(),
                const SizedBox(width: 8),
                Text('⌂  ${meta.label}', style: MedievalTheme.titleStyle),
                const Spacer(),
                GestureDetector(
                  onTap: onClose,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: MedievalTheme.chipDecoration(),
                    child: const Text(' ✕ ',
                        style: TextStyle(
                          color: MedievalTheme.textSecondary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        )),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 4),

          // ── Durum satırları ──
          if (isMine) ...[
            _row('Boyut', '${meta.cols}×${meta.rows} tile'),
            _row('Durum', building.isActive ? '⛏ Çalışıyor' : '💤 Boşta',
                valueColor: building.isActive
                    ? MedievalTheme.successColor
                    : MedievalTheme.textSecondary),
            if (activeMiners.isNotEmpty)
              _row('Madenci', '${activeMiners.length} içeride'),
          ] else if (building.type == BuildingType.woodenHouse ||
              building.type == BuildingType.tavern) ...[
            _row('Boyut', '${meta.cols}×${meta.rows} tile'),
            _row('Sakinler', residents.isEmpty ? 'Boş' : '${residents.length} kişi'),
            if (residents.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                child: Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: residents.map((v) => _chip(v.type.name)).toList(),
                ),
              ),
          ] else ...[
            _row('Boyut', '${meta.cols}×${meta.rows} tile'),
            if (building.isActive)
              _row('Durum', 'Aktif', valueColor: MedievalTheme.successColor),
          ],

          if (!meta.cost.isFree) _costRow(meta.cost),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _costRow(ResourceCost cost) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Maliyet:  ',
                style: TextStyle(
                  color: MedievalTheme.textSecondary,
                  fontSize: 11,
                  fontFamily: 'monospace',
                )),
            Expanded(
              child: Wrap(
                spacing: 6,
                runSpacing: 2,
                children: [
                  for (final (kind, amount) in cost.entries)
                    Text('${kind.icon}$amount',
                        style: const TextStyle(
                          color: MedievalTheme.textAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        )),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _row(String label, String value, {Color? valueColor}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          children: [
            Text('$label:  ',
                style: const TextStyle(
                    color: MedievalTheme.textSecondary,
                    fontSize: 11,
                    fontFamily: 'monospace')),
            Text(value,
                style: TextStyle(
                    color: valueColor ?? MedievalTheme.textPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace')),
          ],
        ),
      );

  Widget _chip(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        margin: const EdgeInsets.only(bottom: 2),
        decoration: MedievalTheme.chipDecoration(),
        child: Text(label,
            style: const TextStyle(
                color: MedievalTheme.textPrimary,
                fontSize: 9,
                fontFamily: 'monospace')),
      );
}
