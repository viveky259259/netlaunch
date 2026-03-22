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
| `netlaunch config set` | Set Firebase config for self-hosted deploys |
| `netlaunch config show` | Show current Firebase config |
| `netlaunch config remove` | Remove Firebase config |

## Deploy Options

| Flag | Short | Description |
|------|-------|-------------|
| `--site` | `-s` | Site name / subdomain (3-30 chars, lowercase) |
| `--file` | `-f` | Path to ZIP archive |
| `--key` | `-k` | API key — optional if logged in |
| `--hosted` | | Force deploy to NetLaunch (ignore saved config) |

## Self-Hosted Deployments

Deploy to **your own Firebase project** instead of NetLaunch's.

### Setup

1. Go to [Firebase Console](https://console.firebase.google.com) → your project
2. **Project Settings** → **Service accounts** → **Generate new private key**
3. Save the JSON file

### CLI

```bash
# Save config locally
netlaunch config set --file ./service-account.json

# Save and sync to server (use from dashboard too)
netlaunch config set --file ./service-account.json --sync

# All deploys now go to YOUR Firebase project
netlaunch deploy -s my-app -f ./dist.zip

# Override: deploy to NetLaunch hosting instead
netlaunch deploy -s my-app -f ./dist.zip --hosted

# View current config
netlaunch config show

# Remove config (back to NetLaunch hosting)
netlaunch config remove
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

Set `NETLAUNCH_KEY` environment variable in your CI pipeline:

```yaml
# GitHub Actions
- name: Deploy
  env:
    NETLAUNCH_KEY: ${{ secrets.NETLAUNCH_KEY }}
  run: npx netlaunch deploy -s my-app -f ./dist.zip
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
