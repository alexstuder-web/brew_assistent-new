class WaterProfile {
  const WaterProfile({
    this.id,
    required this.userProfileId,
    required this.name,
    this.isDefault = false,
    this.ph,
    this.calciumPpm = 0,
    this.magnesiumPpm = 0,
    this.sodiumPpm = 0,
    this.chloridePpm = 0,
    this.sulfatePpm = 0,
    this.bicarbonatePpm = 0,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userProfileId;
  final String name;
  final bool isDefault;
  final double? ph;
  final double calciumPpm;
  final double magnesiumPpm;
  final double sodiumPpm;
  final double chloridePpm;
  final double sulfatePpm;
  final double bicarbonatePpm;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  WaterProfile copyWith({
    String? id,
    String? userProfileId,
    String? name,
    bool? isDefault,
    double? ph,
    double? calciumPpm,
    double? magnesiumPpm,
    double? sodiumPpm,
    double? chloridePpm,
    double? sulfatePpm,
    double? bicarbonatePpm,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WaterProfile(
      id: id ?? this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      isDefault: isDefault ?? this.isDefault,
      ph: ph ?? this.ph,
      calciumPpm: calciumPpm ?? this.calciumPpm,
      magnesiumPpm: magnesiumPpm ?? this.magnesiumPpm,
      sodiumPpm: sodiumPpm ?? this.sodiumPpm,
      chloridePpm: chloridePpm ?? this.chloridePpm,
      sulfatePpm: sulfatePpm ?? this.sulfatePpm,
      bicarbonatePpm: bicarbonatePpm ?? this.bicarbonatePpm,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'name': name,
      'is_default': isDefault,
      'ph': ph,
      'calcium_ppm': calciumPpm,
      'magnesium_ppm': magnesiumPpm,
      'sodium_ppm': sodiumPpm,
      'chloride_ppm': chloridePpm,
      'sulfate_ppm': sulfatePpm,
      'bicarbonate_ppm': bicarbonatePpm,
    };
  }

  factory WaterProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);

    return WaterProfile(
      id: json['id'] as String?,
      userProfileId: json['user_profile_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      isDefault: (json['is_default'] as bool?) ?? false,
      ph: (json['ph'] as num?)?.toDouble(),
      calciumPpm: (json['calcium_ppm'] as num?)?.toDouble() ?? 0,
      magnesiumPpm: (json['magnesium_ppm'] as num?)?.toDouble() ?? 0,
      sodiumPpm: (json['sodium_ppm'] as num?)?.toDouble() ?? 0,
      chloridePpm: (json['chloride_ppm'] as num?)?.toDouble() ?? 0,
      sulfatePpm: (json['sulfate_ppm'] as num?)?.toDouble() ?? 0,
      bicarbonatePpm: (json['bicarbonate_ppm'] as num?)?.toDouble() ?? 0,
      createdAt: parseDate(json['created_at'] as String?),
      updatedAt: parseDate(json['updated_at'] as String?),
    );
  }
}
