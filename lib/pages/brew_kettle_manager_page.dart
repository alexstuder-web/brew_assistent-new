import 'package:flutter/material.dart';
import '../models/brew_kettle.dart';
import '../services/brew_kettle_service.dart';
import '../utils/dialog_utils.dart';
import '../utils/parse_utils.dart';
import '../widgets/card_actions.dart';
import 'efficiency_calculator_page.dart';

class BrewKettleManagerPage extends StatefulWidget {
  const BrewKettleManagerPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final BrewKettleRepository? repository;

  @override
  State<BrewKettleManagerPage> createState() => _BrewKettleManagerPageState();
}

class _BrewKettleManagerPageState extends State<BrewKettleManagerPage> {
  late final BrewKettleRepository _service;

  @override
  void initState() {
    super.initState();
    _service = widget.repository ?? BrewKettleService();
    _load();
  }

  bool _isLoading = true;
  List<BrewKettle> _kettles = [];
  String? _error;

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchKettles(widget.profileId);
      if (!mounted) return;
      setState(() {
        _kettles = items;
        _sortKettles();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Braukessel'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Neu'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Konnte Braukessel nicht laden:\n$_error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_kettles.isEmpty) {
      return const Center(
        child: Text('Noch keine Braukessel vorhanden.'),
      );
    }
    return ListView.separated(
      itemCount: _kettles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final kettle = _kettles[index];
        final titleText = kettle.model?.isNotEmpty == true
            ? '${kettle.brand} ${kettle.model}'
            : kettle.brand;
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            onTap: () => _openForm(editing: kettle),
            leading: Icon(
              kettle.isDefault ? Icons.star : Icons.star_border,
              color: kettle.isDefault ? Colors.amber : Colors.white54,
            ),
            title: Text(titleText.trim()),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kettle.volumeLiters != null)
                  Text('Volumen: ${kettle.volumeLiters!.toStringAsFixed(1)} L'),
                if (kettle.postBoilLossLiters != null)
                  Text(
                      'Prozessverlust: ${kettle.postBoilLossLiters!.toStringAsFixed(1)} L'),
                if (kettle.boilOffPercentage != null)
                  Text('Boil-off: ${kettle.boilOffPercentage!.toStringAsFixed(1)} %'),
                Row(
                  children: [
                    Text('Sudhausausbeute: ${kettle.bhEfficiency.toStringAsFixed(1)} %'),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () async {
                         final result = await Navigator.of(context).push(
                           MaterialPageRoute(
                             builder: (_) => EfficiencyCalculatorPage(
                               initialKettle: kettle,
                             ),
                           ),
                         );
                         if (result == true) {
                           if (!mounted) return;
                           _load();
                         }
                      },
                      child: const Icon(Icons.calculate_outlined, size: 16, color: Colors.blueAccent),
                    ),
                  ],
                ),
                if ((kettle.notes ?? '').isNotEmpty)
                  Text(
                    kettle.notes!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (kettle.hasCondenserHat)
                  const Text(
                    'Hat Kondensator Hut',
                    style: TextStyle(color: Colors.lightBlueAccent),
                  ),
              ],
            ),
            trailing: CardActions(
              onEdit: () => _openForm(editing: kettle),
              onDelete: () => confirmDelete(
                context,
                'Braukessel “${titleText.trim()}” löschen?',
                () => _deleteKettle(kettle),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openForm({BrewKettle? editing}) async {
    final brandCtrl = TextEditingController(text: editing?.brand ?? '');
    final modelCtrl = TextEditingController(text: editing?.model ?? '');
    final volumeCtrl = TextEditingController(
      text: editing?.volumeLiters?.toString() ?? '',
    );
    final postBoilLossCtrl = TextEditingController(
      text: editing?.postBoilLossLiters?.toString() ?? '',
    );
    final boilOffCtrl = TextEditingController(
      text: editing?.boilOffPercentage?.toString() ?? '',
    );
    final bhEfficiencyCtrl = TextEditingController(
      text: editing?.bhEfficiency.toString() ?? '70.0',
    );
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');
    bool isDefault = editing?.isDefault ?? false;
    bool hasCondenserHat = editing?.hasCondenserHat ?? false;
    String? brandError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(editing == null
              ? 'Braukessel hinzufügen'
              : 'Braukessel bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: brandCtrl,
                  decoration: InputDecoration(
                    labelText: 'Marke',
                    errorText: brandError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: modelCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Modell',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: volumeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Volumen (L)',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: postBoilLossCtrl,
                  decoration: InputDecoration(
                    labelText: 'Post-Boil Prozessverlust (L)',
                    suffixIcon: Tooltip(
                      message:
                          'Volumenverlust zwischen Kochende und Gärtank\ndurch bewusst zurückgelassenen Trub im Kessel\nsowie Restwürze in Gegenstromkühler, Schläuchen\nund Pumpe. Dieser Verlust ist qualitätsbedingt\nund wird nicht in den Gärtank übernommen.',
                      triggerMode: TooltipTriggerMode.tap,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      textStyle:
                          const TextStyle(fontSize: 12, color: Colors.white),
                      child: const Icon(Icons.info_outline, size: 20),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: bhEfficiencyCtrl,
                  decoration: InputDecoration(
                    labelText: 'Sudhausausbeute (%)',
                    suffixIcon: Tooltip(
                      message:
                          'Brewhouse Efficiency (BH Efficiency):\nWie viel Prozent des Zuckers aus dem Malz\nlanden am Ende tatsächlich in deiner Würze.\nTypisch für Brewtools B40: 65% - 75%.',
                      triggerMode: TooltipTriggerMode.tap,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      textStyle:
                          const TextStyle(fontSize: 12, color: Colors.white),
                      child: const Icon(Icons.info_outline, size: 20),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => EfficiencyCalculatorPage(
                            initialKettle: editing,
                          ),
                        ),
                      );
                      if (result == true) {
                        if (dialogCtx.mounted) {
                          Navigator.of(dialogCtx).pop(true);
                        }
                        _load(); // Refresh list if updated
                      }
                    },
                    icon: const Icon(Icons.calculate_outlined, size: 16),
                    label: const Text('Rechner öffnen', style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notizen',
                  ),
                ),
                CheckboxListTile(
                  value: hasCondenserHat,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kondensator Hut'),
                  onChanged: (value) =>
                      setState(() => hasCondenserHat = value ?? false),
                ),
                if (hasCondenserHat)
                  Padding(
                    padding: const EdgeInsets.only(left: 32.0, bottom: 12.0),
                    child: TextField(
                      controller: boilOffCtrl,
                      decoration: InputDecoration(
                        labelText: 'Boil-off (%)',
                        suffixIcon: Tooltip(
                          message:
                              'Prozentualer Verdampfungsverlust während des\nKochens pro Stunde. Dieser Wert ist\nspezifisch für dein System und die\nverwendete Heizleistung.',
                          triggerMode: TooltipTriggerMode.tap,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.white24),
                          ),
                          textStyle: const TextStyle(
                              fontSize: 12, color: Colors.white),
                          child: const Icon(Icons.info_outline, size: 20),
                        ),
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                    ),
                  ),
                CheckboxListTile(
                  value: isDefault,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Als Standard verwenden (★)'),
                  onChanged: (value) =>
                      setState(() => isDefault = value ?? false),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(false),
              child: const Text('Abbrechen'),
            ),
            FilledButton(
              onPressed: () {
                if (brandCtrl.text.trim().isEmpty) {
                  setState(() => brandError = 'Marke erforderlich');
                  return;
                }
                Navigator.of(dialogCtx).pop(true);
              },
              child: const Text('Speichern'),
            ),
          ],
        ),
      ),
    );

    if (result != true) return;

    final kettle = BrewKettle(
      id: editing?.id,
      userProfileId: widget.profileId,
      brand: brandCtrl.text.trim(),
      model: modelCtrl.text.trim().isEmpty ? null : modelCtrl.text.trim(),
      isDefault: isDefault,
      volumeLiters: tryParseDouble(volumeCtrl.text),
      postBoilLossLiters: tryParseDouble(postBoilLossCtrl.text),
      boilOffPercentage: tryParseDouble(boilOffCtrl.text),
      bhEfficiency: tryParseDouble(bhEfficiencyCtrl.text) ?? 70.0,
      hasCondenserHat: hasCondenserHat,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );

    try {
      final saved = await _service.saveKettle(kettle);
      if (!mounted) return;
      setState(() {
        if (saved.isDefault) {
          _kettles = _kettles
              .map((existing) => existing.id == saved.id
                  ? existing
                  : existing.copyWith(isDefault: false))
              .toList();
        }
        _upsert(saved);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null
                  ? 'Braukessel erstellt'
                  : 'Braukessel aktualisiert',
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    }
  }

  void _upsert(BrewKettle kettle) {
    final index = _kettles.indexWhere((element) => element.id == kettle.id);
    if (index >= 0) {
      _kettles[index] = kettle;
    } else {
      _kettles.add(kettle);
    }
    _sortKettles();
  }

  void _sortKettles() {
    _kettles.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
    });
  }



  Future<void> _deleteKettle(BrewKettle kettle) async {
    if (kettle.id == null) return;
    try {
      await _service.deleteKettle(kettle.id!);
      setState(() {
        _kettles.removeWhere((item) => item.id == kettle.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Braukessel "${kettle.brand}" gelöscht')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

}
