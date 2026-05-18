import 'package:flutter/material.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';

class IntegrationsPage extends StatefulWidget {
  const IntegrationsPage({super.key, required this.profileId});

  final String profileId;

  @override
  State<IntegrationsPage> createState() => _IntegrationsPageState();
}

class _IntegrationsPageState extends State<IntegrationsPage> {
  final UserProfileService _service = UserProfileService();
  bool _isLoading = true;
  UserProfile? _profile;

  final TextEditingController _raptUserIdCtrl = TextEditingController();
  final TextEditingController _raptApiKeyCtrl = TextEditingController();
  final TextEditingController _brewfatherUserIdCtrl = TextEditingController();
  final TextEditingController _brewfatherApiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _raptUserIdCtrl.dispose();
    _raptApiKeyCtrl.dispose();
    _brewfatherUserIdCtrl.dispose();
    _brewfatherApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _service.fetchProfile(widget.profileId);
      if (mounted) {
        setState(() {
          _profile = profile;
          if (profile != null) {
            _raptUserIdCtrl.text = profile.raptUserId ?? '';
            _raptApiKeyCtrl.text = profile.raptApiKey ?? '';
            _brewfatherUserIdCtrl.text = profile.brewfatherUserId ?? '';
            _brewfatherApiKeyCtrl.text = profile.brewfatherApiKey ?? '';
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Laden: $e')),
        );
      }
    }
  }

  Future<void> _save() async {
    if (_profile == null) return;
    
    final updatedProfile = UserProfile(
      id: _profile!.id,
      name: _profile!.name,
      avatarBlob: _profile!.avatarBlob,
      defaultBatchLiters: _profile!.defaultBatchLiters,
      raptUserId: _raptUserIdCtrl.text.trim().isEmpty ? null : _raptUserIdCtrl.text.trim(),
      raptApiKey: _raptApiKeyCtrl.text.trim().isEmpty ? null : _raptApiKeyCtrl.text.trim(),
      brewfatherUserId: _brewfatherUserIdCtrl.text.trim().isEmpty ? null : _brewfatherUserIdCtrl.text.trim(),
      brewfatherApiKey: _brewfatherApiKeyCtrl.text.trim().isEmpty ? null : _brewfatherApiKeyCtrl.text.trim(),
      brewfatherSyncEnabled: _profile!.brewfatherSyncEnabled,
    );

    try {
      await _service.saveProfile(updatedProfile);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Einstellungen gespeichert')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Integrationen')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _profile == null
              ? const Center(child: Text('Profil nicht gefunden'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      children: [
                        _buildSection('R.A.P.T', _raptUserIdCtrl, _raptApiKeyCtrl),
                        const SizedBox(height: 24),
                        _buildSection('Brewfather', _brewfatherUserIdCtrl, _brewfatherApiKeyCtrl),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _save,
                            icon: const Icon(Icons.save),
                            label: const Text('Speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildSection(String title, TextEditingController userCtrl, TextEditingController keyCtrl) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyCtrl,
              decoration: const InputDecoration(labelText: 'API-Key'),
            ),
          ],
        ),
      ),
    );
  }
}
