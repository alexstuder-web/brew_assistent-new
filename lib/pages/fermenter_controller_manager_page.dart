import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/fermenter_controller.dart';
import '../services/fermenter_controller_service.dart';
import '../widgets/card_actions.dart';

class FermenterControllerManagerPage extends StatefulWidget {
  const FermenterControllerManagerPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final FermenterControllerRepository? repository;

  @override
  State<FermenterControllerManagerPage> createState() =>
      _FermenterControllerManagerPageState();
}

class _FermenterControllerManagerPageState
    extends State<FermenterControllerManagerPage> {
  late final FermenterControllerRepository service;
  bool isLoading = true;
  List<FermenterControllerModel> controllers = [];
  String? error;

  @override
  void initState() {
    super.initState();
    service = widget.repository ?? FermenterControllerService();
    load();
  }

  Future<void> load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final items = await service.fetchControllers(widget.profileId);
      if (!mounted) return;
      setState(() {
        controllers = items;
        sortControllers();
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
        title: const Text('Fermentierer-Kontroller'),
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
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Text(
          'Konnte Kontroller nicht laden:\n$error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (controllers.isEmpty) {
      return const Center(child: Text('Noch keine Controller vorhanden.'));
    }
    return ListView.separated(
      itemCount: controllers.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final controller = controllers[index];
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            onTap: () => openForm(editing: controller),
            leading: Icon(
              controller.isDefault ? Icons.star : Icons.star_border,
              color: controller.isDefault ? Colors.amber : Colors.white54,
            ),
            title: Text(controller.name),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((controller.username ?? '').isNotEmpty)
                  Text('User: ${controller.username}'),
                if ((controller.apiKey ?? '').isNotEmpty)
                  Text('API Key: ${controller.apiKey}'),
                if ((controller.notes ?? '').isNotEmpty)
                  Text(
                    controller.notes!,
                    style: const TextStyle(color: Colors.white70),
                  ),
              ],
            ),
            trailing: CardActions(
              onEdit: () => openForm(editing: controller),
              onDelete: () => confirmDelete(
                context,
                'Kontroller “${controller.name}” löschen?',
                () => deleteController(controller),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> openForm({FermenterControllerModel? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final usernameCtrl = TextEditingController(text: editing?.username ?? '');
    final apiKeyCtrl = TextEditingController(text: editing?.apiKey ?? '');
    final notesCtrl = TextEditingController(text: editing?.notes ?? '');
    bool isDefault = editing?.isDefault ?? false;
    String? nameError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(editing == null
              ? 'Kontroller hinzufügen'
              : 'Kontroller bearbeiten'),
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
                  controller: usernameCtrl,
                  decoration: const InputDecoration(labelText: 'Username'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: apiKeyCtrl,
                  decoration: const InputDecoration(labelText: 'API Key'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notizen'),
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

    final controller = FermenterControllerModel(
      id: editing?.id,
      userProfileId: widget.profileId,
      name: nameCtrl.text.trim(),
      isDefault: isDefault,
      username:
          usernameCtrl.text.trim().isEmpty ? null : usernameCtrl.text.trim(),
      apiKey: apiKeyCtrl.text.trim().isEmpty ? null : apiKeyCtrl.text.trim(),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );

    try {
      final saved = await service.saveController(controller);
      if (!mounted) return;
      setState(() {
        if (saved.isDefault) {
          controllers = controllers
              .map((existing) => existing.id == saved.id
                  ? existing
                  : existing.copyWith(isDefault: false))
              .toList();
        }
        final index =
            controllers.indexWhere((element) => element.id == saved.id);
        if (index >= 0) {
          controllers[index] = saved;
        } else {
          controllers.add(saved);
        }
        sortControllers();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null
                  ? 'Kontroller erstellt'
                  : 'Kontroller aktualisiert',
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

  void sortControllers() {
    controllers.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
  }

  Future<void> deleteController(FermenterControllerModel controller) async {
    if (controller.id == null) return;
    try {
      await service.deleteController(controller.id!);
      setState(() {
        controllers.removeWhere((item) => item.id == controller.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kontroller "${controller.name}" gelöscht')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

}
