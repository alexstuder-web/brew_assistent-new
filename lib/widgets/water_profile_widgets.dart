import 'package:flutter/material.dart';

class WaterSectionHeader extends StatelessWidget {
  const WaterSectionHeader({
    super.key,
    required this.title,
    required this.accent,
    required this.subtitle,
    this.trailing,
    this.trailingColor,
  });

  final String title;
  final Color accent;
  final String subtitle;
  final String? trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: '$title ',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                  children: [
                    TextSpan(
                      text: subtitle,
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: TextStyle(
                  color: trailingColor ?? Colors.white70,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        Container(height: 2, width: 64, color: accent),
      ],
    );
  }
}

class WaterIonTile extends StatelessWidget {
  const WaterIonTile({
    super.key,
    required this.title,
    required this.controller,
    this.fieldKey,
    this.onChanged,
  });

  final String title;
  final TextEditingController controller;
  final Key? fieldKey;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0F172A),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ppm',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.6),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            key: fieldKey,
            controller: controller,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Wert',
              hintText: 'z. B. 50',
            ),
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}

class WaterStatTile extends StatelessWidget {
  const WaterStatTile({
    super.key,
    required this.width,
    required this.label,
    required this.value,
  });

  final double width;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: const Color(0xFF0F172A),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
