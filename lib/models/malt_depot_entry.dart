class MaltDepotEntryModel {
  const MaltDepotEntryModel({
    this.id,
    required this.userProfileId,
    required this.name,
    this.url,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userProfileId;
  final String name;
  final String? url;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  MaltDepotEntryModel copyWith({
    String? id,
    String? userProfileId,
    String? name,
    String? url,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return MaltDepotEntryModel(
      id: id ?? this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory MaltDepotEntryModel.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    return MaltDepotEntryModel(
      id: json['id'] as String?,
      userProfileId: json['user_profile_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      url: json['url'] as String?,
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
      'url': url,
      'notes': notes,
    };
  }
}
