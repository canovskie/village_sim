import 'package:flutter/material.dart';
import 'villager_painter.dart';
import 'villager_type.dart';

class VillagerCard extends StatelessWidget {
  final VillagerType type;

  const VillagerCard({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 100,
          height: 170,
          child: CustomPaint(
            painter: VillagerPainter(type: type, scale: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          type.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
            shadows: [Shadow(color: Colors.black, blurRadius: 4)],
          ),
        ),
      ],
    );
  }
}
