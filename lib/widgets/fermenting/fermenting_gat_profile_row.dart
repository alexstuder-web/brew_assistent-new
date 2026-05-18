import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bf_batch.dart';
import '../../services/calendar_service.dart';
import '../batch_detail_widgets.dart';

class FermentingGatProfileRow extends StatelessWidget {
  const FermentingGatProfileRow({
    super.key,
    required this.batch,
    required this.steps,
    required this.startDate,
    required this.bottlingDate,
    required this.brewDateMs,
  });

  final BfBatch batch;
  final List steps;
  final String startDate;
  final String bottlingDate;
  final int? brewDateMs;

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd. MMM. yyyy');

    List<Widget> stepWidgets = [];
    int accumulatedDays = 0;
    DateTime startDt = brewDateMs != null
        ? DateTime.fromMillisecondsSinceEpoch(brewDateMs!)
        : DateTime.now();

    for (var step in steps) {
      String name = step['name'] ?? '';
      num temp = step['stepTemp'] ?? 0;
      num days = step['stepTime'] ?? 0;

      DateTime stepDate = startDt.add(Duration(days: accumulatedDays));
      accumulatedDays += days.toInt();

      stepWidgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                '${dateFormat.format(stepDate)} - $name - $temp °C - $days Tage',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              IconButton(
                icon: const Icon(Icons.event_available, size: 16, color: Colors.greenAccent),
                onPressed: () {
                  CalendarService.addToGoogleCalendar(
                    title: 'Gärung: ${batch.name} ($name)',
                    startTime: stepDate,
                    description: 'Sud: ${batch.name}\nTemperatur: $temp °C\nDauer: $days Tage',
                  );
                },
                tooltip: 'In Kalender eintragen',
              ),
            ],
          ),
        ),
      );
    }

    return BatchDetailCardSection(
      title: 'Gärprofil',
      children: [
        Align(alignment: Alignment.center, child: Column(children: stepWidgets)),
        const SizedBox(height: 20),
        const Divider(color: Colors.white12),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Gärung Start',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(startDate,
                      style: const TextStyle(fontWeight: FontWeight.bold))
                ]),
                const SizedBox(height: 4),
                Container(height: 1, width: 120, color: Colors.white24)
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Datum Abfüllung',
                    style: TextStyle(color: Colors.grey, fontSize: 11)),
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today, size: 14, color: Colors.white),
                  const SizedBox(width: 6),
                  Text(bottlingDate,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  if (batch.data['bottlingDate'] != null)
                    IconButton(
                      icon: const Icon(Icons.event_available, size: 16, color: Colors.greenAccent),
                      onPressed: () {
                        final bDate = DateTime.fromMillisecondsSinceEpoch(batch.data['bottlingDate']);
                        CalendarService.addToGoogleCalendar(
                          title: 'Abfüllung: ${batch.name}',
                          startTime: bDate,
                          description: 'Sud: ${batch.name} abfüllen.',
                        );
                      },
                      tooltip: 'In Kalender eintragen',
                    ),
                ]),
                const SizedBox(height: 4),
                Container(height: 1, width: 120, color: Colors.white24)
              ],
            )
          ],
        )
      ],
    );
  }
}
