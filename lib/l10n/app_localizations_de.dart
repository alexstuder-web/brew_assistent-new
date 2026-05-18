// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'AiBrewGenius';

  @override
  String get userProfile => 'Benutzerprofil';

  @override
  String get name => 'Name';

  @override
  String get save => 'Speichern';

  @override
  String get saveProfile => 'Profil speichern';

  @override
  String get language => 'Sprache';

  @override
  String get settings => 'Einstellungen';

  @override
  String get waterProfiles => 'Wasserprofile';

  @override
  String get brewKettles => 'Braukessel';

  @override
  String get fermenters => 'Fermentierer';

  @override
  String get keezer => 'Keezer';

  @override
  String get fermenterControllers => 'Fermentierer-Kontroller';

  @override
  String get packaging => 'Zielmenge, Abfüllen & Lagern';

  @override
  String get finingAgents => 'Klärmittel';

  @override
  String get howTo => 'How To\'s';

  @override
  String get breweryShops => 'Brauerei Shops';

  @override
  String get integrations => 'Integration';

  @override
  String get brewfather => 'Brewfather';

  @override
  String get yeast => 'Hefe';

  @override
  String get fermentables => 'Vergärbare Zutaten';

  @override
  String get hops => 'Hopfen';

  @override
  String get miscs => 'Sonstiges';

  @override
  String get recipes => 'Rezepte';

  @override
  String get batches => 'Sud / Batches';

  @override
  String get videoInstructions => 'Video Anleitungen';

  @override
  String get aiDisclaimer =>
      'Dieses Rezept wurde von einer KI erstellt. Keine Garantie für Qualität oder Richtigkeit.';

  @override
  String tapDetails(int number) {
    return 'Zapfhahn # $number Details';
  }

  @override
  String get beerName => 'Bier Name';

  @override
  String get tappedAt => 'Angezapft am';

  @override
  String get bestBefore => 'Genießbar bis';

  @override
  String get notSet => 'Nicht festgelegt';

  @override
  String get cancel => 'Abbrechen';

  @override
  String get empty => 'Leer';

  @override
  String get noConfig => 'Noch keine Konfiguration vorhanden.';

  @override
  String get configureNow => 'Jetzt konfigurieren';

  @override
  String get analyzeRecipe => 'Rezept analysieren';

  @override
  String get analysisResult => 'Analyse Ergebnis';
}
