class BrewKettle {
  const BrewKettle({
    this.id,
    required this.userProfileId,
    required this.brand,
    this.model,
    this.isDefault = false,
    this.volumeLiters,
    this.postBoilLossLiters,
    this.boilOffPercentage,
    this.bhEfficiency = 70.0,
    this.hasCondenserHat = false,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userProfileId;
  final String brand;
  final String? model;
  final bool isDefault;
  final double? volumeLiters;
  final double? postBoilLossLiters;
  final double? boilOffPercentage;
  final double bhEfficiency;
  final bool hasCondenserHat;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  BrewKettle copyWith({
    String? id,
    String? userProfileId,
    String? brand,
    String? model,
    bool? isDefault,
    double? volumeLiters,
    double? postBoilLossLiters,
    double? boilOffPercentage,
    double? bhEfficiency,
    bool? hasCondenserHat,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BrewKettle(
      id: id ?? this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      isDefault: isDefault ?? this.isDefault,
      volumeLiters: volumeLiters ?? this.volumeLiters,
      postBoilLossLiters: postBoilLossLiters ?? this.postBoilLossLiters,
      boilOffPercentage: boilOffPercentage ?? this.boilOffPercentage,
      bhEfficiency: bhEfficiency ?? this.bhEfficiency,
      hasCondenserHat: hasCondenserHat ?? this.hasCondenserHat,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory BrewKettle.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    return BrewKettle(
      id: json['id'] as String?,
      userProfileId: json['user_profile_id'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String?,
      isDefault: (json['is_default'] as bool?) ?? false,
      volumeLiters: (json['volume_liters'] as num?)?.toDouble(),
      postBoilLossLiters: (json['post_boil_loss_liters'] as num?)?.toDouble(),
      boilOffPercentage: (json['boil_off_percentage'] as num?)?.toDouble(),
      bhEfficiency: (json['bh_efficiency'] as num?)?.toDouble() ?? 70.0,
      hasCondenserHat: (json['has_condenser_hat'] as bool?) ?? false,
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
      'model': model,
      'is_default': isDefault,
      'volume_liters': volumeLiters,
      'post_boil_loss_liters': postBoilLossLiters,
      'boil_off_percentage': boilOffPercentage,
      'bh_efficiency': bhEfficiency,
      'has_condenser_hat': hasCondenserHat,
      'notes': notes,
    };
  }
}
