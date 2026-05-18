import 'package:flutter/material.dart';
import '../models/fine_tuning_profile.dart';
import '../widgets/user_name_banner.dart';
import '../widgets/fine_tuning_widgets.dart';
import 'special_additions_page.dart';

class FineTuningAftertastePage extends StatefulWidget {
  const FineTuningAftertastePage({super.key, required this.profile});

  final FineTuningProfile profile;

  @override
  State<FineTuningAftertastePage> createState() =>
      _FineTuningAftertastePageState();
}

class _FineTuningAftertastePageState extends State<FineTuningAftertastePage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Feintuning Nachtrunk'),
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
                  'Feintuning für ${widget.profile.beerName} · Nachtrunk',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                SliderBlock(
                  label: 'abklingen',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.fade,
                  baselineKey: 'fade',
                ),
                FineSlider(
                  value: widget.profile.fade,
                  onChanged: (v) => setState(() => widget.profile.fade = v),
                  baselineKey: 'fade',
                ),
                const SizedBox(height: 12),
                SliderBlock(
                  label: 'erfrischend',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.fresh,
                  baselineKey: 'fresh',
                ),
                FineSlider(
                  value: widget.profile.fresh,
                  onChanged: (v) => setState(() => widget.profile.fresh = v),
                  baselineKey: 'fresh',
                ),
                const SizedBox(height: 12),
                SliderBlock(
                  label: 'trocken',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.dry,
                  baselineKey: 'dry',
                ),
                FineSlider(
                  value: widget.profile.dry,
                  onChanged: (v) => setState(() => widget.profile.dry = v),
                  baselineKey: 'dry',
                ),
                const SizedBox(height: 12),
                SliderBlock(
                  label: 'langanhaltend',
                  minLabel: 'leicht',
                  maxLabel: 'kräftig',
                  value: widget.profile.lasting,
                  baselineKey: 'lasting',
                ),
                FineSlider(
                  value: widget.profile.lasting,
                  onChanged: (v) => setState(() => widget.profile.lasting = v),
                  baselineKey: 'lasting',
                ),
                const SizedBox(height: 32),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SpecialAdditionsPage(
                            profile: widget.profile,
                          ),
                        ),
                      );
                    },
                    child: const Text('Spezielle Zugaben festlegen'),
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
