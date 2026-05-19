import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../utils/env_config.dart';

class RaptService {
  static const String directBaseUrl = 'https://api.rapt.io/api';

  // Proxy-URL wird runtime aus dem Hostname abgeleitet (siehe EnvConfig).
  static String get proxyBaseUrl {
    final url = EnvConfig.proxyUrl();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
  
  final String userId;
  final String apiKey;

  RaptService({
    required this.userId,
    required this.apiKey,
  });
  
  String get baseUrl => kIsWeb ? proxyBaseUrl : directBaseUrl;

  // Helper to fetch controllers
  Future<List<dynamic>> getControllers() async {
    // If using Proxy, we hit /cache/controllers
    // If Direct, we hit /TemperatureControllers/GetTemperatureControllers
    
    final uri = kIsWeb 
        ? Uri.parse('$baseUrl/cache/controllers')
        : Uri.parse('$baseUrl/TemperatureControllers/GetTemperatureControllers');
    
    // Authorization
    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    
    // Only send Auth for direct mode (Proxy handles its own auth from .env)
    if (!kIsWeb) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      
      // Adapt parsing based on source
      if (kIsWeb) {
        // Proxy returns { controllers: [...], ... }
        if (data is Map && data.containsKey('controllers')) {
           return data['controllers'] as List;
        }
        return [];
      } else {
        // Direct API returns List
        return data as List;
      }
    } else {
       debugPrint('RAPT API Error ${response.statusCode}: ${response.body}');
       throw Exception('Failed to load controllers: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> getHydrometers() async {
    final uri = kIsWeb 
        ? Uri.parse('$baseUrl/rapt/hydrometers')
        : Uri.parse('$baseUrl/Hydrometers/GetHydrometers');

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (!kIsWeb) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.get(uri, headers: headers);
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    } else {
      throw Exception('Failed to load hydrometers: ${response.statusCode}');
    }
  }

  Future<List<dynamic>> fetchHydrometerTelemetry({
    required String hydrometerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final Map<String, dynamic> params = {
      'hydrometerId': hydrometerId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
    
    final uri = kIsWeb
        ? Uri.parse('$baseUrl/rapt/hydrometer-telemetry').replace(queryParameters: params)
        : Uri.parse('$baseUrl/Hydrometers/GetTelemetry').replace(queryParameters: params);

    final Map<String, String> headers = {
      'Content-Type': 'application/json',
    };
    if (!kIsWeb) {
      headers['Authorization'] = 'Bearer $apiKey';
    }

    final response = await http.get(uri, headers: headers);

    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      // RAPT usually returns a List for direct, and our proxy also sends List 
      if (decoded is List) return decoded;
      return [];
    } else {
      throw Exception('Failed to load hydrometer telemetry: ${response.statusCode}');
    }
  }

  Future<Map<String, dynamic>> fetchTelemetry({
    String? controllerId, 
    DateTime? startDate,
    bool forceRefresh = false,
    bool useCacheOnly = false,
  }) async {
    if (!kIsWeb) {
      // Direct Mode (Legacy/Native)
      // Calls RAPT API directly which returns a List<dynamic>
      final uri = Uri.parse('$baseUrl/TemperatureControllers/GetTelemetry').replace(queryParameters: {
          'temperatureControllerId': controllerId,
          'startDate': startDate?.toIso8601String(),
       });
       
       final response = await http.get(uri, headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $apiKey'});
       
       if (response.statusCode == 200) {
         final list = jsonDecode(response.body) as List;
         return {
           'rows': list,
           'generatedAt': DateTime.now().toIso8601String(), // Mock for direct
         };
       } else {
         throw Exception('Failed to load telemetry: ${response.statusCode}');
       }
    }

    // Web / Proxy Mode
    Uri uri;
    if (useCacheOnly) {
      uri = Uri.parse('$baseUrl/cache/telemetry');
    } else {
      final query = <String, String>{};
      if (forceRefresh) query['reload'] = 'true';
      if (startDate != null) query['start'] = startDate.toIso8601String();
      
      uri = Uri.parse('$baseUrl/rapt/telemetry').replace(queryParameters: query);
    }

    final response = await http.get(uri);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) {
        return data; 
      }
      return {'rows': []};
    } else {
      throw Exception('Failed to load telemetry: ${response.statusCode} ${response.body}');
    }
  }

  Future<void> resetStartDate() async {
    if (!kIsWeb) return;
    
    final uri = Uri.parse('$baseUrl/rapt/telemetry/start-override');
    await http.delete(uri);
  }

}
