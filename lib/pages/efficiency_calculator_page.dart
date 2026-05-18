import 'package:flutter/material.dart';
import '../utils/brew_math.dart';
import '../models/brew_kettle.dart';
import '../services/brew_kettle_service.dart';
import '../widgets/efficiency_guide.dart';

class EfficiencyCalculatorPage extends StatefulWidget {
  final BrewKettle? initialKettle;
  const EfficiencyCalculatorPage({super.key, this.initialKettle});

  @override
  State<EfficiencyCalculatorPage> createState() => _EfficiencyCalculatorPageState();
}

class _EfficiencyCalculatorPageState extends State<EfficiencyCalculatorPage> {
  final _formKey = GlobalKey<FormState>();
  final _maltController = TextEditingController();
  final _volumeController = TextEditingController();
  final _ogController = TextEditingController();
  
  double? _calculatedEfficiency;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    // Pre-fill some defaults if available
    if (widget.initialKettle?.volumeLiters != null) {
      // We don't pre-fill batch size as it varies, but OG could be a hint
    }
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      final malt = double.tryParse(_maltController.text.replaceAll(',', '.')) ?? 0;
      final volume = double.tryParse(_volumeController.text.replaceAll(',', '.')) ?? 0;
      final og = double.tryParse(_ogController.text.replaceAll(',', '.')) ?? 1.050;

      setState(() {
        _calculatedEfficiency = BrewMath.calculateEfficiency(
          totalMaltKg: malt,
          volumeL: volume,
          ogSg: og,
        );
      });
    }
  }

  Future<void> _saveToProfile() async {
    if (widget.initialKettle == null || _calculatedEfficiency == null) return;

    setState(() => _isSaving = true);
    try {
      final updatedKettle = widget.initialKettle!.copyWith(
        bhEfficiency: double.parse(_calculatedEfficiency!.toStringAsFixed(1)),
      );
      
      final service = BrewKettleService();
      await service.saveKettle(updatedKettle);
      
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Sudhausausbeute auf ${updatedKettle.bhEfficiency}% aktualisiert!')),
      );
      Navigator.of(context).pop(true); // Return true to trigger refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler beim Speichern: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Effizienz-Rechner'),
        actions: [
          IconButton(
            onPressed: () => showDialog(
              context: context,
              builder: (_) => const EfficiencyGuideDialog(),
            ),
            icon: const Icon(Icons.help_outline),
            tooltip: 'Wie erhöhe ich die Effizienz?',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Bestimme deine reale Sudhausausbeute basierend auf deinen letzten Brauwerten.',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _maltController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Eingesetztes Malz (kg)',
                  suffixText: 'kg',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _volumeController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Volumen im Gäreimer (kalt)',
                  suffixText: 'L',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ogController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: 'Gemessene Stammwürze (OG)',
                  hintText: 'z.B. 1.052',
                  suffixText: 'SG',
                  border: OutlineInputBorder(),
                ),
                validator: (v) => (v == null || v.isEmpty) ? 'Pflichtfeld' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _calculate,
                icon: const Icon(Icons.calculate),
                label: const Text('Effizienz berechnen'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              ),
              if (_calculatedEfficiency != null) ...[
                const SizedBox(height: 32),
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text('Deine reale Sudhausausbeute:'),
                      const SizedBox(height: 8),
                      Text(
                        '${_calculatedEfficiency!.toStringAsFixed(1)} %',
                        style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                      ),
                      const SizedBox(height: 16),
                      if (_calculatedEfficiency! < 65)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: InkWell(
                            onTap: () => showDialog(
                              context: context,
                              builder: (_) => const EfficiencyGuideDialog(),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.amber.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.tips_and_updates, color: Colors.amber, size: 20),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Deine Effizienz ist recht niedrig. Hier sind 5 Tipps, wie du sie verbessern kannst!',
                                      style: TextStyle(fontSize: 12, color: Colors.amberAccent),
                                    ),
                                  ),
                                  Icon(Icons.chevron_right, color: Colors.amber, size: 20),
                                ],
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(height: 16),
                      if (widget.initialKettle != null)
                        OutlinedButton.icon(
                          onPressed: _isSaving ? null : _saveToProfile,
                          icon: _isSaving 
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.save),
                          label: Text('In Profil "${widget.initialKettle!.brand}" übernehmen'),
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.greenAccent),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
