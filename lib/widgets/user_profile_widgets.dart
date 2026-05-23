import 'dart:convert';
import 'package:flutter/material.dart';

import '../controllers/user_profile_controller.dart';
import '../l10n/app_localizations.dart';
import '../services/water_profile_service.dart';
import '../services/brew_kettle_service.dart';
import '../services/fermenter_service.dart';
import '../services/fermenter_controller_service.dart';
import '../services/malt_depot_service.dart';
import '../services/packaging_profile_service.dart';
import '../services/fining_agents_service.dart';
import '../services/yeast_bank_service.dart';

import '../pages/generated_recipes_list_page.dart';
import '../pages/water_profile_manager_page.dart';
import '../pages/brew_kettle_manager_page.dart';
import '../pages/fermenter_manager_page.dart';
import '../pages/fermenter_controller_manager_page.dart';
import '../pages/packaging_profile_manager_page.dart';
import '../pages/fining_agents_page.dart';
import '../pages/how_to_page.dart';
import '../pages/malt_depot_manager_page.dart';
import '../pages/integrations_page.dart';
import '../pages/brewfather_menu_page.dart';
import '../pages/yeast_bank_manager_page.dart';
import '../pages/available_ingredients_page.dart';
import '../pages/hops_manager_page.dart';
import '../pages/miscs_manager_page.dart';
import '../pages/recipes_list_page.dart';
import '../pages/batches_list_page.dart';
import '../pages/keezer_manager_page.dart';
import '../pages/video_instructions_page.dart';

class UserProfileSection extends StatelessWidget {
  final UserProfileController controller;

