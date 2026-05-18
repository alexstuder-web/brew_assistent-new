import 'dart:convert';
import 'package:http/http.dart' as http;

class BrewfatherService {
  final String userId;
  final String apiKey;

  // Base URL für die Brewfather API v2
  static const String _baseUrl = 'https://api.brewfather.app/v2';

  BrewfatherService({required this.userId, required this.apiKey});

  // Helper Methode für den Authorization Header
  Map<String, String> get _headers {
    final bytes = utf8.encode('$userId:$apiKey');
    final base64Str = base64.encode(bytes);
    return {
      'Authorization': 'Basic $base64Str',
      'Content-Type': 'application/json',
    };
  }

  // Recipes abrufen
  Future<List<dynamic>> getRecipes() async {
    final uri = Uri.parse('$_baseUrl/recipes?complete=true&limit=50');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      // Die API gibt standardmässig eine Liste JSON-Objekten zurück
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Fehler beim Laden der Rezepte: ${response.statusCode} ${response.body}');
    }
  }

  // Batches abrufen
  Future<List<dynamic>> getBatches() async {
    final uri = Uri.parse('$_baseUrl/batches?complete=true&limit=20');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
      var batches = jsonDecode(response.body) as List<dynamic>;

      // Fetch full details for each batch to ensure we have the complete JSON (readings, detailed steps, etc.)
      // The list endpoint provides a summary, but the user requested the FULL JSON.
      batches = await Future.wait(batches.map((batch) async {
        final id = batch['_id'] ?? batch['id'];
        if (id != null) {
          final detailUri = Uri.parse('$_baseUrl/batches/$id');
          final detailRes = await http.get(detailUri, headers: _headers);
          if (detailRes.statusCode == 200) {
            return jsonDecode(detailRes.body);
          }
        }
        return batch;
      }));

      return batches;
    } else {
      throw Exception('Fehler beim Laden der Batches: ${response.statusCode} ${response.body}');
    }
  }

  // Nur Fermentables abrufen
  Future<List<dynamic>> getFermentables() async {
    final uri = Uri.parse('$_baseUrl/inventory/fermentables');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
       return jsonDecode(response.body) as List<dynamic>;
    } else {
       throw Exception('Fehler beim Laden der Fermentables: ${response.statusCode} ${response.body}');
    }
  }

  // Inventory abrufen (wir rufen exemplarisch Fermentables, Hops, Miscs und Yeasts ab und kombinieren sie)
  Future<Map<String, List<dynamic>>> getInventory() async {
    final endpoints = {
      'fermentables': '$_baseUrl/inventory/fermentables',
      'hops': '$_baseUrl/inventory/hops',
      'miscs': '$_baseUrl/inventory/miscs',
      'yeasts': '$_baseUrl/inventory/yeasts',
    };

    final Map<String, List<dynamic>> inventory = {};

    for (final entry in endpoints.entries) {
      final category = entry.key;
      final uri = Uri.parse(entry.value);
      final response = await http.get(uri, headers: _headers);
      
      if (response.statusCode == 200) {
        var items = jsonDecode(response.body) as List<dynamic>;

        // Details für ALLE Kategorien nachladen (Yeasts, Hops, Fermentables, Miscs)
        // Die List-Endpoints liefern oft nur Basisdaten.
        items = await Future.wait(items.map((item) async {
          final id = item['_id'] ?? item['id'];
          if (id != null) {
            final detailUri = Uri.parse('$_baseUrl/inventory/$category/$id');
            final detailRes = await http.get(detailUri, headers: _headers);
            if (detailRes.statusCode == 200) {
              return jsonDecode(detailRes.body);
            }
          }
          return item;
        }));

        inventory[category] = items;
      } else {
        // Fehler bei einem Teilbereich nicht fatal, aber loggen/werfen
        throw Exception('Fehler beim Laden von $category: ${response.statusCode}');
      }
    }
    return inventory;
  }

  // Hefe zum Inventar hinzufügen (Versuch via POST /v2/inventory/yeasts, da spezifischer Endpoint nicht dokumentiert)
  Future<void> addInventoryYeast(Map<String, dynamic> yeastData) async {
    // Brewfather erwartet normalerweise 'inventory' Anpassungen.
    // Wenn 'POST' nicht supported ist, wird das fehlschlagen.
    // Wir versuchen es trotzdem konform zur User-Anforderung "hinzugefügt werden".
    final uri = Uri.parse('$_baseUrl/inventory/yeasts');
    final body = jsonEncode(yeastData);
    
    // Hinweis: Laut Doku gibt es nur GET und PUT (Update) auf ID. 
    // Aber vielleicht geht POST für Create. Wenn nicht, werfen wir Fehler.
    final response = await http.post(uri, headers: _headers, body: body);

    if (response.statusCode == 200 || response.statusCode == 201) {
      return;
    } else {
       throw Exception('Fehler beim Hinzufügen zu Brewfather: ${response.statusCode} ${response.body}');
    }
  }
  // Hefe im Brewfather update (nur für Items mit bestehender ID)
  Future<void> updateInventoryYeast(String id, Map<String, dynamic> yeastData) async {
    final uri = Uri.parse('$_baseUrl/inventory/yeasts/$id');
    final response = await http.patch(uri, headers: _headers, body: jsonEncode(yeastData));
    
    if (response.statusCode != 200) {
       throw Exception('Fehler beim Update in Brewfather: ${response.statusCode} ${response.body}');
    }
  }
  Future<void> updateFermentableInventory(String id, double inventoryAmount) async {
    final uri = Uri.parse('$_baseUrl/inventory/fermentables/$id');
    final response = await http.patch(
      uri, 
      headers: _headers, 
      body: jsonEncode({'inventory': inventoryAmount})
    );
    
    if (response.statusCode != 200) {
       throw Exception('Fehler beim Update des Fermentable Inventars: ${response.statusCode} ${response.body}');
    }
  }

  // Get Hops specifically
  Future<List<dynamic>> getHops() async {
    final uri = Uri.parse('$_baseUrl/inventory/hops');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
       return jsonDecode(response.body) as List<dynamic>;
    } else {
       throw Exception('Fehler beim Laden der Hopfen: ${response.statusCode} ${response.body}');
    }
  }

  // Update Hop inventory
  Future<void> updateHopInventory(String id, double inventoryAmount) async {
    final uri = Uri.parse('$_baseUrl/inventory/hops/$id');
    final response = await http.patch(
      uri, 
      headers: _headers, 
      body: jsonEncode({'inventory': inventoryAmount})
    );
    
    if (response.statusCode != 200) {
       throw Exception('Fehler beim Update des Hopfen Inventars: ${response.statusCode} ${response.body}');
    }
  }
  // Get Miscs specifically
  Future<List<dynamic>> getMiscs() async {
    final uri = Uri.parse('$_baseUrl/inventory/miscs');
    final response = await http.get(uri, headers: _headers);

    if (response.statusCode == 200) {
       return jsonDecode(response.body) as List<dynamic>;
    } else {
       throw Exception('Fehler beim Laden von Sonstiges (Miscs): ${response.statusCode} ${response.body}');
    }
  }

  // Update Misc inventory
  Future<void> updateMiscInventory(String id, double inventoryAmount) async {
    final uri = Uri.parse('$_baseUrl/inventory/miscs/$id');
    final response = await http.patch(
      uri, 
      headers: _headers, 
      body: jsonEncode({'inventory': inventoryAmount})
    );
    
    if (response.statusCode != 200) {
       throw Exception('Fehler beim Update des Misc Inventars: ${response.statusCode} ${response.body}');
    }
  }
}
