import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/auth_page.dart';

/// Wraps the app: shows AuthPage when no session, [signedIn] when a session exists.
/// Listens to onAuthStateChange so login/logout transitions are reflected immediately.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.signedIn});

  final Widget signedIn;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = Supabase.instance.client.auth.currentSession;
        if (session == null) {
          return const AuthPage();
        }
        return widget.signedIn;
      },
    );
  }
}
