import 'package:flutter/material.dart';
import '../models/keezer_config.dart';
import '../services/keezer_service.dart';

class KeezerConfigPage extends StatefulWidget {
  const KeezerConfigPage({super.key, required this.profileId, this.initialConfig});

  final String profileId;
  final KeezerConfig? initialConfig;

  @override
  State<KeezerConfigPage> createState() => _KeezerConfigPageState();
}

class _KeezerConfigPageState extends State<KeezerConfigPage> {
  final _service = KeezerService();
  late int _numTaps;
  late List<TapConfig> _taps;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _numTaps = widget.initialConfig?.numTaps ?? 1;
    _taps = widget.initialConfig?.taps ?? [TapConfig(tapNumber: 1)];
    
    _syncTaps();
  }

  void _syncTaps() {
    if (_taps.length < _numTaps) {
      for (int i = _taps.length + 1; i <= _numTaps; i++) {
        _taps.add(TapConfig(tapNumber: i));
      }
    } else if (_taps.length > _numTaps) {
      _taps = _taps.take(_numTaps).toList();
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    final config = KeezerConfig(
      userProfileId: widget.profileId,
      numTaps: _numTaps,
      taps: _taps,
    );
    
    try {
      await _service.saveConfig(config);
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fehler beim Speichern: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keezer Konfiguration'),
        actions: [
          if (_isSaving)
            const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check),
              onPressed: _save,
              tooltip: 'Speichern',
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Anzahl Zapfhähne',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Slider(
                    value: _numTaps.toDouble(),
                    min: 1,
                    max: 12,
                    divisions: 11,
                    label: _numTaps.toString(),
                    onChanged: (val) {
                      setState(() {
                        _numTaps = val.round();
                        _syncTaps();
                      });
                    },
                  ),
                ),
                Text(
                  _numTaps.toString(),
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 16),
              ],
            ),
            const Divider(height: 32),
            ...List.generate(_numTaps, (index) => _buildTapEditor(index)),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _save,
                child: const Text('Konfiguration speichern'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTapEditor(int index) {
    final tap = _taps[index];
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Zapfhahn #${tap.tapNumber}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blueAccent),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<TapType>(
                    initialValue: tap.tapType,
                    decoration: const InputDecoration(labelText: 'Zapfhahn-Art'),
                    items: TapType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _taps[index] = tap.copyWith(tapType: val);
                        });
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<GasType>(
                    initialValue: tap.gasType,
                    decoration: const InputDecoration(labelText: 'Gas-Art'),
                    items: GasType.values.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text(t.name.toUpperCase()),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _taps[index] = tap.copyWith(gasType: val);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

