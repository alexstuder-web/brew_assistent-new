import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:mime/mime.dart';

import '../services/openai_service.dart';
import '../services/packaging_profile_service.dart';
import '../services/brew_kettle_service.dart';
import '../services/fermenter_service.dart';
import '../services/fining_agents_service.dart';
import '../services/yeast_bank_service.dart';
import '../services/user_profile_service.dart';
import '../models/packaging_profile.dart';
import '../models/brew_kettle.dart';
import '../models/fermenter.dart';
import '../models/ai_recipe.dart';
import '../models/image_attachment.dart';
import '../utils/recipe_scaler.dart';

class RecipePromptController extends ChangeNotifier {
  final TextEditingController promptController = TextEditingController();
  final OpenAIService _service = OpenAIService();

  String? responseText;
  String? error;
  bool isLoading = false;
  Uint8List? imageBytes;
  String? imageName;
  String? imageMime;
  bool isSearchingShops = false;
  String? lastGeneratedPrompt;
  AiRecipe? lastGeneratedRecipe;

  @override
  void dispose() {
    promptController.dispose();
    super.dispose();
  }

  Future<void> requestRecipe(BuildContext context, VoidCallback onSuccess) async {
    final userInput = promptController.text.trim();
    if (userInput.isEmpty) {
      error = 'Bitte gib eine Beschreibung ein.';
      notifyListeners();
      return;
    }

    isLoading = true;
    error = null;
    lastGeneratedPrompt = null;
    responseText = null;
    notifyListeners();

    try {
      final bundle = DefaultAssetBundle.of(context);
      final template = await bundle.loadString('prompt/freitext_rezept_basis2');
      final jsonTemplate = await bundle.loadString('prompt/freitext_response_template2.json');

      double targetVolume = 20.0;
      double bottleVolume = 0.0;
      double kegVolume = 0.0;
      bool bottleEnabled = false;
      bool kegEnabled = false;
      String servingGas = 'CO2';
      double? bottleCarbTemp;
      double? kegCarbTemp;
      double? kegStorageTemp;
      bool foundDefaultPackaging = false;
      bool foundDefaultKettle = false;
      bool foundDefaultFermenter = false;
      BrewKettle? defaultKettle;
      Fermenter? defaultFermenter;

      try {
        final packagingService = PackagingProfileService();
        final profiles = await packagingService.fetchProfiles(UserProfileService.defaultProfileId);
        foundDefaultPackaging = profiles.any((p) => p.isDefault);
        
        final defaultProfile = profiles.firstWhere(
          (p) => p.isDefault,
          orElse: () => profiles.isNotEmpty ? profiles.first : PackagingProfile(id: '', userProfileId: '', name: '', createdAt: DateTime.now()),
        );

        if (defaultProfile.targetVolume != null) targetVolume = defaultProfile.targetVolume!;
        
        if (defaultProfile.bottleEnabled) {
          bottleEnabled = true;
          bottleCarbTemp = defaultProfile.bottleCarbonationTempC;
        }

        if (defaultProfile.kegEnabled) {
          kegEnabled = true;
          kegVolume = defaultProfile.kegVolumeLiters ?? 0.0;
          kegCarbTemp = defaultProfile.kegCarbonationTempC;
          kegStorageTemp = defaultProfile.kegStorageTempC;
          final List<String> g = [];
          if (defaultProfile.hasCo2) g.add('CO2');
          if (defaultProfile.hasNitro) g.add('Nitro');
          if (g.isNotEmpty) servingGas = g.join(' + ');
        }

        if (bottleEnabled && kegEnabled) {
          if (kegVolume > targetVolume) {
            kegVolume = targetVolume;
            bottleVolume = 0;
          } else {
            bottleVolume = targetVolume - kegVolume;
          }
        } else if (kegEnabled) {
          kegVolume = targetVolume;
          bottleVolume = 0;
        } else {
          bottleVolume = targetVolume;
          bottleEnabled = true;
        }
      } catch (e) {
        debugPrint('Error fetching packaging profile: $e');
        bottleVolume = targetVolume;
        bottleEnabled = true;
      }

      String packagingInfo = '';
      String bottleInfoText = '';
      String kegInfoText = '';

      if (kegEnabled && kegVolume > 0) kegInfoText = '${kegVolume.toStringAsFixed(1)} Liter KEGS';
      if (bottleEnabled && bottleVolume > 0) bottleInfoText = '${bottleVolume.toStringAsFixed(1)} Liter FLASCHEN';

      if (bottleInfoText.isNotEmpty && kegInfoText.isNotEmpty) {
        packagingInfo = 'Abfüllung: $bottleInfoText und $kegInfoText (Zapfgas: $servingGas)\\n(Flaschen-Temp: ${bottleCarbTemp ?? 20}°C, Keg-Carb-Temp: ${kegCarbTemp ?? 5}°C, Keg-Lager-Temp: ${kegStorageTemp ?? 5}°C)';
      } else if (bottleInfoText.isNotEmpty) {
        packagingInfo = 'Abfüllung: $bottleInfoText\\n(Flaschen-Temp: ${bottleCarbTemp ?? 20}°C)';
      } else if (kegInfoText.isNotEmpty) {
        packagingInfo = 'Abfüllung: $kegInfoText (Zapfgas: $servingGas)\\n(Keg-Carb-Temp: ${kegCarbTemp ?? 5}°C, Keg-Lager-Temp: ${kegStorageTemp ?? 5}°C)';
      } else {
        packagingInfo = 'Keine spezifische Abfüllung angegeben.';
      }

      String brewingEquipmentInfo = 'Kein spezifisches Equipment angegeben.';
      try {
        final kettleService = BrewKettleService();
        final kettles = await kettleService.fetchKettles(UserProfileService.defaultProfileId);
        foundDefaultKettle = kettles.any((k) => k.isDefault);
        if (kettles.isNotEmpty) {
          defaultKettle = kettles.firstWhere((k) => k.isDefault, orElse: () => kettles.first);
          brewingEquipmentInfo = 'Marke: ${defaultKettle.brand}, Modell: ${defaultKettle.model ?? ""}, Volumen: ${defaultKettle.volumeLiters}L';
          if (defaultKettle.hasCondenserHat) brewingEquipmentInfo += ', Kondensator Hut vorhanden';
        }
      } catch (e) {
        debugPrint('Error fetching brew kettles: $e');
      }

      String fermenterInfo = 'Kein spezifischer Fermenter angegeben.';
      try {
        final fermenterService = FermenterService();
        final fermenters = await fermenterService.fetchFermenters(UserProfileService.defaultProfileId);
        foundDefaultFermenter = fermenters.any((f) => f.isDefault);
        if (fermenters.isNotEmpty) {
          defaultFermenter = fermenters.firstWhere((f) => f.isDefault, orElse: () => fermenters.first);
          fermenterInfo = 'Marke: ${defaultFermenter.brand}, Gärverlust: ${defaultFermenter.fermentationLossLiters}L';
          fermenterInfo += ', Heizung: ${defaultFermenter.hasHeating ? "vorhanden" : "NICHT vorhanden"}';
          fermenterInfo += ', Kühlung: ${defaultFermenter.hasCooling ? "vorhanden" : "NICHT vorhanden"}';
          if (defaultFermenter.canPressurize) {
            fermenterInfo += ', Druckvergärung möglich';
          } else {
            fermenterInfo += ', Druckvergärung NICHT möglich';
          }
        }
      } catch (e) {
        debugPrint('Error fetching fermenters: $e');
      }

      String finingAgentsInfo = 'Keine verfügbaren Schönungsmittel im Profil.';
      try {
        final finingService = FiningAgentsService();
        final settings = await finingService.fetchSettings(UserProfileService.defaultProfileId);
        
        final available = <String>[];
        if (settings.irishMoss) available.add('Irish Moss (Kochen)');
        if (settings.whirlfloc) available.add('Whirlfloc (Kochen/Whirlpool)');
        if (settings.gelatin) available.add('Gelatine (Klärung/Lagerung)');
        if (settings.biersol) available.add('Biersol (Klärung)');
        if (settings.polyclar) available.add('Polyclar (Stabilisierung)');
        if (settings.isinglass) available.add('Isinglass (Klärung)');
        if (settings.bentonite) available.add('Bentonite (Klärung)');
        if (settings.eggWhites) available.add('Eiweiß (Klärung)');
        if (settings.activatedCarbon) available.add('Aktivkohle (Klärung/Geschmack)');
        
        if (settings.extras.isNotEmpty) available.addAll(settings.extras.map((e) => '$e (Benutzerdefiniert)'));
        if (available.isNotEmpty) finingAgentsInfo = available.map((a) => '- $a').join('\\n');
      } catch (e) {
        debugPrint('Error fetching fining agents: $e');
      }

      String yeastInventoryInfo = 'Keine Hefe im Bestand gefunden.';
      try {
        final yeastService = YeastBankService();
        final entries = await yeastService.fetchEntries(UserProfileService.defaultProfileId);
        if (entries.isNotEmpty) {
          yeastInventoryInfo = entries.map((y) {
            String s = '- ${y.brand} ${y.strain}';
            if (y.productId != null) s += ' (${y.productId})';
            if (y.form != null) s += ' [${y.form}]';
            if (y.inventory != null) s += ' - Bestand: ${y.inventory} ${y.unit ?? "Pck."}';
            return s;
          }).join('\\n');
        }
      } catch (e) {
        debugPrint('Error fetching yeast bank: $e');
      }

      final missingDefaults = <String>[];
      if (!foundDefaultPackaging) missingDefaults.add('Verpackungsprofil (Favorit)');
      if (!foundDefaultKettle) missingDefaults.add('Brauanlage (Favorit)');
      if (!foundDefaultFermenter) missingDefaults.add('Fermenter (Favorit)');

      if (missingDefaults.isNotEmpty) {
        if (!context.mounted) return;
        final proceed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Information'),
            content: Text('Für ein präzises Rezept fehlen Favoriten:\\n\\n${missingDefaults.map((e) => '- $e').join('\\n')}\\n\\nEs wird mit Standardwerten improvisiert.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Trotzdem erstellen')),
            ],
          ),
        );
        if (proceed != true) {
          isLoading = false;
          notifyListeners();
          return;
        }
      }

      final fermLoss = defaultFermenter?.fermentationLossLiters ?? 0.0;
      final pBoilLoss = defaultKettle?.postBoilLossLiters ?? 0.0;
      final bOffPct = defaultKettle?.boilOffPercentage ?? 10.0;
      final bhEfficiency = defaultKettle?.bhEfficiency ?? 70.0;

      final fullPrompt = template
          .replaceAll('{{description}}', userInput)
          .replaceAll('{{targetVolume}}', targetVolume.toStringAsFixed(1))
          .replaceAll('{{fermentationLoss}}', fermLoss.toStringAsFixed(1))
          .replaceAll('{{postBoilLoss}}', pBoilLoss.toStringAsFixed(1))
          .replaceAll('{{boilOffPercentage}}', bOffPct.toStringAsFixed(1))
          .replaceAll('{{bhEfficiency}}', bhEfficiency.toStringAsFixed(1))
          .replaceAll('{{packaging_info}}', packagingInfo)
          .replaceAll('{{brewing_equipment}}', brewingEquipmentInfo)
          .replaceAll('{{fermenter_info}}', fermenterInfo)
          .replaceAll('{{fining_agents}}', finingAgentsInfo)
          .replaceAll('{{yeast_inventory}}', yeastInventoryInfo)
          .replaceAll('{{json_template}}', jsonTemplate);

      lastGeneratedPrompt = fullPrompt;
      notifyListeners();

      final attachment = _buildAttachment();
      final recipeJsonString = await _service.brewRecipe(
        fullPrompt,
        attachment: attachment,
      );
      
      final cleanedJson = _extractJson(recipeJsonString);
      final recipeMap = jsonDecode(cleanedJson);
      var initialRecipe = AiRecipe.fromJson(recipeMap).copyWith(
        canPressurize: defaultFermenter?.canPressurize ?? false,
      );

      final scaledRecipe = RecipeScaler.scale(
        initialRecipe,
        bhEfficiency: bhEfficiency,
        targetVolumeL: targetVolume,
        fermentationLossL: fermLoss,
        postBoilLossL: pBoilLoss,
        boilOffPercentage: bOffPct,
      );

      if (attachment != null) {
        scaledRecipe.sourceImage = attachment;
      }

      isLoading = false;
      lastGeneratedRecipe = scaledRecipe;
      responseText = recipeJsonString;
      notifyListeners();

      onSuccess();

    } catch (e) {
      String msg = e.toString();
      if (msg.contains('Interner Proxy-Fehler') || msg.contains('504') || msg.contains('500')) {
         msg = 'Fehler: Die KI antwortet nicht rechtzeitig oder das Bild ist zu groß.\\nBitte versuche es erneut (ggf. ohne Bild oder kürzerem Text).';
      }
      error = msg;
      isLoading = false;
      notifyListeners();
    }
  }

  String _extractJson(String input) {
    String cleaned = input.trim();
    if (cleaned.startsWith('```')) {
      final lines = cleaned.split('\\n');
      if (lines.length > 2) {
        cleaned = lines.sublist(1, lines.length - 1).join('\\n').trim();
      }
    }
    final firstBrace = cleaned.indexOf('{');
    final lastBrace = cleaned.lastIndexOf('}');
    if (firstBrace != -1 && lastBrace != -1 && lastBrace > firstBrace) {
      return cleaned.substring(firstBrace, lastBrace + 1);
    }
    return cleaned;
  }

  Future<void> pickImage(Function(String) showSnackBar) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      
      final file = result.files.first;
      Uint8List? rawBytes = file.bytes;
      if (rawBytes == null) {
        showSnackBar('Konnte Bilddaten nicht laden.');
        return;
      }
      
      if (rawBytes.lengthInBytes > 10 * 1024 * 1024) throw Exception('Bild zu groß (max 10MB)');
      
      imageBytes = rawBytes;
      imageName = file.name;
      
      final mime = lookupMimeType(
        file.name,
        headerBytes: rawBytes.length >= 16 ? rawBytes.sublist(0, 16) : rawBytes,
      );
      
      if (mime == null || !mime.startsWith('image/')) {
        showSnackBar('Nur Bilddateien werden unterstützt.');
        return;
      }
      
      imageMime = mime;
      notifyListeners();
    } catch (e) {
      showSnackBar('Fehler beim Bild-Upload: $e');
    }
  }

  void clearImage() {
    imageBytes = null;
    imageName = null;
    imageMime = null;
    notifyListeners();
  }

  ImageAttachment? _buildAttachment() {
    if (imageBytes == null || imageMime == null) return null;
    return ImageAttachment(
      bytes: imageBytes!,
      mimeType: imageMime!,
      fileName: imageName,
    );
  }

  Future<List<ShopSearchResponse>> searchShopsForIngredients() async {
    if (responseText == null || isSearchingShops) return [];
    final queries = _extractShopQueries(responseText!);
    if (queries.isEmpty) return [];
    
    isSearchingShops = true;
    notifyListeners();
    
    final results = <ShopSearchResponse>[];
    try {
      for (final query in queries) {
        final resp = await _service.searchShops(query);
        results.add(resp);
      }
      isSearchingShops = false;
      notifyListeners();
      return results;
    } catch (e) {
      isSearchingShops = false;
      notifyListeners();
      throw Exception('Shopsuche fehlgeschlagen: $e');
    }
  }

  List<String> _extractShopQueries(String text) {
    final queries = <String>{};
    final parsed = _tryParseIngredientJson(text);
    if (parsed != null) {
      void collect(String key) {
        final list = parsed[key];
        if (list is List) {
          for (final item in list) {
            if (item is Map && item['name'] is String) {
              final name = (item['name'] as String).trim();
              if (name.isNotEmpty) {
                queries.add(name);
                if (queries.length >= 12) return;
              }
            }
          }
        }
      }
      collect('malz');
      collect('hopfen');
      collect('hefe');
      if (queries.isNotEmpty) return queries.toList();
    }

    final fallbackCategories = {'malz', 'hopfen', 'hefe'};
    final lines = text.split('\\n');
    String? currentCategory;
    for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;
      final lower = line.toLowerCase();
      if (fallbackCategories.any((cat) => lower.startsWith(cat) && (lower.length == cat.length || lower.substring(cat.length).startsWith(' ') || lower.substring(cat.length).startsWith(':')))) {
        currentCategory = fallbackCategories.firstWhere((cat) => lower.startsWith(cat));
        continue;
      }
      if (lower.endsWith(':')) {
        final heading = lower.substring(0, lower.length - 1);
        if (fallbackCategories.contains(heading)) {
          currentCategory = heading;
          continue;
        }
      }
      if (currentCategory == null) continue;
      String entry = line;
      if (entry.startsWith('#')) continue;
      if (RegExp(r'^[0-9]+[\\.\\)]').hasMatch(entry)) continue;
      if (entry.toLowerCase().contains('mais') || entry.toLowerCase().contains('gär') || entry.toLowerCase().contains('plan')) continue;
      if (entry.startsWith('-') || entry.startsWith('*')) entry = entry.substring(1).trim();
      entry = entry.replaceFirst(RegExp(r'^[0-9\\.\\)\\s]+'), '').trim();
      if (entry.isEmpty) continue;
      if (entry.toLowerCase() == 'unbekannt') continue;
      queries.add(entry);
      if (queries.length >= 8) break;
    }
    return queries.toList();
  }

  Map<String, dynamic>? _tryParseIngredientJson(String text) {
    try {
      final decoded = jsonDecode(text);
      if (decoded is Map<String, dynamic>) return decoded;
    } catch (_) {}
    return null;
  }
}
