import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/user_profile.dart';
import '../services/rapt_service.dart';
import '../services/user_profile_service.dart';
import 'rapt_dashboard/rapt_summary_tile.dart';
import 'rapt_dashboard/rapt_telemetry_chart.dart';
import 'rapt_dashboard/rapt_controls_panel.dart';
import 'rapt_dashboard/rapt_badges.dart';

class RaptDashboardPage extends StatefulWidget {
  const RaptDashboardPage({super.key});

  static const String routeName = '/rapt_dashboard';

  @override
  State<RaptDashboardPage> createState() => _RaptDashboardPageState();
}

class _RaptDashboardPageState extends State<RaptDashboardPage> {
  bool _isLoading = false;
  String? _error;
  
  UserProfile? _profile;
  List<dynamic> _controllers = [];
  String? _selectedControllerId;
  
  List<dynamic> _telemetryData = [];
  DateTime? _startDate;
  
  bool _isFallbackData = false;

  // Dashboard Metrics
  double? _latestTemp;
  double? _latestGravity;
  double? _latestAbv;
  double? _og;
  double? _latestBattery;
  double? _delta24h;
  String? _generatedAt;
  String? _currentProfileName;

  @override
  void initState() {
    super.initState();
    _loadProfileAndControllers();
  }

  Future<void> _loadProfileAndControllers() async {
    setState(() => _isLoading = true);
    try {
      final profile = await UserProfileService().fetchDefaultProfile();
      if (profile == null) throw Exception('Kein Benutzerprofil gefunden.');
      if ((profile.raptUserId ?? '').isEmpty || (profile.raptApiKey ?? '').isEmpty) {
        throw Exception('Keine RAPT Zugangsdaten im Profil hinterlegt.');
      }
      
      _profile = profile;
      
      final service = RaptService(
        userId: profile.raptUserId!,
        apiKey: profile.raptApiKey!,
      );
      
      final controllers = await service.getControllers();
      if (controllers.isEmpty) throw Exception('Keine Controller gefunden.');
      
      setState(() {
        _controllers = controllers;
        _selectedControllerId = _getControllerId(controllers.first);
      });
      
      if (_selectedControllerId != null) {
        await _loadTelemetry(_selectedControllerId!);
      }
      
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _getControllerId(dynamic c) {
    return c['id'] ?? c['Id'] ?? c['temperatureControllerId'] ?? c['TemperatureControllerId'];
  }

  Future<void> _loadTelemetry(String controllerId, {DateTime? startOverride, bool forceRefresh = false}) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    
    try {
      final service = RaptService(
        userId: _profile!.raptUserId!,
        apiKey: _profile!.raptApiKey!,
      );
      
      final dataEnv = await service.fetchTelemetry(
        controllerId: controllerId,
        startDate: startOverride,
        forceRefresh: forceRefresh,
        useCacheOnly: !forceRefresh && startOverride == null,
      );
      
      final rows = (dataEnv['rows'] as List?)?.map((e) => e as Map<String,dynamic>).toList() ?? [];
      final genAt = dataEnv['generatedAt'] as String?;
      final isFallback = dataEnv['isFallback'] == true; // Capture fallback flag
      
      if (dataEnv['resolvedStartDate'] != null) {
         _startDate = DateTime.tryParse(dataEnv['resolvedStartDate']);
      } else if (startOverride != null) {
         _startDate = startOverride;
      }

      setState(() {
        _generatedAt = genAt;
        _isFallbackData = isFallback;
      });
      
      _processTelemetry(rows);
      
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _processTelemetry(List<dynamic> rows) {
    if (rows.isEmpty) {
      setState(() {
        _telemetryData = [];
        _latestTemp = null;
        _latestGravity = null;
        _latestAbv = null;
        _latestBattery = null;
        _og = null;
        _delta24h = null;
      });
      return;
    }
    
    // Sort by date
    rows.sort((a, b) {
      final da = DateTime.tryParse(a['createdOn'] ?? '') ?? DateTime(0);
      final db = DateTime.tryParse(b['createdOn'] ?? '') ?? DateTime(0);
      return da.compareTo(db);
    });
    
    // Helper
    double normalize(double? val) {
      if (val == null) return 0.0;
      if (val > 500) return val / 1000.0;
      return val;
    }

    final last = rows.last;
    final temp = (last['temperature'] as num?)?.toDouble();
    double? gravity = (last['gravity'] as num?)?.toDouble();
    if (gravity != null) gravity = normalize(gravity);
    
    // Battery
    final battery = (last['battery'] as num?)?.toDouble();
    
    // OG
    final gravities = rows.map((r) => normalize((r['gravity'] as num?)?.toDouble())).where((g) => g > 0).toList();
    final og = gravities.isNotEmpty ? gravities.reduce((a, b) => a > b ? a : b) : null;
    
    // ABV
    double? abv;
    if (og != null && gravities.isNotEmpty) {
       double lastAbv = 0.0;
       for (final r in rows) {
          double? g = (r['gravity'] as num?)?.toDouble();
          if (g != null) {
             g = normalize(g);
             double currentAbv = (og - g) * 131.25;
             if (currentAbv < 0) currentAbv = 0;
             if (currentAbv < lastAbv) {
                currentAbv = lastAbv;
             } else {
                lastAbv = currentAbv;
             }
             abv = currentAbv;
          }
       }
    }
    
    // Delta 24h
    double? delta;
    if (gravity != null) {
       final now = DateTime.tryParse(last['createdOn'] ?? '');
       if (now != null) {
         final target = now.subtract(const Duration(hours: 24));
         int minDiff = 999999999;
         Map<String, dynamic>? closest;
         
         for (final r in rows) {
            final t = DateTime.tryParse(r['createdOn'] ?? '');
            if (t == null) continue;
            final diff = (t.difference(target)).inSeconds.abs();
            if (diff < minDiff) {
               minDiff = diff;
               closest = r;
            }
         }
         
         if (closest != null && minDiff < 3600 * 2) {
             double? oldG = (closest['gravity'] as num?)?.toDouble();
             if (oldG != null) {
               oldG = normalize(oldG);
               delta = gravity - oldG;
             }
         }
       }
    }
    
    setState(() {
      _telemetryData = rows;
      _latestTemp = temp;
      _latestGravity = gravity;
      _latestAbv = abv;
      _latestBattery = battery;
      _og = og;
      _delta24h = delta;
      _currentProfileName = last['profileName'] ?? last['ProfileName'];
    });
  }
  
  // (Rest of methods) ... skip to build ...

  
  // New helper to reset
  Future<void> _resetDateAndReload() async {
     setState(() => _isLoading = true);
     try {
       final service = RaptService(
          userId: _profile!.raptUserId!,
          apiKey: _profile!.raptApiKey!,
        );
       await service.resetStartDate();
       setState(() => _startDate = null);
       // Reload with force refresh to clear any stale cache state on proxy side regarding date override
       await _loadTelemetry(_selectedControllerId!, forceRefresh: true);
     } catch (e) {
        if (mounted) setState(() => _error = e.toString());
        setState(() => _isLoading = false);
     }
  }




  @override
  Widget build(BuildContext context) {
    if (_profile == null && _isLoading && _controllers.isEmpty) {
      return const Scaffold(
        backgroundColor: Color(0xFF020617),
        body: Center(child: CircularProgressIndicator()),
      );
    }
    
    // Check active session
    bool isActive = false;
    if (_selectedControllerId != null) {
      final c = _controllers.firstWhere((c) => _getControllerId(c) == _selectedControllerId, orElse: () => null);
      if (c != null && (c['activeProfileSession'] != null || c['ActiveProfileSession'] != null)) {
        isActive = true;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF020617),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('RAPT Dashboard'),
        centerTitle: true,
        actions: [
           if (_latestBattery != null)
             Padding(
                padding: const EdgeInsets.only(right: 16), 
                child: Center(child: RaptBatteryBadge(percent: _latestBattery!))
             ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Status Badge
            RaptStatusBadge(isActive: isActive),
            const SizedBox(height: 16),

            // 2. Metadata Info (Design from Bild 1: Floppy Icon + Amber Text) at the TOP
            if (_telemetryData.isNotEmpty)
               Padding(
                 padding: const EdgeInsets.only(bottom: 16),
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     Row(
                       children: [
                         const Icon(Icons.save, size: 16, color: Colors.amberAccent),
                         const SizedBox(width: 8),
                         Text(
                           'Cache · ${_telemetryData.length} Messpunkte · Stand ${_generatedAt != null ? DateFormat('dd.MM.yyyy, HH:mm').format(DateTime.tryParse(_generatedAt!) ?? DateTime.now()) : '-'} MEZ',
                           style: const TextStyle(color: Colors.amberAccent, fontSize: 13, fontWeight: FontWeight.bold),
                         ),
                       ],
                     ),
                     const SizedBox(height: 4),
                     Builder(
                       builder: (context) {
                         final first = _telemetryData.first;
                         final last = _telemetryData.last;
                         final start = DateTime.tryParse(first['createdOn'] ?? '');
                         final end = DateTime.tryParse(last['createdOn'] ?? '');
                         final fmt = DateFormat('dd.MM.yyyy, HH:mm');
                         if (start == null || end == null) return const SizedBox();
                         return Text(
                           'Zeitraum: ${fmt.format(start)} MEZ → ${fmt.format(end)} MEZ',
                           style: const TextStyle(color: Colors.white70, fontSize: 13),
                         );
                       },
                     ),
                   ],
                 ),
               ),
            // 3. Profile Title (Bild 1)
            Text(
               _isFallbackData ? 'Letzter Sud: ${_telemetryData.isNotEmpty ? (_telemetryData.first['profileName'] ?? _telemetryData.first['ProfileName'] ?? 'Unbekannt') : ''}' 
                               : (_currentProfileName ?? 'RAPT Sud'),
               style: const TextStyle(
                 color: Colors.white,
                 fontSize: 28,
                 fontWeight: FontWeight.bold,
                 height: 1.2,
               ),
            ),
            const SizedBox(height: 24),

            if (_error != null)
               Container(
                 padding: const EdgeInsets.all(12),
                 margin: const EdgeInsets.only(bottom: 16),
                 decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                 child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
               ),
             
             // Main Panel
             Container(
               padding: const EdgeInsets.all(24),
               decoration: BoxDecoration(
                 color: const Color(0xFF04060F).withValues(alpha: 0.94),
                 borderRadius: BorderRadius.circular(40),
                 boxShadow: [
                   BoxShadow(color: Colors.blue.withValues(alpha: 0.05), blurRadius: 0, spreadRadius: 1), // inset simulation
                 ]
               ),
               child: Column(
                  children: [
                     // 4. Main Metric Cards (Bild 1: Temp, Gravity, Alcohol)
                     LayoutBuilder(
                       builder: (ctx, constraints) {
                         if (constraints.maxWidth < 600) {
                            return Column(
                               children: [
                                  RaptSummaryTile(label: 'TEMPERATUR', value: _latestTemp, unit: '°C', color: Colors.blue),
                                  const SizedBox(height: 16),
                                  RaptSummaryTile(label: 'GRAVITY', value: _latestGravity, unit: 'SG', color: Colors.red, extra: _buildGravityExtra()),
                                  const SizedBox(height: 16),
                                  RaptSummaryTile(label: 'ALKOHOL', value: _latestAbv, unit: 'Vol.%', color: Colors.amber),
                               ],
                            );
                         }
                         return IntrinsicHeight(
                           child: Row(
                             crossAxisAlignment: CrossAxisAlignment.stretch,
                             children: [
                               Expanded(child: RaptSummaryTile(label: 'TEMPERATUR', value: _latestTemp, unit: '°C', color: Colors.blue)),
                               const SizedBox(width: 16),
                               Expanded(child: RaptSummaryTile(label: 'GRAVITY', value: _latestGravity, unit: 'SG', color: Colors.red, extra: _buildGravityExtra())),
                               const SizedBox(width: 16),
                               Expanded(child: RaptSummaryTile(label: 'ALKOHOL', value: _latestAbv, unit: 'Vol.%', color: Colors.amber)),
                             ],
                           ),
                         );
                       },
                     ),
                     const SizedBox(height: 24),

                     // 5. Controller Selection (Label + Dropdown) - Below Tiles
                     if (!_isFallbackData) ...[
                        const Text('Temperature Controller', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                             color: const Color(0xFF020B1D),
                             border: Border.all(color: Colors.white24),
                             borderRadius: BorderRadius.circular(10),
                          ),
                          child: DropdownButton<String>(
                            value: _selectedControllerId,
                            isExpanded: true,
                            dropdownColor: const Color(0xFF020B1D),
                            underline: const SizedBox(),
                            style: const TextStyle(color: Colors.white),
                            items: _controllers.map((c) {
                               final id = _getControllerId(c);
                               final name = c['name'] ?? c['controllerName'] ?? id;
                               return DropdownMenuItem<String>(
                                  value: id,
                                  child: Text(name),
                               );
                            }).toList(),
                            onChanged: (v) {
                               if (v != null) {
                                  setState(() {
                                    _selectedControllerId = v;
                                    _startDate = null; 
                                  });
                                  _loadTelemetry(v); 
                               }
                            },
                          ),
                        ),
                        const SizedBox(height: 32),
                     ],
                     
                     // 6. CHART
                     SizedBox(
                       height: 450,
                       child: RaptTelemetryChart(telemetryData: _telemetryData),
                     ),
                     const SizedBox(height: 24),
                     
                     // 7. Controls Row
                     RaptControlsPanel(
                        startDate: _startDate, 
                        generatedAt: _generatedAt,
                        onDateChanged: (dt) => setState(() => _startDate = dt), 
                        onApply: () {
                           if (_selectedControllerId != null) {
                              _loadTelemetry(_selectedControllerId!, startOverride: _startDate, forceRefresh: true);
                           }
                        }, 
                        onReset: _resetDateAndReload, 
                        onRefresh: () {
                           if (_selectedControllerId != null) {
                              _loadTelemetry(_selectedControllerId!, startOverride: _startDate, forceRefresh: true);
                           }
                        }
                     ),
                  ],
               ),
             ),
             
             // Footer Button
             const SizedBox(height: 32),
             Center(
               child: TextButton(
                 onPressed: () => Navigator.pop(context),
                 child: const Text('Zur Startseite'),
               ),
             ),
             const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  

  Widget _buildGravityExtra() {
     return Column(
        children: [
           _buildRow('OG', _og != null ? _og!.toStringAsFixed(4) : '–'),
           _buildRow('\u0394 24h', _delta24h != null ? _delta24h!.toStringAsFixed(4) : '–'),
        ],
     );
  }
  
  Widget _buildRow(String label, String val) {
     return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
           Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11)),
           Text(val, style: const TextStyle(color: Colors.white, fontSize: 11)),
        ],
     );
  }
}
