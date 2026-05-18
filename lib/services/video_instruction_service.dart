import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/video_instruction.dart';

class VideoInstructionService {
  final _client = Supabase.instance.client;
  static const String _tableName = 'video_instructions';
  static const String _schemaName = 'aibrewgenius';

  Future<List<VideoInstruction>> fetchVideos(String profileId) async {
    try {
      final response = await _client
          .schema(_schemaName)
          .from(_tableName)
          .select()
          .eq('user_profile_id', profileId)
          .order('position', ascending: true);

      return (response as List).map((e) => VideoInstruction.fromJson(e)).toList();
    } catch (e) {
      // Return empty list if table doesn't exist yet
      return [];
    }
  }

  Future<VideoInstruction> saveVideo(VideoInstruction video) async {
    final data = video.toJson();
    if (video.id.isEmpty) data.remove('id');
    
    final response = await _client
        .schema(_schemaName)
        .from(_tableName)
        .upsert(data)
        .select()
        .single();
    
    return VideoInstruction.fromJson(response);
  }

  Future<void> deleteVideo(String id) async {
    await _client
        .schema(_schemaName)
        .from(_tableName)
        .delete()
        .eq('id', id);
  }
}
