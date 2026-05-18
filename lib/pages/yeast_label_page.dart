import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../models/yeast_bank_entry.dart';
import '../services/yeast_bank_service.dart';
import '../utils/clipboard_utils.dart';
import '../utils/download_utils.dart';
// unnecessary_import fixed

class YeastLabelPage extends StatefulWidget {
  final YeastBankEntry entry;
  const YeastLabelPage({super.key, required this.entry});

  @override
  State<YeastLabelPage> createState() => _YeastLabelPageState();
}

class _YeastLabelPageState extends State<YeastLabelPage> {
  final GlobalKey _globalKey = GlobalKey();
  late TextEditingController _brandCtrl;
  late TextEditingController _strainCtrl;
  late TextEditingController _productIdCtrl;
  late TextEditingController _tempRangeCtrl;
  late TextEditingController _urlCtrl;
  late DateTime _selectedDate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _brandCtrl = TextEditingController(text: widget.entry.brand);
    _strainCtrl = TextEditingController(text: widget.entry.strain);
    _productIdCtrl = TextEditingController(text: widget.entry.productId ?? '');
    
    final minTemp = widget.entry.temperatureMin?.toStringAsFixed(1) ?? '??';
    final maxTemp = widget.entry.temperatureMax?.toStringAsFixed(1) ?? '??';
    _tempRangeCtrl = TextEditingController(text: '$minTemp - $maxTemp °C');
    
    _urlCtrl = TextEditingController(text: widget.entry.url ?? '');
    _selectedDate = DateTime.now();
  }

  @override
  void dispose() {
    _brandCtrl.dispose();
    _strainCtrl.dispose();
    _productIdCtrl.dispose();
    _tempRangeCtrl.dispose();
    _urlCtrl.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _copyLabel() async {
    final generation = widget.entry.zuchtGenerationen.length + 1;
    final dateDisplay = DateFormat('dd.MM.yyyy').format(_selectedDate);
    
    // 1. Copy Text to Clipboard (Keep as fallback or secondary)
    final textContent = '''
${_brandCtrl.text}
${_productIdCtrl.text}
${_strainCtrl.text}
${_tempRangeCtrl.text}
$dateDisplay
$generation. Generation
'''.trim();

    await Clipboard.setData(ClipboardData(text: textContent));

    // 2. Try to copy Image (Label) to Clipboard
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      // We use a high pixel ratio for better quality
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        await copyImageToClipboard(pngBytes);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Etikett als Bild in die Zwischenablage kopiert!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Image copy error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Text kopiert (Bild-Copy fehlgeschlagen)')),
        );
      }
    }
  }

  Future<void> _downloadLabel() async {
    try {
      final boundary = _globalKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      
      if (byteData != null) {
        final Uint8List pngBytes = byteData.buffer.asUint8List();
        final fileName = 'hefe_etikett_${widget.entry.brand}_${widget.entry.strain}.png'
            .replaceAll(' ', '_')
            .toLowerCase();
            
        downloadBytes(pngBytes, fileName);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download gestartet: $fileName')),
          );
        }
      }
    } catch (e) {
      debugPrint('Download error: $e');
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final updatedGenerations = List<String>.from(widget.entry.zuchtGenerationen)..add(dateStr);
      
      final updatedEntry = widget.entry.copyWith(
        zuchtGenerationen: updatedGenerations,
      );

      await YeastBankService().saveEntry(updatedEntry);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Zuchtgeneration erfolgreich gespeichert.')),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final generation = widget.entry.zuchtGenerationen.length + 1;
    final dateDisplay = DateFormat('dd.MM.yyyy').format(_selectedDate);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hefe Etikette'),
        actions: [
          if (_isSaving)
            const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          else
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: _save,
              tooltip: 'Speichern & Neue Generation erfassen',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Label Preview Card
            Card(
              elevation: 4,
              color: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
              child: Stack(
                children: [
                  RepaintBoundary(
                    key: _globalKey,
                    child: SelectionArea(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        width: 300, // Tightest width to minimize white space
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: Colors.grey.shade300, width: 0.5),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // QR Code Section
                            Container(
                              width: 120, // Adjusted back to 120 for balance
                              height: 120,
                              color: Colors.white,
                              child: _urlCtrl.text.isNotEmpty
                                  ? QrImageView(
                                      data: _urlCtrl.text,
                                      version: QrVersions.auto,
                                      size: 120.0,
                                      gapless: false,
                                      padding: const EdgeInsets.all(2),
                                      eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: Colors.black),
                                      dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: Colors.black),
                                    )
                                  : const Center(child: Icon(Icons.qr_code_2, size: 70, color: Colors.grey)),
                            ),
                            const SizedBox(width: 8),
                            // Text Section
                            Expanded(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const SizedBox(height: 2),
                                  // 1. Zeile: Marke
                                  _LabelTextField(
                                    controller: _brandCtrl,
                                    hint: 'Marke',
                                    isBold: true,
                                    fontSize: 14,
                                  ),
                                  // 2. Zeile: Produkt ID
                                  _LabelTextField(
                                    controller: _productIdCtrl,
                                    hint: 'Produkt ID',
                                    fontSize: 13,
                                  ),
                                  // 3. Zeile: Stamm
                                  _LabelTextField(
                                    controller: _strainCtrl,
                                    hint: 'Stamm',
                                    fontSize: 13,
                                  ),
                                  // 4. Zeile: Temperatur
                                  _LabelTextField(
                                    controller: _tempRangeCtrl,
                                    hint: 'Temperatur',
                                    fontSize: 13,
                                  ),
                                  // 5. Zeile: Datum
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.calendar_today, size: 10, color: Colors.black87),
                                        const SizedBox(width: 4),
                                        InkWell(
                                          onTap: _selectDate,
                                          child: Text(
                                            dateDisplay,
                                            style: const TextStyle(fontSize: 13, color: Colors.black, fontFamily: 'monospace'),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  // 6. Zeile: Generation
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '$generation. Generation',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.black, fontFamily: 'monospace'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    right: 4,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.download, size: 18, color: Colors.blueGrey),
                          onPressed: _downloadLabel,
                          tooltip: 'Etikett herunterladen',
                        ),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: Colors.grey),
                          onPressed: _copyLabel,
                          tooltip: 'Etikett kopieren (Bild)',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            const Text(
              'Tipp: Klicke auf die Zeilen oben, um sie anzupassen.\nNur das Datum wird permanent als neue Generation in der DB gespeichert.',
              style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _LabelTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isBold;
  final double fontSize;
  
  const _LabelTextField({
    required this.controller, 
    required this.hint, 
    this.isBold = false,
    this.fontSize = 13,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: TextStyle(
        fontSize: fontSize,
        color: Colors.black,
        fontFamily: 'monospace',
        fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
      ),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 2),
        border: InputBorder.none,
        hintText: hint,
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: fontSize - 2),
        fillColor: Colors.transparent,
        filled: true,
      ),
    );
  }
}
