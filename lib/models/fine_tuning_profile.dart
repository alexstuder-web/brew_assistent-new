class SpecialAddition {
  SpecialAddition({
    required this.title,
    required this.focus,
    required this.intensity,
  });

  final String title;
  final double focus;
  final double intensity;
}

class FineTuningProfile {
  FineTuningProfile({required this.beerName, required this.beerType});

  final String beerName;
  final String beerType;
  double mouthfeel = 0.0;
  double antrunkMalt = 0.0;
  double antrunkRoast = 0.0;
  double smooth = 0.0;
  double fullBody = 0.0;
  double mainMalt = 0.0;
  double mainRoast = 0.0;
  double fade = 0.0;
  double fresh = 0.0;
  double dry = 0.0;
  double lasting = 0.0;
  double hopIntensity = 0.0;
  double hopHerbal = 0.0;
  double hopFloral = 0.0;
  double hopFruity = 0.0;
  double hopNose = 0.0;
  double hopPalate = 0.0;
  double hopFinish = 0.0;
  final List<SpecialAddition> specialAdditions = [];
  final List<String> specialStorage = [];

  final Map<String, double> _baseline = {};

  void applyPreset(Map<String, double> preset) {
    _baseline
      ..clear()
      ..addAll(preset);
    hopIntensity = preset['hopIntensity'] ?? hopIntensity;
    hopHerbal = preset['hopHerbal'] ?? hopHerbal;
    hopFloral = preset['hopFloral'] ?? hopFloral;
    hopFruity = preset['hopFruity'] ?? hopFruity;
    hopNose = preset['hopNose'] ?? hopNose;
    hopPalate = preset['hopPalate'] ?? hopPalate;
    hopFinish = preset['hopFinish'] ?? hopFinish;
    mouthfeel = preset['mouthfeel'] ?? mouthfeel;
    antrunkMalt = preset['antrunkMalt'] ?? antrunkMalt;
    antrunkRoast = preset['antrunkRoast'] ?? antrunkRoast;
    smooth = preset['smooth'] ?? smooth;
    fullBody = preset['fullBody'] ?? fullBody;
    mainMalt = preset['mainMalt'] ?? mainMalt;
    mainRoast = preset['mainRoast'] ?? mainRoast;
    fade = preset['fade'] ?? fade;
    fresh = preset['fresh'] ?? fresh;
    dry = preset['dry'] ?? dry;
    lasting = preset['lasting'] ?? lasting;
  }

  double diff(String key, double current) {
    final base = _baseline[key];
    if (base == null) return 0.0;
    return current - base;
  }
}

String describeAdditionFocus(double value) {
  if (value <= 0.2) return 'Antrunk';
  if (value >= 0.8) return 'Abgang';
  if (value < 0.5) return 'Zwischenphase (Richtung Antrunk)';
  if (value > 0.5) return 'Zwischenphase (Richtung Abgang)';
  return 'Zwischenphase';
}
