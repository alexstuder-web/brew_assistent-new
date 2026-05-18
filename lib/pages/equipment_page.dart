import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/fine_tuning_profile.dart';
import '../models/brew_kettle.dart';
import '../models/water_profile.dart';
import '../models/fermenter.dart';
import '../models/fermenter_controller.dart';
import '../models/malt_depot_entry.dart';
import '../models/fining_agents.dart';
import '../models/packaging_profile.dart';
import '../services/brew_kettle_service.dart';
import '../services/water_profile_service.dart';
import '../services/fermenter_service.dart';
import '../services/fermenter_controller_service.dart';
import '../services/malt_depot_service.dart';
import '../services/fining_agents_service.dart';
import '../services/packaging_profile_service.dart';
import '../services/openai_service.dart';
import '../services/user_profile_service.dart';
import 'recipe_summary_page.dart';
import 'legacy_recipe_pages.dart';
import 'efficiency_calculator_page.dart';

class EquipmentPage extends StatefulWidget {
  const EquipmentPage({super.key, required this.profile});

  final FineTuningProfile profile;

  @override
  State<EquipmentPage> createState() => _EquipmentPageState();
}

class _EquipmentPageState extends State<EquipmentPage> {
  final BrewKettleService kettleService = BrewKettleService();
  final WaterProfileService waterService = WaterProfileService();
  final FermenterService fermenterService = FermenterService();
  final FermenterControllerService controllerService =
      FermenterControllerService();
  final MaltDepotService maltService = MaltDepotService();
  final FiningAgentsService finingService = FiningAgentsService();
  final PackagingProfileService packagingService = PackagingProfileService();
  final OpenAIService openAIService = OpenAIService();

  bool isLoading = true;
  bool isCalculating = false;
  String? error;

  List<BrewKettle> kettles = [];
  List<WaterProfile> waterProfiles = [];
  List<Fermenter> fermenters = [];
  List<FermenterControllerModel> controllers = [];
  List<MaltDepotEntryModel> maltDepots = [];
  FiningAgents? finingSettings;
  PackagingProfile? selectedPackagingProfile;

  BrewKettle? selectedKettle;
  WaterProfile? selectedWaterProfile;
  Fermenter? selectedFermenter;
  FermenterControllerModel? selectedController;
  MaltDepotEntryModel? selectedMaltDepot;
  final TextEditingController batchSizeCtrl = TextEditingController();
  final FocusNode batchSizeFocusNode = FocusNode();

  static const String profileId = UserProfileService.defaultProfileId;
  static const Map<String, Map<String, String>> finingMetadata = {
    'irish_moss': {
      'name': 'Irish Moss',
      'purpose': 'Bindet Heißtrub für klare Würze.',
      'phase': 'Letzte 10–15 min des Kochens',
    },
    'whirlfloc': {
      'name': 'Whirlfloc-Tabletten',
      'purpose': 'Schnellere Heißtrub-Flockung im Kochkessel.',
      'phase': 'Letzte 10 min des Kochens',
    },
    'gelatin': {
      'name': 'Gelatine',
      'purpose': 'Schönung nach der Gärung für klares Bier.',
      'phase': 'Nachgärung bzw. Kaltlagerung',
    },
    'biersol': {
      'name': 'Biersol (Kieselsol)',
      'purpose': 'Feinklärung vor Abfüllung.',
      'phase': 'Nach der Gärung vor Abfüllung',
    },
    'polyclar': {
      'name': 'Polyclar/PVPP',
      'purpose': 'Polyphenolbindung für geschmackliche Stabilität.',
      'phase': 'Kaltseite vor Abfüllung',
    },
    'isinglass': {
      'name': 'Isinglass',
      'purpose': 'Klassische Klärung für britische Ales.',
      'phase': 'Nachgärung/Kaltlagerung',
    },
    'bentonite': {
      'name': 'Bentonit',
      'purpose': 'Proteinbindung für klare Spezialbiere.',
      'phase': 'Nachguss oder Nachgärung je nach Stil',
    },
    'egg_whites': {
      'name': 'Eiweiß',
      'purpose': 'Traditionelle Schönung (selten genutzt).',
      'phase': 'Nachgärung',
    },
    'activated_carbon': {
      'name': 'Aktivkohle',
      'purpose': 'Spezialreinigung/zur Entfernung Fehlgeschmack.',
      'phase': 'Nachgärung oder Filtration',
    },
  };

  @override
  void initState() {
    super.initState();
    loadEquipment();
  }

  @override
  void dispose() {
    batchSizeCtrl.dispose();
    batchSizeFocusNode.dispose();
    super.dispose();
  }

