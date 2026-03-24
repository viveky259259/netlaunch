# Phase 2: PLAN — Engineering Review Output

## Architecture Decision
Two-tier config storage: local (~/.netlaunch/firebase-config.json) for CLI, synced to Firestore (firebaseConfigs/{userId}) for dashboard+CLI. Deploy resolution: server config > local config > default (NetLaunch project).

## Implementation Plan

### Files to Change (in order)
1. `functions/src/services/firebaseDeployer.ts` — Refactor to accept optional FirebaseProjectConfig, use user's credentials if provided
2. `functions/src/functions/saveFirebaseConfig.ts` — NEW: validate + save service account config
3. `functions/src/functions/getFirebaseConfig.ts` — NEW: retrieve user's saved config
4. `functions/src/functions/deleteFirebaseConfig.ts` — NEW: remove saved config
5. `functions/src/functions/onFileUpload.ts` — Fetch user's config before deploying
6. `functions/src/functions/cliDeploy.ts` — Accept optional config, fetch user's server config
7. `functions/src/index.ts` — Register new functions
8. `flutter_app/lib/services/storage_service.dart` — No changes needed (config resolved server-side by userId)
9. `flutter_app/lib/services/functions_service.dart` — Add config CRUD methods
10. `flutter_app/lib/screens/settings_screen.dart` — Add Firebase Config section
11. `cli/index.js` — Add config set/remove/show commands, --sync flag, --hosted flag

## Decisions Made
1. Scope: EXPANSION
2. Config set once, used forever (not per-deploy)
3. Two-tier: local + synced to server
4. --sync flag opts into server storage
5. Dashboard always uses server config
