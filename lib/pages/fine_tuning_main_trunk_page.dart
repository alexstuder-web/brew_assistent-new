import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart';
import '../widgets/user_name_banner.dart';
import '../widgets/fine_tuning_widgets.dart';
import 'fine_tuning_aftertaste_page.dart';

class FineTuningMainTrunkPage extends StatefulWidget {
  const FineTuningMainTrunkPage({super.key, required this.profile});

  final FineTuningProfile profile;

  @override
  State<FineTuningMainTrunkPage> createState() =>
      _FineTuningMainTrunkPageState();
}

class _FineTuningMainTrunkPageState extends State<FineTuningMainTrunkPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feintuning Haupttrunk'),
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
      body: LayoutBuilder(
        builder: (context, constraints) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const UserNameBanner(),
                const SizedBox(height: 20),
                Text(
                  'Feintuning für ${widget.profile.beerName} · Haupttrunk',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SliderBlock(
                  label: 'süffig',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.smooth,
                  baselineKey: 'smooth',
                ),
                FineSlider(
                  value: widget.profile.smooth,
                  onChanged: (v) => setState(() => widget.profile.smooth = v),
                  baselineKey: 'smooth',
                ),
                const SizedBox(height: 12),
                SliderBlock(
                  label: 'vollmundig',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.fullBody,
                  baselineKey: 'fullBody',
                ),
                FineSlider(
                  value: widget.profile.fullBody,
                  onChanged: (v) => setState(() => widget.profile.fullBody = v),
                  baselineKey: 'fullBody',
                ),
                const SizedBox(height: 12),
                SliderBlock(
                  label: 'Malzaroma',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.mainMalt,
                  baselineKey: 'mainMalt',
                ),
                FineSlider(
                  value: widget.profile.mainMalt,
                  onChanged: (v) => setState(() => widget.profile.mainMalt = v),
                  baselineKey: 'mainMalt',
                ),
                const SizedBox(height: 12),
                SliderBlock(
                  label: 'Röstaroma',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.mainRoast,
                  baselineKey: 'mainRoast',
                ),
                FineSlider(
                  value: widget.profile.mainRoast,
                  onChanged: (v) =>
                      setState(() => widget.profile.mainRoast = v),
                  baselineKey: 'mainRoast',
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              FineTuningAftertastePage(profile: widget.profile),
                        ),
                      );
                    },
                    child: const Text('Weiter zu Feintuning Nachtrunk'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
