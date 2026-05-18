import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart';
import '../widgets/user_name_banner.dart';
import '../widgets/fine_tuning_widgets.dart';
import 'fine_tuning_main_trunk_page.dart';

class FineTuningPage extends StatefulWidget {
  const FineTuningPage({super.key, required this.profile});

  final FineTuningProfile profile;

  @override
  State<FineTuningPage> createState() => _FineTuningPageState();
}

class _FineTuningPageState extends State<FineTuningPage> {
  FineTuningProfile get profile => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feintuning Antrunk'),
        centerTitle: true,
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
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const Align(
              alignment: Alignment.centerLeft,
              child: UserNameBanner(),
            ),
            const SizedBox(height: 20),
            Text(
              'Lass uns ein neues leckeres und einzigartiges ${profile.beerName} Bier entwerfen',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SliderBlock(
              label: 'Mundgefühl',
              minLabel: 'Wasser',
              maxLabel: 'Motorenöl',
              value: profile.mouthfeel,
              baselineKey: 'mouthfeel',
            ),
            FineSlider(
              value: profile.mouthfeel,
              onChanged: (v) => setState(() => profile.mouthfeel = v),
              baselineKey: 'mouthfeel',
            ),
            const SizedBox(height: 12),
            SliderBlock(
              label: 'Malzaroma',
              minLabel: 'leicht',
              maxLabel: 'kräftig',
              value: profile.antrunkMalt,
              baselineKey: 'antrunkMalt',
            ),
            FineSlider(
              value: profile.antrunkMalt,
              onChanged: (v) => setState(() => profile.antrunkMalt = v),
              baselineKey: 'antrunkMalt',
            ),
            const SizedBox(height: 12),
            SliderBlock(
              label: 'Röstmalzaroma',
              minLabel: 'leicht',
              maxLabel: 'kräftig',
              value: profile.antrunkRoast,
              baselineKey: 'antrunkRoast',
            ),
            FineSlider(
              value: profile.antrunkRoast,
              onChanged: (v) => setState(() => profile.antrunkRoast = v),
              baselineKey: 'antrunkRoast',
            ),
            const Spacer(),
            Align(
              alignment: Alignment.bottomRight,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => FineTuningMainTrunkPage(profile: profile),
                    ),
                  );
                },
                child: const Text('Weiter zu Feintuning Haupttrunk'),
              ),
            )
          ],
        ),
      ),
    );
  }
}
