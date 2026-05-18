class UserProfile {
  const UserProfile({
    required this.id,
    required this.name,
    this.avatarBlob,
    required this.defaultBatchLiters,
    this.raptUserId,
    this.raptApiKey,
    this.brewfatherUserId,
    this.brewfatherApiKey,
    this.brewfatherSyncEnabled = false,
    this.language = 'de',
  });

  final String id;
  final String name;
  final String? avatarBlob;
  final double? defaultBatchLiters;
  final String? raptUserId;
  final String? raptApiKey;
  final String? brewfatherUserId;
  final String? brewfatherApiKey;
  final bool brewfatherSyncEnabled;
  final String language;

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar_blob': avatarBlob,
        'default_batch_liters': defaultBatchLiters,
        'rapt_user_id': raptUserId,
        'rapt_api_key': raptApiKey,
        'brewfather_user_id': brewfatherUserId,
        'brewfather_api_key': brewfatherApiKey,
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
        raptApiKey: json['rapt_api_key'] as String?,
        brewfatherUserId: json['brewfather_user_id'] as String?,
        brewfatherApiKey: json['brewfather_api_key'] as String?,
        brewfatherSyncEnabled: json['brewfather_sync_enabled'] as bool? ?? false,
        language: json['language'] as String? ?? 'de',
      );
}

