import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/yeast_bank_entry.dart';

class YeastBankEditorController extends ChangeNotifier {
  YeastBankEditorController({
    this.editing,
    Map<String, String>? debugJsonMap,
  }) {
    String initialNotes = editing?.notes ?? '';
    String initialProductId = editing?.productId ?? '';
    String initialForm = editing?.form ?? '';
    String initialInventory =
        editing?.inventory != null ? editing!.inventory.toString() : '';
    String initialUnit = editing?.unit ?? '';

    if (editing != null &&
        (initialProductId.isEmpty || initialForm.isEmpty) &&
        debugJsonMap != null &&
        debugJsonMap.containsKey(editing!.strain)) {
      try {
        final data = jsonDecode(debugJsonMap[editing!.strain]!) as Map<String, dynamic>;
        if (initialProductId.isEmpty) {
          initialProductId = data['productId']?.toString() ?? '';
        }
        if (initialForm.isEmpty) initialForm = data['form']?.toString() ?? '';
        if (initialInventory.isEmpty && data['inventory'] != null) {
          initialInventory = data['inventory'].toString();
        }
        if (initialUnit.isEmpty && data['unit'] != null) {
          initialUnit = data['unit'].toString();
        }
      } catch (_) {}
    }

    brandCtrl = TextEditingController(text: editing?.brand ?? '');
    strainCtrl = TextEditingController(text: editing?.strain ?? '');
    styleCtrl = TextEditingController(text: editing?.style ?? '');
    urlCtrl = TextEditingController(text: editing?.url ?? '');
    attenuationMinCtrl =
        TextEditingController(text: editing?.attenuationMin?.toString() ?? '');
    attenuationMaxCtrl =
        TextEditingController(text: editing?.attenuationMax?.toString() ?? '');
    tempMinCtrl =
        TextEditingController(text: editing?.temperatureMin?.toString() ?? '');
    tempMaxCtrl =
        TextEditingController(text: editing?.temperatureMax?.toString() ?? '');

    notesCtrl = TextEditingController(text: initialNotes);
    productIdCtrl = TextEditingController(text: initialProductId);
    formCtrl = TextEditingController(text: initialForm);
    inventoryCtrl = TextEditingController(text: initialInventory);
    unitCtrl = TextEditingController(text: initialUnit);
  }

  final YeastBankEntry? editing;

  late final TextEditingController brandCtrl;
  late final TextEditingController strainCtrl;
  late final TextEditingController styleCtrl;
  late final TextEditingController urlCtrl;
  late final TextEditingController attenuationMinCtrl;
  late final TextEditingController attenuationMaxCtrl;
  late final TextEditingController tempMinCtrl;
  late final TextEditingController tempMaxCtrl;
  late final TextEditingController notesCtrl;
  late final TextEditingController productIdCtrl;
  late final TextEditingController formCtrl;
  late final TextEditingController inventoryCtrl;
  late final TextEditingController unitCtrl;

  String? brandError;
  String? strainError;
  bool isSaving = false;

  bool get isSynced =>
      editing?.brewfatherId != null && editing!.brewfatherId!.isNotEmpty;

  @override
  void dispose() {
    brandCtrl.dispose();
    strainCtrl.dispose();
    styleCtrl.dispose();
    urlCtrl.dispose();
    attenuationMinCtrl.dispose();
    attenuationMaxCtrl.dispose();
    tempMinCtrl.dispose();
    tempMaxCtrl.dispose();
    notesCtrl.dispose();
    productIdCtrl.dispose();
    formCtrl.dispose();
    inventoryCtrl.dispose();
    unitCtrl.dispose();
    super.dispose();
  }

  bool validate() {
    bool isValid = true;
    brandError = null;
    strainError = null;

    if (brandCtrl.text.trim().isEmpty) {
      brandError = 'Pflichtfeld';
      isValid = false;
    }
    if (strainCtrl.text.trim().isEmpty) {
      strainError = 'Pflichtfeld';
      isValid = false;
    }
    notifyListeners();
    return isValid;
  }

  double? parseDouble(String value) {
    if (value.trim().isEmpty) return null;
    return double.tryParse(value.replaceAll(',', '.').trim());
  }

  YeastBankEntry buildDraft({required String profileId}) {
    return YeastBankEntry(
      id: editing?.id,
      userProfileId: profileId,
      brewfatherId: editing?.brewfatherId,
      brand: brandCtrl.text.trim(),
      strain: strainCtrl.text.trim(),
      productId:
          productIdCtrl.text.trim().isEmpty ? null : productIdCtrl.text.trim(),
      form: formCtrl.text.trim().isEmpty ? null : formCtrl.text.trim(),
      inventory: parseDouble(inventoryCtrl.text),
      unit: unitCtrl.text.trim().isEmpty ? null : unitCtrl.text.trim(),
      style: styleCtrl.text.trim().isEmpty ? null : styleCtrl.text.trim(),
      url: urlCtrl.text.trim().isEmpty ? null : urlCtrl.text.trim(),
      attenuationMin: parseDouble(attenuationMinCtrl.text),
      attenuationMax: parseDouble(attenuationMaxCtrl.text),
      temperatureMin: parseDouble(tempMinCtrl.text),
      temperatureMax: parseDouble(tempMaxCtrl.text),
      notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
    );
  }

  void setIsSaving(bool value) {
    isSaving = value;
    notifyListeners();
  }
}
