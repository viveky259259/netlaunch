# Phase 3: BUILD — Implementation Output

## Changes Made

### Backend (functions/src/)
- `services/firebaseDeployer.ts` — Refactored: added `FirebaseProjectConfig` interface, `resolveCredentials()` that mints JWT tokens from user service accounts, `getUserFirebaseConfig()` helper. All API calls now use `DeployCredentials` object instead of hardcoded project/token. Analytics beacon skipped for self-hosted deploys.
- `functions/saveFirebaseConfig.ts` — NEW: Validates service account by minting token + calling Hosting API, saves to `firebaseConfigs/{userId}`
- `functions/getFirebaseConfig.ts` — NEW: Returns user's config (projectId, clientEmail — never the private key)
- `functions/deleteFirebaseConfig.ts` — NEW: Removes saved config
- `functions/onFileUpload.ts` — Updated: fetches user's Firebase config before deploying
- `functions/cliDeploy.ts` — Updated: fetches user's Firebase config before deploying
- `index.ts` — Registered 3 new callable functions

### Frontend (flutter_app/lib/)
- `services/functions_service.dart` — Added `saveFirebaseConfig()`, `getFirebaseConfig()`, `deleteFirebaseConfig()`
- `screens/settings_screen.dart` — Added "Firebase Configuration" section with upload/remove/status UI

### CLI (cli/)
- `index.js` — Added `config set/show/remove` commands, `--sync` flag, `--hosted` flag, local config storage

### Dependencies
- `google-auth-library` — Added for JWT token minting from service account keys

## Deployed
- 3 new Cloud Functions created (saveFirebaseConfigFunction, getFirebaseConfigFunction, deleteFirebaseConfigFunction)
- 10 existing functions updated
- Hosting updated with new Flutter build

## Deviations from Plan
- None — implemented as planned
