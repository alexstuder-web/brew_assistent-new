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
  bool _isSaving = false;
  UserProfile? _profile;

  final TextEditingController _brewfatherUserIdCtrl = TextEditingController();
  final TextEditingController _brewfatherApiKeyCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _brewfatherUserIdCtrl.dispose();
    _brewfatherApiKeyCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final profile = await _service.fetchProfile(widget.profileId);
      if (!mounted) return;
      setState(() {
        _profile = profile;
        if (profile != null) {
          _brewfatherUserIdCtrl.text = profile.brewfatherUserId ?? '';
          // API-Keys werden NICHT vorbefüllt — sie liegen verschlüsselt
          // im Vault und sind im Frontend nicht lesbar.
        }
        _isLoading = false;
      });
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
    setState(() => _isSaving = true);

    try {
      // Klartext-Felder via regulärem upsert.
      final updatedProfile = UserProfile(
        id: _profile!.id,
        name: _profile!.name,
        avatarBlob: _profile!.avatarBlob,
        defaultBatchLiters: _profile!.defaultBatchLiters,
        brewfatherUserId: _brewfatherUserIdCtrl.text.trim().isEmpty
            ? null
            : _brewfatherUserIdCtrl.text.trim(),
        brewfatherSyncEnabled: _profile!.brewfatherSyncEnabled,
        language: _profile!.language,
        brewfatherConfigured: _profile!.brewfatherConfigured,
      );
      await _service.saveProfile(updatedProfile);

      // API-Key via Vault-RPC — nur wenn der User wirklich getippt hat.
      // Leeres Feld = "nichts ändern". Explizit löschen = eigener Button.
      final newBfKey = _brewfatherApiKeyCtrl.text.trim();
      if (newBfKey.isNotEmpty) {
        await _service.setBrewfatherApiKey(newBfKey);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Einstellungen gespeichert')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearBrewfatherKey() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Brewfather-Key löschen?'),
        content: const Text('Der gespeicherte API-Key wird aus dem Vault gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.setBrewfatherApiKey(null);
      if (!mounted) return;
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gelöscht.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fehler: $e')));
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
                        _buildBrewfatherSection(),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _save,
                            icon: const Icon(Icons.save),
                            label: Text(_isSaving ? 'Speichere...' : 'Speichern'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildBrewfatherSection() {
    final configured = _profile!.brewfatherConfigured;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Brewfather',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(width: 10),
                if (configured)
                  const Chip(
                    label: Text('Key gesetzt'),
                    backgroundColor: Color(0xFF1A4731),
                    labelStyle: TextStyle(color: Colors.greenAccent, fontSize: 12),
                  )
                else
                  const Chip(
                    label: Text('Kein Key'),
                    backgroundColor: Color(0xFF4A2222),
                    labelStyle: TextStyle(color: Colors.redAccent, fontSize: 12),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _brewfatherUserIdCtrl,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _brewfatherApiKeyCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'API-Key',
                hintText: configured
                    ? 'Leer = unverändert. Wert = ersetzen.'
                    : 'Hier neuen Key eintragen',
                suffixIcon: configured
                    ? IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Key aus Vault löschen',
                        onPressed: _clearBrewfatherKey,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
