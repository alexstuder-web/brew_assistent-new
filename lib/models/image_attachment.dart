import 'dart:convert';
import 'dart:typed_data';

class ImageAttachment {
  const ImageAttachment({
    required this.bytes,
    required this.mimeType,
    this.fileName,
  });

  final Uint8List bytes;
  final String mimeType;
  final String? fileName;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'data': base64Encode(bytes),
        'mime_type': mimeType,
        if (fileName != null) 'file_name': fileName,
      };
}
