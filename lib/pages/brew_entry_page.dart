import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'discovery_welcome_page.dart';
import 'user_profile_page.dart';
import 'recipe_prompt_page.dart';
import '../utils/env_config.dart';
import '../widgets/entry_button.dart';

class BrewEntryPage extends StatelessWidget {
  const BrewEntryPage({super.key});

  static const String routeName = '/';

  void _openRoute(BuildContext context, String route) {
    Navigator.of(context).pushNamed(route);
  }

  Future<void> _openStudio(BuildContext context) async {
    final uri = Uri.parse('http://127.0.0.1:54323/');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte Studio nicht öffnen.')),
      );
    }
  }

  Future<void> _openRaptDashboard(BuildContext context) async {
    final uri = Uri.parse(EnvConfig.raptDashboardUrl());
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konnte RAPT-Dashboard nicht öffnen.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                    const SizedBox(height: 18),
                    EntryButton(
                      label: 'Studio',
                      onPressed: () => _openStudio(context),
                    ),
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
