import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/packaging_profile.dart';
import '../services/packaging_profile_service.dart';
import '../utils/parse_utils.dart';
import '../widgets/card_actions.dart';

class PackagingProfileManagerPage extends StatefulWidget {
  const PackagingProfileManagerPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final PackagingProfileRepository? repository;

  @override
  State<PackagingProfileManagerPage> createState() =>
      _PackagingProfileManagerPageState();
}

class _PackagingProfileManagerPageState
    extends State<PackagingProfileManagerPage> {
  late final PackagingProfileRepository repository;
  bool isLoading = true;
  List<PackagingProfile> profiles = [];
  String? error;

  @override
  void initState() {
    super.initState();
    repository = widget.repository ?? PackagingProfileService();
    load();
  }

  Future<void> load() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final items = await repository.fetchProfiles(widget.profileId);
      if (!mounted) return;
      setState(() {
        profiles = items;
        profiles.sort(
          (a, b) {
            if (a.isDefault != b.isDefault) {
              return a.isDefault ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          },
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
      appBar: AppBar(
        title: const Text('Zielmenge,Abfüllen und Lagern'),
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
          'Konnte Profile nicht laden:\n$error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (profiles.isEmpty) {
      return const Center(
        child: Text('Noch keine Abfüll- und Lagerprofile vorhanden.'),
      );
    }
    return ListView.separated(
      itemCount: profiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = profiles[index];
        final kegInfo = <String>[];
        final bottleInfo = <String>[];
        if (profile.targetVolume != null) {
          kegInfo.add('Zielmenge: ${profile.targetVolume!.toStringAsFixed(1)} L');
        }
        if (profile.kegEnabled) {
          final carb = profile.kegCarbonationTempC != null
              ? '${profile.kegCarbonationTempC!.toStringAsFixed(1)} °C'
              : '–';
          final storage = profile.kegStorageTempC != null
              ? '${profile.kegStorageTempC!.toStringAsFixed(1)} °C'
              : '–';
          final liters = profile.kegVolumeLiters != null
              ? ', ${profile.kegVolumeLiters!.toStringAsFixed(1)} L'
              : '';
          final gases = <String>[];
          if (profile.hasCo2) gases.add('CO2');
          if (profile.hasNitro) gases.add('Nitro');
          final gasStr = gases.isNotEmpty ? ' [${gases.join(' + ')}]' : '';

          kegInfo.add('Keg: Karb $carb · Lager $storage$liters$gasStr');
        }
        if (profile.bottleEnabled) {
          final carb = profile.bottleCarbonationTempC != null
              ? '${profile.bottleCarbonationTempC!.toStringAsFixed(1)} °C'
              : '–';
          final storage = profile.bottleStorageTempC != null
              ? '${profile.bottleStorageTempC!.toStringAsFixed(1)} °C'
              : '–';
          bottleInfo.add('Flaschen: Karb $carb · Lager $storage');
        }
        final info = [...kegInfo, ...bottleInfo];
        if (info.isEmpty) {
          info.add('Keine Angaben');
        }
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            onTap: () => openForm(editing: profile),
            leading: Icon(
              profile.isDefault ? Icons.star : Icons.star_border,
              color: profile.isDefault ? Colors.amber : Colors.white54,
            ),
            title: Text(profile.name),
            subtitle: info.isEmpty
                ? null
                : Text(
                    info.join(' · '),
                  ),
            trailing: CardActions(
              onEdit: () => openForm(editing: profile),
              onDelete: () => confirmDelete(
                context,
                'Profil “${profile.name}” löschen?',
                () => deleteProfile(profile),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> openForm({PackagingProfile? editing}) async {
    final nameCtrl = TextEditingController(text: editing?.name ?? '');
    final targetVolumeCtrl = TextEditingController(
      text: editing?.targetVolume?.toString() ?? '',
    );
    final bottleCarbCtrl = TextEditingController(
      text: editing?.bottleCarbonationTempC?.toString() ?? '',
    );
    final bottleStorageCtrl = TextEditingController(
      text: editing?.bottleStorageTempC?.toString() ?? '',
    );
    final kegCarbCtrl = TextEditingController(
      text: editing?.kegCarbonationTempC?.toString() ?? '',
    );
    final kegStorageCtrl = TextEditingController(
      text: editing?.kegStorageTempC?.toString() ?? '',
    );
    final volumeCtrl = TextEditingController(
      text: editing?.kegVolumeLiters?.toString() ?? '',
    );
    bool bottleEnabled = editing?.bottleEnabled ?? true;
    bool kegEnabled = editing?.kegEnabled ?? false;
    bool hasCo2 = editing?.hasCo2 ?? true;
    bool hasNitro = editing?.hasNitro ?? false;
    bool isDefault = editing?.isDefault ?? false;
    String? nameError;
    String? typeError;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title:
              Text(editing == null ? 'Profil hinzufügen' : 'Profil bearbeiten'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: 'Profilname',
                    errorText: nameError,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: targetVolumeCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Zielmenge',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                ),
                const SizedBox(height: 12),
                if (typeError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      typeError!,
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                  ),
                SwitchListTile(
                  value: bottleEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Flaschen abfüllen'),
                  onChanged: (value) => setState(() => bottleEnabled = value),
                ),
                if (bottleEnabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: bottleCarbCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Flaschen – Karbonisierung (°C)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: bottleStorageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Flaschen – Lagerung (°C)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                ],
                SwitchListTile(
                  value: kegEnabled,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Kegs abfüllen'),
                  onChanged: (value) => setState(() => kegEnabled = value),
                ),
                if (kegEnabled) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: kegCarbCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keg – Karbonisierung (°C)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kegStorageCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keg – Lagerung (°C)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: volumeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Keg Volumen (L)',
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  const SizedBox(height: 12),
                  const SizedBox(height: 12),
                  const Text('Schankgas', style: TextStyle(fontSize: 16)),
                  CheckboxListTile(
                    value: hasCo2,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('CO2'),
                    onChanged: (val) => setState(() => hasCo2 = val ?? false),
                  ),
                  CheckboxListTile(
                    value: hasNitro,
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Nitro'),
                    onChanged: (val) => setState(() => hasNitro = val ?? false),
                  ),
                  const SizedBox(height: 12),
                ],
                CheckboxListTile(
                  value: isDefault,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  title: const Text('Als Standard markieren'),
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
                if (!bottleEnabled && !kegEnabled) {
                  setState(() =>
                      typeError = 'Mindestens Flaschen oder Keg aktivieren');
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

    final profile = PackagingProfile(
      id: editing?.id,
      userProfileId: widget.profileId,
      name: nameCtrl.text.trim(),
      targetVolume: tryParseDouble(targetVolumeCtrl.text),
      bottleEnabled: bottleEnabled,
      bottleCarbonationTempC:
          bottleEnabled ? tryParseDouble(bottleCarbCtrl.text) : null,
      bottleStorageTempC:
          bottleEnabled ? tryParseDouble(bottleStorageCtrl.text) : null,
      kegEnabled: kegEnabled,
      kegCarbonationTempC: kegEnabled ? tryParseDouble(kegCarbCtrl.text) : null,
      kegStorageTempC: kegEnabled ? tryParseDouble(kegStorageCtrl.text) : null,
      kegVolumeLiters: kegEnabled ? tryParseDouble(volumeCtrl.text) : null,
      hasCo2: hasCo2,
      hasNitro: hasNitro,
      isDefault: isDefault,
    );

    try {
      final saved = await repository.saveProfile(profile);
      if (!mounted) return;
      setState(() {
        if (saved.isDefault) {
          profiles = profiles
              .map((existing) => existing.id == saved.id
                  ? existing
                  : existing.copyWith(isDefault: false))
              .toList();
        }
        final index = profiles.indexWhere((element) => element.id == saved.id);
        if (index >= 0) {
          profiles[index] = saved;
        } else {
          profiles.add(saved);
        }
        profiles.sort(
          (a, b) {
            if (a.isDefault != b.isDefault) {
              return a.isDefault ? -1 : 1;
            }
            return a.name.toLowerCase().compareTo(b.name.toLowerCase());
          },
        );
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              editing == null ? 'Profil erstellt' : 'Profil aktualisiert',
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



  Future<void> deleteProfile(PackagingProfile profile) async {
    if (profile.id == null) return;
    try {
      await repository.deleteProfile(profile.id!);
      setState(() {
        profiles.removeWhere((item) => item.id == profile.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil "${profile.name}" gelöscht')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

}
