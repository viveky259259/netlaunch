# NetLaunch CLI

Deploy static sites in seconds. Zero config, instant URLs.

```bash
npx netlaunch deploy -s my-app -f ./dist.zip
# → https://my-app.web.app
```

## Install

```bash
npm install -g netlaunch
```

Or use directly with `npx`:

```bash
npx netlaunch deploy -s my-app -f ./dist.zip
```

## Quick Start

### 1. Login with Google

```bash
netlaunch login
```

Opens your browser for Google Sign-In. Credentials are stored locally at `~/.netlaunch/credentials.json`.

### 2. Deploy

```bash
netlaunch deploy --site my-app --file ./dist.zip
```

That's it. Your site is live at `https://my-app.web.app`.

## Commands

| Command | Description |
|---------|-------------|
| `netlaunch login` | Sign in with Google (opens browser) |
| `netlaunch logout` | Remove stored credentials |
| `netlaunch whoami` | Show current logged-in user |
| `netlaunch deploy` | Deploy a ZIP archive |
| `netlaunch link <project>` | Bind this repo to a Firebase project (writes `.netlaunch/config.json`) |
| `netlaunch config use` | Pick a project, mint its key (`./.netlaunch/`) **and** write `config.json` |
| `netlaunch config set` | Set Firebase config for self-hosted deploys (global) |
| `netlaunch config show` | Show the resolved binding, key source & deploy mode (doctor) |
| `netlaunch config remove` | Remove this repo's `.netlaunch/` binding & key |

## Deploy Options

| Flag | Short | Description |
|------|-------|-------------|
| `--site` | `-s` | Site name / subdomain — optional if `config.json` sets it |
| `--file` | `-f` | Path to ZIP archive |
| `--key` | `-k` | API key — optional if logged in |
| `--target` | `-t` | Target name from a multi-env `config.json` |
| `--yes` | `-y` | Skip the production confirmation (required in CI for prod) |
| `--hosted` | | Force deploy to NetLaunch (ignore saved config) |

## Self-Hosted Deployments (per-repo)

Deploy to **your own Firebase project** instead of NetLaunch's. Each repo is bound to its
own project via a committed `.netlaunch/config.json`, so the binding travels with the repo
(teammates, CI, a new laptop) while the secret key stays local and gitignored.

```
.netlaunch/
  config.json           # COMMITTED — { project, site, ... }. The binding. No secrets.
  service-account.json  # GITIGNORED — the key. Per-developer, per-machine.
```

### Connect a repo

```bash
# Pick a project, mint a key, AND write the committed config.json (needs gcloud, or use --file)
netlaunch config use

# Or just DECLARE the binding (no key, no gcloud) — for authors & teammates:
netlaunch link my-project --site my-site
netlaunch link my-project --prod          # mark production (red banner + confirm)

# Bring your own key:
netlaunch config use --file ./service-account.json
```

Commit `.netlaunch/config.json`. The CLI adds `service-account.json` to `.gitignore` for you.

### Deploy

```bash
# project & site come from config.json — no flags needed
netlaunch deploy -f ./dist.zip

# multi-environment config:
netlaunch deploy --target prod -f ./dist.zip

# override: deploy to NetLaunch hosting instead
netlaunch deploy -s my-app -f ./dist.zip --hosted

netlaunch config show      # doctor: shows project, site, key source & mode
netlaunch config remove    # drop this repo's binding & key
```

### Clone-and-go

A teammate clones a repo that has a committed `config.json` but no key. `netlaunch deploy`
reads the project from `config.json`, and — if no key is found locally, in `~/.netlaunch`'s
cache, or in the environment — prompts them to authenticate once for that project.

### Multi-environment `config.json`

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

### Dashboard

Go to **Settings** → **Firebase Configuration** → upload your service account JSON.

## Examples

```bash
# Login first (one-time)
netlaunch login

# Deploy a site
netlaunch deploy -s portfolio -f ./build.zip

# Deploy with explicit API key (no login needed)
netlaunch deploy -k fk_abc123 -s my-app -f ./dist.zip

# Self-hosted: set config and deploy
netlaunch config set -f ./my-firebase-key.json --sync
netlaunch deploy -s my-app -f ./dist.zip

# Use environment variable for CI/CD
export NETLAUNCH_KEY=fk_your_key
netlaunch deploy -s my-app -f ./dist.zip
```

## CI/CD

**NetLaunch hosting** — set `NETLAUNCH_KEY`:

```yaml
# GitHub Actions
- name: Deploy
  env:
    NETLAUNCH_KEY: ${{ secrets.NETLAUNCH_KEY }}
  run: npx netlaunch deploy -s my-app -f ./dist.zip
```

**Self-hosted** — commit `.netlaunch/config.json`, provide the key via `NETLAUNCH_SA_JSON`
(or `GOOGLE_APPLICATION_CREDENTIALS`), and pass `--yes` to clear the production gate:

```yaml
- name: Deploy to our Firebase project
  env:
    NETLAUNCH_KEY: ${{ secrets.NETLAUNCH_KEY }}
    NETLAUNCH_SA_JSON: ${{ secrets.FIREBASE_SA_JSON }}
  run: npx netlaunch deploy --target prod --yes -f ./dist.zip
```

## Requirements

- Node.js >= 18
- A ZIP file with `index.html` at root (or in a subdirectory)

## Links

- **Dashboard**: [deployinstantwebapp.web.app](https://deployinstantwebapp.web.app)
- **Docs**: [netlaunch-docs.web.app](https://netlaunch-docs.web.app)
- **GitHub**: [github.com/viveky259259/netlaunch](https://github.com/viveky259259/netlaunch)

## License

MIT
