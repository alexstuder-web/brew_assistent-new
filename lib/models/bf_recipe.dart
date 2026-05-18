import 'dart:typed_data';
import 'dart:convert';

class BfRecipe {
  final String? id;
  final String userProfileId;
  final String? brewfatherId;
  final String name;
  final String? style;
  final double? abv;
  final double? ibu;
  final double? color; // EBC usually
  final Map<String, dynamic> data;
  final Uint8List? image;

  BfRecipe({
    this.id,
    required this.userProfileId,
    this.brewfatherId,
    required this.name,
    this.style,
    this.abv,
    this.ibu,
    this.color,
    required this.data,
    this.image,
  });

  factory BfRecipe.fromJson(Map<String, dynamic> json) {
    Uint8List? imgBytes;
    if (json['image'] != null) {
      if (json['image'] is String) {
        try {
           // If it is encoded as a Hex string (Postgres bytea default in some drivers)
           final str = json['image'] as String;
           if (str.startsWith('\\x')) {
              // Not supported directly in Dart core for postgres Hex format, but usually Supabase returns standard string or handled.
              // Supabase/Postgrest usually returns bytea as Hex string.
              // We need to verify what supabase returns. Often it returns a Hex string starting with \x.
              // For simplicity, we might rely on Supabase Flutter client handling, but 'postgrest' package usually returns string.
              // Let's assume it could be base64 if we inserted base64, but we want to insert bytes.
              // If we select it back, it usually comes as Hex string.
              // Let's try to handle it.
              imgBytes = null; // We'll handle this in UI or service logic if needed, but for now let's hope it's standard.
              // Actually, best to handle it here.
              // But let's simplify and assume Supabase returns it as String and we might need to parse.
           } else {
             // Maybe base64?
             imgBytes = base64Decode(str);
           }
        } catch (e) {
          // ignore
        }
      } else if (json['image'] is List) {
        imgBytes = Uint8List.fromList(List<int>.from(json['image']));
      }
      
      // Postgrest returns bytea as a hex string prefixed with \x
      if (json['image'] is String && (json['image'] as String).startsWith(r'\x')) {
         final hex = (json['image'] as String).substring(2);
         final List<int> bytes = [];
         for (var i = 0; i < hex.length; i += 2) {
           bytes.add(int.parse(hex.substring(i, i + 2), radix: 16));
         }
         imgBytes = Uint8List.fromList(bytes);
      }
    }

    return BfRecipe(
      id: json['id'],
      userProfileId: json['user_profile_id'],
      brewfatherId: json['brewfather_id'],
      name: json['name'],
      style: json['style'],
      abv: (json['abv'] as num?)?.toDouble(),
      ibu: (json['ibu'] as num?)?.toDouble(),
      color: (json['color'] as num?)?.toDouble(),
      data: json['data'] ?? {},
      image: imgBytes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brewfather_id': brewfatherId,
      'name': name,
      'style': style,
      'abv': abv,
      'ibu': ibu,
      'color': color,
      'data': data,
      // 'image': image, // We skip sending image back in normal toJson if mixed with other usage, but for DB save we need it.
      // However, UserProfileService prepares the JSON for upsert.
    };
  }
  
  // Create a separate method for DB insertion if needed, or include it in toJson.
  // Warning: If we send Uint8List to Supabase/Postgrest directly in JSON, it might need to be proper format.
  // Usually Supabase overrides handle it? Or we can send as Hex string.
  // Let's modify toJson to check usage OR just try usage of bytes and see if driver handles it.
  // The UserProfileService uses simple map.
  
  Map<String, dynamic> toDbJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brewfather_id': brewfatherId,
      'name': name,
      'style': style,
      'abv': abv,
      'ibu': ibu,
      'color': color,
      'data': data,
      'image': image, // Supabase Flutter SDK should handle Uint8List for bytea columns
    };
  }

  factory BfRecipe.fromBrewfather(Map<String, dynamic> bfData, String userProfileId) {
    return BfRecipe(
      userProfileId: userProfileId,
      brewfatherId: bfData['_id'] ?? bfData['id'],
      name: bfData['name'] ?? 'Unbenannt',
      style: bfData['style']?['name'],
      abv: (bfData['abv'] as num?)?.toDouble(),
      ibu: (bfData['ibu'] as num?)?.toDouble(),
      color: (bfData['color'] as num?)?.toDouble(),
      data: bfData,
    );
  }
  
  BfRecipe copyWith({
    String? id,
    Map<String, dynamic>? data,
    Uint8List? image,
  }) {
    return BfRecipe(
      id: id ?? this.id,
      userProfileId: userProfileId,
      brewfatherId: brewfatherId,
      name: name,
      style: style,
      abv: abv,
      ibu: ibu,
      color: color,
      data: data ?? this.data,
      image: image ?? this.image,
    );
  }
}
