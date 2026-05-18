import 'dart:async';
import 'dart:js_interop';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

Future<String?> processPhoto(Uint8List bytes) async {
  try {
    final blob = web.Blob([bytes.toJS].toJS);
    final url = web.URL.createObjectURL(blob);
    
    final imgElement = web.HTMLImageElement();
    final completer = Completer<void>();
    
    imgElement.onload = (web.Event e) {
      completer.complete();
    }.toJS;
    
    imgElement.onerror = (web.Event e, [JSAny? a, JSAny? b, JSAny? c, JSAny? d]) {
      completer.completeError('Fehler beim Laden');
    }.toJS;
    
    imgElement.src = url;
    
    await completer.future;

    // Calculate new size
    int width = imgElement.naturalWidth;
    int height = imgElement.naturalHeight;
    const int maxDim = 800;
    
    if (width > maxDim || height > maxDim) {
      if (width >= height) {
        height = (height * maxDim / width).round();
        width = maxDim;
      } else {
        width = (width * maxDim / height).round();
        height = maxDim;
      }
    }

    final canvas = web.document.createElement('canvas') as web.HTMLCanvasElement;
    canvas.width = width;
    canvas.height = height;
    
    final ctx = canvas.getContext('2d') as web.CanvasRenderingContext2D;
    ctx.drawImage(imgElement, 0, 0, width, height);
    
    final dataUrl = canvas.toDataURL('image/jpeg', 0.8.toJS);
    web.URL.revokeObjectURL(url);
    
    return dataUrl;
  } catch (e) {
    debugPrint('Web-processing error: $e');
    return null;
  }
}
