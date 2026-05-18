class Fermenter {
  const Fermenter({
    this.id,
    required this.userProfileId,
    required this.brand,
    this.type,
    this.isDefault = false,
    this.volumeLiters,
    this.hasHeating = false,
    this.hasCooling = false,
    this.hasDryHoppingPort = false,
    this.canPressurize = false,
    this.fermentationLossLiters,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userProfileId;
  final String brand;
  final String? type;
  final bool isDefault;
  final double? volumeLiters;
  final bool hasHeating;
  final bool hasCooling;
  final bool hasDryHoppingPort;
  final bool canPressurize;
  final double? fermentationLossLiters;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Fermenter copyWith({
    String? id,
    String? userProfileId,
    String? brand,
    String? type,
    bool? isDefault,
    double? volumeLiters,
    bool? hasHeating,
    bool? hasCooling,
    bool? hasDryHoppingPort,
    bool? canPressurize,
    double? fermentationLossLiters,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Fermenter(
      id: id ?? this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      brand: brand ?? this.brand,
      type: type ?? this.type,
      isDefault: isDefault ?? this.isDefault,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      hasHeating: hasHeating ?? this.hasHeating,
      hasCooling: hasCooling ?? this.hasCooling,
      hasDryHoppingPort: hasDryHoppingPort ?? this.hasDryHoppingPort,
      canPressurize: canPressurize ?? this.canPressurize,
      fermentationLossLiters:
          fermentationLossLiters ?? this.fermentationLossLiters,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Fermenter.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    return Fermenter(
      id: json['id'] as String?,
      userProfileId: json['user_profile_id'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      type: json['type'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
      volumeLiters: (json['volume_liters'] as num?)?.toDouble(),
      hasHeating: (json['has_heating'] as bool?) ?? false,
      hasCooling: (json['has_cooling'] as bool?) ?? false,
      hasDryHoppingPort: (json['has_dry_hopping_port'] as bool?) ?? false,
      canPressurize: (json['can_pressurize'] as bool?) ?? false,
      fermentationLossLiters:
          (json['fermentation_loss_liters'] as num?)?.toDouble(),
      notes: json['notes'] as String?,
      createdAt: parseDate(json['created_at'] as String?),
      updatedAt: parseDate(json['updated_at'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'brand': brand,
      'type': type,
      'is_default': isDefault,
      'volume_liters': volumeLiters,
      'has_heating': hasHeating,
      'has_cooling': hasCooling,
      'has_dry_hopping_port': hasDryHoppingPort,
      'can_pressurize': canPressurize,
      'fermentation_loss_liters': fermentationLossLiters,
      'notes': notes,
    };
  }
}
