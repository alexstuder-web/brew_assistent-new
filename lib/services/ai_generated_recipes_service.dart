import 'package:supabase_flutter/supabase_flutter.dart';

abstract class AiGeneratedRecipesRepository {
  Future<List<Map<String, dynamic>>> fetchRecipes();
  Future<Map<String, dynamic>> fetchRecipeById(String id);
  Future<void> deleteRecipe(String id);
}

class AiGeneratedRecipesService implements AiGeneratedRecipesRepository {
  AiGeneratedRecipesService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _schemaName = 'aibrewgenius';
  static const String _tableName = 'ai_generated_recipes_v2';

  SupabaseQueryBuilder _table() =>
      _client.schema(_schemaName).from(_tableName);

  @override
  Future<List<Map<String, dynamic>>> fetchRecipes() async {
    final result = await _table()
        .select('id, basis_bier, bier_typ, created_at')
        .order('created_at', ascending: false);
    return List<Map<String, dynamic>>.from(result);
  }

  @override
  Future<Map<String, dynamic>> fetchRecipeById(String id) async {
    return await _table().select().eq('id', id).single();
  }

  @override
  Future<void> deleteRecipe(String id) async {
    await _table().delete().eq('id', id);
  }
}
