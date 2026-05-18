import 'package:flutter/material.dart';
import '../models/water_profile.dart';
import '../services/water_profile_service.dart';
import '../controllers/water_profile_editor_controller.dart';
import '../widgets/water_profile_widgets.dart';

class WaterProfileEditorPage extends StatefulWidget {
  const WaterProfileEditorPage({
    super.key,
    required this.profileId,
    this.profile,
    this.repository,
  });

  final String profileId;
  final WaterProfile? profile;
  final WaterProfileRepository? repository;

  @override
  State<WaterProfileEditorPage> createState() => _WaterProfileEditorPageState();
}

class _WaterProfileEditorPageState extends State<WaterProfileEditorPage> {
  late final WaterProfileEditorController _controller;
  late final WaterProfileRepository _repository;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? WaterProfileService();
    _controller = WaterProfileEditorController(profile: widget.profile);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _formatNumber(double? value, {int fractionDigits = 2}) {
    if (value == null || value.isNaN || value.isInfinite) return '–';
    return value.toStringAsFixed(fractionDigits);
  }

  Future<void> _handleSave() async {
    final draft = _controller.buildDraft(
      profileId: widget.profileId,
      id: widget.profile?.id,
    );
    _controller.setIsSaving(true);
    try {
      final saved = await _repository.saveProfile(draft);
      if (!mounted) return;
      Navigator.of(context).pop(saved);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Wasserprofil konnte nicht gespeichert werden: $e')),
      );
    } finally {
      if (mounted) {
        _controller.setIsSaving(false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.profile == null
        ? 'Wasserprofil anlegen'
        : 'Wasserprofil bearbeiten';

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller.nameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Profilname',
                          hintText: 'z. B. Glattfelden',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: TextField(
                        controller: _controller.phCtrl,
                        keyboardType:
                            const TextInputType.numberWithOptions(decimal: true),
                        decoration: const InputDecoration(
                          labelText: 'pH',
                          hintText: '7.2',
                        ),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                  ],
                ),
                CheckboxListTile(
                  value: _controller.isDefault,
                  controlAffinity: ListTileControlAffinity.leading,
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Als Standard verwenden (★)'),
                  onChanged: (value) => _controller.setIsDefault(value ?? false),
                ),
                const SizedBox(height: 24),
                WaterSectionHeader(
                  title: 'Kationen',
                  accent: const Color(0xFFEAB308),
                  subtitle: 'Eingabe in ppm',
                  trailing: _controller.hasWaterStats
                      ? '${_controller.cationCharge.toStringAsFixed(2)} mEq/L'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: WaterIonTile(
                        title: 'Kalzium Ca²⁺',
                        controller: _controller.calciumCtrl,
                        fieldKey: const Key('input_calcium'),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WaterIonTile(
                        title: 'Magnesium Mg²⁺',
                        controller: _controller.magnesiumCtrl,
                        fieldKey: const Key('input_magnesium'),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WaterIonTile(
                        title: 'Natrium Na⁺',
                        controller: _controller.sodiumCtrl,
                        fieldKey: const Key('input_sodium'),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                WaterSectionHeader(
                  title: 'Anionen',
                  accent: const Color(0xFF38BDF8),
                  subtitle: 'Eingabe in ppm',
                  trailing: _controller.hasWaterStats
                      ? '${_controller.anionCharge.toStringAsFixed(2)} mEq/L'
                      : null,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: WaterIonTile(
                        title: 'Chlorid Cl⁻',
                        controller: _controller.chlorideCtrl,
                        fieldKey: const Key('input_chloride'),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WaterIonTile(
                        title: 'Sulfat SO₄²⁻',
                        controller: _controller.sulfateCtrl,
                        fieldKey: const Key('input_sulfate'),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: WaterIonTile(
                        title: 'Bicarbonat HCO₃⁻',
                        controller: _controller.bicarbonateCtrl,
                        fieldKey: const Key('input_bicarbonate'),
                        onChanged: (_) => _controller.updateWaterStats(),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: const Color(0xFF0F172A),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline, color: Colors.white54),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Gib deine Wasserwerte in ppm ein. '
                          'Die Berechnung erfolgt automatisch.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_controller.hasWaterStats) ...[
                  const SizedBox(height: 24),
                  WaterSectionHeader(
                    title: 'Statistiken',
                    accent: Colors.white24,
                    subtitle: 'Berechnet aus den Eingaben',
                    trailing: _controller.ionBalancePercent != null
                        ? 'Ionenbilanz ${_controller.ionBalancePercent! >= 0 ? '+' : ''}${_controller.ionBalancePercent!.toStringAsFixed(0)}%'
                        : null,
                    trailingColor: (_controller.ionBalancePercent?.abs() ?? 0) > 10
                        ? Colors.redAccent
                        : Colors.greenAccent,
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final double baseWidth = constraints.maxWidth >= 640
                          ? (constraints.maxWidth - 48) / 5
                          : (constraints.maxWidth - 36) / 3;
                      final double tileWidth =
                          baseWidth.clamp(140.0, constraints.maxWidth);
                      return Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          WaterStatTile(
                            width: tileWidth,
                            label: 'SO₄²⁻/Cl⁻ Verhältnis',
                            value: _formatNumber(_controller.so4ClRatio),
                          ),
                          WaterStatTile(
                            width: tileWidth,
                            label: 'Härte (ppm CaCO₃)',
                            value: _formatNumber(_controller.waterHardness, fractionDigits: 0),
                          ),
                          WaterStatTile(
                            width: tileWidth,
                            label: 'Alkalinität',
                            value:
                                _formatNumber(_controller.waterAlkalinity, fractionDigits: 0),
                          ),
                          WaterStatTile(
                            width: tileWidth,
                            label: 'Restalkalinität',
                            value: _formatNumber(_controller.residualAlkalinity,
                                fractionDigits: 0),
                          ),
                          WaterStatTile(
                            width: tileWidth,
                            label: 'pH Eingabe',
                            value: _controller.computedWaterPh != null
                                ? _controller.computedWaterPh!.toStringAsFixed(2)
                                : '–',
                          ),
                        ],
                      );
                    },
                  ),
                ],
                const SizedBox(height: 24),
                Row(
                  key: const Key('editor_actions_row'),
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.icon(
                      key: const Key('save_button'),
                      onPressed: _controller.isSaving ? null : _handleSave,
                      icon: _controller.isSaving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(_controller.isSaving ? 'Speichert …' : 'Speichern'),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      label: const Text('Abbrechen'),
                    ),
                  ],
                ),
              ],
            ),
          );
        }
      ),
    );
  }
}
