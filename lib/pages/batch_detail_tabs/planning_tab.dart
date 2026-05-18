import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bf_batch.dart';

class PlanningTab extends StatelessWidget {
  const PlanningTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    final recipe = batch.data['recipe'] ?? {};
    final fermentables = (recipe['fermentables'] as List?) ?? [];
    final hops = (recipe['hops'] as List?) ?? [];
    final yeast = (recipe['yeasts'] as List?) ?? [];
    final miscs = (recipe['miscs'] as List?) ?? [];

    // Data sources for water
    final rData = recipe['data'] ?? {};
    final waterData = recipe['water'] ?? {};
    final mashWater = rData['mashWaterAmount'] ?? waterData['mashWaterAmount'];
    final spargeWater =
        rData['hltWaterAmount'] ?? waterData['spargeWaterAmount'];
    final spargeTemp = waterData['spargeWaterTemp'];
    final totalWater =
        rData['totalWaterAmount'] ?? waterData['totalWaterAmount'];
    final mashVolume = rData['mashVolume'];

    String fmtVal(dynamic v, {String suffix = ''}) =>
        v != null ? '$v$suffix' : '-';

    String formatDate(dynamic ts) {
      if (ts == null) return '-';
      if (ts is int) {
        return DateFormat('HH:mm').format(DateTime.fromMillisecondsSinceEpoch(ts));
      }
      return ts.toString();
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: LayoutBuilder(
            builder: (context, constraints) {
              bool isWide = constraints.maxWidth > 800;

              Widget leftColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildIngredientSection('MALZ & GÄRBARES', fermentables, (item) {
                    return _buildRow(item['name'], "${item['color']} EBC",
                        "${item['amount']} kg");
                  }),
                  _buildIngredientSection('HOPFEN', hops, (item) {
                    double amountRaw = (item['amount'] as num? ?? 0).toDouble();
                    double amount = (amountRaw < 2.0 &&
                            (item['unit'] == 'kg' || item['unit'] == null))
                        ? amountRaw * 1000
                        : amountRaw;

                    return _buildRow(
                        item['name'],
                        "${item['alpha']}% AA @ ${item['time']} min (${item['use']})",
                        '${amount.toStringAsFixed(1)} g');
                  }),
                  _buildIngredientSection('HEFE', yeast, (item) {
                    return _buildRow(item['name'], "Typ: ${item['type']}",
                        "${item['amount']} ${item['amountUnit'] ?? 'pkg'}");
                  }),
                  if (miscs.isNotEmpty)
                    _buildIngredientSection('SONSTIGES', miscs, (item) {
                      return _buildRow(
                          item['name'],
                          "${item['type']} @ ${item['time'] ?? '-'} ${item['timeUnit'] ?? ''}",
                          "${item['amount']} ${item['amountUnit'] ?? ''}");
                    }),
                ],
              );

              Widget rightColumn = Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Braudatum',
                      style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                  Text(
                      batch.brewDate != null
                          ? DateFormat('dd.MM.yyyy').format(
                              DateTime.fromMillisecondsSinceEpoch(
                                  batch.brewDate!))
                          : '-',
                      style: const TextStyle(fontSize: 14)),
                  const SizedBox(height: 24),
                  _buildRecipeSummaryCard(recipe),
                  const SizedBox(height: 24),
                  _buildWaterSection(waterData, mashWater, spargeWater,
                      spargeTemp, totalWater, mashVolume, fmtVal),
                  const SizedBox(height: 24),
                  _buildProtocolSection(batch, formatDate),
                  const SizedBox(height: 24),
                  const Text('Sud Notizen',
                      style: TextStyle(color: Colors.grey, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(batch.data['notes'] is String ? batch.data['notes'] : '',
                      style: const TextStyle(fontSize: 12)),
                ],
              );

              if (isWide) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 4, child: leftColumn),
                    const SizedBox(width: 32),
                    Expanded(flex: 2, child: rightColumn),
                  ],
                );
              } else {
                return Column(
                  children: [
                    leftColumn,
                    const Divider(height: 48),
                    rightColumn,
                  ],
                );
              }
            },
          ),
        ),
      ),
    );
  }

  Widget _buildIngredientSection(
      String title, List items, Widget Function(dynamic) rowBuilder) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Text(title,
              style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontWeight: FontWeight.bold)),
        ),
        const Divider(height: 1),
        ...items.map((item) => rowBuilder(item)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildRow(String title, String subtitle, String amount) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[900]!, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: TextStyle(color: Colors.grey[500], fontSize: 12)),
              ],
            ),
          ),
          Text(amount,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecipeSummaryCard(Map recipe) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(4),
      ),
      padding: const EdgeInsets.all(8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            color: Colors.grey[800],
            child: Center(
                child: Icon(Icons.receipt,
                    color: Colors.grey[600])),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(recipe['name'] ?? 'Rezept',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14)),
                const Text('Maischesud',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  "STW ${recipe['og'] ?? '-'}  IBU ${recipe['ibu'] ?? '-'}  EBC ${recipe['color'] ?? '-'}",
                  style: TextStyle(color: Colors.grey[400], fontSize: 11),
                ),
              ],
            ),
          ),
          Row(
            children: [
              IconButton(
                  icon: const Icon(Icons.print, size: 18), onPressed: () {}),
              IconButton(
                  icon: const Icon(Icons.open_in_new, size: 18),
                  onPressed: () {}),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildWaterSection(
      Map waterData,
      dynamic mashWater,
      dynamic spargeWater,
      dynamic spargeTemp,
      dynamic totalWater,
      dynamic mashVolume,
      String Function(dynamic, {String suffix}) fmtVal) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Icon(Icons.water_drop, size: 16, color: Colors.blue[300]),
          const SizedBox(width: 8),
          const Text('Wasser', style: TextStyle(color: Colors.grey)),
          const Spacer(),
          if (waterData['ph'] != null)
            Text("pH ${waterData['ph']}",
                style: TextStyle(color: Colors.green[300], fontSize: 12)),
        ]),
        const SizedBox(height: 8),
        _buildRightColRow("${fmtVal(mashWater, suffix: ' L')} Hauptguss"),
        _buildRightColRow(
            "${fmtVal(spargeWater, suffix: ' L')} Nachgusswasser ${spargeTemp != null ? '@ $spargeTemp °C' : ''}"),
        _buildRightColRow("${fmtVal(totalWater, suffix: ' L')} Wasser gesamt",
            isBold: true),
        _buildRightColRow(
            "${fmtVal(mashVolume, suffix: ' L')} Maischevolumen (Wasser + Malz)"),
      ],
    );
  }

  Widget _buildRightColRow(String text, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 12,
          color: isBold ? Colors.white : Colors.grey[300],
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildProtocolSection(BfBatch batch, String Function(dynamic) formatDate) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          const Icon(Icons.edit_note, size: 16, color: Colors.grey),
          const SizedBox(width: 8),
          const Text('Protokoll', style: TextStyle(color: Colors.grey)),
          const Spacer(),
          OutlinedButton(
              onPressed: () {},
              style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Colors.grey[700]!),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                  minimumSize: const Size(0, 24)),
              child: const Text('+ HINZUFÜGEN',
                  style: TextStyle(fontSize: 10, color: Colors.white)))
        ]),
        const SizedBox(height: 8),
        Builder(builder: (c) {
          var events = batch.data['events'] as List?;
          if (events == null || events.isEmpty) {
            return const Text('Keine Einträge',
                style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                    fontSize: 12));
          }
          return Column(
            children: events
                .map((e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(formatDate(e['time']),
                              style: TextStyle(
                                  color: Colors.grey[500], fontSize: 11)),
                          const SizedBox(width: 8),
                          Expanded(
                              child: Text(e['note'] ?? e['title'] ?? '-',
                                  style: const TextStyle(fontSize: 12))),
                        ],
                      ),
                    ))
                .toList(),
          );
        }),
      ],
    );
  }
}
