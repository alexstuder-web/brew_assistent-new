class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.avatarBlob,
    required this.defaultBatchLiters,
    this.raptUserId,
    this.brewfatherUserId,
    this.brewfatherSyncEnabled = false,
    this.brewfatherConfigured = false,
    this.raptConfigured = false,
    this.language = 'de',
  });

  final String id;
  final String name;
  final String? avatarBlob;
  final double? defaultBatchLiters;
  final String? raptUserId;
  final String? brewfatherUserId;
  final bool brewfatherSyncEnabled;
  // Vault-Indikatoren (DB GENERATED columns): true wenn ein Secret in
  // vault.secrets existiert. Der eigentliche API-Key kommt nicht mehr per
  // user_profiles-Row, sondern via RPC (Proxy) bzw. ist überhaupt nicht
  // mehr im Browser sichtbar.
  final bool brewfatherConfigured;
  final bool raptConfigured;
  final String language;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_blob': avatarBlob,
        'default_batch_liters': defaultBatchLiters,
        'rapt_user_id': raptUserId,
        'brewfather_user_id': brewfatherUserId,
        'brewfather_sync_enabled': brewfatherSyncEnabled,
        'language': language,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? '',
        avatarBlob: json['avatar_blob'] as String?,
        defaultBatchLiters:
            (json['default_batch_liters'] as num?)?.toDouble(),
        raptUserId: json['rapt_user_id'] as String?,
        brewfatherUserId: json['brewfather_user_id'] as String?,
        brewfatherSyncEnabled: json['brewfather_sync_enabled'] as bool? ?? false,
        brewfatherConfigured: json['brewfather_configured'] as bool? ?? false,
        raptConfigured: json['rapt_configured'] as bool? ?? false,
        language: json['language'] as String? ?? 'de',
      );
}
