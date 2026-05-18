import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/water_profile.dart';

abstract class WaterProfileRepository {
  Future<List<WaterProfile>> fetchProfiles(String userProfileId);
  Future<WaterProfile> saveProfile(WaterProfile profile);
  Future<void> deleteProfile(String id);
}

class WaterProfileService implements WaterProfileRepository {
  WaterProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'water_profiles';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<WaterProfile>> fetchProfiles(String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('is_default', ascending: false)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(WaterProfile.fromJson)
        .toList();
  }

  @override
  Future<WaterProfile> saveProfile(WaterProfile profile) async {
    if (profile.isDefault) {
      await _table()
          .update({'is_default': false})
          .eq('user_profile_id', profile.userProfileId);
    }
    final payload = profile.toJson();
    final data = await _table().upsert(payload).select().single();
    return WaterProfile.fromJson(data);
  }

  @override
  Future<void> deleteProfile(String id) async {
    await _table().delete().eq('id', id);
  }
}
