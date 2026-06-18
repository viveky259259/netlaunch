# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

NetLaunch — deploy a static-site ZIP and get an instant live URL. Two front doors share one backend:

- **Web app** (`flutter_app/`) — Flutter web dashboard at `deployinstantwebapp.web.app`. Sign in with Google, upload a ZIP, manage sites, view analytics.
- **CLI** (`cli/`) — the `netlaunch` npm package. `netlaunch login && netlaunch deploy -f dist.zip`.

Both deploy to either **NetLaunch hosting** (the default shared Firebase project) or a user's **self-hosted** Firebase project (when they supply a service-account key). README.md/SETUP.md are stale (they still call the project "firebase_hosting_service") — trust the code over those docs.

## Repository layout

| Path | What | Stack |
|------|------|-------|
| `flutter_app/` | Web frontend (screens, widgets) | Flutter web |
| `packages/` | 4 path-dependency Dart packages (see below) | Dart/Flutter |
| `functions/` | Cloud Functions backend | TypeScript → `lib/` |
| `cli/` | `netlaunch` CLI, single-file `index.js` (~1200 lines, no deps) | Node ≥18 |
| `firebase/` | `firestore.rules`, `storage.rules` | — |
| `scripts/` | `setup.sh` (config injection) + `deploy.sh` | bash |

### Dart package dependency graph

`netlaunch_core` is pure Dart (models `Deployment`/`DeploymentAnalytics`, `SiteNameValidator`, status constants — no Flutter/Firebase). Everything else depends on it:

- `netlaunch_auth` — provider-agnostic auth interface + Firebase/Google implementation.
- `netlaunch_api` — Firebase service layer (Firestore, Functions, Storage, usage, preferences).
- `netlaunch_ui` — shared widgets + theme (uses `flutterkit` from a git dependency).

`flutter_app` composes all four. When adding a model or validator used across layers, put it in `netlaunch_core` — don't reintroduce Firebase coupling there.

## Config injection — read before touching source

Source files commit **`*_PLACEHOLDER` tokens** instead of real Firebase config (e.g. `FIREBASE_PROJECT_ID_PLACEHOLDER`, `FIREBASE_API_KEY_PLACEHOLDER`). `scripts/setup.sh` `sed`-replaces them **in place** from `.env` across `*.dart/*.ts/*.js/*.html/*.json/.firebaserc`. Files carrying placeholders: `firebase.json`, `flutter_app/lib/main.dart`, `flutter_app/web/cli-auth.html`, `cli/index.js`, `functions/src/services/firebaseDeployer.ts`, `scripts/setup.sh`.

Consequences:
- **Never commit a file after `setup.sh` has injected real values** — it would leak credentials and break the placeholder contract. If you must edit one of those files, edit the placeholder tokens, not the substituted values.
- `.env` is gitignored and lives in the private `netlaunch-config` repo. Bootstrap with `./scripts/setup.sh --from-repo` (clones the config repo, drops in `.env`). See the `netlaunch-release-workflow` memory.
- When adding a new piece of injectable config, add a `*_PLACEHOLDER` token in source, an `.env` var, and a `replace_placeholder` line in `setup.sh`.

## Common commands

```bash
# One-time / per-machine: pull private .env, then inject config
./scripts/setup.sh --from-repo

# Full deploy (functions + flutter hosting) — injects config, builds, deploys
./scripts/deploy.sh

# Targeted deploys
npm run deploy:functions      # build TS + deploy functions only
npm run deploy:rules          # firestore + storage rules
npm run deploy:hosting        # flutter web build + hosting (deploy.sh)

# Functions (from functions/)
npm run build                 # tsc → lib/
npm run serve                 # build + emulators (functions only)
npm run logs                  # firebase functions:log

# Flutter (from flutter_app/)
flutter run -d chrome         # local dev
flutter build web --release
flutter test                  # only widget_test.dart exists today

# Full local emulator suite
firebase emulators:start
```

CLI is published to npm as `netlaunch` (version in `cli/package.json`, currently 2.x). The repo also versions the web app (`flutter_app/lib/version.dart` `kAppVersion`, kept in sync with `pubspec.yaml`) — bump both together when changing the app version shown in the footer.

## Backend architecture (`functions/src/`)

`index.ts` is the wiring manifest — every function is registered there (region `us-central1`). Two entry styles:

1. **Storage-triggered web deploys** — `onFileUploadTrigger` (`onFinalize`) fires on uploads to `uploads/{apiKey}/{timestamp}.zip`, runs `onFileUpload`: validate API key → unzip → validate (must contain an HTML file) → assign subdomain → deploy.
2. **HTTP `cliDeploy`** — multipart endpoint the CLI posts to; same deploy path without a Storage round-trip.

Plus callables for listing/deleting deployments, analytics, API-key generation, and self-hosted Firebase config CRUD (`saveFirebaseConfig`/`getFirebaseConfig`/`deleteFirebaseConfig`).

`services/` holds the reusable core:
- `apiKeyService.ts` — keys are `fk_<hex>`, **stored SHA-256-hashed** in Firestore `apiKeys/{hash}`; validation hashes the incoming key. Never store/log the raw key.
- `firebaseDeployer.ts` — `deployToFirebaseHosting`. Resolves credentials: default project vs. **self-hosted** (user service-account JWT via `google-auth-library`). Injects an analytics beacon `<script>` into HTML **before** upload — **skipped for self-hosted** deploys. Uses the Hosting REST API (gzip + sha256 of each file).
- `subdomainManager.ts`, `fileProcessor.ts` — subdomain allocation and ZIP extraction/validation.

When changing the deploy flow, remember it runs from **both** `onFileUpload` and `cliDeploy` — keep them consistent.

## CLI deploy modes (`cli/index.js`)

Config resolution is the subtle part. Precedence and storage:
- Global creds: `~/.netlaunch/credentials.json`; global key cache: `~/.netlaunch/projects/`; self-hosted Firebase config: `~/.netlaunch/firebase-config.json`.
- **Project-local** `./.netlaunch/`: `config.json` (committed binding — project/site/alias/target, **no secrets**) + `service-account.json` (gitignored key).
- `link` writes a binding; `config use` mints a key and writes `config.json`; `config show` is the doctor that prints the resolved binding, key source, and deploy mode. `--prod` bindings show a red banner and require confirm (`-y` to skip, needed in CI). `--hosted` forces NetLaunch hosting, ignoring saved self-hosted config.

There's a known gotcha where server-stored config can override local intent — see the `netlaunch-release-workflow` memory (cliDeploy stored-config gotcha) and `netlaunch-invalid-jwt-cause` for the self-hosted JWT propagation issue.

## Heads-up

`SETUP.md` line 2 contains a committed raw `fk_…` API key — flag/rotate it; don't replicate that pattern. Secrets belong in the private `netlaunch-config` / `secrets` repos, never in tracked source.
