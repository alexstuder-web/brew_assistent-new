// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'AiBrewGenius';

  @override
  String get userProfile => 'User Profile';

  @override
  String get name => 'Name';

  @override
  String get save => 'Save';

  @override
  String get saveProfile => 'Save Profile';

  @override
  String get language => 'Language';

  @override
  String get settings => 'Settings';

  @override
  String get waterProfiles => 'Water Profiles';

  @override
  String get brewKettles => 'Brew Kettles';

  @override
  String get fermenters => 'Fermenters';

  @override
  String get keezer => 'Keezer';

  @override
  String get fermenterControllers => 'Fermenter Controllers';

  @override
  String get packaging => 'Packaging & Storage';

  @override
  String get finingAgents => 'Fining Agents';

  @override
  String get howTo => 'How To\'s';

  @override
  String get breweryShops => 'Brewery Shops';

  @override
  String get integrations => 'Integrations';

  @override
  String get brewfather => 'Brewfather';

  @override
  String get yeast => 'Yeast';

  @override
  String get fermentables => 'Fermentables';

  @override
  String get hops => 'Hops';

  @override
  String get miscs => 'Miscs';

  @override
  String get recipes => 'Recipes';

  @override
  String get batches => 'Batches';

  @override
  String get videoInstructions => 'Video Instructions';

  @override
  String get aiDisclaimer =>
      'This recipe was created by an AI. No guarantee for quality or correctness.';

  @override
  String tapDetails(int number) {
    return 'Tap # $number Details';
  }

  @override
  String get beerName => 'Beer Name';

  @override
  String get tappedAt => 'Tapped at';

  @override
  String get bestBefore => 'Best before';

  @override
  String get notSet => 'Not set';

  @override
  String get cancel => 'Cancel';

  @override
  String get empty => 'Empty';

  @override
  String get noConfig => 'No configuration available yet.';

  @override
  String get configureNow => 'Configure now';

  @override
  String get analyzeRecipe => 'Analyze Recipe';

  @override
  String get analysisResult => 'Analysis Result';
}
