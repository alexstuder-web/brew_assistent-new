import 'dart:convert';
import 'package:flutter/material.dart';
import '../utils/dialog_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/yeast_bank_entry.dart';
import '../services/yeast_bank_service.dart';
import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../services/brewfather_service.dart';
import '../widgets/card_actions.dart';
import 'integrations_page.dart';
import 'yeast_label_page.dart';
import 'yeast_bank_editor_page.dart';

class YeastBankManagerPage extends StatefulWidget {
  const YeastBankManagerPage({
    super.key,
    required this.profileId,
    this.repository,
    this.userRepository,
  });

  final String profileId;
  final YeastBankRepository? repository;
  final UserProfileRepository? userRepository;

  @override
  State<YeastBankManagerPage> createState() => _YeastBankManagerPageState();
}

class _YeastBankManagerPageState extends State<YeastBankManagerPage> {
  late final YeastBankRepository _service;
  late final UserProfileRepository _userService;
  bool _isLoading = true;
  List<YeastBankEntry> _entries = [];
  String? _error;
  bool _syncEnabled = false;
  UserProfile? _userProfile;
  final Map<String, String> _debugJsonMap = {};

  @override
  void initState() {
    super.initState();
    _service = widget.repository ?? YeastBankService();
    _userService = widget.userRepository ?? UserProfileService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final profile = await _userService.fetchProfile(widget.profileId);
      final items = await _service.fetchEntries(widget.profileId);

      if (!mounted) return;

      setState(() {
        _userProfile = profile;
        _syncEnabled = profile?.brewfatherSyncEnabled ?? false;
        _entries = items;
        _isLoading = false;
      });

      if (_syncEnabled) {
        await _syncWithBrewfather();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _syncWithBrewfather() async {
    if (_userProfile?.brewfatherUserId == null ||
        !(_userProfile?.brewfatherConfigured ?? false)) {
      return;
    }
    try {
      final bfService = BrewfatherService();
      final inventory = await bfService.getInventory();
      final yeasts = inventory['yeasts'] ?? [];

      bool changed = false;
      for (var y in yeasts) {
        final name = y['name'] ?? '';
        if (name.isEmpty) continue;

        YeastBankEntry? existingEntry;
        final bfId = y['_id'] ?? y['id'];

        if (bfId != null) {
          try {
            existingEntry = _entries.firstWhere((e) => e.brewfatherId == bfId);
          } catch (_) {}
        }

        if (existingEntry == null) {
          try {
            existingEntry = _entries.firstWhere(
                (e) => e.strain.toLowerCase() == name.toLowerCase());
          } catch (_) {}
        }

        if (mounted) {
          setState(() {
            _debugJsonMap[name] = jsonEncode(y);
          });
        }

        final newEntry = YeastBankEntry(
          id: existingEntry?.id,
          userProfileId: widget.profileId,
          brewfatherId: bfId,
          brand: y['laboratory'] ?? y['lab'] ?? 'Brewfather',
          strain: name,
          style: y['type'],
          attenuationMin: (y['minAttenuation'] as num?)?.toDouble() ??
              (y['attenuation'] as num?)?.toDouble(),
          attenuationMax: (y['maxAttenuation'] as num?)?.toDouble() ??
              (y['attenuation'] as num?)?.toDouble(),
          temperatureMin: (y['minTemp'] as num?)?.toDouble(),
          temperatureMax: (y['maxTemp'] as num?)?.toDouble(),
          notes: (y['userNotes']?.toString().isNotEmpty == true)
              ? y['userNotes']
              : ((y['notes']?.toString().isNotEmpty == true)
                  ? y['notes']
                  : y['description']),
          productId: y['productId']?.toString() ?? existingEntry?.productId,
          form: y['form']?.toString() ?? existingEntry?.form,
          inventory: (y['inventory'] as num?)?.toDouble() ??
              (y['amount'] as num?)?.toDouble(),
          unit: y['unit']?.toString() ?? y['amountUnit']?.toString(),
          url: existingEntry?.url,
        );

        final saved = await _service.saveEntry(newEntry);

        if (existingEntry != null) {
          final index = _entries.indexOf(existingEntry);
          if (index != -1) {
            _entries[index] = saved;
          }
        } else {
          _entries.add(saved);
        }
        changed = true;
      }
      if (changed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Hefen von Brewfather synchronisiert.')));
        setState(() {});
      }
    } catch (e) {
      debugPrint('Sync Error: $e');
    }
  }

  Future<void> _toggleSync(bool value) async {
    if (_userProfile == null) return;

    if (value) {
      if ((_userProfile!.brewfatherUserId ?? '').isEmpty ||
          !_userProfile!.brewfatherConfigured) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Fehlende Zugangsdaten'),
            content: const Text(
                'Bitte hinterlegen Sie erst Ihre Brewfather User ID und API Key in den Einstellungen.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Abbrechen')),
              FilledButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          IntegrationsPage(profileId: widget.profileId),
                    ),
                  );
                },
                child: const Text('Zu den Einstellungen'),
              ),
            ],
          ),
        );
        return;
      }
    }

    final updated = UserProfile(
      id: _userProfile!.id,
      name: _userProfile!.name,
      avatarBlob: _userProfile!.avatarBlob,
      defaultBatchLiters: _userProfile!.defaultBatchLiters,
      raptUserId: _userProfile!.raptUserId,
      brewfatherUserId: _userProfile!.brewfatherUserId,
      brewfatherSyncEnabled: value,
      brewfatherConfigured: _userProfile!.brewfatherConfigured,
      raptConfigured: _userProfile!.raptConfigured,
      language: _userProfile!.language,
    );

    await _userService.saveProfile(updated);
    setState(() {
      _userProfile = updated;
      _syncEnabled = value;
    });

    if (value) {
      setState(() => _isLoading = true);
      await _syncWithBrewfather();
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Hefedatenbank'),
        actions: [
          Row(
            children: [
              const Text('Brewfather Sync'),
              Switch(
                value: _syncEnabled,
                onChanged: _toggleSync,
                activeThumbColor: Colors.blue,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton.icon(
              onPressed: () => _openForm(),
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
          'Konnte Hefen nicht laden:\n$_error',
          textAlign: TextAlign.center,
        ),
      );
    }
    if (_entries.isEmpty) {
      return const Center(
        child: Text('Noch keine Hefen eingetragen.'),
      );
    }
    return ListView.separated(
      itemCount: _entries.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final entry = _entries[index];
        return Card(
          color: const Color(0xFF0F172A),
          child: ListTile(
            leading: (entry.brewfatherId != null && entry.brewfatherId!.isNotEmpty)
                ? Image.asset('assets/Brewfather_logo.png', width: 24, height: 24)
                : Image.asset('assets/icon_small.png', width: 24, height: 24),
            onTap: () => _openForm(editing: entry),
            title: Text('${entry.brand} · ${entry.strain}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if ((entry.style ?? '').isNotEmpty) Text('Stil: ${entry.style}'),
                if (entry.attenuationMin != null || entry.attenuationMax != null)
                  Text(
                    'EVG: ${_rangeString(entry.attenuationMin, entry.attenuationMax, suffix: '%')}',
                  ),
                if (entry.temperatureMin != null || entry.temperatureMax != null)
                  Text(
                    'Temp: ${_rangeString(entry.temperatureMin, entry.temperatureMax, suffix: '°C')}',
                  ),
                if ((entry.url ?? '').isNotEmpty)
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(entry.url!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri);
                      }
                    },
                    child: Text(
                      'URL: ${entry.url}',
                      style: const TextStyle(
                        color: Colors.blueAccent,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                if ((entry.notes ?? '').isNotEmpty)
                  Text(
                    entry.notes!,
                    style: const TextStyle(color: Colors.white70),
                  ),
                if (_debugJsonMap.containsKey(entry.strain)) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      border: Border.all(color: Colors.grey.shade800),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: SelectableText(
                      'Brewfather Raw:\n${_debugJsonMap[entry.strain]}',
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 10,
                          color: Colors.greenAccent),
                    ),
                  ),
                ],
              ],
            ),
            trailing: CardActions(
              onLabel: () async {
                final updated = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => YeastLabelPage(entry: entry),
                  ),
                );
                if (updated == true) {
                  _load();
                }
              },
              onEdit: () => _openForm(editing: entry),
              onDelete: () => confirmDelete(
                context,
                'Hefeeintrag “${entry.brand} · ${entry.strain}” löschen?',
                () => _deleteEntry(entry),
              ),
            ),
          ),
        );
      },
    );
  }


  String _rangeString(double? min, double? max, {String suffix = ''}) {
    if (min == null && max == null) return '–';
    if (min != null && max != null) {
      return '${min.toStringAsFixed(1)}–${max.toStringAsFixed(1)}$suffix';
    }
    final value = min ?? max!;
    return '${value.toStringAsFixed(1)}$suffix';
  }

  Future<void> _openForm({YeastBankEntry? editing}) async {
    final saved = await Navigator.of(context).push<YeastBankEntry?>(
      MaterialPageRoute(
        builder: (_) => YeastBankEditorPage(
          profileId: widget.profileId,
          editing: editing,
          userProfile: _userProfile,
          syncEnabled: _syncEnabled,
          debugJsonMap: _debugJsonMap,
        ),
      ),
    );
    if (saved != null) {
      if (!mounted) return;
      setState(() {
        final index = _entries.indexWhere((element) => element.id == saved.id);
        if (index >= 0) {
          _entries[index] = saved;
        } else {
          _entries.add(saved);
        }
        _entries.sort(
          (a, b) => '${a.brand} ${a.strain}'
              .toLowerCase()
              .compareTo('${b.brand} ${b.strain}'.toLowerCase()),
        );
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            editing == null ? 'Hefe gespeichert' : 'Hefe aktualisiert',
          ),
        ),
      );
    }
  }

  Future<void> _deleteEntry(YeastBankEntry entry) async {
    if (entry.id == null) return;
    try {
      await _service.deleteEntry(entry.id!);
      setState(() {
        _entries.removeWhere((item) => item.id == entry.id);
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Hefe "${entry.brand} · ${entry.strain}" gelöscht'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Löschen fehlgeschlagen: $e')));
    }
  }

}
