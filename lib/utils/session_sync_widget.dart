import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:web/web.dart' as web;

import 'cookie_session_storage.dart';

/// Listens to the browser's `visibilitychange` event and syncs the Supabase
/// session from the shared `sb-session` cookie when the tab becomes visible.
///
/// This enables cross-app SSO (Variante B):
///   - Logout in App A  → App B reads the now-absent cookie on tab focus
///     → calls signOut(scope: local) → AuthGate shows AuthPage.
///   - Login / refresh in App A → App B reads the fresh cookie on tab focus
///     → calls recoverSession() → AuthGate shows the signed-in view.
///
/// Restrisiko: Wenn beide Tabs gleichzeitig sichtbar sind und in demselben
/// Sekundenfenster refreshen, kann ein verbrauchter Refresh-Token zu einem
/// kurzem Logout führen. Der nächste Tab-Fokus stellt die Session wieder her.
/// Ohne serverseitige Refresh-Token-Reuse-Toleranz nicht vollständig
/// eliminierbar. Ein BroadcastChannel-Koordinator wäre over-engineered.
class SessionSyncWidget extends StatefulWidget {
  const SessionSyncWidget({super.key, required this.child});

  final Widget child;

  @override
  State<SessionSyncWidget> createState() => _SessionSyncWidgetState();
}

class _SessionSyncWidgetState extends State<SessionSyncWidget> {
  StreamSubscription<web.Event>? _visibilitySub;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _visibilitySub = web.document.onVisibilityChange.listen((_) {
      if (web.document.visibilityState == 'visible') {
        _syncFromCookie();
      }
    });
  }

  @override
  void dispose() {
    _visibilitySub?.cancel();
    super.dispose();
  }

  Future<void> _syncFromCookie() async {
    if (_syncing) return;
    _syncing = true;
    try {
      final auth = Supabase.instance.client.auth;
      final cookieJson = await CookieSessionStorage().accessToken();

      if (cookieJson == null) {
        // Cookie gone → the other app logged out → mirror locally.
        final currentSession = auth.currentSession;
        if (currentSession != null) {
          debugPrint('SessionSyncWidget: cookie absent, signing out locally');
          await auth.signOut(scope: SignOutScope.local);
        }
        return;
      }

      // Cookie present — check whether it differs from the in-memory session.
      final currentSession = auth.currentSession;
      if (currentSession == null) {
        // We have no in-memory session but the cookie exists → recover it.
        debugPrint('SessionSyncWidget: no in-memory session, recovering from cookie');
        try {
          await auth.recoverSession(cookieJson);
        } catch (e) {
          debugPrint('SessionSyncWidget: recoverSession failed: $e');
        }
        return;
      }

      // Both cookie and in-memory session exist. Compare access tokens to detect
      // a refresh written by the partner app.
      final memToken = currentSession.accessToken;
      try {
        // Extract the access_token from the cookie JSON for comparison only.
        // This is a lightweight check; if parsing fails we do nothing.
        final cookieTokenStart = cookieJson.indexOf('"access_token":"');
        if (cookieTokenStart < 0) return;
        final valueStart = cookieTokenStart + '"access_token":"'.length;
        final valueEnd = cookieJson.indexOf('"', valueStart);
        if (valueEnd < 0) return;
        final cookieToken = cookieJson.substring(valueStart, valueEnd);

        if (cookieToken != memToken) {
          debugPrint('SessionSyncWidget: cookie token differs, recovering session');
          try {
            await auth.recoverSession(cookieJson);
          } catch (e) {
            debugPrint('SessionSyncWidget: recoverSession failed: $e');
          }
        }
      } catch (e) {
        // JSON comparison is best-effort; ignore failures silently.
        debugPrint('SessionSyncWidget: token comparison failed: $e');
      }
    } finally {
      _syncing = false;
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
