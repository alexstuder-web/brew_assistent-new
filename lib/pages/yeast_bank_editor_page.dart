import 'package:flutter/material.dart';
import '../models/yeast_bank_entry.dart';
import '../models/user_profile.dart';
import '../services/yeast_bank_service.dart';
import '../services/brewfather_service.dart';
import '../controllers/yeast_bank_editor_controller.dart';

class YeastBankEditorPage extends StatefulWidget {
  const YeastBankEditorPage({
    super.key,
    required this.profileId,
    this.editing,
    this.userProfile,
    this.syncEnabled = false,
    this.debugJsonMap,
  });

  final String profileId;
  final YeastBankEntry? editing;
  final UserProfile? userProfile;
  final bool syncEnabled;
  final Map<String, String>? debugJsonMap;

  @override
  State<YeastBankEditorPage> createState() => _YeastBankEditorPageState();
}

class _YeastBankEditorPageState extends State<YeastBankEditorPage> {
  late final YeastBankEditorController _controller;
  final YeastBankService _service = YeastBankService();

  @override
  void initState() {
    super.initState();
    _controller = YeastBankEditorController(
      editing: widget.editing,
      debugJsonMap: widget.debugJsonMap,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_controller.validate()) return;

    _controller.setIsSaving(true);
    try {
      final draft = _controller.buildDraft(profileId: widget.profileId);
      final saved = await _service.saveEntry(draft);

      if (widget.syncEnabled &&
          widget.userProfile?.brewfatherUserId != null &&
          (widget.userProfile?.brewfatherConfigured ?? false)) {
        if (saved.brewfatherId != null) {
          try {
            final bfService = BrewfatherService();
            await bfService.updateInventoryYeast(saved.brewfatherId!, {
              'name': saved.strain,
              'lab': saved.brand,
              'type': saved.style ?? 'Ale',
              'attenuation': saved.attenuationMax ?? 75,
              'minTemp': saved.temperatureMin ?? 18,
              'maxTemp': saved.temperatureMax ?? 23,
              'description': saved.notes ?? '',
              'productId': saved.productId,
              'form': saved.form,
              'inventory': saved.inventory,
              'unit': saved.unit,
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Update an Brewfather gesendet.')));
            }
          } catch (e) {
            debugPrint('Error updating Brewfather: $e');
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Warnung: Brewfather Update fehlgeschlagen: $e')));
            }
          }
        } else {
          if (mounted) {
            await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Brewfather Info'),
                content: const Text(
                    'Eintrag wurde lokal gespeichert.\nDas Hinzufügen neuer Einträge wird von Brewfather nicht unterstützt.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('OK'))
                ],
              ),
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) _controller.setIsSaving(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.editing == null ? 'Hefe hinzufügen' : 'Hefe bearbeiten'),
        actions: [
          ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilledButton.icon(
                  onPressed: _controller.isSaving ? null : _handleSave,
                  icon: _controller.isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_controller.isSaving ? 'Speichert...' : 'Speichern'),
                ),
              );
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final isSynced = _controller.isSynced;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 800),
              child: Column(
                children: [
                   Tooltip(
                    message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                    child: TextField(
                      controller: _controller.brandCtrl,
                      readOnly: isSynced,
                      decoration: InputDecoration(
                        labelText: 'Marke',
                        errorText: _controller.brandError,
                        filled: isSynced,
                        fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Tooltip(
                    message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                    child: TextField(
                      controller: _controller.productIdCtrl,
                      readOnly: isSynced,
                      decoration: InputDecoration(
                        labelText: 'Produkt ID',
                        filled: isSynced,
                        fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Tooltip(
                    message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                    child: TextField(
                      controller: _controller.strainCtrl,
                      readOnly: isSynced,
                      decoration: InputDecoration(
                        labelText: 'Stamm',
                        errorText: _controller.strainError,
                        filled: isSynced,
                        fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Tooltip(
                    message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                    child: TextField(
                      controller: _controller.styleCtrl,
                      readOnly: isSynced,
                      decoration: InputDecoration(
                        labelText: 'Stil / Verwendung',
                        filled: isSynced,
                        fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Tooltip(
                    message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                    child: TextField(
                      controller: _controller.formCtrl,
                      readOnly: isSynced,
                      decoration: InputDecoration(
                        labelText: 'Form',
                        filled: isSynced,
                        fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _controller.urlCtrl,
                    decoration: const InputDecoration(
                      labelText: 'URL (lokal)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                          child: TextField(
                            controller: _controller.attenuationMinCtrl,
                            readOnly: isSynced,
                            decoration: InputDecoration(
                              labelText: 'EVG min %',
                              filled: isSynced,
                              fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Tooltip(
                          message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                          child: TextField(
                            controller: _controller.attenuationMaxCtrl,
                            readOnly: isSynced,
                            decoration: InputDecoration(
                              labelText: 'EVG max %',
                              filled: isSynced,
                              fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Tooltip(
                          message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                          child: TextField(
                            controller: _controller.tempMinCtrl,
                            readOnly: isSynced,
                            decoration: InputDecoration(
                              labelText: 'Temp. min (°C)',
                              filled: isSynced,
                              fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Tooltip(
                          message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                          child: TextField(
                            controller: _controller.tempMaxCtrl,
                            readOnly: isSynced,
                            decoration: InputDecoration(
                              labelText: 'Temp. max (°C)',
                              filled: isSynced,
                              fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: _controller.inventoryCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Bestand',
                          ),
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 1,
                        child: Tooltip(
                          message: isSynced ? 'Dieses Feld erlaubt Brewfather nicht mutiert zu werden.' : '',
                          child: TextField(
                            controller: _controller.unitCtrl,
                            readOnly: isSynced,
                            decoration: InputDecoration(
                              labelText: 'Einheit',
                              filled: isSynced,
                              fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Tooltip(
                    message: isSynced ? 'Dieses Feld wird von Brewfather synchronisiert.' : '',
                    child: TextField(
                      controller: _controller.notesCtrl,
                      maxLines: 3,
                      readOnly: isSynced,
                      decoration: InputDecoration(
                        labelText: 'Notizen',
                        filled: isSynced,
                        fillColor: isSynced ? Colors.grey.withValues(alpha: 0.1) : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
