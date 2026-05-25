import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/bf_recipe.dart';
import '../models/bf_batch.dart';
import '../models/misc.dart';
import '../models/hop.dart';
import '../models/fermentable.dart';
import '../models/user_profile.dart';

abstract class UserProfileRepository {
  Future<void> saveProfile(UserProfile profile);
  Future<UserProfile?> fetchProfile(String id);
  Future<UserProfile?> fetchDefaultProfile({bool refresh = false});
  
  // Fermentables
  Future<List<Fermentable>> getFermentables(String userProfileId);
  Future<void> saveFermentables(List<Fermentable> fermentables);
  Future<void> saveFermentable(Fermentable fermentable);
  Future<void> deleteFermentable(String id);

  // Hops
  Future<List<Hop>> getHops(String userProfileId);
  Future<void> saveHops(List<Hop> hops);
  Future<void> saveHop(Hop hop);

  // Miscs
  Future<List<Misc>> getMiscs(String userProfileId);
  Future<void> saveMiscs(List<Misc> miscs);
  Future<void> saveMisc(Misc misc);

  // Recipes
  Future<List<BfRecipe>> getRecipes(String userProfileId);
  Future<void> saveRecipes(List<BfRecipe> recipes);

  // Batches
  Future<List<BfBatch>> getBatches(String userProfileId);
  Future<void> saveBatches(List<BfBatch> batches, {bool syncDeletions = false});
}

class UserProfileService implements UserProfileRepository {
  UserProfileService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _tableName = 'user_profiles';
  static const String _schemaName = 'aibrewgenius';

  /// UUID des aktuell eingeloggten Users. Wirft, wenn keine Session existiert.
  /// AuthGate stellt sicher, dass innerhalb der App immer ein User da ist.
  static String get currentUserId {
    final id = Supabase.instance.client.auth.currentUser?.id;
    if (id == null) {
      throw StateError('Kein eingeloggter User — currentUserId nicht verfügbar.');
    }
    return id;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _table().upsert(profile.toJson(), onConflict: 'id');
  }

  @override
  Future<UserProfile?> fetchProfile(String id) async {
    final data = await _table().select().eq('id', id).maybeSingle();
    if (data == null) return null;
    return UserProfile.fromJson(data);
  }

  @override
  Future<UserProfile?> fetchDefaultProfile({bool refresh = false}) =>
      fetchProfile(currentUserId);

  /// Setzt oder löscht den Brewfather-API-Key über die Vault-RPC.
  /// [apiKey] null oder leer -> Secret wird gelöscht, `brewfather_configured` -> false.
  Future<void> setBrewfatherApiKey(String? apiKey) async {
    await _client
        .schema(_schemaName)
        .rpc('set_my_brewfather_creds', params: {'p_api_key': apiKey});
  }

  @override
  Future<List<Fermentable>> getFermentables(String userProfileId) =>
      _getItems(_tableFermentables(), userProfileId, Fermentable.fromJson);

  @override
  Future<void> saveFermentables(List<Fermentable> items) =>
      _upsertItems(_tableFermentables(), items, (i) => i.toJson());

  @override
  Future<void> saveFermentable(Fermentable item) =>
      _saveItem(_tableFermentables(), item, (i) => i.toJson());

  @override
  Future<void> deleteFermentable(String id) => _deleteItem(_tableFermentables(), id);

  @override
  Future<List<Hop>> getHops(String userProfileId) =>
      _getItems(_tableHops(), userProfileId, Hop.fromJson);

  @override
  Future<void> saveHops(List<Hop> items) => _upsertItems(_tableHops(), items, (i) => i.toJson());

  @override
  Future<void> saveHop(Hop item) => _saveItem(_tableHops(), item, (i) => i.toJson());

  Future<void> deleteHop(String id) => _deleteItem(_tableHops(), id);

  @override
  Future<List<Misc>> getMiscs(String userProfileId) =>
      _getItems(_tableMiscs(), userProfileId, Misc.fromJson);

  @override
  Future<void> saveMiscs(List<Misc> items) => _upsertItems(_tableMiscs(), items, (i) => i.toJson());

  @override
  Future<void> saveMisc(Misc item) => _saveItem(_tableMiscs(), item, (i) => i.toJson());

  Future<void> deleteMisc(String id) => _deleteItem(_tableMiscs(), id);

  @override
  Future<List<BfRecipe>> getRecipes(String userProfileId) =>
      _getItems(_tableRecipes(), userProfileId, BfRecipe.fromJson);

  @override
  Future<void> saveRecipes(List<BfRecipe> items) =>
      _upsertItems(_tableRecipes(), items, (i) => i.toDbJson());

