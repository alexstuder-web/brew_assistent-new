import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fermenter_controller.dart';

abstract class FermenterControllerRepository {
  Future<List<FermenterControllerModel>> fetchControllers(String userProfileId);
  Future<FermenterControllerModel> saveController(FermenterControllerModel controller);
  Future<void> deleteController(String id);
}

class FermenterControllerService implements FermenterControllerRepository {
  FermenterControllerService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;
  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'fermenter_controllers';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<FermenterControllerModel>> fetchControllers(
      String userProfileId) async {
    final data = await _table()
        .select()
        .eq('user_profile_id', userProfileId)
        .order('is_default', ascending: false)
        .order('created_at');
    return data
        .cast<Map<String, dynamic>>()
        .map(FermenterControllerModel.fromJson)
        .toList();
  }

  @override
  Future<FermenterControllerModel> saveController(
      FermenterControllerModel controller) async {
    if (controller.isDefault) {
      await _table()
          .update({'is_default': false})
          .eq('user_profile_id', controller.userProfileId);
    }
    final data = await _table().upsert(controller.toJson()).select().single();
    return FermenterControllerModel.fromJson(data);
  }

  @override
  Future<void> deleteController(String id) async {
    await _table().delete().eq('id', id);
  }
}
