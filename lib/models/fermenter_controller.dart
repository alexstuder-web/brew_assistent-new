class FermenterControllerModel {
  const FermenterControllerModel({
    this.id,
    required this.userProfileId,
    required this.name,
    this.isDefault = false,
    this.username,
    this.apiKey,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userProfileId;
  final String name;
  final bool isDefault;
  final String? username;
  final String? apiKey;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  FermenterControllerModel copyWith({
    String? id,
    String? userProfileId,
    String? name,
    bool? isDefault,
    String? username,
    String? apiKey,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FermenterControllerModel(
      id: id ?? this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      username: username ?? this.username,
      apiKey: apiKey ?? this.apiKey,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FermenterControllerModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    return FermenterControllerModel(
      id: json['id'] as String?,
      userProfileId: json['user_profile_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
      username: json['username'] as String?,
      apiKey: json['api_key'] as String?,
      notes: json['notes'] as String?,
      createdAt: parse(json['created_at'] as String?),
      updatedAt: parse(json['updated_at'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'name': name,
      'is_default': isDefault,
      'username': username,
      'api_key': apiKey,
      'notes': notes,
    };
  }
}
