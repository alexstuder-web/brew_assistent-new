import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart'; 
import '../models/beer_presets.dart';

class FocusSlider extends StatelessWidget {
  const FocusSlider({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final antrunkPercent = ((1 - value) * 100).round();
    final abgangPercent = 100 - antrunkPercent;
    final sliderTheme = SliderTheme.of(context).copyWith(
      activeTrackColor: Colors.white60,
      inactiveTrackColor: Colors.white24,
      thumbColor: Colors.white,
      overlayColor: Colors.white10,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            SliderLabel(title: 'Antrunk', percent: antrunkPercent),
            Expanded(
              child: SliderTheme(
                data: sliderTheme,
                child: Slider(
                  value: value,
                  onChanged: onChanged,
                ),
              ),
            ),
            SliderLabel(title: 'Abgang', percent: abgangPercent),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: Text(
            describeAdditionFocus(value),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.white70,
            ),
          ),
        ),
      ],
    );
  }
}

class IntensitySlider extends StatelessWidget {
  const IntensitySlider({super.key, required this.value, required this.onChanged});

  final double value;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Text('Intensität', style: TextStyle(color: Colors.white70)),
        Expanded(
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
        Text(
          '${(value * 100).round()}%',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class SliderLabel extends StatelessWidget {
  const SliderLabel({super.key, required this.title, required this.percent});

  final String title;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: Colors.white70),
        ),
        Text(
          '$percent%',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

class SliderBlock extends StatelessWidget {
  const SliderBlock({
    super.key,
    required this.label,
    required this.minLabel,
    required this.maxLabel,
    required this.value,
    required this.baselineKey,
  });

  final String label;
  final String minLabel;
  final String maxLabel;
  final double value;
  final String baselineKey;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              minLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
            Text(
              maxLabel,
              style: const TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${(value * 100).round()}%',
          style: const TextStyle(fontSize: 12, color: Colors.white60),
        ),
      ],
    );
  }
}

class IndentedBlock extends StatelessWidget {
  const IndentedBlock({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 48),
      child: child,
    );
  }
}

class FineSlider extends StatelessWidget {
  const FineSlider({
    super.key,
    required this.value,
    required this.onChanged,
    required this.baselineKey,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String baselineKey;

  @override
  Widget build(BuildContext context) {
    final theme = SliderTheme.of(context).copyWith(
      trackHeight: 4,
      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
    );

    return Padding(
      padding: const EdgeInsets.only(top: 4, right: 24),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final points = markerPoints(baselineKey, width);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              SizedBox(
                width: width,
                child: SliderTheme(
                  data: theme,
                  child: Slider(
                    value: value,
                    min: 0,
                    max: 1,
                    onChanged: onChanged,
                  ),
                ),
              ),
              ...points,
            ],
          );
        },
      ),
    );
  }

  List<Widget> markerPoints(String key, double width) {
    final entries = beerPresets.entries
        .map((e) => MapEntry(e.key, e.value[key]))
        .where((e) => e.value != null)
        .map((e) => MapEntry(e.key, e.value!.clamp(0.0, 1.0)))
        .toList();
    if (entries.isEmpty) return [];

    entries.sort((a, b) => a.value.compareTo(b.value));
    final candidates = <MapEntry<String, double>>[];
    candidates.add(entries.first);
    if (entries.length > 2) {
      final midIndex = entries.length ~/ 2;
      candidates.add(entries[midIndex]);
    }
    candidates.add(entries.last);

    final List<Widget> markers = [];
    for (var i = 0; i < candidates.length; i++) {
      final entry = candidates[i];
      final left = (entry.value * width).clamp(0.0, width - 12.0);
      final placeAbove = i.isEven;
      final double top = placeAbove ? -24.0 - i * 4.0 : 18.0 + i * 4.0;
      markers.add(Marker(left: left, top: top, label: entry.key));
    }
    return markers;
  }
}

class Marker extends StatelessWidget {
  const Marker({super.key, required this.left, required this.top, required this.label});

  final double left;
  final double top;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: top < 0
            ? [
                Container(
                  constraints: const BoxConstraints(maxWidth: 70),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ]
            : [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: Colors.white54,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  constraints: const BoxConstraints(maxWidth: 70),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: Colors.white54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
      ),
    );
  }
}
