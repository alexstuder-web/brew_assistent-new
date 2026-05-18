import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/bf_batch.dart';

class CompletedTab extends StatelessWidget {
  const CompletedTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  Widget build(BuildContext context) {
    final batchData = batch.data;
    final recipe = batchData['recipe'] ?? {};

    String val(dynamic v, {String suffix = '', String def = '-'}) {
      if (v == null || v == '') return def;
      if (v is num && (v.isInfinite || v.isNaN)) return 'Infinity';
      return '$v$suffix';
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Geschmack', icon: Icons.local_drink),
          const SizedBox(height: 16),
          const Text('Bewertung',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          Slider(
            value:
                (batchData['tasteRating'] as num? ?? 0).toDouble().clamp(0, 50),
            min: 0,
            max: 50,
            divisions: 50,
            activeColor: const Color(0xFF66B342),
            inactiveColor: Colors.grey[800],
            onChanged: (val) {},
            label: (batchData['tasteRating'] as num? ?? 0).toString(),
          ),
          Align(
              alignment: Alignment.centerRight,
              child: Text(
                  (batchData['tasteRating'] as num? ?? 0).toDouble().toString(),
                  style: const TextStyle(fontSize: 12))),
          const SizedBox(height: 12),
          const Text('Anmerkungen zum Geschmack',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
          Text(batchData['tasteNotes'] ?? '',
              style: const TextStyle(fontSize: 14)),
          const Divider(height: 48, color: Colors.white12),
          _buildSectionHeader('Gemessene Werte',
              icon: Icons.straighten,
              action: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 28)),
                  child: const Text('+ HINZUFÜGEN',
                      style: TextStyle(color: Colors.white, fontSize: 10)))),
          const SizedBox(height: 16),
          _buildGridValues([
            _buildGridItem('Maischen', val(batchData['measuredMashPh']), 'pH'),
            _buildGridItem(
                'Kochvolumen', val(batchData['measuredBoilSize']), 'L'),
            _buildGridItem(
                'Stammwürze vor Kochen', val(recipe['preBoilGravity']), 'SG'),
            _buildGridItem('Stammwürze nach dem Kochen',
                val(batchData['measuredPostBoilGravity']), 'SG'),
            _buildGridItem(
                'Kochkessel Vol', val(batchData['measuredKettleVolume']), 'L'),
            _buildGridItem('Stammwürze', val(batchData['measuredOg']), 'SG'),
            _buildGridItem(
                'Auffüllmenge Gärtank', val(batchData['topUpWater']), 'L'),
            _buildGridItem('Gärtank Vol',
                val(batchData['measuredFermenterVolume']), 'L'),
            _buildGridItem('Restextrakt', val(batchData['measuredFg']), 'SG'),
            _buildGridItem(
                'Abfüllmenge', val(batchData['measuredBottlingSize']), 'L'),
            _buildGridItem('Temperatur Karbonisierung',
                val(batchData['carbonationTemp']), '°C'),
            const SizedBox(),
          ]),
          const Divider(height: 48, color: Colors.white12),
          _buildSectionHeader('Statistiken', icon: Icons.bar_chart),
          const SizedBox(height: 16),
          _buildGridValues([
            _buildGridItem('ALK', val(batchData['measuredAbv']), '%'),
            _buildGridItem(
                'Vergärungsgrad', val(batchData['measuredAttenuation']), '%'),
            _buildGridItem('Maische Effizienz',
                val(batchData['measuredMashEfficiency']), '%'),
            _buildGridItem(
                'Gesamteffizienz', val(batchData['measuredEfficiency']), '%'),
          ]),
          const Divider(height: 48, color: Colors.white12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(children: [
                Icon(Icons.list, color: Colors.grey, size: 18),
                SizedBox(width: 8),
                Text('Zusammenfassung',
                    style: TextStyle(
                        fontWeight: FontWeight.bold, color: Colors.grey)),
              ]),
              Row(
                children: [
                  Switch(
                      value: true,
                      onChanged: (v) {},
                      activeTrackColor: const Color(0xFF66B342)),
                  const SizedBox(width: 8),
                  OutlinedButton(
                      onPressed: () {},
                      child: const Text('ANGEPASSTES REZEPT',
                          style: TextStyle(fontSize: 10)))
                ],
              )
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Messung', 'Rezept', 'Sud', isHeader: true),
          const Divider(color: Colors.white24),
          _buildSummaryRow('Volumen vor Kochen (Heiß)', val(recipe['boilSize']),
              val(recipe['boilSize'])),
          _buildSummaryRow(
              'Verdampfung pro Stunde',
              val(recipe['equipment']?['boilOffPerHr']),
              val(recipe['equipment']?['boilOffPerHr'])),
          _buildSummaryRow(
              'Sudgröße', val(recipe['batchSize']), val(recipe['batchSize'])),
          _buildSummaryRow('Stammwürze vor Kochen', val(recipe['preBoilGravity']),
              val(recipe['preBoilGravity'])),
          const Divider(height: 48, color: Colors.white12),
          _buildSectionHeader('Protokoll',
              icon: Icons.edit,
              action: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                      minimumSize: const Size(0, 28)),
                  child: const Text('+ HINZUFÜGEN',
                      style: TextStyle(fontSize: 10, color: Colors.white)))),
          const SizedBox(height: 16),
          ...((batchData['notes'] as List? ?? []).map((n) {
            final note =
                n is Map ? n : {'note': n.toString(), 'timestamp': 0, 'status': ''};
            final dateStr = note['timestamp'] != null
                ? DateFormat('dd. MMM. yyyy HH:mm').format(
                    DateTime.fromMillisecondsSinceEpoch(note['timestamp']))
                : '-';
            String msg = note['note'] ?? '';
            final status = note['status'];
            if (status != null && status.toString().isNotEmpty) {
              msg += ' \u2192 $status';
            }
            if (msg.trim().isEmpty && note['type'] == 'statusChanged') {
              return const SizedBox.shrink();
            }

            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Text('$dateStr ',
                        style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    if (status != null)
                      Text(
                          status == 'Fermenting'
                              ? '\u2192 In Gärung'
                              : (status == 'Brewing' ? '\u2192 Brauen' : status),
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12)),
                  ]),
                  const SizedBox(height: 4),
                  Text(note['note'] ?? '', style: const TextStyle(fontSize: 14)),
                ],
              ),
            );
          })),
          const Divider(height: 48, color: Colors.white12),
          _buildSectionHeader('Ereignisse',
              icon: Icons.event,
              action: Switch(
                  value: true,
                  onChanged: (v) {},
                  activeTrackColor: const Color(0xFF66B342))),
          const SizedBox(height: 8),
          ...((batchData['events'] as List? ?? []).map((e) {
            final dateStr = e['time'] != null
                ? DateFormat('EEEE, d. MMMM yyyy HH:mm')
                    .format(DateTime.fromMillisecondsSinceEpoch(e['time']))
                : '-';
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10))),
              child: Row(
                children: [
                  Expanded(
                      child: Text(dateStr,
                          style:
                              const TextStyle(color: Colors.grey, fontSize: 12))),
                  Expanded(
                      child: Text(e['eventText'] ?? e['title'] ?? '',
                          style: const TextStyle(fontSize: 12))),
                  const Icon(Icons.edit, size: 14, color: Colors.grey)
                ],
              ),
            );
          })),
          const SizedBox(height: 40),
          _buildFooter(batchData),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, {IconData? icon, Widget? action}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      color: const Color(0xFF1E1E1E),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: Colors.grey),
            const SizedBox(width: 8)
          ],
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.bold, color: Colors.grey)),
          const Spacer(),
          if (action != null) action
        ],
      ),
    );
  }

  Widget _buildGridValues(List<Widget> items) {
    return LayoutBuilder(builder: (ctx, constr) {
      int cols = constr.maxWidth > 600 ? 2 : 1;
      return Wrap(
        spacing: 32,
        runSpacing: 16,
        children: items
            .map((i) =>
                SizedBox(width: (constr.maxWidth - (cols - 1) * 32) / cols, child: i))
            .toList(),
      );
    });
  }

  Widget _buildGridItem(String label, String value, String unit) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        Padding(
          padding: const EdgeInsets.only(bottom: 4.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(unit, style: const TextStyle(color: Colors.grey, fontSize: 10)),
              Text(value,
                  style:
                      const TextStyle(fontSize: 16, fontWeight: FontWeight.normal)),
            ],
          ),
        )
      ],
    );
  }

  Widget _buildSummaryRow(String col1, String col2, String col3,
      {bool isHeader = false}) {
    final style = TextStyle(
        fontSize: 12,
        color: isHeader ? Colors.white : Colors.grey[400],
        fontWeight: isHeader ? FontWeight.bold : FontWeight.normal);
    final valStyle = TextStyle(
        fontSize: 12,
        color: isHeader ? Colors.white : Colors.green[300],
        fontWeight: isHeader ? FontWeight.normal : FontWeight.bold);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          Expanded(
              flex: 4,
              child: Text(col1,
                  style: isHeader
                      ? style
                      : const TextStyle(fontSize: 12, color: Colors.white))),
          Expanded(
              flex: 1,
              child: Text(col2,
                  textAlign: TextAlign.right,
                  style: isHeader
                      ? style
                      : const TextStyle(fontSize: 12, color: Colors.white))),
          Expanded(
              flex: 1, child: Text(col3, textAlign: TextAlign.right, style: valStyle)),
        ],
      ),
    );
  }

  Widget _buildFooter(Map batchData) {
    String created = '-';
    if (batchData['_created'] != null && batchData['_created']['_seconds'] != null) {
      created = DateFormat('dd. MMM yyyy HH:mm').format(
          DateTime.fromMillisecondsSinceEpoch(
              batchData['_created']['_seconds'] * 1000));
    }
    return Text(
        "Erstellt $created Zuletzt gespeichert ${DateFormat('dd. MMM yyyy HH:mm').format(DateTime.now())}",
        style: const TextStyle(fontSize: 10, color: Colors.grey));
  }
}
