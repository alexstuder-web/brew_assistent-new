import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import 'brewfather_data_page.dart';
import 'integrations_page.dart';
import '../models/user_profile.dart'; // Import BrewfatherDataPage

class BrewfatherMenuPage extends StatelessWidget {
  const BrewfatherMenuPage({super.key, required this.profileId});

  final String profileId;

  Future<UserProfile?> _loadProfile() async {
    return UserProfileService().fetchProfile(profileId);
  }

  void _navigateToData(BuildContext context, String dataType, String userId, String apiKey) {
    if (userId.isEmpty || apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bitte erst Brewfather User ID und API Key in den Einstellungen hinterlegen.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => BrewfatherDataPage(userId: userId, apiKey: apiKey, dataType: dataType),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Brewfather')),
      body: FutureBuilder<UserProfile?>(
        future: _loadProfile(),
        builder: (context, snapshot) {
           if (snapshot.connectionState == ConnectionState.waiting) {
             return const Center(child: CircularProgressIndicator());
           }
           final profile = snapshot.data;
           final userId = profile?.brewfatherUserId ?? '';
           final apiKey = profile?.brewfatherApiKey ?? '';

           return Center(
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 if (userId.isEmpty || apiKey.isEmpty)
                   Padding(
                     padding: const EdgeInsets.all(16.0),
                     child: Column(
                       children: [
                         const Text(
                           'Warnung: Keine Zugangsdaten gefunden. Bitte unter "Integration" konfigurieren.',
                           style: TextStyle(color: Colors.orange),
                           textAlign: TextAlign.center,
                         ),
                         const SizedBox(height: 12),
                         FilledButton.icon(
                           onPressed: () {
                             Navigator.of(context).push(
                               MaterialPageRoute(
                                 builder: (_) =>
                                     IntegrationsPage(profileId: profileId),
                               ),
                             );
                           },
                           icon: const Icon(Icons.settings),
                           label: const Text('Jetzt konfigurieren'),
                         ),
                       ],
                     ),
                   ),
                 _MenuButton(
                   label: 'Read Recipes',
                   icon: Icons.menu_book,
                   onPressed: () => _navigateToData(context, 'recipes', userId, apiKey),
                 ),
                 const SizedBox(height: 16),
                 _MenuButton(
                   label: 'Read Batches',
                   icon: Icons.batch_prediction,
                   onPressed: () => _navigateToData(context, 'batches', userId, apiKey),
                 ),
                 const SizedBox(height: 16),
                 _MenuButton(
                   label: 'Read Inventory',
                   icon: Icons.inventory,
                   onPressed: () => _navigateToData(context, 'inventory', userId, apiKey),
                 ),
               ],
             ),
           );
        },
      ),
    );
  }
}

class _MenuButton extends StatelessWidget {
  const _MenuButton({required this.label, required this.icon, required this.onPressed});
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 250,
      height: 60,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label, style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
