import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'package:web/web.dart' as web;
import 'package:flutter/foundation.dart';

Future<void> copyImageToClipboard(Uint8List bytes) async {
  try {
    final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: 'image/png'));
    
    // Create a plain JS object and set the property using js_interop_unsafe
    // This is compatible with Wasm compilation
    final itemData = JSObject();
    itemData.setProperty('image/png'.toJS, blob);
    
    final clipboardItem = web.ClipboardItem(itemData);
    
    await web.window.navigator.clipboard.write([clipboardItem].toJS).toDart;
  } catch (e) {
    debugPrint('Web Clipboard Error: $e');
    rethrow;
  }
}
