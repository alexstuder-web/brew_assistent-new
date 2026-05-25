import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/bf_batch.dart';
import '../../widgets/fermenting_tab_widgets.dart';

class FermentingTab extends StatelessWidget {
  const FermentingTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    final recipe = batch.data['recipe'] ?? {};
    final fermentation = recipe['fermentation'] ?? {};
    final steps = (fermentation['steps'] as List?) ?? [];

    final yeasts = batch.data['batchYeastsLocal'] ?? recipe['yeasts'] ?? [];
    final miscs = batch.data['batchMiscsLocal'] ?? [];

    final brewDateMs = batch.data['fermentationStartDate'] ?? batch.data['brewDate'];
    final bottlingDateMs = batch.data['bottlingDate'];
    final dateFormat = DateFormat('dd.MM.yyyy');

    final startDateStr = brewDateMs != null
        ? dateFormat.format(DateTime.fromMillisecondsSinceEpoch(brewDateMs))
        : '-';
    final bottlingDateStr = bottlingDateMs != null
        ? dateFormat.format(DateTime.fromMillisecondsSinceEpoch(bottlingDateMs))
        : '-';

    List<FlSpot> targetTempSpots = [];
    double currentDay = 0;
    if (steps.isNotEmpty) {
      double startTemp = (steps.first['stepTemp'] as num).toDouble();
      targetTempSpots.add(FlSpot(0, startTemp));
    }
    for (var step in steps) {
      double temp = (step['stepTemp'] as num).toDouble();
      double days = (step['stepTime'] as num).toDouble();
      targetTempSpots.add(FlSpot(currentDay + days, temp));
      currentDay += days;
    }

    return LayoutBuilder(builder: (context, constraints) {
      bool isWide = constraints.maxWidth > 900;

      Widget leftColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FermentingMesswerteSection(
            targetTempSpots: targetTempSpots,
          ),
          const SizedBox(height: 16),
          FermentingGatProfileRow(
            batch: batch,
            steps: steps,
            startDate: startDateStr,
            bottlingDate: bottlingDateStr,
            brewDateMs: brewDateMs,
          ),
          const SizedBox(height: 16),
          FermentingBeigabenSection(
            yeasts: yeasts,
            miscs: miscs,
          ),
        ],
      );

      Widget rightColumn = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FermentingGemesseneWerteSection(batch: batch),
          const SizedBox(height: 16),
          FermentingKarbonisierungSection(batch: batch),
          const SizedBox(height: 16),
          FermentingStatistikenSection(batch: batch),
          const SizedBox(height: 16),
          const FermentingZusammenfassungSection(),
          const SizedBox(height: 16),
          FermentingEreignisseSection(batch: batch),
        ],
      );

      if (isWide) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 4, child: leftColumn),
                  const SizedBox(width: 16),
                  Expanded(flex: 2, child: rightColumn),
                ],
              ),
            ),
          ),
        );
      } else {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                children: [
                  leftColumn,
                  const SizedBox(height: 16),
                  rightColumn,
                ],
              ),
            ),
          ),
        );
      }
    });
  }
}
