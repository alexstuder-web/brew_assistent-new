import 'package:flutter/material.dart';
import '../widgets/user_name_banner.dart';
import 'fine_tuning_general_page.dart';

class DiscoveryWelcomePage extends StatefulWidget {
  const DiscoveryWelcomePage({super.key});

  static const String routeName = '/discover';

  @override
  State<DiscoveryWelcomePage> createState() => _DiscoveryWelcomePageState();
}

class _DiscoveryWelcomePageState extends State<DiscoveryWelcomePage> {
  final Map<String, List<String>> _beerGroups = const {
    'Ale': ['Porter', 'Stout', 'Pale Ale', 'IPA', 'Weizen', 'Belgian'],
    'Lager': ['Pale Lager', 'Schwarzbier', 'Märzen', 'Bock'],
  };

  String? _selectedBeer;

  Future<void> _handleSelection(String value) async {
    setState(() {
      _selectedBeer = value;
    });

    final beerType = _beerGroups.entries
        .firstWhere(
          (entry) => entry.value.contains(value),
          orElse: () => const MapEntry('Unbekannt', <String>[]),
        )
        .key;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excelente Wahl. Los gehts ...'),
        content: Text('„$value“ auswählen und weitermachen?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Weiter'),
          ),
        ],
      ),
    );

    if (!mounted) return;

    if (proceed == true) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              FineTuningGeneralPage(beerName: value, beerType: beerType),
        ),
      );
      if (!mounted) return;
      setState(() {
        _selectedBeer = null;
      });
    } else {
      setState(() {
        _selectedBeer = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AiBrewGenius'),
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const UserNameBanner(),
            const SizedBox(height: 20),
            const Text(
              'Wähle die Basis deines neuen Bieres',
              style: TextStyle(fontSize: 26, letterSpacing: 1.2),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: ListView(
                children: _beerGroups.entries
                    .map((entry) => Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: _BeerGroup(
                            title: entry.key,
                            beers: entry.value,
                            selected: _selectedBeer,
                            onSelected: _handleSelection,
                          ),
                        ))
                    .toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BeerGroup extends StatelessWidget {
  const _BeerGroup({
    required this.title,
    required this.beers,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<String> beers;
  final String? selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 16,
          runSpacing: 12,
          children: beers
              .map(
                (beer) => _BeerChoice(
                  label: beer,
                  groupValue: selected,
                  onTap: () => onSelected(beer),
                ),
              )
              .toList(),
        ),
      ],
    );
  }
}

class _BeerChoice extends StatelessWidget {
  const _BeerChoice({
    required this.label,
    required this.groupValue,
    required this.onTap,
  });

  final String label;
  final String? groupValue;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isSelected = groupValue == label;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? const Color(0xFF2563EB) : Colors.white24,
            width: 2,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? const Color(0xFF2563EB) : Colors.white54,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontSize: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
