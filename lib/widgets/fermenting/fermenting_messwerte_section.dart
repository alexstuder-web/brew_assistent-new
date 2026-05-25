import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../batch_detail_widgets.dart';

/// Zeigt das Gärkurven-Soll-Profil (Zieltemperaturen aus dem Rezept).
/// RAPT-Telemetrie-Anzeige wurde in Phase 5 entfernt —
/// Echtzeit-Fermentationsdaten sind ausschliesslich im rapt_dashboard verfügbar.
class FermentingMesswerteSection extends StatelessWidget {
  const FermentingMesswerteSection({
    super.key,
    required this.targetTempSpots,
  });

  final List<FlSpot> targetTempSpots;

  @override
  Widget build(BuildContext context) {
    return BatchDetailCardSection(
      title: 'Messwerte',
      children: [
        if (targetTempSpots.isNotEmpty)
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
        else
          const SizedBox(
              height: 80,
              child: Center(
                  child: Text(
                'Kein Gärprofil im Rezept hinterlegt.',
                style: TextStyle(color: Colors.grey),
              ))),
      ],
    );
  }
}
