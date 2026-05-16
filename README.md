# brew_assistent

KI-gestützter Brauassistent für Hobbybrauer – Flutter Web App, ausgeliefert via Nginx-Container.

## Features
- Rezeptgenerator via OpenAI GPT
- Schritt-für-Schritt Brauanleitung
- Verbindung zum zentralen `api_proxy` für sichere API-Key-Verwaltung

## Architektur
- Container: `web_assistent`
- Deployment: GitOps via Watchtower
- Tunnel: Cloudflare → `assistent.alexstuder.ch`

## Lokale Entwicklung
```bash
flutter pub get
flutter run -d chrome
```

## Deployment
Push auf `main` → GitHub Actions → Docker Hub → Watchtower deployed automatisch.
