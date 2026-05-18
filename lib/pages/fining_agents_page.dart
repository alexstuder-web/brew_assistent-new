import 'package:flutter/material.dart';
import '../models/fining_agents.dart';
import '../services/fining_agents_service.dart';

class FiningAgentsPage extends StatefulWidget {
  const FiningAgentsPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final FiningAgentsRepository? repository;

  @override
  State<FiningAgentsPage> createState() => _FiningAgentsPageState();
}

class _FiningAgentsPageState extends State<FiningAgentsPage> {
  late final FiningAgentsRepository repository;
  bool isLoading = true;
  bool isSaving = false;
  FiningAgents? settings;
  final Map<String, bool> values = {};
  final List<TextEditingController> extraCtrls = [];
  final TextEditingController newExtraCtrl = TextEditingController();
  String? error;
  static const List<_FiningOption> options = [
    _FiningOption(
      key: 'irish_moss',
      title: 'Irish Moss',
      subtitle: 'Carrageen/Rotalgextrakt für die Würzekochung.',
    ),
    _FiningOption(
      key: 'whirlfloc',
      title: 'Whirlfloc-Tabletten',
      subtitle: 'Praktische Tabletten auf Irish-Moss-Basis.',
    ),
    _FiningOption(
      key: 'gelatin',
      title: 'Gelatine',
      subtitle: 'Klassisches Schönungsmittel nach der Gärung.',
    ),
    _FiningOption(
      key: 'biersol',
      title: 'Biersol (Kieselsol)',
      subtitle: 'Flüssigschönung für die Endklärung.',
    ),
    _FiningOption(
      key: 'polyclar',
      title: 'Polyclar/PVPP',
      subtitle: 'Entfernt Polyphenole für klare Biere.',
    ),
    _FiningOption(
      key: 'isinglass',
      title: 'Isinglass',
      subtitle: 'Fischblasen-Schönung, typisch britisch.',
    ),
    _FiningOption(
      key: 'bentonite',
      title: 'Bentonit',
      subtitle: 'Tonerde, häufiger im Wein- und Spezialbierbereich.',
    ),
    _FiningOption(
      key: 'egg_whites',
      title: 'Egg Whites',
      subtitle: 'Selten genutzt, eher beim Wein.',
    ),
    _FiningOption(
      key: 'activated_carbon',
      title: 'Aktivkohle',
      subtitle: 'Für Spezialreinigung und besondere Effekte.',
    ),
  ];

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? FiningAgentsService();
    load();
  }

  @override
  void dispose() {
    for (final ctrl in extraCtrls) {
      ctrl.dispose();
    }
    newExtraCtrl.dispose();
    super.dispose();
  }

  Future<void> load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final data = await repository.fetchSettings(widget.profileId);
      if (!mounted) return;
      setState(() {
        settings = data;
        values['irish_moss'] = data.irishMoss;
        values['whirlfloc'] = data.whirlfloc;
        values['gelatin'] = data.gelatin;
        values['biersol'] = data.biersol;
        values['polyclar'] = data.polyclar;
        values['isinglass'] = data.isinglass;
        values['bentonite'] = data.bentonite;
        values['egg_whites'] = data.eggWhites;
        values['activated_carbon'] = data.activatedCarbon;
        for (final ctrl in extraCtrls) {
          ctrl.dispose();
        }
        extraCtrls
          ..clear()
          ..addAll(
            data.extras.map((extra) => TextEditingController(text: extra)),
          );
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
      appBar: AppBar(title: const Text('Klärmittel / Schönungsmittel')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade900.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('Fehler: $error'),
                    ),
                  ],
                  Expanded(
                    child: ListView(
                      children: [
                        ...options.map(
                          (option) => CheckboxListTile(
                            value: values[option.key] ?? false,
                            onChanged: (value) {
                              setState(() {
                                values[option.key] = value ?? false;
                              });
                            },
                            contentPadding: EdgeInsets.zero,
                            title: Text(option.title),
                            subtitle: Text(option.subtitle),
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Divider(),
                        const SizedBox(height: 12),
                        const Text(
                          'Weitere Mittel',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...extraCtrls.asMap().entries.map(
                              (entry) => Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: entry.value,
                                        decoration: InputDecoration(
                                          labelText: 'Zusatz ${entry.key + 1}',
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      onPressed: () => removeExtra(entry.key),
                                      icon: const Icon(Icons.delete_outline),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        TextField(
                          controller: newExtraCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Neues Mittel (ENTER zum Hinzufügen)',
                          ),
                          onSubmitted: (_) => addExtra(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: isSaving ? null : save,
                      icon: isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_alt),
                      label: Text(isSaving ? 'Speichert …' : 'Speichern'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void addExtra() {
    final value = newExtraCtrl.text.trim();
    if (value.isEmpty) return;
    setState(() {
      extraCtrls.add(TextEditingController(text: value));
      newExtraCtrl.clear();
    });
  }

  void removeExtra(int index) {
    setState(() {
      extraCtrls[index].dispose();
      extraCtrls.removeAt(index);
    });
  }

  Future<void> save() async {
    if (settings == null) return;
    
    final newExtraValue = newExtraCtrl.text.trim();
    if (newExtraValue.isNotEmpty) {
      addExtra();
    }

    setState(() {
      isSaving = true;
    });
    try {
      final updated = FiningAgents(
        userProfileId: widget.profileId,
        irishMoss: values['irish_moss'] ?? false,
        whirlfloc: values['whirlfloc'] ?? false,
        gelatin: values['gelatin'] ?? false,
        biersol: values['biersol'] ?? false,
        polyclar: values['polyclar'] ?? false,
        isinglass: values['isinglass'] ?? false,
        bentonite: values['bentonite'] ?? false,
        eggWhites: values['egg_whites'] ?? false,
        activatedCarbon: values['activated_carbon'] ?? false,
        extras: extraCtrls
            .map((ctrl) => ctrl.text.trim())
            .where((text) => text.isNotEmpty)
            .toList(),
      );
      final saved = await repository.saveSettings(updated);
      if (!mounted) return;
      
      setState(() {
        settings = saved;
        for (final ctrl in extraCtrls) {
          ctrl.dispose();
        }
        extraCtrls
          ..clear()
          ..addAll(
            saved.extras.map((extra) => TextEditingController(text: extra)),
          );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schönungsmittel gespeichert')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Speichern fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isSaving = false;
        });
      }
    }
  }
}

class _FiningOption {
  const _FiningOption({
    required this.key,
    required this.title,
    required this.subtitle,
  });

  final String key;
  final String title;
  final String subtitle;
}
