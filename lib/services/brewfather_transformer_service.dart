
import '../models/ai_recipe.dart';

class BrewfatherTransformerService {
  
  static Map<String, dynamic> transform(AiRecipe recipe, {String? author, bool? isPressure}) {
    // Basic defaults
    const double batchSizeVal = 20.0; // Standard falls nicht anders definiert
    const double efficiencyVal = 72.0; 

    // Calculate total Grain Amount for percentage calculation (approximate)
    double totalGrainKg = recipe.zutaten.malts.fold(0.0, (sum, m) => sum + m.amountKg);
    if (totalGrainKg == 0) totalGrainKg = 1.0; // Prevent div by zero

    // Fermentation logic
    final bool fermentationIsPressure = isPressure ?? recipe.prozessdaten.fermentation.steps.any((s) => s.pressure > 0);

    return {
      '_versionNumber': 1,
      '_init': true,
      '_type': 'recipe',
      'ibuFormula': 'tinseth',
      'fgFormula': 'normal',
      'name': recipe.basisBier,
      'author': author ?? 'AI Brew Genius',
      'tags': ['AI Brew Genius'],
      'searchTags': ['AI Brew Genius'],
      'type': 'All Grain',
      'batchSize': batchSizeVal,
      'boilTime': recipe.prozessdaten.boil.duration,
      'efficiency': efficiencyVal,
      'mashEfficiency': efficiencyVal,
      'brewhouseEfficiency': efficiencyVal,
      'og': recipe.stammwuerzeSg,
      'fg': recipe.restextraktSg,
      'ibu': recipe.ibu,
      'estOg': recipe.stammwuerzeSg,
      'estFg': recipe.restextraktSg,
      'estIbu': recipe.ibu,
      'preBoilGravity': recipe.stammwuerzeSg, // Use OG as a safe fallback if pre-boil is not explicitly provided
      'postBoilGravity': recipe.stammwuerzeSg,
      'abv': recipe.alkoholgehalt,
      'attenuation': (recipe.stammwuerzeSg != null && recipe.restextraktSg != null && recipe.stammwuerzeSg! > 1.0) 
          ? ((recipe.stammwuerzeSg! - recipe.restextraktSg!) / (recipe.stammwuerzeSg! - 1.0) * 100).roundToDouble()
          : 0.0,
      'boilSize': recipe.prozessdaten.boil.preBoilVolumeL > 0 
          ? recipe.prozessdaten.boil.preBoilVolumeL 
          : batchSizeVal + 3.0, // Fallback boil size
      'equipment': {
        'name': 'AI Generated Profile',
        'efficiency': efficiencyVal / 100, // 0.72
        'batchSize': batchSizeVal,
        'boilTime': recipe.prozessdaten.boil.duration,
        'boilOffPerHr': 0.01,
        'postBoilKettleVol': 0,
        'fermenterVolume': 0,
        'bottlingVolume': 0,
        'fermenterLossEstimate': 0,
        'evaporationRate': 0,
      },
      'notes': _buildNotes(recipe),
      
      // Style
      'style': {
        'name': recipe.bjcpStyle?.name ?? recipe.bierTyp,
        'category': recipe.bjcpStyle?.category ?? 'Custom',
        'categoryNumber': recipe.bjcpStyle?.categoryNumber,
        'styleLetter': recipe.bjcpStyle?.styleLetter,
        'styleGuide': recipe.bjcpStyle?.guide ?? 'Custom',
        'type': 'Beer',
      },

      // Fermentables (Malts)
      'fermentables': recipe.zutaten.malts.map((m) {
        return {
          'name': m.name,
          'amount': m.amountKg,
          'unit': 'kg',
          'type': 'Grain',
          'percentage': (m.amountKg / totalGrainKg) * 100,
          '_id': 'generate_${DateTime.now().microsecondsSinceEpoch}_${m.name.hashCode}',
        };
      }).toList(),

      // Hops
      'hops': recipe.zutaten.hops.map((h) {
        return {
          'name': h.name,
          'amount': h.amountG,
          'unit': 'g',
          'alpha': h.alpha,
          'use': _mapHopUse(h.use),
          'time': h.timeMin,
          'type': 'Pellet',
          'ibu': recipe.ibu != null ? (recipe.ibu! / recipe.zutaten.hops.length) : 0,
          '_id': 'generate_${DateTime.now().microsecondsSinceEpoch}_${h.name.hashCode}',
        };
      }).toList(),

      // Yeasts
      'yeasts': [
        {
          'name': recipe.zutaten.yeast.name,
          'amount': 1,
          'unit': 'pkg',
          'type': _mapYeastType(recipe.zutaten.yeast.type),
           '_id': 'generate_${DateTime.now().microsecondsSinceEpoch}_yeast',
        }
      ],

      // Mash Steps
      'mash': {
        'name': 'AI Generated Mash Profile',
        'steps': recipe.prozessdaten.mash.steps.map((s) {
           return {
             'name': s.stage,
             'stepTemp': s.temp,
             'stepTime': s.duration,
             'type': 'Temperature',
           };
        }).toList(),
      },

      // Fermentation
      'fermentation': {
        'name': 'AI Generated Fermentation Profile',
        'isPressure': fermentationIsPressure,
        'steps': recipe.prozessdaten.fermentation.steps.asMap().entries.map((entry) {
          final idx = entry.key;
          final s = entry.value;
          final type = _mapFermentationStepType(s.phase);
          
          // Fallback: If global isPressure but this step has 0, set 1.0 bar for the first step
          double? stepPressure = s.pressure > 0 ? s.pressure : null;
          if (stepPressure == null && fermentationIsPressure && (idx == 0 || type == 'Primary')) {
             stepPressure = 1.0; 
          }

          return {
            'name': s.phase,
            'temp': s.temp,
            'stepTemp': s.temp,
            'displayStepTemp': s.temp,
            'time': s.days,
            'stepTime': s.days,
            'type': type,
            'pressure': stepPressure,
            'displayPressure': stepPressure,
          };
        }).toList(),
      },
      'primaryTemp': recipe.prozessdaten.fermentation.pitchTemp > 0 
          ? recipe.prozessdaten.fermentation.pitchTemp 
          : (recipe.prozessdaten.fermentation.steps.isNotEmpty 
              ? recipe.prozessdaten.fermentation.steps.first.temp 
              : 12.0),

      // Water Target Profile
      'water': {
        'target': {
          'name': 'AI Target Profile',
          'ca': recipe.zutaten.water.ca,
          'mg': recipe.zutaten.water.mg,
          'na': recipe.zutaten.water.na,
          'cl': recipe.zutaten.water.cl,
          'so4': recipe.zutaten.water.so4,
          'hco3': recipe.zutaten.water.hco3,
        }
      },

      // Image Fields
      'thumb': recipe.generatedImage != null
          ? 'data:image/jpeg;base64,${recipe.generatedImage}'
          : null,
      'image': recipe.generatedImage != null
          ? 'data:image/jpeg;base64,${recipe.generatedImage}'
          : null,
      'img': recipe.generatedImage != null
          ? 'data:image/jpeg;base64,${recipe.generatedImage}'
          : null,

      // Metadata
      '_timestamp': DateTime.now().toIso8601String(),
      '_timestamp_ms': DateTime.now().millisecondsSinceEpoch,
    };
  }

