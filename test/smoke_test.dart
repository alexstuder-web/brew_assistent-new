import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:brew_genius/services/user_profile_service.dart';
import 'package:brew_genius/services/water_profile_service.dart';
import 'package:brew_genius/models/user_profile.dart';
import 'package:brew_genius/models/water_profile.dart';
import 'package:brew_genius/models/bf_recipe.dart';
import 'package:brew_genius/models/bf_batch.dart';
import 'package:brew_genius/pages/user_profile_page.dart';
import 'package:brew_genius/pages/brew_entry_page.dart';
import 'package:brew_genius/models/misc.dart';
import 'package:brew_genius/models/hop.dart';
import 'package:brew_genius/models/fermentable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:brew_genius/l10n/app_localizations.dart';

class TestAssetBundle extends CachingAssetBundle {
  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return '{}';
  }
  @override
  Future<ByteData> load(String key) async {
    if (key == 'AssetManifest.bin') {
      final emptyMap = <Object, Object>{};
      final data = const StandardMessageCodec().encodeMessage(emptyMap);
      return data!;
    }
    if (key == 'AssetManifest.json') {
       return ByteData.view(Uint8List.fromList(utf8.encode('{}')).buffer);
    }
    final transparentPixel = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR4nGMAAQAABQABDQottAAAAABJRU5ErkJggg==',
    );
    return ByteData.view(transparentPixel.buffer);
  }
}

class MockLocalStorage extends LocalStorage {
  @override
  Future<void> initialize() async {}
  @override
  Future<bool> hasAccessToken() async => false;
  @override
  Future<String?> accessToken() async => null;
  @override
  Future<void> persistSession(String persistSessionString) async {}
  @override
  Future<void> removePersistedSession() async {}
}

class MockUserProfileRepository implements UserProfileRepository {
  @override
  Future<UserProfile?> fetchProfile(String id) async {
    return UserProfile(
      id: 'test_id',
      name: 'Test User',
      defaultBatchLiters: 20.0,
      brewfatherSyncEnabled: false,
    );
  }
  @override
  Future<UserProfile?> fetchDefaultProfile({bool refresh = false}) async => fetchProfile('any');
  @override
  Future<void> saveProfile(UserProfile profile) async {}
  
  @override Future<List<Fermentable>> getFermentables(String id) async => [];
  @override Future<void> saveFermentables(List<Fermentable> f) async {}
  @override Future<void> saveFermentable(Fermentable f) async {}
  @override Future<void> deleteFermentable(String id) async {}
  
  @override Future<List<Hop>> getHops(String id) async => [];
  @override Future<void> saveHops(List<Hop> h) async {}
  @override Future<void> saveHop(Hop h) async {}
  
  @override Future<List<Misc>> getMiscs(String id) async => [];
  @override Future<void> saveMiscs(List<Misc> m) async {}
  @override Future<void> saveMisc(Misc m) async {}
  
  @override Future<List<BfRecipe>> getRecipes(String id) async => [];
  @override Future<void> saveRecipes(List<BfRecipe> r) async {}
  
  @override Future<List<BfBatch>> getBatches(String id) async => [];
  @override Future<void> saveBatches(List<BfBatch> b, {bool syncDeletions = false}) async {}
}

class MockWaterProfileRepository implements WaterProfileRepository {
  @override Future<List<WaterProfile>> fetchProfiles(String id) async => [];
  @override Future<WaterProfile> saveProfile(WaterProfile p) async => p;
  @override Future<void> deleteProfile(String id) async {}
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    // Initialize Supabase with dummy data to prevent crashes in sub-pages that instantiate the singleton.
    // The network calls will fail, but that's expected and handled by error states.
    try {
      await Supabase.initialize(
        url: 'https://example.com',
        anonKey: 'dummy',
        authOptions: FlutterAuthClientOptions(localStorage: MockLocalStorage()),
      );
    } catch (_) {
      // Ignore if already initialized
    }
  });

  testWidgets('Smoke Test: App starts and shows main menu', (WidgetTester tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: [Locale('de'), Locale('en')],
          locale: Locale('de'),
          home: BrewEntryPage(),
        ),
      ),
    );
    expect(find.text('Users profil'), findsOneWidget);
  });

  testWidgets('Smoke Test: UserProfilePage buttons navigate correctly', (WidgetTester tester) async {
    await tester.pumpWidget(
      DefaultAssetBundle(
        bundle: TestAssetBundle(),
        child: MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [Locale('de'), Locale('en')],
          locale: const Locale('de'),
          home: UserProfilePage(
            profileRepository: MockUserProfileRepository(),
            waterRepository: MockWaterProfileRepository(),
          ),
        ),
      ),
    );
    
    // Allow profile to load
    await tester.pumpAndSettle();
    expect(find.text('Test User'), findsOneWidget);

    final buttons = [
      'Wasserprofile',
      'Braukessel',
      'Fermentierer',
      'Fermentierer-Kontroller',
      'Zielmenge, Abfüllen & Lagern',
      'Klärmittel',
      'How To\'s',
      'Brauerei Shops',
      'Video Anleitungen',
      'Integration',
      'Brewfather',
      'Hefe',
      'Vergärbare Zutaten',
      'Hopfen',
      'Sonstiges',
      'Rezepte',
      'Sud / Batches'
    ];

    // Find the Scrollable inside SingleChildScrollView
    final scrollable = find.descendant(
      of: find.byType(SingleChildScrollView),
      matching: find.byType(Scrollable),
    ).first;

    for (final btnLabel in buttons) {
      // Find button specifically to avoid duplicates/ambiguity
      final buttonFinder = find.widgetWithText(OutlinedButton, btnLabel);
      
      // Scroll until visible
      await tester.scrollUntilVisible(
        buttonFinder,
        100,
        scrollable: scrollable,
      );
      expect(buttonFinder, findsOneWidget);
      
      // Tap button
      await tester.tap(buttonFinder);
      await tester.pumpAndSettle();

      // Verify navigation (presence of AppBar)
      expect(find.byType(AppBar), findsOneWidget); 
      
      // Go back
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      if (find.text('Test User').evaluate().isEmpty && find.byType(BackButton).evaluate().isNotEmpty) {
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
      }
      
      // Verify we are back (find user name again)
      expect(find.text('Test User'), findsOneWidget);
    }
  });
}
