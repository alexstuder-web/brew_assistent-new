import 'dart:math';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../batch_detail_widgets.dart';

class FermentingMesswerteSection extends StatelessWidget {
  const FermentingMesswerteSection({
    super.key,
    required this.useRaptData,
    required this.isLoadingRapt,
    required this.raptError,
    required this.raptData,
    required this.raptStartDate,
    required this.raptEndDate,
    required this.targetTempSpots,
    required this.onUseRaptChanged,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
  });

  final bool useRaptData;
  final bool isLoadingRapt;
  final String? raptError;
  final List<dynamic> raptData;
  final DateTime? raptStartDate;
  final DateTime? raptEndDate;
  final List<FlSpot> targetTempSpots;

  final ValueChanged<bool> onUseRaptChanged;
  final ValueChanged<DateTime> onStartDateChanged;
  final ValueChanged<DateTime> onEndDateChanged;

  @override
  Widget build(BuildContext context) {
    return BatchDetailCardSection(
      title: 'Messwerte',
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Get Controller Date',
                style: TextStyle(fontSize: 12, color: Colors.white)),
            Switch(
              value: useRaptData,
              onChanged: onUseRaptChanged,
              activeThumbColor: Colors.green,
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (useRaptData) ...[
          Row(
            children: [
              Expanded(
                child: _buildDatePickerField('Start Datum', raptStartDate, context, onStartDateChanged),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildDatePickerField('End Datum', raptEndDate, context, onEndDateChanged),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isLoadingRapt)
            const Center(child: CircularProgressIndicator())
          else if (raptError != null)
            Text(raptError!, style: const TextStyle(color: Colors.red))
          else if (raptData.isEmpty && raptStartDate != null && raptEndDate != null)
            const Text('Keine Daten für diesen Zeitraum.',
                style: TextStyle(color: Colors.grey))
          else if (raptData.isNotEmpty)
            SizedBox(height: 300, child: FermentingChart(raptData: raptData))
          else
            const SizedBox(
                height: 100,
                child: Center(
                    child: Text('Bitte Daten wählen',
                        style: TextStyle(color: Colors.grey)))),
        ] else ...[
          AspectRatio(
            aspectRatio: 1.7,
            child: LineChart(LineChartData(
                gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (value) =>
                        const FlLine(color: Colors.white10, strokeWidth: 1)),
                titlesData: FlTitlesData(
                  leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          getTitlesWidget: (val, meta) => Text(
                              val.toInt().toString(),
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)))),
                  bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                          showTitles: true,
                          interval: 2,
                          getTitlesWidget: (val, meta) => Text('${val.toInt()}d',
                              style: const TextStyle(
                                  fontSize: 10, color: Colors.grey)))),
                  topTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles:
                      const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: targetTempSpots,
                    isCurved: false,
                    color: Colors.greenAccent,
                    barWidth: 2,
                    dotData: const FlDotData(show: false),
                    belowBarData: BarAreaData(
                        show: true,
                        color: Colors.greenAccent.withValues(alpha: 0.1)),
                  )
                ])),
          )
        ]
      ],
    );
  }

  Widget _buildDatePickerField(
      String label, DateTime? date, BuildContext context, Function(DateTime) onChanged) {
    final fmt = DateFormat('dd.MM.yyyy HH:mm');
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
            context: context,
            initialDate: date ?? DateTime.now(),
            firstDate: DateTime(2020),
            lastDate: DateTime.now());
        if (picked != null) {
          if (!context.mounted) return;
          final time = await showTimePicker(
              context: context,
              initialTime: TimeOfDay.fromDateTime(date ?? DateTime.now()));
          if (time != null) {
            onChanged(DateTime(picked.year, picked.month, picked.day, time.hour,
                time.minute));
          }
        }
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            border: Border.all(color: Colors.white24),
            borderRadius: BorderRadius.circular(8),
            color: Colors.white.withValues(alpha: 0.05)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(date != null ? fmt.format(date) : '-',
                    style: const TextStyle(color: Colors.white)),
                const Icon(Icons.calendar_today, size: 14, color: Colors.white54),
              ],
            )
          ],
        ),
      ),
    );
  }
}

class FermentingChart extends StatelessWidget {
  const FermentingChart({super.key, required this.raptData});

  final List<dynamic> raptData;

