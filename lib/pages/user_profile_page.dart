import 'package:flutter/material.dart';
import '../services/user_profile_service.dart';
import '../services/water_profile_service.dart';
import '../services/brew_kettle_service.dart';
import '../services/fermenter_service.dart';
import '../services/fermenter_controller_service.dart';
import '../services/malt_depot_service.dart';
import '../services/packaging_profile_service.dart';
import '../services/fining_agents_service.dart';
import '../services/yeast_bank_service.dart';
import '../l10n/app_localizations.dart';

import '../controllers/user_profile_controller.dart';
import '../widgets/user_profile_widgets.dart';

class UserProfilePage extends StatefulWidget {
  const UserProfilePage({
    super.key,
    this.profileRepository,
    this.waterRepository,
    this.brewKettleRepository,
    this.fermenterRepository,
    this.fermenterControllerRepository,
    this.maltDepotRepository,
    this.packagingRepository,
    this.finingAgentsRepository,
    this.yeastRepository,
  });

  static const String routeName = '/user-profile';
  final UserProfileRepository? profileRepository;
  final WaterProfileRepository? waterRepository;
  final BrewKettleRepository? brewKettleRepository;
  final FermenterRepository? fermenterRepository;
  final FermenterControllerRepository? fermenterControllerRepository;
  final MaltDepotRepository? maltDepotRepository;
  final PackagingProfileRepository? packagingRepository;
  final FiningAgentsRepository? finingAgentsRepository;
  final YeastBankRepository? yeastRepository;

  @override
  State<UserProfilePage> createState() => _UserProfilePageState();
}

class _UserProfilePageState extends State<UserProfilePage> {
  late final UserProfileController _controller;

  @override
  void initState() {
    super.initState();
    _controller = UserProfileController(repository: widget.profileRepository);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.userProfile),
        centerTitle: true,
      ),
      body: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          if (_controller.isLoadingProfile) {
            return const Center(child: CircularProgressIndicator());
          }
          return LayoutBuilder(
            builder: (context, constraints) => Align(
              alignment: Alignment.topCenter,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_controller.loadError != null) ...[
                        Card(
                          color: Colors.red.shade900.withValues(alpha: 0.35),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              'Laden fehlgeschlagen: ${_controller.loadError}',
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      UserProfileSection(controller: _controller),
                      const SizedBox(height: 20),
                      ResourceButtonsGrid(
                        controller: _controller,
                        waterRepository: widget.waterRepository,
                        brewKettleRepository: widget.brewKettleRepository,
                        fermenterRepository: widget.fermenterRepository,
                        fermenterControllerRepository: widget.fermenterControllerRepository,
                        maltDepotRepository: widget.maltDepotRepository,
                        packagingRepository: widget.packagingRepository,
                        finingAgentsRepository: widget.finingAgentsRepository,
                        yeastRepository: widget.yeastRepository,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: _controller.isSaving ? null : () => _controller.saveProfile(context),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_controller.isSaving)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            else
                              const Icon(Icons.save_rounded),
                            const SizedBox(width: 12),
                            Text(_controller.isSaving ? 'Speichert …' : AppLocalizations.of(context)!.saveProfile),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back),
                        label: const Text('Zurück'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
