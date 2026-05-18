import 'package:flutter/material.dart';
import '../../models/bf_batch.dart';

class BrewingTab extends StatelessWidget {
  const BrewingTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    final recipe = batch.data['recipe'] ?? {};
    final equipment = recipe['equipment'] ?? {};
    final water = recipe['water'] ?? {};
    final mash = recipe['mash'] ?? {};
    final mashSteps = mash['steps'] as List? ?? [];
    final fermentables = recipe['fermentables'] as List?;
    final hops = recipe['hops'] as List?;
    final yeasts = recipe['yeasts'] as List?;
    final fermentation = recipe['fermentation'] ?? {};
    final fermSteps = fermentation['steps'] as List?;

    double totalFermentables = 0;
    if (fermentables != null) {
      for (var f in fermentables) {
        totalFermentables += (f['amount'] as num? ?? 0).toDouble();
      }
    }

    double totalHops = 0;
    if (hops != null) {
      for (var h in hops) {
        double raw = (h['amount'] as num? ?? 0).toDouble();
        if (raw < 2.0 && (h['unit'] == 'kg' || h['unit'] == null)) {
          totalHops += raw * 1000;
        } else {
          totalHops += raw;
        }
      }
    }

    String type = recipe['type'] ?? 'Unknown';
    if (type == 'All Grain') type = 'Maischesud';

    TextStyle headerStyle = const TextStyle(
        fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white);
    TextStyle textStyle =
        const TextStyle(fontSize: 12, color: Colors.grey, height: 1.5);
    TextStyle boldText = const TextStyle(
        fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(recipe['name'] ?? 'Unbenannt',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white)),
              Text(type, style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 24),
              if (equipment.isNotEmpty) ...[
                Text(equipment['name'] ?? '', style: boldText),
                Text("${recipe['efficiency'] ?? '-'}% Ausbeute",
                    style: textStyle),
                Text("Sudgröße: ${recipe['batchSize'] ?? '-'} L",
                    style: textStyle),
                Text("Kochzeit: ${recipe['boilTime'] ?? '-'} min",
                    style: textStyle),
                const SizedBox(height: 16),
              ],
              _buildWaterSummary(recipe, water, textStyle),
              Text('Eckdaten', style: headerStyle),
              Text(
                  "Stammwürze: ${recipe['og'] ?? recipe['preBoilGravity'] ?? '-'} SG",
                  style: textStyle),
              Text("Restextrakt: ${recipe['fg'] ?? '-'} SG", style: textStyle),
              Text("IBU (Tinseth): ${recipe['ibu'] == 0 ? '-' : (recipe['ibu'] ?? '-')}",
                  style: textStyle),
              Text("Farbe: ${recipe['color'] ?? '-'} EBC", style: textStyle),
              const SizedBox(height: 24),
              Text('Maischen', style: headerStyle),
              if (mashSteps.isEmpty) Text('-', style: textStyle),
              ...mashSteps.map((step) => Text(
                  "${step['name'] ?? 'Schritt'} — ${step['stepTemp']} °C — ${step['stepTime']} min",
                  style: textStyle)),
              const SizedBox(height: 24),
              Text('Malze (${totalFermentables.toStringAsFixed(2)} kg)',
                  style: headerStyle),
              if (fermentables == null || fermentables.isEmpty)
                Text('-', style: textStyle),
              if (fermentables != null)
                ...fermentables.map((f) => _buildFermentableRow(
                    f, totalFermentables, textStyle, boldText)),
              const SizedBox(height: 24),
              Text('Hopfen (${totalHops.toStringAsFixed(1)} g)',
                  style: headerStyle),
              if (hops == null || hops.isEmpty) Text('-', style: textStyle),
              if (hops != null)
                ...hops.map((h) => _buildHopRow(h, textStyle, boldText)),
              const SizedBox(height: 24),
              Text('Hefe', style: headerStyle),
              if (yeasts == null || yeasts.isEmpty) Text('-', style: textStyle),
              if (yeasts != null)
                ...yeasts.map((y) => _buildYeastRow(y, textStyle, boldText)),
              const SizedBox(height: 24),
              Text('Gärung', style: headerStyle),
              if (fermSteps == null || fermSteps.isEmpty)
                Text('-', style: textStyle),
              if (fermSteps != null)
                ...fermSteps.map((s) => Text(
                    "${s['type'] ?? 'Step'} — ${s['stepTemp']} °C — ${s['stepTime']} Tage",
                    style: textStyle)),
              const SizedBox(height: 24),
              Text('Wasserprofil', style: headerStyle),
              _buildWaterProfile(water),
              const SizedBox(height: 40),
              _buildNotes(recipe, textStyle),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWaterSummary(Map recipe, Map water, TextStyle textStyle) {
    final rData = recipe['data'] ?? {};
    final mashWater = rData['mashWaterAmount'] ?? water['mashWaterAmount'];
    final spargeWater = rData['hltWaterAmount'] ?? water['spargeWaterAmount'];
    final totalWater = rData['totalWaterAmount'] ?? water['totalWaterAmount'];
    final kochVol = rData['boilSize'] ?? water['boilSize'] ?? recipe['boilSize'];
    final spargeTemp = water['spargeWaterTemp'] ?? '-';
    final preBoilOg = recipe['preBoilGravity'];

    if (mashWater != null || totalWater != null) {
      return Column(children: [
        if (mashWater != null) Text('Maischwasser: $mashWater L', style: textStyle),
        if (spargeWater != null)
          Text('Nachgusswasser: $spargeWater L @ $spargeTemp °C',
              style: textStyle),
        if (totalWater != null) Text('Wasser gesamt: $totalWater L', style: textStyle),
        if (kochVol != null) Text('Kochvolumen: $kochVol L', style: textStyle),
        if (preBoilOg != null)
          Text('Stammwürze vor Kochen: $preBoilOg', style: textStyle),
        const SizedBox(height: 16),
      ]);
    }
    return const SizedBox.shrink();
  }

