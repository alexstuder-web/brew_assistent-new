import 'package:flutter/material.dart';
import '../../models/bf_batch.dart';
import '../batch_detail_widgets.dart';

class FermentingGemesseneWerteSection extends StatelessWidget {
  const FermentingGemesseneWerteSection({super.key, required this.batch});

  final BfBatch batch;

  Widget _buildDottedRow(String label, String value, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: CustomPaint(
                painter: DottedLinePainter(),
              ),
            ),
          ),
          Text(value,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(width: 4),
          Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final data = batch.data;
    final recipe = data['recipe'] ?? {};

    return BatchDetailCardSection(
      title: 'Gemessene Werte',
      children: [
        _buildDottedRow(
            'Stammwürze', data['measuredOg']?.toString() ?? 'Infinity', 'SG'),
        _buildDottedRow('Gärtank-Vol',
            recipe['equipment']?['fermenterVolume']?.toString() ?? '0', 'L'),
        _buildDottedRow('Abfüllmenge',
            recipe['equipment']?['bottlingVolume']?.toString() ?? '0', 'L'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildDottedRow('Auffüllmenge Gärtank', '0', 'L')),
            const SizedBox(width: 16),
            Expanded(
                child: _buildDottedRow('Restextrakt',
                    data['measuredFg']?.toString() ?? 'Infinity', 'SG')),
          ],
        ),
        const SizedBox(height: 8),
        _buildDottedRow('Temperatur Karbonisierung', '4', '°C'),
      ],
    );
  }
}
