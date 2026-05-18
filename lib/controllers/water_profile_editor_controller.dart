import 'package:flutter/material.dart';
import '../models/water_profile.dart';

class WaterProfileEditorController extends ChangeNotifier {
  WaterProfileEditorController({WaterProfile? profile}) {
    if (profile != null) {
      nameCtrl.text = profile.name;
      phCtrl.text = _doubleToText(profile.ph, emptyIfNull: true);
      calciumCtrl.text = _doubleToText(profile.calciumPpm);
      magnesiumCtrl.text = _doubleToText(profile.magnesiumPpm);
      sodiumCtrl.text = _doubleToText(profile.sodiumPpm);
      chlorideCtrl.text = _doubleToText(profile.chloridePpm);
      sulfateCtrl.text = _doubleToText(profile.sulfatePpm);
      bicarbonateCtrl.text = _doubleToText(profile.bicarbonatePpm);
      isDefault = profile.isDefault;
    }
    updateWaterStats();
  }

  final TextEditingController nameCtrl = TextEditingController();
  final TextEditingController phCtrl = TextEditingController();
  final TextEditingController calciumCtrl = TextEditingController();
  final TextEditingController magnesiumCtrl = TextEditingController();
  final TextEditingController sodiumCtrl = TextEditingController();
  final TextEditingController chlorideCtrl = TextEditingController();
  final TextEditingController sulfateCtrl = TextEditingController();
  final TextEditingController bicarbonateCtrl = TextEditingController();

  bool isDefault = false;
  bool isSaving = false;

  bool hasWaterStats = false;
  double? computedWaterPh;
  double cationCharge = 0;
  double anionCharge = 0;
  double? ionBalancePercent;
  double? so4ClRatio;
  double? waterHardness;
  double? waterAlkalinity;
  double? residualAlkalinity;

  @override
  void dispose() {
    nameCtrl.dispose();
    phCtrl.dispose();
    calciumCtrl.dispose();
    magnesiumCtrl.dispose();
    sodiumCtrl.dispose();
    chlorideCtrl.dispose();
    sulfateCtrl.dispose();
    bicarbonateCtrl.dispose();
    super.dispose();
  }

  void setIsDefault(bool value) {
    isDefault = value;
    notifyListeners();
  }

  void setIsSaving(bool value) {
    isSaving = value;
    notifyListeners();
  }

  bool get hasWaterInput {
    final controllers = [
      phCtrl,
      calciumCtrl,
      magnesiumCtrl,
      sodiumCtrl,
      chlorideCtrl,
      sulfateCtrl,
      bicarbonateCtrl,
    ];
    return controllers.any((ctrl) => ctrl.text.trim().isNotEmpty);
  }

  double parseControllerValue(TextEditingController controller) {
    return double.tryParse(controller.text.replaceAll(',', '.')) ?? 0.0;
  }

  double? parseOptionalDouble(TextEditingController controller) {
    final text = controller.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text.replaceAll(',', '.'));
  }

  void updateWaterStats() {
    if (!hasWaterInput) {
      _resetStats();
      notifyListeners();
      return;
    }
    final double ca = parseControllerValue(calciumCtrl);
    final double mg = parseControllerValue(magnesiumCtrl);
    final double na = parseControllerValue(sodiumCtrl);
    final double cl = parseControllerValue(chlorideCtrl);
    final double so4 = parseControllerValue(sulfateCtrl);
    final double hco3 = parseControllerValue(bicarbonateCtrl);
    final double ph = parseControllerValue(phCtrl);

    final double cationMeq = (ca / 20.0) + (mg / 12.15) + (na / 23.0);
    final double anionMeq = (cl / 35.45) + (so4 / 48.0) + (hco3 / 61.0);

    final double? ionBalance = (cationMeq > 0 && anionMeq > 0)
        ? ((cationMeq - anionMeq) / ((cationMeq + anionMeq) / 2)) * 100
        : null;

    final double? ratio = cl > 0 ? so4 / cl : null;
    final double hardness = (2.5 * ca) + (4.1 * mg);
    final double alkalinity = hco3 * (50 / 61);
    final double residual =
        alkalinity - ((2.5 * ca) / 3.5) - ((4.1 * mg) / 7.0);

    hasWaterStats = true;
    cationCharge = cationMeq;
    anionCharge = anionMeq;
    ionBalancePercent = ionBalance;
    so4ClRatio = ratio;
    waterHardness = hardness;
    waterAlkalinity = alkalinity;
    residualAlkalinity = residual;
    computedWaterPh = ph > 0 ? ph : null;
    notifyListeners();
  }

  void _resetStats() {
    hasWaterStats = false;
    cationCharge = 0;
    anionCharge = 0;
    ionBalancePercent = null;
    so4ClRatio = null;
    waterHardness = null;
    waterAlkalinity = null;
    residualAlkalinity = null;
    computedWaterPh = null;
  }

  String _doubleToText(double? value, {bool emptyIfNull = false}) {
    if (value == null) {
      return emptyIfNull ? '' : '–';
    }
    if (value == 0) return '0';
    final bool isInt = value.truncateToDouble() == value;
    return isInt ? value.toStringAsFixed(0) : value.toStringAsFixed(2);
  }

  WaterProfile buildDraft({required String profileId, String? id}) {
    final name = nameCtrl.text.trim().isEmpty
        ? 'Unbenanntes Profil'
        : nameCtrl.text.trim();
    return WaterProfile(
      id: id,
      userProfileId: profileId,
      name: name,
      isDefault: isDefault,
      ph: parseOptionalDouble(phCtrl),
      calciumPpm: parseControllerValue(calciumCtrl),
      magnesiumPpm: parseControllerValue(magnesiumCtrl),
      sodiumPpm: parseControllerValue(sodiumCtrl),
      chloridePpm: parseControllerValue(chlorideCtrl),
      sulfatePpm: parseControllerValue(sulfateCtrl),
      bicarbonatePpm: parseControllerValue(bicarbonateCtrl),
    );
  }
}
