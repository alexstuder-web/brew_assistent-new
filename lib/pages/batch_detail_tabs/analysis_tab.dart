import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../../models/bf_batch.dart';
import '../../services/user_profile_service.dart';
import '../../utils/image_utils.dart';

class AnalysisTab extends StatefulWidget {
  const AnalysisTab({super.key, required this.batch});

  final BfBatch batch;

  @override
  State<AnalysisTab> createState() => _AnalysisTabState();
}

class _AnalysisTabState extends State<AnalysisTab> {
  late TextEditingController _analysisController;
  late List<String> _analysisPhotos;
  bool _isSavingAnalysis = false;

  @override
  void initState() {
    super.initState();
    _analysisController = TextEditingController(
      text: widget.batch.analysisData['description'] ?? '',
    );
    final existingPhotos = widget.batch.analysisData['photos'] ?? [];
    _analysisPhotos = List<String>.from(existingPhotos
        .where((p) => (p as String).startsWith('data:image'))
        .toList());
  }

  @override
  void dispose() {
    _analysisController.dispose();
    super.dispose();
  }

  Future<void> _pickAndProcessPhoto() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) return;

      for (var file in result.files) {
        Uint8List? fileBytes = file.bytes;
        if (fileBytes == null) continue;

        String? base64Result = await processPhoto(fileBytes);

        if (base64Result != null) {
          setState(() {
            _analysisPhotos.add(base64Result);
          });
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text(
                      'Das Format von "${file.name}" konnte nicht verarbeitet werden.')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Foto-Upload fehlgeschlagen: $e')),
        );
      }
    }
  }

  Future<void> _saveBatchAnalysis() async {
    setState(() => _isSavingAnalysis = true);
    try {
      widget.batch.analysisData['description'] = _analysisController.text;
      widget.batch.analysisData['photos'] = _analysisPhotos;

      await UserProfileService().saveBatches([widget.batch]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Analyse erfolgreich gespeichert.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSavingAnalysis = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'SENSORIK & BEWERTUNG',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
              if (_isSavingAnalysis)
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2))
              else
                TextButton.icon(
                  onPressed: _saveBatchAnalysis,
                  icon: const Icon(Icons.save, size: 18, color: Colors.greenAccent),
                  label: const Text('SPEICHERN',
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.bold)),
                ),
            ],
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _analysisController,
            maxLines: 12,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white.withValues(alpha: 0.05),
              hintText:
                  'Beschreibe Aussehen, Geruch und Geschmack deines Bieres...',
              hintStyle: const TextStyle(color: Colors.white24),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'FOTOS',
                style: TextStyle(
                    color: Colors.grey,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5),
              ),
              TextButton.icon(
                onPressed: _pickAndProcessPhoto,
                icon: const Icon(Icons.add_a_photo, size: 18),
                label: const Text('HINZUFÜGEN'),
                style: TextButton.styleFrom(foregroundColor: Colors.greenAccent),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_analysisPhotos.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.02),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white10),
              ),
              child: const Column(
                children: [
                  Icon(Icons.photo_library_outlined,
                      color: Colors.white24, size: 48),
                  SizedBox(height: 12),
                  Text('Noch keine Fotos hinzugefügt',
                      style: TextStyle(color: Colors.white24)),
                ],
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _analysisPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _analysisPhotos[index].startsWith('data:image')
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(
                                base64Decode(
                                    _analysisPhotos[index].split(',').last),
                                fit: BoxFit.cover,
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.broken_image,
                                    color: Colors.white24, size: 32),
                                const SizedBox(height: 4),
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    _analysisPhotos[index],
                                    style: const TextStyle(
                                        fontSize: 8, color: Colors.white54),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                      Positioned(
                        top: 4,
                        right: 4,
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _analysisPhotos.removeAt(index)),
                          child: CircleAvatar(
                            radius: 12,
                            backgroundColor: Colors.red.withValues(alpha: 0.8),
                            child:
                                const Icon(Icons.close, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