  @override
  Widget build(BuildContext context) {
    List<dynamic> source = raptData;
    if (source.length > 500) {
      final step = (source.length / 500).ceil();
      List<dynamic> reduced = [];
      for (int i = 0; i < source.length; i += step) {
        reduced.add(source[i]);
      }
      source = reduced;
    }

    final pointsTemp = <FlSpot>[];
    final pointsGravity = <FlSpot>[];
    final rawGravities = <double>[];

    for (final r in source) {
      final t = DateTime.tryParse(r['createdOn'] ?? '')
          ?.millisecondsSinceEpoch
          .toDouble();
      final temp = (r['temperature'] as num?)?.toDouble();
      double? grav = (r['gravity'] as num?)?.toDouble();
      if (grav != null && grav > 500) grav = grav / 1000.0;

      if (t != null) {
        if (temp != null) pointsTemp.add(FlSpot(t, temp));
        if (grav != null) {
          pointsGravity.add(FlSpot(t, grav));
          rawGravities.add(grav);
        }
      }
    }

    double minTemp = pointsTemp.isEmpty
        ? -5
        : pointsTemp.map((e) => e.y).reduce(min) - 5;
    double maxTemp = pointsTemp.isEmpty
        ? 35
        : pointsTemp.map((e) => e.y).reduce(max) + 5;

    double minGrav = pointsGravity.isEmpty
        ? 0.995
        : pointsGravity.map((e) => e.y).reduce(min) - 0.005;
    double maxGrav = pointsGravity.isEmpty
        ? 1.085
        : pointsGravity.map((e) => e.y).reduce(max) + 0.005;

    double normalizeG(double g) {
      if (maxGrav == minGrav) return minTemp + (maxTemp - minTemp) / 2;
      return (g - minGrav) / (maxGrav - minGrav) * (maxTemp - minTemp) + minTemp;
    }

    final pointsAbv = <FlSpot>[];
    final pointsVelocity = <FlSpot>[];

    for (int i = 0; i < source.length; i++) {
      final r = source[i];
      final tEnd = DateTime.tryParse(r['createdOn'] ?? '')
          ?.millisecondsSinceEpoch
          .toDouble();
      if (tEnd == null) continue;

      final windowMs = 12 * 60 * 60 * 1000;
      int? startIdx;
      for (int j = i - 1; j >= 0; j--) {
        final tj = DateTime.tryParse(source[j]['createdOn'] ?? '')
            ?.millisecondsSinceEpoch
            .toDouble();
        if (tj == null) continue;
        startIdx = j;
        if (tj <= tEnd - windowMs) break;
      }

      if (startIdx != null && startIdx != i) {
        final rStart = source[startIdx];
        final t1 = DateTime.tryParse(rStart['createdOn'] ?? '')
            ?.millisecondsSinceEpoch
            .toDouble();
        if (t1 != null) {
          final dtDays = (tEnd - t1) / (1000 * 60 * 60 * 24);
          if (dtDays >= 0.05) {
            double g1 = (rStart['gravity'] as num?)?.toDouble() ?? 0;
            double g2 = (r['gravity'] as num?)?.toDouble() ?? 0;
            if (g1 > 500) g1 /= 1000;
            if (g2 > 500) g2 /= 1000;

            final dg = (g1 - g2) * 1000;
            double vel = dg / dtDays;

            if (vel < 0.3 && i < source.length * 0.2) vel = 0;
            if (vel < 0) vel = 0;

            pointsVelocity.add(FlSpot(tEnd, vel));
          }
        }
      } else {
        pointsVelocity.add(FlSpot(tEnd, 0));
      }
    }

    if (rawGravities.isNotEmpty) {
      final double og = rawGravities.reduce(max);
      double lastAbv = 0.0;

      for (final spot in pointsGravity) {
        final g = spot.y;
        double currentAbv = (og - g) * 131.25;
        if (currentAbv < 0) currentAbv = 0;
        if (currentAbv < lastAbv) {
          currentAbv = lastAbv;
        } else {
          lastAbv = currentAbv;
        }
        pointsAbv.add(FlSpot(spot.x, currentAbv));
      }
    }

    double maxAbv =
        pointsAbv.isEmpty ? 8.0 : pointsAbv.map((e) => e.y).reduce(max) + 1.0;
    double minAbv = -0.5;

    double maxVel = pointsVelocity.isEmpty
        ? 10.0
        : (pointsVelocity.map((e) => e.y).reduce(max) * 1.2 / 5).ceil() * 5.0;
    if (maxVel < 5) maxVel = 5;
    double minVel = 0;

    double normalizeAbv(double a) {
      if (maxAbv == minAbv) return minTemp + (maxTemp - minTemp) / 2;
      return (a - minAbv) / (maxAbv - minAbv) * (maxTemp - minTemp) + minTemp;
    }

    double normalizeVel(double v) {
      if (maxVel == minVel) return minTemp + (maxTemp - minTemp) / 2;
      return (v - minVel) / (maxVel - minVel) * (maxTemp - minTemp) + minTemp;
    }

    return Column(
      children: [
        SizedBox(
          height: 250,
          child: LineChart(LineChartData(
              minY: minTemp,
              maxY: maxTemp,
              lineTouchData: LineTouchData(touchTooltipData: LineTouchTooltipData(
                  getTooltipItems: (List<LineBarSpot> touchedSpots) {
                touchedSpots.sort((a, b) => a.barIndex.compareTo(b.barIndex));

                return touchedSpots.asMap().entries.map((entry) {
                  int idx = entry.key;
                  LineBarSpot spot = entry.value;

                  String txt = '';
                  Color col = Colors.white;

                  if (spot.barIndex == 0) {
                    txt = '${spot.y.toStringAsFixed(1)} °C';
                    col = Colors.blue;
                  } else if (spot.barIndex == 1) {
                    double denorm = (spot.y - minTemp) /
                            (maxTemp - minTemp) *
                            (maxGrav - minGrav) +
                        minGrav;
                    txt = denorm.toStringAsFixed(4);
                    col = Colors.red;
                  } else if (spot.barIndex == 2) {
                    double denorm = (spot.y - minTemp) /
                            (maxTemp - minTemp) *
                            (maxAbv - minAbv) +
                        minAbv;
                    txt = '${denorm.toStringAsFixed(1)} %';
                    col = Colors.amber;
                  } else if (spot.barIndex == 3) {
                    double denorm = (spot.y - minTemp) /
                            (maxTemp - minTemp) *
                            (maxVel - minVel) +
                        minVel;
                    txt = '${(denorm / 1000).toStringAsFixed(4)} SG/Tag';
                    col = Colors.purple;
                  }

                  if (idx == 0) {
                    DateTime date =
                        DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
                    String dateStr = DateFormat('dd.MM.yyyy HH:mm').format(date);
                    return LineTooltipItem(
                        '$dateStr\n$txt',
                        TextStyle(color: col, fontWeight: FontWeight.bold),
                        children: [
                          TextSpan(
                              text: '',
                              style: TextStyle(
                                  color: col, fontWeight: FontWeight.bold))
                        ]);
                  }

                  return LineTooltipItem(txt,
                      TextStyle(color: col, fontWeight: FontWeight.bold));
                }).toList();
              })),
              gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (v) =>
                      const FlLine(color: Colors.white10)),
              titlesData: FlTitlesData(
                bottomTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (val, _) => Text(val.toInt().toString(),
                            style:
                                const TextStyle(color: Colors.blue, fontSize: 10)))),
                rightTitles: AxisTitles(
                    sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (val, _) {
                          if (val < minTemp || val > maxTemp) {
                            return const SizedBox.shrink();
                          }
                          double denorm = (val - minTemp) /
                                  (maxTemp - minTemp) *
                                  (maxGrav - minGrav) +
                              minGrav;
                          return Text(denorm.toStringAsFixed(3),
                              style: const TextStyle(
                                  color: Colors.red, fontSize: 10));
                        })),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
              lineBarsData: [
                LineChartBarData(
                  spots: pointsTemp,
                  color: Colors.blue,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: pointsGravity
                      .map((s) => FlSpot(s.x, normalizeG(s.y)))
                      .toList(),
                  color: Colors.red,
                  barWidth: 2,
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots:
                      pointsAbv.map((s) => FlSpot(s.x, normalizeAbv(s.y))).toList(),
                  color: Colors.amber,
                  barWidth: 2,
                  dashArray: [5, 5],
                  dotData: const FlDotData(show: false),
                ),
                LineChartBarData(
                  spots: pointsVelocity
                      .map((s) => FlSpot(s.x, normalizeVel(s.y)))
                      .toList(),
                  color: Colors.purple.withValues(alpha: 0.5),
                  barWidth: 1.5,
                  isCurved: false,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                      show: true, color: Colors.purple.withValues(alpha: 0.1)),
                ),
              ])),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildLegendItem('Temperatur', Colors.blue),
            const SizedBox(width: 16),
            _buildLegendItem('Extrakt', Colors.red),
            const SizedBox(width: 16),
            _buildLegendItem('Alkohol', Colors.amber),
            const SizedBox(width: 16),
            _buildLegendItem('Aktivität', Colors.purple),
          ],
        )
      ],
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }
}
