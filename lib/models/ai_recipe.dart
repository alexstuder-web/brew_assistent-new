import 'image_attachment.dart';

class AiRecipe {
  final String? id;
  final String basisBier;
  final String bierTyp;
  final BjcpStyle? bjcpStyle;
  final double? stammwuerzeSg;
  final double? restextraktSg;
  final double? alkoholgehalt;
  final double? ibu;
  final Ingredients zutaten;
  final ProcessData prozessdaten;
  final List<String> notizen;
  final String? generatedImage;
  final bool canPressurize;
  ImageAttachment? sourceImage;

  AiRecipe({
    this.id,
    required this.basisBier,
    required this.bierTyp,
    this.bjcpStyle,
    this.stammwuerzeSg,
    this.restextraktSg,
    this.alkoholgehalt,
    this.ibu,
    required this.zutaten,
    required this.prozessdaten,
    required this.notizen,
    this.sourceImage,
    this.generatedImage,
    this.canPressurize = false,
  });

  AiRecipe copyWith({
    String? id,
    String? basisBier,
    String? bierTyp,
    BjcpStyle? bjcpStyle,
    double? stammwuerzeSg,
    double? restextraktSg,
    double? alkoholgehalt,
    double? ibu,
    Ingredients? zutaten,
    ProcessData? prozessdaten,
    List<String>? notizen,
    ImageAttachment? sourceImage,
    String? generatedImage,
    bool? canPressurize,
  }) {
    return AiRecipe(
      id: id ?? this.id,
      basisBier: basisBier ?? this.basisBier,
      bierTyp: bierTyp ?? this.bierTyp,
      bjcpStyle: bjcpStyle ?? this.bjcpStyle,
      stammwuerzeSg: stammwuerzeSg ?? this.stammwuerzeSg,
      restextraktSg: restextraktSg ?? this.restextraktSg,
      alkoholgehalt: alkoholgehalt ?? this.alkoholgehalt,
      ibu: ibu ?? this.ibu,
      zutaten: zutaten ?? this.zutaten,
      prozessdaten: prozessdaten ?? this.prozessdaten,
      notizen: notizen ?? this.notizen,
      sourceImage: sourceImage ?? this.sourceImage,
      generatedImage: generatedImage ?? this.generatedImage,
      canPressurize: canPressurize ?? this.canPressurize,
    );
  }

  factory AiRecipe.fromJson(Map<String, dynamic> json) {
    return AiRecipe(
      id: json['id'] as String?,
      basisBier: json['basis_bier'] ?? '',
      bierTyp: json['bier_typ'] ?? '',
      bjcpStyle: json['bjcp_stil'] != null ? BjcpStyle.fromJson(json['bjcp_stil']) : null,
      stammwuerzeSg: (json['stammwuerze_sg'] as num?)?.toDouble(),
      restextraktSg: (json['restextrakt_sg'] as num?)?.toDouble(),
      alkoholgehalt: (json['alkoholgehalt_vol_prozent'] as num?)?.toDouble(),
      ibu: (json['ibu'] as num?)?.toDouble() ?? (json['EBU'] as num?)?.toDouble(),
      zutaten: Ingredients.fromJson(json['Zutaten'] ?? {}),
      prozessdaten: ProcessData.fromJson(json['Prozessdaten'] ?? {}),
      notizen: (json['Notizen'] as List?)?.map((e) => e.toString()).toList() ?? [],
      generatedImage: json['generated_image'],
      canPressurize: json['can_pressurize'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'basis_bier': basisBier,
      'bier_typ': bierTyp,
      'bjcp_stil': bjcpStyle?.toJson(),
      'stammwuerze_sg': stammwuerzeSg,
      'restextrakt_sg': restextraktSg,
      'alkoholgehalt_vol_prozent': alkoholgehalt,
      'ibu': ibu,
      'Zutaten': zutaten.toJson(),
      'Prozessdaten': prozessdaten.toJson(),
      'Notizen': notizen,
      'can_pressurize': canPressurize,
    };
  }
}

class BjcpStyle {
  final String name;
  final String category;
  final String categoryNumber;
  final String styleLetter;
  final String guide;