  Future<void> saveRecipe(BfRecipe item) =>
      _saveItem(_tableRecipes(), item, (i) => i.toDbJson(), onConflict: 'user_profile_id, brewfather_id');

  @override
  Future<List<BfBatch>> getBatches(String userProfileId) =>
      _getItems(_tableBatches(), userProfileId, BfBatch.fromJson);

  @override
  Future<void> saveBatches(List<BfBatch> batches, {bool syncDeletions = false}) async {
    if (batches.isEmpty && !syncDeletions) return;

    if (batches.isEmpty && syncDeletions) return;

    final userProfileId = batches.first.userProfileId;
    final existingData = await _tableBatches()
        .select('brewfather_id, rapt_data, analysis_data, data, id')
        .eq('user_profile_id', userProfileId);
    
    final Map<String, Map<String, dynamic>> existingMap = {
      for (var item in existingData) 
         if (item['brewfather_id'] != null) item['brewfather_id'] as String : item
    };

    final Map<String, Map<String, dynamic>> dataToUpsert = {};
    final Set<String> incomingBfIds = {};

    for (var batch in batches) {
       var json = batch.toJson();
       json.remove('id');

       final bfId = batch.brewfatherId;
       if (bfId != null) {
          incomingBfIds.add(bfId);
          if (existingMap.containsKey(bfId)) {
             final existing = existingMap[bfId]!;
             
             final incomingRapt = json['rapt_data'] as Map<String, dynamic>? ?? {};
             final existingRapt = existing['rapt_data'] as Map<String, dynamic>? ?? {};
             if (incomingRapt.isEmpty && existingRapt.isNotEmpty) {
                json['rapt_data'] = existingRapt;
             }

             final incomingAnalysis = json['analysis_data'] as Map<String, dynamic>? ?? {};
             final existingAnalysis = existing['analysis_data'] as Map<String, dynamic>? ?? {};
             if (incomingAnalysis.isEmpty && existingAnalysis.isNotEmpty) {
                json['analysis_data'] = existingAnalysis;
             }
          }
          dataToUpsert[bfId] = json;
       }
    }

    if (syncDeletions) {
       final List<String> idsToDelete = [
         for (var bfId in existingMap.keys) if (!incomingBfIds.contains(bfId)) bfId
       ];
       
       if (idsToDelete.isNotEmpty) {
          await _tableBatches()
              .delete()
              .eq('user_profile_id', userProfileId)
              .filter('brewfather_id', 'in', idsToDelete);
       }
    }

    if (dataToUpsert.isNotEmpty) {
       await _tableBatches().upsert(dataToUpsert.values.toList(), onConflict: 'user_profile_id, brewfather_id');
    }
  }

  // Generic Helpers
  Future<List<T>> _getItems<T>(
    SupabaseQueryBuilder table,
    String userProfileId,
    T Function(Map<String, dynamic>) fromJson,
  ) async {
    final data = await table.select().eq('user_profile_id', userProfileId);
    return (data as List).map((e) => fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> _upsertItems<T>(
    SupabaseQueryBuilder table,
    List<T> items,
    Map<String, dynamic> Function(T) toJson,
  ) async {
    if (items.isEmpty) return;
    final data = items.map((e) {
      final json = toJson(e);
      if (json['id'] == null) json.remove('id');
      return json;
    }).toList();
    await table.upsert(data, onConflict: 'user_profile_id, brewfather_id');
  }

  Future<void> _saveItem<T>(
    SupabaseQueryBuilder table,
    T item,
    Map<String, dynamic> Function(T) toJson, {
    String? onConflict,
  }) async {
    final json = toJson(item);
    if (json['id'] == null) json.remove('id');

    if (json['id'] != null) {
      await table.upsert(json, onConflict: onConflict);
    } else {
      await table.insert(json);
    }
  }

  Future<void> _deleteItem(SupabaseQueryBuilder table, String id) async {
    await table.delete().eq('id', id);
  }

  SupabaseQueryBuilder _table() => _client.schema(_schemaName).from(_tableName);
  SupabaseQueryBuilder _tableFermentables() => _client.schema(_schemaName).from('fermentables');
  SupabaseQueryBuilder _tableHops() => _client.schema(_schemaName).from('hops');
  SupabaseQueryBuilder _tableMiscs() => _client.schema(_schemaName).from('miscs');
  SupabaseQueryBuilder _tableRecipes() => _client.schema(_schemaName).from('recipes');
  SupabaseQueryBuilder _tableBatches() => _client.schema(_schemaName).from('batches');
}
