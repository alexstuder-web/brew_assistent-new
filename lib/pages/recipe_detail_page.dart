import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../models/bf_recipe.dart';
import '../services/user_profile_service.dart';
import '../services/openai_service.dart';
import '../l10n/app_localizations.dart';
import '../widgets/section_title.dart';

class RecipeDetailPage extends StatefulWidget {
  const RecipeDetailPage({super.key, required this.recipe});

  final BfRecipe recipe;

  @override
  State<RecipeDetailPage> createState() => _RecipeDetailPageState();
}

class _RecipeDetailPageState extends State<RecipeDetailPage> {
  final UserProfileService _userService = UserProfileService();
  late BfRecipe _recipe;
  bool _isLoadingImage = false;

  @override
  void initState() {
    super.initState();
    _recipe = widget.recipe;
    _checkAndLoadImage();
  }

  Future<void> _checkAndLoadImage() async {
    // If we already have the image bytes, good.
    if (_recipe.image != null && _recipe.image!.isNotEmpty) {
      return;
    }

    // Check if JSON has img_url
    final jsonImg = _recipe.data['image'] ?? _recipe.data['img_url'];
    if (jsonImg != null && jsonImg is String && jsonImg.startsWith('http')) {
      final imgUrl = jsonImg;

      if (!mounted) return;
      setState(() => _isLoadingImage = true);

      try {
        // Try direct fetch first
        var response = await http.get(Uri.parse(imgUrl));
        
        // If direct fetch fails (non-200), or if we are here, we check status.
        // Note: CORS errors in Web usually throw an exception, so we'll catch 'em below.
        if (response.statusCode == 200) {
           await _saveImageBytes(response.bodyBytes);
           return;
        }
      } catch (e) {
        debugPrint('Direct fetch failed (likely CORS), trying proxy... $e');
      }

      // Fallback: Try via CORS proxy
      // We use a public proxy for this client-side demo workaround. 
      // In production, you'd use your own backend proxy or Supabase Edge Function.
      try {
        final proxyUrl = 'https://api.allorigins.win/raw?url=${Uri.encodeComponent(imgUrl)}';
        final response = await http.get(Uri.parse(proxyUrl));
        
        if (response.statusCode == 200) {
           await _saveImageBytes(response.bodyBytes);
           return;
        }
      } catch (e) {
        debugPrint('Proxy fetch failed too: $e');
      }

    }
  }

  Future<void> _analyzeRecipe() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final analysis = await OpenAIService().analyzeRecipe(_recipe.data);
      if (!mounted) return;
      Navigator.pop(context); // Pop loading

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (context) => DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) => SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      AppLocalizations.of(context)!.analysisResult,
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(analysis),
              ],
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // Pop loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Fehler bei der Analyse: $e')),
      );
    }
  }

  Future<void> _saveImageBytes(List<int> bytes) async {
    final updatedRecipe = _recipe.copyWith(image: Uint8List.fromList(bytes));
    
    // Save to DB
    await _userService.saveRecipe(updatedRecipe);

    if (mounted) {
      setState(() {
        _recipe = updatedRecipe;
        _isLoadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _recipe.data;
    final fermentables = data['fermentables'] as List<dynamic>? ?? [];
    final hops = data['hops'] as List<dynamic>? ?? [];
    final yeast = data['yeasts'] as List<dynamic>? ?? [];
    final mash = data['mash'] as Map<String, dynamic>?;
    final mashSteps = mash?['steps'] as List<dynamic>? ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(_recipe.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            onPressed: _analyzeRecipe,
            tooltip: AppLocalizations.of(context)!.analyzeRecipe,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTopSection(context),
            const SizedBox(height: 24),
            const SectionTitle('Malz & Gärfähiges', color: Colors.blueAccent),
            ...fermentables.map((f) => _buildIngredientRow(
                  f['name'],
                  '${f['amount']} ${f['unit'] ?? 'kg'}',
                  subtitle: '${f['type'] ?? ''} • ${f['potential'] ?? ''} SG',
                )),
            if (fermentables.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gesamtmenge Malz:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${fermentables.fold<double>(0, (sum, f) => sum + ((f['amount'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(2)} kg',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),
            
            const SectionTitle('Hopfen', color: Colors.blueAccent),
            ...hops.map((h) => _buildIngredientRow(
                  h['name'],
                  '${h['amount']} ${h['unit'] ?? 'g'}',
                  subtitle: '${h['use']} • ${h['time']} min • ${h['alpha']}% Alpha',
                )),
            if (hops.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8, bottom: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Gesamtmenge Hopfen:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      '${hops.fold<double>(0, (sum, h) => sum + ((h['amount'] as num?)?.toDouble() ?? 0.0)).toStringAsFixed(0)} g',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.greenAccent),
                    ),
                  ],
                ),
              ),
            
            const SectionTitle('Hefe', color: Colors.blueAccent),
            ...yeast.map((y) => _buildIngredientRow(
                  y['name'],
                  '${y['amount']} ${y['unit'] ?? ''}',
                  subtitle: '${y['laboratory'] ?? ''} ${y['productId'] ?? ''}',
                )),

            const SizedBox(height: 16),
            const SectionTitle('Maische', color: Colors.blueAccent),
             ...mashSteps.map((step) => _buildIngredientRow(
                  step['name'] ?? 'Step',
                  '${step['stepTemp']} °C',
                  subtitle: '${step['stepTime']} min',
                )),

            const SizedBox(height: 24),
            ExpansionTile(
              title: const Text('Rohdaten (JSON)'),
              children: [
                SelectableText(
                  const JsonEncoder.withIndent('  ').convert(data),
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSection(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
         // Image Section
         Container(
           width: 100,
           height: 100,
           margin: const EdgeInsets.only(right: 16),
           decoration: BoxDecoration(
             color: Colors.black12,
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: Colors.white24),
           ),
           child: _buildImageWidget(),
         ),
         // Stats Section
         Expanded(
           child: _buildHeader(context),
         ),
      ],
    );
  }

  Widget _buildImageWidget() {
    if (_recipe.image != null && _recipe.image!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.memory(
          _recipe.image!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              const Icon(Icons.broken_image, size: 32),
        ),
      );
    }
    if (_isLoadingImage) {
      return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    }
    return const Center(child: Icon(Icons.image_not_supported, color: Colors.white24));
  }


  Widget _buildHeader(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('ABV', '${_recipe.abv?.toStringAsFixed(1)}%'),
                _buildStat('IBU', '${_recipe.ibu?.toStringAsFixed(0)}'),
              ],
            ),
            const SizedBox(height: 8),
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStat('EBC', '${_recipe.color?.toStringAsFixed(0)}'),
                _buildStat('Style', _recipe.style ?? '-'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStat(String label, String value) {
    return Column(
      children: [
        Text(label, style: const TextStyle(color: Colors.white60, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
      ],
    );
  }



  Widget _buildIngredientRow(String name, String amount, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(fontSize: 16)),
                if (subtitle != null)
                  Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
              ],
            ),
          ),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