  BjcpStyle({
    required this.name,
    required this.category,
    required this.categoryNumber,
    required this.styleLetter,
    required this.guide,
  });

  factory BjcpStyle.fromJson(Map<String, dynamic> json) {
    return BjcpStyle(
      name: json['name'] ?? '',
      category: json['kategorie'] ?? '',
      categoryNumber: json['kategorie_nummer'] ?? '',
      styleLetter: json['stil_buchstabe'] ?? '',
      guide: json['guide'] ?? 'BJCP 2021',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'kategorie': category,
      'kategorie_nummer': categoryNumber,
      'stil_buchstabe': styleLetter,
      'guide': guide,
    };
  }
}


class Ingredients {
  final List<Malt> malts;
  final List<Hop> hops;
  final Yeast yeast;
  final WaterProfileTargets water;
  final List<SpecialIngredient> specials;
  final List<FiningAgentRef> finings;

  Ingredients({
    required this.malts,
    required this.hops,
    required this.yeast,
    required this.water,
    required this.specials,
    required this.finings,
  });

  factory Ingredients.fromJson(Map<String, dynamic> json) {
    return Ingredients(
      malts: (json['Original_Malz'] as List?)?.map((e) => Malt.fromJson(e)).toList() ?? [],
      hops: (json['Original_Hopfen'] as List?)?.map((e) => Hop.fromJson(e)).toList() ?? [],
      yeast: Yeast.fromJson(json['Original_Hefe'] ?? {}),
      water: WaterProfileTargets.fromJson(json['Wasserprofil_Zielwerte'] ?? {}),
      specials: (json['Spezialzutaten'] as List?)?.map((e) => SpecialIngredient.fromJson(e)).toList() ?? [],
      finings: (json['Klaer_und_Schonungsmittel'] as List?)?.map((e) => FiningAgentRef.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Original_Malz': malts.map((e) => e.toJson()).toList(),
      'Original_Hopfen': hops.map((e) => e.toJson()).toList(),
      'Original_Hefe': yeast.toJson(),
      'Wasserprofil_Zielwerte': water.toJson(),
      'Spezialzutaten': specials.map((e) => e.toJson()).toList(),
      'Klaer_und_Schonungsmittel': finings.map((e) => e.toJson()).toList(),
    };
  }
}

class Malt {
  final String name;
  final double amountKg;
  final int proportionPercent;
  final double crushGap;

  Malt({required this.name, required this.amountKg, required this.proportionPercent, required this.crushGap});

  factory Malt.fromJson(Map<String, dynamic> json) {
    return Malt(
      name: json['Name'] ?? 'Unbekannt',
      amountKg: (json['Menge_kg'] as num?)?.toDouble() ?? 0.0,
      proportionPercent: (json['Anteil_Prozent'] as num?)?.toInt() ?? 0,
      crushGap: (json['Optimales_Schrot_Spaltmass_mm'] as num?)?.toDouble() ?? 1.2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Menge_kg': amountKg,
      'Anteil_Prozent': proportionPercent,
      'Optimales_Schrot_Spaltmass_mm': crushGap,
    };
  }
}

class Hop {
  final String name;
  final double alpha;
  final double amountG;
  final String use;
  final int timeMin;

  Hop({required this.name, required this.alpha, required this.amountG, required this.use, required this.timeMin});

