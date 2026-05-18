import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:convert';

Future<String?> processPhoto(Uint8List bytes) async {
  // Desktop/Mobile implementation using the 'image' package
  final image = img.decodeImage(bytes);
  if (image == null) return null;

  img.Image resized = image;
  if (image.width > 1024 || image.height > 1024) {
    resized = img.copyResize(
      image,
      width: image.width >= image.height ? 1024 : null,
      height: image.height > image.width ? 1024 : null,
    );
  }

  final jpgBytes = img.encodeJpg(resized, quality: 75);
  return 'data:image/jpeg;base64,${base64Encode(jpgBytes)}';
}
