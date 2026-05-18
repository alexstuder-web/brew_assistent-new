import 'package:flutter/material.dart';

class RaptStatusBadge extends StatelessWidget {
  final bool isActive;

  const RaptStatusBadge({
    super.key,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isActive ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
        border: Border.all(color: isActive ? Colors.green : Colors.red.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        isActive ? 'Gärt gerade' : 'Gärt nicht',
        style: TextStyle(
          color: isActive ? Colors.greenAccent : Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class RaptBatteryBadge extends StatelessWidget {
  final double percent;

  const RaptBatteryBadge({
    super.key,
    required this.percent,
  });

  @override
  Widget build(BuildContext context) {
    Color color = Colors.green;
    if (percent < 30) {
      color = Colors.red;
    } else if (percent < 60) {
      color = Colors.yellow;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Pill Batterie', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(width: 6),
          Icon(Icons.battery_std, color: color, size: 16),
          const SizedBox(width: 4),
          Text('${percent.floor()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
