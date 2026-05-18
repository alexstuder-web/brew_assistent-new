import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart';
import '../models/beer_presets.dart';
import '../widgets/user_name_banner.dart';
import '../widgets/fine_tuning_widgets.dart';
import 'fine_tuning_taste_page.dart';

class FineTuningGeneralPage extends StatefulWidget {
  const FineTuningGeneralPage({
    super.key,
    required this.beerName,
    required this.beerType,
  });

  final String beerName;
  final String beerType;

  @override
  State<FineTuningGeneralPage> createState() => _FineTuningGeneralPageState();
}

class _FineTuningGeneralPageState extends State<FineTuningGeneralPage> {
  late final FineTuningProfile profile;

  @override
  void initState() {
    super.initState();
    profile =
        FineTuningProfile(beerName: widget.beerName, beerType: widget.beerType);
    final preset = beerPresets[widget.beerName];
    if (preset != null) {
      profile.applyPreset(preset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feintuning Generell'),
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const UserNameBanner(),
              const SizedBox(height: 20),
              Text(
                'Erste Anpassungen für ${profile.beerName}',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Hopfen',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              IndentedBlock(
                child: Column(
                  children: [
                    SliderBlock(
                      label: 'Aromaintensität',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopIntensity,
                      baselineKey: 'hopIntensity',
                    ),
                    FineSlider(
                      value: profile.hopIntensity,
                      onChanged: (v) =>
                          setState(() => profile.hopIntensity = v),
                      baselineKey: 'hopIntensity',
                    ),
                    const SizedBox(height: 12),
                    SliderBlock(
                      label: 'Kräuterig',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopHerbal,
                      baselineKey: 'hopHerbal',
                    ),
                    FineSlider(
                      value: profile.hopHerbal,
                      onChanged: (v) => setState(() => profile.hopHerbal = v),
                      baselineKey: 'hopHerbal',
                    ),
                    const SizedBox(height: 12),
                    SliderBlock(
                      label: 'Blumig',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopFloral,
                      baselineKey: 'hopFloral',
                    ),
                    FineSlider(
                      value: profile.hopFloral,
                      onChanged: (v) => setState(() => profile.hopFloral = v),
                      baselineKey: 'hopFloral',
                    ),
                    const SizedBox(height: 12),
                    SliderBlock(
                      label: 'Fruchtig',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopFruity,
                      baselineKey: 'hopFruity',
                    ),
                    FineSlider(
                      value: profile.hopFruity,
                      onChanged: (v) => setState(() => profile.hopFruity = v),
                      baselineKey: 'hopFruity',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Verteilung',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              IndentedBlock(
                child: Column(
                  children: [
                    SliderBlock(
                      label: 'Nase',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopNose,
                      baselineKey: 'hopNose',
                    ),
                    FineSlider(
                      value: profile.hopNose,
                      onChanged: (v) => setState(() => profile.hopNose = v),
                      baselineKey: 'hopNose',
                    ),
                    const SizedBox(height: 12),
                    SliderBlock(
                      label: 'Gaumen',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopPalate,
                      baselineKey: 'hopPalate',
                    ),
                    FineSlider(
                      value: profile.hopPalate,
                      onChanged: (v) => setState(() => profile.hopPalate = v),
                      baselineKey: 'hopPalate',
                    ),
                    const SizedBox(height: 12),
                    SliderBlock(
                      label: 'Abgang',
                      minLabel: 'wenig',
                      maxLabel: 'stark',
                      value: profile.hopFinish,
                      baselineKey: 'hopFinish',
                    ),
                    FineSlider(
                      value: profile.hopFinish,
                      onChanged: (v) => setState(() => profile.hopFinish = v),
                      baselineKey: 'hopFinish',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Align(
                alignment: Alignment.bottomRight,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => FineTuningPage(profile: profile),
                      ),
                    );
                  },
                  child: const Text('Weiter zu Feintuning Antrunk'),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
