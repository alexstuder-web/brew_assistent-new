import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/brew_kettle.dart';

abstract class BrewKettleRepository {
  Future<List<BrewKettle>> fetchKettles(String userProfileId);
  Future<BrewKettle> saveKettle(BrewKettle kettle);
  Future<void> deleteKettle(String id);
}

class BrewKettleService implements BrewKettleRepository {
  BrewKettleService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'brew_kettles';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<BrewKettle>> fetchKettles(String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('is_default', ascending: false)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(BrewKettle.fromJson)
        .toList();
  }

  @override
  Future<BrewKettle> saveKettle(BrewKettle kettle) async {
    if (kettle.isDefault) {
      await _table()
          .update({'is_default': false})
          .eq('user_profile_id', kettle.userProfileId);
    }
    final data = await _table().upsert(kettle.toJson()).select().single();
    return BrewKettle.fromJson(data);
  }

  @override
  Future<void> deleteKettle(String id) async {
    await _table().delete().eq('id', id);
  }
}
