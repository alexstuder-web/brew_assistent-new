import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'utils/env_config.dart';
import 'utils/cookie_session_storage.dart';
import 'utils/session_sync_widget.dart';
import 'widgets/auth_gate.dart';
import 'pages/user_profile_page.dart';
import 'pages/recipe_prompt_page.dart';
import 'pages/brew_entry_page.dart';
import 'pages/discovery_welcome_page.dart';
import 'l10n/app_localizations.dart';

import 'services/user_profile_service.dart';
import 'services/water_profile_service.dart';
import 'services/brew_kettle_service.dart';
import 'services/fermenter_service.dart';
import 'services/fermenter_controller_service.dart';
import 'services/malt_depot_service.dart';
import 'services/packaging_profile_service.dart';
import 'services/fining_agents_service.dart';
import 'services/yeast_bank_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  await initializeDateFormatting('de_DE', null);

  // URL aus aktuellem Hostname ableiten (lokal vs. VPS — siehe EnvConfig).
  // Anon Key bleibt aus dem .env Asset (build-time, kann nicht runtime abgeleitet werden).
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl(),
    anonKey: EnvConfig.supabaseAnonKey(),
    postgrestOptions: const PostgrestClientOptions(schema: 'aibrewgenius'),
    authOptions: FlutterAuthClientOptions(localStorage: CookieSessionStorage()),
  );

  // Pre-auth: kein Profil-Fetch (RLS blockt). Locale 'de' als Default,
  // Profil-Sprache greift erst nach Login (AuthGate setzt sie nach Profil-Fetch um).
  runApp(
    SessionSyncWidget(
      child: BrewMateApp(key: BrewMateApp.appKey, initialLocale: const Locale('de')),
    ),
  );
}

class BrewMateApp extends StatefulWidget {
  const BrewMateApp({
    super.key,
    required this.initialLocale,
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

  final Locale initialLocale;
  final UserProfileRepository? profileRepository;
  final WaterProfileRepository? waterRepository;
  final BrewKettleRepository? brewKettleRepository;
  final FermenterRepository? fermenterRepository;
  final FermenterControllerRepository? fermenterControllerRepository;
  final MaltDepotRepository? maltDepotRepository;
  final PackagingProfileRepository? packagingRepository;
  final FiningAgentsRepository? finingAgentsRepository;
  final YeastBankRepository? yeastRepository;

  /// Internal GlobalKey for locale changes from outside the widget tree (e.g.
  /// AuthGate after an async profile fetch where BuildContext is unavailable).
  // ignore: library_private_types_in_public_api
  static final GlobalKey<_BrewMateAppState> appKey = GlobalKey<_BrewMateAppState>();

  /// Apply [newLocale] via [appKey] — safe to call from async callbacks.
  static void applyLocale(Locale newLocale) {
    appKey.currentState?.setLocale(newLocale);
  }

  /// Context-based variant kept for callers that already hold a mounted context
  /// (e.g. UserProfileController.saveProfile).
  static void setLocale(BuildContext context, Locale newLocale) {
    _BrewMateAppState? state = context.findAncestorStateOfType<_BrewMateAppState>();
    state?.setLocale(newLocale);
  }

  @override
  State<BrewMateApp> createState() => _BrewMateAppState();
}

class _BrewMateAppState extends State<BrewMateApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
    _updateDateFormatting();
  }

  void setLocale(Locale locale) {
    setState(() {
      _locale = locale;
    });
    _updateDateFormatting();
  }

  void _updateDateFormatting() {
    final localeStr = _locale.languageCode == 'de' ? 'de_DE' : 'en_US';
    initializeDateFormatting(localeStr, null);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AiBrewGenius',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData.dark().copyWith(
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF2563EB),
        ),
        inputDecorationTheme: const InputDecorationTheme(
          filled: true,
          fillColor: Color(0xFF1E293B),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
            borderSide: BorderSide.none,
          ),
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
      ),
      initialRoute: BrewEntryPage.routeName,
      routes: {
        BrewEntryPage.routeName: (_) => const BrewEntryPage(),
        UserProfilePage.routeName: (_) => UserProfilePage(
              profileRepository: widget.profileRepository,
              waterRepository: widget.waterRepository,
              brewKettleRepository: widget.brewKettleRepository,
              fermenterRepository: widget.fermenterRepository,
              fermenterControllerRepository: widget.fermenterControllerRepository,
              maltDepotRepository: widget.maltDepotRepository,
              packagingRepository: widget.packagingRepository,
              finingAgentsRepository: widget.finingAgentsRepository,
              yeastRepository: widget.yeastRepository,
            ),
        DiscoveryWelcomePage.routeName: (_) => const DiscoveryWelcomePage(),
        RecipePromptPage.routeName: (_) => const RecipePromptPage(),
      },
      builder: (context, child) =>
          AuthGate(signedIn: child ?? const SizedBox.shrink()),
    );
  }
}
