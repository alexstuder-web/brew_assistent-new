import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bf_batch.dart';
import '../batch_detail_widgets.dart';

class FermentingEreignisseSection extends StatelessWidget {
  const FermentingEreignisseSection({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    final events = (batch.data['events'] as List?) ?? [];
    final dateFormat = DateFormat('EEEE, d. MMMM yyyy HH:mm', 'de_DE');

    return BatchDetailCardSection(
      title: 'Ereignisse',
      children: [
        ...events.map((e) {
          DateTime dt = DateTime.fromMillisecondsSinceEpoch(e['time']);
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                    flex: 4,
                    child: Text(dateFormat.format(dt),
                        style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 11,
                            fontStyle: FontStyle.italic))),
                Expanded(
                    flex: 6,
                    child: Text(e['title'] ?? e['eventType'] ?? '',
                        style: const TextStyle(
                            fontSize: 11, fontStyle: FontStyle.italic))),
                const Icon(Icons.edit, size: 14, color: Colors.grey)
              ],
            ),
          );
        })
      ],
    );
  }
}
