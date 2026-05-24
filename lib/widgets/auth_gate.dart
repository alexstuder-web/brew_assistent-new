import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../main.dart';
import '../pages/auth_page.dart';
import '../services/user_profile_service.dart';

/// Wraps the app: shows AuthPage when no session, [signedIn] when a session exists.
/// Listens to onAuthStateChange so login/logout transitions are reflected immediately.
/// After login, fetches the stored language from user_profiles and applies it via
/// BrewMateApp.setLocale so the locale is active before the first authenticated frame.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.signedIn});

  final Widget signedIn;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Tracks the last session user-id for which we already applied the locale.
  /// Resets to null on sign-out so a re-login re-triggers the fetch.
  String? _localeAppliedForUser;

  /// Fetches the stored language for [userId] and applies it via
  /// BrewMateApp.applyLocale (GlobalKey-based, no BuildContext needed).
  void _scheduleProfileLocale(String userId) {
    UserProfileService().fetchProfile(userId).then((profile) {
      if (!mounted) return;
      if (profile != null && profile.language.isNotEmpty) {
        BrewMateApp.applyLocale(Locale(profile.language));
      }
    }).catchError((Object e) {
      debugPrint('AuthGate: locale fetch failed: $e');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          // User signed out — reset so the next login re-applies the locale.
          _localeAppliedForUser = null;
          return const AuthPage();
        }

        // Apply locale once per session (avoids re-fetching on every rebuild).
        final userId = session.user.id;
        if (_localeAppliedForUser != userId) {
          _localeAppliedForUser = userId;
          // Schedule after the current build frame to avoid setState-during-build.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scheduleProfileLocale(userId);
          });
        }

        return widget.signedIn;
      },
    );
  }
}
