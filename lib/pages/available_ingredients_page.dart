import 'package:flutter/material.dart';
import '../services/brewfather_service.dart';
import '../services/user_profile_service.dart';
import '../models/fermentable.dart';

class AvailableIngredientsPage extends StatefulWidget {
  const AvailableIngredientsPage({super.key, required this.profileId, this.userRepository});

  final String profileId;
  final UserProfileRepository? userRepository;

  @override
  State<AvailableIngredientsPage> createState() => _AvailableIngredientsPageState();
}

class _AvailableIngredientsPageState extends State<AvailableIngredientsPage> {
  late final UserProfileRepository _userService;
  bool _isLoading = true;
  String? _error;
  List<Fermentable> _fermentables = [];

  @override
  void initState() {
    super.initState();
    _userService = widget.userRepository ?? UserProfileService();
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

      // 1. Load from DB first to show something quickly (optional, but good UX)
      var localItems = await _userService.getFermentables(widget.profileId);
      if (mounted && localItems.isNotEmpty) {
        setState(() {
          _fermentables = localItems;
          _isLoading = false;
        });
      }

      if ((profile.brewfatherUserId ?? '').isEmpty ||
          (profile.brewfatherApiKey ?? '').isEmpty) {
        // Only throw if we have no local data either? 
        // Or just warn? Let's keep it as is for now, blocking if no creds.
        if (localItems.isEmpty) {
          throw Exception(
            'Bitte hinterlegen Sie erst Ihre Brewfather User ID und API Key in den Einstellungen.');
        } else {
             // If we have local items but no credentials, just stop here
             if (mounted) setState(() => _isLoading = false);
             return;
        }
      }

      final bfService = BrewfatherService(
        userId: profile.brewfatherUserId!,
        apiKey: profile.brewfatherApiKey!,
      );

      // 2. Fetch from Brewfather
      final bfData = await bfService.getFermentables();
      
      // 3. Filter and Convert
      // "alle anderen Einträge sollen in die DB eingetragen werden"
      // "null in inventory ... sollen nicht dargestellt werden"
      // So we filter existing nulls from display, but should we save them?
      // Use filter for saving too? Probably yes, to keep DB clean of empty stuff.
      
      final List<Fermentable> newItems = [];
      for (var item in bfData) {
        final inventory = item['inventory'];
        if (inventory == null || (inventory is num && inventory == 0)) continue; 
        
        newItems.add(Fermentable.fromBrewfather(item, widget.profileId));
      }

      // 4. Upsert to DB
      await _userService.saveFermentables(newItems);

      // 5. Reload completely from DB to be clean and have all IDs etc.
      localItems = await _userService.getFermentables(widget.profileId);

      if (!mounted) return;

      setState(() {
        _fermentables = localItems;
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
        title: const Text('Vergärbare Zutaten (Brewfather)'),
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

    final validItems = _fermentables.where((i) => i.name.isNotEmpty).toList();

    if (validItems.isEmpty) {
      return const Center(
        child: Text('Keine fermentierbaren Zutaten in Brewfather gefunden.'),
      );
    }

    return ListView.separated(
      itemCount: validItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = validItems[index];
        final name = item.name;
        final supplier = item.supplier ?? '';
        final amount = item.amount;
        final unit = item.unit ?? 'kg';
        final type = item.type ?? '';

        // Priority: potential (explicit SG) -> yield (calculated) -> attenuation (fallback)
        double sg = 1.0;
        if (item.potential != null) {
           sg = item.potential!;
        } else if (item.yield != null) {
           // Yield is typically percentage e.g. 80
           // ~0.46 points per percent yield is a standard approximation for sucrose equivalent
           sg = 1 + (item.yield! * 0.46) / 1000;
        } else if (item.attenuation != null) {
             sg = 1 + (item.attenuation! * 0.46) / 1000;
        }

        return ListTile(
          leading: (item.brewfatherId != null && item.brewfatherId!.isNotEmpty)
              ? Image.asset('assets/Brewfather_logo.png', width: 24, height: 24)
              : Image.asset('assets/icon_small.png', width: 24, height: 24),
          title: Text(name),
          subtitle: Text(
            '$type${supplier.isNotEmpty ? ' • $supplier' : ''} • ${sg.toStringAsFixed(3)} SG',
            style: const TextStyle(color: Colors.white70),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${amount.toStringAsFixed(3)} $unit',
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

  void _onEditItem(Fermentable item) {
    if (item.brewfatherId != null && item.brewfatherId!.isNotEmpty) {
      _editBFInventory(item);
    } else {
      _openManualForm(editing: item);
    }
  }

  Future<void> _openManualForm({Fermentable? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final supplierCtrl = TextEditingController(text: editing?.supplier ?? '');
    final amountCtrl = TextEditingController(text: editing?.amount.toString() ?? '0.0');
    // final unitCtrl = TextEditingController(text: editing?.unit ?? 'kg'); // Removed
    String selectedUnit = editing?.unit ?? 'kg';
    const List<String> unitOptions = ['kg', 'g', 'lbs', 'oz']; // Add other units as needed
    final typeCtrl = TextEditingController(text: editing?.type ?? 'Grain');
    final potentialCtrl = TextEditingController(text: editing?.potential?.toString() ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(editing == null ? 'Zutat hinzufügen' : 'Zutat bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name'),
                ),
                TextField(
                  controller: supplierCtrl,
                  decoration: const InputDecoration(labelText: 'Hersteller'),
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
                        decoration: const InputDecoration(labelText: 'Einheit'),
                        items: unitOptions.map((String val) {
                          return DropdownMenuItem<String>(
                            value: val,
                            child: Text(val),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                             selectedUnit = val;
                          }
                        },
                      ),
                    ),
                  ],
                ),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'Typ (Grain, Hops, etc.)'),
                ),
                TextField(
                  controller: potentialCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Potential (SG, z.B. 1.036)'),
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
      },
    );

    if (saved == true) {
      setState(() => _isLoading = true);
      try {
        final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0.0;
        final potential = double.tryParse(potentialCtrl.text.replaceAll(',', '.'));

        final newItem = Fermentable(
          id: editing?.id, // Keep ID if editing, null if new
          userProfileId: widget.profileId,
          brewfatherId: null, // Manual entry
          name: nameCtrl.text.trim(),
          supplier: supplierCtrl.text.trim(),
          amount: amount,
          unit: selectedUnit,
          type: typeCtrl.text.trim(),
          potential: potential,
          notes: notesCtrl.text.trim(),
        );

        await _userService.saveFermentable(newItem);
        await _load(); // Reload to show changes

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Zutat gespeichert.')),
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

  Future<void> _deleteItem(Fermentable item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Zutat löschen?'),
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
      if (item.id == null) return; // Should not happen for existing items
      setState(() => _isLoading = true);
      try {
        await _userService.deleteFermentable(item.id!);
        await _load();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Zutat gelöscht.')),
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

  Future<void> _editBFInventory(Fermentable item) async {
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
                  labelText: 'Menge (${item.unit ?? "kg"})',
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

        final bfService = BrewfatherService(
          userId: profile.brewfatherUserId!,
          apiKey: profile.brewfatherApiKey!,
        );

        if (item.brewfatherId == null) throw Exception('Keine Brewfather ID vorhanden.');

        // Update in Brewfather
        await bfService.updateFermentableInventory(item.brewfatherId!, newAmount);

        // Update Locally via sync
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
