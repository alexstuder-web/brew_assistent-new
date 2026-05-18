import '../models/ai_recipe.dart';
import 'dart:math' as math;
import 'brew_math.dart';

class RecipeScaler {
  /// Scales the recipe ingredients and volumes based on the blueprint provided by the AI
  /// and the user's system parameters.
  static AiRecipe scale(
    AiRecipe recipe, {
    required double bhEfficiency,
    required double targetVolumeL,
    required double fermentationLossL,
    required double postBoilLossL,
    required double boilOffPercentage,
  }) {
    // 1. Calculate intermediate volumes first (Math-First approach)
    final boilDuration = recipe.prozessdaten.boil.duration.toDouble();
    
    // V_Gärgefäß_Kalt: Volume that enters the fermenter (Net + Loss)
    final vGaergefassKalt = targetVolumeL + fermentationLossL;
    // V_Ausschlag_Heiß: Hot volume at end of boil (adjusted for shrinking)
    final vAusschlagHeiss = vGaergefassKalt / 0.96;
    // V_Koch_Ende_Heiß: Hot volume in kettle including trub loss
    final vKochEndeHeiss = vAusschlagHeiss + postBoilLossL;
    
    // Total Cold Wort Volume: The volume that actually contains the extract (Stammwürze)
    final vTotalColdWort = vKochEndeHeiss * 0.96;

    // 2. Calculate Malt for the TOTAL produced extract
    final targetSg = recipe.stammwuerzeSg ?? 1.050;
    final totalMaltKg = _calculateTotalMalt(targetSg, vTotalColdWort, bhEfficiency);

    final scaledMalts = recipe.zutaten.malts.map((m) {
      final amount = (totalMaltKg * m.proportionPercent) / 100.0;
      return Malt(
        name: m.name,
        amountKg: amount,
        proportionPercent: m.proportionPercent,
        crushGap: m.crushGap,
      );
    }).toList();

    // 3. Scale Hops and Specials (Based on Gross Cold Volume)
    // The AI blueprint is designed for 20L Gross (Ausschlagwürze).
    final scalingFactor = vTotalColdWort / 20.0;

    final scaledHops = recipe.zutaten.hops.map((h) {
      return Hop(
        name: h.name,
        alpha: h.alpha,
        amountG: h.amountG * scalingFactor,
        use: h.use,
        timeMin: h.timeMin,
      );
    }).toList();

    final scaledSpecials = recipe.zutaten.specials.map((s) {
      double? numericAmount = double.tryParse(s.amount.replaceAll(',', '.'));
      if (numericAmount != null) {
        return SpecialIngredient(
          name: s.name,
          amount: (numericAmount * scalingFactor).toStringAsFixed(1),
          unit: s.unit,
          detail: s.detail,
        );
      }
      return s;
    }).toList();

    // 4. Calculate Water Volumes for the new scale
    final evaporationFactor = 1.0 - (boilOffPercentage / 100.0 * (boilDuration / 60.0));
    final vPfannevoll = vKochEndeHeiss / evaporationFactor;

    double mashRatio = 3.5;
    final baseMaltAmount = recipe.zutaten.malts.fold<double>(0, (sum, m) => sum + m.amountKg);
    if (baseMaltAmount > 0) {
      mashRatio = recipe.prozessdaten.mash.mashWaterL / baseMaltAmount;
    }
    if (mashRatio < 2.0 || mashRatio > 5.0) mashRatio = 3.5;

    final mashWaterL = totalMaltKg * mashRatio;
    const absorption = 0.9;
    final spargeWaterL = vPfannevoll - (mashWaterL - (totalMaltKg * absorption));

    // 5. Update the Recipe Object
    return recipe.copyWith(
      zutaten: Ingredients(
        malts: scaledMalts,
        hops: scaledHops,
        yeast: recipe.zutaten.yeast,
        water: recipe.zutaten.water,
        specials: scaledSpecials,
        finings: recipe.zutaten.finings,
      ),
      prozessdaten: ProcessData(
        mash: MashPlan(
          mashWaterL: double.parse(mashWaterL.toStringAsFixed(1)),
          mashInTemp: recipe.prozessdaten.mash.mashInTemp,
          steps: recipe.prozessdaten.mash.steps,
        ),
        lauter: LauterPlan(
          spargeWaterL: double.parse(math.max(0.0, spargeWaterL).toStringAsFixed(1)),
          targetPh: recipe.prozessdaten.lauter.targetPh,
        ),
        boil: BoilPlan(
          preBoilVolumeL: double.parse(vPfannevoll.toStringAsFixed(1)),
          duration: recipe.prozessdaten.boil.duration,
        ),
        fermentation: recipe.prozessdaten.fermentation,
        packaging: recipe.prozessdaten.packaging,
        volumeCalculation: VolumeCalculationCoT(
          step1EimerKalt: double.parse(vGaergefassKalt.toStringAsFixed(1)),
          step2AusschlagHeiss: double.parse(vAusschlagHeiss.toStringAsFixed(1)),
          step3KochEndeHeiss: double.parse(vKochEndeHeiss.toStringAsFixed(1)),
          step4Pfannevoll: double.parse(vPfannevoll.toStringAsFixed(1)),
          calculationNote: 'Automatische Skalierung basierend auf Anlagen-Effizienz (${bhEfficiency.toStringAsFixed(1)}%) und Verlusten.',
        ),
      ),
    );
  }

  static double _calculateTotalMalt(double sg, double volumeL, double efficiency) {
    final plato = BrewMath.sgToPlato(sg);
    final density = 1.0 + (plato / 250.0);
    final extractKg = volumeL * density * (plato / 100.0);
    const theoreticalYield = 0.80;
    return extractKg / ((efficiency / 100.0) * theoreticalYield);
  }
}
