import 'package:flutter/material.dart';
import '../batch_detail_widgets.dart';

class FermentingBeigabenSection extends StatelessWidget {
  const FermentingBeigabenSection({
    super.key,
    required this.yeasts,
    required this.miscs,
  });

  final List yeasts;
  final List miscs;

  Widget _buildBeigabenRow(String amount, String name) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
          const Text(' - ', style: TextStyle(color: Colors.grey)),
          Expanded(
              child:
                  Text(name, style: const TextStyle(color: Colors.white70))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<Widget> items = [];
    for (var y in yeasts) {
      dynamic amount = y is Map ? y['amount'] : y.amount;
      String unit = y is Map ? (y['unit'] ?? '') : (y.unit ?? '');
      String name = y is Map ? (y['name'] ?? '') : y.name;
      items.add(_buildBeigabenRow('$amount $unit', name));
    }
    for (var m in miscs) {
      dynamic amount = m is Map ? m['amount'] : m.amount;
      String unit = m is Map ? (m['unit'] ?? '') : (m.unit ?? '');
      String name = m is Map ? (m['name'] ?? '') : m.name;
      items.add(_buildBeigabenRow('$amount $unit', name));
    }
    if (items.isEmpty) {
      items.add(const Text('Keine Beigaben',
          style: TextStyle(color: Colors.grey)));
    }

    return BatchDetailCardSection(title: 'Beigaben', children: items);
  }
}
