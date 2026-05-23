import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/env_config.dart';

/// RAPT-Calls laufen ausschließlich über den brew-proxy mit Supabase-JWT-Auth.
/// Der Proxy holt die User-spezifischen RAPT-Credentials RLS-geschützt aus
/// user_profiles. Die Native-Direct-API-Variante existiert nicht mehr — die
/// Credentials sollen niemals Client-Seite verfügbar sein.
class RaptService {
  RaptService();

  String get _baseUrl {
    final url = EnvConfig.proxyUrl();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  Map<String, String> _headers() {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError('Kein eingeloggter User — RAPT-Call nicht möglich.');
    }
    return {
      'Authorization': 'Bearer ${session.accessToken}',
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
  }

  Future<List<dynamic>> getControllers() async {
    final uri = Uri.parse('$_baseUrl/cache/controllers');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map && data.containsKey('controllers')) {
        return data['controllers'] as List;
      }
      return [];
    }
    debugPrint('RAPT proxy error ${response.statusCode}: ${response.body}');
    throw Exception('Failed to load controllers: ${response.statusCode}');
  }

  Future<List<dynamic>> getHydrometers() async {
    final uri = Uri.parse('$_baseUrl/rapt/hydrometers');
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as List<dynamic>;
    }
    throw Exception('Failed to load hydrometers: ${response.statusCode}');
  }

  Future<List<dynamic>> fetchHydrometerTelemetry({
    required String hydrometerId,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    final params = {
      'hydrometerId': hydrometerId,
      'startDate': startDate.toIso8601String(),
      'endDate': endDate.toIso8601String(),
    };
    final uri =
        Uri.parse('$_baseUrl/rapt/hydrometer-telemetry').replace(queryParameters: params);
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      final decoded = jsonDecode(response.body);
      if (decoded is List) return decoded;
      return [];
    }
    throw Exception('Failed to load hydrometer telemetry: ${response.statusCode}');
  }

  Future<Map<String, dynamic>> fetchTelemetry({
    String? controllerId,
    DateTime? startDate,
    bool forceRefresh = false,
    bool useCacheOnly = false,
  }) async {
    Uri uri;
    if (useCacheOnly) {
      uri = Uri.parse('$_baseUrl/cache/telemetry');
    } else {
      final query = <String, String>{};
      if (forceRefresh) query['reload'] = 'true';
      if (startDate != null) query['start'] = startDate.toIso8601String();
      uri = Uri.parse('$_baseUrl/rapt/telemetry').replace(queryParameters: query);
    }
    final response = await http.get(uri, headers: _headers());
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data is Map<String, dynamic>) return data;
      return {'rows': []};
    }
    throw Exception('Failed to load telemetry: ${response.statusCode} ${response.body}');
  }

  Future<void> resetStartDate() async {
    final uri = Uri.parse('$_baseUrl/rapt/telemetry/start-override');
    await http.delete(uri, headers: _headers());
  }
}
