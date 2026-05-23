import 'package:flutter/material.dart';
import '../models/ai_recipe.dart';
import '../services/ai_generated_recipes_service.dart';
import 'recipe_result_page.dart';

class GeneratedRecipesListPage extends StatefulWidget {
  GeneratedRecipesListPage({super.key, AiGeneratedRecipesService? service})
      : _service = service ?? AiGeneratedRecipesService();

  final AiGeneratedRecipesService _service;

  @override
  State<GeneratedRecipesListPage> createState() => _GeneratedRecipesListPageState();
}

class _GeneratedRecipesListPageState extends State<GeneratedRecipesListPage> {
  late Future<List<Map<String, dynamic>>> _recipesFuture;

  @override
  void initState() {
    super.initState();
    _recipesFuture = widget._service.fetchRecipes();
  }

  void _reload() {
    setState(() {
      _recipesFuture = widget._service.fetchRecipes();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Generierte Rezepte')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _recipesFuture,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Fehler: ${snapshot.error}'));
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final recipes = snapshot.data!;
          if (recipes.isEmpty) {
            return const Center(child: Text('Keine gespeicherten Rezepte gefunden.'));
          }

          return ListView.builder(
            itemCount: recipes.length,
            itemBuilder: (context, index) {
              final row = recipes[index];
              final dateStr = row['created_at'] as String?;
              final date = dateStr != null ? DateTime.parse(dateStr).toLocal() : DateTime.now();

              return ListTile(
                title: Text(row['basis_bier'] ?? 'Unbenannt'),
                subtitle: Text('${row['bier_typ']} • ${date.day}.${date.month}.${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.grey),
                      onPressed: () async {
                        final confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Rezept löschen?'),
                            content: const Text('Möchtest du dieses Rezept wirklich unwiderruflich löschen?'),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context, false), // Abbrechen
                                child: const Text('Abbrechen'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(context, true), // Löschen
                                style: TextButton.styleFrom(foregroundColor: Colors.red),
                                child: const Text('Löschen'),
                              ),
                            ],
                          ),
                        );

                        if (confirm == true) {
                          try {
                            await widget._service.deleteRecipe(row['id'].toString());
                            _reload();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Rezept gelöscht.')),
                              );
                            }
                          } catch (e) {
                             if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Fehler beim Löschen: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                    const Icon(Icons.arrow_forward_ios, size: 16),
                  ],
                ),
                onTap: () async {
                   try {
                     final r = await widget._service.fetchRecipeById(row['id'].toString());

                     final malts = (r['malts'] as List?)?.map((m) => {
                       'Name': m['name'],
                       'Menge_kg': m['amount_kg'],
                       'Optimales_Schrot_Spaltmass_mm': m['crush_gap_mm'],
                     }).toList();

                     final hops = (r['hops'] as List?)?.map((h) => {
                       'Sortenname': h['name'],
                       'Alpha_Saeure': h['alpha_acid'],
                       'Menge_g': h['amount_g'],
                       'Einsatz': h['use_type'],
                       'Zeit_min': h['time_min'],
                     }).toList();

                     final specials = (r['specials'] as List?)?.map((s) => {
                       'Name': s['name'],
                       'Menge': s['amount'],
                       'Einheit': s['unit'],
                       'Anwendung_Detail': s['detail'],
                     }).toList();

                     final finings = (r['finings'] as List?)?.map((f) => {
                       'Name': f['name'],
                       'Menge': f['amount'],
                       'Phase': f['phase'],
                       'Zweck': f['purpose'],
                       'Anwendung_Detail': f['detail'],
                       'Beschaffung_Notwendig': f['procurement_needed'],
                     }).toList();
                     
                     // In denormalized structure, the list might already be ordered if saved ordered.
                     // But sorting again is safer. However, we don't have 'step_order' field saved in the new JSON?
                     // Wait, in Step 595 I removed step_order from the JSON map!
                     // 'stage': s.stage... NO step_order.
                     // But List order is preserved in JSON.
                     // So we don't need to sort by a missing key 'step_order'.
                     
                     final mashSteps = (r['mash_steps'] as List?);
                     final mashStepsMapped = mashSteps?.map((ms) => {
                       'Stufe': ms['stage'],
                       'Temperatur_C': ms['temp_c'],
                       'Dauer_min': ms['duration_min'],
                     }).toList();

                     final fermSteps = (r['fermentation_steps'] as List?);
                     final fermStepsMapped = fermSteps?.map((fs) => {
                       'Phase': fs['phase'],
                       'Temperatur_C': fs['temp_c'],
                       'Dauer_Tage': fs['days'],
                       'Druck_bar': fs['pressure_bar'],
                       'Druck_Begruendung': fs['pressure_note'],
                       'Hinweis': fs['note'],
                     }).toList();

                     final recipeMap = {
                       'id': r['id'],
                       'basis_bier': r['basis_bier'],
                       'bier_typ': r['bier_typ'],
                       'stammwuerze_sg': r['stammwuerze_sg'],
                       'restextrakt_sg': r['restextrakt_sg'],
                       'alkoholgehalt_vol_prozent': r['alkoholgehalt'],
                       'Notizen': r['notizen'] ?? [],
                       'generated_image': r['generated_image'],
                       'can_pressurize': r['can_pressurize'],
                       'Zutaten': {
                         'Original_Malz': malts ?? [],
                         'Original_Hopfen': hops ?? [],
                         'Original_Hefe': {
                           'Name': r['yeast_name'],
                           'Typ': r['yeast_type'],
                           'Menge_Packungen_oder_ml': r['yeast_amount'],
                           'Beschaffung_Notwendig': r['yeast_procurement_needed'] ?? false,
                         },
                         'Wasserprofil_Zielwerte': {
                           'Kalzium_Ca_mg_L': r['water_ca'],
                           'Magnesium_Mg_mg_L': r['water_mg'],
                           'Natrium_Na_mg_L': r['water_na'],
                           'Chlorid_Cl_mg_L': r['water_cl'],
                           'Sulfat_SO4_mg_L': r['water_so4'],
                           'Hydrogencarbonat_HCO3_mg_L': r['water_hco3'],
                           'Salzzugabe_Zeitpunkt': r['water_salt_timing'],
                         },
                         'Spezialzutaten': specials ?? [],
                         'Klaer_und_Schonungsmittel': finings ?? [],
                       },
                       'Prozessdaten': {
                         'Maischeplan': {
                           'Hauptguss_L': r['mash_water_l'],
                           'Einmaischtemperatur_C': r['mash_in_temp_c'],
                           'Rasten': mashStepsMapped ?? [],
                         },
                         'Laeuterungsplan': {
                           'Nachgusswasser_Menge_L': r['lauter_sparge_water_l'],
                           'Ziel_pH_vor_Laeutern': r['lauter_target_ph'],
                         },
                         'Kochplan': {
                           'Pfannevoll_Tatsaechlich_L': r['boil_pre_vol_l'],
                           'Gesamte_Kochdauer_min': r['boil_duration_min'],
                         },
                         'Gaerungsplan': {
                           'Hefe_Anstelltemperatur_C': r['fermentation_pitch_temp_c'],
                           'Gaerverlauf': fermStepsMapped ?? [],
                           'Druck_Hinweis': r['fermentation_pressure_note'],
                         },
                         'Abfuell_und_Lagerungsplan': {
                           'Abfuellung_Typ': r['packaging_type'],
                           'Karbonisierung_Ziel_CO2_g_L': r['packaging_co2_target'],
                           'Keg_Druck_bar': r['packaging_keg_pressure'],
                           'Keg_Karbonisierung_Temp_C': r['packaging_keg_temp'],
                           'Flaschen_Zucker_g_pro_L': r['packaging_bottle_sugar'],
                           'Flaschen_Karbonisierung_Temp_C': r['packaging_bottle_temp'],
                           'Lagerung_Temperatur_C': r['packaging_storage_temp'],
                           'Lagerung_Dauer_Wochen': r['packaging_storage_weeks'],
                           'Reifungshinweis': r['packaging_maturation_note'],
                           'Empfohlenes_Ausschankgas': r['packaging_serving_gas'],
                           'Karbonisierungsdauer_Tage': r['packaging_carb_days'],
                         }
                       }
                     };

                     final recipe = AiRecipe.fromJson(recipeMap);
                     if (context.mounted) {
                       Navigator.of(context).push(
                         MaterialPageRoute(builder: (_) => RecipeResultPage(recipe: recipe)),
                       );
                     }

                   } catch (e) {
                     if (context.mounted) {
                       ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler beim Laden: $e')));
                     }
                   }
                },
              );
            },
          );
        },
      ),
    );
  }
}
