import 'dart:convert';
import 'package:brew_genius/models/user_profile.dart';
import 'package:brew_genius/models/water_profile.dart';
import 'package:brew_genius/services/user_profile_service.dart';
import 'package:brew_genius/services/water_profile_service.dart';
import 'package:brew_genius/models/fermentable.dart';
import 'package:brew_genius/models/hop.dart';
import 'package:brew_genius/models/misc.dart';
import 'package:brew_genius/pages/user_profile_page.dart';
import 'package:brew_genius/pages/brew_entry_page.dart';
import 'package:brew_genius/models/bf_recipe.dart';
import 'package:brew_genius/models/bf_batch.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:brew_genius/l10n/app_localizations.dart';


void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    _registerTestAsset();
  });

  testWidgets('User can fill profile and water data via GUI flow', (tester) async {
    // Set larger window size
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    final fakeUserRepo = FakeUserProfileRepository();
    final fakeWaterRepo = FakeWaterProfileRepository();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: const [
          Locale('de'),
          Locale('en'),
        ],
        locale: const Locale('de'),
        home: const BrewEntryPage(),
        routes: {
          UserProfilePage.routeName: (_) => UserProfilePage(
                profileRepository: fakeUserRepo,
                waterRepository: fakeWaterRepo,
              ),
        },
      ),
    );

    await tester.tap(find.text('Users profil').first);
    await tester.pumpAndSettle();

    // Check if we are on UserProfilePage
    expect(find.text('Benutzerprofil'), findsWidgets);

    await tester.enterText(find.byType(TextField).first, 'Brew Master');
    await tester.pumpAndSettle();
    
    // Tap Water Profiles button
    final waterBtn = find.text('Wasserprofile');
    await tester.ensureVisible(waterBtn);
    await tester.tap(waterBtn);
    await tester.pumpAndSettle();

    final addBtn = find.text('Profil anlegen');
    await tester.ensureVisible(addBtn);
    await tester.tap(addBtn);
    await tester.pumpAndSettle();

    // In Editor
    await tester.enterText(find.byType(TextField).at(0), 'Hauswasser');
    await tester.enterText(find.byType(TextField).at(1), '5.4');

    // Values for Ca, Mg, Na...
    // In WaterProfileEditorPage, the ion fields start after Name (0) and pH (1)
    // The following index 2..7 are Ca, Mg, Na, Cl, SO4, HCO3
    final allFields = find.byType(TextField);
    await tester.enterText(allFields.at(2), '55'); // Ca
    await tester.enterText(allFields.at(3), '12'); // Mg
    await tester.enterText(allFields.at(4), '18'); // Na
    await tester.enterText(allFields.at(5), '10'); // Cl
    await tester.enterText(allFields.at(6), '45'); // SO4
    await tester.enterText(allFields.at(7), '180'); // HCO3

    await tester.tap(find.text('Speichern'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(fakeUserRepo.saveCallCount, greaterThanOrEqualTo(1));
    expect(fakeWaterRepo.lastSaved?.name, 'Hauswasser');
    expect(fakeWaterRepo.lastSaved?.ph, 5.4);
    expect(fakeWaterRepo.lastSaved?.calciumPpm, 55);
    expect(fakeWaterRepo.lastSaved?.magnesiumPpm, 12);
    expect(fakeWaterRepo.lastSaved?.sodiumPpm, 18);

    expect(find.text('Brew Master'), findsWidgets);

    // Now go back to home
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    
    expect(find.text('Users profil'), findsOneWidget);
  });
}

void _registerTestAsset() {
  final assets = [
    'assets/icon.png',
    'assets/icon_small.png',
    'assets/Brewfather_logo.png',
    '.env',
  ];
  final transparentPixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
  );
  
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
    final Uint8List list = message!.buffer.asUint8List();
    final String key = utf8.decode(list);
    
    if (assets.contains(key)) {
      return ByteData.view(transparentPixel.buffer);
    }
    
    if (key == 'AssetManifest.json' || key == 'AssetManifest.bin.json') {
      final manifestJson = jsonEncode({for (var a in assets) a: [a]});
      return ByteData.view(Uint8List.fromList(utf8.encode(manifestJson)).buffer);
    }
    
    if (key == 'AssetManifest.bin') {
      final bin = const StandardMessageCodec().encodeMessage({});
      return bin;
    }
    
    return null;
  });
}

class FakeUserProfileRepository implements UserProfileRepository {
  UserProfile? stored;
  int saveCallCount = 0;

  @override
  Future<UserProfile?> fetchProfile(String id) async {
    return stored;
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    saveCallCount += 1;
    stored = profile;
  }



  @override
  Future<UserProfile?> fetchDefaultProfile({bool refresh = false}) async {
    return stored;
  }

  @override
  Future<List<Fermentable>> getFermentables(String userProfileId) async {
    return [];
  }

  @override
  Future<void> saveFermentables(List<Fermentable> fermentables) async {
    // no-op for now
  }

  @override
  Future<void> saveFermentable(Fermentable fermentable) async {
    // no-op for now
  }
  
  @override
  Future<void> deleteFermentable(String id) async {
    // no-op
  }
  
  @override
  Future<List<Hop>> getHops(String userProfileId) async {
    return [];
  }

  @override
  Future<void> saveHops(List<Hop> hops) async {
    // no-op
  }

  @override
  Future<void> saveHop(Hop hop) async {
    // no-op
  }
  
  @override
  Future<List<Misc>> getMiscs(String userProfileId) async {
    return [];
  }

  @override
  Future<void> saveMiscs(List<Misc> miscs) async {
    // no-op
  }

  @override
  Future<void> saveMisc(Misc misc) async {
    // no-op
  }
  
  @override
  Future<List<BfRecipe>> getRecipes(String userProfileId) async {
    return [];
  }

  @override
  Future<void> saveRecipes(List<BfRecipe> recipes) async {
    // no-op
  }

  @override
  Future<List<BfBatch>> getBatches(String userProfileId) async {
    return [];
  }

  @override
  Future<void> saveBatches(List<BfBatch> batches, {bool syncDeletions = false}) async {
    // no-op
  }
}

class FakeWaterProfileRepository implements WaterProfileRepository {
  final List<WaterProfile> _profiles = [];
  WaterProfile? lastSaved;

  @override
  Future<void> deleteProfile(String id) async {
    _profiles.removeWhere((profile) => profile.id == id);
  }

  @override
  Future<List<WaterProfile>> fetchProfiles(String userProfileId) async {
    return _profiles
        .where((profile) => profile.userProfileId == userProfileId)
        .toList();
  }

  @override
  Future<WaterProfile> saveProfile(WaterProfile profile) async {
    final assignedId = profile.id ?? 'water_${_profiles.length + 1}';
    final saved = profile.copyWith(id: assignedId);
    _profiles.removeWhere((existing) => existing.id == assignedId);
    _profiles.add(saved);
    lastSaved = saved;
    return saved;
  }
}
