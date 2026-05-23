import 'package:flutter/material.dart';
import '../services/brewfather_service.dart';
import '../services/user_profile_service.dart';
import '../models/misc.dart';

class MiscsManagerPage extends StatefulWidget {
  const MiscsManagerPage({super.key, required this.profileId});

  final String profileId;

  @override
  State<MiscsManagerPage> createState() => _MiscsManagerPageState();
}

class _MiscsManagerPageState extends State<MiscsManagerPage> {
  final UserProfileService _userService = UserProfileService();
  bool _isLoading = true;
  String? _error;
  List<Misc> _miscs = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final profile = await _userService.fetchProfile(widget.profileId);
      if (profile == null) throw Exception('Profil nicht gefunden');

      // 1. Load from DB first
      var localItems = await _userService.getMiscs(widget.profileId);
      if (mounted && localItems.isNotEmpty) {
        setState(() {
          _miscs = localItems;
          _isLoading = false;
        });
      }

      if ((profile.brewfatherUserId ?? '').isEmpty ||
          (profile.brewfatherApiKey ?? '').isEmpty) {
         if (localItems.isEmpty) {
           throw Exception('Bitte hinterlegen Sie erst Ihre Brewfather User ID und API Key.');
         } else {
             if (mounted) setState(() => _isLoading = false);
             return;
         }
      }

      final bfService = BrewfatherService();

      // 2. Fetch from Brewfather
      final bfData = await bfService.getMiscs();

      // 3. Filter and Convert
      final List<Misc> newItems = [];
      for (var item in bfData) {
        final inventory = item['inventory'];
        if (inventory == null || (inventory is num && inventory == 0)) continue; 
        
        newItems.add(Misc.fromBrewfather(item, widget.profileId));
      }

      // 4. Upsert to DB
      await _userService.saveMiscs(newItems);

      // 5. Reload completely from DB
      localItems = await _userService.getMiscs(widget.profileId);

      if (!mounted) return;

