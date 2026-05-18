import 'package:flutter/material.dart';
import '../../models/bf_batch.dart';
import '../batch_detail_widgets.dart';

class FermentingKarbonisierungSection extends StatelessWidget {
  const FermentingKarbonisierungSection({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    final recipe = batch.data['recipe'] ?? {};
    final dynamic carbonationField = recipe['carbonation'];

    double? carbonationVolumes;
    String? carbonationMethod;

    if (carbonationField is Map) {
      carbonationVolumes = (carbonationField['vols'] as num?)?.toDouble();
      carbonationMethod = carbonationField['method']?.toString();
    } else if (carbonationField is num) {
      carbonationVolumes = carbonationField.toDouble();
    }

    String method =
        batch.data['carbonationType'] ?? carbonationMethod ?? 'Keg';
    String info =
        '-1.05 Bar bei 4 °C\nfür etwa 1 Wochen\num ${carbonationVolumes ?? 0} Vol CO₂ zu erreichen';

    return BatchDetailCardSection(
      title: 'Karbonisierung',
      children: [
        const Text('Typ', style: TextStyle(color: Colors.grey, fontSize: 12)),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(method, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Icon(Icons.arrow_drop_down, color: Colors.grey)
          ],
        ),
        const Divider(color: Colors.white12),
        const SizedBox(height: 8),
        Center(
          child: Text(info,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 13)),
        )
      ],
    );
  }
}
