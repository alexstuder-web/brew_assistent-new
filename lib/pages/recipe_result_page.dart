import 'package:flutter/material.dart';
import 'dart:convert';
import '../models/ai_recipe.dart';
import 'recipe_completion_page.dart';
import '../models/water_profile.dart';
import '../services/water_profile_service.dart';
import '../services/user_profile_service.dart';
import '../utils/water_calc.dart';
import '../l10n/app_localizations.dart';
import '../widgets/section_title.dart';

class RecipeResultPage extends StatelessWidget {
  final AiRecipe recipe;

  const RecipeResultPage({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(recipe.basisBier),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(48),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: Row(
                  children: [
                    const Expanded(
                      child: TabBar(
                        tabs: [
                          Tab(icon: Icon(Icons.list), text: 'Übersicht'),
                          Tab(icon: Icon(Icons.timelapse), text: 'Brauprozess'),
                          Tab(icon: Icon(Icons.local_drink), text: 'Abfüllung'),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RecipeCompletionPage(recipe: recipe),
                            ),
                          );
                        },
                        icon: const Icon(Icons.check_circle_outline, size: 20),
                        label: const Text('Abschliessen'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.greenAccent,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: TabBarView(
              children: [
                _OverviewTab(recipe: recipe),
                _ProcessTab(recipe: recipe),
                _PackagingTab(recipe: recipe),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OverviewTab extends StatefulWidget {
  final AiRecipe recipe;
  const _OverviewTab({required this.recipe});

  @override
  State<_OverviewTab> createState() => _OverviewTabState();
}

class _OverviewTabState extends State<_OverviewTab> {
  late Future<WaterProfile?> _sourceWaterFuture;
  WaterProfile? _forcedProfile;

  @override
  void initState() {
    super.initState();
    _sourceWaterFuture = _fetchSource();
  }

  Future<WaterProfile?> _fetchSource() async {
     try {
       final service = WaterProfileService();
       final profiles = await service.fetchProfiles(UserProfileService.defaultProfileId);
       if (profiles.isNotEmpty) {
           return profiles.firstWhere((p) => p.isDefault, orElse: () => profiles.first);
       }
       return null;
     } catch (e) {

       return null;
     }
  }

  void _useDistilled() {
     setState(() {
        _forcedProfile = const WaterProfile(
           id: 'distilled', 
           userProfileId: '', 
           name: 'Destilliertes Wasser', 
           calciumPpm: 0, magnesiumPpm: 0, sodiumPpm: 0, chloridePpm: 0, sulfatePpm: 0, bicarbonatePpm: 0, 
           isDefault: false, 
        );
     });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<WaterProfile?>(
      future: _sourceWaterFuture,
      builder: (context, snapshot) {
         WaterProfile? profile = _forcedProfile; 
         bool loading = snapshot.connectionState == ConnectionState.waiting;
         if (!loading && profile == null) {
            profile = snapshot.data;
         }

         return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                  if (widget.recipe.generatedImage != null)
                    Center(
                      child: FractionallySizedBox(
                        widthFactor: 0.25, // 25% width
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.memory(
                              base64Decode(widget.recipe.generatedImage!),
                              width: double.infinity,
                              fit: BoxFit.fitWidth,
                              errorBuilder: (context, error, stackTrace) => Container(
                                height: 100, 
                                alignment: Alignment.center,
                                child: Text('Bild Fehler: $error', style: const TextStyle(fontSize: 10, color: Colors.red))
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),

                  Card(
                    color: Colors.orange.withValues(alpha: 0.1),
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.orangeAccent.withValues(alpha: 0.3)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              AppLocalizations.of(context)!.aiDisclaimer,
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  _buildKeyStatsCard(),
                  const SizedBox(height: 16),
                  const SectionTitle('Malz & Fermentierbares'),
                  ...widget.recipe.zutaten.malts.map((m) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(m.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('Schrotmaß: ${m.crushGap} mm'),
                    trailing: Text('${m.amountKg.toStringAsFixed(2)} kg', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  )),
                  if (widget.recipe.zutaten.malts.isEmpty) 
                    const Text('Keine Malze angegeben.')
                  else
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamtmenge Malz:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            '${widget.recipe.zutaten.malts.fold<double>(0, (sum, m) => sum + m.amountKg).toStringAsFixed(2)} kg', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.blueAccent)
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const SectionTitle('Hopfen'),
                  ...widget.recipe.zutaten.hops.map((h) => ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(h.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${h.use} • ${h.timeMin} min • ${h.alpha}% Alpha'),
                    trailing: Text('${h.amountG.toStringAsFixed(0)} g', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  )),
                  if (widget.recipe.zutaten.hops.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Gesamtmenge Hopfen:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text(
                            '${widget.recipe.zutaten.hops.fold<double>(0, (sum, h) => sum + h.amountG).toStringAsFixed(0)} g', 
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.greenAccent)
                          ),
                        ],
                      ),
                    ),
                  
                  const SizedBox(height: 16),
                  const SectionTitle('Hefe'),
                  ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    title: Text(widget.recipe.zutaten.yeast.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.recipe.zutaten.yeast.type),
                        if (widget.recipe.zutaten.yeast.procurementNeeded)
                           const Padding(
                             padding: EdgeInsets.only(top: 4),
                             child: Chip(label: Text('Beschaffung nötig!'), backgroundColor: Colors.orangeAccent),
                           )
                        else
                           const Padding(
                             padding: EdgeInsets.only(top: 4),
                             child: Chip(label: Text('Vorhanden'), backgroundColor: Colors.greenAccent),
                           ),
                      ],
                    ),
                    leading: const Icon(Icons.opacity),
                    trailing: Text(widget.recipe.zutaten.yeast.amount, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),

                  const SizedBox(height: 16),
                  const SectionTitle('Wasserprofil (Zielwerte)'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _buildWaterBadge('Ca', widget.recipe.zutaten.water.ca),
                      _buildWaterBadge('Mg', widget.recipe.zutaten.water.mg),
                      _buildWaterBadge('Na', widget.recipe.zutaten.water.na),
                      _buildWaterBadge('Cl', widget.recipe.zutaten.water.cl),
                      _buildWaterBadge('SO4', widget.recipe.zutaten.water.so4),
                      _buildWaterBadge('HCO3', widget.recipe.zutaten.water.hco3),
                    ],
                  ),

                  const SizedBox(height: 16),
                  if (loading) 
                     const Center(child: CircularProgressIndicator())
                  else if (profile == null)
                     Card(
                        color: Colors.red.shade900,
                        child: Padding(
                           padding: const EdgeInsets.all(16),
                           child: Column(children: [
                              const Text('Kein Wasserprofil (Favorit) gefunden!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 8),
                              const Text('Bitte lege ein Wasserprofil an und markiere es als Standard.', style: TextStyle(color: Colors.white70)),
                              const SizedBox(height: 8),
                              ElevatedButton(onPressed: _useDistilled, child: const Text('Mit Destilliertem Wasser berechnen'))
                           ]),
                        )
                     )
                  else 
                     _buildWaterDiff(profile),

                  if (widget.recipe.zutaten.specials.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionTitle('Spezialzutaten'),
                    ...widget.recipe.zutaten.specials.map((s) => ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                      title: Text(s.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(s.detail),
                      trailing: Text('${s.amount} ${s.unit}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    )),
                  ],
                  
                  if (widget.recipe.zutaten.finings.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    const SectionTitle('Schönungsmittel'),
                    ...widget.recipe.zutaten.finings.map((f) => ListTile(
                      title: Text('${f.name} (${f.purpose})'),
                      subtitle: Text('Phase: ${f.phase}\nMenge: ${f.amount}\n${f.applicationDetail}'),
                      isThreeLine: true,
                      trailing: f.procurementNeeded 
                        ? const Chip(label: Text('Beschaffung nötig!'), backgroundColor: Colors.orangeAccent)
                        : const Chip(label: Text('Vorhanden'), backgroundColor: Colors.greenAccent),
                    )),
                  ]
               ],
            ),
         );
      }
    );
  }

  Widget _buildWaterDiff(WaterProfile profile) {
     final additions = WaterCalculator.calculate(
         source: profile,
         target: widget.recipe.zutaten.water,
         mashVolumeL: widget.recipe.prozessdaten.mash.mashWaterL,
         spargeVolumeL: widget.recipe.prozessdaten.lauter.spargeWaterL,
         strategy: widget.recipe.zutaten.water.saltTiming 
     );
     
     if (additions.isEmpty) return const SizedBox.shrink();

     return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text('Zugabe der Salze zum Ausgangswasserprofil: ${profile.name}', style: const TextStyle(fontWeight: FontWeight.bold, decoration: TextDecoration.underline)),
            if (widget.recipe.zutaten.water.saltTiming.isNotEmpty)
               Padding(padding: const EdgeInsets.only(top:4, bottom: 4), child: Text('Strategie: ${widget.recipe.zutaten.water.saltTiming}', style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12, color: Colors.grey))),
            ...additions.map((a) => ListTile(
               contentPadding: const EdgeInsets.symmetric(horizontal: 8),
               dense: true,
               title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w600)), 
               subtitle: Text('Zugabe: ${a.timing}'), 
               trailing: Text('${a.amountG.toStringAsFixed(2)} g', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18))
            )),
        ]
     );
  }

  Widget _buildKeyStatsCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statItem('Stammwürze', '${widget.recipe.stammwuerzeSg?.toStringAsFixed(3) ?? "-"} SG'),
            _statItem('Restextrakt', '${widget.recipe.restextraktSg?.toStringAsFixed(3) ?? "-"} SG'),
            _statItem('ABV', '${widget.recipe.alkoholgehalt?.toStringAsFixed(1) ?? "-"} %'),
            _statItem('IBU/EBU', widget.recipe.ibu?.toStringAsFixed(0) ?? '-'),
          ],
        ),
      ),
    );
  }

  Widget _statItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
  
  Widget _buildWaterBadge(String ion, int val) {
    return Chip(label: Text('$ion: $val mg/L'));
  }


}

