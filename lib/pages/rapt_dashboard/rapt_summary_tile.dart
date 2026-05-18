import 'package:flutter/material.dart';

class RaptSummaryTile extends StatelessWidget {
  final String label;
  final double? value;
  final String unit;
  final Color color;
  final Widget? extra;

  const RaptSummaryTile({
    super.key,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.extra,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.65),
        border: Border.all(color: color.withValues(alpha: 0.4)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: Colors.indigo[100], fontSize: 13, letterSpacing: 0.5)),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value != null 
                  ? ((label.toUpperCase() == 'GRAVITY') ? value!.toStringAsFixed(4) : value!.toStringAsFixed(1)) 
                  : '–',
                style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 4),
              Text(unit, style: const TextStyle(color: Colors.white70, fontSize: 14)),
            ],
          ),
          if (extra != null) ...[
            const SizedBox(height: 8),
            extra!,
          ],
        ],
      ),
    );
  }
}
