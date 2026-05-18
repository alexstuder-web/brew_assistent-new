import 'dart:math';
import '../models/water_profile.dart'; // Source
import '../models/ai_recipe.dart'; // Target

class SaltAddition {
  final String name;
  final double amountG;
  final String timing; // "Maischen" or "Kochen"

  SaltAddition({required this.name, required this.amountG, required this.timing});
}

class WaterCalculator {
  // Constants for 1g in 10L (mg/L)
  // Data roughly from Bru'n Water or similar
  static const double _epsomMg = 9.86;
  static const double _epsomSO4 = 39.0;
  
  static const double _gypsumCa = 23.28;
  static const double _gypsumSO4 = 55.78;
  
  static const double _cacl2Ca = 27.26;
  static const double _cacl2Cl = 48.23;
  
  static const double _bakingSodaNa = 27.37;
  static const double _bakingSodaHCO3 = 71.85;



  static List<SaltAddition> calculate({
    required WaterProfile source,
    required WaterProfileTargets target,
    required double mashVolumeL,
    required double spargeVolumeL,
    required String strategy, // "Maische", "Kochen", "Beides", "Maische_und_Nachguss"
  }) {
    // Strategy Interpretation:
    // 'Maische' -> Treat MashVolume. Add everything to Mash.
    // 'Kochen' -> Treat TotalVolume? Or BoilVolume? Usually user means "Treat the full water amount in the boil kettle" (rare) or "Add to boil". 
    //            Let's assume "Kochen" means treat the full water volume but add it to the boil.
    // 'Beides' -> Treat MashVolume (add to Mash) AND Treat SpargeVolume (add to Sparge or Boil).
    // 'Maische_und_Nachguss' -> Same as Beides.

    bool treatMash = true;
    bool treatSparge = false;


    if (strategy.toLowerCase().contains('kochen') && !strategy.toLowerCase().contains('maische')) {
       // Only Boil? Treat full volume?
       treatMash = false;
       treatSparge = false; // logic below will handle 'total'
    } else if (strategy.toLowerCase().contains('beides') || strategy.toLowerCase().contains('nachguss')) {
      treatSparge = true;
    }

    List<SaltAddition> additions = [];

    if (treatMash) {
      additions.addAll(_calcForVolume(source, target, mashVolumeL, 'Maischen'));
    }
    
    if (treatSparge) {
      String label = strategy.toLowerCase().contains('nachguss') ? 'Nachguss' : 'Kochen';
      additions.addAll(_calcForVolume(source, target, spargeVolumeL, label));
    }

    if (!treatMash && !treatSparge) {
        // Assume 'Kochen' means treating the total water (Mash + Sparge) and adding at Boil 
        // OR Treating PreBoil volume.
        // Let's use Sum of Mash+Sparge for safety if preBoil not available, but 'calculate' doesn't have preboil.
        // We'll use mash + sparge as total water processed.
        double totalL = mashVolumeL + spargeVolumeL;
        additions.addAll(_calcForVolume(source, target, totalL, 'Kochen'));
    }

    return additions;
  }

  static List<SaltAddition> _calcForVolume(
      WaterProfile src, WaterProfileTargets tgt, double liters, String timing) {
    if (liters <= 0) return [];
    
    List<SaltAddition> result = [];
    
    // Deltas (Target - Source)
    double dMg = max(0, tgt.mg - src.magnesiumPpm);
    double dSO4 = max(0, tgt.so4 - src.sulfatePpm);
    double dCa = max(0, tgt.ca - src.calciumPpm);
    double dCl = max(0, tgt.cl - src.chloridePpm);
    double dNa = max(0, tgt.na - src.sodiumPpm);
    double dHCO3 = max(0, tgt.hco3 - src.bicarbonatePpm);
    
    // 1. Epsom Salt (MgSO4) -> Match Mg
    // Effect per gram: _epsomMg * 10 / liters
    double epsomFactorMg = _epsomMg * 10 / liters;
    double epsomFactorSO4 = _epsomSO4 * 10 / liters;
    
    double epsomG = 0;
    if (epsomFactorMg > 0 && dMg > 0) {
      epsomG = dMg / epsomFactorMg;
      // Update deficits
      dMg = 0; // Satisfied
      // It adds SO4 too
      double so4Added = epsomG * epsomFactorSO4;
      dSO4 = max(0, dSO4 - so4Added);
      
      result.add(SaltAddition(name: 'Bittersalz (MgSO4)', amountG: epsomG, timing: timing));
    }
    
    // 2. Gypsum (CaSO4) -> Match remaining SO4
    double gypsumFactorCa = _gypsumCa * 10 / liters;
    double gypsumFactorSO4 = _gypsumSO4 * 10 / liters;
    
    double gypsumG = 0;
    if (gypsumFactorSO4 > 0 && dSO4 > 0) {
       gypsumG = dSO4 / gypsumFactorSO4;
       // Update
       dSO4 = 0; 
       double caAdded = gypsumG * gypsumFactorCa;
       dCa = max(0, dCa - caAdded);
       
       result.add(SaltAddition(name: 'Braugips (CaSO4)', amountG: gypsumG, timing: timing));
    }
    
    // 3. Calcium Chloride (CaCl2) -> Match remaining Cl
    double cacl2FactorCa = _cacl2Ca * 10 / liters;
    double cacl2FactorCl = _cacl2Cl * 10 / liters;
    
    double cacl2G = 0;
    if (cacl2FactorCl > 0 && dCl > 0) {
       cacl2G = dCl / cacl2FactorCl;
       // Update
       dCl = 0;
       double caAdded = cacl2G * cacl2FactorCa;
       dCa = max(0, dCa - caAdded);
       
       result.add(SaltAddition(name: 'Calciumchlorid (CaCl2)', amountG: cacl2G, timing: timing));
    }
    
    // 4. Baking Soda (NaHCO3) -> Match remaining HCO3 (Alkalinity) or Na
    // Prioritize HCO3 if explicit target
    double sodaFactorNa = _bakingSodaNa * 10 / liters;
    double sodaFactorHCO3 = _bakingSodaHCO3 * 10 / liters;
    
    double sodaG = 0;
    if (sodaFactorHCO3 > 0 && dHCO3 > 0) {
       sodaG = dHCO3 / sodaFactorHCO3;
       // Update
       dHCO3 = 0;
       double naAdded = sodaG * sodaFactorNa;
       dNa = max(0, dNa - naAdded);
       
       result.add(SaltAddition(name: 'Natron (NaHCO3)', amountG: sodaG, timing: timing));
    }
    
    // 5. Check Na? If dNa still high, add Salt (NaCl)
    double naclFactorNa = 39.3 * 10 / liters; // NaCl is ~39.3% Na, 60.7% Cl
    
    if (naclFactorNa > 0 && dNa > 5) { // Threshold 5mg/L ignore
       double saltG = dNa / naclFactorNa;
       result.add(SaltAddition(name: 'Kochsalz (NaCl)', amountG: saltG, timing: timing));
    }

    return result;
  }
}