class _ProcessTab extends StatelessWidget {
  final AiRecipe recipe;
  const _ProcessTab({required this.recipe});

  @override
  Widget build(BuildContext context) {
    // Filter and sort hops regarding boil time
    final boilHops = recipe.zutaten.hops
        .where((h) =>
            h.use.toLowerCase().contains('kochen') ||
            h.use.toLowerCase().contains('würze') ||
            h.use.toLowerCase().contains('whirlpool'))
        .toList()
      ..sort((a, b) => b.timeMin.compareTo(a.timeMin));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Maischen'),
          Text('Hauptguss: ${recipe.prozessdaten.mash.mashWaterL} Liter'),
          Text('Einmaischen bei: ${recipe.prozessdaten.mash.mashInTemp} °C'),
          const SizedBox(height: 8),
          ...recipe.prozessdaten.mash.steps.map((step) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.timer),
            title: Text(step.stage, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('${step.temp} °C'),
            trailing: Text('${step.duration} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          )),
          
          const Divider(height: 32),
          const SectionTitle('Läutern'),
          Text('Nachguss: ${recipe.prozessdaten.lauter.spargeWaterL} Liter'),
          if (recipe.prozessdaten.lauter.targetPh.isNotEmpty)
            Text('Ziel-pH: ${recipe.prozessdaten.lauter.targetPh}'),

          const Divider(height: 32),
          const SectionTitle('Volumen-Bilanz (Berechnet)'),
          if (recipe.prozessdaten.volumeCalculation != null)
             Container(
               padding: const EdgeInsets.all(12),
               margin: const EdgeInsets.only(bottom: 16),
               decoration: BoxDecoration(
                 color: Colors.blueGrey.withValues(alpha: 0.1),
                 borderRadius: BorderRadius.circular(8),
                 border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    _buildCalcRow('1. Im Gärgefäß (kalt):', '${recipe.prozessdaten.volumeCalculation!.step1EimerKalt} L'),
                    _buildCalcRow('2. Ausschlagwürze (heiß 100°C):', '${recipe.prozessdaten.volumeCalculation!.step2AusschlagHeiss} L'),
                    _buildCalcRow('3. Im Kessel (Post-Boil heiß):', '${recipe.prozessdaten.volumeCalculation!.step3KochEndeHeiss} L'),
                    _buildCalcRow('4. Pfannevoll (Pre-Boil):', '${recipe.prozessdaten.volumeCalculation!.step4Pfannevoll} L'),
                    if (recipe.prozessdaten.volumeCalculation!.calculationNote.isNotEmpty) ...[
                       const Divider(),
                       Text('Rechenweg-Notiz:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueAccent.shade100)),
                       Text(recipe.prozessdaten.volumeCalculation!.calculationNote, style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic)),
                    ]
                 ],
               ),
             )
          else
             const Text('Keine Berechnungsdaten verfügbar.', style: TextStyle(color: Colors.grey)),

          const SectionTitle('Kochen'),
          ListTile(
            title: const Text('Würzekochen (Gesamt)'),
            subtitle: Text('Pfannevoll: ${recipe.prozessdaten.boil.preBoilVolumeL} Liter'),
            trailing: Text('Gesamt: ${recipe.prozessdaten.boil.duration} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          ...boilHops.map((h) => ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.grass),
              title: Text('${h.amountG.toStringAsFixed(0)}g ${h.name}', style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('${h.alpha}% Alpha (${h.use})'),
              trailing: Text('Kochzeit: ${h.timeMin} min', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          )),

          const Divider(height: 32),
          const SectionTitle('Gärung'),
          if (recipe.prozessdaten.fermentation.pressureNote.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Text(
                recipe.prozessdaten.fermentation.pressureNote,
                style: const TextStyle(
                  fontStyle: FontStyle.italic,
                  color: Colors.orangeAccent,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          Text('Anstelltemperatur: ${recipe.prozessdaten.fermentation.pitchTemp} °C'),
          const SizedBox(height: 8),
          ...recipe.prozessdaten.fermentation.steps.map((step) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.thermostat),
            title: Text(step.phase, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (step.pressure > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 2),
                    child: Text(
                      'Druck: ${step.pressure.toStringAsFixed(1)} bar${step.pressureReason.isNotEmpty ? ' (${step.pressureReason})' : ''}',
                      style: const TextStyle(color: Colors.cyanAccent, fontWeight: FontWeight.bold),
                    ),
                  ),
                Text(step.note.isNotEmpty ? step.note : 'Keine besonderen Hinweise'),
              ],
            ),
            trailing: Text('${step.temp} °C / ${step.days} Tage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          )),
        ],
      ),
    );
  }

  Widget _buildCalcRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: Colors.white70)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        ],
      ),
    );
  }


}