  Future<void> loadEquipment() async {
    setState(() {
      isLoading = true;
      error = null;
    });
    try {
      final results = await Future.wait([
        kettleService.fetchKettles(profileId),
        waterService.fetchProfiles(profileId),
        fermenterService.fetchFermenters(profileId),
        controllerService.fetchControllers(profileId),
        maltService.fetchEntries(profileId),
        finingService.fetchSettings(profileId),
        packagingService.fetchProfiles(profileId),
      ]);
      if (!mounted) return;
      setState(() {
        kettles = results[0] as List<BrewKettle>;
        waterProfiles = results[1] as List<WaterProfile>;
        fermenters = results[2] as List<Fermenter>;
        controllers = results[3] as List<FermenterControllerModel>;
        maltDepots = results[4] as List<MaltDepotEntryModel>;
        finingSettings = results[5] as FiningAgents;
        selectedKettle = pickDefault(kettles, (k) => k.isDefault);
        selectedWaterProfile = pickDefault(waterProfiles, (p) => p.isDefault);
        selectedFermenter = pickDefault(fermenters, (f) => f.isDefault);
        selectedController = pickDefault(controllers, (c) => c.isDefault);
        selectedMaltDepot = maltDepots.isNotEmpty ? maltDepots.first : null;
        final packagingProfiles = results[6] as List<PackagingProfile>;
        if (packagingProfiles.isNotEmpty) {
          selectedPackagingProfile =
              pickDefault(packagingProfiles, (p) => p.isDefault) ??
                  packagingProfiles.first;
        } else {
          selectedPackagingProfile = null;
        }
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
        title: const Text('Equipment'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Equipment konnte nicht geladen werden:\n$error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: loadEquipment,
                  child: ListView(
                    padding: const EdgeInsets.all(24),
                    children: [
                      TextField(
                        controller: batchSizeCtrl,
                        focusNode: batchSizeFocusNode,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Ziel Menge in Liter',
                          hintText: '20',
                        ),
                      ),
                      const SizedBox(height: 16),
                      buildRecipeButton(),
                      const SizedBox(height: 24),
                      _EquipmentSection<BrewKettle>(
                        title: 'Braukessel',
                        items: kettles,
                        selected: selectedKettle,
                        onSelected: (kettle) {
                          if (kettle == null) return;
                          setState(() => selectedKettle = kettle);
                        },
                        isDefaultBuilder: (kettle) => kettle.isDefault,
                        labelBuilder: (kettle) =>
                            kettle.model?.isNotEmpty == true
                                ? '${kettle.brand} ${kettle.model}'
                                : kettle.brand,
                        actions: [
                          TextButton.icon(
                            onPressed: () async {
                              final result = await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EfficiencyCalculatorPage(
                                    initialKettle: selectedKettle,
                                  ),
                                ),
                              );
                              if (result == true) {
                                loadEquipment(); // Refresh if updated
                              }
                            },
                            icon: const Icon(Icons.calculate_outlined, size: 18),
                            label: const Text('Effizienz bestimmen', style: TextStyle(fontSize: 12)),
                            style: TextButton.styleFrom(foregroundColor: Colors.blueAccent),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _EquipmentSection<WaterProfile>(
                        title: 'Wasserprofil',
                        items: waterProfiles,
                        selected: selectedWaterProfile,
                        onSelected: (profile) {
                          if (profile == null) return;
                          setState(() => selectedWaterProfile = profile);
                        },
                        isDefaultBuilder: (profile) => profile.isDefault,
                        labelBuilder: (profile) => profile.name,
                      ),
                      const SizedBox(height: 18),
                      _EquipmentSection<Fermenter>(
                        title: 'Fermentierer',
                        items: fermenters,
                        selected: selectedFermenter,
                        onSelected: (fermenter) {
                          if (fermenter == null) return;
                          setState(() => selectedFermenter = fermenter);
                        },
                        isDefaultBuilder: (fermenter) => fermenter.isDefault,
                        labelBuilder: (fermenter) =>
                            fermenter.type?.isNotEmpty == true
                                ? '${fermenter.brand} ${fermenter.type}'
                                : fermenter.brand,
                      ),
                      const SizedBox(height: 18),
                      _EquipmentSection<FermenterControllerModel>(
                        title: 'Kontroller',
                        items: controllers,
                        selected: selectedController,
                        onSelected: (controller) {
                          if (controller == null) return;
                          setState(() => selectedController = controller);
                        },
                        isDefaultBuilder: (controller) => controller.isDefault,
                        labelBuilder: (controller) => controller.name,
                      ),
                      const SizedBox(height: 18),
                      _EquipmentSection<MaltDepotEntryModel>(
                        title: 'Brauerei Shops',
                        items: maltDepots,
                        selected: selectedMaltDepot,
                        onSelected: (entry) {
                          if (entry == null) return;
                          setState(() => selectedMaltDepot = entry);
                        },
                        labelBuilder: (entry) => entry.name,
                      ),
                      const SizedBox(height: 24),
                      const Divider(height: 24, color: Colors.white24),
                      const SizedBox(height: 12),
                      Text(
                        'Rezept-Zusammenfassung',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      ...buildRecipeSummarySections(widget.profile),
                    ],
                  ),
                ),
    );
  }

  Widget buildRecipeButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: isCalculating ? null : generateRecipe,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          side: const BorderSide(color: Colors.purple),
          foregroundColor: Colors.white,
          backgroundColor: Colors.purple.withValues(alpha: 0.15),
        ),
        icon: isCalculating
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.science_rounded),
        label: Text(isCalculating ? 'Berechne …' : 'Rezept erstellen'),
      ),
    );
  }

  Future<void> generateRecipe() async {
    final batchSize = batchSizeCtrl.text.trim();
    if (batchSize.isEmpty) {
      batchSizeFocusNode.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte Ziel Menge eingeben')),
      );
      return;
    }
    try {
      setState(() {
        isCalculating = true;
      });
      final template = await rootBundle.loadString('prompt/rezept_basis');
      final prompt = buildPrompt(template);
      final response = await openAIService.brewRecipe(prompt);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LegacyRecipeResultPage(
            prompt: prompt,
            response: response,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Rezeptberechnung fehlgeschlagen: $e')),
      );
    } finally {
      if (mounted) {
        setState(() {
          isCalculating = false;
        });
      }
    }
  }

  T? pickDefault<T>(List<T> items, bool Function(T item) isDefault) {
    if (items.isEmpty) return null;
    for (final item in items) {
      if (isDefault(item)) return item;
    }
    return items.first;
  }

  String buildShopListJson() {
    if (maltDepots.isEmpty) return '[]';
    final list = maltDepots.map((entry) {
      final url = (entry.url ?? '').trim();
      final map = <String, String>{'shop_name': entry.name};
      if (url.isNotEmpty) {
        map['shop_url'] = url;
      }
      return map;
    }).toList();
    return jsonEncode(list);
  }

  String buildSpecialAdditionsJson() {
    if (widget.profile.specialAdditions.isEmpty) return '[]';
    final list = widget.profile.specialAdditions.map((addition) {
      final antrunkPercent = ((1 - addition.focus) * 100).round();
      final abgangPercent = 100 - antrunkPercent;
      final intensityPercent = (addition.intensity * 100).round();
      return {
        'name': addition.title,
        'antrunk_percent': antrunkPercent,
        'abgang_percent': abgangPercent,
        'intensity_percent': intensityPercent,
      };
    }).toList();
    return jsonEncode(list);
  }

  String buildSpecialStorageJson() {
    if (widget.profile.specialStorage.isEmpty) return '[]';
    final list = widget.profile.specialStorage
        .map((entry) => entry.trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
    if (list.isEmpty) return '[]';
    return jsonEncode(list);
  }

  String buildFiningAgentsJson() {
    final settings = finingSettings;
    if (settings == null) return '[]';
    final selections = <Map<String, String>>[];

    void addOption(String key, bool enabled) {
      if (!enabled) return;
      final meta = finingMetadata[key];
      selections.add({
        'key': key,
        'name': meta?['name'] ?? key,
        'purpose': meta?['purpose'] ?? '',
        'recommended_phase': meta?['phase'] ?? '',
      });
    }

    addOption('irish_moss', settings.irishMoss);
    addOption('whirlfloc', settings.whirlfloc);
    addOption('gelatin', settings.gelatin);
    addOption('biersol', settings.biersol);
    addOption('polyclar', settings.polyclar);
    addOption('isinglass', settings.isinglass);
    addOption('bentonite', settings.bentonite);
    addOption('egg_whites', settings.eggWhites);
    addOption('activated_carbon', settings.activatedCarbon);

    for (final extra in settings.extras) {
      final trimmed = extra.trim();
      if (trimmed.isEmpty) continue;
      selections.add({
        'key': 'custom',
        'name': trimmed,
        'purpose': 'Vom Nutzer hinterlegt',
        'recommended_phase': '',
      });
    }

    if (selections.isEmpty) return '[]';
    return jsonEncode(selections);
  }

  String buildPackagingProfileJson() {
    final profile = selectedPackagingProfile;
    if (profile == null) return '{}';
    final map = <String, dynamic>{
      'name': profile.name,
      'bottle': {
        'enabled': profile.bottleEnabled,
        'carbonation_temp_c': profile.bottleCarbonationTempC,
        'storage_temp_c': profile.bottleStorageTempC,
      },
      'keg': {
        'enabled': profile.kegEnabled,
        'carbonation_temp_c': profile.kegCarbonationTempC,
        'storage_temp_c': profile.kegStorageTempC,
        'volume_l': profile.kegVolumeLiters,
      },
    };
    return jsonEncode(map);
  }

  String buildPrompt(String template) {
    String formatScore(double value) => value.toStringAsFixed(2);
    String formatWater(double? value) => (value ?? 0).toStringAsFixed(2);
    String formatText(String? value) =>
        (value == null || value.trim().isEmpty) ? 'unbekannt' : value.trim();
    String formatBool(bool? value) => (value ?? false) ? 'true' : 'false';

    final water = selectedWaterProfile;
    final replacements = <String, String>{
      'bier_typ': widget.profile.beerType,
      'basis_bier': widget.profile.beerName,
      'hop_intensity': formatScore(widget.profile.hopIntensity),
      'hop_herbal': formatScore(widget.profile.hopHerbal),
      'hop_floral': formatScore(widget.profile.hopFloral),
      'hop_fruity': formatScore(widget.profile.hopFruity),
      'hop_nose': formatScore(widget.profile.hopNose),
      'hop_palate': formatScore(widget.profile.hopPalate),
      'hop_finish': formatScore(widget.profile.hopFinish),
      'mouthfeel': formatScore(widget.profile.mouthfeel),
      'antrunk_malt': formatScore(widget.profile.antrunkMalt),
      'antrunk_roast': formatScore(widget.profile.antrunkRoast),
      'smooth': formatScore(widget.profile.smooth),
      'full_body': formatScore(widget.profile.fullBody),
      'main_malt': formatScore(widget.profile.mainMalt),
      'main_roast': formatScore(widget.profile.mainRoast),
      'fade': formatScore(widget.profile.fade),
      'fresh': formatScore(widget.profile.fresh),
      'dry': formatScore(widget.profile.dry),
      'lasting': formatScore(widget.profile.lasting),
      'kettle_brand': formatText(selectedKettle?.brand),
      'kettle_type': formatText(selectedKettle?.model),
      'fermenter_brand': formatText(selectedFermenter?.brand),
      'fermenter_type': formatText(selectedFermenter?.type),
      'fermenter_heating': formatBool(selectedFermenter?.hasHeating),
      'fermenter_cooling': formatBool(selectedFermenter?.hasCooling),
      'special_additions': buildSpecialAdditionsJson(),
      'special_storage': buildSpecialStorageJson(),
      'fining_agents': buildFiningAgentsJson(),
      'packaging_profile': buildPackagingProfileJson(),
      'shop_list': buildShopListJson(),
      'target_volume_l':
          batchSizeCtrl.text.trim().isEmpty ? '0' : batchSizeCtrl.text.trim(),
      'calcium': formatWater(water?.calciumPpm),
      'magnesium': formatWater(water?.magnesiumPpm),
      'sodium': formatWater(water?.sodiumPpm),
      'chloride': formatWater(water?.chloridePpm),
      'sulfate': formatWater(water?.sulfatePpm),
      'bicarbonate': formatWater(water?.bicarbonatePpm),
      'ph': water?.ph?.toStringAsFixed(2) ?? '0.00',
    };

    var prompt = template;
    replacements.forEach((key, value) {
      prompt = prompt.replaceAll('{{$key}}', value);
    });
    return prompt;
  }
}

