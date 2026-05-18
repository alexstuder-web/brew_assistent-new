import 'dart:js_interop';
import 'dart:typed_data';
import 'package:web/web.dart' as web;

void downloadBytes(Uint8List bytes, String fileName, {String mimeType = 'application/octet-stream'}) {
  final blob = web.Blob([bytes.toJS].toJS, web.BlobPropertyBag(type: mimeType));
  final url = web.URL.createObjectURL(blob);
  
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement;
  anchor.href = url;
  anchor.download = fileName;
  anchor.click();
  
  // Revoke after a short delay to ensure click processing finishes in some browsers
  web.window.setTimeout(() {
    web.URL.revokeObjectURL(url);
  }.toJS, 100.toJS);
}