class _PackagingTab extends StatelessWidget {
  final AiRecipe recipe;
  const _PackagingTab({required this.recipe});

  @override
  Widget build(BuildContext context) {
    final pack = recipe.prozessdaten.packaging;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Abfüllung'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            title: const Text('Abfüllung Typ', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Ziel-CO2: ${pack.co2Target} g/L'),
            trailing: Text(pack.type, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (pack.bottleSugar > 0)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Flaschengärung', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Zuckerzugabe (bei ${pack.bottleTemp.toStringAsFixed(1)} °C)'),
              trailing: Text('${pack.bottleSugar.toStringAsFixed(1)} g/L', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          if (pack.kegPressure > 0)
             ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              title: const Text('Zwangskarbonisierung (Keg)', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text('Spundungsdruck (bei ${pack.kegTemp.toStringAsFixed(1)} °C)'),
              trailing: Text('${pack.kegPressure.toStringAsFixed(1)} bar', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          
          if (pack.carbonationDurationDays > 0)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.timer_outlined),
              title: const Text('Karbonisierungsdauer', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text('${pack.carbonationDurationDays} Tage', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),
          
          if (pack.servingGasRecommendation.isNotEmpty)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.gas_meter_outlined),
              title: const Text('Empfohlenes Ausschankgas', style: TextStyle(fontWeight: FontWeight.w600)),
              trailing: Text(pack.servingGasRecommendation, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ),

          const Divider(height: 32),
          const SectionTitle('Lagerung & Reifung'),
          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: const Icon(Icons.ac_unit),
            title: const Text('Lagertemperatur', style: TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text('Dauer: ${pack.storageDurationWeeks} Wochen'),
            trailing: Text('${pack.storageTemp.toStringAsFixed(1)} °C', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          if (pack.maturationNote.isNotEmpty)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 8),
              leading: const Icon(Icons.info_outline),
              title: const Text('Hinweis', style: TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(pack.maturationNote),
            ),

          const Divider(height: 32),
          const SectionTitle('Notizen des KI-Braumeisters'),
          if (recipe.notizen.isEmpty) 
            const Text('Keine weiteren Notizen.'),
          ...recipe.notizen.map((n) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(n),
            ),
          )),
        ],
      ),
    );
  }


}
