import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart';
import '../widgets/user_name_banner.dart';
import '../widgets/fine_tuning_widgets.dart';
import 'recipe_summary_page.dart';

class SpecialAdditionsPage extends StatefulWidget {
  const SpecialAdditionsPage({super.key, required this.profile});

  final FineTuningProfile profile;

  @override
  State<SpecialAdditionsPage> createState() => _SpecialAdditionsPageState();
}

class _SpecialAdditionsPageState extends State<SpecialAdditionsPage> {
  final TextEditingController titleCtrl = TextEditingController();
  final TextEditingController storageCtrl = TextEditingController();
  double focusValue = 0.5;
  double intensityValue = 0.5;
  String? titleError;
  String? storageError;

  @override
  void dispose() {
    titleCtrl.dispose();
    storageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spezielle Zugaben'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/icon_small.png',
              height: 40,
              filterQuality: FilterQuality.none,
              semanticLabel: 'AiBrewGenius',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UserNameBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Füge deinem Bier besondere Schritte wie Barrel Aging, Holzchips oder Speziallagerungen hinzu.',
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Bisherige Zugaben',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (widget.profile.specialAdditions.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text(
                        'Noch keine speziellen Zugaben definiert.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ...widget.profile.specialAdditions.asMap().entries.map(
                          (entry) {
                            final addition = entry.value;
                            final antrunkPercent =
                                ((1 - addition.focus) * 100).round();
                            final abgangPercent = 100 - antrunkPercent;
                            final intensityPercent =
                                (addition.intensity * 100).round();
                            return Card(
                              color: const Color(0xFF0F172A),
                              child: ListTile(
                                title: Text(addition.title),
                                subtitle: Text(
                                  'Antrunk $antrunkPercent% · Abgang $abgangPercent% · Intensität $intensityPercent%',
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.delete_outline),
                                  onPressed: () => removeAddition(entry.key),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 24),
                  Text(
                    'Neue Zugabe hinzufügen',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: InputDecoration(
                      labelText: 'Bezeichnung',
                      hintText: 'z. B. Rumfass Lagerung',
                      errorText: titleError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  FocusSlider(
                    value: focusValue,
                    onChanged: (v) => setState(() => focusValue = v),
                  ),
                  const SizedBox(height: 12),
                  IntensitySlider(
                    value: intensityValue,
                    onChanged: (v) => setState(() => intensityValue = v),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: addAddition,
                      icon: const Icon(Icons.add),
                      label: const Text('Hinzufügen'),
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Divider(
                    height: 32,
                    thickness: 1,
                    color: Colors.white24,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Spezielle Lagerung',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 12),
                  if (widget.profile.specialStorage.isEmpty)
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Text(
                        'Noch keine Lagerungsarten definiert.',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  else
                    Column(
                      children: [
                        ...widget.profile.specialStorage.asMap().entries.map(
                              (entry) => Card(
                                color: const Color(0xFF0F172A),
                                child: ListTile(
                                  title: Text(entry.value),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.delete_outline),
                                    onPressed: () => removeStorage(entry.key),
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
                  TextField(
                    controller: storageCtrl,
                    decoration: InputDecoration(
                      labelText: 'z. B. Barrel Aged',
                      errorText: storageError,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      onPressed: addStorage,
                      icon: const Icon(Icons.add),
                      label: const Text('Lagerung hinzufügen'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                TextButton(
                  onPressed: goToSummary,
                  child: const Text('Überspringen'),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: goToSummary,
                  child: const Text('Weiter zum Rezept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void addAddition() {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => titleError = 'Bezeichnung erforderlich');
      return;
    }
    setState(() {
      titleError = null;
      widget.profile.specialAdditions.add(
        SpecialAddition(
          title: title,
          focus: focusValue,
          intensity: intensityValue,
        ),
      );
      titleCtrl.clear();
      focusValue = 0.5;
      intensityValue = 0.5;
    });
  }

  void removeAddition(int index) {
    setState(() {
      widget.profile.specialAdditions.removeAt(index);
    });
  }

  void addStorage() {
    final entry = storageCtrl.text.trim();
    if (entry.isEmpty) {
      setState(() => storageError = 'Bitte eine Lagerung eingeben');
      return;
    }
    setState(() {
      storageError = null;
      widget.profile.specialStorage.add(entry);
      storageCtrl.clear();
    });
  }

  void removeStorage(int index) {
    setState(() {
      widget.profile.specialStorage.removeAt(index);
    });
  }

  void goToSummary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => RecipeSummaryPage(profile: widget.profile),
      ),
    );
  }
}
