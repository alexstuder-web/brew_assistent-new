import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/image_attachment.dart';

class OpenAIService {
  static const String _defaultProxyBase = 'http://localhost:3000/api';

  OpenAIService()
      : _brewEndpoint = _deriveEndpoint('brew'),
        _shopEndpoint = _deriveEndpoint('shop-search'),
        _chatEndpoint = _deriveEndpoint('chat'),
        _imageEndpoint = _deriveEndpoint('picture');

  final Uri _brewEndpoint;
  final Uri _shopEndpoint;
  final Uri _chatEndpoint;
  final Uri _imageEndpoint;

  String get proxyBaseUrl {
    String baseUrl = const String.fromEnvironment('PROXY_URL', defaultValue: '');
    if (baseUrl.isEmpty) {
      baseUrl = dotenv.env['PROXY_URL'] ?? _defaultProxyBase;
    }
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }
    return baseUrl;
  }

  static Uri _deriveEndpoint(String path) {
    // 1. Try dart-define (usually from CI/CD or local flutter run)
    // 2. Try dotenv (usually from local .env file)
    // 3. Fallback to default
    String baseUrl = const String.fromEnvironment('PROXY_URL', defaultValue: '');
    if (baseUrl.isEmpty) {
      baseUrl = dotenv.env['PROXY_URL'] ?? _defaultProxyBase;
    }

    // Remove trailing slash
    if (baseUrl.endsWith('/')) {
      baseUrl = baseUrl.substring(0, baseUrl.length - 1);
    }

    // Check if the baseUrl already ends with the path (e.g. if someone put .../api/brew in .env)
    // To be safe, check for the path with a leading slash
    if (baseUrl.endsWith('/$path')) {
      return Uri.parse(baseUrl);
    }

    return Uri.parse('$baseUrl/$path');
  }

  Future<String> brewRecipe(
    String userPrompt, {
    ImageAttachment? attachment,
  }) async {
    if (userPrompt.trim().isEmpty) {
      throw Exception('Bitte gib eine Beschreibung ein.');
    }

    final payload = <String, dynamic>{
      'prompt': userPrompt,
      if (attachment != null) 'image': attachment.toJson(),
    };

    final response = await http.post(
      _brewEndpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      final message =
          response.body.isNotEmpty ? response.body : 'Unbekannter Fehler';
      throw Exception('Proxy-Anfrage fehlgeschlagen: $message');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    final result = decoded['result'];

    if (result is! String || result.trim().isEmpty) {
      throw Exception('Keine gültige Antwort vom Proxy erhalten.');
    }

    return result.trim();
  }

  Future<ShopSearchResponse> searchShops(String query) async {
    final response = await http.post(
      _shopEndpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({'query': query}),
    );

    if (response.statusCode != 200) {
      final message =
          response.body.isNotEmpty ? response.body : 'Unbekannter Fehler';
      throw Exception('Shopsuche fehlgeschlagen: $message');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    return ShopSearchResponse.fromJson(decoded);
  }

  Future<String> generalChat(String prompt, {ImageAttachment? attachment}) async {
    final response = await http.post(
      _chatEndpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        if (attachment != null) 'image': attachment.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      final message =
          response.body.isNotEmpty ? response.body : 'Unbekannter Fehler';
      throw Exception('Chat-Anfrage fehlgeschlagen: $message');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    return (decoded['result'] as String? ?? '').trim();
  }

  Future<String> generateImage(String prompt, {ImageAttachment? attachment}) async {
    final response = await http.post(
      _imageEndpoint,
      headers: const {'Content-Type': 'application/json'},
      body: jsonEncode({
        'prompt': prompt,
        if (attachment != null) 'image': attachment.toJson(),
      }),
    );

    if (response.statusCode != 200) {
      final message =
          response.body.isNotEmpty ? response.body : 'Unbekannter Fehler';
      throw Exception('Bildgenerierung fehlgeschlagen: $message');
    }

    final Map<String, dynamic> decoded =
        jsonDecode(response.body) as Map<String, dynamic>;
    final imageUrl = decoded['result'] as String?;
    
    if (imageUrl == null || imageUrl.isEmpty) {
      throw Exception('Keine Bild-URL vom Proxy erhalten.');
    }
    
    return imageUrl;
  }

  Future<String> analyzeRecipe(Map<String, dynamic> recipeData) async {
    final prompt = 'Bitte analysiere folgendes Bierbrau-Rezept und gib konstruktive Vorschläge zur Verbesserung (z.B. Hopfen-Timing, Malz-Zusammensetzung, Gärführung). \n\nRezept-Daten:\n${const JsonEncoder.withIndent('  ').convert(recipeData)}';
    return generalChat(prompt);
  }

}

class ShopSearchResponse {
  ShopSearchResponse({required this.query, required this.shops});

  final String query;
  final List<ShopSearchShop> shops;

  factory ShopSearchResponse.fromJson(Map<String, dynamic> json) {
    final shopsJson = json['shops'] as List<dynamic>? ?? const [];
    return ShopSearchResponse(
      query: json['query'] as String? ?? '',
      shops: shopsJson
          .map(
              (entry) => ShopSearchShop.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ShopSearchShop {
  ShopSearchShop({
    required this.shop,
    required this.url,
    required this.results,
    this.error,
  });

  final String shop;
  final String? url;
  final List<ShopSearchItem> results;
  final String? error;

  factory ShopSearchShop.fromJson(Map<String, dynamic> json) {
    final resultsJson = json['results'] as List<dynamic>? ?? const [];
    return ShopSearchShop(
      shop: json['shop'] as String? ?? '',
      url: json['url'] as String?,
      error: json['error'] as String?,
      results: resultsJson
          .map(
              (entry) => ShopSearchItem.fromJson(entry as Map<String, dynamic>))
          .toList(),
    );
  }
}

class ShopSearchItem {
  ShopSearchItem({
    required this.title,
    this.link,
    this.price,
    this.availability,
  });

  final String title;
  final String? link;
  final String? price;
  final String? availability;

  factory ShopSearchItem.fromJson(Map<String, dynamic> json) {
    return ShopSearchItem(
      title: json['title'] as String? ?? '',
      link: json['link'] as String?,
      price: json['price'] as String?,
      availability: json['availability'] as String?,
    );
  }
}
