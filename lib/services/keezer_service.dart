import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/keezer_config.dart';

class KeezerService {
  final _client = Supabase.instance.client;

  Future<KeezerConfig?> fetchConfig(String profileId) async {
    try {
      final response = await _client
          .schema('aibrewgenius')
          .from('keezer_configs')
          .select()
          .eq('user_profile_id', profileId)
          .maybeSingle();

      if (response == null) return null;
      return KeezerConfig.fromJson(response);
    } catch (e) {
      // If table doesn't exist yet or other error, we'll return null to trigger configuration
      return null;
    }
  }

  Future<KeezerConfig> saveConfig(KeezerConfig config) async {
    final data = config.toJson();
    final response = await _client
        .schema('aibrewgenius')
        .from('keezer_configs')
        .upsert(data)
        .select()
        .single();
    return KeezerConfig.fromJson(response);
  }
}
