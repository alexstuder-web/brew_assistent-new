import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart';
import '../widgets/user_name_banner.dart';
import 'equipment_page.dart';

class RecipeSummaryPage extends StatelessWidget {
  const RecipeSummaryPage({super.key, required this.profile});

  final FineTuningProfile profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rezept'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Image.asset(
              'assets/icon_small.png',
              height: 40,
              filterQuality: FilterQuality.none,
              semanticLabel: 'AiBrewGenius',
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UserNameBanner(),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                children: [
                  Text(
                    'Zusammenfassung für ${profile.beerName}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...buildRecipeSummarySections(profile),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => EquipmentPage(profile: profile),
                    ),
                  );
                },
                child: const Text('Equipment'),
              ),
            )
          ],
        ),
      ),
    );
  }
}

class _SummarySection {
  const _SummarySection(this.title, this.entries, {this.dividerBefore = false});

  final String title;
  final List<_SummaryEntry> entries;
  final bool dividerBefore;
}

class _SummaryEntry {
  const _SummaryEntry(this.label, this.value, {required this.baselineKey});

  final String label;
  final double value;
  final String baselineKey;
}

List<Widget> buildRecipeSummarySections(FineTuningProfile profile) {
  final sections = [
    _SummarySection('Hopfen', [
      _SummaryEntry('Aromaintensität', profile.hopIntensity,
          baselineKey: 'hopIntensity'),
      _SummaryEntry('Kräuterig', profile.hopHerbal, baselineKey: 'hopHerbal'),
      _SummaryEntry('Blumig', profile.hopFloral, baselineKey: 'hopFloral'),
      _SummaryEntry('Fruchtig', profile.hopFruity, baselineKey: 'hopFruity'),
    ]),
    _SummarySection('Verteilung', [
      _SummaryEntry('Nase', profile.hopNose, baselineKey: 'hopNose'),
      _SummaryEntry('Gaumen', profile.hopPalate, baselineKey: 'hopPalate'),
      _SummaryEntry('Abgang', profile.hopFinish, baselineKey: 'hopFinish'),
    ]),
    _SummarySection(
        'Antrunk',
        [
          _SummaryEntry('Mundgefühl', profile.mouthfeel,
              baselineKey: 'mouthfeel'),
          _SummaryEntry('Malzaroma', profile.antrunkMalt,
              baselineKey: 'antrunkMalt'),
          _SummaryEntry('Röstmalzaroma', profile.antrunkRoast,
              baselineKey: 'antrunkRoast'),
        ],
        dividerBefore: true),
    _SummarySection('Haupttrunk', [
      _SummaryEntry('süffig', profile.smooth, baselineKey: 'smooth'),
      _SummaryEntry('vollmundig', profile.fullBody, baselineKey: 'fullBody'),
      _SummaryEntry('Malzaroma', profile.mainMalt, baselineKey: 'mainMalt'),
      _SummaryEntry('Röstaroma', profile.mainRoast, baselineKey: 'mainRoast'),
    ]),
    _SummarySection('Nachtrunk', [
      _SummaryEntry('abklingen', profile.fade, baselineKey: 'fade'),
      _SummaryEntry('erfrischend', profile.fresh, baselineKey: 'fresh'),
      _SummaryEntry('trocken', profile.dry, baselineKey: 'dry'),
      _SummaryEntry('langanhaltend', profile.lasting, baselineKey: 'lasting'),
    ]),
  ];

  final widgets = <Widget>[];
  for (final section in sections) {
    if (section.dividerBefore) {
      widgets.add(const Divider(
        height: 24,
        thickness: 1,
        color: Colors.white24,
      ));
    }
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...section.entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(left: 20, top: 4, bottom: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        entry.label,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ),
                    Text(
                      '${(entry.value * 100).round()}%',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      _formatSummaryDiff(profile, entry),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  if (profile.specialAdditions.isNotEmpty) {
    widgets.add(const Divider(
      height: 24,
      thickness: 1,
      color: Colors.white24,
    ));
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spezielle Zugaben & Lagerungen',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...profile.specialAdditions.map(
              (addition) {
                final antrunkPercent = ((1 - addition.focus) * 100).round();
                final abgangPercent = 100 - antrunkPercent;
                final intensityPercent = (addition.intensity * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(left: 20, bottom: 8),
                  child: Text(
                    '${addition.title}: Antrunk $antrunkPercent% · Abgang $abgangPercent% · Intensität $intensityPercent%',
                    style: const TextStyle(fontSize: 14),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
  if (profile.specialStorage.isNotEmpty) {
    widgets.add(
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Spezielle Lagerung',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            ...profile.specialStorage.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(left: 20, bottom: 6),
                child: Text(
                  entry,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  return widgets;
}

String _formatSummaryDiff(FineTuningProfile profile, _SummaryEntry entry) {
  final delta = profile.diff(entry.baselineKey, entry.value);
  if (delta.abs() < 0.005) return '0%';
  final sign = delta > 0 ? '+' : '-';
  return '$sign${(delta.abs() * 100).round()}%';
}
