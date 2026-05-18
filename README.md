# AiBrewGenius 🍺

Ein kleines Flutter-Projekt, das jetzt als AiBrewGenius individuelle Bierrezepte über die OpenAI API generiert. Die App läuft auf Android, iOS und im Web und bietet eine Eingabemaske für einen Prompt sowie die Darstellung der erzeugten Antwort.

## Voraussetzungen

- Flutter SDK (≥ 3.4)  
- Für iOS: Xcode & CocoaPods  
- Für Android: Android Studio oder die Android command-line tools  
- Ein gültiger OpenAI API Key

## Projekt einrichten

```bash
cd flutter_brew_assistent
cp .env.example .env
# .env anpassen und den eigenen API-Key hinterlegen

flutter pub get
```

## App starten

```bash
# Web
flutter run -d chrome

# iOS (Simulator)
flutter run -d ios

# Android (Emulator)
flutter run -d android
```

## Architektur

- `lib/main.dart`: UI + Stateful Widget für Prompt-Eingabe und Ergebnisanzeige  
- `lib/services/openai_service.dart`: Einfache Service-Klasse, die die Chat Completions API (`gpt-4o-mini`) anspricht  
- `.env`: wird über `flutter_dotenv` geladen, um den OpenAI-Schlüssel nicht ins Repo einzuchecken

## Sicherheitshinweis

Der OpenAI-Key darf niemals eingecheckt oder clientseitig offengelegt werden. Für produktive Apps empfiehlt sich ein Proxy-Backend, das die Anfrage serverseitig proxy’t und den Key schützt.

Viel Spaß beim Experimentieren und Prost! 🍻
