import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/malt_depot_entry.dart';

abstract class MaltDepotRepository {
  Future<List<MaltDepotEntryModel>> fetchEntries(String userProfileId);
  Future<MaltDepotEntryModel> saveEntry(MaltDepotEntryModel entry);
  Future<void> deleteEntry(String id);
}

class MaltDepotService implements MaltDepotRepository {
  MaltDepotService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'malt_depots';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<MaltDepotEntryModel>> fetchEntries(String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(MaltDepotEntryModel.fromJson)
        .toList();
  }

  @override
  Future<MaltDepotEntryModel> saveEntry(MaltDepotEntryModel entry) async {
    final data = await _table().upsert(entry.toJson()).select().single();
    return MaltDepotEntryModel.fromJson(data);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _table().delete().eq('id', id);
  }
}
