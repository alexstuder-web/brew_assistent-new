import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../utils/download_utils.dart';
import 'package:url_launcher/url_launcher.dart'; 
import '../models/ai_recipe.dart';
import '../services/brewfather_transformer_service.dart';

class JsonExportPage extends StatefulWidget {
  final AiRecipe recipe;
  final String? author;
  final bool? isPressureOverride;

  const JsonExportPage({
    super.key,
    required this.recipe,
    this.author,
    this.isPressureOverride,
  });

  @override
  State<JsonExportPage> createState() => _JsonExportPageState();
}

class _JsonExportPageState extends State<JsonExportPage> {
  late String _jsonString;
  late String _fileName;

  @override
  void initState() {
    super.initState();
    final map = BrewfatherTransformerService.transform(
      widget.recipe,
      author: widget.author,
      isPressure: widget.isPressureOverride,
    );
    _jsonString = const JsonEncoder.withIndent('  ').convert(map);
    
    // Generate filename: Brewfather_RECIPE_Name_Date.json
    final date = DateTime.now();
    final dateStr = '${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}';
    final cleanName = widget.recipe.basisBier.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '');
    _fileName = 'Brewfather_RECIPE_${cleanName}_$dateStr.json';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Brewfather Export'),
        actions: [
          // Download Button
          IconButton(
            icon: const Icon(Icons.download),
            tooltip: 'Download JSON',
            onPressed: _download,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              color: Colors.blueGrey.withValues(alpha: 0.1),
              child: SelectableText(
                'Dateiname: $_fileName\n\nSpeichere das JSON über den Download-Button oben rechts ab, um die Datei danach in Brewfather importieren zu können.',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(8),
                  child: SelectableText(
                    _jsonString,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _download() async {
    try {
      if (kIsWeb) {
        final bytes = utf8.encode(_jsonString);
        downloadBytes(
          Uint8List.fromList(bytes),
          _fileName,
          mimeType: 'application/json',
        );
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download gestartet!')),
          );
        }
        return;
      }

      // Fallback für Nicht-Web (z.B. Desktop/Mobile) via url_launcher
      final dataUri = Uri.dataFromString(
        _jsonString,
        mimeType: 'application/json',
        encoding: utf8,
      );
      
      if (await canLaunchUrl(dataUri)) {
        await launchUrl(dataUri);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download auf dieser Plattform leider nicht unterstützt.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
      }
    }
  }
}
