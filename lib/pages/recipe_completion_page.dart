import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/ai_recipe.dart';
import '../services/openai_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'json_export_page.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'dart:convert';
import '../services/user_profile_service.dart';
import '../services/fermenter_service.dart';

class RecipeCompletionPage extends StatefulWidget {
  final AiRecipe recipe;

  const RecipeCompletionPage({super.key, required this.recipe});

  @override
  State<RecipeCompletionPage> createState() => _RecipeCompletionPageState();
}

class _RecipeCompletionPageState extends State<RecipeCompletionPage> {
  late final TextEditingController _promptController;
  final OpenAIService _openAIService = OpenAIService();
  bool _isGenerating = false;
  String? _generatedImageUrl;
  String? _processedBase64Image;
  bool _useSourceImage = false;
  bool _isSaving = false;
  String? _currentDatabaseId;

  @override
  void initState() {
    super.initState();
    _promptController = TextEditingController(text: _buildInitialPrompt());
    _useSourceImage = widget.recipe.sourceImage != null;
    _currentDatabaseId = widget.recipe.id;
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  String _buildInitialPrompt() {
    final style = widget.recipe.bierTyp;
    final name = widget.recipe.basisBier;
    
    String prompt = "Erstelle ein professionelles Produktfoto für ein Bier '$name' im Stil '$style'. ";
    prompt += 'Das Bild zeigt das Bier in einem mit dem Biernamen angeschriebenen und passenden Glas, appetitlich und frisch in Szene gesetzt. ';
    prompt += 'Die Umgebung ist atmosphärisch passend, vielleicht mit einem kleinen Einblick in eine zum Bier passende Stadt aber nicht ablenkend. ';
    prompt += '\n\nSTRIKT FOR BREWFATHER-APP OPTIMIEREN:\n';
    prompt += '1. FORMAT & AUFLÖSUNG: Quadratisch (1:1), 1200x1200px (mind. 800x800px).\n';
    prompt += "2. DATEIGRÖSSEN-OPTIMIERUNG (<5MB): Nutze klare Flächen und starke Kontraste. Vermeide unnötiges visuelles Rauschen ('Noise'), um eine gute JPG/PNG-Komprimierung zu gewährleisten.\n";
    prompt += '3. INHALT: Bier im passenden Glas, zentral platziert (Safe-Zone für Cropping!), professioneller RGB-Stil.\n';
    prompt += '4. NO-GOS: kein Rahmen, keine Transparenz.';
    
    return prompt;
  }

  Future<void> _generateImage() async {
    if (_promptController.text.trim().isEmpty) return;

    setState(() {
      _isGenerating = true;
      _generatedImageUrl = null;
      _processedBase64Image = null; // Reset processed image to allow re-processing
    });

    try {
      final result = await _openAIService.generateImage(
        _promptController.text,
        attachment: _useSourceImage ? widget.recipe.sourceImage : null,
      );
      if (mounted) {
        setState(() {
          _generatedImageUrl = result;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler bei der Generierung: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
      }
    }
  }

  Future<void> _saveRecipeNormalized() async {
    final userId = UserProfileService.currentUserId;
    final r = widget.recipe;
    final client = Supabase.instance.client;

    // Process image if available
    await _ensureBase64Image();
    
    // 1. Prepare/Upsert Main Recipe
    final Map<String, dynamic> data = {
      'user_profile_id': userId,
      'basis_bier': r.basisBier,
      'bier_typ': r.bierTyp,
      'stammwuerze_sg': r.stammwuerzeSg,
      'restextrakt_sg': r.restextraktSg,
      'alkoholgehalt': r.alkoholgehalt,
      'notizen': r.notizen,
      'generated_image': _processedBase64Image ?? widget.recipe.generatedImage,
      
      // Yeast (1:1)
      'yeast_name': r.zutaten.yeast.name,
      'yeast_type': r.zutaten.yeast.type,
      'yeast_amount': r.zutaten.yeast.amount,
      'yeast_procurement_needed': r.zutaten.yeast.procurementNeeded,
      
      // Water (1:1)
      'water_ca': r.zutaten.water.ca,
      'water_mg': r.zutaten.water.mg,
      'water_na': r.zutaten.water.na,
      'water_cl': r.zutaten.water.cl,
      'water_so4': r.zutaten.water.so4,
      'water_hco3': r.zutaten.water.hco3,
      'water_salt_timing': r.zutaten.water.saltTiming,
      
      // Process Data (1:1)
      'mash_water_l': r.prozessdaten.mash.mashWaterL,
      'mash_in_temp_c': r.prozessdaten.mash.mashInTemp,
      'lauter_sparge_water_l': r.prozessdaten.lauter.spargeWaterL,
      'lauter_target_ph': r.prozessdaten.lauter.targetPh,
      'boil_pre_vol_l': r.prozessdaten.boil.preBoilVolumeL,
      'boil_duration_min': r.prozessdaten.boil.duration,
      'fermentation_pitch_temp_c': r.prozessdaten.fermentation.pitchTemp,
      'packaging_type': r.prozessdaten.packaging.type,
      'packaging_co2_target': r.prozessdaten.packaging.co2Target,
      'packaging_keg_pressure': r.prozessdaten.packaging.kegPressure,
      'packaging_keg_temp': r.prozessdaten.packaging.kegTemp,
      'packaging_bottle_sugar': r.prozessdaten.packaging.bottleSugar,
      'packaging_bottle_temp': r.prozessdaten.packaging.bottleTemp,
      'packaging_storage_temp': r.prozessdaten.packaging.storageTemp,
      'packaging_storage_weeks': r.prozessdaten.packaging.storageDurationWeeks,
      'packaging_maturation_note': r.prozessdaten.packaging.maturationNote,
      'packaging_serving_gas': r.prozessdaten.packaging.servingGasRecommendation,
      'packaging_carb_days': r.prozessdaten.packaging.carbonationDurationDays,
      'can_pressurize': r.canPressurize,
      'fermentation_pressure_note': r.prozessdaten.fermentation.pressureNote,
      'bjcp_stil': r.bjcpStyle?.toJson(),
      'ibu': r.ibu,

      // Arrays (JSONB)
      'malts': r.zutaten.malts.map((m) => {
        'name': m.name,
        'amount_kg': m.amountKg,
        'crush_gap_mm': m.crushGap,
      }).toList(),
      'hops': r.zutaten.hops.map((h) => {
        'name': h.name,
        'alpha_acid': h.alpha,
        'amount_g': h.amountG,
        'use_type': h.use,
        'time_min': h.timeMin,
      }).toList(),
      'specials': r.zutaten.specials.map((s) => {
        'name': s.name,
        'amount': s.amount,
        'unit': s.unit,
        'detail': s.detail,
      }).toList(),
      'finings': r.zutaten.finings.map((f) => {
        'name': f.name,
        'amount': f.amount,
        'phase': f.phase, 
        'purpose': f.purpose,
        'detail': f.applicationDetail,
        'procurement_needed': f.procurementNeeded,
      }).toList(),
      'mash_steps': r.prozessdaten.mash.steps.map((s) => {
        'stage': s.stage,
        'temp_c': s.temp,
        'duration_min': s.duration,
      }).toList(),
      'fermentation_steps': r.prozessdaten.fermentation.steps.map((s) => {
        'phase': s.phase,
        'temp_c': s.temp,
        'days': s.days,
        'pressure_bar': s.pressure,
        'pressure_note': s.pressureReason,
        'note': s.note,
      }).toList(),
    };

    if (_currentDatabaseId != null) {
      data['id'] = _currentDatabaseId;
    }

    final response = await client
        .schema('aibrewgenius')
        .from('ai_generated_recipes_v2')
        .upsert(data)
        .select('id')
        .single();
    
    if (response['id'] != null) {
      setState(() {
        _currentDatabaseId = response['id'].toString();
      });
    }
  }

  Future<void> _ensureBase64Image() async {
    // Falls schon verarbeitet oder gar keine neue URL da, nichts tun
    if (_processedBase64Image != null || _generatedImageUrl == null) return;

    try {
      Uint8List bytes;
      if (_generatedImageUrl!.startsWith('data:')) {
        final idx = _generatedImageUrl!.indexOf(',');
        bytes = base64Decode(_generatedImageUrl!.substring(idx + 1));
      } else {
        final urlToFetch = '${_openAIService.proxyBaseUrl}/proxy-image?url=${Uri.encodeComponent(_generatedImageUrl!)}';
        final response = await http.get(Uri.parse(urlToFetch));
        if (response.statusCode != 200) return;
        bytes = response.bodyBytes;
      }

      final image = img.decodeImage(bytes);
      if (image != null) {
        final resized = img.copyResize(image, width: 256);
        final jpg = img.encodeJpg(resized, quality: 65);
        _processedBase64Image = base64Encode(jpg);
      }
    } catch (e) {
      debugPrint('Image processing failed: $e');
    }
  }

  Future<void> _handleBrewfatherExport() async {
    setState(() => _isSaving = true);
    await _ensureBase64Image();
    
    String? authorName;
    bool? isPressure;
    try {
      final userService = UserProfileService();
      final profile = await userService.fetchDefaultProfile();
      authorName = profile?.name;
      
      final fermenterService = FermenterService();
      final fermenters = await fermenterService.fetchFermenters(UserProfileService.currentUserId);
      final defaultFermenter = fermenters.where((f) => f.isDefault).firstOrNull ?? fermenters.firstOrNull;
      isPressure = defaultFermenter?.canPressurize;
    } catch (e) {
      debugPrint('Profil/Fermenter-Fetch fehlgeschlagen: $e');
    }

    setState(() => _isSaving = false);

    final finalImage = _processedBase64Image ?? widget.recipe.generatedImage;
    final recipeToExport = finalImage != null 
        ? widget.recipe.copyWith(generatedImage: finalImage)
        : widget.recipe;

    if (!mounted) return;

    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => JsonExportPage(
        recipe: recipeToExport,
        author: authorName,
        isPressureOverride: isPressure,
      )),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezept abschließen'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Dein Rezept ist bereit!',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Bild-Prompt anpassen:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _promptController,
              maxLines: 4,
              enabled: !_isGenerating,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                hintText: 'Vorgeschlagener Prompt...',
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
              ),
            ),
            if (widget.recipe.sourceImage != null) ...[
              const SizedBox(height: 8),
              CheckboxListTile(
                title: const Text(
                  'Soll das hochgeladene Foto als Vorlage an ChatGPT mitgeliefert werden?',
                  style: TextStyle(fontSize: 14),
                ),
                value: _useSourceImage,
                onChanged: _isGenerating 
                    ? null 
                    : (val) => setState(() => _useSourceImage = val ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
                dense: true,
              ),
            ],
            const SizedBox(height: 16),
            

            const SizedBox(height: 16),
            
            if (_generatedImageUrl != null || widget.recipe.generatedImage != null) ...[
              const Text(
                'Generiertes Bild:',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Center(
                child: FractionallySizedBox(
                  widthFactor: 0.25,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black26,
                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                      ),
                  child: _generatedImageUrl != null
                    ? Image.network(
                        _generatedImageUrl!.startsWith('data:')
                            ? _generatedImageUrl!
                            : '${_openAIService.proxyBaseUrl}/proxy-image?url=${Uri.encodeComponent(_generatedImageUrl!)}',
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return SizedBox(
                            height: 300,
                            child: Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Lade Bild: ${loadingProgress.cumulativeBytesLoaded ~/ 1024} KB',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                      )
                    : Image.memory(
                        base64Decode(widget.recipe.generatedImage!),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => _buildErrorWidget(),
                      ),
                    ),
                  ),
                ),
              ),
            ],
            if (_generatedImageUrl != null) ...[
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      final url = Uri.parse(_generatedImageUrl!);
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    },
                    icon: const Icon(Icons.download),
                    label: const Text('Bild öffnen / Download'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generatedImageUrl!));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Link in Zwischenablage kopiert!')),
                      );
                    },
                    icon: const Icon(Icons.link),
                    label: const Text('Link kopieren'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],

            _CompletionButton(
              label: _isGenerating ? 'Generiere...' : 'Bild generieren',
              icon: Icons.auto_awesome,
              onPressed: _isGenerating ? null : _generateImage,
              isLoading: _isGenerating,
            ),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            _CompletionButton(
              label: _isSaving ? 'Speichere...' : 'Rezept abspeichern',
              icon: Icons.save,
              isLoading: _isSaving,
              onPressed: (_isGenerating || _isSaving) ? null : () async {
                setState(() => _isSaving = true);
                try {
                  await _saveRecipeNormalized();

                  if (context.mounted) {
                    setState(() => _isSaving = false);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rezept erfolgreich gespeichert!')),
                    );
                  }
                } catch (e) {
                  setState(() => _isSaving = false);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Fehler beim Speichern: $e')),
                    );
                  }
                }
              },
            ),
            const SizedBox(height: 16),
            _CompletionButton(
              label: 'In Brewfather.json transformieren',
              icon: Icons.code,
              onPressed: _isGenerating ? null : _handleBrewfatherExport,
            ),
            const SizedBox(height: 16),
            _CompletionButton(
              label: 'In BeerXML transformieren',
              icon: Icons.description,
              onPressed: _isGenerating ? null : () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('In BeerXML transformieren...')),
                );
              },
            ),
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            _CompletionButton(
              label: 'Zur Startseite',
              icon: Icons.home,
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
  Widget _buildErrorWidget() {
    return Container(
      height: 200,
      color: Colors.red.withValues(alpha: 0.1),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 48),
            const SizedBox(height: 8),
            const Text('Bild konnte nicht geladen werden.'),
            TextButton(
              onPressed: _generateImage,
              child: const Text('Erneut generieren'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompletionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool isLoading;

  const _CompletionButton({
    required this.label,
    required this.icon,
    this.onPressed,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: isLoading 
          ? const SizedBox(
              width: 18, 
              height: 18, 
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            ) 
          : Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16),
      ),
    );
  }
}