  factory Hop.fromJson(Map<String, dynamic> json) {
    return Hop(
      name: json['Sortenname'] ?? 'Unbekannt',
      alpha: (json['Alpha_Saeure'] as num?)?.toDouble() ?? 0.0,
      amountG: (json['Menge_g'] as num?)?.toDouble() ?? 0.0,
      use: json['Einsatz'] ?? '',
      timeMin: (json['Zeit_min'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Sortenname': name,
      'Alpha_Saeure': alpha,
      'Menge_g': amountG,
      'Einsatz': use,
      'Zeit_min': timeMin,
    };
  }
}

class Yeast {
  final String name;
  final String type;
  final String amount;
  final bool procurementNeeded;

  Yeast({
    required this.name,
    required this.type,
    required this.amount,
    required this.procurementNeeded,
  });

  factory Yeast.fromJson(Map<String, dynamic> json) {
    return Yeast(
      name: json['Name'] ?? '',
      type: json['Typ'] ?? '',
      amount: json['Menge_Packungen_oder_ml'] ?? '',
      procurementNeeded: json['Beschaffung_Notwendig'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Typ': type,
      'Menge_Packungen_oder_ml': amount,
      'Beschaffung_Notwendig': procurementNeeded,
    };
  }
}

class WaterProfileTargets {
  final int ca;
  final int mg;
  final int na;
  final int cl;
  final int so4;
  final int hco3;
  final String saltTiming;

  WaterProfileTargets({this.ca=0, this.mg=0, this.na=0, this.cl=0, this.so4=0, this.hco3=0, this.saltTiming=''});

  factory WaterProfileTargets.fromJson(Map<String, dynamic> json) {
    return WaterProfileTargets(
      ca: (json['Kalzium_Ca_mg_L'] as num?)?.toInt() ?? 0,
      mg: (json['Magnesium_Mg_mg_L'] as num?)?.toInt() ?? 0,
      na: (json['Natrium_Na_mg_L'] as num?)?.toInt() ?? 0,
      cl: (json['Chlorid_Cl_mg_L'] as num?)?.toInt() ?? 0,
      so4: (json['Sulfat_SO4_mg_L'] as num?)?.toInt() ?? 0,
      hco3: (json['Hydrogencarbonat_HCO3_mg_L'] as num?)?.toInt() ?? 0,
      saltTiming: json['Salzzugabe_Zeitpunkt'] ?? 'Maische',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Kalzium_Ca_mg_L': ca,
      'Magnesium_Mg_mg_L': mg,
      'Natrium_Na_mg_L': na,
      'Chlorid_Cl_mg_L': cl,
      'Sulfat_SO4_mg_L': so4,
      'Hydrogencarbonat_HCO3_mg_L': hco3,
      'Salzzugabe_Zeitpunkt': saltTiming,
    };
  }
}

class SpecialIngredient {
  final String name;
  final String amount;
  final String unit;
  final String detail;

  SpecialIngredient({required this.name, required this.amount, required this.unit, required this.detail});

  factory SpecialIngredient.fromJson(Map<String, dynamic> json) {
    return SpecialIngredient(
      name: json['Name'] ?? '',
      amount: json['Menge_g']?.toString() ?? json['Menge']?.toString() ?? '',
      unit: json['Einheit'] ?? 'g',
      detail: json['Einsatzphase'] ?? json['Anwendung_Detail'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Menge': amount,
      'Einheit': unit,
      'Anwendung_Detail': detail,
    };
  }
}

class FiningAgentRef {
  final String name;
  final String amount;
  final String phase;
  final String purpose;
  final String applicationDetail;
  final bool procurementNeeded;

  FiningAgentRef({
    required this.name,
    required this.amount,
    required this.phase,
    required this.purpose,
    required this.applicationDetail,
    required this.procurementNeeded,
  });

  factory FiningAgentRef.fromJson(Map<String, dynamic> json) {
    return FiningAgentRef(
      name: json['Name'] ?? '',
      amount: json['Menge'] ?? '',
      phase: json['Phase'] ?? json['Phase / Schritt'] ?? '',
      purpose: json['Zweck'] ?? '',
      applicationDetail: json['Hinweis'] ?? json['Anwendung_Detail'] ?? '',
      procurementNeeded: json['Beschaffung_Notwendig'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Name': name,
      'Menge': amount,
      'Phase': phase,
      'Zweck': purpose,
      'Anwendung_Detail': applicationDetail,
      'Beschaffung_Notwendig': procurementNeeded,
    };
  }
}

class ProcessData {
  final MashPlan mash;
  final LauterPlan lauter;
  final BoilPlan boil;
  final FermentationPlan fermentation;
  final PackagingPlan packaging;
  final VolumeCalculationCoT? volumeCalculation;

  ProcessData({
    required this.mash,
    required this.lauter,
    required this.boil,
    required this.fermentation,
    required this.packaging,
    this.volumeCalculation,
  });

  factory ProcessData.fromJson(Map<String, dynamic> json) {
    return ProcessData(
      mash: MashPlan.fromJson(json['Maischeplan'] ?? {}),
      lauter: LauterPlan.fromJson(json['Laeuterungsplan'] ?? json['Laeutern'] ?? {}),
      boil: BoilPlan.fromJson(json['Kochplan'] ?? json['Kochzeit_und_Kochphasen'] ?? {}),
      fermentation: FermentationPlan.fromJson(json['Gaerplan'] ?? json['Gaerungsplan'] ?? {}),
      packaging: PackagingPlan.fromJson(json['Abfuell_und_Lagerungsplan'] ?? json),
      volumeCalculation: VolumeCalculationCoT.fromJson(json['Mathematische_Volumenberechnung_CoT'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Maischeplan': mash.toJson(),
      'Laeuterungsplan': lauter.toJson(),
      'Kochplan': boil.toJson(),
      'Gaerungsplan': fermentation.toJson(),
      'Abfuell_und_Lagerungsplan': packaging.toJson(),
      'Mathematische_Volumenberechnung_CoT': volumeCalculation?.toJson(),
    };
  }
}

class VolumeCalculationCoT {
  final double step1EimerKalt;
  final double step2AusschlagHeiss;
  final double step3KochEndeHeiss;
  final double step4Pfannevoll;
  final String calculationNote;

  VolumeCalculationCoT({
    this.step1EimerKalt = 0.0,
    this.step2AusschlagHeiss = 0.0,
    this.step3KochEndeHeiss = 0.0,
    this.step4Pfannevoll = 0.0,
    this.calculationNote = '',
  });

  factory VolumeCalculationCoT.fromJson(Map<String, dynamic> json) {
    return VolumeCalculationCoT(
      step1EimerKalt: (json['Schritt_1_Eimer_kalt_L'] as num?)?.toDouble() ?? 0.0,
      step2AusschlagHeiss: (json['Schritt_2_Ausschlag_heiss_L'] as num?)?.toDouble() ?? 0.0,
      step3KochEndeHeiss: (json['Schritt_3_Koch_Ende_heiss_L'] as num?)?.toDouble() ?? 0.0,
      step4Pfannevoll: (json['Schritt_4_Pfannevoll_L'] as num?)?.toDouble() ?? 0.0,
      calculationNote: json['Kontrollrechnung_Notiz'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Schritt_1_Eimer_kalt_L': step1EimerKalt,
      'Schritt_2_Ausschlag_heiss_L': step2AusschlagHeiss,
      'Schritt_3_Koch_Ende_heiss_L': step3KochEndeHeiss,
      'Schritt_4_Pfannevoll_L': step4Pfannevoll,
      'Kontrollrechnung_Notiz': calculationNote,
    };
  }
}

class MashPlan {
  final double mashWaterL;
  final double mashInTemp;
  final List<MashStep> steps;

  MashPlan({required this.mashWaterL, required this.mashInTemp, required this.steps});

  factory MashPlan.fromJson(Map<String, dynamic> json) {
    // If the value passed is actually a list (common if the AI structure is flat), use it
    final stepsList = json['Rasten'] ?? json['Maischeplan'] ?? (json is List ? json : []);
    
    return MashPlan(
      mashWaterL: (json['Hauptguss_L'] as num?)?.toDouble() ?? 0.0,
      mashInTemp: (json['Einmaischtemperatur_C'] as num?)?.toDouble() ?? 0.0,
      steps: (stepsList as List?)?.map((e) => MashStep.fromJson(e)).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Hauptguss_L': mashWaterL,
      'Einmaischtemperatur_C': mashInTemp,
      'Rasten': steps.map((e) => e.toJson()).toList(),
    };
  }
}

class MashStep {
  final String stage;
  final double temp;
  final int duration;

  MashStep({required this.stage, required this.temp, required this.duration});

  factory MashStep.fromJson(Map<String, dynamic> json) {
    return MashStep(
      stage: json['Phase'] ?? json['Stufe'] ?? json['Name'] ?? '',
      temp: (json['Temperatur_C'] as num?)?.toDouble() ?? 0.0,
      duration: (json['Dauer_min'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Stufe': stage,
      'Temperatur_C': temp,
      'Dauer_min': duration,
    };
  }
}

class LauterPlan {
  final double spargeWaterL;
  final String targetPh;

  LauterPlan({required this.spargeWaterL, required this.targetPh});

  factory LauterPlan.fromJson(Map<String, dynamic> json) {
    return LauterPlan(
      spargeWaterL: (json['Nachgusswasser_Menge_L'] as num?)?.toDouble() ?? 0.0,
      targetPh: json['Ziel_pH_vor_Laeutern'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Nachgusswasser_Menge_L': spargeWaterL,
      'Ziel_pH_vor_Laeutern': targetPh,
    };
  }
}

class BoilPlan {
  final double preBoilVolumeL;
  final int duration;

  BoilPlan({required this.preBoilVolumeL, required this.duration});

  factory BoilPlan.fromJson(Map<String, dynamic> json) {
    return BoilPlan(
      preBoilVolumeL: (json['Pfannevoll_Tatsaechlich_L'] as num?)?.toDouble() ?? 
                       (json['Vorderwuerze_L'] as num?)?.toDouble() ?? 0.0,
      duration: (json['Gesamte_Kochdauer_min'] as num?)?.toInt() ?? 
                (json['Kochzeit_min'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Pfannevoll_Tatsaechlich_L': preBoilVolumeL,
      'Gesamte_Kochdauer_min': duration,
    };
  }
}

class FermentationPlan {
  final double pitchTemp;
  final List<FermentationStep> steps;
  final String pressureNote;

  FermentationPlan({required this.pitchTemp, required this.steps, required this.pressureNote});

  factory FermentationPlan.fromJson(Map<String, dynamic> json) {
    // Treat the list directly if it's passed as a list, or look for common keys
    final stepsList = json['Gaerphase'] ?? json['Gaerverlauf'] ?? json['Gaerungsverlauf'] ?? [];
    return FermentationPlan(
      pitchTemp: (json['Hefe_Anstelltemperatur_C'] as num?)?.toDouble() ?? 
                 (json['Anstelltemperatur_C'] as num?)?.toDouble() ?? 0.0,
      steps: (stepsList as List?)?.map((e) => FermentationStep.fromJson(e)).toList() ?? [],
      pressureNote: json['Druck_Hinweis'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Hefe_Anstelltemperatur_C': pitchTemp,
      'Gaerverlauf': steps.map((e) => e.toJson()).toList(),
      'Druck_Hinweis': pressureNote,
    };
  }
}

class FermentationStep {
  final String phase;
  final double temp;
  final int days;
  final double pressure;
  final String pressureReason;
  final String note;

  FermentationStep({
    required this.phase,
    required this.temp,
    required this.days,
    required this.pressure,
    required this.pressureReason,
    required this.note,
  });

  factory FermentationStep.fromJson(Map<String, dynamic> json) {
    return FermentationStep(
      phase: json['Name'] ?? json['Phase'] ?? json['Stufe'] ?? '',
      temp: (json['Temperatur_C'] as num?)?.toDouble() ?? 0.0,
      days: (json['Dauer_Tage'] as num?)?.toInt() ?? 
            (json['Zeit_Tage'] as num?)?.toInt() ?? 0,
      pressure: (json['Druck_bar'] as num?)?.toDouble() ?? 
                (json['CO2_Druck_bar'] as num?)?.toDouble() ?? 0.0,
      pressureReason: json['Druck_Begruendung'] ?? '',
      note: json['Hinweis'] ?? json['Notiz'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Phase': phase,
      'Temperatur_C': temp,
      'Dauer_Tage': days,
      'Druck_bar': pressure,
      'Druck_Begruendung': pressureReason,
      'Hinweis': note,
    };
  }
}

class PackagingPlan {
  final String type;
  final double co2Target;
  final double kegPressure;
  final double kegTemp;
  final double bottleSugar;
  final double bottleTemp;
  final double storageTemp;
  final int storageDurationWeeks;
  final String maturationNote;
  final String servingGasRecommendation;
  final int carbonationDurationDays;

  PackagingPlan({
    required this.type,
    required this.co2Target,
    required this.kegPressure,
    required this.kegTemp,
    required this.bottleSugar,
    required this.bottleTemp,
    required this.storageTemp,
    required this.storageDurationWeeks,
    required this.maturationNote,
    required this.servingGasRecommendation,
    required this.carbonationDurationDays,
  });

  factory PackagingPlan.fromJson(Map<String, dynamic> json) {
    // Merge potential sub-objects from the prompt structure
    final keg = json['Abfuellung_ins_Keg'] ?? {};
    final bottle = json['Abfuellung_in_Flaschen'] ?? {};
    
    return PackagingPlan(
      type: json['Abfuellung_Typ'] ?? json['type'] ?? '',
      co2Target: (json['Karbonisierung_Ziel_CO2_g_L'] as num?)?.toDouble() ?? 
                 (keg['CO2_Druck_bar'] as num?)?.toDouble() ?? 0.0,
      kegPressure: (keg['CO2_Druck_bar'] as num?)?.toDouble() ?? 
                   (json['Keg_Druck_bar'] as num?)?.toDouble() ?? 0.0,
      kegTemp: (keg['Temperatur_C'] as num?)?.toDouble() ?? 
               (json['Keg_Karbonisierung_Temp_C'] as num?)?.toDouble() ?? 0.0,
      bottleSugar: (bottle['Zucker_pro_Flasche_g'] as num?)?.toDouble() ?? 
                   (json['Flaschen_Zucker_g_pro_L'] as num?)?.toDouble() ?? 0.0,
      bottleTemp: (bottle['Karbonisierung_Temperatur_C'] as num?)?.toDouble() ?? 
                  (json['Flaschen_Karbonisierung_Temp_C'] as num?)?.toDouble() ?? 0.0,
      storageTemp: (bottle['Lager_Temperatur_C'] as num?)?.toDouble() ?? 
                   (json['Lagerung_Temperatur_C'] as num?)?.toDouble() ?? 0.0,
      storageDurationWeeks: (keg['Dauer_Tage'] as num?)?.toInt() ?? 
                             (json['Lagerung_Dauer_Wochen'] as num?)?.toInt() ?? 0,
      maturationNote: bottle['Hinweis'] ?? json['Reifungshinweis'] ?? '',
      servingGasRecommendation: json['Empfohlenes_Ausschankgas'] ?? '',
      carbonationDurationDays: (keg['Dauer_Tage'] as num?)?.toInt() ?? 
                               (json['Karbonisierungsdauer_Tage'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Abfuellung_Typ': type,
      'Karbonisierung_Ziel_CO2_g_L': co2Target,
      'Keg_Druck_bar': kegPressure,
      'Keg_Karbonisierung_Temp_C': kegTemp,
      'Flaschen_Zucker_g_pro_L': bottleSugar,
      'Flaschen_Karbonisierung_Temp_C': bottleTemp,
      'Lagerung_Temperatur_C': storageTemp,
      'Lagerung_Dauer_Wochen': storageDurationWeeks,
      'Reifungshinweis': maturationNote,
      'Empfohlenes_Ausschankgas': servingGasRecommendation,
      'Karbonisierungsdauer_Tage': carbonationDurationDays,
    };
  }
}
