import 'package:flutter/material.dart';
import '../batch_detail_widgets.dart';

class FermentingZusammenfassungSection extends StatelessWidget {
  const FermentingZusammenfassungSection({super.key});

  Widget _buildSummaryRow(String label, String target, String actual, bool isDiff) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 12, color: Colors.grey))),
          SizedBox(
            width: 120,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(target, style: const TextStyle(fontSize: 12)),
                Text(actual,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDiff ? Colors.redAccent : Colors.greenAccent)),
              ],
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BatchDetailCardSection(
      title: 'Zusammenfassung',
      children: [
        _buildSummaryRow('Kessel nach dem Kochen', '25.0', '25.5', true),
        _buildSummaryRow('Stammwürze nach dem Kochen', '1.048', '1.050', true),
        _buildSummaryRow('Sudhausausbeute', '70', '72', false),
      ],
    );
  }
}
