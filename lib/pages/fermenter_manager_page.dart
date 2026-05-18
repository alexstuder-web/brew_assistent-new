import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/fermenter.dart';
import '../services/fermenter_service.dart';
import '../utils/parse_utils.dart';
import '../widgets/card_actions.dart';

class FermenterManagerPage extends StatefulWidget {
  const FermenterManagerPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final FermenterRepository? repository;

  @override
  State<FermenterManagerPage> createState() => _FermenterManagerPageState();
}

class _FermenterManagerPageState extends State<FermenterManagerPage> {
  late final FermenterRepository _service;
  bool _isLoading = true;
  List<Fermenter> _fermenters = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = widget.repository ?? FermenterService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _service.fetchFermenters(widget.profileId);
      if (!mounted) return;
      setState(() {
        _fermenters = items;
        _sortFermenters();
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
        title: const Text('Fermentierer'),
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
          'Konnte Fermentierer nicht laden:\n$_error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_fermenters.isEmpty) {
      return const Center(
        child: Text('Noch keine Fermentierer vorhanden.'),
      );
    }
    return ListView.separated(
      itemCount: _fermenters.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final fermenter = _fermenters[index];
        final titleText = fermenter.type?.isNotEmpty == true
            ? '${fermenter.brand} ${fermenter.type}'
            : fermenter.brand;
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            onTap: () => _openForm(editing: fermenter),
            leading: Icon(
              fermenter.isDefault ? Icons.star : Icons.star_border,
              color: fermenter.isDefault ? Colors.amber : Colors.white54,
            ),
            title: Text(titleText.trim()),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (fermenter.volumeLiters != null)
                  Text(
                      'Volumen: ${fermenter.volumeLiters!.toStringAsFixed(1)} L'),
                Text('Heizung: ${fermenter.hasHeating ? 'Ja' : 'Nein'}'),
                Text('Kühlung: ${fermenter.hasCooling ? 'Ja' : 'Nein'}'),
                Text(
                    'Dry-Hopping-Port: ${fermenter.hasDryHoppingPort ? 'Ja' : 'Nein'}'),
                Text(
                    'Druckvergärung möglich: ${fermenter.canPressurize ? 'Ja' : 'Nein'}'),
                if (fermenter.fermentationLossLiters != null)
                  Text(
                      'Gärverlust: ${fermenter.fermentationLossLiters!.toStringAsFixed(1)} L'),
                if ((fermenter.notes ?? '').isNotEmpty)
                  Text(
                    fermenter.notes!,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
            trailing: CardActions(
              onEdit: () => _openForm(editing: fermenter),
              onDelete: () => confirmDelete(
                context,
                'Fermentierer “${titleText.trim()}” löschen?',
                () => _deleteFermenter(fermenter),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _openForm({Fermenter? editing}) async {
    final brandCtrl = TextEditingController(text: editing?.brand ?? '');
    final typeCtrl = TextEditingController(text: editing?.type ?? '');
    final volumeCtrl =
        TextEditingController(text: editing?.volumeLiters?.toString() ?? '');
    final fermentationLossCtrl = TextEditingController(
        text: editing?.fermentationLossLiters?.toString() ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');
    bool hasHeating = editing?.hasHeating ?? false;
    bool hasCooling = editing?.hasCooling ?? false;
    bool hasDryHopPort = editing?.hasDryHoppingPort ?? false;
    bool canPressurize = editing?.canPressurize ?? false;
    bool isDefault = editing?.isDefault ?? false;
    String? brandError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(editing == null
              ? 'Fermentierer hinzufügen'
              : 'Fermentierer bearbeiten'),
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
                  controller: typeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Typ',
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
                  controller: fermentationLossCtrl,
                  decoration: InputDecoration(
                    labelText: 'Gärverlust (Hefe- und Trub in L)',
                    suffixIcon: Tooltip(
                      message:
                          'Volumenverlust im Fermenter durch abgesetzte\nHefe und Trub. Umfasst das bewusst nicht\nmitübertragene Sediment beim Abfüllen oder\nUmdrücken in Keg bzw. Flaschen und dient der\nSicherstellung von Klarheit und Stabilität\ndes Bieres.',
                      triggerMode: TooltipTriggerMode.tap,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white24),
                      ),
                      textStyle: const TextStyle(fontSize: 12, color: Colors.white),
                      child: const Icon(Icons.info_outline, size: 20),
                    ),
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notizen',
                  ),
                ),
                const SizedBox(height: 12),
                CheckboxListTile(
                  value: hasHeating,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Heizung vorhanden'),
                  onChanged: (value) =>
                      setState(() => hasHeating = value ?? false),
                ),
                CheckboxListTile(
                  value: hasCooling,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kühlung vorhanden'),
                  onChanged: (value) =>
                      setState(() => hasCooling = value ?? false),
                ),
                CheckboxListTile(
                  value: hasDryHopPort,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Dry-Hopping Port vorhanden'),
                  onChanged: (value) =>
                      setState(() => hasDryHopPort = value ?? false),
                ),
                CheckboxListTile(
                  value: canPressurize,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Druckvergärung möglich'),
                  onChanged: (value) =>
                      setState(() => canPressurize = value ?? false),
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

    final fermenter = Fermenter(
      id: editing?.id,
      userProfileId: widget.profileId,
      brand: brandCtrl.text.trim(),
      type: typeCtrl.text.trim().isEmpty ? null : typeCtrl.text.trim(),
      volumeLiters: tryParseDouble(volumeCtrl.text),
      fermentationLossLiters: tryParseDouble(fermentationLossCtrl.text),
      hasHeating: hasHeating,
      hasCooling: hasCooling,
      hasDryHoppingPort: hasDryHopPort,
      canPressurize: canPressurize,
      isDefault: isDefault,
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );

    try {
      final saved = await _service.saveFermenter(fermenter);
      if (!mounted) return;
      setState(() {
        if (saved.isDefault) {
          _fermenters = _fermenters
              .map((existing) => existing.id == saved.id
                  ? existing
                  : existing.copyWith(isDefault: false))
              .toList();
        }
        final index =
            _fermenters.indexWhere((element) => element.id == saved.id);
        if (index >= 0) {
          _fermenters[index] = saved;
        } else {
          _fermenters.add(saved);
        }
        _sortFermenters();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null
                  ? 'Fermentierer erstellt'
                  : 'Fermentierer aktualisiert',
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



  void _sortFermenters() {
    _fermenters.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.brand.toLowerCase().compareTo(b.brand.toLowerCase());
    });
  }

  Future<void> _deleteFermenter(Fermenter fermenter) async {
    if (fermenter.id == null) return;
    try {
      await _service.deleteFermenter(fermenter.id!);
      setState(() {
        _fermenters.removeWhere((item) => item.id == fermenter.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fermentierer "${fermenter.brand}" gelöscht')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

}
