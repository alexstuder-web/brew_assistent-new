import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/yeast_bank_entry.dart';

abstract class YeastBankRepository {
  Future<List<YeastBankEntry>> fetchEntries(String userProfileId);
  Future<YeastBankEntry> saveEntry(YeastBankEntry entry);
  Future<void> deleteEntry(String id);
}

class YeastBankService implements YeastBankRepository {
  YeastBankService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'yeast_bank_entries';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<YeastBankEntry>> fetchEntries(String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(YeastBankEntry.fromJson)
        .toList();
  }

  @override
  Future<YeastBankEntry> saveEntry(YeastBankEntry entry) async {
    final data = await _table().upsert(entry.toJson()).select().single();
    return YeastBankEntry.fromJson(data);
  }

  @override
  Future<void> deleteEntry(String id) async {
    await _table().delete().eq('id', id);
  }
}
