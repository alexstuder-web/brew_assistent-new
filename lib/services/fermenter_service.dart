import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fermenter.dart';

abstract class FermenterRepository {
  Future<List<Fermenter>> fetchFermenters(String userProfileId);
  Future<Fermenter> saveFermenter(Fermenter fermenter);
  Future<void> deleteFermenter(String id);
}

class FermenterService implements FermenterRepository {
  FermenterService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'fermenters';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<Fermenter>> fetchFermenters(String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('is_default', ascending: false)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(Fermenter.fromJson)
        .toList();
  }

  @override
  Future<Fermenter> saveFermenter(Fermenter fermenter) async {
    if (fermenter.isDefault) {
      await _table()
          .update({'is_default': false})
          .eq('user_profile_id', fermenter.userProfileId);
    }
    final data = await _table().upsert(fermenter.toJson()).select().single();
    return Fermenter.fromJson(data);
  }

  @override
  Future<void> deleteFermenter(String id) async {
    await _table().delete().eq('id', id);
  }
}