  Widget _buildFermentableRow(
      Map f, double totalWeight, TextStyle textStyle, TextStyle boldText) {
    double amount = (f['amount'] as num? ?? 0).toDouble();
    double percent = totalWeight > 0 ? (amount / totalWeight * 100) : 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(style: textStyle, children: [
            TextSpan(text: '${amount.toStringAsFixed(2)} kg ', style: boldText),
            TextSpan(text: '(${percent.toStringAsFixed(1)}%) — '),
            TextSpan(text: "${f['name']} "),
            TextSpan(text: "— ${f['supplier'] ?? ''} — "),
            TextSpan(text: "${f['color']} EBC"),
          ])),
    );
  }

  Widget _buildHopRow(Map h, TextStyle textStyle, TextStyle boldText) {
    double rawAmount = (h['amount'] as num? ?? 0).toDouble();
    double amountG = rawAmount;
    if (amountG < 2.0 && (h['unit'] == 'kg' || h['unit'] == null)) {
      amountG = amountG * 1000;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(style: textStyle, children: [
            TextSpan(text: '${amountG.toStringAsFixed(0)} g ', style: boldText),
            TextSpan(text: "— ${h['name']} ${h['alpha']}% — "),
            TextSpan(
                text: "${h['use'] ?? ''} — ",
                style: const TextStyle(color: Colors.redAccent)),
            TextSpan(text: "${h['time']} min"),
          ])),
    );
  }

  Widget _buildYeastRow(Map y, TextStyle textStyle, TextStyle boldText) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(style: textStyle, children: [
            TextSpan(
                text: "${y['amount'] ?? '-'} ${y['amountUnit'] ?? 'unit'} ",
                style: boldText),
            TextSpan(
                text:
                    "— ${y['name']} ${y['attenuation'] != null ? '${y['attenuation']}%' : ''}"),
          ])),
    );
  }

  Widget _buildWaterProfile(Map water) {
    final adjustments = water['totalAdjustments'] ?? water['meta'];
    if (adjustments != null) {
      return Column(
        children: [
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildWaterIon('Ca²⁺', adjustments['calcium'] ?? adjustments['Ca']),
              _buildWaterIon(
                  'Mg²⁺', adjustments['magnesium'] ?? adjustments['Mg']),
              _buildWaterIon('Na⁺', adjustments['sodium'] ?? adjustments['Na']),
              _buildWaterIon('Cl⁻', adjustments['chloride'] ?? adjustments['Cl']),
              _buildWaterIon(
                  'SO₄²⁻', adjustments['sulfate'] ?? adjustments['SO4']),
              _buildWaterIon(
                  'HCO₃⁻', adjustments['bicarbonate'] ?? adjustments['HCO3']),
            ],
          ),
        ],
      );
    }
    return const Text('Kein Wasserprofil',
        style: TextStyle(color: Colors.grey));
  }

  Widget _buildWaterIon(String name, dynamic value) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          Text(name,
              style: const TextStyle(
                  fontSize: 10,
                  color: Colors.blueAccent,
                  fontWeight: FontWeight.bold)),
          Text(value?.toString() ?? '-',
              style: const TextStyle(fontSize: 12, color: Colors.white)),
        ],
      ),
    );
  }

  Widget _buildNotes(Map recipe, TextStyle textStyle) {
    final notes = recipe['notes'];
    if (notes == null) return const SizedBox.shrink();
    if (notes is String) {
      return Text(notes, style: textStyle, textAlign: TextAlign.center);
    }
    if (notes is List) {
      return Column(
          children: notes
              .map((n) => Text(n is Map ? (n['note'] ?? '') : n.toString(),
                  style: textStyle, textAlign: TextAlign.center))
              .toList());
    }
    return const SizedBox.shrink();
  }
}
