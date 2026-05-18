import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en')
  ];

  /// Der Titel der Anwendung
  ///
  /// In de, this message translates to:
  /// **'AiBrewGenius'**
  String get appTitle;

  /// No description provided for @userProfile.
  ///
  /// In de, this message translates to:
  /// **'Benutzerprofil'**
  String get userProfile;

  /// No description provided for @name.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @save.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get save;

  /// No description provided for @saveProfile.
  ///
  /// In de, this message translates to:
  /// **'Profil speichern'**
  String get saveProfile;

  /// No description provided for @language.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get language;

  /// No description provided for @settings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settings;

  /// No description provided for @waterProfiles.
  ///
  /// In de, this message translates to:
  /// **'Wasserprofile'**
  String get waterProfiles;

  /// No description provided for @brewKettles.
  ///
  /// In de, this message translates to:
  /// **'Braukessel'**
  String get brewKettles;

  /// No description provided for @fermenters.
  ///
  /// In de, this message translates to:
  /// **'Fermentierer'**
  String get fermenters;

  /// No description provided for @keezer.
  ///
  /// In de, this message translates to:
  /// **'Keezer'**
  String get keezer;

  /// No description provided for @fermenterControllers.
  ///
  /// In de, this message translates to:
  /// **'Fermentierer-Kontroller'**
  String get fermenterControllers;

  /// No description provided for @packaging.
  ///
  /// In de, this message translates to:
  /// **'Zielmenge, Abfüllen & Lagern'**
  String get packaging;

  /// No description provided for @finingAgents.
  ///
  /// In de, this message translates to:
  /// **'Klärmittel'**
  String get finingAgents;

  /// No description provided for @howTo.
  ///
  /// In de, this message translates to:
  /// **'How To\'s'**
  String get howTo;

  /// No description provided for @breweryShops.
  ///
  /// In de, this message translates to:
  /// **'Brauerei Shops'**
  String get breweryShops;

  /// No description provided for @integrations.
  ///
  /// In de, this message translates to:
  /// **'Integration'**
  String get integrations;

  /// No description provided for @brewfather.
  ///
  /// In de, this message translates to:
  /// **'Brewfather'**
  String get brewfather;

  /// No description provided for @yeast.
  ///
  /// In de, this message translates to:
  /// **'Hefe'**
  String get yeast;

  /// No description provided for @fermentables.
  ///
  /// In de, this message translates to:
  /// **'Vergärbare Zutaten'**
  String get fermentables;

  /// No description provided for @hops.
  ///
  /// In de, this message translates to:
  /// **'Hopfen'**
  String get hops;

  /// No description provided for @miscs.
  ///
  /// In de, this message translates to:
  /// **'Sonstiges'**
  String get miscs;

  /// No description provided for @recipes.
  ///
  /// In de, this message translates to:
  /// **'Rezepte'**
  String get recipes;

  /// No description provided for @batches.
  ///
  /// In de, this message translates to:
  /// **'Sud / Batches'**
  String get batches;

  /// No description provided for @videoInstructions.
  ///
  /// In de, this message translates to:
  /// **'Video Anleitungen'**
  String get videoInstructions;

  /// No description provided for @aiDisclaimer.
  ///
  /// In de, this message translates to:
  /// **'Dieses Rezept wurde von einer KI erstellt. Keine Garantie für Qualität oder Richtigkeit.'**
  String get aiDisclaimer;

  /// No description provided for @tapDetails.
  ///
  /// In de, this message translates to:
  /// **'Zapfhahn # {number} Details'**
  String tapDetails(int number);

  /// No description provided for @beerName.
  ///
  /// In de, this message translates to:
  /// **'Bier Name'**
  String get beerName;

  /// No description provided for @tappedAt.
  ///
  /// In de, this message translates to:
  /// **'Angezapft am'**
  String get tappedAt;

  /// No description provided for @bestBefore.
  ///
  /// In de, this message translates to:
  /// **'Genießbar bis'**
  String get bestBefore;

  /// No description provided for @notSet.
  ///
  /// In de, this message translates to:
  /// **'Nicht festgelegt'**
  String get notSet;

  /// No description provided for @cancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get cancel;

  /// No description provided for @empty.
  ///
  /// In de, this message translates to:
  /// **'Leer'**
  String get empty;

  /// No description provided for @noConfig.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Konfiguration vorhanden.'**
  String get noConfig;

  /// No description provided for @configureNow.
  ///
  /// In de, this message translates to:
  /// **'Jetzt konfigurieren'**
  String get configureNow;

  /// No description provided for @analyzeRecipe.
  ///
  /// In de, this message translates to:
  /// **'Rezept analysieren'**
  String get analyzeRecipe;

  /// No description provided for @analysisResult.
  ///
  /// In de, this message translates to:
  /// **'Analyse Ergebnis'**
  String get analysisResult;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
