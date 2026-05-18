class PackagingProfile {
  const PackagingProfile({
    this.id,
    required this.userProfileId,
    required this.name,
    this.targetVolume,
    this.bottleEnabled = false,
    this.bottleCarbonationTempC,
    this.bottleStorageTempC,
    this.kegEnabled = false,
    this.kegCarbonationTempC,
    this.kegStorageTempC,
    this.kegVolumeLiters,
    this.hasCo2 = true,
    this.hasNitro = false,
    this.isDefault = false,
    this.createdAt,
    this.updatedAt,
  });

  final String? id;
  final String userProfileId;
  final String name;
  final double? targetVolume;
  final bool bottleEnabled;
  final double? bottleCarbonationTempC;
  final double? bottleStorageTempC;
  final bool kegEnabled;
  final double? kegCarbonationTempC;
  final double? kegStorageTempC;
  final double? kegVolumeLiters;
  final bool hasCo2;
  final bool hasNitro;
  final bool isDefault;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  PackagingProfile copyWith({
    String? id,
    String? userProfileId,
    String? name,
    double? targetVolume,
    bool? bottleEnabled,
    double? bottleCarbonationTempC,
    double? bottleStorageTempC,
    bool? kegEnabled,
    double? kegCarbonationTempC,
    double? kegStorageTempC,
    double? kegVolumeLiters,
    bool? hasCo2,
    bool? hasNitro,
    bool? isDefault,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PackagingProfile(
      id: id ?? this.id,
      userProfileId: userProfileId ?? this.userProfileId,
      name: name ?? this.name,
      targetVolume: targetVolume ?? this.targetVolume,
      bottleEnabled: bottleEnabled ?? this.bottleEnabled,
      bottleCarbonationTempC:
          bottleCarbonationTempC ?? this.bottleCarbonationTempC,
      bottleStorageTempC: bottleStorageTempC ?? this.bottleStorageTempC,
      kegEnabled: kegEnabled ?? this.kegEnabled,
      kegCarbonationTempC: kegCarbonationTempC ?? this.kegCarbonationTempC,
      kegStorageTempC: kegStorageTempC ?? this.kegStorageTempC,
      kegVolumeLiters: kegVolumeLiters ?? this.kegVolumeLiters,
      hasCo2: hasCo2 ?? this.hasCo2,
      hasNitro: hasNitro ?? this.hasNitro,
      isDefault: isDefault ?? this.isDefault,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory PackagingProfile.fromJson(Map<String, dynamic> json) {
    DateTime? parse(String? value) =>
        value == null ? null : DateTime.tryParse(value);
    return PackagingProfile(
      id: json['id'] as String?,
      userProfileId: json['user_profile_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      targetVolume: (json['target_volume'] as num?)?.toDouble(),
      bottleEnabled: (json['bottle_enabled'] as bool?) ?? false,
      bottleCarbonationTempC:
          (json['bottle_carbonation_temp_c'] as num?)?.toDouble(),
      bottleStorageTempC:
          (json['bottle_storage_temp_c'] as num?)?.toDouble(),
      kegEnabled: (json['keg_enabled'] as bool?) ?? false,
      kegCarbonationTempC:
          (json['keg_carbonation_temp_c'] as num?)?.toDouble(),
      kegStorageTempC: (json['keg_storage_temp_c'] as num?)?.toDouble(),
      kegVolumeLiters: (json['keg_volume_l'] as num?)?.toDouble(),
      hasCo2: (json['has_co2'] as bool?) ?? true,
      hasNitro: (json['has_nitro'] as bool?) ?? false,
      isDefault: (json['is_default'] as bool?) ?? false,
      createdAt: parse(json['created_at'] as String?),
      updatedAt: parse(json['updated_at'] as String?),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'user_profile_id': userProfileId,
      'name': name,
      if (targetVolume != null) 'target_volume': targetVolume,
      'bottle_enabled': bottleEnabled,
      'bottle_carbonation_temp_c': bottleCarbonationTempC,
      'bottle_storage_temp_c': bottleStorageTempC,
      'keg_enabled': kegEnabled,
      'keg_carbonation_temp_c': kegCarbonationTempC,
      'keg_storage_temp_c': kegStorageTempC,
      'keg_volume_l': kegVolumeLiters,
      'has_co2': hasCo2,
      'has_nitro': hasNitro,
      'is_default': isDefault,
    };
  }
}
