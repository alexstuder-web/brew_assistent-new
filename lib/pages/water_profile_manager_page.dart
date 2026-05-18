import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import '../models/water_profile.dart';
import '../services/water_profile_service.dart';
import '../widgets/card_actions.dart';
import 'water_profile_editor_page.dart';

class WaterProfileManagerPage extends StatefulWidget {
  const WaterProfileManagerPage({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final WaterProfileRepository? repository;

  @override
  State<WaterProfileManagerPage> createState() =>
      _WaterProfileManagerPageState();
}

class _WaterProfileManagerPageState extends State<WaterProfileManagerPage> {
  bool _isLoading = true;
  String? _error;
  List<WaterProfile> _profiles = [];
  late final WaterProfileRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WaterProfileService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final items = await _repository.fetchProfiles(widget.profileId);
      if (!mounted) return;
      items.sort((a, b) {
        if (a.isDefault != b.isDefault) {
          return a.isDefault ? -1 : 1;
        }
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
      setState(() {
        _profiles = items;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wasserprofile'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Neu'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Text(
          'Konnte Wasserprofile nicht laden:\n$_error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_profiles.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Noch keine Wasserprofile vorhanden.'),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Profil anlegen'),
            ),
          ],
        ),
      );
    }
    return ListView.separated(
      itemCount: _profiles.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final profile = _profiles[index];
        final title = profile.name.isEmpty ? 'Unbenannt' : profile.name;
        final stats = _buildQuickStats(profile);
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            onTap: () => _openEditor(editing: profile),
            leading: Icon(
              profile.isDefault ? Icons.star : Icons.star_border,
              color: profile.isDefault ? Colors.amber : Colors.white54,
            ),
            title: Text(title),
            subtitle: Text(stats),
            trailing: CardActions(
              onEdit: () => _openEditor(editing: profile),
              onDelete: () => confirmDelete(
                context,
                    'Profil “${profile.name.isEmpty ? 'Unbenannt' : profile.name}” löschen?',
                () => _deleteProfile(profile),
              ),
            ),
          ),
        );
      },
    );
  }

  String _buildQuickStats(WaterProfile profile) {
    final values = <String>[];
    if (profile.ph != null) {
      values.add('pH ${profile.ph!.toStringAsFixed(2)}');
    }
    values.add('Ca ${profile.calciumPpm.toStringAsFixed(0)} ppm');
    values.add('Mg ${profile.magnesiumPpm.toStringAsFixed(0)} ppm');
    values.add('SO₄ ${profile.sulfatePpm.toStringAsFixed(0)} ppm');
    values.add('Cl ${profile.chloridePpm.toStringAsFixed(0)} ppm');
    return values.join(' · ');
  }

  Future<void> _openEditor({WaterProfile? editing}) async {
    final saved = await Navigator.of(context).push<WaterProfile?>(
      MaterialPageRoute(
        builder: (_) => WaterProfileEditorPage(
          profileId: widget.profileId,
          profile: editing,
          repository: _repository,
        ),
      ),
    );
    if (saved != null) {
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing == null
                ? 'Wasserprofil erstellt'
                : 'Wasserprofil aktualisiert',
          ),
        ),
      );
    }
  }

  Future<void> _deleteProfile(WaterProfile profile) async {
    try {
      await _repository.deleteProfile(profile.id!);
      setState(() {
        _profiles.removeWhere((element) => element.id == profile.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil "${profile.name}" gelöscht')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profil konnte nicht gelöscht werden: $e')),
      );
    }
  }

}

