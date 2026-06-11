# Brainstorm: Multiple Firebase Project Setup

**Date**: 2026-06-09
**Type**: exploration / decision-making
**Project**: NetLaunch

## Central Question
How should NetLaunch support working with **multiple Firebase projects** — for end users
(bring-your-own-project), for switching/scoping between projects, and/or for scaling
NetLaunch's own shared hosting across many backend projects?

## Current State (grounding)
- Two deploy targets:
  1. **Shared NetLaunch hosting** (default) → `deployinstantwebapp`, user gets a subdomain.
  2. **BYO Firebase** → `netlaunch config use` picks a GCP project, mints a service-account
     key, stores it globally (`~/.netlaunch/firebase-config.json`) or project-locally
     (`./.netlaunch/`, takes precedence over global).
- gcloud SDK lists projects + mints keys.
- Functions backend stores user SA config server-side (`saveFirebaseConfigFunction` etc).
- **CRITICAL FACT:** each deploy creates a *real Firebase Hosting site*
  (`firebaseDeployer.ts` → `createHostingSiteIfNeeded` → `POST .../sites?siteId=`,
  URL `https://${siteId}.web.app/`). Firebase caps **~36 sites/project** by default →
  the shared project can host ~36 user deployments TOTAL before wall-slamming.
  This makes backend scaling (Branch B) a near-term ceiling, not a someday problem.

## Mind Map
```
MULTIPLE FIREBASE PROJECT SETUP
├── A. USER-SIDE PROFILES (one dev, many own projects)
│     A1. Named aliases: config use --as staging ; deploy -p staging
│     A2. Reference-not-copy: .netlaunch/ stores alias pointer; SA lives once globally
│     A3. Wrong-project safety: colored pre-deploy banner, prod=red+confirm, folder pin
│     A4. Visibility: `netlaunch projects` (list + active + last-deployed)
│     A5. Resolution chain: flag > env > ./.netlaunch > global default
├── B. NETLAUNCH BACKEND SHARDING (shared hosting outgrows one project)
│     B1. Forcing function: ~36 sites/project cap
│     B2. Shard pool: shard-01..NN, Firestore site→shard map, capacity allocator, auto-pool
│     B3. Escape cap: wildcard domain + router (Cloud Run/Worker) + object store + CDN
│     B4. Blast-radius isolation: per-shard quota/billing
│     B5. Rebalancing: migrate site between shards
└── C. MULTI-TENANT / TEAM
      C1. Tiers: Managed (NL-owned, we bill) vs BYO (user project, their billing)
      C2. Workspaces + RBAC
      C3. Credential security: off long-lived SA keys → least-priv / encrypt / client-side / WIF
      C4. Onboarding: "Connect your Firebase" OAuth + Management API vs paste SA JSON
      C5. Isolation: tenant-per-project (strong) vs shared+namespaced (weak) = same axis as B
```

**Spine connecting all three:** *how isolated is each deployment, and who owns the project
it lands in?* A = UX of choosing; B = scaling consequence of NOT isolating (shared pool);
C = trust/billing consequence of isolating (BYO/per-tenant).

## Deep Dives

### A1+A3 — Profiles & safety (ship-now layer)
- `~/.netlaunch/profiles.json`: { alias: {projectId, saRef, production?} }
- `config use --as <alias>`, `deploy -p <alias>`, `netlaunch projects` (list/active/last-deploy)
- Resolution: `--project` > `$NETLAUNCH_PROJECT` > `./.netlaunch` > global default
- A2: `.netlaunch/config.json` = `{ "project": "alias" }` pointer (no SA duplication per folder)
- A3: pre-deploy banner (alias/projectId/site/tag); prod = red + typed confirm; folder pin → CI mismatch error
- Cost: one CLI-only PR, no backend change. Best value/effort.

### B2 — Shard pool allocator (incremental, ceilinged)
- shards netlaunch-shard-01..NN (≤36 sites each); Firestore sites{→shard} + shards{capacity}
- least-loaded allocator; auto-Terraform new shard when free capacity < threshold
- Pros: reuses Firebase CDN/TLS/atomic-deploy/rollback; incremental
- Cons: mini-orchestrator; cross-project SA/IAM sprawl; monitor N projects; cap = 36×N;
  quota bumps need Google support → you don't own your ceiling

### B3 — Escape the cap (strategic re-platform)
- `*.netlaunch.app` wildcard + managed TLS → Router (Cloud Run / CF Worker) reads Host →
  serves from object store (Cloud Storage / R2) + CDN. No Hosting "site" objects → unlimited.
- Firebase shrinks to Auth + Firestore(metadata) + Functions (no site cap there).
- Natural seam for analytics injection (already have trackPageView), headers, redirects.
- B3a: Cloudflare for SaaS (Workers + R2 + on-demand TLS for user custom domains) — cleanest
  multi-tenant static host, but off-GCP hosting path.
- Cons: re-implement atomic deploy, cache invalidation, and esp. TLS for arbitrary user
  custom domains (the hard part). Bigger build; removes the ceiling entirely.

### C3 — Credential security (multi-tenant gate)
Today: raw SA private keys stored server-side → one leak = takeover of every BYO project.
Fix ladder:
  1. Least-privilege SA on mint (firebasehosting.admin only)        — tiny
  2. Encrypt at rest (Secret Manager / KMS), decrypt in-function     — small
  3. Client-mediated deploy: CLI uses local .netlaunch/ SA, server never sees key — medium
  4. IAM grant / Workload Identity Federation: user grants NL deployer SA Hosting Admin on
     THEIR project; zero user keys stored; revoke = remove binding   — larger