  static String _buildNotes(AiRecipe recipe) {
    final buffer = StringBuffer();
    buffer.writeln('Generiertes Rezept für: ${recipe.bierTyp}');
    buffer.writeln('Stammwürze: ${recipe.stammwuerzeSg} SG');
    buffer.writeln('Alkohol: ${recipe.alkoholgehalt} %');
    buffer.writeln();
    buffer.writeln('Notizen:');
    for (var n in recipe.notizen) {
      buffer.writeln('- $n');
    }
    return buffer.toString();
  }

  static String _mapHopUse(String use) {
    final u = use.toLowerCase();
    if (u.contains('kochen') || u.contains('boil') || u.contains('würze')) return 'Boil';
    if (u.contains('whirlpool')) return 'Aroma';
    if (u.contains('stopfen') || u.contains('dry')) return 'Dry Hop';
    if (u.contains('vorderwürze') || u.contains('first')) return 'First Wort';
    if (u.contains('maische') || u.contains('mash')) return 'Mash';
    return 'Boil'; // Default
  }

  static String _mapYeastType(String type) {
    final t = type.toLowerCase();
    if (t.contains('lager') || t.contains('unter')) return 'Lager';
    if (t.contains('ale') || t.contains('ober')) return 'Ale';
    if (t.contains('hefe') || t.contains('weizen')) return 'Wheat';
    return 'Ale'; // Default
  }

  static String _mapFermentationStepType(String phase) {
    final p = phase.toLowerCase();
    if (p.contains('haupt') || p.contains('primär')) return 'Primary';
    if (p.contains('nach') || p.contains('sekundär')) return 'Secondary';
    if (p.contains('reif') || p.contains('lagern') || p.contains('aging')) return 'Aging';
    if (p.contains('cold') || p.contains('crash')) return 'Crash';
    if (p.contains('karbo') || p.contains('condit') || p.contains('flasche')) return 'Conditioning';
    if (p.contains('tertiär')) return 'Tertiary';
    
    return 'Primary'; // Default
  }
}
