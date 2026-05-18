import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../models/bf_batch.dart';
import '../../controllers/fermenting_controller.dart';
import '../../widgets/fermenting_tab_widgets.dart';

class FermentingTab extends StatefulWidget {
  const FermentingTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  State<FermentingTab> createState() => _FermentingTabState();
}

class _FermentingTabState extends State<FermentingTab> {
  late final FermentingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FermentingController(widget.batch);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final recipe = widget.batch.data['recipe'] ?? {};
    final fermentation = recipe['fermentation'] ?? {};
    final steps = (fermentation['steps'] as List?) ?? [];

    final yeasts = widget.batch.data['batchYeastsLocal'] ?? recipe['yeasts'] ?? [];
    final miscs = widget.batch.data['batchMiscsLocal'] ?? [];

    final brewDateMs = widget.batch.data['fermentationStartDate'] ?? widget.batch.data['brewDate'];
    final bottlingDateMs = widget.batch.data['bottlingDate'];
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

    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: LayoutBuilder(builder: (context, constraints) {
                bool isWide = constraints.maxWidth > 900;

                Widget leftColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FermentingMesswerteSection(
                      useRaptData: _controller.useRaptData,
                      isLoadingRapt: _controller.isLoadingRapt,
                      raptError: _controller.raptError,
                      raptData: _controller.raptData,
                      raptStartDate: _controller.raptStartDate,
                      raptEndDate: _controller.raptEndDate,
                      targetTempSpots: targetTempSpots,
                      onUseRaptChanged: _controller.setUseRaptData,
                      onStartDateChanged: (dt) => _controller.setRaptDates(dt, _controller.raptEndDate),
                      onEndDateChanged: (dt) => _controller.setRaptDates(_controller.raptStartDate, dt),
                    ),
                    const SizedBox(height: 16),
                    FermentingGatProfileRow(
                      batch: widget.batch,
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
                    FermentingGemesseneWerteSection(batch: widget.batch),
                    const SizedBox(height: 16),
                    FermentingKarbonisierungSection(batch: widget.batch),
                    const SizedBox(height: 16),
                    FermentingStatistikenSection(batch: widget.batch),
                    const SizedBox(height: 16),
                    const FermentingZusammenfassungSection(),
                    const SizedBox(height: 16),
                    FermentingEreignisseSection(batch: widget.batch),
                  ],
                );

                if (isWide) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(flex: 4, child: leftColumn),
                      const SizedBox(width: 16),
                      Expanded(flex: 2, child: rightColumn),
                    ],
                  );
                } else {
                  return Column(
                    children: [
                      leftColumn,
                      const SizedBox(height: 16),
                      rightColumn,
                    ],
                  );
                }
              }),
            ),
          ),
        );
      },
    );
  }
}