class _EquipmentSection<T> extends StatelessWidget {
  const _EquipmentSection({
    required this.title,
    required this.items,
    required this.selected,
    required this.onSelected,
    required this.labelBuilder,
    this.isDefaultBuilder,
    this.actions,
  });

  final String title;
  final List<T> items;
  final T? selected;
  final ValueChanged<T?> onSelected;
  final String Function(T item) labelBuilder;
  final bool Function(T item)? isDefaultBuilder;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Card(
        color: const Color(0xFF0F172A),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text('Keine Daten für $title vorhanden.'),
        ),
      );
    }
    final T current = selected ?? defaultItem() ?? items.first;
    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (actions != null) ...actions!,
              ],
            ),
            const SizedBox(height: 12),
            if (items.length > 1)
              DropdownMenu<T>(
                initialSelection: current,
                onSelected: onSelected,
                dropdownMenuEntries: items
                    .map(
                      (item) => DropdownMenuEntry<T>(
                        value: item,
                        label: decorateLabel(item),
                      ),
                    )
                    .toList(),
              )
            else
              Text(decorateLabel(current)),
          ],
        ),
      ),
    );
  }

  String decorateLabel(T item) {
    final label = labelBuilder(item);
    final isDefault = isDefaultBuilder?.call(item) ?? false;
    return isDefault ? '$label ★' : label;
  }

  T? defaultItem() {
    final checker = isDefaultBuilder;
    if (checker == null) return null;
    for (final item in items) {
      if (checker(item)) return item;
    }
    return null;
  }
}
