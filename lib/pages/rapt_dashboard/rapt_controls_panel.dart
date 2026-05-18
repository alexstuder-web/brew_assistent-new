import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RaptControlsPanel extends StatelessWidget {
  final DateTime? startDate;
  final Function(DateTime?) onDateChanged;
  final VoidCallback onApply;
  final VoidCallback onReset;
  final VoidCallback onRefresh;
  final String? generatedAt;

  const RaptControlsPanel({
    super.key,
    required this.startDate,
    required this.onDateChanged,
    required this.onApply,
    required this.onReset,
    required this.onRefresh,
    this.generatedAt,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Startdatum (optional)', style: TextStyle(color: Colors.white54, fontSize: 12)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            // Date Picker
            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: startDate ?? DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) {
                  if (!context.mounted) return;
                  final time = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay.fromDateTime(startDate ?? DateTime.now()),
                  );
                  if (time != null) {
                    final dt = DateTime(picked.year, picked.month, picked.day, time.hour, time.minute);
                    onDateChanged(dt);
                  }
                }
              },
              child: Container(
                width: 200,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.6),
                  border: Border.all(color: Colors.white24),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      startDate != null ? DateFormat('dd.MM.yyyy, HH:mm').format(startDate!) : 'Datum wählen...',
                      style: const TextStyle(color: Colors.white),
                    ),
                    const Icon(Icons.calendar_today, size: 16, color: Colors.white54),
                  ],
                ),
              ),
            ),

            // Übernehmen
            SizedBox(
              height: 48,
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: const BorderSide(color: Colors.white24)),
                ),
                child: const Text('Übernehmen'),
              ),
            ),

            // Zurücksetzen
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: onReset,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  side: const BorderSide(color: Colors.white24),
                ),
                child: const Text('Zurücksetzen'),
              ),
            ),


            // Reload
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Reload', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.white24),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.refresh, color: Colors.white),
                    onPressed: onRefresh,
                  ),
                ),
              ],
            )
          ],
        ),
      ],
    );
  }
}
