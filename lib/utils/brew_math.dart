class BrewMath {
  /// Converts Specific Gravity (SG) to Plato scale.
  /// Formula: P = 259 * (1 - (1/SG))
  static double sgToPlato(double sg) {
    if (sg <= 1.0) return 0.0;
    return 259.0 * (1.0 - (1.0 / sg));
  }

  /// Calculates the Brewhouse Efficiency (BHE) based on brew day results.
  /// 
  /// [volumeL] - Volume of cold wort in the fermenter
  /// [ogSg] - Measured Original Gravity in SG
  /// [totalMaltKg] - Total weight of malt used
  /// [theoreticalYield] - The potential extract of the malt (standard is 0.80 or 80%)
  static double calculateEfficiency({
    required double volumeL,
    required double ogSg,
    required double totalMaltKg,
    double theoreticalYield = 0.80,
  }) {
    if (totalMaltKg <= 0) return 0.0;
    
    final plato = sgToPlato(ogSg);
    // Density approximation: 1 + (Plato / 250)
    final density = 1.0 + (plato / 250.0);
    
    // Extract in kg = Volume * Density * (Plato / 100)
    final extractKg = volumeL * density * (plato / 100.0);
    
    // Efficiency = (Actual Extract / Theoretical Max Extract) * 100
    // Max Extract = Malt Weight * Theoretical Yield
    final efficiency = (extractKg / (totalMaltKg * theoreticalYield)) * 100.0;
    
    return efficiency;
  }
}
