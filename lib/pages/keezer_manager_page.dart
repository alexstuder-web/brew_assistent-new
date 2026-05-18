import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import '../models/keezer_config.dart';
import '../services/keezer_service.dart';
import 'keezer_config_page.dart';
import '../l10n/app_localizations.dart';

class KeezerManagerPage extends StatefulWidget {
  const KeezerManagerPage({super.key, required this.profileId});

  final String profileId;

  @override
  State<KeezerManagerPage> createState() => _KeezerManagerPageState();
}

class _KeezerManagerPageState extends State<KeezerManagerPage> with SingleTickerProviderStateMixin {
  final _service = KeezerService();
  KeezerConfig? _config;
  bool _isLoading = true;
  late AnimationController _bubbleController;

  @override
  void initState() {
    super.initState();
    _bubbleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat();
    _loadConfig();
  }

  @override
  void dispose() {
    _bubbleController.dispose();
    super.dispose();
  }

  Future<void> _loadConfig() async {
    setState(() => _isLoading = true);
    final config = await _service.fetchConfig(widget.profileId);
    if (!mounted) return;

    if (config == null) {
      // Navigate to config if none exists
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => KeezerConfigPage(profileId: widget.profileId),
        ),
      );
      if (result == true) {
        _loadConfig();
      } else {
        setState(() => _isLoading = false);
      }
    } else {
      setState(() {
        _config = config;
        _isLoading = false;
      });
    }
  }

  void _openConfig() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => KeezerConfigPage(profileId: widget.profileId, initialConfig: _config),
      ),
    );
    if (result == true) {
      _loadConfig();
    }
  }

  void _saveKeezerConfig(KeezerConfig config) async {
    setState(() => _isLoading = true);
    await _service.saveConfig(config);
    _loadConfig();
  }

  Future<void> _showKegDetailsDialog(TapConfig tap) async {
    final nameController = TextEditingController(text: tap.beerName);
    DateTime? tappedAt = tap.tappedAt;
    DateTime? bestBefore = tap.bestBefore;

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(AppLocalizations.of(context)!.tapDetails(tap.tapNumber)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      decoration: InputDecoration(
                        labelText: AppLocalizations.of(context)!.beerName,
                        hintText: 'z.B. Pilsner, IPA...',
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: Text(AppLocalizations.of(context)!.tappedAt),
                      subtitle: Text(tappedAt != null
                          ? DateFormat('dd.MM.yyyy').format(tappedAt!)
                          : AppLocalizations.of(context)!.notSet),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: tappedAt ?? DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() {
                            tappedAt = picked;
                            bestBefore ??= picked.add(const Duration(days: 90));
                          });
                        }
                      },
                    ),
                    ListTile(
                      title: Text(AppLocalizations.of(context)!.bestBefore),
                      subtitle: Text(bestBefore != null
                          ? DateFormat('dd.MM.yyyy').format(bestBefore!)
                          : AppLocalizations.of(context)!.notSet),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: bestBefore ?? DateTime.now().add(const Duration(days: 90)),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setState(() => bestBefore = picked);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(AppLocalizations.of(context)!.cancel),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, 'empty'),
                  child: Text(AppLocalizations.of(context)!.empty, style: const TextStyle(color: Colors.redAccent)),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, 'save'),
                  child: Text(AppLocalizations.of(context)!.save),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == 'save' || result == 'empty') {
      final updatedTaps = _config!.taps.map((t) {
        if (t.tapNumber == tap.tapNumber) {
          if (result == 'empty') {
             return t.copyWith(
                beerName: '',
                tappedAt: null,
                bestBefore: null,
             );
          }
          return t.copyWith(
            beerName: nameController.text,
            tappedAt: tappedAt,
            bestBefore: bestBefore,
          );
        }
        return t;
      }).toList();

      final updatedConfig = KeezerConfig(
        userProfileId: widget.profileId,
        numTaps: _config!.numTaps,
        taps: updatedTaps,
      );

      _saveKeezerConfig(updatedConfig);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keezer'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: _openConfig,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _config == null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(AppLocalizations.of(context)!.noConfig),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _openConfig,
                        child: Text(AppLocalizations.of(context)!.configureNow),
                      ),
                    ],
                  ),
                )
              : _buildKeezerVisualization(),
    );
  }

  Widget _buildKeezerVisualization() {
    final taps = _config!.taps;

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const SizedBox(height: 40),
          // Taps
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: taps.map((tap) => _buildTap(tap)).toList(),
          ),
          // Continuous Stroke (Collar area)
          Container(
            height: 4,
            width: double.infinity,
            color: Colors.grey[700],
          ),
          // Keezer Body (Large horizontal rectangle)
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: taps.map((tap) => _buildKeg(tap)).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTap(TapConfig tap) {
    Color tapColor;
    switch (tap.tapType) {
      case TapType.ale:
        tapColor = Colors.orangeAccent;
        break;
      case TapType.stout:
        tapColor = Colors.grey[850]!;
        break;
      case TapType.standard:
        tapColor = Colors.grey[400]!;
        break;
    }

    return Column(
      children: [
        // Handle
        Container(
          width: 8,
          height: 30,
          decoration: BoxDecoration(
            color: tapColor,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        // Faucet
        Container(
          width: 15,
          height: 10,
          decoration: BoxDecoration(
            color: tapColor,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildKeg(TapConfig tap) {
    double fillPercentage = 0.0;
    bool hasBeer = tap.beerName != null && tap.beerName!.isNotEmpty;

    if (hasBeer && tap.tappedAt != null && tap.bestBefore != null) {
      final now = DateTime.now();
      if (now.isBefore(tap.tappedAt!)) {
        fillPercentage = 1.0;
      } else if (now.isAfter(tap.bestBefore!)) {
        fillPercentage = 0.0;
      } else {
        final totalDuration = tap.bestBefore!.difference(tap.tappedAt!).inSeconds;
        final remainingDuration = tap.bestBefore!.difference(now).inSeconds;
        if (totalDuration > 0) {
          fillPercentage = (remainingDuration / totalDuration).clamp(0.0, 1.0);
        }
      }
    } else if (hasBeer) {
      // If we have a beer but no dates, we show it as full as a fallback
      fillPercentage = 1.0;
    }

    final dateFormat = DateFormat('dd.MM.yy');

    return GestureDetector(
      onTap: () => _showKegDetailsDialog(tap),
      child: Column(
        children: [
          // Tapped Date (Top)
          Text(
            tap.tappedAt != null ? dateFormat.format(tap.tappedAt!) : '-',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(height: 4),
          // Keg
          Expanded(
            child: Container(
              width: 50,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(4),
                border: Border.all(color: Colors.white24, width: 1),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Stack(
                  alignment: Alignment.bottomCenter,
                  children: [
                    // Empty part (Background)
                    Container(
                      width: double.infinity,
                      height: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.grey[800]!,
                            Colors.grey[700]!,
                            Colors.grey[900]!,
                          ],
                        ),
                      ),
                    ),
                    // Beer part (Filling from bottom)
                    FractionallySizedBox(
                      heightFactor: fillPercentage,
                      widthFactor: 1.0,
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                            colors: [
                              Colors.amber[600]!,
                              Colors.amber[400]!,
                              Colors.amber[700]!,
                            ],
                          ),
                        ),
                      ),
                    ),
                    // Bubbles effect for beer
                    if (fillPercentage > 0)
                      Positioned.fill(
                        child: AnimatedBuilder(
                          animation: _bubbleController,
                          builder: (context, child) {
                            return CustomPaint(
                              painter: BubblesPainter(
                                fillPercentage: fillPercentage,
                                animationValue: _bubbleController.value,
                              ),
                            );
                          },
                        ),
                      ),
                    // Label (Beer Name)
                    RotatedBox(
                      quarterTurns: 3,
                      child: Center(
                        child: Text(
                          hasBeer ? tap.beerName! : '#${tap.tapNumber}',
                          style: TextStyle(
                            color: fillPercentage > 0.3 ? Colors.black87 : Colors.white70,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            shadows: fillPercentage > 0.3 
                              ? [] 
                              : [const Shadow(color: Colors.black, blurRadius: 2)],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Best Before Date (Bottom)
          Text(
            tap.bestBefore != null ? dateFormat.format(tap.bestBefore!) : '-',
            style: const TextStyle(fontSize: 10, color: Colors.white38),
          ),
          const SizedBox(height: 4),
          // Gas label
          Text(
            tap.gasType.name.toUpperCase(),
            style: const TextStyle(fontSize: 10, color: Colors.blueAccent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

class BubblesPainter extends CustomPainter {
  BubblesPainter({
    required this.fillPercentage,
    required this.animationValue,
  });

  final double fillPercentage;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (fillPercentage <= 0) return;

    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    final count = (20 * fillPercentage).toInt().clamp(10, 30);

    for (int i = 0; i < count; i++) {
      final radius = random.nextDouble() * 2 + 1;
      // Animate vertical position
      final baseTop = size.height * (1 - fillPercentage);
      final offsetMultiplier = random.nextDouble();
      final bubbleHeight = size.height * fillPercentage;
      
      // Infinite upward movement
      double yProgress = (animationValue + offsetMultiplier) % 1.0;
      final y = size.height - (yProgress * bubbleHeight);
      
      // Subtle horizontal sway
      final xSway = math.sin(animationValue * 2 * math.pi + i) * 3;
      final x = (random.nextDouble() * size.width) + xSway;

      if (y > baseTop) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant BubblesPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.fillPercentage != fillPercentage;
}
