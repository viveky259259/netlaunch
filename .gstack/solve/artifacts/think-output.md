# Phase 1: THINK — CEO Review Output

## Problem (restated)
Build a full self-hosted deployment platform where users provide their own Firebase project configuration (service account key), and NetLaunch deploys to THEIR Firebase Hosting project. NetLaunch becomes a deployment orchestrator for any Firebase project.

## Scope Decision: EXPANSION
User chose full self-hosted platform over CLI-only or minimal approaches.

## Key Insights
1. **Current deployer is tightly coupled** — `PROJECT_ID` hardcoded, uses `admin.credential.applicationDefault()`. Need to make the deployer accept arbitrary Firebase credentials.
2. **Service account key is the critical piece** — users must provide a JSON service account key with Firebase Hosting Admin permissions. This key must be stored securely (encrypted at rest).
3. **Two deployment modes emerge** — "NetLaunch Hosted" (default, deploy to our project) vs "Self-Hosted" (deploy to user's Firebase project). Both share the same deployment engine.
4. **Analytics beacon needs to be configurable** — currently points to our trackPageView endpoint. For self-hosted, either skip it or let user opt-in.

## What Already Exists
- `firebaseDeployer.ts` — full Firebase Hosting API integration (create site, version, upload, release)
- `cliDeploy` HTTP function — already accepts multipart uploads
- CLI tool — already has login, deploy commands
- Dashboard — NewDeploymentScreen with method selector

## Deferred (explicitly NOT in scope)
- Billing/metering for self-hosted deployments
- Multi-project management UI (manage many Firebase configs)
- Automatic Firebase project setup (user must create project themselves)
- Custom analytics pipeline for self-hosted sites

## Delight Opportunities
- One-click test of Firebase config (validate before first deploy)
- Config saved per-account so user doesn't re-upload every time
- Dashboard shows both hosted and self-hosted deployments in one view
- CLI `netlaunch config add` to save Firebase configs locally
