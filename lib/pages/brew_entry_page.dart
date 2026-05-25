import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'discovery_welcome_page.dart';
import 'user_profile_page.dart';
import 'recipe_prompt_page.dart';
import '../utils/env_config.dart';
import '../services/sso_service.dart';
import '../widgets/entry_button.dart';

class BrewEntryPage extends StatelessWidget {
  const BrewEntryPage({super.key});

  static const String routeName = '/';

  void _openRoute(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _signOut(BuildContext context) async {
    await Supabase.instance.client.auth.signOut();
  }

  Future<void> _openStudio(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte Studio nicht öffnen.')),
      );
    }
  }

  /// Holt ein SSO-Ticket vom assistent-Proxy und öffnet das rapt_dashboard
  /// mit dem Ticket im URL-Fragment (#sso=TICKET).
  ///
  /// Bei Proxy-Fehler: SnackBar + Dashboard ohne Ticket öffnen (Fallback).
  /// Das Ticket ist single-use und max. 60 s gültig — kein Persistieren.
  Future<void> _openRaptDashboard(BuildContext context) async {
    final baseUrl = EnvConfig.raptDashboardUrl();
    String? ticket;

    try {
      ticket = await SsoService().fetchRaptTicket();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte RAPT-Login nicht vorbereiten.')),
      );
    }

    if (!context.mounted) return;

    // Ticket im URL-Fragment (nicht Query) — landet nicht in Server-Logs/Referer.
    final uri = ticket != null
        ? Uri.parse('$baseUrl/#sso=$ticket')
        : Uri.parse(baseUrl);

    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte RAPT-Dashboard nicht öffnen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final studioUrl = EnvConfig.studioUrl();
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Positioned(
              top: 20,
              right: 20,
              child: Row(
                children: [
                  const Text(
                    String.fromEnvironment('BUILD_TIME', defaultValue: 'dev'),
                    style: TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Image.asset(
                    'assets/icon_small.png',
                    height: 49,
                    filterQuality: FilterQuality.none,
                    semanticLabel: 'AiBrewGenius',
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    tooltip: 'Abmelden',
                    onPressed: () => _signOut(context),
                  ),
                ],
              ),
            ),
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    EntryButton(
                      label: 'Users profil',
                      onPressed: () =>
                          _openRoute(context, UserProfilePage.routeName),
                    ),
                    const SizedBox(height: 18),
                    EntryButton(
                      label: 'Currently Brewing',
                      onPressed: () => _openRaptDashboard(context),
                    ),
                    if (studioUrl != null) ...[
                      const SizedBox(height: 18),
                      EntryButton(
                        label: 'Studio',
                        onPressed: () => _openStudio(context, studioUrl),
                      ),
                    ],
                    const SizedBox(height: 18),
                    EntryButton(
                      label: 'Start, entdecken wir ein neues Bier',
                      onPressed: () => _openRoute(
                        context,
                        DiscoveryWelcomePage.routeName,
                      ),
                    ),
                    const SizedBox(height: 18),
                    EntryButton(
                      label: 'Freie Text beschreibung',
                      onPressed: () =>
                          _openRoute(context, RecipePromptPage.routeName),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
