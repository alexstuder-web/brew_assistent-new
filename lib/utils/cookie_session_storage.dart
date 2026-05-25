import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

/// Cookie-based [LocalStorage] adapter for supabase_flutter.
///
/// Stores the Supabase session as a cookie named [_cookieName] so that both
/// Flutter-Web apps on the same root domain share a single session
/// (Domain=.baseDomain on production, host-only cookie on localhost).
///
/// Cookie format:
///   sb-session=Uri.encodeComponent(persistSessionString); Path=/; SameSite=Lax
///   [; Domain=.baseDomain; Secure]   — only on non-localhost hosts
///
/// IMPORTANT: Deleting the cookie (logout) uses the EXACT same Domain + Path
/// attributes as writing — otherwise the browser keeps the old cookie and
/// logout does not terminate the session.
///
/// Restrisiko (Cross-Tab Race):
/// Sind beide Apps *gleichzeitig* sichtbar und refreshen im selben
/// Sekundenfenster, kann eine App mit dem gerade verbrauchten Refresh-Token
/// scheitern und kurz ausloggen. Nach dem nächsten Tab-Fokus (visibilitychange)
/// liest sie das neue Cookie und stellt die Session wieder her. Das ist
/// akzeptabel und ohne serverseitige Refresh-Token-Reuse-Toleranz nicht
/// vollständig eliminierbar.
class CookieSessionStorage extends LocalStorage {
  static const String _cookieName = 'sb-session';

  // Max-Age in seconds (400 days). The browser may cap this; the actual
  // session validity is encoded in the stored JSON, not the cookie lifetime.
  static const int _maxAgeSecs = 34560000;

  // ---------------------------------------------------------------------------
  // Host detection — mirrors EnvConfig._isLocalHost() / _baseDomain()
  // ---------------------------------------------------------------------------

  static bool _isLocalHost() {
    final h = Uri.base.host;
    return h == 'localhost' || h == '127.0.0.1' || h.isEmpty;
  }

  /// Returns "alexstuder.cloud" from "rapt.alexstuder.cloud".
  static String _baseDomain() =>
      Uri.base.host.replaceFirst(RegExp(r'^[^.]+\.'), '');

  // ---------------------------------------------------------------------------
  // Cookie attribute string helpers
  // ---------------------------------------------------------------------------

  /// Shared attribute tail for both write and delete operations.
  /// Must be identical in both so that the browser considers them the same cookie.
  static String _cookieAttrs({required bool forDelete}) {
    final maxAge = forDelete ? 0 : _maxAgeSecs;
    final base = 'Path=/; SameSite=Lax; Max-Age=$maxAge';
    if (_isLocalHost()) {
      // Host-only cookie (no Domain attribute, no Secure).
      // Browsers ignore the port → localhost:8081 and localhost:8082 share it.
      return base;
    }
    // Production / staging: scoped to root domain + Secure.
    final domain = '.${_baseDomain()}';
    return '$base; Domain=$domain; Secure';
  }

  // ---------------------------------------------------------------------------
  // Low-level read / write
  // ---------------------------------------------------------------------------

  /// Reads the raw (URI-encoded) value of [name] from document.cookie.
  /// Returns null when the cookie is absent or empty.
  static String? _readCookieRaw(String name) {
    final all = web.document.cookie;
    for (final part in all.split(';')) {
      final trimmed = part.trim();
      final eqIdx = trimmed.indexOf('=');
      if (eqIdx < 0) continue;
      final k = trimmed.substring(0, eqIdx).trim();
      if (k == name) {
        final v = trimmed.substring(eqIdx + 1).trim();
        return v.isEmpty ? null : v;
      }
    }
    return null;
  }

  /// Writes (or deletes, when [value] is null) the cookie via document.cookie.
  static void _applyCookie(String name, String? value,
      {required bool forDelete}) {
    final encoded = value != null ? Uri.encodeComponent(value) : '';
    final attrs = _cookieAttrs(forDelete: forDelete);
    // document.cookie setter: one assignment = one cookie change.
    web.document.cookie = '$name=$encoded; $attrs';
  }

  // ---------------------------------------------------------------------------
  // LocalStorage interface
  // ---------------------------------------------------------------------------

  @override
  Future<void> initialize() async {
    // Cookies need no async initialization.
  }

  @override
  Future<String?> accessToken() async {
    // Returns the full persisted-session JSON string (URI-decoded).
    // supabase_flutter passes this directly to auth.setInitialSession() /
    // auth.recoverSession(), which both expect the complete JSON — NOT just
    // the access_token field.
    final raw = _readCookieRaw(_cookieName);
    if (raw == null) return null;
    try {
      return Uri.decodeComponent(raw);
    } catch (e) {
      debugPrint('CookieSessionStorage: URI-decode failed: $e');
      return null;
    }
  }

  @override
  Future<bool> hasAccessToken() async => (await accessToken()) != null;

  @override
  Future<void> persistSession(String persistSessionString) async {
    _applyCookie(_cookieName, persistSessionString, forDelete: false);
  }

  @override
  Future<void> removePersistedSession() async {
    // Delete by writing the cookie with Max-Age=0 and IDENTICAL Domain+Path.
    _applyCookie(_cookieName, null, forDelete: true);
  }
}