      setState(() {
        _miscs = localItems;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sonstiges (Brewfather)'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _openManualForm(),
              icon: const Icon(Icons.add),
              label: const Text('Neu'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            'Fehler beim Laden: $_error',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.redAccent),
          ),
        ),
      );
    }

    final validItems = _miscs.where((i) => i.name.isNotEmpty).toList();

    if (validItems.isEmpty) {
      return const Center(
        child: Text('Keine Einträge in Brewfather gefunden.'),
      );
    }

    return ListView.separated(
      itemCount: validItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = validItems[index];
        final amount = item.amount;
        final unit = item.unit ?? '';
        final type = item.type ?? '';
        final use = item.use ?? '';
        
        // Example subtitle: "Spice • Boil • 10 min"
        final List<String> details = [];
        if (type.isNotEmpty) details.add(type);
        if (use.isNotEmpty) details.add(use);
        if (item.time != null && item.time! > 0) details.add('${item.time} min');

        return ListTile(
          leading: (item.brewfatherId != null && item.brewfatherId!.isNotEmpty)
              ? Image.asset('assets/Brewfather_logo.png', width: 24, height: 24)
              : Image.asset('assets/icon_small.png', width: 24, height: 24),
          title: Text(item.name),
          subtitle: Text(
            details.join(' • '),
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${amount.toStringAsFixed(1)} $unit',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
                IconButton(
                icon: const Icon(Icons.edit, color: Colors.blueAccent),
                onPressed: () => _onEditItem(item),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onEditItem(Misc item) {
    if (item.brewfatherId != null && item.brewfatherId!.isNotEmpty) {
      _editBFInventory(item);
    } else {
      _openManualForm(editing: item);
    }
  }

  Future<void> _openManualForm({Misc? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final amountCtrl = TextEditingController(text: editing?.amount.toString() ?? '0.0');
    final timeCtrl = TextEditingController(text: editing?.time?.toString() ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');

    String selectedUnit = editing?.unit ?? 'g';
    const List<String> unitOptions = ['g', 'kg', 'ml', 'L', 'each', 'tsp', 'tbsp'];

    String selectedType = editing?.type ?? 'Spice';
    final List<String> typeOptions = ['Spice', 'Fining', 'Water Agent', 'Herb', 'Flavor', 'Other'];
    
    String selectedUse = editing?.use ?? 'Boil';
    final List<String> useOptions = ['Boil', 'Mash', 'Bottling', 'Primary', 'Secondary', 'Sparge'];

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        // We use StatefulBuilder to update dropdowns inside Dialog if needed, 
        // essentially the Dialog builder rebuilds so simple vars work if we set them in the closure scope of _openManualForm... 
        // but to update UI we need the builder context's state. 
        // Actually, variables defined in _openManualForm are static for the builder unless we wrap content in StatefulBuilder.
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(editing == null ? 'Eintrag hinzufügen' : 'Eintrag bearbeiten'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameCtrl,
                      decoration: const InputDecoration(labelText: 'Name'),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: amountCtrl,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(labelText: 'Menge'),
                          ),
                        ),
                        const SizedBox(width: 8),
                         Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedUnit,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Einheit'),
                            items: unitOptions.map((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(val),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedUnit = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedType,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Typ'),
                            items: typeOptions.map((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(val),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedType = val);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            initialValue: selectedUse,
                            isExpanded: true,
                            decoration: const InputDecoration(labelText: 'Verwendung'),
                            items: useOptions.map((String val) {
                              return DropdownMenuItem<String>(
                                value: val,
                                child: Text(val),
                              );
                            }).toList(),
                            onChanged: (val) {
                              if (val != null) setState(() => selectedUse = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    TextField(
                      controller: timeCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Zeit (Minuten)'),
                    ),
                    TextField(
                      controller: notesCtrl,
                      decoration: const InputDecoration(labelText: 'Notizen'),
                      maxLines: 2,
                    ),
                  ],
                ),
              ),
              actions: [
                if (editing != null)
                  TextButton(
                    onPressed: () {
                       Navigator.of(context).pop(false);
                       _deleteItem(editing);
                    },
                    style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                    child: const Text('Löschen'),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Abbrechen'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Speichern'),
                ),
              ],
            );
          }
        );
      },
    );

    if (saved == true) {
      setState(() => _isLoading = true);
      try {
        final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
        final time = double.tryParse(timeCtrl.text.replaceAll(',', '.'));

        final newItem = Misc(
          id: editing?.id,
          userProfileId: widget.profileId,
          brewfatherId: null,
          name: nameCtrl.text.trim(),
          amount: amount,
          unit: selectedUnit,
          type: selectedType,
          use: selectedUse,
          time: time,
          notes: notesCtrl.text.trim(),
        );

        await _userService.saveMisc(newItem);
        await _load();

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Eintrag gespeichert.')),
           );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _deleteItem(Misc item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eintrag löschen?'),
        content: Text('Möchten Sie "${item.name}" wirklich löschen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Löschen'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (item.id == null) return;
      setState(() => _isLoading = true);
      try {
        await _userService.deleteMisc(item.id!);
        await _load();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Eintrag gelöscht.')),
           );
        }
      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Fehler beim Löschen: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _editBFInventory(Misc item) async {
    final TextEditingController amountCtrl = TextEditingController(
      text: item.amount.toString(),
    );

    final bool? changed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text('${item.name} Bestand ändern (Brewfather)'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Menge (${item.unit})',
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Abbrechen'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Speichern'),
            ),
          ],
        );
      },
    );

    if (changed == true) {
      final double? newAmount = double.tryParse(amountCtrl.text.replaceAll(',', '.'));
      if (newAmount == null) return;

      setState(() => _isLoading = true);

      try {
        final profile = await _userService.fetchProfile(widget.profileId);
        if (profile == null || (profile.brewfatherUserId ?? '').isEmpty || (profile.brewfatherApiKey ?? '').isEmpty) {
           throw Exception('Fehlende Brewfather Zugangsdaten.');
        }

        final bfService = BrewfatherService();

        if (item.brewfatherId == null) throw Exception('Keine Brewfather ID vorhanden.');

        await bfService.updateMiscInventory(item.brewfatherId!, newAmount);
        await _load();

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Bestand aktualisiert.')),
           );
        }

      } catch (e) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Fehler: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
