import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/packaging_profile.dart';

abstract class PackagingProfileRepository {
  Future<List<PackagingProfile>> fetchProfiles(String userProfileId);
  Future<PackagingProfile> saveProfile(PackagingProfile profile);
  Future<void> deleteProfile(String id);
}

class PackagingProfileService implements PackagingProfileRepository {
  PackagingProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'packaging_profiles';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<PackagingProfile>> fetchProfiles(String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('is_default', ascending: false)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(PackagingProfile.fromJson)
        .toList();
  }

  @override
  Future<PackagingProfile> saveProfile(PackagingProfile profile) async {
    if (profile.isDefault) {
      await _table()
          .update({'is_default': false})
          .eq('user_profile_id', profile.userProfileId);
    }
    final data = await _table().upsert(profile.toJson()).select().single();
    return PackagingProfile.fromJson(data);
  }

  @override
  Future<void> deleteProfile(String id) async {
    await _table().delete().eq('id', id);
  }
}
