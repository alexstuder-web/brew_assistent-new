import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fining_agents.dart';

abstract class FiningAgentsRepository {
  Future<FiningAgents> fetchSettings(String userProfileId);
  Future<FiningAgents> saveSettings(FiningAgents settings);
}

class FiningAgentsService implements FiningAgentsRepository {
  FiningAgentsService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schema = 'aibrewgenius';
  static const String _table = 'fining_agents';

  SupabaseQueryBuilder _tableRef() =>
      _client.schema(_schema).from(_table);

  @override
  Future<FiningAgents> fetchSettings(String userProfileId) async {
    final data = await _tableRef()
        .select()
        .eq('user_profile_id', userProfileId)
        .maybeSingle();
    if (data == null) {
      return FiningAgents.empty(userProfileId);
    }
    final map = Map<String, dynamic>.from(data);
    return FiningAgents.fromJson(map);
  }

  @override
  Future<FiningAgents> saveSettings(FiningAgents settings) async {
    final data = await _tableRef()
        .upsert(settings.toJson())
        .select()
        .single();
    return FiningAgents.fromJson(data);
  }
}
