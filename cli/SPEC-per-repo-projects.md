# NetLaunch CLI — Per-Repo Firebase Project Spec

**Status:** Draft **v2** · **Date:** 2026-06-10 · **Owner:** Vivek
**Source:** `brainstorm-multiple-firebase-project-setup-2026-06-09.md`,
review: `brainstorm-review-the-specs-2026-06-10.md`

### Changes since v1 (from the spec review)
- **Walk-up discovery now bounded** to the git repo root (§3.1) — fixes "deploy from a parent
  repo's config" footgun.
- **.gitignore handled by NEGATION, never rewrite** (§7) — a blanket `.netlaunch/` gets a
  `!.netlaunch/config.json` exception; the key stays ignored. Removes the un-ignore-a-secret risk.
- **New `netlaunch link` command** (§5.5) — declare the binding WITHOUT minting a key
  (authors + teammates). `config use` = link + mint.
- **Global key cache** `~/.netlaunch/projects/<projectId>.json` (§3.2) — repo-local stays the
  source of truth; cache removes the re-auth tax for same-project-many-repos.
- **CI / non-TTY production = hard fail without `--yes`** (§4) — never silent-confirm prod.
- **Schema precedence + version handling pinned** (§2.1) — `targets{}` wins over top-level;
  unknown `version` errors. CI examples made consistent (§8).
- **config.json writer strips secret fields** (§2.1) — defense in depth.

## 1. Goal
Let one user manage **many repos, each bound to its own Firebase project**, so `netlaunch
deploy` (no args) always targets the correct project for the current repo — and the binding
survives clone, CI, and a new laptop.

**Decisions (locked):** key stays **repo-local** (`./.netlaunch/service-account.json`,
gitignored). A **committed** `./.netlaunch/config.json` carries the repo→project binding.
A global key **cache** is a convenience only, never the source of truth.

**Non-goals:** backend sharding; OAuth/WIF; key rotation (noted §11).

## 2. File Layout
```
repo/.netlaunch/
  config.json           # COMMITTED. Safe, no secrets. The binding.
  service-account.json  # GITIGNORED. The key (0600). Per-developer / per-machine.
~/.netlaunch/
  projects/<projectId>.json   # GLOBAL KEY CACHE (0600). Convenience; not authoritative.
  firebase-config.json        # existing global default (unchanged)
  credentials.json            # existing login creds (unchanged)
```

### 2.1 `config.json` schema
Simple (single target):
```jsonc
{ "version": 1, "project": "acme-prod", "site": "acme-www", "alias": "prod", "production": true }
```
Multi-environment:
```jsonc
{
  "version": 1,
  "defaultTarget": "staging",
  "targets": {
    "staging": { "project": "acme-staging", "site": "acme-staging" },
    "prod":    { "project": "acme-prod", "site": "acme-www", "production": true }
  }
}
```
**Rules:**
- If `targets` is present, top-level `{project,site,...}` is **ignored** (targets wins).
  Resolution requires `--target` or `defaultTarget`; else error.
- If `targets` absent, the top-level object is the single target.
- `version` > highest supported → **error**: "config.json version N not supported; upgrade netlaunch."
- The writer MUST strip any `type` / `client_email` / `private_key` / `private_key_id`
  fields before writing (config.json never holds secrets, even by accident).

## 3. Resolution Algorithm
```
netlaunch deploy [--target <t>] [--hosted] [--yes]
  1. --hosted → shared NetLaunch hosting; skip the rest.
  2. DISCOVER config.json (§3.1, git-root-bounded).
  3. Resolve target → projectId, siteId, production?  (§2.1 rules)
  4. FIND KEY for projectId (§3.2).
  5. VALIDATE key.project_id === target.project  (else hard error — mismatch guard).
  6. BANNER + confirm (§4) → deploy via existing firebaseDeployer path.
```
Overall precedence: `--hosted` > repo config.json > global `~/.netlaunch/firebase-config.json`
> NetLaunch hosting default.

### 3.1 Discovery (bounded walk-up)
```
- Determine gitRoot = nearest ancestor containing `.git` (inclusive), searching upward.
- If in a git repo: honor `.netlaunch/config.json` ONLY at or below gitRoot.
    Search cwd → up to gitRoot; first hit wins. Found above gitRoot → ignore.
- If NOT in a git repo: honor only `./.netlaunch/config.json` in cwd (no walk-up).
- NEVER traverse above $HOME or the filesystem root.
- Monorepo: nearest `.netlaunch/` to cwd wins.
```

### 3.2 Key lookup (with cache reuse)
```
For projectId, first hit wins:
  a. $NETLAUNCH_SA_JSON (raw JSON) | $GOOGLE_APPLICATION_CREDENTIALS (path)   [CI]
  b. <repoRoot>/.netlaunch/service-account.json                              [repo-local, authoritative]
  c. ~/.netlaunch/projects/<projectId>.json  → prompt:
        "Reuse saved credentials for <projectId>? [Y/n]"  → copy into (b)     [cache reuse]
  d. none → CLONE-AND-GO (§6): mint/paste → write-through to (b) AND (c)
```

