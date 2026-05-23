import 'package:flutter/material.dart';
import '../services/brewfather_service.dart';
import '../services/user_profile_service.dart';
import '../models/hop.dart';

class HopsManagerPage extends StatefulWidget {
  const HopsManagerPage({super.key, required this.profileId});

  final String profileId;

  @override
  State<HopsManagerPage> createState() => _HopsManagerPageState();
}

class _HopsManagerPageState extends State<HopsManagerPage> {
  final UserProfileService _userService = UserProfileService();
  bool _isLoading = true;
  String? _error;
  List<Hop> _hops = [];

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
      var localItems = await _userService.getHops(widget.profileId);
      if (mounted && localItems.isNotEmpty) {
        setState(() {
          _hops = localItems;
          _isLoading = false;
        });
      }

      if ((profile.brewfatherUserId ?? '').isEmpty ||
          !profile.brewfatherConfigured) {
        if (localItems.isEmpty) {
          throw Exception(
            'Bitte hinterlegen Sie erst Ihre Brewfather User ID und API Key in den Einstellungen.');
        } else {
             if (mounted) setState(() => _isLoading = false);
             return;
        }
      }

      final bfService = BrewfatherService();

      // 2. Fetch from Brewfather
      final bfData = await bfService.getHops();
      
      // 3. Filter and Convert
      final List<Hop> newItems = [];
      for (var item in bfData) {
        final inventory = item['inventory'];
        if (inventory == null || (inventory is num && inventory == 0)) continue; 
        
        newItems.add(Hop.fromBrewfather(item, widget.profileId));
      }

      // 4. Upsert to DB
      await _userService.saveHops(newItems);

      // 5. Reload completely from DB
      localItems = await _userService.getHops(widget.profileId);

      if (!mounted) return;

      setState(() {
        _hops = localItems;
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
        title: const Text('Hopfen (Brewfather)'),
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

    final validItems = _hops.where((i) => i.name.isNotEmpty).toList();

    if (validItems.isEmpty) {
      return const Center(
        child: Text('Kein Hopfen in Brewfather gefunden.'),
      );
    }

    return ListView.separated(
      itemCount: validItems.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final item = validItems[index];
        final name = item.name;
        final alpha = item.alpha ?? 0.0;
        final year = item.year ?? '';
        final origin = item.origin ?? '';
        final amount = item.amount;
        final unit = item.unit ?? 'g';
        final type = item.type ?? '';

        return ListTile(
          leading: (item.brewfatherId != null && item.brewfatherId!.isNotEmpty)
              ? Image.asset('assets/Brewfather_logo.png', width: 24, height: 24)
              : Image.asset('assets/icon_small.png', width: 24, height: 24),
          title: Text(name),
          subtitle: Text(
            '$type $year $origin • ${alpha.toStringAsFixed(1)}% Alpha',
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

  void _onEditItem(Hop item) {
    if (item.brewfatherId != null && item.brewfatherId!.isNotEmpty) {
      _editBFInventory(item);
    } else {
      _openManualForm(editing: item);
    }
  }

  Future<void> _openManualForm({Hop? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final originCtrl = TextEditingController(text: editing?.origin ?? '');
    final yearCtrl = TextEditingController(text: editing?.year ?? '');
    final amountCtrl = TextEditingController(text: editing?.amount.toString() ?? '0.0');
    final alphaCtrl = TextEditingController(text: editing?.alpha?.toString() ?? '');
    
    String selectedUnit = editing?.unit ?? 'g';
    const List<String> unitOptions = ['g', 'kg', 'oz', 'lbs'];
    
    // Type options for Hops
    final typeCtrl = TextEditingController(text: editing?.type ?? 'Pellets');
    // We could make type a dropdown too if needed, but text is fine for now or stick to standard BF types (Pellet, Leaf, Cryo)
    
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(editing == null ? 'Hopfen hinzufügen' : 'Hopfen bearbeiten'),
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
                     Expanded(child: TextField(controller: originCtrl, decoration: const InputDecoration(labelText: 'Herkunft'))),
                     const SizedBox(width: 8),
                     Expanded(child: TextField(controller: yearCtrl, decoration: const InputDecoration(labelText: 'Jahr'))),
                  ],
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
                  controller: alphaCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: 'Alpha Säure (%)'),
                ),
                TextField(
                  controller: typeCtrl,
                  decoration: const InputDecoration(labelText: 'Typ (Pellets, Leaf, Cryo)'),
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
        final alpha = double.tryParse(alphaCtrl.text.replaceAll(',', '.'));

        final newItem = Hop(
          id: editing?.id,
          userProfileId: widget.profileId,
          brewfatherId: null,
          name: nameCtrl.text.trim(),
          origin: originCtrl.text.trim(),
          year: yearCtrl.text.trim(),
          amount: amount,
          unit: selectedUnit,
          type: typeCtrl.text.trim(),
          alpha: alpha,
          notes: notesCtrl.text.trim(),
        );

        await _userService.saveHop(newItem);
        await _load();

        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Hopfen gespeichert.')),
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

  Future<void> _deleteItem(Hop item) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hopfen löschen?'),
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
        await _userService.deleteHop(item.id!);
        await _load();
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Hopfen gelöscht.')),
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

  Future<void> _editBFInventory(Hop item) async {
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
                  labelText: 'Menge (${item.unit ?? "g"})',
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
        if (profile == null || (profile.brewfatherUserId ?? '').isEmpty || !profile.brewfatherConfigured) {
           throw Exception('Fehlende Brewfather Zugangsdaten.');
        }

        final bfService = BrewfatherService();

        if (item.brewfatherId == null) throw Exception('Keine Brewfather ID vorhanden.');

        await bfService.updateHopInventory(item.brewfatherId!, newAmount);
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
