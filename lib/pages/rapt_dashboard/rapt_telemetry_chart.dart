import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class RaptTelemetryChart extends StatelessWidget {
  final List<dynamic> telemetryData;

  const RaptTelemetryChart({
    super.key,
    required this.telemetryData,
  });

  @override
  Widget build(BuildContext context) {
    if (telemetryData.isEmpty) {
      return const Center(child: Text('Keine Daten', style: TextStyle(color: Colors.white54)));
    }

    // Prepare Spots
    List<dynamic> source = telemetryData;
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
    final pointsAbv = <FlSpot>[];
    final pointsVelocity = <FlSpot>[];
    
    // 1. Calculate Velocity properly from gravity differences
    final rawVelocities = <FlSpot>[];
    for (int i = 0; i < source.length; i++) {
        final r = source[i];
        final tEnd = DateTime.tryParse(r['createdOn'] ?? '')?.millisecondsSinceEpoch.toDouble();
        if (tEnd == null) continue;
        
        final windowMs = 12 * 60 * 60 * 1000;
        int? startIdx;
        for (int j = i - 1; j >= 0; j--) {
           final tj = DateTime.tryParse(source[j]['createdOn'] ?? '')?.millisecondsSinceEpoch.toDouble();
           if (tj == null) continue;
           startIdx = j;
           if (tj <= tEnd - windowMs) break;
        }
        
        if (startIdx != null && startIdx != i) {
           final rStart = source[startIdx];
           final t1 = DateTime.tryParse(rStart['createdOn'] ?? '')?.millisecondsSinceEpoch.toDouble();
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
                 
                 rawVelocities.add(FlSpot(tEnd, vel));
              }
           }
        } else {
           rawVelocities.add(FlSpot(tEnd, 0));
        }
    }

    // Apply a 2-hour smoothing window (1 hour on each side) to raw velocities
    final smoothingWindowMs = 2 * 60 * 60 * 1000; // 2 hours
    for (int i = 0; i < rawVelocities.length; i++) {
        final currentX = rawVelocities[i].x;
        double sum = 0.0;
        int count = 0;
        for (int j = 0; j < rawVelocities.length; j++) {
            if ((rawVelocities[j].x - currentX).abs() <= (smoothingWindowMs / 2)) {
                sum += rawVelocities[j].y;
                count++;
            }
        }
        if (count > 0) {
            pointsVelocity.add(FlSpot(currentX, sum / count));
        } else {
            pointsVelocity.add(rawVelocities[i]);
        }
    }
    
    final rawGravities = <double>[];
    for (final r in source) {
        final t = DateTime.tryParse(r['createdOn'] ?? '')?.millisecondsSinceEpoch.toDouble();
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
    
    double minTemp = 0;
    double maxTemp = 30;
    if (pointsTemp.isNotEmpty) {
       minTemp = pointsTemp.map((e) => e.y).reduce(min);
       maxTemp = pointsTemp.map((e) => e.y).reduce(max);
    }
    minTemp -= 5;
    maxTemp += 5;

    // 3. Normalized Mapping for Gravity and ABV
    double minGrav = 1.000;
    double maxGrav = 1.100;
    if (pointsGravity.isNotEmpty) {
       minGrav = pointsGravity.map((e) => e.y).reduce(min);
       maxGrav = pointsGravity.map((e) => e.y).reduce(max);
       // Ensure some range
       if (maxGrav - minGrav < 0.005) {
         minGrav -= 0.005;
         maxGrav += 0.005;
       }
       // Add some padding to top/bottom
       double pad = (maxGrav - minGrav) * 0.1;
       minGrav -= pad;
       maxGrav += pad;
    }

    double minAbv = 0;
    double maxAbv = 10;
    if (pointsAbv.isNotEmpty) {
       minAbv = pointsAbv.map((e) => e.y).reduce(min);
       maxAbv = pointsAbv.map((e) => e.y).reduce(max);
       if (maxAbv - minAbv < 1.0) {
         maxAbv = minAbv + 2.0;
       }
       double pad = (maxAbv - minAbv) * 0.1;
       minAbv -= pad;
       maxAbv += pad;
    }
    
    double maxVel = 5;
    if (pointsVelocity.isNotEmpty) {
       maxVel = pointsVelocity.map((e) => e.y).reduce(max);
       if (maxVel < 2) maxVel = 2;
    }
    maxVel *= 1.2;

    // Mapping function: Maps a value from its own [min, max] range to the [minTemp, maxTemp] range
    double mapToTemp(double val, double minVal, double maxVal) {
      if (maxVal == minVal) return minTemp;
      return minTemp + (maxTemp - minTemp) * ((val - minVal) / (maxVal - minVal));
    }

    // Inverse mapping for labels/tooltips
    double inverseMap(double mappedVal, double minVal, double maxVal) {
      if (maxTemp == minTemp) return minVal;
      final ratio = (mappedVal - minTemp) / (maxTemp - minTemp);
      return minVal + ratio * (maxVal - minVal);
    }

    return LineChart(
      LineChartData(
        backgroundColor: Colors.transparent,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
             getTooltipColor: (_) => const Color(0xFF1E293B),
             getTooltipItems: (touchedSpots) {
                return touchedSpots.map((s) {
                   final date = DateTime.fromMillisecondsSinceEpoch(s.x.toInt());
                   final timeStr = DateFormat('dd.MM HH:mm').format(date);
                   
                   if (s.barIndex == 0) return LineTooltipItem('$timeStr\n${s.y.toStringAsFixed(1)}°C', const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold));
                   if (s.barIndex == 1) {
                      final originalSg = inverseMap(s.y, minGrav, maxGrav);
                      return LineTooltipItem('${originalSg.toStringAsFixed(4)} SG', const TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold));
                   }
                   if (s.barIndex == 2) {
                      final originalAbv = inverseMap(s.y, minAbv, maxAbv);
                      return LineTooltipItem('${originalAbv.toStringAsFixed(1)}%', const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold));
                   }
                   if (s.barIndex == 3) {
                      final ratio = (s.y - minTemp) / (maxTemp - minTemp);
                      final originalVel = ratio * maxVel;
                      return LineTooltipItem('${originalVel.toStringAsFixed(1)} P/Tag', const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold));
                   }
                   return null;
                }).toList().whereType<LineTooltipItem>().toList();
             }
          )
        ),
        gridData: const FlGridData(show: true, drawVerticalLine: false, horizontalInterval: 5),
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (val, meta) => Text('${val.toInt()}°', style: const TextStyle(color: Colors.blue, fontSize: 10)),
            ),
          ),
          rightTitles: AxisTitles(
             sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 130, // Increased to fit 3 columns
                getTitlesWidget: (val, meta) {
                   // Only show labels every 5 units on the temp scale
                   if (val % 5 != 0 && val != meta.min && val != meta.max) return const SizedBox();
                   
                   final sg = inverseMap(val, minGrav, maxGrav);
                   final vel = ((val - minTemp) / (maxTemp - minTemp)) * maxVel;
                   final abv = inverseMap(val, minAbv, maxAbv);
                   
                   return Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       SizedBox(
                         width: 45,
                         child: Text(sg.toStringAsFixed(4), textAlign: TextAlign.right, style: const TextStyle(color: Colors.redAccent, fontSize: 9)),
                       ),
                       const SizedBox(width: 8),
                       SizedBox(
                         width: 25,
                         child: Text(vel.toStringAsFixed(0), textAlign: TextAlign.right, style: const TextStyle(color: Colors.greenAccent, fontSize: 9)),
                       ),
                       const SizedBox(width: 8),
                       SizedBox(
                         width: 30,
                         child: Text(abv.toStringAsFixed(1), textAlign: TextAlign.right, style: const TextStyle(color: Colors.amberAccent, fontSize: 9)),
                       ),
                     ],
                   );
                }
             ),
             axisNameWidget: const Padding(
               padding: EdgeInsets.only(left: 8),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.end,
                 children: [
                    RotatedBox(quarterTurns: 1, child: Text('Gravity', style: TextStyle(color: Colors.redAccent, fontSize: 9))),
                    SizedBox(width: 20),
                    RotatedBox(quarterTurns: 1, child: Text('Punkte/Tag', style: TextStyle(color: Colors.greenAccent, fontSize: 9))),
                    SizedBox(width: 15),
                    RotatedBox(quarterTurns: 1, child: Text('Alkohol %', style: TextStyle(color: Colors.amberAccent, fontSize: 9))),
                 ],
               ),
             ),
             axisNameSize: 20,
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (val, meta) {
                final date = DateTime.fromMillisecondsSinceEpoch(val.toInt());
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text(DateFormat('dd.MM').format(date), style: const TextStyle(color: Colors.white54, fontSize: 10)),
                );
              },
              interval: max(1, (telemetryData.last['createdOn'] != null ? DateTime.tryParse(telemetryData.last['createdOn'])?.millisecondsSinceEpoch ?? 0 : 0) - (telemetryData.first['createdOn'] != null ? DateTime.tryParse(telemetryData.first['createdOn'])?.millisecondsSinceEpoch ?? 0 : 0)) / 5,
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: pointsTemp.isNotEmpty ? pointsTemp.first.x : 0,
        maxX: pointsTemp.isNotEmpty ? pointsTemp.last.x : 0,
        minY: minTemp,
        maxY: maxTemp,
        lineBarsData: [
          // Temp
          LineChartBarData(
            spots: pointsTemp,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.blue.withValues(alpha: 0.1)),
          ),
          // Gravity (mapped)
          LineChartBarData(
            spots: pointsGravity.map((s) => FlSpot(s.x, mapToTemp(s.y, minGrav, maxGrav))).toList(),
            isCurved: true,
            color: Colors.red,
            barWidth: 2,
            dotData: const FlDotData(show: false),
          ),
          // ABV (mapped)
          LineChartBarData(
            spots: pointsAbv.map((s) => FlSpot(s.x, mapToTemp(s.y, minAbv, maxAbv))).toList(),
            isCurved: true,
            color: Colors.amber,
            barWidth: 2,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
          // Velocity (scaled to fit)
          LineChartBarData(
            spots: pointsVelocity.map((s) {
               final mappedY = mapToTemp(s.y, 0, maxVel);
               return FlSpot(s.x, mappedY);
            }).toList(),
            isCurved: true,
            color: Colors.green.withValues(alpha: 0.5),
            barWidth: 1,
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.green.withValues(alpha: 0.05)),
          )
        ],
      ),
    );
  }
}
