import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/env_config.dart';

/// Brewfather-Calls laufen über den brew-proxy.
/// Auth: Supabase-JWT als Bearer; der Proxy liest die User-Brewfather-Creds
/// RLS-geschützt aus user_profiles und macht den eigentlichen Basic-Auth-Call.
/// Die Brewfather-Credentials verlassen den Server nie Richtung Browser.
class BrewfatherService {
  BrewfatherService();

  String get _baseUrl => '${EnvConfig.proxyUrl()}/brewfather';

  Map<String, String> _headers({String contentType = 'application/json'}) {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError('Kein eingeloggter User — Brewfather-Call nicht möglich.');
    }
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': contentType,
      'Accept': 'application/json',
    };
  }

  Future<List<dynamic>> getRecipes() async {
    final uri = Uri.parse('$_baseUrl/recipes?complete=true&limit=50');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Fehler beim Laden der Rezepte: ${response.statusCode} ${response.body}');
  }

  Future<List<dynamic>> getBatches() async {
    final uri = Uri.parse('$_baseUrl/batches?complete=true&limit=20');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 429) {
      throw Exception('Brewfather Rate-Limit erreicht — bitte in ~1 min nochmal versuchen.');
    }
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Laden der Batches: ${response.statusCode} ${response.body}');
    }
    var batches = jsonDecode(response.body) as List<dynamic>;

    // Detail-Fetches pro Batch — die List-Endpoints sind summary-only.
    batches = await Future.wait(batches.map((batch) async {
      final id = batch['_id'] ?? batch['id'];
      if (id == null) return batch;
      final detailUri = Uri.parse('$_baseUrl/batches/$id');
      final detailRes = await http.get(detailUri, headers: _headers());
      if (detailRes.statusCode == 429) {
        throw Exception('Brewfather Rate-Limit erreicht — bitte in ~1 min nochmal versuchen.');
      }
      if (detailRes.statusCode == 200) {
        return jsonDecode(detailRes.body);
      }
      return batch;
    }));

    return batches;
  }

  Future<List<dynamic>> getFermentables() async {
    final uri = Uri.parse('$_baseUrl/inventory/fermentables');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Fehler beim Laden der Fermentables: ${response.statusCode} ${response.body}');
  }

  Future<Map<String, List<dynamic>>> getInventory() async {
    final categories = ['fermentables', 'hops', 'miscs', 'yeasts'];
    final Map<String, List<dynamic>> inventory = {};

    for (final category in categories) {
      final uri = Uri.parse('$_baseUrl/inventory/$category');
      final response = await http.get(uri, headers: _headers());
      if (response.statusCode == 429) {
        throw Exception('Brewfather Rate-Limit erreicht — bitte in ~1 min nochmal versuchen.');
      }
      if (response.statusCode != 200) {
        throw Exception('Fehler beim Laden von $category: ${response.statusCode}');
      }
      var items = jsonDecode(response.body) as List<dynamic>;

      items = await Future.wait(items.map((item) async {
        final id = item['_id'] ?? item['id'];
        if (id == null) return item;
        final detailUri = Uri.parse('$_baseUrl/inventory/$category/$id');
        final detailRes = await http.get(detailUri, headers: _headers());
        if (detailRes.statusCode == 429) {
          throw Exception('Brewfather Rate-Limit erreicht — bitte in ~1 min nochmal versuchen.');
        }
        if (detailRes.statusCode == 200) {
          return jsonDecode(detailRes.body);
        }
        return item;
      }));

      inventory[category] = items;
    }
    return inventory;
  }

  Future<void> addInventoryYeast(Map<String, dynamic> yeastData) async {
    final uri = Uri.parse('$_baseUrl/inventory/yeasts');
    final response = await http.post(uri, headers: _headers(), body: jsonEncode(yeastData));
    if (response.statusCode == 200 || response.statusCode == 201) return;
    throw Exception('Fehler beim Hinzufügen zu Brewfather: ${response.statusCode} ${response.body}');
  }

  Future<void> updateInventoryYeast(String id, Map<String, dynamic> yeastData) async {
    final uri = Uri.parse('$_baseUrl/inventory/yeasts/$id');
    final response = await http.patch(uri, headers: _headers(), body: jsonEncode(yeastData));
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Update in Brewfather: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> updateFermentableInventory(String id, double inventoryAmount) async {
    final uri = Uri.parse('$_baseUrl/inventory/fermentables/$id');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'inventory': inventoryAmount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Update des Fermentable Inventars: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<dynamic>> getHops() async {
    final uri = Uri.parse('$_baseUrl/inventory/hops');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Fehler beim Laden der Hopfen: ${response.statusCode} ${response.body}');
  }

  Future<void> updateHopInventory(String id, double inventoryAmount) async {
    final uri = Uri.parse('$_baseUrl/inventory/hops/$id');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'inventory': inventoryAmount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Update des Hopfen Inventars: ${response.statusCode} ${response.body}');
    }
  }

  Future<List<dynamic>> getMiscs() async {
    final uri = Uri.parse('$_baseUrl/inventory/miscs');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Fehler beim Laden von Sonstiges (Miscs): ${response.statusCode} ${response.body}');
  }

  Future<void> updateMiscInventory(String id, double inventoryAmount) async {
    final uri = Uri.parse('$_baseUrl/inventory/miscs/$id');
    final response = await http.patch(
      uri,
      headers: _headers(),
      body: jsonEncode({'inventory': inventoryAmount}),
    );
    if (response.statusCode != 200) {
      throw Exception('Fehler beim Update des Misc Inventars: ${response.statusCode} ${response.body}');
    }
  }
}
