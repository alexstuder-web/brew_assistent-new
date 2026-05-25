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
  // RAPT-Status kommt aus rapt-Schema (rapt.user_profiles), da aibrewgenius
  // nach Migration 006 dauerhaft rapt_configured=false hat.
  bool _raptConfigured = false;

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
      // Zwei sequentielle Reads: aibrewgenius für Brewfather-Daten, rapt für RAPT-Status.
      final profile = await _service.fetchProfile(widget.profileId);
      final raptStatus = await _service.fetchRaptStatus();
      if (!mounted) return;
      setState(() {
        _profile = profile;
        _raptConfigured = raptStatus.raptConfigured;
        if (profile != null) {
          // RAPT-User-ID aus dem rapt-Store bevorzugen; Fallback auf aibrewgenius.
          _raptUserIdCtrl.text =
              raptStatus.raptUserId ?? profile.raptUserId ?? '';
          _brewfatherUserIdCtrl.text = profile.brewfatherUserId ?? '';
          // API-Keys werden NICHT vorbefüllt — sie liegen verschlüsselt
          // im Vault und sind im Frontend nicht lesbar.
        } else {
          _raptUserIdCtrl.text = raptStatus.raptUserId ?? '';
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
      // 1. Klartext-Felder (user_id, sync_enabled etc.) via regulärem upsert.
      final updatedProfile = UserProfile(
        id: _profile!.id,
        name: _profile!.name,
        avatarBlob: _profile!.avatarBlob,
        defaultBatchLiters: _profile!.defaultBatchLiters,
        raptUserId: _raptUserIdCtrl.text.trim().isEmpty
            ? null
            : _raptUserIdCtrl.text.trim(),
        brewfatherUserId: _brewfatherUserIdCtrl.text.trim().isEmpty
            ? null
            : _brewfatherUserIdCtrl.text.trim(),
        brewfatherSyncEnabled: _profile!.brewfatherSyncEnabled,
        language: _profile!.language,
        brewfatherConfigured: _profile!.brewfatherConfigured,
        // raptConfigured ist ein DB-generated Column im rapt-Schema; aibrewgenius hat
        // nach Migration 006 dauerhaft false. Den lokal gecachten rapt-Store-Wert verwenden.
        raptConfigured: _raptConfigured,
      );
      await _service.saveProfile(updatedProfile);

      // 2. API-Keys via Vault-RPC — nur wenn der User wirklich getippt hat.
      //    Leeres Feld = "nichts ändern". Explizit löschen = eigener Button.
      final newBfKey = _brewfatherApiKeyCtrl.text.trim();
      if (newBfKey.isNotEmpty) {
        await _service.setBrewfatherApiKey(newBfKey);
      }
      final newRaptKey = _raptApiKeyCtrl.text.trim();
      if (newRaptKey.isNotEmpty) {
        final raptUserId = _raptUserIdCtrl.text.trim();
        if (raptUserId.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('RAPT User ID erforderlich — bitte zuerst die User ID eintragen.'),
              ),
            );
            setState(() => _isSaving = false);
          }
          return;
        }
        await _service.setRaptApiKey(newRaptKey, raptUserId: raptUserId);
      }

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
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _clearKey({required bool isBrewfather}) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('${isBrewfather ? "Brewfather" : "RAPT"}-Key löschen?'),
        content: const Text('Der gespeicherte API-Key wird aus dem Vault gelöscht.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Abbrechen')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Löschen')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      if (isBrewfather) {
        await _service.setBrewfatherApiKey(null);
      } else {
        await _service.setRaptApiKey(null);
      }
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
                        _buildSection(
                          title: 'R.A.P.T',
                          userCtrl: _raptUserIdCtrl,
                          keyCtrl: _raptApiKeyCtrl,
                          configured: _raptConfigured,
                          onClear: () => _clearKey(isBrewfather: false),
                        ),
                        const SizedBox(height: 24),
                        _buildSection(
                          title: 'Brewfather',
                          userCtrl: _brewfatherUserIdCtrl,
                          keyCtrl: _brewfatherApiKeyCtrl,
                          configured: _profile!.brewfatherConfigured,
                          onClear: () => _clearKey(isBrewfather: true),
                        ),
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

  Widget _buildSection({
    required String title,
    required TextEditingController userCtrl,
    required TextEditingController keyCtrl,
    required bool configured,
    required VoidCallback onClear,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              controller: userCtrl,
              decoration: const InputDecoration(labelText: 'User ID'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: keyCtrl,
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
                        onPressed: onClear,
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
