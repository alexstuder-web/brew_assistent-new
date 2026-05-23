import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Runtime-Konfiguration: leitet URLs aus dem aktuellen Hostname ab.
/// Dasselbe Web-Image läuft so lokal und auf jeder VPS-Domain (.cloud, .ch, ...).
///
/// Lokal      -> http://localhost:[port]
/// VPS        -> https://[sub].[aktuelle-domain]
///
/// ANON_KEY kann NICHT aus dem Hostname abgeleitet werden (ist ein signiertes JWT
/// pro Supabase-Instanz). Er kommt weiter aus dem dotenv .env Asset, also
/// build-time. Für single-VPS Setup ist das OK: ein .env, ein Image.
class EnvConfig {
  static bool _isLocalHost() {
    final h = Uri.base.host;
    return h == 'localhost' || h == '127.0.0.1' || h.isEmpty;
  }

  /// "assistent.alexstuder.cloud" → "alexstuder.cloud"
  static String _baseDomain() {
    return Uri.base.host.replaceFirst(RegExp(r'^[^.]+\.'), '');
  }

  /// Supabase Kong Gateway URL.
  static String supabaseUrl() {
    if (_isLocalHost()) return 'http://localhost:54321';
    return 'https://db.${_baseDomain()}';
  }

  /// Brew-Proxy URL (für /api/rapt, /api/openai, …).
  static String proxyUrl() {
    if (_isLocalHost()) return 'http://localhost:8083/api';
    return 'https://api.${_baseDomain()}/api';
  }

  /// RAPT Brewing Dashboard URL — wird in neuem Tab geöffnet.
  /// Override via .env (RAPT_DASHBOARD_URL), z.B. wenn RAPT auf anderem VPS sitzt.
  static String raptDashboardUrl() {
    final override = dotenv.env['RAPT_DASHBOARD_URL'];
    if (override != null && override.isNotEmpty) return override;
    if (_isLocalHost()) return 'http://localhost:8082';
    return 'https://rapt.${_baseDomain()}';
  }

  /// Supabase Studio URL — Dev-Tool, in Production standardmäßig versteckt.
  /// Lokal: http://localhost:54323
  /// Override via .env (STUDIO_URL) immer respektiert.
  /// In non-local OHNE Override: null → UI darf den Button nicht rendern.
  static String? studioUrl() {
    final override = dotenv.env['STUDIO_URL'];
    if (override != null && override.isNotEmpty) return override;
    if (_isLocalHost()) return 'http://localhost:54323';
    return null;
  }

  /// Supabase Anon Key — bleibt build-time aus dem .env Asset.
  static String supabaseAnonKey() => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
}
