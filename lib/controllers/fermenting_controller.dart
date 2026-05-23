import 'package:flutter/material.dart';
import '../models/bf_batch.dart';
import '../services/rapt_service.dart';
import '../services/user_profile_service.dart';

class FermentingController extends ChangeNotifier {
  FermentingController(this.batch) {
    _initializeRaptState();
  }

  final BfBatch batch;

  bool _useRaptData = false;
  bool _isLoadingRapt = false;
  List<dynamic> _raptData = [];
  String? _raptError;
  String? _hydrometerId;
  DateTime? _raptStartDate;
  DateTime? _raptEndDate;

  bool get useRaptData => _useRaptData;
  bool get isLoadingRapt => _isLoadingRapt;
  List<dynamic> get raptData => _raptData;
  String? get raptError => _raptError;
  String? get hydrometerId => _hydrometerId;
  DateTime? get raptStartDate => _raptStartDate;
  DateTime? get raptEndDate => _raptEndDate;

  void setUseRaptData(bool value) {
    _useRaptData = value;
    notifyListeners();
  }

  void setRaptDates(DateTime? start, DateTime? end) {
    _raptStartDate = start;
    _raptEndDate = end;
    if (_raptStartDate != null && _raptEndDate != null) {
      loadRaptData();
    } else {
      notifyListeners();
    }
  }

  void _initializeRaptState() {
    final data = batch.raptData;
    if (data.isNotEmpty &&
        data['telemetry'] != null &&
        (data['telemetry'] as List).isNotEmpty) {
      _useRaptData = true;
      _raptData = List<dynamic>.from(data['telemetry']);

      if (data['start_date'] != null) {
        _raptStartDate = DateTime.tryParse(data['start_date']);
      }
      if (data['end_date'] != null) {
        _raptEndDate = DateTime.tryParse(data['end_date']);
      }
      if (data['hydrometer_id'] != null) {
        _hydrometerId = data['hydrometer_id'];
      }
    }
  }

  Future<void> loadRaptData() async {
    if (_raptStartDate == null || _raptEndDate == null) return;

    _isLoadingRapt = true;
    _raptError = null;
    notifyListeners();

    try {
      final profile = await UserProfileService().fetchDefaultProfile();
      if (profile == null ||
          (profile.raptUserId ?? '').isEmpty ||
          (profile.raptApiKey ?? '').isEmpty) {
        throw Exception('Keine RAPT Zugangsdaten im Profil.');
      }

      final service = RaptService();

      if (_hydrometerId == null) {
        final hydrometers = await service.getHydrometers();
        if (hydrometers.isNotEmpty) {
          _hydrometerId = hydrometers.first['id'] ?? hydrometers.first['Id'];
        } else {
          throw Exception('Keine Hydrometer bei RAPT gefunden.');
        }
      }

      if (_hydrometerId == null) {
        throw Exception('Konnte Hydrometer ID nicht ermitteln.');
      }

      final data = await service.fetchHydrometerTelemetry(
        hydrometerId: _hydrometerId!,
        startDate: _raptStartDate!,
        endDate: _raptEndDate!,
      );

      _raptData = data;
      _raptData.sort((a, b) {
        final da = DateTime.tryParse(a['createdOn'] ?? '') ?? DateTime(0);
        final db = DateTime.tryParse(b['createdOn'] ?? '') ?? DateTime(0);
        return da.compareTo(db);
      });
      await saveRaptDataToBatch();
    } catch (e) {
      _raptError = e.toString();
    } finally {
      _isLoadingRapt = false;
      notifyListeners();
    }
  }

  Future<void> saveRaptDataToBatch() async {
    try {
      batch.raptData.clear();
      batch.raptData.addAll({
        'telemetry': _raptData,
        'start_date': _raptStartDate?.toIso8601String(),
        'end_date': _raptEndDate?.toIso8601String(),
        'hydrometer_id': _hydrometerId,
      });

      await UserProfileService().saveBatches([batch]);
      // Eventuell hier Success Feedback geben anstatt im Controller? (z.B. über ein Callback)
    } catch (e) {
      debugPrint('Failed to save RAPT data: $e');
      // Fehlerhandling
    }
  }
}
