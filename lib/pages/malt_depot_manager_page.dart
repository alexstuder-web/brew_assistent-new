import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/malt_depot_entry.dart';
import '../services/malt_depot_service.dart';
import '../widgets/card_actions.dart';

class MaltDepotManagerPage extends StatefulWidget {
  const MaltDepotManagerPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final MaltDepotRepository? repository;

  @override
  State<MaltDepotManagerPage> createState() => _MaltDepotManagerPageState();
}

class _MaltDepotManagerPageState extends State<MaltDepotManagerPage> {
  late final MaltDepotRepository repository;
  bool isLoading = true;
  List<MaltDepotEntryModel> entries = [];
  String? error;

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? MaltDepotService();
    load();
  }

  Future<void> load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final items = await repository.fetchEntries(widget.profileId);
      if (!mounted) return;
      setState(() {
        entries = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brauerei Shops'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Neu'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: buildBody(),
      ),
    );
  }

  Widget buildBody() {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (error != null) {
      return Center(
        child: Text(
          'Konnte Brauerei Shops nicht laden:\n$error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (entries.isEmpty) {
      return const Center(child: Text('Noch keine Einträge.'));
    }
    return ListView.separated(
      itemCount: entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            onTap: () => openForm(editing: entry),
            title: Text(entry.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((entry.url ?? '').isNotEmpty) Text('URL: ${entry.url}'),
                if ((entry.notes ?? '').isNotEmpty)
                  Text(
                    entry.notes!,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
            trailing: CardActions(
              onEdit: () => openForm(editing: entry),
              onDelete: () => confirmDelete(
                context,
                'Malzlieferant “${entry.name}” löschen?',
                () => deleteEntry(entry),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> openForm({MaltDepotEntryModel? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final urlCtrl = TextEditingController(text: editing?.url ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');
    String? nameError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(editing == null
              ? 'Malzlieferant hinzufügen'
              : 'Malzlieferant bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Name',
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: urlCtrl,
                  decoration: const InputDecoration(labelText: 'URL'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notizen'),
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
                if (nameCtrl.text.trim().isEmpty) {
                  setState(() => nameError = 'Name erforderlich');
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

    final entry = MaltDepotEntryModel(
      id: editing?.id,
      userProfileId: widget.profileId,
      name: nameCtrl.text.trim(),
      url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );

    try {
      final saved = await repository.saveEntry(entry);
      if (!mounted) return;
      setState(() {
        final index = entries.indexWhere((element) => element.id == saved.id);
        if (index >= 0) {
          entries[index] = saved;
        } else {
          entries.add(saved);
        }
        entries.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null ? 'Eintrag erstellt' : 'Eintrag aktualisiert',
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

  Future<void> deleteEntry(MaltDepotEntryModel entry) async {
    if (entry.id == null) return;
    try {
      await repository.deleteEntry(entry.id!);
      setState(() {
        entries.removeWhere((item) => item.id == entry.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Malzlieferant "${entry.name}" gelöscht')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

}