  const UserProfileSection({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    ImageProvider? avatarImage;
    if (controller.newAvatarBase64 != null) {
      avatarImage = MemoryImage(base64Decode(controller.newAvatarBase64!));
    } else if (controller.loadedProfile?.avatarBlob != null &&
        controller.loadedProfile!.avatarBlob!.isNotEmpty) {
      avatarImage = MemoryImage(base64Decode(controller.loadedProfile!.avatarBlob!));
    }

    return Card(
      color: const Color(0xFF0F172A),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'User',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                GestureDetector(
                  onTap: () => controller.uploadAvatar(context),
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: const Color(0xFF1D4ED8),
                        backgroundImage: avatarImage,
                        child: avatarImage == null
                            ? Icon(
                                Icons.person_outline,
                                size: 36,
                                color: Colors.white.withValues(alpha: 0.9),
                              )
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2563EB),
                            shape: BoxShape.circle,
                            border: Border.all(
                                color: Theme.of(context).scaffoldBackgroundColor,
                                width: 1.5),
                          ),
                          child: const Icon(Icons.camera_alt,
                              size: 12, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: controller.userNameCtrl,
                    focusNode: controller.userNameFocusNode,
                    decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)!.name,
                      hintText: 'z. B. Alex Studer',
                      errorText: controller.userNameError,
                    ),
                    onChanged: (_) => controller.clearUserNameError(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: controller.selectedLanguage,
              decoration: InputDecoration(
                labelText: AppLocalizations.of(context)!.language,
                prefixIcon: const Icon(Icons.language),
              ),
              items: const [
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (val) {
                if (val != null) {
                  controller.setLanguage(val);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class ResourceButtonsGrid extends StatelessWidget {
  final UserProfileController controller;
  final WaterProfileRepository? waterRepository;
  final BrewKettleRepository? brewKettleRepository;
  final FermenterRepository? fermenterRepository;
  final FermenterControllerRepository? fermenterControllerRepository;
  final MaltDepotRepository? maltDepotRepository;
  final PackagingProfileRepository? packagingRepository;
  final FiningAgentsRepository? finingAgentsRepository;
  final YeastBankRepository? yeastRepository;

  const ResourceButtonsGrid({
    super.key,
    required this.controller,
    this.waterRepository,
    this.brewKettleRepository,
    this.fermenterRepository,
    this.fermenterControllerRepository,
    this.maltDepotRepository,
    this.packagingRepository,
    this.finingAgentsRepository,
    this.yeastRepository,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 60,
          ),
          children: [
            _managerButton(
              context,
              icon: Icons.receipt_long,
              label: 'Generierte Rezepte',
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => GeneratedRecipesListPage()),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.water_drop_outlined,
              label: AppLocalizations.of(context)!.waterProfiles,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => WaterProfileManagerPage(profileId: UserProfileController.profileId, repository: waterRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.kitchen_outlined,
              label: AppLocalizations.of(context)!.brewKettles,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BrewKettleManagerPage(profileId: UserProfileController.profileId, repository: brewKettleRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.science_outlined,
              label: AppLocalizations.of(context)!.fermenters,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FermenterManagerPage(profileId: UserProfileController.profileId, repository: fermenterRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.kitchen,
              label: AppLocalizations.of(context)!.keezer,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => KeezerManagerPage(profileId: UserProfileController.profileId)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.developer_board_outlined,
              label: AppLocalizations.of(context)!.fermenterControllers,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FermenterControllerManagerPage(profileId: UserProfileController.profileId, repository: fermenterControllerRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.inventory_2_outlined,
              label: AppLocalizations.of(context)!.packaging,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => PackagingProfileManagerPage(profileId: UserProfileController.profileId, repository: packagingRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.filter_alt_outlined,
              label: AppLocalizations.of(context)!.finingAgents,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => FiningAgentsPage(profileId: UserProfileController.profileId, repository: finingAgentsRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.help_outline,
              label: AppLocalizations.of(context)!.howTo,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HowToPage()),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.warehouse_outlined,
              label: AppLocalizations.of(context)!.breweryShops,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MaltDepotManagerPage(profileId: UserProfileController.profileId, repository: maltDepotRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.video_library_outlined,
              label: AppLocalizations.of(context)!.videoInstructions,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => VideoInstructionsPage(profileId: UserProfileController.profileId)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Divider(color: Colors.white24),
        const SizedBox(height: 24),
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 60,
          ),
          children: [
            _managerButton(
              context,
              icon: Icons.extension_outlined,
              label: AppLocalizations.of(context)!.integrations,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => IntegrationsPage(profileId: UserProfileController.profileId)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.cloud_download_outlined,
              label: AppLocalizations.of(context)!.brewfather,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BrewfatherMenuPage(profileId: UserProfileController.profileId)),
              ),
              customIcon: Image.asset(
                'assets/Brewfather_logo.png',
                width: 24,
                height: 24,
              ),
            ),
            _managerButton(
              context,
              icon: Icons.biotech_outlined,
              label: AppLocalizations.of(context)!.yeast,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => YeastBankManagerPage(profileId: UserProfileController.profileId, repository: yeastRepository, userRepository: controller.profileRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.grain_outlined,
              label: AppLocalizations.of(context)!.fermentables,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => AvailableIngredientsPage(profileId: UserProfileController.profileId, userRepository: controller.profileRepository)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.grass_outlined,
              label: AppLocalizations.of(context)!.hops,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => HopsManagerPage(profileId: UserProfileController.profileId)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.category_outlined,
              label: AppLocalizations.of(context)!.miscs,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => MiscsManagerPage(profileId: UserProfileController.profileId)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.menu_book,
              label: AppLocalizations.of(context)!.recipes,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => RecipesListPage(profileId: UserProfileController.profileId)),
              ),
            ),
            _managerButton(
              context,
              icon: Icons.history_edu,
              label: AppLocalizations.of(context)!.batches,
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => BatchesListPage(profileId: UserProfileController.profileId)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _managerButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Widget? customIcon,
  }) {
    return OutlinedButton.icon(
      onPressed: () async {
        if (!controller.ensureUserName(context)) return;
        final saved = await controller.saveProfileIfNeeded(context);
        if (!saved) return;
        onPressed();
      },
      icon: customIcon ?? Icon(icon),
      label: Text(
        label,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 4),
      ),
    );
  }
}
