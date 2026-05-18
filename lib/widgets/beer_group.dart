import 'package:flutter/material.dart';

class BeerGroup extends StatelessWidget {
  const BeerGroup({
    super.key,
    required this.title,
    required this.beers,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> beers;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: beers
              .map(
                (beer) => _BeerChoice(
                  label: beer,
                  groupValue: selected,
                  onTap: () => onSelected(beer),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _BeerChoice extends StatelessWidget {
  const _BeerChoice({
    required this.label,
    required this.groupValue,
    required this.onTap,
  });

  final String label;
  final String? groupValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = groupValue == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white24,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF2563EB) : Colors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