## 4. Safety Banner (A3)
Before every self-hosted deploy:
```
  Deploying to Firebase
  Project:  acme-prod   (prod)
  Site:     acme-www
  Source:   ./dist.zip
```
- `production: true` → project line **red**.
- Confirmation matrix:
  | Env | production | --yes | Behavior |
  |-----|-----------|-------|----------|
  | TTY | false | – | deploy (banner only) |
  | TTY | true  | no  | require typed project id to continue |
  | TTY | true  | yes | deploy |
  | non-TTY (CI) | false | – | deploy |
  | non-TTY (CI) | true | no | **HARD FAIL**: "Refusing prod deploy without --yes" |
  | non-TTY (CI) | true | yes | deploy |
- `config.project` ≠ resolved key `project_id` → **refuse** (mismatch guard), any env.

## 5. Command Surface

### 5.1 `netlaunch config use`  (extend)
Pick project (gcloud) or `--file <sa.json>`, then: write key to repo-local (0600) + global
cache; **call `link` internally** to write `config.json`; ensure gitignore (§7). Order:
gitignore rules FIRST, then config.json, then print `git add .netlaunch/config.json`.

### 5.2 `netlaunch deploy`  (extend)
§3 resolution + §4 banner. `--target`, `--yes` added. Flags override config.

### 5.3 `netlaunch config show`  (extend → resolution trace)
Print: gitRoot, discovered config path, resolved target (project/site/alias/production),
key source (`env` / `repo-local` / `cache` / `missing`), and effective deploy mode. Acts as
a `doctor` — answers "why is it deploying to X?".

### 5.4 `netlaunch config remove`  (extend)
Remove repo `service-account.json` + `config.json`; leave global cache (with a note).

### 5.5 `netlaunch link <project>`  (NEW)
`netlaunch link <projectId> [--site <s>] [--alias <a>] [--prod] [--target <name>]`
- Writes/updates `./.netlaunch/config.json` ONLY — no gcloud, no key, no network.
- Ensures gitignore (§7) and prints `git add .netlaunch/config.json`.
- Use cases: repo AUTHOR declaring the binding; adding a target to multi-env config;
  teammate who will supply their own key later via `config use` / clone-and-go.

## 6. Clone-and-Go Flow
Repo has committed `config.json` but no key on this machine:
```
$ netlaunch deploy
  This repo is bound to Firebase project: acme-prod  (.netlaunch/config.json)
  No local credentials for acme-prod.
  ~/.netlaunch cache has a saved key for acme-prod → Reuse? [Y/n]      (if cache hit)
  else → Authenticate: [1] gcloud   [2] paste service-account JSON path
```
On success: validate `project_id === config.project`, write-through to repo-local + cache, deploy.

## 7. .gitignore Handling (NEGATION, never rewrite)
```
- Goal: service-account.json ignored; config.json committable. NEVER remove an existing ignore.
- If `.gitignore` has NO `.netlaunch` rule:
     append `.netlaunch/service-account.json`.
- If it has a blanket `.netlaunch/` (or `.netlaunch`):
     git CANNOT re-include a file whose parent dir is excluded, so a bare
     `!.netlaunch/config.json` does nothing. Instead append THREE lines:
        !.netlaunch/        # re-include the directory so git traverses it
        .netlaunch/*        # re-ignore its contents (incl. service-account.json)
        !.netlaunch/config.json   # re-include ONLY the binding
     This keeps the key AND any other files in the folder ignored, exposing only config.json.
- After writing, run `git check-ignore .netlaunch/config.json`; if still ignored, WARN the
  user with the offending pattern and how to fix. Do NOT auto-delete their patterns.
- Verified: blanket case stages only config.json; service-account.json and unrelated
  .netlaunch/ files remain ignored. Idempotent across repeated runs.
```
Migration of legacy repos is just this routine run on next `config`/`deploy` (idempotent),
plus a one-time notice: "Created/committable .netlaunch/config.json — commit it so teammates
and CI know this repo targets <project>."

## 8. CI Recipes
Simple schema:
```yaml
# committed: .netlaunch/config.json  → { version:1, project:"acme-prod", production:true }
# secret:    NETLAUNCH_SA_JSON
- run: npx netlaunch deploy --yes -f ./dist.zip
```
Multi-target schema:
```yaml
# committed config.json has targets.prod
- run: npx netlaunch deploy --target prod --yes -f ./dist.zip
```
No gcloud, no prompts; project from committed config, key from env, `--yes` clears the prod gate.

## 9. Backward Compatibility
- Legacy repos with only `service-account.json` keep working; §7 routine adds a committable
  config.json on next run.
- Global `~/.netlaunch/firebase-config.json` still used when no repo `.netlaunch/` is discovered.
- `--hosted` unchanged.

## 10. Implementation Checklist
- [ ] `findGitRoot()` + bounded `discoverRepoConfig()` (§3.1)
- [ ] `resolveTarget()` — schema rules, version guard, secret-field strip (§2.1)
- [ ] `findKeyForProject()` — env → repo-local → global cache (reuse prompt) → mint (§3.2)
- [ ] global key cache read/write (`~/.netlaunch/projects/<id>.json`, 0600)
- [ ] `.gitignore` negation routine + `git check-ignore` post-check (§7)
- [ ] deploy banner + confirmation matrix + mismatch guard (§4)
- [ ] `netlaunch link` command (§5.5)
- [ ] extend `config use` / `config show` (trace) / `config remove`
- [ ] `--target`, `--yes` flags; update `printUsage()`
- [ ] README: per-repo model, link vs config use, clone-and-go, CI recipes

## 11. Deferred (noted, out of scope)
- Key rotation / expiry workflow.
- config.json declaring build command / output dir (`"output":"dist"`).
- Server-side repo→project map / dashboard sync seeded from config.json.
