import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/env_config.dart';

/// Holt ein Single-Use SSO-Ticket vom assistent-Proxy für das rapt_dashboard.
///
/// POST {proxyUrl}/sso/rapt-ticket mit dem Supabase-Bearer-JWT des eingeloggten
/// Users. Das Ticket ist single-use und max. 60 s gültig — nicht persistieren.
/// Das rapt_dashboard konsumiert es via URL-Fragment #sso=TICKET.
class SsoService {
  SsoService();

  String get _baseUrl {
    final url = EnvConfig.proxyUrl();
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Holt ein frisches SSO-Ticket. Wirft eine Exception wenn kein Session
  /// vorhanden oder der Proxy einen Non-200 zurückgibt.
  Future<String> fetchRaptTicket() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) {
      throw StateError('Kein eingeloggter User — SSO-Ticket nicht verfügbar.');
    }

    final uri = Uri.parse('$_baseUrl/sso/rapt-ticket');
    final response = await http.post(
      uri,
      headers: <String, String>{
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final body = jsonDecode(response.body);
      final ticket = body['ticket'] as String?;
      if (ticket == null || ticket.isEmpty) {
        throw Exception('Proxy antwortete 200 aber ohne ticket-Feld.');
      }
      return ticket;
    }

    debugPrint('SsoService: proxy returned ${response.statusCode}: ${response.body}');
    throw Exception('SSO-Ticket-Anfrage fehlgeschlagen: ${response.statusCode}');
  }
}
