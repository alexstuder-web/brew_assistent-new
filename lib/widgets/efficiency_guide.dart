import 'package:flutter/material.dart';

class EfficiencyGuideDialog extends StatelessWidget {
  const EfficiencyGuideDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.lightbulb_outline, color: Colors.amber),
          SizedBox(width: 12),
          Text('Effizienz steigern: Checkliste'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStep(
              context,
              '1',
              'Schrotbild optimieren',
              'Das Malz darf nicht zu grob sein. Ziel: Kern gebrochen, Spelzen erhalten. Walzenabstand ca. 1,1 - 1,2 mm.',
            ),
            _buildStep(
              context,
              '2',
              'Maische-pH einstellen',
              'Enzyme arbeiten am besten bei pH 5,2 - 5,5. Nutze Milchsäure oder Sauermalz, um den Wert zu senken.',
            ),
            _buildStep(
              context,
              '3',
              'Langsames Läutern',
              'Nicht hetzen! Der Nachguss sollte langsam durch das Bett fließen. Temperatur: exakt 78 °C.',
            ),
            _buildStep(
              context,
              '4',
              'Hydrierung (Nester vermeiden)',
              'Rühre beim Einmaischen extrem gründlich um. Trockene Malz-Klumpen (Nester) geben keinen Zucker ab.',
            ),
            _buildStep(
              context,
              '5',
              'Flow-Rate prüfen',
              'Beim B40: Pumpe so einstellen, dass die Würze oben sanft überläuft, ohne das Malzbett unten zusammenzupressen.',
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Verstanden'),
        ),
      ],
    );
  }

  Widget _buildStep(BuildContext context, String num, String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: Colors.blueAccent.withValues(alpha: 0.2),
            child: Text(num, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
