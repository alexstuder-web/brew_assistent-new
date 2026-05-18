import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/how_to_topic.dart';

class HowToService {
  final _client = Supabase.instance.client;

  Future<List<HowToTopic>> loadTopics(String profileId) async {
    final response = await _client
        .schema('aibrewgenius')
        .from('how_to_topics')
        .select()
        .eq('user_profile_id', profileId)
        .order('position', ascending: true);

    return (response as List).map((json) => HowToTopic.fromJson(json)).toList();
  }

  Future<HowToTopic> saveTopic(HowToTopic topic) async {
    final data = topic.toJson();
    final response = await _client
        .schema('aibrewgenius')
        .from('how_to_topics')
        .upsert(data)
        .select()
        .single();
    return HowToTopic.fromJson(response);
  }

  Future<void> deleteTopic(String id) async {
    await _client.schema('aibrewgenius').from('how_to_topics').delete().eq('id', id);
  }

  Future<void> updatePositions(List<HowToTopic> topics) async {
    // Basic bulk update: in a real production app maybe use a RPC call for efficiency
    // but for small lists this is fine.
    for (int i = 0; i < topics.length; i++) {
        final updated = topics[i].copyWith(position: i);
        if (updated.position != topics[i].position) {
             await saveTopic(updated);
        }
    }
  }
}
