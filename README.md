# brew_assistent (AiBrewGenius)

Flutter-Web-App: AI-Bierrezepte über OpenAI + Persistenz in Supabase
(Schema `aibrewgenius`). Frontend ruft den `api-proxy` aus
[`brew-proxy-new`](https://github.com/alexstuder-web/brew-proxy-new) auf —
der hält den OpenAI-Key serverseitig.

## Status: Source-Repo

Dieses Repo ist **nur Source**. Auf `push main` baut GitHub Actions ein
Container-Image und pusht es zu Docker Hub:

```
${DOCKERHUB_USERNAME}/web_assistent:latest
```

**Production-Deployment läuft via** [`webPage_infra`](https://github.com/alexstuder-web/webPage_infra) — dort wird das Image
gezogen und neben dem Supabase-Stack gestartet. Watchtower aktualisiert
den Container alle 5 Min automatisch.

Image-Definition: siehe [`Dockerfile`](Dockerfile) (Nginx + Flutter-Web-Build).

## Lokales Dev

```bash
cp .env.example .env       # PROXY_URL + SUPABASE_URL anpassen
flutter pub get
flutter run -d chrome
```

Für lokales Testen gegen den **vollen Stack** (Supabase + Proxy + Web) →
`docker-compose.dev.yml` im `webPage_infra` Repo nutzen.

## Architektur

| Bereich | Pfad |
|---|---|
| App-Entry | `lib/main.dart` |
| OpenAI-Service | `lib/services/openai_service.dart` |
| Supabase-Client | `lib/services/recipe_repository.dart` |
| DB-Schema | `db_scripts/full/001_init_schema.sql` (manuell ausführen via Studio) |
| Currently-Brewing-Button | öffnet RAPT-Dashboard in neuem Tab (URL aus `EnvConfig.raptDashboardUrl()`) |

## Sicherheit

OpenAI-Key bleibt im `brew-proxy` — niemals im Flutter-Bundle. `PROXY_URL`
zeigt auf den `api-proxy`-Container.

## Verwandte Repos

- [`webPage_infra`](https://github.com/alexstuder-web/webPage_infra) — Production-Compose + Bootstrap
- [`brew-proxy-new`](https://github.com/alexstuder-web/brew-proxy-new) — OpenAI/RAPT/Brewfather-Proxy
- [`RAPT_Brewing_Dashboard-new`](https://github.com/alexstuder-web/RAPT_Brewing_Dashboard-new) — Echtzeit Fermentation Dashboard
