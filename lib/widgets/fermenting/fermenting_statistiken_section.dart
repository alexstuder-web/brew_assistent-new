import 'package:flutter/material.dart';
import '../../models/bf_batch.dart';
import '../batch_detail_widgets.dart';

class FermentingStatistikenSection extends StatelessWidget {
  const FermentingStatistikenSection({super.key, required this.batch});

  final BfBatch batch;

  Widget _buildStatItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(value,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(width: 4),
            Text(unit, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final r = batch.data['recipe'] ?? {};
    final abv = r['abv'] ?? 0;
    final att = r['attenuation'] ?? 0;
    final mashEff = r['mashEfficiency'] ?? 0;
    final totEff = r['efficiency'] ?? 0;

    return BatchDetailCardSection(
      title: 'Statistiken',
      children: [
        Row(
          children: [
            Expanded(child: _buildStatItem('ALK', '$abv', '%')),
            Expanded(child: _buildStatItem('Vergärungsgrad', '$att', '%')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatItem('Maische Effizienz', '$mashEff', '%')),
            Expanded(child: _buildStatItem('Gesamteffizienz', '$totEff', '%')),
          ],
        ),
      ],
    );
  }
}