Fork: server-mediated deploy (needs creds server-side = the problem) vs client-mediated
(CLI uses local creds = problem evaporates). For BYO, rungs 3–4 make creds-at-rest a non-issue.

## Discussion Log
- Scope: user chose all three senses (A user-side, B backend sharding, C multi-tenant).
- Deep-dive picks: all four (B3, B2, C3, A1+A3).
- Confirmed via firebaseDeployer.ts that each deploy = a Hosting site → ~36/project cap is
  a hard near-term ceiling on the shared project.

### FOCUS: Per-repo → per-project binding (the user's core case)
**Scenario:** one user, many repos, each repo bound to its own Firebase project. `.netlaunch/`
per repo is how NetLaunch remembers which project + key a repo belongs to.

**Current code (grounded):**
- `./.netlaunch/service-account.json` holds the FULL key (private_key), mode 0600.
- `ensureGitignored('.netlaunch')` appends `.netlaunch/` to repo .gitignore (good).
- `loadProjectConfig()`: local SA → else global ~/.netlaunch → else null.
- So per-repo binding works locally, BUT...

**THE GAP:** the whole `.netlaunch/` (incl. projectId) is gitignored, so the repo→project
binding does NOT travel. A teammate / CI / new laptop clones the repo and has no idea which
project it targets — the "which project" knowledge is trapped inside the secret.

**THE FIX — split committed pointer from secret key:**
```
repo/.netlaunch/
  config.json          COMMITTED, safe: { project, site?, alias?, target(s)? }  ← the binding
  service-account.json GITIGNORED, optional repo-local key override
~/.netlaunch/projects/
  <projectId>.json     GLOBAL key store, keyed by projectId, mode 0600, shared across repos
```
**Deploy resolution:**
```
1. discover .netlaunch/ (walk up from cwd, like git finds .git)
2. read config.json → project
3. find key in order: $NETLAUNCH_SA_JSON/$GOOGLE_APPLICATION_CREDENTIALS (CI)
                     → ./.netlaunch/service-account.json (repo override)
                     → ~/.netlaunch/projects/<project>.json (global store)
                     → none → prompt → gcloud mint → save to global store
```
**Why right:** config.json = `.firebaserc` (declarative, shared); key = `~/.aws/credentials`
(secret, machine-local). Same project across N repos → ONE key in global store (no dup).
Different project per repo → config.json disambiguates → wrong-project mistake gets hard.
Multi-env: config.json can hold `targets:{staging,prod}` → `deploy --target prod`.

**Open fork (D5) — RESOLVED:** key storage = **repo-local** (keep today's
`./.netlaunch/service-account.json`, gitignored). Repos stay self-contained. The new piece is
a **committed `./.netlaunch/config.json`** pointer so the binding travels.

**→ Full implementation spec written: `cli/SPEC-per-repo-projects.md`**
(file layout, config.json schema, deploy resolution algorithm, clone-and-go flow, migration
from today's single-file model, CI recipe, gitignore change, command extensions, checklist).

## Synthesis

### Key Insights
1. **The 36-site/project cap is the load-bearing constraint.** Each deploy = a Hosting site,
   so the shared project caps at ~36 user sites. Backend scaling is urgent, not theoretical.
2. **B3 may dissolve the "multiple projects" problem on the backend.** Re-platforming user
   hosting to wildcard-domain + object-store + CDN removes the cap → one project, ∞ sites.
   Then "multiple Firebase projects" is only a USER-side concern (A) + BYO isolation (C).
3. **There's one deploy-locus fork that drives security:** server-mediated (creds stored
   server-side, the C3 risk) vs client-mediated (CLI deploys with local creds). The local
   `.netlaunch/` model already leans client-side — extend it for BYO and the worst credential
   risk largely disappears.
4. **B (isolation for scale) and C5 (isolation for tenancy) are the same axis** — solve once.
5. **A1+A3 is pure upside, no dependencies** — ships immediately, extends the just-published
   config-use feature.

### Decision Points
- **D1 (biggest):** Backend hosting architecture — shard Firebase Hosting (B2) vs re-platform
  to wildcard + object-store/CDN (B3)?
- **D2:** Deploy locus — server-mediated vs client-mediated (esp. for BYO)? Drives C3.
- **D3:** Product model — managed-shared vs BYO vs both (tiers)?
- **D4:** Domain strategy — `.web.app` subdomains vs own `*.netlaunch.app` wildcard vs user
  custom domains?
- **Missing info:** current # of live user sites (how close to 36?); all-GCP vs open to
  Cloudflare; managed-vs-BYO business priority.

### Next Steps (prioritized)
**Quick wins**
1. A1+A3: profiles (`--as`, `-p`, `netlaunch projects`) + pre-deploy safety banner — 1 CLI PR.
2. C3 rungs 1–2: least-privilege SA on mint + encrypt stored keys (Secret Manager).
**Medium**
3. Decide D2; prototype client-side BYO deploy using local `.netlaunch/` SA (removes server
   key storage for BYO).
4. Spike B3: `*.netlaunch.app` wildcard → Cloud Run router → Cloud Storage for ONE test site;
   measure cold start, TLS, cache, rollback. Decide B2 vs B3 (D1).
**Longer**
5. If B3 validates: design migration of shared hosting off Firebase Hosting sites.
6. BYO via IAM grant / WIF (C3 rung 4) — no stored keys.
7. Workspaces/RBAC + billing tiers (C1/C2) once isolation model is fixed.
